extends Control

const StoryBook = preload("res://scripts/story_book.gd")
const LoadingScript = preload("res://scripts/loading_screen.gd")

const VIDEO_PATH := "res://assets/video/intro.ogv"
const NEXT_SCENE := "res://scenes/title_screen.tscn"
const SEEN_PATH := "user://intro_seen.cfg"

const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"

const WARNING_TEXT := "Warning, it may contain blood or flashes,\nbut the flashes can be turned on in the settings."
const DEDICATION_TEXT := "Special For Kouzerumatsukitsune - Father"

const CARD_HOLD := 3.0
const CARD_FADE := 0.6

var _player: VideoStreamPlayer
var _card: Label
var _tween: Tween
var _loading: Control

var _phase := 0
var _cards: Array = []
var _story := false
var _leaving := false
var _loading_done := false


func _ready() -> void:
	_build_cards()

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var stream := load(VIDEO_PATH) as VideoStream
	if stream == null:
		push_warning("Video intro tidak ditemukan: " + VIDEO_PATH)
		_next_phase.call_deferred()
		return

	var ratio := AspectRatioContainer.new()
	ratio.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ratio.ratio = 16.0 / 9.0
	ratio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ratio)

	_player = VideoStreamPlayer.new()
	_player.stream = stream
	_player.expand = true
	_player.bus = "Master"
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_next_phase)
	ratio.add_child(_player)
	_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _loading != null:
		return

	var click: bool = event is InputEventMouseButton and event.pressed
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_next_phase()


func _story_seen() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(SEEN_PATH) == OK and bool(cfg.get_value("intro", "seen", false))


func _mark_story_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("intro", "seen", true)
	cfg.save(SEEN_PATH)


func _build_cards() -> void:
	_cards = [
		[WARNING_TEXT, 30, CARD_HOLD, false],
		[DEDICATION_TEXT, 36, CARD_HOLD, false]
	]

	if _story_seen():
		return

	_story = true
	for sp in StoryBook.SPREADS:
		var txt: String = String(sp[0]) + "\n\n" + String(sp[1])
		_cards.append([txt, 28, clampf(float(txt.length()) / 13.0, 5.0, 14.0), false])

	_cards.append(["12 Tahun berlalu...", 56, 3.6, true])


func _next_phase() -> void:
	if _leaving or _loading != null:
		return

	if _phase == 0 and not _loading_done:
		_stop_video()
		_loading = LoadingScript.new()
		_loading.finished.connect(func() -> void:
			_loading = null
			_loading_done = true
			_next_phase()
		)
		add_child(_loading)
		return

	_phase += 1
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_stop_video()

	if _phase >= 1 and _phase <= _cards.size():
		var c: Array = _cards[_phase - 1]
		_show_card(String(c[0]), int(c[1]), float(c[2]), bool(c[3]))
	else:
		_go_next()


func _stop_video() -> void:
	if _player != null and _player.is_playing():
		_player.stop()
		_player.hide()


func _show_card(text: String, size: int, hold: float = CARD_HOLD, title_font := false) -> void:
	if _card == null:
		_card = Label.new()
		_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_theme_color_override("font_color", Color(0.93, 0.92, 0.98))
		_card.offset_left = 120
		_card.offset_right = -120
		add_child(_card)

	_card.text = text
	_card.add_theme_font_override("font", load(FONT_TITLE if title_font else FONT_UI))
	_card.add_theme_constant_override("line_spacing", 8)
	_card.add_theme_font_size_override("font_size", size)
	_card.modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(_card, "modulate:a", 1.0, CARD_FADE)
	_tween.tween_interval(hold)
	_tween.tween_property(_card, "modulate:a", 0.0, CARD_FADE)
	_tween.tween_callback(_next_phase)


func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	if _story:
		_mark_story_seen()
	get_tree().change_scene_to_file(NEXT_SCENE)
