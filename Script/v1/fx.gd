extends RefCounted


static func soft_circle(px: int = 64) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


static func shadow_params(mode: int) -> Dictionary:
	if mode >= 2:
		return {"lean": 0.9, "squash": 0.5, "alpha": 0.42, "soft_alpha": 0.2, "soft_grow": 1.2}
	if mode == 1:
		return {"lean": 0.6, "squash": 0.4, "alpha": 0.5, "soft_alpha": 0.0, "soft_grow": 1.0}
	return {}


static func shadow_transform(yb: float, lean: float, squash: float) -> Transform2D:
	return Transform2D(Vector2(1.0, 0.0), Vector2(lean, -squash), Vector2(-lean * yb, yb * (1.0 + squash)))


static func ground_drop(space: PhysicsDirectSpaceState2D, from: Vector2, mask: int, exclude: Array = [], max_dist: float = 520.0) -> float:
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, max_dist), mask)
	q.exclude = exclude
	var r := space.intersect_ray(q)
	if r.is_empty():
		return -1.0
	return maxf(0.0, r.position.y - from.y)


static func shadow_height_fade(height: float) -> Vector2:
	return Vector2(clampf(1.0 - height / 220.0, 0.5, 1.0), clampf(1.0 - height / 170.0, 0.15, 1.0))


static func fog(extent: Vector2, amount: int = 14, tint: Color = Color(0.72, 0.72, 0.82, 0.10)) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = soft_circle(128)
	p.amount = amount
	p.lifetime = 24.0
	p.preprocess = 24.0
	p.randomness = 1.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extent
	p.direction = Vector2(1, 0)
	p.spread = 8.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 12.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = tint
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	ramp.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	return p


static var _shadow_shader: Shader


static func shadow_blur(mode: int) -> Vector2:
	if mode <= 0 or not GameSettings.shadow_shader:
		return Vector2.ZERO
	return Vector2(0.4, 2.6) if mode >= 2 else Vector2(0.3, 1.7)


static func shadow_material(base_y: float, fade_h: float, min_a: float = 0.18) -> ShaderMaterial:
	if _shadow_shader == null:
		_shadow_shader = Shader.new()
		_shadow_shader.code = """shader_type canvas_item;
uniform float base_y = 0.0;
uniform float fade_h = 120.0;
uniform float min_a = 0.18;
uniform float clip_min = -1000000.0;
uniform float clip_max = 1000000.0;
// Blur penumbra (teknik Gaussian blur, diadaptasi dari 3d-game-shaders-for-beginners): tajam di dekat kaki,
// makin lembut makin jauh dari titik pijak. Radius dalam texel; 0 = mati.
uniform float blur_near = 0.0;
uniform float blur_far = 0.0;
varying float dist;
varying float wx;
varying vec4 vcol;
void vertex() { dist = base_y - VERTEX.y; wx = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).x; vcol = COLOR; }
void fragment() {
	if (wx < clip_min || wx > clip_max) { discard; }
	float k = clamp(dist / fade_h, 0.0, 1.0);
	float r = mix(blur_near, blur_far, k);
	if (r > 0.01) {
		vec2 s = TEXTURE_PIXEL_SIZE * r;
		float c = texture(TEXTURE, UV).a;
		float acc = c * 0.25;
		acc += (texture(TEXTURE, UV + vec2(s.x, 0.0)).a + texture(TEXTURE, UV - vec2(s.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, s.y)).a + texture(TEXTURE, UV - vec2(0.0, s.y)).a) * 0.125;
		acc += (texture(TEXTURE, UV + s).a + texture(TEXTURE, UV - s).a
			+ texture(TEXTURE, UV + vec2(s.x, -s.y)).a + texture(TEXTURE, UV + vec2(-s.x, s.y)).a) * 0.0625;
		float m = c > 0.05 ? COLOR.a / c : vcol.a;      // alpha modulate (siluet hitam transparan)
		COLOR = vec4(vcol.rgb, acc * m);
	}
	COLOR.a *= mix(1.0, min_a, k);
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shadow_shader
	m.set_shader_parameter("base_y", base_y)
	m.set_shader_parameter("fade_h", fade_h)
	m.set_shader_parameter("min_a", min_a)
	return m
