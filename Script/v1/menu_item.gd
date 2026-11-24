extends Control

signal activated
signal changed

enum Kind { BUTTON, CHOICE, SLIDER }

const GOLD := Color("f6d776")
const IDLE := Color("cfc9ee")
const DIM := Color("625d7c")
const BAR_SEGMENTS := 20
const SEG_W := 10.0
const SEG_GAP := 2.0

var kind: int = Kind.BUTTON
var title := ""
var options: Array[String] = []
var index := 0
var value := 0.5
var step := 0.05
var item_font: Font
var font_size := 30
var disabled := false
var silent_focus := false

var _hbox: HBoxContainer
var _arrow: Label
var _name: Label
var _val: Label
var _bar: Control
var _blink: Tween


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.y = font_size + 16

	_hbox = HBoxContainer.new()
	_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hbox.add_theme_constant_override("separation", 8)
	add_child(_hbox)

	_arrow = _make_label(">")
	_arrow.custom_minimum_size.x = font_size
	_hbox.add_child(_arrow)

	_name = _make_label(title)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.add_child(_name)

	if kind == Kind.SLIDER:
		_bar = Control.new()
		_bar.custom_minimum_size = Vector2(BAR_SEGMENTS * (SEG_W + SEG_GAP) + 6.0, font_size)
		_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.draw.connect(_draw_bar)
		_hbox.add_child(_bar)
		_val = _make_label("")
		_val.custom_minimum_size.x = 84
		_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hbox.add_child(_val)
	elif kind == Kind.CHOICE:
		_val = _make_label("")
		_val.custom_minimum_size.x = 260
		_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hbox.add_child(_val)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(_on_mouse_entered)
	refresh()


func _make_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item_font:
		l.add_theme_font_override("font", item_font)
	l.add_theme_font_size_override("font_size", font_size)
	return l


func set_disabled(d: bool) -> void:
	disabled = d
	focus_mode = Control.FOCUS_NONE if d else Control.FOCUS_ALL
	refresh()


func set_index(i: int) -> void:
	if options.is_empty():
		return
	index = clampi(i, 0, options.size() - 1)
	refresh()


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	refresh()


func refresh() -> void:
	if _name == null:
		return
	var focused := has_focus() and not disabled
	var c: Color = DIM if disabled else (GOLD if focused else IDLE)
	_name.add_theme_color_override("font_color", c)
	_arrow.add_theme_color_override("font_color", GOLD)
	if _blink == null or not _blink.is_valid():
		_arrow.modulate.a = 1.0 if focused else 0.0
	if _val:
		_val.add_theme_color_override("font_color", c)
		if kind == Kind.CHOICE and not options.is_empty():
			_val.text = "< %s >" % options[index]
		elif kind == Kind.SLIDER:
			_val.text = "%d%%" % roundi(value * 100.0)
	if _bar:
		_bar.queue_redraw()


func _on_focus_entered() -> void:
	if silent_focus:
		silent_focus = false
	else:
		AudioManager.play_ui("move")
	if _blink:
		_blink.kill()
	_arrow.modulate.a = 1.0
	_blink = create_tween().set_loops()
	_blink.tween_property(_arrow, "modulate:a", 0.35, 0.45)
	_blink.tween_property(_arrow, "modulate:a", 1.0, 0.45)
	refresh()


func _on_focus_exited() -> void:
	if _blink:
		_blink.kill()
		_blink = null
	_arrow.modulate.a = 0.0
	refresh()


func _on_mouse_entered() -> void:
	if _pressing:
		return
	if not disabled and not has_focus():
		grab_focus()


const DRAG_THRESHOLD := 12.0
var _press_pos := Vector2.ZERO
var _press_scroll := 0
var _pressing := false
var _dragging := false
var _scroll: ScrollContainer


func _find_scroll() -> ScrollContainer:
	var n := get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return null


