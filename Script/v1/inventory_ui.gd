extends CanvasLayer

const UiSkin = preload("res://scripts/ui_skin.gd")
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const GOLD := Color("f6d776")
const BAR_SLOT := 64.0
const GEM_DIR := "res://assets/gems/arskhy_gem_%02d.png"
const GEM_FRAME_COUNT := 11
const GEM_BLUE := Color("5ec8ff")
const FLAT_COUNT := 15

var enabled := true
var _player: CharacterBody2D
var _root: Control
var _bar: Control
var _panel_root: Control
var _open := false
var _bar_slots: Array[Panel] = []
var _font: Font
var _font_bold: Font
var _sel_kind := "item"
var _sel_idx := 0
var _slots := {}
var _desc_icon: TextureRect
var _desc_name: Label
var _desc_text: Label
var _hint: Label
var _btn_equip: Button
var _btn_drop: Button
var _btn_discard: Button
var _count_items: Label
var _count_keys: Label
var _stat_bars := {}
var _discard_armed := 0.0
var _msg_id := 0
var _gem_frames: Array = []
var _gem_view := false
var _gem_sel := 0
var _gem_t := 0.0


class DragSlot extends Panel:
	var kind := ""
	var idx := 0
	var get_item: Callable
	var on_drop: Callable
	var on_click: Callable

	func _get_drag_data(_pos: Vector2) -> Variant:
		var it = get_item.call()
		if it == null or kind == "key" or kind == "gem":
			return null
		var prev := TextureRect.new()
		prev.texture = it.icon if (String(it.get("id", "")).begins_with("potion") or String(it.get("id", "")).contains("map")) else null
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prev.size = Vector2(52, 52)
		prev.position = Vector2(-26, -26)
		prev.modulate.a = 0.9
		var holder := Control.new()
		holder.add_child(prev)
		set_drag_preview(holder)
		on_click.call(kind, idx)
		return {"kind": kind, "idx": idx}

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return kind != "key" and kind != "gem" and data is Dictionary and data.has("kind") and String(data["kind"]) != "key" and String(data["kind"]) != "gem"

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		on_drop.call(String(data["kind"]), int(data["idx"]), kind, idx)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_click.call(kind, idx)


