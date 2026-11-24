extends CanvasLayer

var _ctl: Control
var _motes: Array = []
var _target := 6
var _retarget_t := 4.0


func _ready() -> void:
	layer = 5
	_ctl = Control.new()
	_ctl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ctl.draw.connect(_draw_motes)
	add_child(_ctl)


func _cam() -> Dictionary:
	var vs := get_viewport().get_visible_rect().size
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return {"center": vs * 0.5, "zoom": 1.0, "vs": vs}
	return {"center": cam.get_screen_center_position(), "zoom": maxf(cam.zoom.x, 0.01), "vs": vs}


func _process(delta: float) -> void:
	var c := _cam()
	var view: Vector2 = c.vs / float(c.zoom)
	var center: Vector2 = c.center
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = randf_range(3.0, 6.0)
		_target = randi_range(4, 8)
	if _motes.size() < _target:
		_motes.append({
			"x": center.x + randf_range(-0.5, 0.5) * view.x,
			"y": center.y + view.y * 0.5 + randf_range(0.0, 20.0),
			"v": randf_range(12.0, 26.0),
			"ph": randf() * TAU,
			"t": 0.0,
		})
	for m in _motes:
		m.t += delta
		m.y -= m.v * delta
		m.x += sin(m.t * 1.6 + m.ph) * 4.0 * delta
	_motes = _motes.filter(func(m): return m.y > center.y - view.y * 0.5 - 4.0 and absf(m.x - center.x) < view.x * 0.75)
	_ctl.queue_redraw()


func _draw_motes() -> void:
	var c := _cam()
	var z: float = c.zoom
	var vs: Vector2 = c.vs
	for m in _motes:
		var pos := (Vector2(m.x, m.y) - (c.center as Vector2)) * z + vs * 0.5
		var a := clampf(float(m.t) / 0.8, 0.0, 1.0) * 0.9
		_ctl.draw_rect(Rect2(pos.floor(), Vector2(z, z)), Color(0.42, 1.0, 0.36, a))
