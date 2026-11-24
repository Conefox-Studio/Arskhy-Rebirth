extends Control

signal closed

var inline_mode := false
var inline_left := 520.0
const UiSkin = preload("res://scripts/ui_skin.gd")
const INLINE_BG_ALPHA := 0.9

const PixelItem = preload("res://scripts/menu_item.gd")
const KeybindPanel = preload("res://scripts/keybind_panel.gd")
const TouchEditor = preload("res://scripts/touch_layout_editor.gd")

const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"

const GOLD := Color("f6d776")

var _font_title: Font
var _font_ui: Font
var _font_ui_bold: Font

var _settings_nav: Array = []
var _row_mode: Control
var _row_res: Control
var _row_scale: Control
var _row_vsync: Control
var _row_shadow: Control
var _row_render: Control
var _row_fog: Control
var _row_godrays: Control
var _row_godray_power: Control
var _row_flashes: Control
var _row_wild: Control
var _row_daynight: Control
var _row_lighting: Control
var _row_shadow_shader: Control
var _row_bloom: Control
var _row_grain: Control
var _row_chromatic: Control
var _row_text_speed: Control
var _row_text_size: Control
var _row_box_opacity: Control
var _row_typing_sound: Control
var _row_hints: Control
var _row_hint_style: Control
var _row_touch_opacity: Control
var _row_touch_mode: Control
var _row_hud_layout: Control
var _row_touch_size: Control
var _btn_keybinds: Control
var _btn_touch_edit: Control
var _keybind_panel: Control
var _row_volume := {}


var _pages: Array = []
var _tab_items: Array = []
var _row_wind: Control
var _row_perf: Control
var _scroll: ScrollContainer
var _cur_tab := 0
const TAB_NAMES: Array[String] = ["General", "Graphics", "Environment", "Controls"]


func _ready() -> void:
	_font_title = load(FONT_TITLE)
	_font_ui = load(FONT_UI)
	_font_ui_bold = load(FONT_UI_BOLD)
	_build_settings()


