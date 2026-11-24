extends Control

signal chosen(slot: int)
signal closed

const PixelItem = preload("res://scripts/menu_item.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const GOLD := Color("f6d776")
const MUTED := Color("8b86a8")

var mode := "save"
var _rows: VBoxContainer
var _title: Label
var _hint: Label
var _items: Array = []
var _armed := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var sb: StyleBox = UiSkin.box("panel_ornate", 22, 0.0)
	sb.content_margin_left = 56
	sb.content_margin_right = 56
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", load(FONT_TITLE))
	_title.add_theme_font_size_override("font_size", 38)
	_title.add_theme_color_override("font_color", GOLD)
	v.add_child(_title)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size.x = 760
	_rows.add_theme_constant_override("separation", 4)
	v.add_child(_rows)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", load(FONT_UI))
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", MUTED)
	_hint.custom_minimum_size.y = 28
	v.add_child(_hint)
	visible = false


func open(m: String) -> void:
	mode = m
	_armed = -1
	_title.text = "SAVE TO SLOT" if mode == "save" else "LOAD FROM SLOT"
	_hint.text = GameState.saves_left_text() if mode == "save" else "Choose the save to continue from."
	for c in _rows.get_children():
		c.queue_free()
	_items.clear()
	var first: Control = null
	for info in GameState.all_slot_infos():
		var it: Control = PixelItem.new()
		it.title = GameState.slot_line(info)
		it.kind = PixelItem.Kind.BUTTON
		it.item_font = load(FONT_UI)
		it.font_size = 24
		_rows.add_child(it)
		var empty: bool = bool(info.get("empty", false))
		if mode == "load" and empty:
			it.modulate = Color(1, 1, 1, 0.45)
			it.focus_mode = Control.FOCUS_NONE
			continue
		var slot: int = int(info.slot)
		it.activated.connect(func(): _on_row(slot, empty))
		it.focus_entered.connect(func():
			if _armed != slot:
				_armed = -1
				if mode == "save":
					_hint.text = GameState.saves_left_text())
		_items.append(it)
		if first == null:
			first = it
	var back: Control = PixelItem.new()
	back.title = "Back"
	back.kind = PixelItem.Kind.BUTTON
	back.item_font = load(FONT_UI)
	back.font_size = 26
	_rows.add_child(back)
	back.activated.connect(close)
	_items.append(back)
	var n := _items.size()
	for i in n:
		var it2: Control = _items[i]
		it2.focus_neighbor_top = it2.get_path_to(_items[(i - 1 + n) % n])
		it2.focus_neighbor_bottom = it2.get_path_to(_items[(i + 1) % n])
		it2.focus_neighbor_left = it2.get_path_to(it2)
		it2.focus_neighbor_right = it2.get_path_to(it2)
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	var target: Control = first if first != null else back
	target.silent_focus = true
	target.grab_focus.call_deferred()


func close() -> void:
	if not visible:
		return
	hide()
	AudioManager.play_ui("back")
	closed.emit()


func _on_row(slot: int, empty: bool) -> void:
	if mode == "save" and not empty and _armed != slot:
		_armed = slot
		_hint.text = "Slot %d already has a save. Select it again to overwrite." % slot
		AudioManager.play_ui("move")
		return
	chosen.emit(slot)