class StatBar extends Control:
	var tag := ""
	var fill := Color.WHITE
	var cur := 0
	var mx := 1
	var font: Font

	func _init(t: String, c: Color, f: Font) -> void:
		tag = t
		fill = c
		font = f
		custom_minimum_size = Vector2(0, 22)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func set_values(c: int, m: int) -> void:
		if c == cur and m == mx:
			return
		cur = c
		mx = maxi(1, m)
		queue_redraw()

	func _draw() -> void:
		var bx := 40.0
		var bw := maxf(10.0, size.x - bx - 62.0)
		var by := 6.0
		var bh := 10.0
		draw_string(font, Vector2(0, 16), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e8dcb0"))
		draw_rect(Rect2(bx - 1, by - 1, bw + 2, bh + 2), Color.BLACK)
		draw_rect(Rect2(bx, by, bw, bh), Color(0.12, 0.13, 0.11))
		var f := clampf(float(cur) / float(mx), 0.0, 1.0)
		if f > 0.0:
			draw_rect(Rect2(bx, by, bw * f, bh), fill)
			draw_rect(Rect2(bx, by, bw * f, bh * 0.4), Color(1, 1, 1, 0.28))
		draw_string(font, Vector2(bx + bw + 8.0, 16), "%d/%d" % [cur, mx], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func setup(player: CharacterBody2D) -> void:
	_player = player


func _ready() -> void:
	layer = 9
	_font = load(FONT_UI)
	_font_bold = load(FONT_UI_BOLD)
	for i in GEM_FRAME_COUNT:
		_gem_frames.append(load(GEM_DIR % i))
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel_root = Control.new()
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.visible = false
	_root.add_child(_panel_root)
	_build_bar()
	Inventory.changed.connect(_on_inv_changed)
	Inventory.selected_changed.connect(_refresh_bar)
	_refresh_bar()


func is_open() -> bool:
	return _open


func _process(delta: float) -> void:
	if _discard_armed > 0.0:
		_discard_armed -= delta
		if _discard_armed <= 0.0 and _btn_discard != null:
			_btn_discard.text = "Discard"
	if _open:
		_refresh_stats()
		_gem_t += delta
		var gf: Texture2D = _gem_frames[int(_gem_t * 10.0) % GEM_FRAME_COUNT] if not _gem_frames.is_empty() else null
		for key in _slots:
			var gs: DragSlot = _slots[key]
			if gs.kind == "gem":
				(gs.get_node("Icon") as TextureRect).texture = gf


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", _font_bold if bold else _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _bar_style(selected: bool, hover: bool) -> StyleBox:
	var sb := UiSkin.slot(selected)
	return sb


func _make_bar_slot(size: float, key_text: String) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.modulate = Color(1, 1, 1, 0.82)
	p.add_theme_stylebox_override("panel", _bar_style(false, false))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	var count := _label("", 18, Color.WHITE)
	count.name = "Count"
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -40
	count.offset_top = -26
	count.offset_right = -6
	count.offset_bottom = -2
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(count)
	var k := _label(key_text, 16, Color(0.9, 0.85, 0.6, 0.8))
	k.position = Vector2(8, 2)
	p.add_child(k)
	return p


func _build_bar() -> void:
	_bar = BoxContainer.new()
	(_bar as BoxContainer).vertical = true
	_bar.add_theme_constant_override("separation", 10)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bar)
	for i in Inventory.HOTBAR_COUNT:
		var s := _make_bar_slot(BAR_SLOT, str(i + 1))
		_bar.add_child(s)
		_bar_slots.append(s)
	_bar.modulate.a = 0.0
	create_tween().tween_property(_bar, "modulate:a", 1.0, 1.0).set_delay(1.4)
	for i in _bar_slots.size():
		var idx := i
		_bar_slots[i].gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT \
					and DeviceMode.is_touch() and not _open:
				Inventory.select(idx)
				if Inventory.use_quick(_player):
					AudioManager.play_ui("select"))
	DeviceMode.mode_changed.connect(func(_m): _layout_bar())
	GameSettings.controls_changed.connect(_layout_bar)
	_layout_bar()


func _layout_bar() -> void:
	var touch := DeviceMode.is_touch()
	var sz := 46.0 if touch else BAR_SLOT
	(_bar as BoxContainer).vertical = not touch
	if touch:
		_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_bar.offset_left = -(sz + 5.0)
		_bar.offset_right = sz + 5.0
		_bar.offset_top = -(sz + 14.0)
		_bar.offset_bottom = -14.0
		var d: Vector2 = GameSettings.touch_layout.get("BAR", Vector2.ZERO)
		_bar.offset_left += d.x
		_bar.offset_right += d.x
		_bar.offset_top += d.y
		_bar.offset_bottom += d.y
	else:
		_bar.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_bar.offset_left = -(20.0 + BAR_SLOT)
		_bar.offset_right = -20.0
		_bar.offset_top = -(BAR_SLOT + 5.0)
		_bar.offset_bottom = BAR_SLOT + 5.0
	for s in _bar_slots:
		s.custom_minimum_size = Vector2(sz, sz)


static func _icon_of(item) -> Texture2D:
	var id := String(item.get("id", ""))
	if id.begins_with("potion") or id.contains("map") or id == "arskhy_gem":
		return item.get("icon")
	return null


func _fill_slot(slot: Panel, item) -> void:
	var icon: TextureRect = slot.get_node("Icon")
	var count: Label = slot.get_node("Count")
	if item == null:
		icon.texture = null
		count.text = ""
	else:
		icon.texture = _icon_of(item)
		count.text = ("Lv%d" % int(item.level)) if item.has("level") else ("" if int(item.count) <= 1 else str(int(item.count)))


func _refresh_bar() -> void:
	for i in _bar_slots.size():
		_fill_slot(_bar_slots[i], Inventory.hotbar[i])
		_bar_slots[i].add_theme_stylebox_override("panel", _bar_style(i == Inventory.selected, false))