func _build_settings() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	var pw := 620.0 if inline_mode else 700.0

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.0) if inline_mode else Color(0.0, 0.0, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE if inline_mode else Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	var sb: StyleBox = UiSkin.box("panel_dark_a", 14, 0.0) if inline_mode else UiSkin.box("panel_ornate", 22, 0.0)
	sb.content_margin_left = 46
	sb.content_margin_right = 46
	sb.content_margin_top = 40
	sb.content_margin_bottom = 42
	panel.add_theme_stylebox_override("panel", sb)
	if inline_mode:
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", int(inline_left))
		margin.add_theme_constant_override("margin_top", 24)
		margin.add_theme_constant_override("margin_bottom", 24)
		margin.add_theme_constant_override("margin_right", 8)
		add_child(margin)
		panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		margin.add_child(panel)
	else:
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(center)
		center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var title := _label("SETTINGS", _font_title, 40, GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(_make_ornament(pw - 20.0, true))

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 22)
	v.add_child(tabs)
	var tab_fs := 24
	var tab_sep := 22
	while tab_fs > 12:
		var total := 0.0
		for tn in TAB_NAMES:
			total += _font_ui.get_string_size("[ %s ]" % tn, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs).x + tab_fs + 8.0 + 6.0
		total += tab_sep * (TAB_NAMES.size() - 1)
		if total <= pw:
			break
		tab_fs -= 1
		tab_sep = maxi(8, tab_sep - 1)
	tabs.add_theme_constant_override("separation", tab_sep)
	for ti in TAB_NAMES.size():
		var tb := _make_item(tabs, TAB_NAMES[ti], PixelItem.Kind.BUTTON, tab_fs)
		tb.custom_minimum_size.x = _font_ui.get_string_size("[ %s ]" % TAB_NAMES[ti], HORIZONTAL_ALIGNMENT_LEFT, -1, tab_fs).x + tab_fs + 8.0 + 6.0
		var tidx := ti
		tb.activated.connect(func(): _set_tab(tidx))
		tb.focus_entered.connect(func():
			if _cur_tab != tidx:
				_set_tab(tidx))
		_tab_items.append(tb)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(pw, 372 if inline_mode else 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	var scroll_holder := Control.new()
	scroll_holder.custom_minimum_size = scroll.custom_minimum_size
	v.add_child(scroll_holder)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_holder.add_child(scroll)
	_add_scroll_hint(scroll_holder, scroll)

	_scroll = scroll
	var pages_box := VBoxContainer.new()
	pages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages_box)
	for pi in 4:
		var pg := VBoxContainer.new()
		pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pg.add_theme_constant_override("separation", 2)
		pg.visible = pi == 0
		pages_box.add_child(pg)
		_pages.append(pg)
	var rows: VBoxContainer = _pages[0]

	rows.add_child(_header("DISPLAY"))

	_row_mode = _make_item(rows, "Window Mode", PixelItem.Kind.CHOICE, 26)
	_row_mode.options = GameSettings.WINDOW_MODES.duplicate()
	_row_mode.changed.connect(func():
		GameSettings.window_mode = _row_mode.index
		GameSettings.apply_display()
		_sync_settings_rows())

	var res_opts: Array[String] = []
	for r in GameSettings.RESOLUTIONS:
		res_opts.append("%d x %d" % [r.x, r.y])
	_row_res = _make_item(rows, "Resolution", PixelItem.Kind.CHOICE, 26)
	_row_res.options = res_opts
	_row_res.changed.connect(func():
		GameSettings.resolution_index = _row_res.index
		GameSettings.apply_display())

	var scale_opts: Array[String] = []
	for s in GameSettings.SCALES:
		scale_opts.append("%d%%" % roundi(s * 100.0))
	_row_scale = _make_item(rows, "Window Scale", PixelItem.Kind.CHOICE, 26)
	_row_scale.options = scale_opts
	_row_scale.changed.connect(func():
		GameSettings.scale_index = _row_scale.index
		GameSettings.apply_display())

	_row_vsync = _make_item(rows, "VSync", PixelItem.Kind.CHOICE, 26)
	var vsync_opts: Array[String] = ["On", "Off"]
	_row_vsync.options = vsync_opts
	_row_vsync.changed.connect(func():
		GameSettings.vsync = _row_vsync.index == 0
		GameSettings.apply_display())

	rows = _pages[1]
	rows.add_child(_header("GRAPHICS"))

	_row_perf = _make_item(rows, "Performance", PixelItem.Kind.CHOICE, 26)
	_row_perf.options = GameSettings.PERF_NAMES.duplicate()
	_row_perf.changed.connect(func():
		GameSettings.perf_index = _row_perf.index
		if _row_perf.index >= 2:
			GameSettings.apply_perf_preset(_row_perf.index)
		GameSettings.apply_graphics()
		_sync_settings_rows())

	_row_shadow = _make_item(rows, "Shadows", PixelItem.Kind.CHOICE, 26)
	_row_shadow.options = GameSettings.SHADOW_NAMES.duplicate()
	_row_shadow.changed.connect(func():
		GameSettings.shadow_index = _row_shadow.index
		GameSettings.apply_graphics())

	_row_render = _make_item(rows, "Render Map", PixelItem.Kind.CHOICE, 26)
	_row_render.options = GameSettings.RENDER_MAP_NAMES.duplicate()
	_row_render.changed.connect(func():
		GameSettings.render_map_index = _row_render.index
		GameSettings.apply_graphics())

	var on_off: Array[String] = ["On", "Off"]
	rows = _pages[2]
	rows.add_child(_header("ENVIRONMENT"))
	_row_fog = _make_item(rows, "Fog", PixelItem.Kind.CHOICE, 26)
	_row_fog.options = on_off.duplicate()
	_row_fog.changed.connect(func():
		GameSettings.fog = _row_fog.index == 0
		GameSettings.apply_graphics())

	_row_godrays = _make_item(rows, "God Rays (High-end)", PixelItem.Kind.CHOICE, 26)
	_row_godrays.options = on_off.duplicate()
	_row_godrays.changed.connect(func():
		GameSettings.godrays = _row_godrays.index == 0
		GameSettings.apply_graphics())

	_row_godray_power = _make_item(rows, "God Ray Brightness", PixelItem.Kind.SLIDER, 26)
	_row_godray_power.changed.connect(func():
		GameSettings.godray_strength = _row_godray_power.value
		GameSettings.apply_graphics())

	rows = _pages[1]
	_row_flashes = _make_item(rows, "Flashing Effects", PixelItem.Kind.CHOICE, 26)
	_row_flashes.options = on_off.duplicate()
	_row_flashes.changed.connect(func():
		GameSettings.flashes = _row_flashes.index == 0
		GameSettings.save_settings())

	rows = _pages[2]
	_row_wild = _make_item(rows, "Ambient Wildlife (Parallax)", PixelItem.Kind.CHOICE, 26)
	_row_wild.options = on_off.duplicate()
	_row_wild.changed.connect(func():
		GameSettings.wildlife = _row_wild.index == 0
		GameSettings.apply_graphics())

	_row_daynight = _make_item(rows, "Day / Night Cycle", PixelItem.Kind.CHOICE, 26)
	_row_daynight.options = on_off.duplicate()
	_row_daynight.changed.connect(func():
		GameSettings.day_night = _row_daynight.index == 0
		GameSettings.apply_graphics())

	_row_wind = _make_item(rows, "Wind (VFX)", PixelItem.Kind.CHOICE, 26)
	_row_wind.options = on_off.duplicate()
	_row_wind.changed.connect(func():
		GameSettings.wind = _row_wind.index == 0
		GameSettings.apply_graphics())

	rows = _pages[1]
	_row_lighting = _make_item(rows, "Soft Lighting (High-end)", PixelItem.Kind.CHOICE, 26)
	_row_lighting.options = on_off.duplicate()
	_row_lighting.changed.connect(func():
		GameSettings.soft_lighting = _row_lighting.index == 0
		GameSettings.apply_graphics())

	_row_shadow_shader = _make_item(rows, "Soft Shadow Shader", PixelItem.Kind.CHOICE, 26)
	_row_shadow_shader.options = on_off.duplicate()
	_row_shadow_shader.changed.connect(func():
		GameSettings.shadow_shader = _row_shadow_shader.index == 0
		GameSettings.apply_graphics())

	_row_bloom = _make_item(rows, "Bloom (Shader)", PixelItem.Kind.CHOICE, 26)
	_row_bloom.options = on_off.duplicate()
	_row_bloom.changed.connect(func():
		GameSettings.bloom = _row_bloom.index == 0
		GameSettings.apply_graphics())

	_row_grain = _make_item(rows, "Film Grain (Shader)", PixelItem.Kind.CHOICE, 26)
	_row_grain.options = on_off.duplicate()
	_row_grain.changed.connect(func():
		GameSettings.film_grain = _row_grain.index == 0
		GameSettings.apply_graphics())

	_row_chromatic = _make_item(rows, "Chromatic Aberration", PixelItem.Kind.CHOICE, 26)
	_row_chromatic.options = on_off.duplicate()
	_row_chromatic.changed.connect(func():
		GameSettings.chromatic = _row_chromatic.index == 0
		GameSettings.apply_graphics())

	rows = _pages[0]
	rows.add_child(_header("AUDIO"))
	for bus_name in GameSettings.BUSES:
		var row := _make_item(rows, GameSettings.BUS_LABELS[bus_name], PixelItem.Kind.SLIDER, 26)
		row.changed.connect(func(): GameSettings.set_volume(bus_name, row.value))
		_row_volume[bus_name] = row

	rows.add_child(_header("DIALOG"))

	_row_text_speed = _make_item(rows, "Text Speed", PixelItem.Kind.CHOICE, 26)
	_row_text_speed.options = GameSettings.TEXT_SPEED_NAMES.duplicate()
	_row_text_speed.changed.connect(func():
		GameSettings.text_speed_index = _row_text_speed.index)

	_row_text_size = _make_item(rows, "Text Size", PixelItem.Kind.CHOICE, 26)
	_row_text_size.options = GameSettings.TEXT_SIZE_NAMES.duplicate()
	_row_text_size.changed.connect(func():
		GameSettings.text_size_index = _row_text_size.index)

	_row_box_opacity = _make_item(rows, "Dialog Box", PixelItem.Kind.CHOICE, 26)
	_row_box_opacity.options = GameSettings.BOX_OPACITY_NAMES.duplicate()
	_row_box_opacity.changed.connect(func():
		GameSettings.box_opacity_index = _row_box_opacity.index)

	_row_typing_sound = _make_item(rows, "Typing Sound", PixelItem.Kind.CHOICE, 26)
	var snd_opts: Array[String] = ["On", "Off"]
	_row_typing_sound.options = snd_opts
	_row_typing_sound.changed.connect(func():
		GameSettings.typing_sound = _row_typing_sound.index == 0)

	rows = _pages[3]
	rows.add_child(_header("CONTROLS"))

	_row_hints = _make_item(rows, "Control Hints", PixelItem.Kind.CHOICE, 26)
	_row_hints.options = on_off.duplicate()
	_row_hints.changed.connect(func():
		GameSettings.control_hints = _row_hints.index == 0
		GameSettings.apply_controls()
		_sync_settings_rows())

	_row_hint_style = _make_item(rows, "Icon Style", PixelItem.Kind.CHOICE, 26)
	_row_hint_style.options = GameSettings.HINT_STYLE_NAMES.duplicate()
	_row_hint_style.changed.connect(func():
		GameSettings.hint_style_index = _row_hint_style.index
		GameSettings.apply_controls())

	_row_touch_mode = _make_item(rows, "Touch Controls", PixelItem.Kind.CHOICE, 26)
	_row_touch_mode.options = GameSettings.TOUCH_MODE_NAMES.duplicate()
	_row_touch_mode.changed.connect(func():
		GameSettings.touch_mode_index = _row_touch_mode.index
		GameSettings.apply_controls())

	_row_touch_opacity = _make_item(rows, "Touch Opacity (Mobile)", PixelItem.Kind.CHOICE, 26)
	_row_touch_opacity.options = GameSettings.TOUCH_OPACITY_NAMES.duplicate()
	_row_touch_opacity.changed.connect(func():
		GameSettings.touch_opacity_index = _row_touch_opacity.index
		GameSettings.apply_controls())

	_row_touch_size = _make_item(rows, "Touch Button Size", PixelItem.Kind.CHOICE, 26)
	_row_touch_size.options = GameSettings.TOUCH_SIZE_NAMES.duplicate()
	_row_touch_size.changed.connect(func():
		GameSettings.touch_size_index = _row_touch_size.index
		GameSettings.apply_controls())

	_row_hud_layout = _make_item(rows, "HUD Position (HP Bar)", PixelItem.Kind.CHOICE, 26)
	_row_hud_layout.options = GameSettings.HUD_LAYOUT_NAMES.duplicate()
	_row_hud_layout.changed.connect(func():
		GameSettings.hud_layout_index = _row_hud_layout.index
		GameSettings.apply_controls())

	_btn_touch_edit = _make_item(rows, "Edit Touch Layout", PixelItem.Kind.BUTTON, 26)
	_btn_touch_edit.activated.connect(_open_touch_editor)

	_btn_keybinds = _make_item(rows, "Keybinds (Keyboard / Gamepad)", PixelItem.Kind.BUTTON, 26)
	_btn_keybinds.activated.connect(func():
		_keybind_panel.open())

	v.add_child(_make_ornament(pw - 20.0, true))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 48)
	v.add_child(buttons)
	var reset_btn := _make_item(buttons, "Reset Default", PixelItem.Kind.BUTTON, 26)
	var back_btn := _make_item(buttons, "Back", PixelItem.Kind.BUTTON, 26)
	reset_btn.custom_minimum_size.x = 260
	back_btn.custom_minimum_size.x = 160
	reset_btn.activated.connect(func():
		GameSettings.reset_to_default()
		_sync_settings_rows())
	back_btn.activated.connect(close)

	_settings_nav = _tab_items.duplicate()
	_settings_nav.append_array([_row_mode, _row_res, _row_scale, _row_vsync,
		_row_perf, _row_shadow, _row_render, _row_fog, _row_godrays, _row_godray_power, _row_flashes, _row_wild, _row_daynight, _row_wind, _row_lighting,
		_row_shadow_shader, _row_bloom, _row_grain, _row_chromatic])
	for bus_name in GameSettings.BUSES:
		_settings_nav.append(_row_volume[bus_name])
	_settings_nav.append_array([_row_text_speed, _row_text_size, _row_box_opacity, _row_typing_sound,
		_row_hints, _row_hint_style, _row_touch_mode, _row_touch_opacity])
	_settings_nav.append_array([_row_touch_size, _row_hud_layout, _btn_touch_edit, _btn_keybinds])
	_settings_nav.append(reset_btn)
	_settings_nav.append(back_btn)

	_keybind_panel = KeybindPanel.new()
	add_child(_keybind_panel)
	_keybind_panel.closed.connect(func():
		_btn_keybinds.grab_focus())


