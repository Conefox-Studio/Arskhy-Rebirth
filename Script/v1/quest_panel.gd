extends CanvasLayer

const FONT := "res://assets/fonts/pixelify_sans_bold.ttf"

var _body: Label
var _head: Button
var _shown := true


func _init() -> void:
	layer = 45


func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -230.0
	box.offset_right = -10.0
	box.offset_top = 64.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var f := load(FONT) as Font
	_head = Button.new()
	_head.flat = true
	_head.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_head.focus_mode = Control.FOCUS_NONE
	_head.add_theme_font_size_override("font_size", 14)
	_head.add_theme_color_override("font_color", Color("f6d776"))
	if f != null:
		_head.add_theme_font_override("font", f)
	_head.pressed.connect(toggle)
	box.add_child(_head)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_body.add_theme_font_size_override("font_size", 13)
	_body.add_theme_color_override("font_color", Color("f6e7b0"))
	_body.add_theme_color_override("font_outline_color", Color("1d1530"))
	_body.add_theme_constant_override("outline_size", 4)
	if f != null:
		_body.add_theme_font_override("font", f)
	box.add_child(_body)
	_refresh()


func set_text(t: String) -> void:
	if _body != null:
		_body.text = t


func toggle() -> void:
	_shown = not _shown
	_refresh()


func _refresh() -> void:
	_body.visible = _shown
	_head.text = "Quest [Q] " + ("v" if _shown else "<")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_Q:
		toggle()
