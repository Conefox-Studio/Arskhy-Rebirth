extends Control

const UiSkin = preload("res://scripts/ui_skin.gd")
const PixelItem = preload("res://scripts/menu_item.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const StageScript = preload("res://scripts/title_sky.gd")

const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"

const VERSION_TEXT := "1.0"
const DEV_TEXT := "Dev - Rationatsu"

const CREDITS: Array = [
	["MAIN OC", "Arskhy"],
	["DEVELOPER", "Rationatsu"],
	["ANIMATOR / ASSET", "Opium"],
	["ASSETS", "itch.io"],
	["SPECIAL THANKS", "Kouzerumatsukitsune - Father"],
	["", "Foxy - Besties"],
	["", "Ary's - Brother online"],
	["", "And more"],
]
const NOTE_TEXT := "Note, this game demo and for the full please buy at the trusted source/official source! Do not download at other sources. Official source is https://arskhyrebirth.base44.app"
const SUPPORT_LINKS: Array = [
	["PayPal", "https://paypal.me/hikarurationatsu", "res://assets/ui/links/paypal.png"],
	["Sociabuzz", "https://sociabuzz.com/rationatsu_art/support", "res://assets/ui/links/sociabuzz.png"],
	["Official Website", "https://rationatsu.base44.app", "res://assets/ui/links/app_icon.png"],
]
const INTRO_SCENE := "res://scenes/chapter_intro.tscn"
const CONTINUE_SCENE := "res://scenes/shynetown.tscn"

const GOLD := Color("f6d776")
const GOLD_DARK := Color("c9a24b")
const PALE := Color("efe6ff")
const MUTED := Color("8b86a8")

var _font_title: Font
var _font_ui: Font
var _font_ui_bold: Font

var _stage: Node2D
var _title_labels: Array[Label] = []
var _main_items: Array = []
var _settings: Control
var _about_layer: Control
var _ach_layer: Control
var _about_back: Control
var _menu_box: Control
var _diff_box: VBoxContainer
var _confirm_layer: Control
var _diff_layer: Control
var _diff_items: Array = []
var _diff_desc: Label
var _slots_layer: Control
var _toast: Label
var _fade: ColorRect
var _last_focus: Control
var _busy := false
var _leaving := false


func _ready() -> void:
	AudioManager.silence_game_sounds()
	_font_title = load(FONT_TITLE)
	_font_ui = load(FONT_UI)
	_font_ui_bold = load(FONT_UI_BOLD)

	_build_background()
	_build_main_layout()
	_build_settings()
	_build_about()
	_build_difficulty()
	_build_toast()
	_build_fade()

	AudioManager.play_music(AudioManager.MUSIC_TITLE)
	AudioManager.play_ambient(AudioManager.AMBIENT_WIND)
	_play_intro()


func _build_background() -> void:
	_stage = StageScript.new()
	add_child(_stage)

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62])
	g.colors = PackedColorArray([Color(0.02, 0.02, 0.07, 0.9), Color(0.02, 0.02, 0.07, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	gt.fill = GradientTexture2D.FILL_LINEAR
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	add_child(_overlay(gt))


func _overlay(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_main_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	var title_box := VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", -12)
	col.add_child(title_box)
	title_box.add_child(_title_label("ARSKHY", GOLD))
	title_box.add_child(_title_label("REBIRTH", PALE))
	_start_title_glow()

	col.add_child(_spacer(1.0))

	var menu := VBoxContainer.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.custom_minimum_size.x = 400
	menu.add_theme_constant_override("separation", 6)
	col.add_child(menu)
	_menu_box = menu

	var has_save := GameState.has_any_save()
	var it_new := _make_item(menu, "New Game", PixelItem.Kind.BUTTON, 34)
	var it_cont := _make_item(menu, "Continue", PixelItem.Kind.BUTTON, 34)
	var it_set := _make_item(menu, "Settings", PixelItem.Kind.BUTTON, 34)
	var it_ach := _make_item(menu, "Achievements", PixelItem.Kind.BUTTON, 34)
	var it_about := _make_item(menu, "About", PixelItem.Kind.BUTTON, 34)
	var it_quit := _make_item(menu, "Quit", PixelItem.Kind.BUTTON, 34)
	it_cont.set_disabled(not has_save)
	it_new.activated.connect(_open_difficulty)
	it_cont.activated.connect(_on_continue)
	it_set.activated.connect(_open_settings)
	it_ach.activated.connect(_open_achievements)
	it_about.activated.connect(_open_about)
	it_quit.activated.connect(_on_quit)
	_main_items = [it_new, it_cont, it_set, it_ach, it_about, it_quit]
	_wrap_nav(_main_items)

	col.add_child(_spacer(0.6))

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(footer)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 0)
	footer.add_child(info)
	info.add_child(_label(VERSION_TEXT, _font_ui_bold, 22, GOLD_DARK))
	info.add_child(_label(DEV_TEXT, _font_ui, 20, MUTED))

	var fill := Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(fill)

	var hint := _label("Arrow Keys: Select    Enter: OK    Esc: Back", _font_ui, 18, MUTED)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.add_child(hint)


func _title_label(text: String, color: Color) -> Label:
	var l := _label(text, _font_title, 84, color)
	l.add_theme_color_override("font_outline_color", Color("1a0f3a"))
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.82, 0.35, 0.2))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 14)
	_title_labels.append(l)
	return l


