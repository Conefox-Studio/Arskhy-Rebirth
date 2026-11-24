extends Control

const NEXT_SCENE := "res://scenes/map0.tscn"
const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"

const CHAPTER_NO := "CHAPTER 1"
const CHAPTER_NAME := "AUTUMN"
const STARTED := "has started"

const AMBER := Color("f0a04b")
const GOLD := Color("f6d776")

var _chapter_fv: FontVariation
var _name_fv: FontVariation
var _lbl_chapter: Label
var _lbl_name: Label
var _lbl_started: Label
var _line: Control
var _line_w := 0.0
var _fade: ColorRect
var _leaving := false
var _can_skip := false
var _type_tween: Tween


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("07050d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	_chapter_fv = FontVariation.new()
	_chapter_fv.base_font = load(FONT_UI_BOLD)
	_chapter_fv.spacing_glyph = 30
	_lbl_chapter = _make_label(CHAPTER_NO, _chapter_fv, 30, GOLD.darkened(0.15))
	box.add_child(_lbl_chapter)

	_line = Control.new()
	_line.custom_minimum_size = Vector2(0, 24)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.draw.connect(_draw_line)
	box.add_child(_line)

	_name_fv = FontVariation.new()
	_name_fv.base_font = load(FONT_TITLE)
	_name_fv.spacing_glyph = 60
	_lbl_name = _make_label(CHAPTER_NAME, _name_fv, 120, AMBER)
	_lbl_name.add_theme_color_override("font_outline_color", Color("2a0f05"))
	_lbl_name.add_theme_constant_override("outline_size", 12)
	_lbl_name.add_theme_color_override("font_shadow_color", Color(1.0, 0.55, 0.2, 0.35))
	_lbl_name.add_theme_constant_override("shadow_offset_x", 0)
	_lbl_name.add_theme_constant_override("shadow_offset_y", 0)
	_lbl_name.add_theme_constant_override("shadow_outline_size", 18)
	box.add_child(_lbl_name)

	_lbl_started = _make_label(STARTED, load(FONT_UI), 34, Color("d9d2f2"))
	_lbl_started.visible_characters = 0
	box.add_child(_lbl_started)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_lbl_chapter.modulate.a = 0.0
	_lbl_name.modulate.a = 0.0
	_play()


func _make_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _draw_line() -> void:
	var w := _line.size.x * _line_w
	var cx := _line.size.x / 2.0
	var y := _line.size.y / 2.0
	_line.draw_line(Vector2(cx - w / 2.0, y), Vector2(cx + w / 2.0, y), Color(AMBER, 0.9), 2.0)
	if _line_w > 0.95:
		_line.draw_colored_polygon(PackedVector2Array([
			Vector2(cx, y - 7), Vector2(cx + 7, y), Vector2(cx, y + 7), Vector2(cx - 7, y)]), AMBER)


func _set_line(v: float) -> void:
	_line_w = v
	_line.queue_redraw()


func _play() -> void:
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(_fade, "color:a", 0.0, 0.8)
	t.tween_callback(func():
		_can_skip = true
		AudioManager.play_ui("chapter"))

	t.tween_property(_lbl_chapter, "modulate:a", 1.0, 1.2)
	t.parallel().tween_property(_chapter_fv, "spacing_glyph", 8, 1.8) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	t.tween_method(_set_line, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)

	t.tween_property(_lbl_name, "modulate:a", 1.0, 1.4)
	t.parallel().tween_property(_name_fv, "spacing_glyph", 10, 2.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.5)

	t.tween_callback(_type_started)
	t.tween_interval(2.8)

	t.tween_callback(_leave)


func _type_started() -> void:
	_type_tween = create_tween()
	var n := STARTED.length()
	for i in n:
		_type_tween.tween_callback(func():
			_lbl_started.visible_characters = i + 1
			if GameSettings.typing_sound:
				AudioManager.play_ui("type"))
		_type_tween.tween_interval(0.07)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 1.2)
	t.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if not _can_skip or _leaving:
		return
	var click: bool = event is InputEventMouseButton and event.pressed
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()
