extends CanvasLayer

signal finished
signal page_started(index: int)

const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const GOLD := Color("f6d776")
const INPUT_LOCK := 0.35

var active := false

var _box: PanelContainer
var _name: Label
var _text: Label
var _hint: Label
var _lines: Array = []
var _page := -1
var _typing := false
var _progress := 0.0
var _last_blip := 0
var _lock := 0.0
var _seen_touch := false
var _blink: Tween
var _hold := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build()


func _build() -> void:
	var font: Font = load(FONT_UI)
	var bold: Font = load(FONT_BOLD)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.08, GameSettings.box_opacity())
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 16
	sb.content_margin_bottom = 12
	_box.add_theme_stylebox_override("panel", sb)
	root.add_child(_box)
	_box.modulate.a = 0.0

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	_box.add_child(v)

	_name = Label.new()
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.add_theme_font_override("font", bold)
	_name.add_theme_font_size_override("font_size", 24)
	_name.add_theme_color_override("font_color", GOLD)
	v.add_child(_name)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", font)
	_text.add_theme_font_size_override("font_size", GameSettings.text_size())
	_text.add_theme_color_override("font_color", Color("e9e4fa"))
	_text.add_theme_constant_override("line_spacing", 6)
	v.add_child(_text)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", bold)
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", GOLD)
	_hint.modulate.a = 0.0
	v.add_child(_hint)
	_layout()


func _layout() -> void:
	var h := 150.0
	match GameSettings.text_size_index:
		0: h = 130.0
		2: h = 190.0
	if DeviceMode.is_touch():
		_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_box.offset_left = 120
		_box.offset_right = -120
		_box.offset_top = 20
		_box.offset_bottom = 20.0 + h
	else:
		_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_box.offset_left = 80
		_box.offset_right = -80
		_box.offset_top = -(36.0 + h)
		_box.offset_bottom = -36.0
	match DeviceMode.mode:
		DeviceMode.Mode.TOUCH: _hint.text = "Ketuk  >"
		DeviceMode.Mode.CONTROLLER: _hint.text = "A  >"
		_: _hint.text = "Enter  >"


func open(speaker: String, lines: Array, hold := false) -> void:
	_hold = hold
	if lines.is_empty():
		finished.emit()
		return
	_lines = lines
	_page = -1
	active = true
	_lock = INPUT_LOCK
	_name.text = speaker
	_name.visible = speaker != ""
	_layout()
	create_tween().tween_property(_box, "modulate:a", 1.0, 0.25)
	if _blink:
		_blink.kill()
	_blink = create_tween().set_loops()
	_blink.tween_property(_hint, "self_modulate:a", 0.3, 0.5)
	_blink.tween_property(_hint, "self_modulate:a", 1.0, 0.5)
	_next_page()


func _next_page() -> void:
	_page += 1
	if _page >= _lines.size():
		_close()
		return
	_text.text = String(_lines[_page])
	page_started.emit(_page)
	_progress = 0.0
	_last_blip = 0
	_hint.modulate.a = 0.0
	if GameSettings.text_speed_cps() <= 0.0:
		_text.visible_characters = -1
		_typing = false
		_hint.modulate.a = 1.0
		_check_hold_done.call_deferred()
		return
	_text.visible_characters = 0
	_typing = true


func _check_hold_done() -> void:
	if _hold and active and _page >= _lines.size() - 1 and not _typing:
		active = false
		if _blink:
			_blink.kill()
		_hint.modulate.a = 0.0
		finished.emit()


func release() -> void:
	_hold = false
	create_tween().tween_property(_box, "modulate:a", 0.0, 0.25)


func _close() -> void:
	active = false
	_typing = false
	if _blink:
		_blink.kill()
	var t := create_tween()
	t.tween_property(_box, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): finished.emit())


func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta
	if not _typing:
		return
	_progress += delta * GameSettings.text_speed_cps()
	var n := mini(int(_progress), _text.text.length())
	_text.visible_characters = n
	if n - _last_blip >= 3:
		_last_blip = n
		if GameSettings.typing_sound:
			AudioManager.play_ui("type")
	if n >= _text.text.length():
		_typing = false
		_hint.modulate.a = 1.0
		_check_hold_done()


func _input(event: InputEvent) -> void:
	if not active or _lock > 0.0:
		return
	var adv := false
	if event is InputEventScreenTouch:
		_seen_touch = true
		adv = event.pressed
	elif event is InputEventMouseButton:
		adv = event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _seen_touch
	elif event is InputEventKey or event is InputEventJoypadButton:
		adv = event.pressed and not event.is_echo() and (event.is_action_pressed("ui_accept") \
				or event.is_action_pressed("jump") or event.is_action_pressed("attack"))
	if not adv:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_progress = _text.text.length()
	else:
		_next_page()