func _on_inv_changed() -> void:
	_refresh_bar()
	if _open:
		_refresh_panel()


func _item_of(kind: String, idx: int):
	match kind:
		"item":
			return Inventory.pockets[0][idx]
		"key":
			return Inventory.pockets[1][idx]
		"quick":
			return Inventory.hotbar[idx]
		"gem":
			var lv := int(GameState.gem_levels[idx])
			return {"id": "arskhy_gem", "name": "Arskhy Gem  Lv %d" % lv, "count": 1, "key": true, "level": lv,
				"icon": _gem_frames[0] if not _gem_frames.is_empty() else null,
				"desc": "A blue gem bound to Shyrn. Raises Attack, Max HP, Crit, Range and Magic. Upgrade it with gems and coins (max Lv %d). It cannot be dropped, discarded or sold." % GameState.GEM_MAX_LEVEL}
	return null


func _flat_to_sel(f: int) -> Array:
	if f < 8:
		return ["item", f]
	if f < 13:
		return ["key", f - 8]
	return ["quick", f - 13]


func _sel_to_flat() -> int:
	if _sel_kind == "gem":
		return 14
	match _sel_kind:
		"item":
			return _sel_idx
		"key":
			return 8 + _sel_idx
	return 13 + _sel_idx


func _build_panel() -> void:
	for c in _panel_root.get_children():
		c.queue_free()
	_slots.clear()
	var vs := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(dim)

	var P := Vector2(minf(840.0, vs.x - 20.0), minf(540.0, vs.y - 16.0))
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiSkin.box("panel_ornate", 22, 0.0))
	panel.size = P
	panel.position = ((vs - P) * 0.5).floor()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(panel)

	var m := 34.0
	if _gem_view:
		_stat_bars.clear()
		_build_gem_panel(panel, P, m)
		return
	var lw := P.x * 0.55
	var avail_h := P.y - 2.0 * m - 3.0 * 26.0
	var cell := clampf(avail_h / 4.0 - 10.0, 44.0, 78.0)
	cell = minf(cell, (lw - m - 3.0 * 8.0) / 4.0)
	var gap := 8.0

	_count_items = _label("ITEMS", 20, GOLD, true)
	_count_items.position = Vector2(m, m - 6.0)
	panel.add_child(_count_items)
	var y0 := m + 22.0
	for i in 8:
		var s := _make_slot("item", i, cell)
		s.position = Vector2(m + (i % 4) * (cell + gap), y0 + (i / 4) * (cell + gap))
		panel.add_child(s)
	var ky := y0 + 2.0 * (cell + gap) + 6.0
	_count_keys = _label("KEY ITEMS", 20, GOLD, true)
	_count_keys.position = Vector2(m, ky)
	panel.add_child(_count_keys)
	var kc := minf(cell, (lw - m - 4.0 * gap) / 5.0)
	for i in 5:
		var s := _make_slot("key", i, kc)
		s.position = Vector2(m + i * (kc + gap), ky + 26.0)
		panel.add_child(s)
	var qy := ky + 26.0 + kc + 12.0
	var ql := _label("QUICK SLOTS  (drag items here)", 18, Color("cfd6ff"), false)
	ql.position = Vector2(m, qy)
	panel.add_child(ql)
	for i in 2:
		var s := _make_slot("quick", i, cell)
		s.position = Vector2(m + i * (cell + gap), qy + 24.0)
		panel.add_child(s)
		var kt := _label(str(i + 1), 16, Color(0.9, 0.85, 0.6, 0.9))
		kt.position = Vector2(8, 2)
		s.add_child(kt)
	var gx := m + 2.0 * (cell + gap) + 26.0
	var gl := _label("ARSKHY GEMS  (T)", 18, GEM_BLUE, true)
	gl.position = Vector2(gx, qy)
	panel.add_child(gl)
	for i in 2:
		var gs := _make_slot("gem", i, cell)
		gs.position = Vector2(gx + i * (cell + gap), qy + 24.0)
		panel.add_child(gs)

	var rx := lw + 24.0
	var rw := P.x - rx - m
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UiSkin.box("panel_dark_a", 14, 0.0))
	box.position = Vector2(rx, m - 6.0)
	box.size = Vector2(rw, P.y * 0.36)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_desc_icon = TextureRect.new()
	_desc_icon.position = Vector2(14, 14)
	_desc_icon.size = Vector2(52, 52)
	_desc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_desc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_desc_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_desc_icon)
	_desc_name = _label("", 22, GOLD, true)
	_desc_name.position = Vector2(76, 16)
	_desc_name.size = Vector2(rw - 90.0, 30)
	_desc_name.clip_text = true
	box.add_child(_desc_name)
	_desc_text = _label("", 16, Color("e9e4d0"))
	_desc_text.position = Vector2(14, 74)
	_desc_text.size = Vector2(rw - 28.0, box.size.y - 84.0)
	_desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_desc_text)

	var by := m - 6.0 + box.size.y + 12.0
	var bw := (rw - 2.0 * 8.0) / 3.0
	_btn_equip = _make_button("Equip", Vector2(rx, by), Vector2(bw, 40))
	_btn_drop = _make_button("Drop", Vector2(rx + bw + 8.0, by), Vector2(bw, 40))
	_btn_discard = _make_button("Discard", Vector2(rx + 2.0 * (bw + 8.0), by), Vector2(bw, 40))
	for b in [_btn_equip, _btn_drop, _btn_discard]:
		panel.add_child(b)
	_btn_equip.pressed.connect(_do_equip)
	_btn_drop.pressed.connect(_do_drop)
	_btn_discard.pressed.connect(_do_discard)

	var sy := by + 52.0
	_stat_bars.clear()
	for def in [["HP", Color("5be06f")], ["MP", Color("a76bff")], ["RG", Color("e0524a")]]:
		var sb := StatBar.new(def[0], def[1], _font)
		sb.position = Vector2(rx, sy)
		sb.size = Vector2(rw, 22)
		panel.add_child(sb)
		_stat_bars[def[0]] = sb
		sy += 26.0

	_hint = _label("", 15, Color("cfd6ff"))
	_hint.position = Vector2(m, P.y - 34.0)
	_hint.size = Vector2(P.x - 2.0 * m, 22)
	_hint.clip_text = true
	panel.add_child(_hint)
	_hint.text = _hint_default()

	var cb := Button.new()
	cb.text = "X"
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_override("font", _font_bold)
	cb.add_theme_font_size_override("font_size", 18)
	cb.add_theme_stylebox_override("normal", UiSkin.plaque(false))
	cb.add_theme_stylebox_override("hover", UiSkin.plaque(true))
	cb.add_theme_stylebox_override("pressed", UiSkin.plaque(true))
	cb.size = Vector2(44, 34)
	cb.position = Vector2(P.x - 44.0 - 22.0, 18.0)
	cb.pressed.connect(func(): _set_open(false))
	panel.add_child(cb)
	var gb := _make_button("Gems", Vector2(P.x - 44.0 - 22.0 - 96.0, 18.0), Vector2(88, 34))
	gb.pressed.connect(func(): _set_gem_view(true))
	panel.add_child(gb)
	_refresh_panel()


