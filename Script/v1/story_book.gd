extends Control

const NEXT_SCENE := "res://scenes/chapter_intro.tscn"
const BOOK_TEX := preload("res://assets/ui/book/book_open.png")
const ARROWS_TEX := preload("res://assets/ui/book/page_arrows.png")
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const MUSIC := "res://assets/audio/music/title_theme.mp3"
const INK := Color("4a3626")
const GOLD := Color("f6d776")
const TYPE_CPS := 55.0

const SPREADS: Array = [
	[
		"Di bawah langit malam yang luas, gelap, namun dipenuhi taburan bintang, Arskhy dan Skyumi menyambut kehadiran kelahiran anaknya.",
		"Namun, di balik keheningan malam itu, sebuah perdebatan kecil muncul: siapa nama yang layak disematkan untuk sang buah hati?",
	],
	[
		"Ide itu akhirnya datang dari Arskhy. Ia memadukan kedua nama mereka, Arskhy dan Skyumi, menciptakan sebuah identitas yang terdengar kokoh dan maskulin: Shyrnaru.",
		"Sepakat dengan nama tersebut, keduanya membesarkan sang anak dengan keyakinan penuh akan arti namanya.\\n\\nNamun, waktu berjalan tanpa aba-aba. Tiga tahun berlalu dalam sekejap.",
	],
	[
		"Kejanggalan itu perlahan merayap ketika Arskhy mulai menyadari sesuatu yang tersembunyi di balik suara tawa kecil Shyrnaru. Suara anak itu tidak mewarisi nada berat atau bass khas anak laki-laki seusianya.",
		"Sebaliknya, suaranya begitu lembut, tenang, dan jernih, persis seperti gema suara Skyumi.",
	],
	[
		"Di situlah Arskhy tersadar bahwa Shyrnaru adalah perempuan, rahasia kecil di balik nama yang mereka pilih tiga tahun lalu.",
		"Namun, di malam hari itu mereka sepakat mengganti namanya menjadi\\n\\nShyrn...",
	],
]

var _heading: Label
var _heading_sub: Label
var _book: Control
var _left: Label
var _right: Label
var _hint: Control
var _fade: ColorRect
var _spread := 0
var _typing := false
var _type_t := 0.0
var _busy := true
var _ended := false
var _clock := 0.0
var _tick := 0
var _font: Font


func _ready() -> void:
	_font = load(FONT_UI)
	_build_book()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	AudioManager.play_music_if_new(MUSIC, 2.0)
	_open_book()


func _open_book() -> void:
	_busy = true
	_book.pivot_offset = _book.size * 0.5
	_book.scale = Vector2(0.04, 1.0)
	_left.modulate.a = 0.0
	_right.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.9)
	tw.tween_callback(func(): AudioManager.play_ui("move"))
	tw.tween_property(_book, "scale:x", 1.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_show_heading)


func _show_heading() -> void:
	_heading.modulate.a = 0.0
	_heading_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_heading, "modulate:a", 1.0, 0.9)
	tw.tween_property(_heading_sub, "modulate:a", 1.0, 0.6)
	tw.tween_interval(1.8)
	tw.tween_property(_heading, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(_heading_sub, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		_busy = false
		_show_spread(0, true))


func _build_book() -> void:
	var vs := get_viewport_rect().size
	var sx := vs.x / 266.0
	var sy := vs.y / 152.0
	var sc := minf(sx, sy)
	_book = Control.new()
	_book.size = vs
	_book.position = Vector2.ZERO
	_book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_book)
	var tr := TextureRect.new()
	tr.texture = BOOK_TEX
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(tr)
	var fs := int(clampf(6.4 * sc, 18.0, 64.0))
	_left = _page_label(Rect2(Vector2(20 * sx, 16 * sy), Vector2(96 * sx, 118 * sy)), fs)
	_right = _page_label(Rect2(Vector2(152 * sx, 16 * sy), Vector2(96 * sx, 118 * sy)), fs)
	_heading = _centered(Rect2(Vector2(vs.x * 0.04, vs.y * 0.36), Vector2(vs.x * 0.42, vs.y * 0.2)), "ALUR CERITA", load(FONT_TITLE), int(clampf(9.5 * sc, 30.0, 96.0)))
	_heading_sub = _centered(Rect2(Vector2(vs.x * 0.54, vs.y * 0.42), Vector2(vs.x * 0.42, vs.y * 0.1)), "Prolog  -  Arskhy Rebirth", _font, int(clampf(5.0 * sc, 20.0, 44.0)))
	_hint = TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = ARROWS_TEX
	at.region = Rect2(49, 0, 46, 32)
	(_hint as TextureRect).texture = at
	(_hint as TextureRect).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	(_hint as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE
	(_hint as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hint.size = Vector2(46, 32) * (sc * 0.55)
	_hint.position = Vector2(vs.x - _hint.size.x - 22.0 * sx, vs.y - _hint.size.y - 14.0 * sy)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	var skip := Button.new()
	skip.text = "Lewati >>"
	skip.flat = true
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_override("font", _font)
	skip.add_theme_font_size_override("font_size", 22)
	skip.add_theme_color_override("font_color", Color(0.29, 0.21, 0.15, 0.85))
	skip.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.02))
	skip.add_theme_color_override("font_pressed_color", Color(0.1, 0.06, 0.02))
	skip.custom_minimum_size = Vector2(150, 56)
	skip.size = Vector2(150, 56)
	skip.position = Vector2(vs.x - 170.0, 10.0)
	skip.pressed.connect(_leave_now)
	add_child(skip)
	var tip := Label.new()
	tip.text = "Ketuk / Enter: Lanjut"
	tip.add_theme_font_override("font", _font)
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(0.29, 0.21, 0.15, 0.6))
	tip.position = Vector2(26.0 * sx, vs.y - 78.0)
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip)


