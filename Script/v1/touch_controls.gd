extends CanvasLayer

const FONT := "res://assets/fonts/pixelify_sans_bold.ttf"
const MagicFxName = preload("res://scripts/magic_fx.gd")
const BTN_RING := preload("res://assets/ui/touch/btn_ring.png")

const BUTTONS := [
	{"label": "LEFT", "action": "move_left", "side": "L", "off": Vector2(44, -74), "r": 42.0, "icon": "left", "dpad": true},
	{"label": "RIGHT", "action": "move_right", "side": "L", "off": Vector2(198, -74), "r": 42.0, "icon": "right", "dpad": true},
	{"label": "UP", "action": "td_up", "side": "L", "off": Vector2(121, -172), "r": 42.0, "icon": "up", "dpad": true},
	{"label": "DOWN", "action": "move_down", "side": "L", "off": Vector2(121, -74), "r": 34.0, "icon": "down", "dpad": true},
	{"label": "JUMP", "action": "jump", "side": "R", "off": Vector2(-206, -170), "r": 42.0, "icon": "", "dpad": false},
	{"label": "HIT", "action": "attack", "side": "R", "off": Vector2(-96, -84), "r": 50.0, "icon": "", "dpad": false},
	{"label": "DASH", "action": "dash", "side": "R", "off": Vector2(-206, -70), "r": 38.0, "icon": "", "dpad": false},
	{"label": "MAGIC", "action": "magic_cast", "side": "R", "off": Vector2(-100, -192), "r": 38.0, "icon": "", "dpad": false},
	{"label": "ITEM", "action": "use_quick", "side": "R", "off": Vector2(-292, -118), "r": 28.0, "icon": "", "dpad": false},
	{"label": "RAGE", "action": "range_mode", "side": "R", "off": Vector2(-292, -208), "r": 28.0, "icon": "", "dpad": false},
	{"label": "M<", "action": "magic_prev", "side": "R", "off": Vector2(-60, -262), "r": 24.0, "icon": "", "dpad": false},
	{"label": "M>", "action": "magic_next", "side": "R", "off": Vector2(-148, -262), "r": 24.0, "icon": "", "dpad": false},
]
const TOP_BUTTONS := [
	{"label": "II", "action": "ui_cancel", "side": "T", "off": Vector2(-44, 44), "r": 26.0, "icon": "", "dpad": false},
	{"label": "BAG", "action": "inventory", "side": "T", "off": Vector2(-44, 108), "r": 26.0, "icon": "", "dpad": false},
]
const STICK_R := 78.0
const RUN_HOLD := 0.22

var _root: Control
var _font: Font
var _touch_btn := {}
var _dash_hold := {}
var _run_on := false
var _held := {}
var suspended := false
var _seen_touch := false
const MOUSE_IDX := 99


static func base_pos(b: Dictionary, s: Vector2) -> Vector2:
	var o: Vector2 = b.off
	match String(b.side):
		"L":
			return Vector2(o.x, s.y + o.y)
		"T":
			return Vector2(s.x + o.x, o.y)
	return Vector2(s.x + o.x, s.y + o.y)


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_all)
	add_child(_root)
	DeviceMode.mode_changed.connect(func(_m): _apply())
	_apply()


func _want_visible() -> bool:
	return DeviceMode.is_touch() and not get_tree().paused and not suspended and not Inventory.ui_open


func _apply() -> void:
	visible = _want_visible()
	if not visible:
		_release_all()


func _release_all() -> void:
	_dash_hold.clear()
	if _run_on:
		_run_on = false
		_action("run_hold", false, 0.0)
	for a in _held.keys():
		_action(a, false, 0.0)
	_held.clear()
	_touch_btn.clear()


func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _btn_pos(b: Dictionary) -> Vector2:
	var d: Vector2 = GameSettings.touch_layout.get(b.label, Vector2.ZERO)
	return base_pos(b, _size()) + d


func _r(b: Dictionary) -> float:
	return float(b.r) * (1.0 if (b.action in ["ui_cancel", "inventory"]) else GameSettings.touch_scale())


func _process(delta: float) -> void:
	for k in _dash_hold.keys():
		_dash_hold[k] += delta
		if _dash_hold[k] >= RUN_HOLD and not _run_on:
			_run_on = true
			_action("run_hold", true, 1.0)
	var want := _want_visible()
	if want != visible:
		visible = want
		if not visible:
			_release_all()
	if visible:
		_root.queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		_seen_touch = true
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_move(event.index, event.position)
	elif not _seen_touch:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_touch_down(MOUSE_IDX, event.position)
			else:
				_touch_up(MOUSE_IDX)
		elif event is InputEventMouseMotion and _touch_btn.has(MOUSE_IDX):
			_touch_move(MOUSE_IDX, event.position)


func _all_buttons() -> Array:
	return BUTTONS + TOP_BUTTONS


