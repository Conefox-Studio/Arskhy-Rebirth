extends Node2D

const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const NEXT_SCENE := "res://scenes/shynetown.tscn"
const AtmosphereScript = preload("res://scripts/atmosphere.gd")

@export var extend_ground := true
@export var extend_tiles := 24

const LINES: Array[String] = [
	"Langit di atas dataran Aethelgard tidak pernah biru.",
	"Ia selalu diselimuti oleh kabut tebal berwarna kelabu kehitaman, mengepul dari reruntuhan menara-menara kuno yang telah runtuh sejak berabad-abad lalu.",
	"Di bawah langit yang sekarat itu, dunia terasa sunyi hanya ditemani oleh suara angin malam yang berbisik membawa kutukan.",
]

var _font_ui: Font
var _font_bold: Font
var _box: PanelContainer
var _text: Label
var _hint: Label
var _fade: ColorRect
var _end_label: Label

var _page := -1
var _typing := false
var _progress := 0.0
var _last_blip := 0
var _ready_for_input := false
var _leaving := false


func _ready() -> void:
	_font_ui = load(FONT_UI)
	_font_bold = load(FONT_UI_BOLD)

	if extend_ground:
		_extend_ground()

	_build_atmosphere()
	_build_ui()

	AudioManager.play_music(AudioManager.MUSIC_MAP0, 4.0)
	if not AudioManager.is_ambient_playing():
		AudioManager.play_ambient(AudioManager.AMBIENT_WIND)

	_intro()


func _build_atmosphere() -> void:
	var atm: Node2D = AtmosphereScript.new()
	atm.use_canvas_modulate = false
	atm.use_player_light = false
	atm.fog_tint = Color(0.52, 0.54, 0.62)
	atm.fog_strength = 1.4
	add_child(atm)
	atm.setup($Camera2D)


func _extend_ground() -> void:
	for layer_name in ["Layer_0_2", "Layer_2_0"]:
		var layer := get_node_or_null("Map/" + layer_name) as TileMapLayer
		if layer:
			_extend_layer(layer, extend_tiles)


func _extend_layer(layer: TileMapLayer, pad: int) -> void:
	var used := layer.get_used_cells()
	if used.is_empty():
		return
	var min_x := used[0].x
	var max_x := used[0].x
	for c in used:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
	var rows := {}
	for c in used:
		rows[c.y] = true
	for y in rows.keys():
		var left := Vector2i(min_x + 1, y)
		var right := Vector2i(max_x - 1, y)
		if layer.get_cell_source_id(left) != -1:
			var src := layer.get_cell_source_id(left)
			var atlas := layer.get_cell_atlas_coords(left)
			for x in range(min_x - pad, min_x + 1):
				layer.set_cell(Vector2i(x, y), src, atlas)
		if layer.get_cell_source_id(right) != -1:
			var src2 := layer.get_cell_source_id(right)
			var atlas2 := layer.get_cell_atlas_coords(right)
			for x in range(max_x, max_x + pad + 1):
				layer.set_cell(Vector2i(x, y), src2, atlas2)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	_box = PanelContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_box.offset_left = 80
	_box.offset_right = -80
	var box_h := 190.0
	match GameSettings.text_size_index:
		0: box_h = 160.0
		2: box_h = 240.0
	_box.offset_top = -(36.0 + box_h)
	_box.offset_bottom = -36
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.08, GameSettings.box_opacity())
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 22
	sb.content_margin_bottom = 16
	_box.add_theme_stylebox_override("panel", sb)
	root.add_child(_box)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(v)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", _font_ui)
	_text.add_theme_font_size_override("font_size", GameSettings.text_size())
	_text.add_theme_color_override("font_color", Color("e9e4fa"))
	_text.add_theme_constant_override("line_spacing", 6)
	v.add_child(_text)

	_hint = Label.new()
	_hint.text = "Enter >"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", _font_bold)
	_hint.add_theme_font_size_override("font_size", 20)
	_hint.add_theme_color_override("font_color", Color("f6d776"))
	_hint.modulate.a = 0.0
	v.add_child(_hint)

	_end_label = Label.new()
	_end_label.text = "To be continued..."
	_end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_label.add_theme_font_override("font", _font_ui)
	_end_label.add_theme_font_size_override("font_size", 40)
	_end_label.add_theme_color_override("font_color", Color("d9d2f2"))
	_end_label.modulate.a = 0.0
	root.add_child(_end_label)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


func _intro() -> void:
	var dusk := $CanvasModulate as CanvasModulate
	dusk.color = Color.WHITE
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 2.0)
	t.tween_interval(1.0)
	t.tween_property(_box, "modulate:a", 1.0, 0.5)
	t.tween_callback(_next_page)
	create_tween().tween_property(dusk, "color", Color(0.46, 0.46, 0.56), 14.0) \
		.set_delay(3.0).set_trans(Tween.TRANS_SINE)
	_ready_for_input = true

	var blink := create_tween().set_loops()
	blink.tween_property(_hint, "self_modulate:a", 0.3, 0.5)
	blink.tween_property(_hint, "self_modulate:a", 1.0, 0.5)


func _next_page() -> void:
	_page += 1
	if _page >= LINES.size():
		_finish()
		return
	_text.text = LINES[_page]
	_progress = 0.0
	_last_blip = 0
	_hint.modulate.a = 0.0
	if GameSettings.text_speed_cps() <= 0.0:
		_text.visible_characters = -1
		_typing = false
		_hint.modulate.a = 1.0
		return
	_text.visible_characters = 0
	_typing = true


func _process(delta: float) -> void:
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


func _finish() -> void:
	_hint.modulate.a = 0.0
	_ready_for_input = false
	var t := create_tween()
	t.tween_property(_box, "modulate:a", 0.0, 0.5)
	t.tween_property(_fade, "color:a", 1.0, 1.5)
	t.tween_callback(_go_next)


func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().change_scene_to_file(NEXT_SCENE)


func _go_title() -> void:
	if _leaving:
		return
	_leaving = true
	AudioManager.stop_music(1.0)
	var t := create_tween()
	t.tween_property(_end_label, "modulate:a", 0.0, 0.5)
	t.tween_callback(func(): get_tree().change_scene_to_file(TITLE_SCENE))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_fade.color.a = 0.0
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.6)
		t.tween_callback(_go_title)
		return
	if not _ready_for_input:
		return
	var click: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		get_viewport().set_input_as_handled()
		if _typing:
			_progress = _text.text.length()
		elif _page < LINES.size():
			_next_page()
