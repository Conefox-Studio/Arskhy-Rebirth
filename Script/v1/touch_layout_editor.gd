extends CanvasLayer

signal closed

const TouchControls = preload("res://scripts/touch_controls.gd")
const FONT := "res://assets/fonts/pixelify_sans_bold.ttf"

var _root: Control
var _font: Font
var _drag := ""
var _grab := Vector2.ZERO
var _seen_touch := false
var _drag_idx := -2
var _done_rect := Rect2()
var _reset_rect := Rect2()


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_all)
	add_child(_root)
	get_viewport().size_changed.connect(_root.queue_redraw)


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _items() -> Array:
	var s := _size()
	var out: Array = []
	for b in TouchControls.BUTTONS:
		out.append({"label": b.label, "pos": TouchControls.base_pos(b, s), "r": float(b.r)})
	for b in TouchControls.TOP_BUTTONS:
		out.append({"label": b.label, "pos": TouchControls.base_pos(b, s), "r": float(b.r)})
	out.append({"label": "ITEMS", "pos": Vector2(s.x * 0.5, s.y - 37.0), "r": 46.0})
	return out


func _key(label: String) -> String:
	return "BAR" if label == "ITEMS" else label


func _pos_of(it: Dictionary) -> Vector2:
	var d: Vector2 = GameSettings.touch_layout.get(_key(it.label), Vector2.ZERO)
	return it.pos + d


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed("ui_cancel"):
			_finish()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		_seen_touch = true
		if event.pressed:
			_down(event.index, event.position)
		else:
			_up(event.index)
	elif event is InputEventScreenDrag:
		_move(event.index, event.position)
	elif not _seen_touch:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down(-1, event.position)
			else:
				_up(-1)
		elif event is InputEventMouseMotion:
			_move(-1, event.position)
	get_viewport().set_input_as_handled()


func _down(idx: int, pos: Vector2) -> void:
	if _done_rect.has_point(pos):
		_finish()
		return
	if _reset_rect.has_point(pos):
		GameSettings.touch_layout = {}
		_root.queue_redraw()
		return
	var best := ""
	var best_d := 1.0e9
	for it in _items():
		var d := pos.distance_to(_pos_of(it))
		if d <= float(it.r) * 1.3 and d < best_d:
			best = it.label
			best_d = d
			_grab = _pos_of(it) - pos
	if best != "":
		_drag = best
		_drag_idx = idx


func _move(idx: int, pos: Vector2) -> void:
	if _drag == "" or idx != _drag_idx:
		return
	var s := _size()
	for it in _items():
		if it.label == _drag:
			var want: Vector2 = pos + _grab
			want.x = clampf(want.x, 30.0, s.x - 30.0)
			want.y = clampf(want.y, 30.0, s.y - 30.0)
			GameSettings.touch_layout[_key(_drag)] = want - it.pos
	_root.queue_redraw()


func _up(idx: int) -> void:
	if idx == _drag_idx:
		_drag = ""
		_drag_idx = -2


func _finish() -> void:
	GameSettings.save_settings()
	GameSettings.apply_controls()
	hide()
	closed.emit()
	queue_free()


func _draw_all() -> void:
	var s := _size()
	_root.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.0, 0.06, 0.62))
	_text("TOUCH LAYOUT", Vector2(s.x * 0.5, s.y * 0.30), 34, Color("f6d776"))
	_text("Drag any button to move it.  Tap DONE to save.", Vector2(s.x * 0.5, s.y * 0.30 + 34.0), 20, Color(0.85, 0.88, 1.0))
	for it in _items():
		var p := _pos_of(it)
		var r: float = it.r
		var active: bool = it.label == _drag
		if it.label == "ITEMS":
			_root.draw_rect(Rect2(p - Vector2(r + 4.0, 26.0), Vector2((r + 4.0) * 2.0, 52.0)), Color(0.1, 0.3, 0.5, 0.7 if active else 0.5))
		else:
			_root.draw_circle(p, r, Color(0.1, 0.3, 0.5, 0.7 if active else 0.5))
			_root.draw_arc(p, r, 0.0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)
		_text(String(it.label), p + Vector2(0.0, 6.0), 16, Color.WHITE)
	_done_rect = Rect2(Vector2(s.x * 0.5 + 20.0, s.y * 0.30 + 64.0), Vector2(150.0, 44.0))
	_reset_rect = Rect2(Vector2(s.x * 0.5 - 170.0, s.y * 0.30 + 64.0), Vector2(150.0, 44.0))
	_button(_done_rect, "DONE", Color(0.2, 0.5, 0.3, 0.9))
	_button(_reset_rect, "RESET", Color(0.5, 0.25, 0.25, 0.9))


func _button(r: Rect2, label: String, col: Color) -> void:
	_root.draw_rect(r, col)
	_root.draw_rect(r, Color(1, 1, 1, 0.8), false, 2.0)
	_text(label, r.get_center() + Vector2(0.0, 7.0), 22, Color.WHITE)


func _text(t: String, center: Vector2, size: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center - Vector2(w * 0.5, 0.0)
	_root.draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color.BLACK)
	_root.draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
