extends CanvasLayer

const SHADER_CODE := """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float bloom = 0.0;
uniform float grain = 0.0;
uniform float aberration = 0.0;
uniform float time_s = 0.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 col;
	if (aberration > 0.0) {
		vec2 off = (uv - vec2(0.5)) * 0.006;
		col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	if (bloom > 0.0) {
		vec3 acc = vec3(0.0);
		float tw = 0.0;
		for (int i = -2; i <= 2; i++) {
			for (int j = -2; j <= 2; j++) {
				vec2 o = vec2(float(i), float(j)) * px * 5.0;
				vec3 s = textureLod(screen_tex, uv + o, 1.5).rgb;
				float w = exp(-float(i * i + j * j) * 0.3);
				acc += s * smoothstep(0.55, 0.95, luma(s)) * w;
				tw += w;
			}
		}
		col += (acc / tw) * bloom * 0.9;
	}
	if (grain > 0.0) {
		float n = fract(sin(dot(uv * vec2(1920.0, 1080.0) + vec2(time_s * 37.0, time_s * 91.0), vec2(12.9898, 78.233))) * 43758.5453);
		col += (n - 0.5) * grain * 0.07;
	}
	COLOR = vec4(col, 1.0);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	layer = 6
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	GameSettings.graphics_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var on := GameSettings.bloom or GameSettings.film_grain or GameSettings.chromatic
	visible = on
	set_process(on)
	_mat.set_shader_parameter("bloom", 1.0 if GameSettings.bloom else 0.0)
	_mat.set_shader_parameter("grain", 1.0 if GameSettings.film_grain else 0.0)
	_mat.set_shader_parameter("aberration", 1.0 if GameSettings.chromatic else 0.0)


func _process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("time_s", fmod(_t, 100.0))
