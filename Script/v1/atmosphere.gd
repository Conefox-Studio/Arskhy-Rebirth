extends Node2D


const DayNightScript = preload("res://scripts/day_night.gd")

var fog_tint := Color(0.66, 0.71, 0.86)
var fog_strength := 1.0
var ray_origin := Vector2(0.92, -0.05)
var use_canvas_modulate := true
var use_player_light := true

const FOG_LAYERS_BY_RENDER := [[1], [0, 1], [0, 1, 2]]
const RAY_POWER_BY_RENDER := [0.12, 0.17, 0.24]

const FOG_SHADER := """
shader_type canvas_item;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 cam_pos = vec2(0.0);
uniform vec2 view_size = vec2(640.0, 360.0);
uniform float noise_px = 520.0;
uniform float parallax = 0.6;
uniform vec2 wind = vec2(6.0, 0.0);
uniform vec4 tint : source_color = vec4(0.66, 0.71, 0.86, 1.0);
uniform float density = 0.3;
uniform float low_bias = 0.55;

void fragment() {
	vec2 world = cam_pos * parallax + (UV - 0.5) * view_size + wind * TIME;
	float n1 = texture(noise_tex, world / noise_px).r;
	float n2 = texture(noise_tex, world / (noise_px * 0.43) + vec2(0.37, 0.11)).r;
	float m = smoothstep(0.30, 0.85, n1 * 0.7 + n2 * 0.3);
	float h = mix(1.0, smoothstep(0.05, 1.0, UV.y), low_bias);
	COLOR = vec4(tint.rgb, m * h * density);
}
"""

const RAY_SHADER := """
shader_type canvas_item;
render_mode blend_add;
// God ray layar-penuh (radial light shaft, cara kerja sama dengan plugin god rays):
// tiap piksel menelusuri garis lurus ke arah matahari; langit yang terang = celah cahaya,
// pohon / tanah / objek gelap = penghalang, jadi sinar muncul DI SELA pohon dan konsisten di semua map.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 origin = vec2(0.92, -0.05);
uniform float aspect = 1.78;
uniform float intensity = 0.17;
uniform float soft = 0.0;
uniform vec4 tint : source_color = vec4(1.0, 0.96, 0.82, 1.0);
uniform float density = 0.97;
uniform float decay = 0.955;
uniform float threshold = 0.40;

const int SAMPLES = 32;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 to_sun = origin - uv;
	float dist = length(vec2(to_sun.x * aspect, to_sun.y));
	vec2 stp = to_sun * density / float(SAMPLES);
	vec2 c = uv + stp * fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453) * 0.5;   // jitter kecil: tanpa garis-garis patah
	float illum = 1.0;
	float acc = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		c += stp;
		vec3 s = texture(screen_tex, c).rgb;
		float lum = dot(s, vec3(0.299, 0.587, 0.114));
		acc += smoothstep(threshold, threshold + 0.30, lum) * illum;
		illum *= decay;
	}
	acc /= float(SAMPLES) * 0.45;
	float fall = exp(-dist * mix(1.5, 0.95, soft));
	float glow = exp(-dist * 6.0) * 0.45;       // kilau lembut di sekitar matahari
	float v = (acc * fall + glow) * intensity * 3.2;
	COLOR = vec4(tint.rgb * v, 1.0);
}
"""

const SOFT_LIGHT_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float strength = 0.11;
uniform vec4 tint : source_color = vec4(0.82, 0.88, 1.0, 1.0);