func _start_title_glow() -> void:
	var t := create_tween().set_loops()
	t.tween_method(_set_glow, 0.10, 0.50, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_glow, 0.50, 0.10, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_glow(a: float) -> void:
	for l in _title_labels:
		l.add_theme_color_override("font_shadow_color", Color(1.0, 0.82, 0.35, a))


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _spacer(ratio: float) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_stretch_ratio = ratio
	return s


func _make_item(parent: Control, text: String, kind: int, font_size: int) -> Control:
	var it: Control = PixelItem.new()
	it.title = text
	it.kind = kind
	it.item_font = _font_ui
	it.font_size = font_size
	parent.add_child(it)
	return it


func _make_ornament(width: float, centered: bool) -> Control:
	if centered:
		var none := Control.new()
		none.custom_minimum_size = Vector2(0, 8)
		return none
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 28)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var y := c.size.y / 2.0
		var cx := c.size.x / 2.0 if centered else 14.0
		var n := 40
		var span := (c.size.x / 2.0 - 22.0) if centered else (c.size.x - 36.0)
		for i in n:
			var a := 0.9 * (1.0 - float(i) / n)
			var d0 := 18.0 + span * i / n
			var d1 := 18.0 + span * (i + 1) / n
			c.draw_line(Vector2(cx + d0, y), Vector2(cx + d1, y), Color(GOLD, a), 2.0)
			if centered:
				c.draw_line(Vector2(cx - d0, y), Vector2(cx - d1, y), Color(GOLD, a), 2.0)
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(cx, y - 8), Vector2(cx + 8, y), Vector2(cx, y + 8), Vector2(cx - 8, y)]), GOLD))
	return c


func _wrap_nav(items: Array) -> void:
	var live := items.filter(func(i): return not i.disabled)
	var n := live.size()
	for i in n:
		var it: Control = live[i]
		it.focus_neighbor_top = it.get_path_to(live[(i - 1 + n) % n])
		it.focus_neighbor_bottom = it.get_path_to(live[(i + 1) % n])
		it.focus_neighbor_left = it.get_path_to(it)
		it.focus_neighbor_right = it.get_path_to(it)


func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.inline_mode = true
	_settings.inline_left = 96.0 + 400.0 + 28.0
	add_child(_settings)
	_settings.closed.connect(_on_settings_closed)


func _open_settings() -> void:
	if _busy:
		return
	if _settings.visible:
		_settings.close()
		return
	_last_focus = get_viewport().gui_get_focus_owner()
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE
	_settings.open()


func _on_settings_closed() -> void:
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE if it.disabled else Control.FOCUS_ALL
	var target: Control = _last_focus if _last_focus else _main_items[0]
	target.silent_focus = true
	target.grab_focus()