func _centered(r: Rect2, text: String, font: Font, fs: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_outline_color", Color(0.96, 0.9, 0.74, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _page_label(r: Rect2, fs: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.clip_text = true
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_constant_override("line_spacing", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(l)
	return l


func _show_spread(i: int, first := false) -> void:
	_spread = i
	_left.text = SPREADS[i][0].replace("\\n", "\n")
	_right.text = SPREADS[i][1].replace("\\n", "\n")
	_left.visible_characters = 0
	_right.visible_characters = 0
	_left.modulate.a = 1.0
	_right.modulate.a = 1.0
	_type_t = 0.0
	_typing = true
	_hint.modulate.a = 0.0
	if not first:
		AudioManager.play_ui("tick")


func _total_chars() -> int:
	return _left.text.length() + _right.text.length()


func _process(delta: float) -> void:
	_clock += delta
	if _typing:
		_type_t += delta * TYPE_CPS
		var n := int(_type_t)
		var ln := _left.text.length()
		_left.visible_characters = mini(n, ln)
		_right.visible_characters = clampi(n - ln, 0, _right.text.length())
		if n > _tick + 3:
			_tick = n
			AudioManager.play_ui("tick")
		if n >= _total_chars():
			_finish_typing()
	elif _hint.modulate.a >= 0.0 and not _ended:
		_hint.modulate.a = 0.5 + 0.5 * sin(_clock * 5.0)


func _finish_typing() -> void:
	_typing = false
	_left.visible_characters = -1
	_right.visible_characters = -1
	_hint.modulate.a = 1.0


func _advance() -> void:
	if _busy or _ended:
		return
	if _typing:
		_finish_typing()
		return
	if _spread + 1 < SPREADS.size():
		_turn(_spread + 1)
	else:
		_close_book()


func _turn(to: int) -> void:
	_busy = true
	AudioManager.play_ui("move")
	var tw := create_tween()
	tw.tween_property(_left, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(_right, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(_hint, "modulate:a", 0.0, 0.1)
	tw.tween_callback(func():
		_busy = false
		_show_spread(to))


func _close_book() -> void:
	_ended = true
	_busy = true
	AudioManager.play_ui("back")
	_hint.modulate.a = 0.0
	var blk := ColorRect.new()
	blk.color = Color.BLACK
	blk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blk.modulate.a = 0.0
	add_child(blk)
	move_child(blk, 0)
	var tw := create_tween()
	tw.tween_property(blk, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property(_book, "modulate:a", 0.0, 1.4)
	tw.tween_interval(0.6)
	tw.tween_callback(_show_years)


func _show_years() -> void:
	var l := Label.new()
	l.text = "12 Tahun berlalu..."
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", load(FONT_TITLE))
	l.add_theme_font_size_override("font_size", 54)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.12))
	l.add_theme_constant_override("outline_size", 8)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	move_child(l, _fade.get_index())
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 1.6)
	tw.tween_interval(2.6)
	tw.tween_callback(_leave)


func _leave() -> void:
	if _busy and not _ended:
		return
	_busy = true
	_ended = true
	AudioManager.stop_music(1.5)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.4)
	tw.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave_now()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT, KEY_D, KEY_Z:
				_advance()
			KEY_LEFT, KEY_A:
				if not _busy and not _typing and not _ended and _spread > 0:
					_turn(_spread - 1)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_advance()


func _leave_now() -> void:
	if _ended and _busy:
		return
	_ended = true
	_busy = true
	_leave_force()


func _leave_force() -> void:
	AudioManager.stop_music(1.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.8)
	tw.tween_callback(func(): get_tree().change_scene_to_file(NEXT_SCENE))