void fragment() {
	// cahaya halus: paling terang di sisi kanan, memudar ke kiri
	float g = smoothstep(0.10, 1.0, UV.x);
	float v = 1.0 - smoothstep(0.0, 1.0, UV.y) * 0.6;
	COLOR = vec4(tint.rgb, g * g * v * strength);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.42;
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.15;
	float v = smoothstep(0.32, 0.92, length(p));
	COLOR = vec4(0.015, 0.02, 0.07, v * strength);
}
"""

static var _noise_tex: ImageTexture

var _cam: Camera2D
var _target: Node2D

var _fog_layer: CanvasLayer
var _fog_rects: Array[ColorRect] = []
var _ray_layer: CanvasLayer
var _ray_rect: ColorRect
var _vig_layer: CanvasLayer
var _vig_rect: ColorRect
var _canvas_mod: CanvasModulate
var _light: PointLight2D
var _soft_rect: ColorRect
var day_night: Node = null
var _base_ray := 0.17
var _built := false
var effects_off := false


static func noise_texture() -> ImageTexture:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.frequency = 0.012
		n.seed = 7
		_noise_tex = ImageTexture.create_from_image(n.get_seamless_image(256, 256))
	return _noise_tex


func setup(cam: Camera2D, target: Node2D = null) -> void:
	_cam = cam
	_target = target
	_build_fog()
	_build_rays()
	_build_lighting()
	_built = true
	GameSettings.graphics_changed.connect(refresh)
	refresh()


func _view_world_size() -> Vector2:
	return get_viewport().get_visible_rect().size / _cam.zoom


func _make_layer(layer_num: int) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = layer_num
	add_child(layer)
	return layer


func _make_rect(code: String, parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	parent.add_child(rect)
	return rect


func _build_fog() -> void:
	var defs := [
		{"parallax": 0.35, "noise": 700.0, "density": 0.20, "wind": Vector2(5, 0), "low": 0.35},
		{"parallax": 0.70, "noise": 520.0, "density": 0.26, "wind": Vector2(8, 0), "low": 0.60},
		{"parallax": 1.15, "noise": 380.0, "density": 0.18, "wind": Vector2(13, 0), "low": 0.85},
	]
	_fog_layer = _make_layer(3)
	for d in defs:
		var rect := _make_rect(FOG_SHADER, _fog_layer)
		var mat := rect.material as ShaderMaterial
		mat.set_shader_parameter("noise_tex", noise_texture())
		mat.set_shader_parameter("parallax", d.parallax)
		mat.set_shader_parameter("noise_px", d.noise)
		mat.set_shader_parameter("wind", d.wind)
		mat.set_shader_parameter("low_bias", d.low)
		mat.set_shader_parameter("density", d.density * fog_strength)
		mat.set_shader_parameter("tint", fog_tint)
		_fog_rects.append(rect)


func _build_rays() -> void:
	_ray_layer = _make_layer(2)
	_ray_rect = _make_rect(RAY_SHADER, _ray_layer)
	var mat := _ray_rect.material as ShaderMaterial
	mat.set_shader_parameter("origin", ray_origin)


func _light_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.35, 0.35, 0.35, 1), Color(0, 0, 0, 1)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 256
	t.height = 256
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


func _build_lighting() -> void:
	if use_canvas_modulate:
		_canvas_mod = CanvasModulate.new()
		_canvas_mod.color = Color(0.80, 0.83, 0.95)
		add_child(_canvas_mod)
	if use_player_light:
		_light = PointLight2D.new()
		_light.texture = _light_texture()
		_light.texture_scale = 1.7
		_light.energy = 0.40
		_light.color = Color(1.0, 0.86, 0.64)
		add_child(_light)
	_vig_layer = _make_layer(4)
	_vig_rect = _make_rect(VIGNETTE_SHADER, _vig_layer)
	_soft_rect = _make_rect(SOFT_LIGHT_SHADER, _vig_layer)


func refresh() -> void:
	if not _built:
		return
	var q := clampi(GameSettings.render_map_index, 0, 2)

	_fog_layer.visible = GameSettings.fog
	var use_layers: Array = FOG_LAYERS_BY_RENDER[q]
	for i in _fog_rects.size():
		_fog_rects[i].visible = i in use_layers

	var soft := GameSettings.soft_lighting
	_ray_layer.visible = GameSettings.godrays and GameSettings.godray_strength > 0.01
	var rm := _ray_rect.material as ShaderMaterial
	_base_ray = RAY_POWER_BY_RENDER[q] * (1.25 if soft else 1.0) * GameSettings.godray_strength
	rm.set_shader_parameter("intensity", _base_ray)
	rm.set_shader_parameter("soft", 1.0 if soft else 0.0)
	_vig_layer.visible = soft
	if _canvas_mod != null:
		_canvas_mod.visible = soft
	if _light != null:
		_light.visible = soft
	if effects_off:
		_fog_layer.visible = false
		_ray_layer.visible = false
		_vig_layer.visible = false
		if _canvas_mod != null:
			_canvas_mod.visible = false
		if _light != null:
			_light.visible = false


func _process(_delta: float) -> void:
	if not _built or _cam == null:
		return
	var c := _cam.get_screen_center_position()
	var v := _view_world_size()

	for r in _fog_rects:
		if day_night != null:
			var b: float = clampf(day_night.brightness * day_night.brightness * 1.2, 0.0, 1.0)
			r.modulate = Color(b, b, b, 1.0)
		if r.visible and _fog_layer.visible:
			var mat := r.material as ShaderMaterial
			mat.set_shader_parameter("cam_pos", c)
			mat.set_shader_parameter("view_size", v)

	if _ray_layer.visible:
		var size := get_viewport().get_visible_rect().size
		var rm := _ray_rect.material as ShaderMaterial
		rm.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
		if day_night != null:
			var lp: Vector2 = DayNightScript.light_pos()
			rm.set_shader_parameter("origin", lp)
			rm.set_shader_parameter("intensity", _base_ray * day_night.ray_mult)
			rm.set_shader_parameter("tint", day_night.ray_color)

	if _light != null and _light.visible:
		var base := _target.global_position + Vector2(18, -26) if _target != null else c
		_light.global_position = base