func _build_about() -> void:
	_about_layer = Control.new()
	_about_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_about_layer.visible = false
	add_child(_about_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_about_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_about_layer.add_child(center)

	var panel := PanelContainer.new()
	var sb: StyleBox = UiSkin.box("panel_ornate", 22, 0.0)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 40
	sb.content_margin_bottom = 42
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := _label("ABOUT", _font_title, 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_make_ornament(560.0, true))
	v.add_child(_label_h(VERSION_TEXT, 20, GOLD_DARK))

	for c in CREDITS:
		if String(c[0]) != "":
			var role: Label = _label("- %s -" % c[0], _font_ui_bold, 18, Color("6f8fd8"))
			role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			role.custom_minimum_size.y = 24
			role.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			v.add_child(role)
		var who: Label = _label(c[1], _font_ui, 24, PALE)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(who)

	var note: Label = _label(NOTE_TEXT, _font_ui, 15, Color("e8b86a"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 560
	v.add_child(note)

	var links := HBoxContainer.new()
	links.alignment = BoxContainer.ALIGNMENT_CENTER
	links.add_theme_constant_override("separation", 10)
	v.add_child(links)
	for L in SUPPORT_LINKS:
		var b := Button.new()
		b.text = " " + String(L[0])
		var tex: Texture2D = load(String(L[2]))
		if tex == null:
			tex = preload("res://scripts/tex_util.gd").load_tex(String(L[2]))
		b.icon = tex
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 26)
		b.add_theme_font_override("font", _font_ui_bold)
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", PALE)
		b.add_theme_color_override("font_hover_color", GOLD)
		b.add_theme_stylebox_override("normal", UiSkin.plaque(false))
		b.add_theme_stylebox_override("hover", UiSkin.plaque(true))
		b.add_theme_stylebox_override("pressed", UiSkin.plaque(true))
		b.add_theme_stylebox_override("focus", UiSkin.plaque(true))
		b.custom_minimum_size = Vector2(0, 40)
		var url := String(L[1])
		b.pressed.connect(func():
			AudioManager.play_ui("select")
			OS.shell_open(url))
		links.add_child(b)

	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	v.add_child(gap)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(buttons)
	_about_back = _make_item(buttons, "Back", PixelItem.Kind.BUTTON, 26)
	_about_back.custom_minimum_size.x = 160
	_about_back.activated.connect(_close_about)
	_about_back.focus_neighbor_top = _about_back.get_path_to(_about_back)
	_about_back.focus_neighbor_bottom = _about_back.get_path_to(_about_back)
	_about_back.focus_neighbor_left = _about_back.get_path_to(_about_back)
	_about_back.focus_neighbor_right = _about_back.get_path_to(_about_back)


func _label_h(text: String, font_size: int, color: Color) -> Label:
	var l := _label(text, _font_ui_bold, font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _open_about() -> void:
	if _busy or _about_layer.visible:
		return
	if _settings.visible:
		_settings.close()
	_last_focus = get_viewport().gui_get_focus_owner()
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE
	_about_layer.modulate.a = 0.0
	_about_layer.show()
	create_tween().tween_property(_about_layer, "modulate:a", 1.0, 0.18)
	_about_back.silent_focus = true
	_about_back.grab_focus()


func _close_about() -> void:
	if not _about_layer.visible:
		return
	AudioManager.play_ui("back")
	_about_layer.hide()
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE if it.disabled else Control.FOCUS_ALL
	var target: Control = _last_focus if _last_focus else _main_items[0]
	target.silent_focus = true
	target.grab_focus()


func _make_overlay(title_text: String, width: float) -> Array:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.visible = false
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)

	var panel := PanelContainer.new()
	var sb: StyleBox = UiSkin.box("panel_ornate", 22, 0.0)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 40
	sb.content_margin_bottom = 42
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.custom_minimum_size.x = width
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := _label(title_text, _font_title, 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_make_ornament(width, true))
	return [layer, v]


func _build_difficulty() -> void:
	_diff_layer = Control.new()
	_diff_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diff_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diff_layer.visible = false
	add_child(_diff_layer)
	_diff_box = VBoxContainer.new()
	_diff_box.custom_minimum_size.x = 440
	_diff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_diff_box.add_theme_constant_override("separation", 4)
	_diff_layer.add_child(_diff_box)
	var title := _label("SELECT MODE", _font_title, 30, GOLD)
	_diff_box.add_child(title)
	_diff_items.clear()
	for i in 5:
		var nm := "Special" if i == 4 else GameState.DIFF_NAMES[i]
		var it := _make_item(_diff_box, nm, PixelItem.Kind.BUTTON, 32)
		var idx := i
		it.activated.connect(func(): _pick_mode(idx))
		it.focus_entered.connect(func(): _show_diff_info(idx))
		_diff_items.append(it)
	_diff_desc = _label("", _font_ui, 20, PALE)
	_diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc.custom_minimum_size = Vector2(430, 78)
	_diff_box.add_child(_diff_desc)
	var note := _label("", _font_ui, 18, Color("ff9a8a"))
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(430, 24)
	_diff_box.add_child(note)
	var back := _make_item(_diff_box, "Back", PixelItem.Kind.BUTTON, 26)
	back.activated.connect(_close_diff)
	_diff_items.append(back)
	_wrap_nav(_diff_items)


func _mode_requirement(i: int) -> String:
	match i:
		2:
			return "Locked - finish Normal mode first."
		3:
			return "Locked - finish Hard mode first."
		4:
			return "Locked - finish every mode. Full version only (not available in the demo)."
	return ""


func _refresh_mode_labels() -> void:
	for i in 5:
		var it: Control = _diff_items[i]
		var nm := "Special" if i == 4 else GameState.DIFF_NAMES[i]
		it.title = nm if GameSettings.mode_unlocked(i) else nm + "   [Locked]"
		it.modulate = Color(1, 1, 1, 1.0) if GameSettings.mode_unlocked(i) else Color(1, 1, 1, 0.5)
		it.queue_redraw()


func _show_diff_info(i: int) -> void:
	if i >= 4 or not GameSettings.mode_unlocked(i):
		_diff_desc.text = _mode_requirement(i) if i >= 2 else ""
		if i == 4:
			_diff_desc.text = "A special challenge for the full version.\n" + _mode_requirement(4)
		return
	var boss: int = preload("res://scripts/boss.gd").HP_BY_DIFF[i]
	var saves := "Unlimited" if GameState.DIFF_SAVES[i] < 0 else str(GameState.DIFF_SAVES[i])
	_diff_desc.text = "%s\nHP %d   |   Saves %s   |   Boss HP %d" % [GameState.DIFF_DESC[i], GameState.DIFF_HP[i], saves, boss]


func _pick_mode(i: int) -> void:
	if not GameSettings.mode_unlocked(i):
		AudioManager.play_ui("back")
		var note: Label = _diff_layer.find_child("Note", true, false)
		note.text = _mode_requirement(i)
		return
	_start_new_game(i)


func _open_difficulty() -> void:
	if _busy or _diff_layer.visible or _about_layer.visible:
		return
	if _settings.visible:
		_settings.close()
	_last_focus = get_viewport().gui_get_focus_owner()
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE
		it.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box.set_meta("home_x", _menu_box.position.x)
	var note: Label = _diff_layer.find_child("Note", true, false)
	note.text = "Starting a new journey erases your current saves." if GameState.has_any_save() else ""
	_refresh_mode_labels()
	var start := clampi(GameState.difficulty, 0, 3)
	if not GameSettings.mode_unlocked(start):
		start = 1
	_show_diff_info(start)
	AudioManager.play_ui("select")
	var home := _menu_box.global_position - Vector2(0, 52)
	_diff_box.position = home + Vector2(-60, 0)
	_diff_layer.modulate.a = 0.0
	_diff_layer.show()
	var t := create_tween().set_parallel(true)
	t.tween_property(_menu_box, "modulate:a", 0.0, 0.2)
	t.tween_property(_menu_box, "position:x", _menu_box.position.x - 60.0, 0.2)
	t.tween_property(_diff_layer, "modulate:a", 1.0, 0.3).set_delay(0.12)
	t.tween_property(_diff_box, "position", home, 0.3).set_delay(0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_diff_items[start].silent_focus = true
	_diff_items[start].grab_focus.call_deferred()


func _close_diff() -> void:
	if not _diff_layer.visible:
		return
	AudioManager.play_ui("back")
	var t := create_tween().set_parallel(true)
	t.tween_property(_diff_layer, "modulate:a", 0.0, 0.18)
	t.tween_property(_menu_box, "modulate:a", 1.0, 0.25).set_delay(0.1)
	t.tween_property(_menu_box, "position:x", float(_menu_box.get_meta("home_x", _menu_box.position.x)), 0.25).set_delay(0.1)
	t.chain().tween_callback(func():
		_diff_layer.hide()
		for it in _main_items:
			it.mouse_filter = Control.MOUSE_FILTER_STOP
			it.focus_mode = Control.FOCUS_NONE if it.disabled else Control.FOCUS_ALL
		var target: Control = _last_focus if _last_focus and is_instance_valid(_last_focus) else _main_items[0]
		target.silent_focus = true
		target.grab_focus())


func _open_achievements() -> void:
	if _busy or _diff_layer.visible or _about_layer.visible or (_ach_layer != null and _ach_layer.visible):
		return
	if _settings.visible:
		_settings.close()
	if _ach_layer != null:
		_ach_layer.queue_free()
	var ov := _make_overlay("ACHIEVEMENTS", 680.0)
	_ach_layer = ov[0]
	var v: VBoxContainer = ov[1]
	var cnt := _label("Unlocked %d / %d" % [Achievements.count(), Achievements.LIST.size()], _font_ui, 22, Color("9fb0e8"))
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cnt)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	v.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 2)
	scroll.add_child(rows)
	var items: Array = []
	for e in Achievements.LIST:
		var got: bool = Achievements.is_unlocked(e.id)
		var it := _make_item(rows, ("★ " if got else "?  ") + String(e.name), PixelItem.Kind.BUTTON, 28)
		if not got:
			it.modulate = Color(1, 1, 1, 0.55)
		var d := _label(String(e.desc), _font_ui, 18, Color("c9c2e0") if got else Color("8b86a3"))
		d.add_theme_constant_override("line_spacing", 0)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 40)
		m.add_theme_constant_override("margin_bottom", 8)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		m.add_child(d)
		rows.add_child(m)
		items.append(it)
	var back := _make_item(v, "Back", PixelItem.Kind.BUTTON, 26)
	var layer_ref := _ach_layer
	back.activated.connect(func(): _close_overlay(layer_ref))
	items.append(back)
	_wrap_nav(items)
	_open_overlay(_ach_layer, items[0])


