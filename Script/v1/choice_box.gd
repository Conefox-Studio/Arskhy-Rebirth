extends CanvasLayer

signal chosen(index: int)
const FONT := "res://assets/fonts/pixelify_sans_bold.ttf"
var _buttons: Array = []
var _sel := 0
var _root: Control
var _active := false
var _lock := 0.0


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_PAUSABLE


func ask(options: Array) -> int:
	_clear()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rows.offset_left = 80.0
	rows.offset_right = -80.0
	rows.offset_bottom = -190.0
	rows.offset_top = -190.0 - 52.0 * float(ceili(options.size() / 3.0))
	rows.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(rows)
	var f := load(FONT) as Font
	var row: HBoxContainer = null
	for i in options.size():
		if i % 3 == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_child(row)
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, String(options[i])]
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		if f != null:
			b.add_theme_font_override("font", f)
		b.add_theme_font_size_override("font_size", 22)
		var idx := i
		b.pressed.connect(func(): _pick(idx))
		b.mouse_entered.connect(func(): _select(idx))
		row.add_child(b)
		_buttons.append(b)
	_sel = 0
	_lock = 0.25
	_select(0)
	_active = true
	var r: int = await chosen
	return r


func _clear() -> void:
	_active = false
	_buttons.clear()
	if _root != null:
		_root.queue_free()
		_root = null


func _select(i: int) -> void:
	_sel = i
	for k in _buttons.size():
		(_buttons[k] as Button).modulate = Color(1.0, 0.92, 0.55) if k == i else Color(0.85, 0.85, 0.95)


func _pick(i: int) -> void:
	if not _active or _lock > 0.0:
		return
	_active = false
	AudioManager.play_ui("select")
	_clear()
	chosen.emit(i)


func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta


func _input(event: InputEvent) -> void:
	if not _active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var n := _buttons.size()
	var k: int = event.physical_keycode
	if k >= KEY_1 and k < KEY_1 + n:
		_pick(k - KEY_1)
	elif k == KEY_UP or k == KEY_W or k == KEY_LEFT or k == KEY_A:
		_select(posmod(_sel - 1, n))
		AudioManager.play_ui("move")
	elif k == KEY_DOWN or k == KEY_S or k == KEY_RIGHT or k == KEY_D:
		_select(posmod(_sel + 1, n))
		AudioManager.play_ui("move")
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_Z:
		_pick(_sel)
	else:
		return
	get_viewport().set_input_as_handled()