func _add_scroll_hint(holder: Control, scroll: ScrollContainer) -> void:
	var hint := Control.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(hint)
	var bar := scroll.get_v_scroll_bar()
	hint.draw.connect(func():
		var mx := bar.max_value - bar.page
		if mx <= 1.0:
			return
		var h := hint.size.y
		var th := maxf(28.0, h * bar.page / bar.max_value)
		var ty := (h - th) * clampf(bar.value / mx, 0.0, 1.0)
		hint.draw_rect(Rect2(hint.size.x - 5.0, 0.0, 3.0, h), Color(1, 1, 1, 0.08))
		hint.draw_rect(Rect2(hint.size.x - 5.0, ty, 3.0, th), Color(GOLD, 0.7))
		if bar.value > 2.0:
			hint.draw_colored_polygon(PackedVector2Array([Vector2(hint.size.x * 0.5 - 8, 12), Vector2(hint.size.x * 0.5 + 8, 12), Vector2(hint.size.x * 0.5, 2)]), Color(GOLD, 0.8))
		if bar.value < mx - 2.0:
			hint.draw_colored_polygon(PackedVector2Array([Vector2(hint.size.x * 0.5 - 8, h - 12), Vector2(hint.size.x * 0.5 + 8, h - 12), Vector2(hint.size.x * 0.5, h - 2)]), Color(GOLD, 0.8)))
	bar.value_changed.connect(func(_v): hint.queue_redraw())
	bar.changed.connect(hint.queue_redraw)