func _open_slots() -> void:
	if _slots_layer != null:
		_slots_layer.queue_free()
	var ov := _make_overlay("CONTINUE", 700.0)
	_slots_layer = ov[0]
	var v: VBoxContainer = ov[1]
	var items: Array = []
	for info in GameState.all_slot_infos():
		var it := _make_item(v, GameState.slot_line(info), PixelItem.Kind.BUTTON, 24)
		if bool(info.get("empty", false)):
			it.modulate = Color(1, 1, 1, 0.45)
			it.focus_mode = Control.FOCUS_NONE
			continue
		var slot: int = info.slot
		it.activated.connect(func(): _load_slot(slot))
		items.append(it)
	var back := _make_item(v, "Back", PixelItem.Kind.BUTTON, 26)
	var layer_ref := _slots_layer
	back.activated.connect(func(): _close_overlay(layer_ref))
	items.append(back)
	_wrap_nav(items)
	_open_overlay(_slots_layer, items[0])


func _open_overlay(layer: Control, first: Control) -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE
	layer.modulate.a = 0.0
	layer.show()
	create_tween().tween_property(layer, "modulate:a", 1.0, 0.18)
	first.silent_focus = true
	first.grab_focus.call_deferred()


func _close_overlay(layer: Control) -> void:
	if layer == _diff_layer:
		_close_diff()
		return
	if not layer.visible:
		return
	AudioManager.play_ui("back")
	layer.hide()
	for it in _main_items:
		it.focus_mode = Control.FOCUS_NONE if it.disabled else Control.FOCUS_ALL
	var target: Control = _last_focus if _last_focus and is_instance_valid(_last_focus) else _main_items[0]
	target.silent_focus = true
	target.grab_focus()