func _hint_default() -> String:
	return "Click an item, drag it to a quick slot. Enter = Equip   G = Drop   Del = Discard   I = Close"


func _make_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = size
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color("f1ead2"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.6, 0.6, 0.6))
	b.add_theme_stylebox_override("normal", UiSkin.plaque(false))
	b.add_theme_stylebox_override("hover", UiSkin.plaque(true))
	b.add_theme_stylebox_override("pressed", UiSkin.plaque(true))
	b.add_theme_stylebox_override("disabled", UiSkin.plaque(false))
	return b


func _make_slot(kind: String, idx: int, size: float) -> DragSlot:
	var p := DragSlot.new()
	p.kind = kind
	p.idx = idx
	p.custom_minimum_size = Vector2(size, size)
	p.size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.get_item = func(): return _item_of(kind, idx)
	p.on_drop = Callable(self, "_on_drop")
	p.on_click = Callable(self, "_on_click")
	p.add_theme_stylebox_override("panel", UiSkin.slot(false))
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	var count := _label("", 16, Color.WHITE)
	count.name = "Count"
	count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -52
	count.offset_top = -24
	count.offset_right = -5
	count.offset_bottom = -1
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(count)
	_slots["%s:%d" % [kind, idx]] = p
	return p


func _refresh_panel() -> void:
	if _slots.is_empty():
		return
	if _gem_view:
		return
	for key in _slots:
		var s: DragSlot = _slots[key]
		_fill_slot(s, _item_of(s.kind, s.idx))
		s.add_theme_stylebox_override("panel", UiSkin.slot(s.kind == _sel_kind and s.idx == _sel_idx))
	var n_items := 0
	for it in Inventory.pockets[0]:
		if it != null:
			n_items += 1
	var n_keys := 0
	for it in Inventory.pockets[1]:
		if it != null:
			n_keys += 1
	_count_items.text = "ITEMS  %d/%d" % [n_items, Inventory.ITEM_SLOTS]
	_count_keys.text = "KEY ITEMS  %d/%d" % [n_keys, Inventory.KEY_SLOTS]
	var item = _item_of(_sel_kind, _sel_idx)
	if item == null:
		_desc_icon.texture = null
		_desc_name.text = "-"
		_desc_text.text = "Select an item."
		_btn_equip.disabled = true
		_btn_drop.disabled = true
		_btn_discard.disabled = true
		_btn_equip.text = "Equip"
		return
	_desc_icon.texture = _icon_of(item)
	_desc_name.text = String(item.name) + ("  x%d" % int(item.count) if int(item.count) > 1 else "")
	_desc_text.text = String(item.desc)
	var is_key := bool(item.get("key", false))
	var equipped := Inventory.hotbar_index_of(item) >= 0
	_btn_equip.text = "Unequip" if equipped else "Equip"
	_btn_equip.disabled = is_key
	if _sel_kind == "gem":
		_btn_equip.text = "Upgrade"
		_btn_equip.disabled = false
	_btn_drop.disabled = is_key
	_btn_discard.disabled = is_key
	if _discard_armed <= 0.0:
		_btn_discard.text = "Discard"