func _open_touch_editor() -> void:
	var ed := TouchEditor.new()
	get_tree().root.add_child(ed)
	ed.closed.connect(func():
		_btn_touch_edit.grab_focus())


func _header(text: String) -> Label:
	var l := _label("-  %s  -" % text, _font_ui_bold, 22, Color("6f8fd8"))
	l.custom_minimum_size.y = 40
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _sync_settings_rows() -> void:
	_row_mode.set_index(GameSettings.window_mode)
	_row_res.set_index(GameSettings.resolution_index)
	_row_scale.set_index(GameSettings.scale_index)
	_row_vsync.set_index(0 if GameSettings.vsync else 1)
	_row_perf.set_index(GameSettings.perf_index)
	_row_wind.set_index(0 if GameSettings.wind else 1)
	_row_shadow.set_index(GameSettings.shadow_index)
	_row_render.set_index(GameSettings.render_map_index)
	_row_fog.set_index(0 if GameSettings.fog else 1)
	_row_godrays.set_index(0 if GameSettings.godrays else 1)
	_row_flashes.set_index(0 if GameSettings.flashes else 1)
	_row_godray_power.set_value(GameSettings.godray_strength)
	_row_wild.set_index(0 if GameSettings.wildlife else 1)
	_row_daynight.set_index(0 if GameSettings.day_night else 1)
	_row_lighting.set_index(0 if GameSettings.soft_lighting else 1)
	_row_shadow_shader.set_index(0 if GameSettings.shadow_shader else 1)
	_row_bloom.set_index(0 if GameSettings.bloom else 1)
	_row_grain.set_index(0 if GameSettings.film_grain else 1)
	_row_chromatic.set_index(0 if GameSettings.chromatic else 1)
	_row_text_speed.set_index(GameSettings.text_speed_index)
	_row_text_size.set_index(GameSettings.text_size_index)
	_row_box_opacity.set_index(GameSettings.box_opacity_index)
	_row_typing_sound.set_index(0 if GameSettings.typing_sound else 1)
	_row_hints.set_index(0 if GameSettings.control_hints else 1)
	_row_hint_style.set_index(GameSettings.hint_style_index)
	_row_touch_mode.set_index(GameSettings.touch_mode_index)
	_row_touch_opacity.set_index(GameSettings.touch_opacity_index)
	_row_touch_size.set_index(GameSettings.touch_size_index)
	_row_hud_layout.set_index(GameSettings.hud_layout_index)
	_row_hint_style.set_disabled(not GameSettings.control_hints)
	_row_res.set_disabled(GameSettings.window_mode != 0)
	for bus_name in GameSettings.BUSES:
		_row_volume[bus_name].set_value(GameSettings.volumes[bus_name])
	_rebuild_settings_nav()