func _start_new_game(diff: int) -> void:
	if _busy:
		return
	_busy = true
	Achievements.unlock("first_steps")
	GameState.new_journey(diff)
	AudioManager.play_ui("select")
	AudioManager.play_sfx_named("game_start")
	AudioManager.stop_music(3.0)
	_leave_to(INTRO_SCENE)


func _on_continue() -> void:
	if _busy:
		return
	if not GameState.has_any_save():
		_show_toast("Save data not found")
		return
	_open_slots()


func _load_slot(slot: int) -> void:
	if _busy:
		return
	var scene_path := GameState.load_slot(slot, CONTINUE_SCENE)
	if scene_path == "":
		_show_toast("Save data not found")
		return
	_busy = true
	AudioManager.stop_music(3.0)
	_leave_to(scene_path)


func _leave_to(scene_path: String) -> void:
	_leaving = true
	var fade_ui := create_tween().set_parallel(true)
	for it in _main_items:
		fade_ui.tween_property(it, "modulate:a", 0.0, 0.35)
	for l in _title_labels:
		fade_ui.tween_property(l, "modulate:a", 0.0, 0.5)
	for layer in [_diff_layer, _slots_layer, _settings, _about_layer]:
		if layer != null and is_instance_valid(layer) and layer.visible:
			fade_ui.tween_property(layer, "modulate:a", 0.0, 0.3)
	var go := func():
		if not _leaving:
			return
		_leaving = false
		var t := create_tween()
		t.tween_property(_fade, "color:a", 1.0, 0.7)
		t.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
	_stage.hero_exited.connect(go, CONNECT_ONE_SHOT)
	_stage.hero_walk_out()
	var guard := Timer.new()
	guard.one_shot = true
	guard.wait_time = 8.0
	add_child(guard)
	guard.timeout.connect(go)
	guard.start()


