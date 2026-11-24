extends Control

const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const MUSIC := "res://assets/audio/music/before_ending.mp3"
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const SCROLL_SPEED := 52.0
const GOLD := Color("f6d776")
const PALE := Color("efe6ff")
const BLUE := Color("6f8fd8")

const ROLL: Array = [
	["TITLE", "ARSKHY REBIRTH", "A Dark Fantasy Adventure"],
	["DEVELOPED & CREATED BY", "Rationatsu"],
	["STORY & NARRATIVE DESIGN", "Rationatsu"],
	["PROGRAMMING & GAME MECHANICS", "Rationatsu"],
	["ART & CHARACTER DESIGN", "Rationatsu"],
	["ANIMATION", "Opium"],
	["MUSIC & SOUND DESIGN", "Original Piano Composition & Performance by Rationatsu"],
	["SPECIAL THANKS", "Kouzerumatsukitsune - Father", "Foxy - Besties", "Ary's - Brother online", "Lisa", "And more", "All supporters, family, and friends"],
	["NOTE", "This game demo and for the full please buy", "at the trusted source / official source!", "Do not download at other sources.", "Official source: https://arskhyrebirth.base44.app"],
	["FOOTER", "\u00a9 2026 Conefox Studio. All Rights Reserved."],
]

var _col: VBoxContainer
var _fade: ColorRect
var _phase := 0
var _done := false
var _title_font: Font
var _ui_font: Font
var _bold: Font


func _ready() -> void:
	_title_font = load(FONT_TITLE)
	_ui_font = load(FONT_UI)
	_bold = load(FONT_BOLD)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.01, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 18)
	_col.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_col)
	for e in ROLL:
		_add_entry(e)
	_col.custom_minimum_size.x = 900.0
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	AudioManager.play_music_if_new(MUSIC, 1.0)
	create_tween().tween_property(_fade, "color:a", 0.0, 1.5)
	await get_tree().process_frame
	_col.size = Vector2(900.0, 0.0)
	_col.position = Vector2((size.x - 900.0) * 0.5, size.y + 40.0)
	_phase = 1


func _lbl(text: String, font: Font, fs: int, color: Color, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.12))
		l.add_theme_constant_override("outline_size", 6)
	return l


func _gap(h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	_col.add_child(c)


func _add_entry(e: Array) -> void:
	match e[0]:
		"TITLE":
			_col.add_child(_lbl(e[1], _title_font, 76, GOLD))
			_col.add_child(_lbl(e[2], _ui_font, 28, PALE))
			_gap(120.0)
		"FOOTER":
			_gap(40.0)
			_col.add_child(_lbl(e[1], _ui_font, 22, Color(0.7, 0.68, 0.82)))
			_gap(60.0)
		_:
			_col.add_child(_lbl(e[0], _bold, 22, BLUE))
			for i in range(1, e.size()):
				_col.add_child(_lbl(e[i], _ui_font, 34 if e[i].length() < 30 else 26, PALE))
			_gap(70.0)


func _process(delta: float) -> void:
	if _phase != 1:
		return
	var fast := 3.0 if Input.is_action_pressed("ui_accept") else 1.0
	_col.position.y -= SCROLL_SPEED * fast * delta
	if _col.position.y + _col.get_combined_minimum_size().y < -20.0:
		_end_cards()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _phase == 1:
		_end_cards()
	elif _phase == 3 and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		_to_title()


func _end_cards() -> void:
	if _phase != 1:
		return
	_phase = 2
	var tw := create_tween()
	tw.tween_property(_col, "modulate:a", 0.0, 1.0)
	tw.tween_callback(_show_thanks)


func _card(text: String, font: Font, fs: int, color: Color) -> Label:
	var l := _lbl(text, font, fs, color)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	add_child(l)
	move_child(l, _fade.get_index())
	return l


func _show_thanks() -> void:
	Achievements.unlock("demo_clear")
	_col.hide()
	var thanks := _card("Thank You For Playing Demo", _title_font, 60, GOLD)
	var tw := create_tween()
	tw.tween_property(thanks, "modulate:a", 1.0, 1.6)
	tw.tween_interval(3.6)
	tw.tween_property(thanks, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func():
		var tbc := _card("To Be Continued", _title_font, 72, PALE)
		var t2 := create_tween()
		t2.tween_property(tbc, "modulate:a", 1.0, 2.0)
		t2.tween_callback(func(): _phase = 3)
		t2.tween_interval(6.0)
		t2.tween_callback(_to_title))


func _to_title() -> void:
	if _done:
		return
	_done = true
	_phase = 4
	AudioManager.stop_music(2.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.8)
	tw.tween_callback(func(): get_tree().change_scene_to_file(TITLE_SCENE))
