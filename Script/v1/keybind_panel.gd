extends Control

signal closed

const Keybinds = preload("res://scripts/keybinds.gd")
const PlayerScript = preload("res://scripts/player.gd")
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const GOLD := Color("f6d776")

var _font: Font
var _bold: Font
var _cells := {}
var _capture := {}
var _hint: Label
var _first: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_UI)
	_bold = load(FONT_BOLD)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.12, 0.98)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(_label("KEYBINDS", _bold, 34, GOLD, true))
	_hint = _label("Select a box, then press the new key / gamepad button.  Esc = cancel", _font, 17, Color(0.7, 0.75, 0.9), true)
	v.add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	grid.add_child(_label("Action", _bold, 20, Color("6f8fd8"), false))
	grid.add_child(_label("Keyboard", _bold, 20, Color("6f8fd8"), true))
	grid.add_child(_label("Gamepad", _bold, 20, Color("6f8fd8"), true))
	for d in Keybinds.ACTIONS:
		var a: String = d["a"]
		var name_l := _label(String(d["label"]), _font, 22, Color(0.92, 0.92, 0.98), false)
		name_l.custom_minimum_size.x = 230
		grid.add_child(name_l)
		for t in ["k", "p"]:
			var b := Button.new()
			b.custom_minimum_size = Vector2(190, 34)
			_style_button(b)
			b.pressed.connect(_begin.bind(a, t))
			grid.add_child(b)
			_cells["%s|%s" % [a, t]] = b
			if _first == null:
				_first = b

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	v.add_child(row)
	var reset_b := Button.new()
	reset_b.text = "Reset Keybinds"
	reset_b.custom_minimum_size = Vector2(230, 38)
	_style_button(reset_b)
	reset_b.pressed.connect(_reset)
	row.add_child(reset_b)
	var back_b := Button.new()
	back_b.text = "Back"
	back_b.custom_minimum_size = Vector2(150, 38)
	_style_button(back_b)
	back_b.pressed.connect(close)
	row.add_child(back_b)


func _label(text: String, font: Font, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _style_button(b: Button) -> void:
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 20)
	var states := {"normal": Color(0.12, 0.13, 0.26), "hover": Color(0.2, 0.22, 0.42),
		"pressed": Color(0.3, 0.3, 0.55), "focus": Color(0.2, 0.22, 0.42)}
	for s in states:
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[s]
		sb.set_corner_radius_all(4)
		if s == "focus":
			sb.border_color = GOLD
			sb.set_border_width_all(2)
		b.add_theme_stylebox_override(s, sb)


func open() -> void:
	PlayerScript.ensure_actions()
	Keybinds.apply_all(GameSettings.bindings)
	_refresh()
	_end_capture()
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	if _first != null:
		_first.grab_focus()


func close() -> void:
	if not visible:
		return
	_end_capture()
	GameSettings.save_settings()
	GameSettings.apply_controls()
	hide()
	closed.emit()


func _refresh() -> void:
	for d in Keybinds.ACTIONS:
		var a: String = d["a"]
		(_cells["%s|k" % a] as Button).text = Keybinds.key_text(Keybinds.key_of(a))
		(_cells["%s|p" % a] as Button).text = Keybinds.pad_text(Keybinds.pad_of(a))


func _begin(a: String, t: String) -> void:
	_end_capture()
	_capture = {"a": a, "t": t, "t0": Time.get_ticks_msec()}
	(_cells["%s|%s" % [a, t]] as Button).text = "press key..." if t == "k" else "press button..."
	_hint.text = "Press a keyboard key  (Esc = cancel)" if t == "k" else "Press a gamepad button or trigger  (Esc = cancel)"


func _end_capture() -> void:
	_capture = {}
	if _hint != null:
		_hint.text = "Select a box, then press the new key / gamepad button.  Esc = cancel"
	if not _cells.is_empty():
		_refresh()


func _reset() -> void:
	GameSettings.bindings = {}
	Keybinds.apply_all(GameSettings.bindings)
	_end_capture()
	AudioManager.play_ui("select")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not _capture.is_empty():
		var t: String = _capture["t"]
		var a: String = _capture["a"]
		if Time.get_ticks_msec() - int(_capture["t0"]) < 180:
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode == KEY_ESCAPE:
				_end_capture()
			elif t == "k":
				_assign(a, "k", int(event.physical_keycode))
			return
		if t == "p":
			if event is InputEventJoypadButton and event.pressed:
				get_viewport().set_input_as_handled()
				_assign(a, "p", ["b", int(event.button_index)])
			elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.7:
				get_viewport().set_input_as_handled()
				_assign(a, "p", ["a", int(event.axis), signf(event.axis_value)])
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _assign(a: String, t: String, val) -> void:
	var mine_k := Keybinds.key_of(a)
	var mine_p := Keybinds.pad_of(a)
	for d in Keybinds.ACTIONS:
		var o: String = d["a"]
		if o == a:
			continue
		var ob: Dictionary = (GameSettings.bindings.get(o, {}) as Dictionary).duplicate()
		if t == "k" and Keybinds.key_of(o) == int(val):
			ob["k"] = mine_k
			GameSettings.bindings[o] = ob
		elif t == "p" and Keybinds.pad_of(o) == val:
			if mine_p.is_empty():
				ob["p"] = ["b", -1]
			else:
				ob["p"] = mine_p
			GameSettings.bindings[o] = ob
	var b: Dictionary = (GameSettings.bindings.get(a, {}) as Dictionary).duplicate()
	b[t] = val
	GameSettings.bindings[a] = b
	Keybinds.apply_all(GameSettings.bindings)
	AudioManager.play_ui("select")
	_end_capture()