func _on_quit() -> void:
	if _busy or (_confirm_layer != null and _confirm_layer.visible):
		return
	if _confirm_layer == null:
		var ov := _make_overlay("ARE YOU SURE?", 460.0)
		_confirm_layer = ov[0]
		var v: VBoxContainer = ov[1]
		var q := _label("Do you want to quit the game?", _font_ui, 24, PALE)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(q)
		var yes := _make_item(v, "Yes", PixelItem.Kind.BUTTON, 30)
		var no := _make_item(v, "No", PixelItem.Kind.BUTTON, 30)
		yes.activated.connect(_do_quit)
		no.activated.connect(_close_confirm)
		var cits: Array = [yes, no]
		_wrap_nav(cits)
		_confirm_layer.set_meta("no", no)
	_open_overlay(_confirm_layer, _confirm_layer.get_meta("no"))


func _close_confirm() -> void:
	if _confirm_layer != null:
		_close_overlay(_confirm_layer)


func _do_quit() -> void:
	if _busy:
		return
	_busy = true
	AudioManager.play_ui("back")
	AudioManager.stop_music(0.8)
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.8)
	t.tween_interval(0.35)
	t.tween_callback(get_tree().quit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _confirm_layer != null and _confirm_layer.visible:
		get_viewport().set_input_as_handled()
		_close_confirm()
		return
	if event.is_action_pressed("ui_cancel") and _diff_layer.visible:
		get_viewport().set_input_as_handled()
		_close_overlay(_diff_layer)
		return
	if event.is_action_pressed("ui_cancel") and _slots_layer != null and _slots_layer.visible:
		get_viewport().set_input_as_handled()
		_close_overlay(_slots_layer)
		return
	if event.is_action_pressed("ui_cancel") and _ach_layer != null and _ach_layer.visible:
		get_viewport().set_input_as_handled()
		_close_overlay(_ach_layer)
		return
	if event.is_action_pressed("ui_cancel") and _about_layer.visible:
		get_viewport().set_input_as_handled()
		_close_about()
		return
	if event.is_action_pressed("ui_cancel") and _settings.visible:
		get_viewport().set_input_as_handled()
		_settings.close()
		return
	if get_viewport().gui_get_focus_owner() == null and not _settings.visible and not _about_layer.visible \
			and not _diff_layer.visible and not (_slots_layer != null and _slots_layer.visible):
		if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up") \
				or event.is_action_pressed("ui_accept"):
			get_viewport().set_input_as_handled()
			_main_items[0].grab_focus()


func _build_toast() -> void:
	_toast = _label("", _font_ui_bold, 26, GOLD)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast.offset_bottom = -110
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_toast.add_theme_color_override("font_outline_color", Color("0b0820"))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _show_toast(text: String) -> void:
	_toast.text = text
	var t := create_tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.2)
	t.tween_interval(2.2)
	t.tween_property(_toast, "modulate:a", 0.0, 0.5)


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _play_intro() -> void:
	create_tween().tween_property(_fade, "color:a", 0.0, 1.6)
	var hero_timer := Timer.new()
	hero_timer.one_shot = true
	hero_timer.wait_time = 0.7
	add_child(hero_timer)
	hero_timer.timeout.connect(func(): _stage.start_hero())
	hero_timer.start()
	var t := create_tween().set_parallel(true)
	for i in _main_items.size():
		var it: Control = _main_items[i]
		it.modulate.a = 0.0
		t.tween_property(it, "modulate:a", 1.0, 0.5).set_delay(0.8 + i * 0.14)
	for l in _title_labels:
		l.modulate.a = 0.0
		t.tween_property(l, "modulate:a", 1.0, 1.2).set_delay(0.3)
	var first: Control = _main_items[0]
	first.silent_focus = true
	first.grab_focus.call_deferred()