func _refresh_stats() -> void:
	if _player == null or _stat_bars.is_empty():
		return
	(_stat_bars["HP"] as StatBar).set_values(_player.hp, _player.max_hp)
	(_stat_bars["MP"] as StatBar).set_values(_player.mp, _player.max_mp)
	(_stat_bars["RG"] as StatBar).set_values(_player.range_pts, _player.max_range)


func _flash(msg: String) -> void:
	if _hint == null:
		return
	_msg_id += 1
	var my_id := _msg_id
	_hint.text = msg
	get_tree().create_timer(1.8).timeout.connect(func():
		if my_id == _msg_id and _hint != null and is_instance_valid(_hint):
			_hint.text = _hint_default())


func _fmt(n: int) -> String:
	var t := str(absi(n))
	var out := ""
	for i in t.length():
		if i > 0 and (t.length() - i) % 3 == 0:
			out += ","
		out += t[i]
	return ("-" if n < 0 else "") + out


func _set_gem_view(on: bool) -> void:
	_gem_view = on
	_discard_armed = 0.0
	if on:
		_sel_kind = "gem"
		_sel_idx = _gem_sel
	else:
		_sel_kind = "item"
		_sel_idx = 0
	AudioManager.play_ui("select")
	if _open:
		_build_panel()
		_panel_root.modulate.a = 1.0


func _gem_stat_rows(t: float) -> Array:
	var base_hp := float(_player._base_max.hp) if _player != null else 30.0
	var base_mp := float(_player._base_max.mp) if _player != null else 5.0
	var base_rg := float(_player._base_max.range) if _player != null else 10.0
	var base_at := float(_player.ATTACK_DAMAGE) if _player != null else 5.0
	return [
		["ATTACK", _fmt(int(round(GameState.gem_scale_at("attack", base_at, t))))],
		["MAX HP", _fmt(int(round(GameState.gem_scale_at("hp", base_hp, t))))],
		["CRIT", "%.1f%%" % (GameState.gem_crit_at(t) * 100.0)],
		["RANGE", _fmt(int(round(GameState.gem_scale_at("range", base_rg, t))))],
		["MAGIC", _fmt(int(round(GameState.gem_scale_at("mp", base_mp, t))))],
	]