func _on_active_page(it: Control) -> bool:
	var p: Node = it.get_parent()
	while p != null:
		if _pages.has(p):
			return (p as Control).visible
		p = p.get_parent()
	return true


func _set_tab(i: int) -> void:
	_cur_tab = i
	for pi in _pages.size():
		(_pages[pi] as Control).visible = pi == i
	for ti in _tab_items.size():
		var tb: Control = _tab_items[ti]
		tb.title = ("[ %s ]" % TAB_NAMES[ti]) if ti == i else TAB_NAMES[ti]
		tb.queue_redraw()
	if _scroll != null:
		_scroll.scroll_vertical = 0
	_rebuild_settings_nav()


func _rebuild_settings_nav() -> void:
	var live := _settings_nav.filter(func(i): return not i.disabled and _on_active_page(i))
	var n := live.size()
	var reset_btn: Control = live[n - 2]
	var back_btn: Control = live[n - 1]
	for i in n:
		var it: Control = live[i]
		it.focus_neighbor_top = it.get_path_to(live[(i - 1 + n) % n])
		it.focus_neighbor_bottom = it.get_path_to(live[(i + 1) % n])
		it.focus_neighbor_left = it.get_path_to(it)
		it.focus_neighbor_right = it.get_path_to(it)
	reset_btn.focus_neighbor_right = reset_btn.get_path_to(back_btn)
	back_btn.focus_neighbor_left = back_btn.get_path_to(reset_btn)
	var last_row: Control = live[n - 3]
	reset_btn.focus_neighbor_top = reset_btn.get_path_to(last_row)
	back_btn.focus_neighbor_top = back_btn.get_path_to(last_row)
	reset_btn.focus_neighbor_bottom = reset_btn.get_path_to(live[0])
	back_btn.focus_neighbor_bottom = back_btn.get_path_to(live[0])
	live[0].focus_neighbor_top = live[0].get_path_to(reset_btn)
	last_row.focus_neighbor_bottom = last_row.get_path_to(reset_btn)
	for ti in _tab_items.size():
		var tb: Control = _tab_items[ti]
		tb.focus_neighbor_left = tb.get_path_to(_tab_items[(ti - 1 + _tab_items.size()) % _tab_items.size()])
		tb.focus_neighbor_right = tb.get_path_to(_tab_items[(ti + 1) % _tab_items.size()])
		tb.focus_neighbor_bottom = tb.get_path_to(live[_tab_items.size()])
		tb.focus_neighbor_top = tb.get_path_to(reset_btn)
	var first_row: Control = live[_tab_items.size()]
	first_row.focus_neighbor_top = first_row.get_path_to(_tab_items[_cur_tab])


func _label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


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


func open() -> void:
	if visible:
		return
	_set_tab(0)
	_sync_settings_rows()
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)
	var first: Control = _settings_nav[_tab_items.size()]
	first.silent_focus = true
	first.grab_focus()


func close() -> void:
	if not visible:
		return
	GameSettings.save_settings()
	AudioManager.play_ui("back")
	hide()
	closed.emit()


