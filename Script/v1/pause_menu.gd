extends CanvasLayer

signal save_slot_chosen(slot: int)
signal load_slot_chosen(slot: int)
signal sleep_requested
signal quit_requested

const UiSkin = preload("res://scripts/ui_skin.gd")
const PixelItem = preload("res://scripts/menu_item.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const SlotPanel = preload("res://scripts/slot_panel.gd")

const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"

const GOLD := Color("f6d776")
const MUTED := Color("8b86a8")

var enabled := true
var _root: Control
var _items: Array = []
var _settings: Control
var _slots: Control
var _toast: Label
var _toast_tween: Tween
var _font_title: Font
var _font_ui: Font
var _font_bold: Font
var _is_open := false
var _last_focus: Control
var _info: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font_title = load(FONT_TITLE)
	_font_ui = load(FONT_UI)
	_font_bold = load(FONT_UI_BOLD)
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb: StyleBox = UiSkin.box("panel_ornate", 22, 0.0)
	sb.content_margin_left = 64
	sb.content_margin_right = 64
	sb.content_margin_top = 40
	sb.content_margin_bottom = 42
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := _label("PAUSED", _font_title, 44, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_ornament(380.0))

	_info = _label("", _font_ui, 20, MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info)

	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 340
	menu.add_theme_constant_override("separation", 6)
	v.add_child(menu)

	var it_resume := _item(menu, "Resume")
	var it_settings := _item(menu, "Settings")
	var it_sleep := _item(menu, "Sleep")
	var it_save := _item(menu, "Save State")
	var it_load := _item(menu, "Load State")
	var it_quit := _item(menu, "Quit to Title")
	it_resume.activated.connect(close)
	it_settings.activated.connect(_open_settings)
	it_sleep.activated.connect(func(): sleep_requested.emit())
	it_save.activated.connect(func(): _open_slots("save"))
	it_load.activated.connect(func(): _open_slots("load"))
	it_quit.activated.connect(_ask_quit)
	_items = [it_resume, it_settings, it_sleep, it_save, it_load, it_quit]
	var n := _items.size()
	for i in n:
		var it: Control = _items[i]
		it.focus_neighbor_top = it.get_path_to(_items[(i - 1 + n) % n])
		it.focus_neighbor_bottom = it.get_path_to(_items[(i + 1) % n])
		it.focus_neighbor_left = it.get_path_to(it)
		it.focus_neighbor_right = it.get_path_to(it)

	_toast = _label("", _font_bold, 22, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.custom_minimum_size.y = 30
	_toast.modulate.a = 0.0
	v.add_child(_toast)

	var hint := _label("Esc: Resume", _font_ui, 18, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)

	_settings = SettingsPanel.new()
	_root.add_child(_settings)
	_settings.closed.connect(_on_settings_closed)
	_slots = SlotPanel.new()
	_root.add_child(_slots)
	_slots.chosen.connect(_on_slot_chosen)
	_slots.closed.connect(_on_settings_closed)


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _item(parent: Control, text: String) -> Control:
	var it: Control = PixelItem.new()
	it.title = text
	it.kind = PixelItem.Kind.BUTTON
	it.item_font = _font_ui
	it.font_size = 30
	parent.add_child(it)
	return it


func _ornament(width: float) -> Control:
	var none := Control.new()
	none.custom_minimum_size = Vector2(0, 8)
	if true:
		return none
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 24)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var y := c.size.y / 2.0
		var cx := c.size.x / 2.0
		var steps := 40
		var span := c.size.x / 2.0 - 22.0
		for i in steps:
			var a := 0.9 * (1.0 - float(i) / steps)
			var d0 := 18.0 + span * i / steps
			var d1 := 18.0 + span * (i + 1) / steps
			c.draw_line(Vector2(cx + d0, y), Vector2(cx + d1, y), Color(GOLD, a), 2.0)
			c.draw_line(Vector2(cx - d0, y), Vector2(cx - d1, y), Color(GOLD, a), 2.0)
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(cx, y - 7), Vector2(cx + 7, y), Vector2(cx, y + 7), Vector2(cx - 7, y)]), GOLD))
	return c


func is_open() -> bool:
	return _is_open


func refresh_info() -> void:
	if _info == null:
		return
	_info.text = "Day %d  -  %s  -  %s" % [GameState.DayNight.day, GameState.difficulty_name(), GameState.saves_left_text()]
	_info.add_theme_color_override("font_color", MUTED if GameState.can_save() else Color("ff8a8a"))


func open() -> void:
	if _is_open or not enabled:
		return
	refresh_info()
	_is_open = true
	get_tree().paused = true
	_root.modulate.a = 0.0
	_root.show()
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.15)
	AudioManager.play_ui("select")
	var first: Control = _items[0]
	first.silent_focus = true
	first.grab_focus()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_root.hide()
	get_tree().paused = false
	AudioManager.play_ui("back")


func _open_settings() -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	for it in _items:
		it.focus_mode = Control.FOCUS_NONE
	_settings.open()


func _open_slots(mode: String) -> void:
	if mode == "save" and not GameState.can_save():
		show_toast("No save slots left!")
		AudioManager.play_ui("error")
		return
	if mode == "load" and not GameState.has_any_save():
		show_toast("No saves yet.")
		AudioManager.play_ui("error")
		return
	_last_focus = get_viewport().gui_get_focus_owner()
	for it in _items:
		it.focus_mode = Control.FOCUS_NONE
	_slots.open(mode)


func _on_slot_chosen(slot: int) -> void:
	var mode: String = _slots.mode
	_slots.hide()
	_on_settings_closed()
	if mode == "save":
		save_slot_chosen.emit(slot)
	else:
		load_slot_chosen.emit(slot)


func _on_settings_closed() -> void:
	for it in _items:
		it.focus_mode = Control.FOCUS_ALL
	var target: Control = _last_focus if _last_focus else _items[0]
	target.silent_focus = true
	target.grab_focus()


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _slots.visible:
		_slots.close()
	elif _settings.visible:
		_settings.close()
	elif _is_open:
		close()
	else:
		open()


var _confirm: Control


func _ask_quit() -> void:
	if _confirm != null:
		return
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.05, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.97)
	sb.border_color = Color("e8c964")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var t := Label.new()
	t.text = "Are You Sure?"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color("e8c964"))
	v.add_child(t)
	var q := Label.new()
	q.text = "Quit to the title screen? Unsaved progress is lost."
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 20)
	v.add_child(q)
	var yes := _item(v, "Yes")
	var no := _item(v, "No")
	yes.activated.connect(func():
		_confirm.queue_free()
		_confirm = null
		quit_requested.emit())
	no.activated.connect(func():
		_confirm.queue_free()
		_confirm = null
		if not _items.is_empty():
			_items[_items.size() - 1].grab_focus())
	yes.focus_neighbor_bottom = yes.get_path_to(no)
	no.focus_neighbor_top = no.get_path_to(yes)
	yes.focus_neighbor_top = yes.get_path_to(no)
	no.focus_neighbor_bottom = no.get_path_to(yes)
	no.grab_focus.call_deferred()