func _hit(pos: Vector2, only_dpad: bool = false, grow: float = 1.3) -> Dictionary:
	var best := {}
	var best_d := 1.0e9
	for b in _all_buttons():
		if only_dpad and not bool(b.dpad):
			continue
		var d := pos.distance_to(_btn_pos(b))
		if d <= _r(b) * grow and d < best_d:
			best = b
			best_d = d
	return best


func _touch_down(idx: int, pos: Vector2) -> void:
	var b := _hit(pos)
	if b.is_empty():
		return
	_bind(idx, b)


func _touch_move(idx: int, pos: Vector2) -> void:
	if not _touch_btn.has(idx):
		return
	var cur: Dictionary = _touch_btn[idx]
	if not bool(cur.dpad):
		return
	var nb := _hit(pos, true, 1.2)
	if nb.is_empty():
		if pos.distance_to(_btn_pos(cur)) > _r(cur) * 2.2:
			_unbind(idx)
		return
	if nb.label != cur.label:
		_unbind(idx)
		_bind(idx, nb)


func _touch_up(idx: int) -> void:
	_unbind(idx)


func _bind(idx: int, b: Dictionary) -> void:
	_touch_btn[idx] = b
	_press(b.action, true)
	if b.action == "dash":
		_dash_hold[idx] = 0.0


func _unbind(idx: int) -> void:
	if not _touch_btn.has(idx):
		return
	var b: Dictionary = _touch_btn[idx]
	_touch_btn.erase(idx)
	if _dash_hold.has(idx):
		_dash_hold.erase(idx)
		if _run_on:
			_run_on = false
			_action("run_hold", false, 0.0)
	_press(b.action, false)


func _press(action: String, down: bool) -> void:
	var n: int = int(_held.get(action, 0))
	if down:
		_held[action] = n + 1
		if n == 0:
			_action(action, true, 1.0)
	else:
		n -= 1
		if n <= 0:
			_held.erase(action)
			_action(action, false, 0.0)
		else:
			_held[action] = n


func _action(action: String, down: bool, strength: float) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = down
	ev.strength = strength if down else 0.0
	Input.parse_input_event(ev)


func _draw_all() -> void:
	for b in BUTTONS:
		_draw_button(b)
	for b in TOP_BUTTONS:
		_draw_button(b)


func _draw_arrow(p: Vector2, r: float, dir: String, col: Color) -> void:
	var s := r * 0.46
	var pts := PackedVector2Array()
	match dir:
		"left":
			pts = PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, -s), p + Vector2(0, -s * 0.45), p + Vector2(s, -s * 0.45), p + Vector2(s, s * 0.45), p + Vector2(0, s * 0.45), p + Vector2(0, s)])
		"right":
			pts = PackedVector2Array([p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(0, s * 0.45), p + Vector2(-s, s * 0.45), p + Vector2(-s, -s * 0.45), p + Vector2(0, -s * 0.45), p + Vector2(0, -s)])
		"down":
			pts = PackedVector2Array([p + Vector2(0, s), p + Vector2(s, 0), p + Vector2(s * 0.45, 0), p + Vector2(s * 0.45, -s), p + Vector2(-s * 0.45, -s), p + Vector2(-s * 0.45, 0), p + Vector2(-s, 0)])
		_:
			pts = PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(s * 0.45, 0), p + Vector2(s * 0.45, s), p + Vector2(-s * 0.45, s), p + Vector2(-s * 0.45, 0), p + Vector2(-s, 0)])
	_root.draw_colored_polygon(pts, col)


func _draw_button(b: Dictionary) -> void:
	var p := _btn_pos(b)
	var r: float = _r(b)
	var down: bool = _held.has(b.action)
	var op := GameSettings.touch_opacity()
	_root.draw_circle(p, r, Color(0.05, 0.05, 0.12, clampf((0.45 if not down else 0.75) * op, 0.0, 1.0)))
	_root.draw_texture_rect(BTN_RING, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, clampf((0.9 if down else 0.55) * op, 0.0, 1.0)))
	var fg := Color(0.96, 0.94, 0.85, clampf(op, 0.0, 1.0))
	if b.action == "magic_cast" and MagicFxName.current_name != "":
		var nm: String = MagicFxName.current_name
		var nw := _font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		_root.draw_string_outline(_font, p + Vector2(-nw * 0.5, -r - 8.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		_root.draw_string(_font, p + Vector2(-nw * 0.5, -r - 8.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.86, 0.78, 1.0, clampf(op, 0.0, 1.0)))
	if String(b.icon) != "":
		_draw_arrow(p, r, String(b.icon), fg)
		return
	var fs := 18 if r >= 40.0 else (14 if r >= 28.0 else 12)
	var w := _font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := p + Vector2(-w * 0.5, fs * 0.35)
	_root.draw_string_outline(_font, pos, b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
	_root.draw_string(_font, pos, b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