func _gui_input(event: InputEvent) -> void:
	var left_btn: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var clicked: bool = left_btn and event.pressed
	var released: bool = left_btn and not event.pressed
	var confirm: bool = event.is_action_pressed("ui_accept")
	_scroll = _find_scroll()

	if _scroll != null:
		if clicked:
			_pressing = true
			_dragging = false
			_press_pos = event.global_position
			_press_scroll = _scroll.scroll_vertical
			if kind != Kind.SLIDER:
				accept_event()
				if not disabled:
					grab_focus()
				return
		elif event is InputEventMouseMotion and _pressing and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			var d: Vector2 = event.global_position - _press_pos
			if not _dragging and absf(d.y) > DRAG_THRESHOLD and absf(d.y) > absf(d.x) * (1.0 if kind != Kind.SLIDER else 1.8):
				_dragging = true
			if _dragging:
				accept_event()
				_scroll.scroll_vertical = _press_scroll - int(d.y)
				return
			if kind != Kind.SLIDER:
				accept_event()
				return
		elif released:
			var was_drag := _dragging
			_pressing = false
			_dragging = false
			accept_event()
			if was_drag or disabled:
				return
			if get_global_rect().has_point(event.global_position) and (event.global_position - _press_pos).length() < DRAG_THRESHOLD * 1.5:
				match kind:
					Kind.BUTTON:
						AudioManager.play_ui("select")
						activated.emit()
					Kind.CHOICE:
						_step_choice(1)
			return

	if disabled:
		if clicked or confirm:
			accept_event()
			AudioManager.play_ui("error")
		return

	match kind:
		Kind.BUTTON:
			if (clicked and _scroll == null) or confirm:
				accept_event()
				AudioManager.play_ui("select")
				activated.emit()
		Kind.CHOICE:
			if event.is_action_pressed("ui_left", true):
				accept_event()
				_step_choice(-1)
			elif event.is_action_pressed("ui_right", true):
				accept_event()
				_step_choice(1)
			elif (clicked and _scroll == null) or confirm:
				accept_event()
				_step_choice(1)
		Kind.SLIDER:
			if event.is_action_pressed("ui_left", true):
				accept_event()
				_set_value_user(value - step)
			elif event.is_action_pressed("ui_right", true):
				accept_event()
				_set_value_user(value + step)
			elif clicked:
				accept_event()
				_set_from_mouse(event.position.x)
			elif event is InputEventMouseMotion \
					and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
				accept_event()
				_set_from_mouse(event.position.x)


func _step_choice(dir: int) -> void:
	if options.is_empty():
		return
	index = wrapi(index + dir, 0, options.size())
	refresh()
	AudioManager.play_ui("tick")
	changed.emit()


func _set_value_user(v: float) -> void:
	v = clampf(snappedf(v, step), 0.0, 1.0)
	if is_equal_approx(v, value):
		return
	value = v
	refresh()
	AudioManager.play_ui("tick")
	changed.emit()


func _set_from_mouse(x: float) -> void:
	var bar_left := _bar.position.x + _hbox.position.x + 4.0
	var bar_w := _bar.size.x - 8.0
	_set_value_user((x - bar_left) / bar_w)


func _draw_bar() -> void:
	var w := _bar.size.x
	var bh := 20.0
	var y := (_bar.size.y - bh) / 2.0
	var focused := has_focus() and not disabled
	var col: Color = DIM if disabled else (GOLD if focused else IDLE)
	_bar.draw_rect(Rect2(0, y, w, bh), Color(0.03, 0.03, 0.09, 0.9))
	_bar.draw_rect(Rect2(1, y + 1, w - 2, bh - 2), col.darkened(0.25), false, 2.0)
	var filled := roundi(value * BAR_SEGMENTS)
	for i in BAR_SEGMENTS:
		var r := Rect2(4.0 + i * (SEG_W + SEG_GAP), y + 5.0, SEG_W, bh - 10.0)
		_bar.draw_rect(r, col if i < filled else col.darkened(0.8))
