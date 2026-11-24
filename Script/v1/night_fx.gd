extends CanvasLayer

const DayNight = preload("res://scripts/day_night.gd")

var cam: Camera2D
var player: Node2D
var ground_fn: Callable
var x_min := 0.0
var x_max := 3000.0
var use_eyes := true
var use_fireflies := true
var use_aurora := false
var rain := false

var _norm: Control
var _add: Control
var _t := 0.0
var _eyes: Array = []
var _tex_fire: Texture2D
var _tex_eyes: Texture2D
var _tex_rain: Texture2D
var _tex_aur: Texture2D
var _dark := 0.0
var _vis := false


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_tex_fire = load("res://assets/fx/fireflies.png")
	_tex_eyes = load("res://assets/fx/eyes.png")
	_tex_rain = load("res://assets/fx/rain.png")
	_tex_aur = load("res://assets/fx/aurora.png")
	_norm = Control.new()
	_norm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_norm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_norm.draw.connect(_draw_norm)
	add_child(_norm)
	_add = Control.new()
	_add.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = mat
	_add.draw.connect(_draw_add)
	add_child(_add)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	var x := x_min + 220.0
	while x < x_max - 120.0:
		var gy := 0.0
		if ground_fn.is_valid():
			gy = float(ground_fn.call(x))
		_eyes.append({"x": x, "y": gy - rng.randf_range(26.0, 58.0), "ph": rng.randi_range(0, 59), "sp": rng.randf_range(6.0, 11.0)})
		x += rng.randf_range(240.0, 520.0)


func _process(delta: float) -> void:
	_t += delta
	_dark = DayNight.darkness()
	var want := _dark > 0.02
	if want != _vis:
		_vis = want
		_norm.visible = want
		_add.visible = want
	if _vis:
		_norm.queue_redraw()
		_add.queue_redraw()


func _frame(n: int, fps: float, ph: int = 0) -> int:
	return (int(_t * fps) + ph) % n


func _draw_add() -> void:
	var vs := _add.size
	if use_fireflies and _tex_fire != null:
		for k in 3:
			var fw := 143.0
			var fh := 96.0
			var w := vs.x * 0.62
			var h := w * fh / fw
			var cx: float = cam.get_screen_center_position().x if cam != null else 0.0
			var px := fposmod(k * vs.x * 0.45 - cx * (0.25 + 0.1 * k) + sin(_t * 0.4 + k) * 24.0, vs.x * 1.3) - w * 0.4
			var py := vs.y * (0.50 + 0.12 * k) + sin(_t * 0.6 + k * 2.0) * 14.0
			var i := _frame(40, 10.0, k * 13)
			var src := Rect2((i % 8) * fw, (i / 8) * fh, fw, fh)
			_add.draw_texture_rect_region(_tex_fire, Rect2(px, py, w, h), src, Color(1, 1, 1, 0.85 * _dark))
	if use_aurora and _tex_aur != null:
		var aw := vs.x
		var ah := vs.y * 0.40
		var j := _frame(30, 9.0)
		_add.draw_texture_rect_region(_tex_aur, Rect2(0, vs.y * 0.01, aw, ah), Rect2((j % 6) * 238.0, (j / 6) * 168.0 + 30.0, 238, 104), Color(1, 1, 1, 0.34 * _dark))


func _draw_norm() -> void:
	var vs := _norm.size
	if use_eyes and _tex_eyes != null:
		var xf := get_viewport().get_canvas_transform()
		var z: float = xf.get_scale().x
		var fw := 242.0
		var fh := 127.0
		for e in _eyes:
			var sp: Vector2 = xf * Vector2(e.x, e.y)
			var w := fw * 0.5 * z
			var h := fh * 0.5 * z
			if sp.x < -w or sp.x > vs.x + w or sp.y < -h or sp.y > vs.y + h:
				continue
			var i := _frame(60, float(e.sp), int(e.ph))
			var src := Rect2((i % 11) * fw, (i / 11) * fh, fw, fh)
			_norm.draw_texture_rect_region(_tex_eyes, Rect2(sp.x - w * 0.5, sp.y - h * 0.5, w, h), src, Color(1, 1, 1, 0.95 * _dark))
	if rain and _tex_rain != null:
		var r := _frame(22, 14.0)
		_norm.draw_texture_rect_region(_tex_rain, Rect2(0, 0, vs.x, vs.y), Rect2((r % 6) * 374.0, (r / 6) * 224.0, 374, 224), Color(0.66, 0.76, 1.0, 0.6))