func _build_gem_panel(panel: Panel, P: Vector2, m: float) -> void:
	var title := _label("ARSKHY GEMS", 26, GEM_BLUE, true)
	title.position = Vector2(m, m - 10.0)
	panel.add_child(title)
	var sub := _label("Bound to Shyrn. Cannot be dropped, discarded or sold.", 16, Color("cfd6ff"))
	sub.position = Vector2(m, m + 22.0)
	panel.add_child(sub)
	var cell := minf(112.0, P.y * 0.2)
	var y0 := m + 62.0
	for i in 2:
		var s := _make_slot("gem", i, cell)
		s.position = Vector2(m + i * (cell + 18.0), y0)
		panel.add_child(s)
		var lv := _label("Lv %d / %d" % [int(GameState.gem_levels[i]), GameState.GEM_MAX_LEVEL], 20, Color.WHITE, true)
		lv.position = Vector2(m + i * (cell + 18.0), y0 + cell + 6.0)
		panel.add_child(lv)
		var nm := _label("Gem %d" % (i + 1), 16, Color("cfd6ff"))
		nm.position = Vector2(m + i * (cell + 18.0), y0 + cell + 30.0)
		panel.add_child(nm)
	var wy := y0 + cell + 64.0
	var wallet := _label("You have:  %d gems   %s coins" % [GameState.gems, _fmt(GameState.coins)], 18, Color("f6e7b0"))
	wallet.position = Vector2(m, wy)
	panel.add_child(wallet)
	var cost := GameState.gem_upgrade_cost(_gem_sel)
	var ok := GameState.gem_can_upgrade(_gem_sel)
	var ctext := "Max level reached" if cost.is_empty() else "Upgrade Gem %d to Lv %d:  %d gems + %s coins" % [_gem_sel + 1, int(GameState.gem_levels[_gem_sel]) + 1, int(cost.gems), _fmt(int(cost.coins))]
	var cl := _label(ctext, 18, Color("9be8a8") if ok or cost.is_empty() else Color("ff9a8a"))
	cl.position = Vector2(m, wy + 26.0)
	panel.add_child(cl)
	var bw := 150.0
	_btn_equip = _make_button("Upgrade", Vector2(m, wy + 62.0), Vector2(bw, 40))
	_btn_equip.disabled = not ok
	_btn_equip.pressed.connect(_do_gem_upgrade)
	panel.add_child(_btn_equip)
	var back := _make_button("Back to Bag", Vector2(m + bw + 10.0, wy + 62.0), Vector2(bw, 40))
	back.pressed.connect(func(): _set_gem_view(false))
	panel.add_child(back)
	var rx := m + 2.0 * (cell + 18.0) + 40.0
	var rw := P.x - rx - m
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UiSkin.box("panel_dark_a", 14, 0.0))
	box.position = Vector2(rx, m - 6.0)
	box.size = Vector2(rw, P.y - 2.0 * m - 30.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var th := _label("BONUS  (both gems combined)", 18, GOLD, true)
	th.position = Vector2(16, 12)
	box.add_child(th)
	var now := _gem_stat_rows(GameState.gem_progress())
	var nxt := _gem_stat_rows(GameState.gem_progress_next(_gem_sel))
	var ry := 52.0
	var rowh := minf(56.0, (box.size.y - 70.0) / 5.0)
	for i in now.size():
		var a := _label(String(now[i][0]), 18, Color("e8dcb0"), true)
		a.position = Vector2(16, ry)
		box.add_child(a)
		var b := _label(String(now[i][1]), 20, Color.WHITE, true)
		b.position = Vector2(16, ry + 22.0)
		box.add_child(b)
		if String(nxt[i][1]) != String(now[i][1]):
			var c := _label("-> " + String(nxt[i][1]), 20, Color("9be8a8"), true)
			c.position = Vector2(rw * 0.5, ry + 22.0)
			box.add_child(c)
		ry += rowh
	_hint = _label("", 15, Color("cfd6ff"))
	_hint.position = Vector2(m, P.y - 34.0)
	_hint.size = Vector2(P.x - 2.0 * m, 22)
	_hint.clip_text = true
	panel.add_child(_hint)
	_hint.text = "Left / Right: choose gem    Enter: upgrade    T or Esc: back to bag"
	var cb := Button.new()
	cb.text = "X"
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_override("font", _font_bold)
	cb.add_theme_font_size_override("font_size", 18)
	cb.add_theme_stylebox_override("normal", UiSkin.plaque(false))
	cb.add_theme_stylebox_override("hover", UiSkin.plaque(true))
	cb.add_theme_stylebox_override("pressed", UiSkin.plaque(true))
	cb.size = Vector2(44, 34)
	cb.position = Vector2(P.x - 44.0 - 22.0, 18.0)
	cb.pressed.connect(func(): _set_open(false))
	panel.add_child(cb)
	for key in _slots:
		var gs: DragSlot = _slots[key]
		gs.add_theme_stylebox_override("panel", UiSkin.slot(gs.idx == _gem_sel))


func _do_gem_upgrade() -> void:
	if GameState.gem_upgrade(_gem_sel):
		AudioManager.play_ui("select")
		AudioManager.play_sfx_named("m_charm")
		_build_panel()
		_flash("Gem %d is now Lv %d!" % [_gem_sel + 1, int(GameState.gem_levels[_gem_sel])])
	else:
		AudioManager.play_ui("error")
		_flash("Not enough gems or coins." if int(GameState.gem_levels[_gem_sel]) < GameState.GEM_MAX_LEVEL else "Already at max level.")


func _on_click(kind: String, idx: int) -> void:
	if _gem_view:
		if kind == "gem":
			_gem_sel = idx
			_sel_kind = "gem"
			_sel_idx = idx
			AudioManager.play_ui("tick")
			_build_panel()
		return
	if kind == _sel_kind and idx == _sel_idx:
		return
	_sel_kind = kind
	_sel_idx = idx
	_discard_armed = 0.0
	AudioManager.play_ui("tick")
	_refresh_panel()


func _on_drop(from_kind: String, from_idx: int, to_kind: String, to_idx: int) -> void:
	if to_kind == "quick":
		if from_kind == "item":
			var it = Inventory.pockets[0][from_idx]
			if it != null:
				Inventory.assign_hotbar(to_idx, it)
				_sel_kind = "quick"
				_sel_idx = to_idx
				AudioManager.play_ui("select")
		elif from_kind == "quick" and from_idx != to_idx:
			var a = Inventory.hotbar[from_idx]
			var b = Inventory.hotbar[to_idx]
			Inventory.hotbar[to_idx] = a
			Inventory.hotbar[from_idx] = b
			Inventory.changed.emit()
			AudioManager.play_ui("select")
	elif to_kind == "item":
		if from_kind == "item":
			Inventory.swap_slots(0, from_idx, to_idx)
			_sel_kind = "item"
			_sel_idx = to_idx
			AudioManager.play_ui("select")
		elif from_kind == "quick":
			Inventory.assign_hotbar(from_idx, null)
			AudioManager.play_ui("back")
	_refresh_panel()


func _do_equip() -> void:
	if _sel_kind == "gem":
		_gem_sel = _sel_idx
		_set_gem_view(true)
		return
	var item = _item_of(_sel_kind, _sel_idx)
	if item == null:
		return
	if Inventory.hotbar_index_of(item) >= 0:
		Inventory.unequip(item)
		_flash("Removed from quick slot.")
	else:
		var slot := Inventory.equip(item)
		if slot >= 0:
			_flash("Equipped to quick slot %d." % (slot + 1))
	AudioManager.play_ui("select")
	_refresh_panel()


func _do_drop() -> void:
	var item = _item_of(_sel_kind, _sel_idx)
	if _sel_kind == "gem":
		_flash("Arskhy Gems are bound to you.")
		return
	if item == null or bool(item.get("key", false)):
		return
	var nm := String(item.name)
	Inventory.drop_item(item)
	AudioManager.play_ui("back")
	_flash("Dropped %s." % nm)
	_refresh_panel()


func _do_discard() -> void:
	var item = _item_of(_sel_kind, _sel_idx)
	if _sel_kind == "gem":
		_flash("Arskhy Gems are bound to you.")
		return
	if item == null or bool(item.get("key", false)):
		return
	if _discard_armed <= 0.0:
		_discard_armed = 2.0
		_btn_discard.text = "Sure?"
		return
	_discard_armed = 0.0
	var nm := String(item.name)
	Inventory.discard_item(item)
	AudioManager.play_ui("error")
	_flash("Discarded %s." % nm)
	_refresh_panel()


func _nav(d: int) -> void:
	var f := clampi(_sel_to_flat() + d, 0, FLAT_COUNT - 1)
	var s := _flat_to_sel(f)
	_sel_kind = s[0]
	_sel_idx = s[1]
	_discard_armed = 0.0
	AudioManager.play_ui("tick")
	_refresh_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_set_open(not _open)
		return
	if _open:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			if _gem_view:
				_set_gem_view(false)
			else:
				_set_open(false)
		elif event is InputEventKey and event.pressed and not event.echo:
			if _handle_open_key(event):
				get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed:
			if _handle_open_pad(event):
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("hotbar_1"):
		Inventory.select(0)
	elif event.is_action_pressed("hotbar_2"):
		Inventory.select(1)
	elif event.is_action_pressed("use_quick"):
		if Inventory.use_quick(_player):
			AudioManager.play_ui("select")
		else:
			AudioManager.play_ui("back")


func _handle_open_pad(ev: InputEventJoypadButton) -> bool:
	match ev.button_index:
		JOY_BUTTON_DPAD_LEFT:
			_nav(-1)
		JOY_BUTTON_DPAD_RIGHT:
			_nav(1)
		JOY_BUTTON_DPAD_UP:
			_nav(-4)
		JOY_BUTTON_DPAD_DOWN:
			_nav(4)
		JOY_BUTTON_A:
			_do_equip()
		JOY_BUTTON_X:
			_do_drop()
		JOY_BUTTON_Y:
			_do_discard()
		_:
			return false
	return true


func _handle_open_key(ev: InputEventKey) -> bool:
	if ev.physical_keycode == KEY_T:
		_set_gem_view(not _gem_view)
		return true
	if _gem_view:
		match ev.physical_keycode:
			KEY_LEFT, KEY_A:
				_on_click("gem", 0)
			KEY_RIGHT, KEY_D:
				_on_click("gem", 1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_do_gem_upgrade()
			_:
				return false
		return true
	match ev.physical_keycode:
		KEY_LEFT, KEY_A:
			_nav(-1)
		KEY_RIGHT, KEY_D:
			_nav(1)
		KEY_UP, KEY_W:
			_nav(-4)
		KEY_DOWN, KEY_S:
			_nav(4)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_do_equip()
		KEY_G:
			_do_drop()
		KEY_DELETE, KEY_X:
			_do_discard()
		KEY_1, KEY_KP_1:
			var it = _item_of(_sel_kind, _sel_idx)
			if it != null and _sel_kind != "key":
				Inventory.assign_hotbar(0, it)
		KEY_2, KEY_KP_2:
			var it2 = _item_of(_sel_kind, _sel_idx)
			if it2 != null and _sel_kind != "key":
				Inventory.assign_hotbar(1, it2)
		_:
			return false
	return true


func _set_open(open: bool) -> void:
	if open == _open:
		return
	_open = open
	Inventory.ui_open = open
	if _player != null:
		_player.controls_enabled = not open
	if open:
		_build_panel()
		_panel_root.modulate.a = 0.0
		_panel_root.visible = true
		create_tween().tween_property(_panel_root, "modulate:a", 1.0, 0.15)
		AudioManager.play_ui("select")
	else:
		_gem_view = false
		_panel_root.visible = false
		AudioManager.play_ui("back")


func shutdown() -> void:
	enabled = false
	_open = false
	Inventory.ui_open = false
	_panel_root.visible = false


func _exit_tree() -> void:
	Inventory.ui_open = false
