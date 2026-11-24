extends CanvasLayer

const FRAME_COUNT := 16
const DIR := "res://assets/fx/wind/wind_%02d.png"

var _tex: Array = []
var _ctl: Control
var _gusts: Array = []
var _spawn_t := 1.0


func _ready() -> void:
	layer = 5
	for i in range(1, FRAME_COUNT + 1):
		var t := load(DIR % i) as Texture2D
		if t != null:
			_tex.append(t)
	_ctl = Control.new()
	_ctl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ctl.draw.connect(_draw_gusts)
	add_child(_ctl)
	GameSettings.graphics_changed.connect(_apply)
	_apply()


func _apply() -> void:
	var on := GameSettings.wind and _tex.size() == FRAME_COUNT
	visible = on
	set_process(on)
	if not on:
		_gusts.clear()


func _cam() -> Dictionary:
	var vs := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return {"center": vs * 0.5, "zoom": 1.0, "vs": vs}
	return {"center": cam.get_screen_center_position(), "zoom": maxf(cam.zoom.x, 0.01), "vs": vs}


func _process(delta: float) -> void:
	var c := _cam()
	var vs: Vector2 = c.vs
	var zoom: float = c.zoom
	var center: Vector2 = c.center
	var view := vs / zoom
	var max_n := 2 if GameSettings.perf_index == 3 else 4
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(0.6, 1.8)
		if _gusts.size() < max_n:
			_gusts.append({
				"x": center.x + randf_range(-0.6, 0.3) * view.x,
				"y": center.y + randf_range(-0.38, 0.30) * view.y,
				"t": 0.0,
				"fps": randf_range(9.0, 13.0),
				"sc": randf_range(0.85, 1.2),
				"vx": randf_range(18.0, 42.0),
			})
	for g in _gusts:
		g.t += delta
		g.x += g.vx * delta
	_gusts = _gusts.filter(func(g): return int(g.t * g.fps) < FRAME_COUNT and absf(g.x - center.x) < view.x * 1.4)
	_ctl.queue_redraw()


func _draw_gusts() -> void:
	if _tex.is_empty():
		return
	var c := _cam()
	var vs: Vector2 = c.vs
	var zoom: float = c.zoom
	var center: Vector2 = c.center
	for g in _gusts:
		var fi := mini(int(g.t * g.fps), FRAME_COUNT - 1)
		var tex: Texture2D = _tex[fi]
		var life := clampf(float(fi) / float(FRAME_COUNT - 1), 0.0, 1.0)
		var a := minf(sin(life * PI) * 1.1, 1.0) * 0.8
		var s: float = float(g.sc) * vs.x * 0.07 / float(tex.get_width())
		var sz := Vector2(tex.get_width(), tex.get_height()) * s
		var pos := (Vector2(g.x, g.y) - center) * zoom + vs * 0.5
		_ctl.draw_texture_rect(tex, Rect2(pos, sz), false, Color(1, 1, 1, a))
