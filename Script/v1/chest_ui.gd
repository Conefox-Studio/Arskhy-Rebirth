extends CanvasLayer

signal closed

const UiSkin = preload("res://scripts/ui_skin.gd")
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_UI_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const GOLD := Color("f6d776")
const CHEST_SLOTS := 10
const INPUT_LOCK := 0.3


class Slot extends Panel:
	var kind := ""
	var idx := 0
	var get_icon: Callable
	var on_drop: Callable
	var on_click: Callable

	func _get_drag_data(_pos: Vector2) -> Variant:
		var tex = get_icon.call()
		if tex == null:
			return null
		var prev := TextureRect.new()
		prev.texture = tex
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		prev.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prev.size = Vector2(52, 52)
		prev.position = Vector2(-26, -26)
		prev.modulate.a = 0.9
		var holder := Control.new()
		holder.add_child(prev)
		set_drag_preview(holder)
		on_click.call(kind, idx, false, false)
		return {"kind": kind, "idx": idx}

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("kind")

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		on_drop.call(String(data["kind"]), int(data["idx"]), kind, idx)

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_click.call(kind, idx, ev.double_click, ev.shift_pressed)


var active := false

var _slots_data: Array = []
var _panel_root: Control
var _font: Font
var _bold: Font
var _slots := {}
var _sel_kind := "chest"
var _sel_idx := 0
var _lock := 0.0
var _desc_icon: TextureRect
var _desc_name: Label
var _desc_text: Label
var _msg: Label
var _wallet: Label


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_font = load(FONT_UI)
	_bold = load(FONT_UI_BOLD)
	_panel_root = Control.new()
	_panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.visible = false
	add_child(_panel_root)


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _bold if bold else _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_slot(kind: String, idx: int, size: float) -> Slot:
	var p := Slot.new()
	p.kind = kind
	p.idx = idx
	p.custom_minimum_size = Vector2(size, size)
	p.size = Vector2(size, size)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.get_icon = func(): return _icon_at(kind, idx)
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
	count.offset_left = -38
	count.offset_top = -24
	count.offset_right = -5
	count.offset_bottom = -1
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(count)
	_slots["%s:%d" % [kind, idx]] = p
	return p


func _make_button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _bold)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", UiSkin.plaque(false))
	b.add_theme_stylebox_override("hover", UiSkin.plaque(true))
	b.add_theme_stylebox_override("pressed", UiSkin.plaque(true))
	b.position = pos
	b.size = size
	return b


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

	var P := Vector2(minf(780.0, vs.x - 20.0), minf(600.0, vs.y - 16.0))
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiSkin.box("panel_ornate", 22, 0.0))
	panel.size = P
	panel.position = ((vs - P) * 0.5).floor()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(panel)

	var m := 34.0
	var gap := 8.0
	var cell := clampf((P.y - 2.0 * m - 250.0) / 3.0, 44.0, 70.0)
	cell = minf(cell, (P.x - 2.0 * m - 7.0 * gap) / 8.0)

	var t1 := _label("CHEST", 22, GOLD, true)
	t1.position = Vector2(m, m - 8.0)
	panel.add_child(t1)
	var y0 := m + 22.0
	for i in CHEST_SLOTS:
		var s := _make_slot("chest", i, cell)
		s.position = Vector2(m + (i % 5) * (cell + gap), y0 + (i / 5) * (cell + gap))
		panel.add_child(s)
	var gw := 5.0 * cell + 4.0 * gap
	var rx := m + gw + 22.0
	var rw := P.x - rx - m
	var rh := 2.0 * cell + gap
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UiSkin.box("panel_dark_a", 14, 0.0))
	box.position = Vector2(rx, y0)
	box.size = Vector2(rw, rh)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_desc_icon = TextureRect.new()
	_desc_icon.position = Vector2(12, 12)
	_desc_icon.size = Vector2(44, 44)
	_desc_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_desc_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_desc_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_desc_icon)
	_desc_name = _label("", 20, GOLD, true)
	_desc_name.position = Vector2(64, 14)
	_desc_name.size = Vector2(rw - 76.0, 28)
	_desc_name.clip_text = true
	box.add_child(_desc_name)
	_desc_text = _label("", 15, Color("e9e4d0"))
	_desc_text.position = Vector2(12, 62)
	_desc_text.size = Vector2(rw - 24.0, rh - 70.0)
	_desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_desc_text)

	var iy := y0 + 2.0 * (cell + gap) + 8.0
	var t2 := _label("INVENTORY", 22, GOLD, true)
	t2.position = Vector2(m, iy)
	panel.add_child(t2)
	var iy0 := iy + 28.0
	for i in 8:
		var s := _make_slot("item", i, cell)
		s.position = Vector2(m + i * (cell + gap), iy0)
		panel.add_child(s)
	var qy := iy0 + cell + 12.0
	var ql := _label("QUICK SLOTS", 18, Color("cfd6ff"))
	ql.position = Vector2(m, qy)
	panel.add_child(ql)
	for i in 2:
		var s := _make_slot("quick", i, cell)
		s.position = Vector2(m + i * (cell + gap), qy + 24.0)
		panel.add_child(s)
		var kt := _label(str(i + 1), 16, Color(0.9, 0.85, 0.6, 0.9))
		kt.position = Vector2(8, 2)
		s.add_child(kt)
	var bx := m + 2.0 * (cell + gap) + 20.0
	var bw := minf(150.0, (P.x - bx - m - 2.0 * gap) / 3.0)
	_wallet = _label("", 20, Color("f6e7b0"))
	_wallet.position = Vector2(bx, qy + 2.0)
	panel.add_child(_wallet)
	var by := qy + 24.0 + (cell - 40.0) * 0.5
	var b_all := _make_button("Take All", Vector2(bx, by), Vector2(bw, 40))
	var b_close := _make_button("Close", Vector2(bx + bw + gap, by), Vector2(bw, 40))
	panel.add_child(b_all)
	panel.add_child(b_close)
	b_all.pressed.connect(_take_all)
	b_close.pressed.connect(close)
	_msg = _label("", 16, Color("cfd6ff"))
	_msg.position = Vector2(m, P.y - 34.0)
	_msg.size = Vector2(P.x - 2.0 * m, 22)
	_msg.clip_text = true
	panel.add_child(_msg)
	_msg.text = "Double-click / Enter: move    Drag: move or swap    R: take all    E / Esc: close"


func open(data: Array) -> void:
	_slots_data = data
	_sel_kind = "chest"
	_sel_idx = 0
	_lock = INPUT_LOCK
	_build_panel()
	active = true
	_panel_root.visible = true
	if not Inventory.changed.is_connected(_refresh):
		Inventory.changed.connect(_refresh)
	_refresh()


func close() -> void:
	if not active:
		return
	active = false
	_panel_root.visible = false
	if Inventory.changed.is_connected(_refresh):
		Inventory.changed.disconnect(_refresh)
	AudioManager.play_ui("back")
	closed.emit()


func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta


func _chest_entry(i: int):
	return _slots_data[i] if i < _slots_data.size() else null


func _view(kind: String, idx: int):
	match kind:
		"chest":
			var s = _chest_entry(idx)
			if s == null:
				return null
			match String(s.kind):
				"item":
					var it: Dictionary = s.item
					return {"icon": it.get("icon"), "count": int(it.get("count", 1)), "name": String(it.get("name", "Item")), "desc": String(it.get("desc", it.get("description", "")))}
				"coin":
					return {"icon": _atlas("res://assets/fx/coin.png", 0), "count": int(s.n), "name": "Coins", "desc": "Goes straight into your purse."}
				"gem":
					return {"icon": _atlas("res://assets/fx/gems.png", int(s.get("frame", 0))), "count": int(s.n), "name": "Gems", "desc": "Goes straight into your purse."}
		"item", "quick":
			var it2 = Inventory.pockets[0][idx] if kind == "item" else Inventory.hotbar[idx]
			if it2 == null:
				return null
			return {"icon": it2.get("icon"), "count": int(it2.get("count", 1)), "name": String(it2.get("name", "Item")), "desc": String(it2.get("desc", it2.get("description", "")))}
	return null


func _atlas(path: String, frame: int) -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load(path)
	at.region = Rect2(frame * 16, 0, 16, 16)
	return at


func _icon_at(kind: String, idx: int):
	var v = _view(kind, idx)
	return v.icon if v != null else null


func _refresh() -> void:
	if _slots.is_empty():
		return
	for key in _slots:
		var s: Slot = _slots[key]
		var v = _view(s.kind, s.idx)
		(s.get_node("Icon") as TextureRect).texture = v.icon if v != null else null
		(s.get_node("Count") as Label).text = "" if v == null or int(v.count) <= 1 else str(int(v.count))
		s.add_theme_stylebox_override("panel", UiSkin.slot(s.kind == _sel_kind and s.idx == _sel_idx))
	var sv = _view(_sel_kind, _sel_idx)
	_desc_icon.texture = sv.icon if sv != null else null
	_desc_name.text = String(sv.name) if sv != null else ""
	_desc_text.text = String(sv.desc) if sv != null else "Select a slot."
	_wallet.text = "Coins %d     Gems %d" % [GameState.coins, GameState.gems]


func _say(text: String) -> void:
	if _msg != null:
		_msg.text = text


func _on_click(kind: String, idx: int, dbl: bool, shift: bool) -> void:
	var same := kind == _sel_kind and idx == _sel_idx
	_sel_kind = kind
	_sel_idx = idx
	if not same:
		AudioManager.play_ui("tick")
	_refresh()
	if (dbl or shift) and _lock <= 0.0:
		_transfer(kind, idx)


func _first_free_chest() -> int:
	for i in CHEST_SLOTS:
		if _chest_entry(i) == null:
			return i
	return -1


func _take_chest(i: int, silent := false) -> bool:
	var s = _chest_entry(i)
	if s == null:
		return false
	match String(s.kind):
		"item":
			if not Inventory.add_item(s.item.duplicate()):
				_say("Your bag is full.")
				AudioManager.play_ui("error")
				return false
			_say("Took %s." % String(s.item.get("name", "item")))
		"coin":
			GameState.add_coins(int(s.n))
			_say("Took %d coins." % int(s.n))
		"gem":
			GameState.add_gems(int(s.n))
			_say("Took %d gem%s." % [int(s.n), "s" if int(s.n) > 1 else ""])
	_slots_data[i] = null
	if not silent:
		AudioManager.play_ui("select")
	_refresh()
	return true


func _stash(idx: int) -> bool:
	var it = Inventory.pockets[0][idx]
	if it == null:
		return false
	var f := _first_free_chest()
	if f < 0:
		_say("The chest is full.")
		AudioManager.play_ui("error")
		return false
	_slots_data[f] = {"kind": "item", "item": it.duplicate()}
	Inventory.discard_item(it)
	_say("Stored %s." % String(it.get("name", "item")))
	AudioManager.play_ui("select")
	_refresh()
	return true


func _transfer(kind: String, idx: int) -> void:
	match kind:
		"chest":
			_take_chest(idx)
		"item":
			_stash(idx)


func _take_all() -> void:
	var any := false
	for i in CHEST_SLOTS:
		if _take_chest(i, true):
			any = true
	if any:
		AudioManager.play_ui("select")
		_say("Took everything you could carry.")
	else:
		_say("Nothing to take.")


func _on_drop(fk: String, fi: int, tk: String, ti: int) -> void:
	if fk == tk and fi == ti:
		return
	if fk == "chest" and tk == "chest":
		var a = _slots_data[fi]
		_slots_data[fi] = _slots_data[ti]
		_slots_data[ti] = a
		AudioManager.play_ui("select")
	elif fk == "chest":
		var s = _chest_entry(fi)
		if s == null:
			return
		if String(s.kind) != "item" or tk == "quick":
			_take_chest(fi)
		else:
			var cur = Inventory.pockets[0][ti]
			if cur == null:
				Inventory.pockets[0][ti] = s.item
				_slots_data[fi] = null
				Inventory.changed.emit()
				_say("Took %s." % String(s.item.get("name", "item")))
				AudioManager.play_ui("select")
			elif String(cur.get("id", "")) == String(s.item.get("id", "")):
				_take_chest(fi)
			else:
				Inventory.pockets[0][ti] = s.item
				_slots_data[fi] = {"kind": "item", "item": cur}
				Inventory.changed.emit()
				AudioManager.play_ui("select")
	elif tk == "chest":
		if fk != "item":
			return
		var it = Inventory.pockets[0][fi]
		if it == null:
			return
		var s2 = _chest_entry(ti)
		if s2 == null:
			_slots_data[ti] = {"kind": "item", "item": it.duplicate()}
			Inventory.discard_item(it)
			_say("Stored %s." % String(it.get("name", "item")))
			AudioManager.play_ui("select")
		elif String(s2.kind) == "item":
			Inventory.pockets[0][fi] = s2.item
			_slots_data[ti] = {"kind": "item", "item": it}
			Inventory.changed.emit()
			AudioManager.play_ui("select")
		else:
			_stash(fi)
	else:
		if tk == "quick":
			if fk == "item" and Inventory.pockets[0][fi] != null:
				Inventory.assign_hotbar(ti, Inventory.pockets[0][fi])
				AudioManager.play_ui("select")
			elif fk == "quick" and fi != ti:
				var a2 = Inventory.hotbar[fi]
				Inventory.hotbar[fi] = Inventory.hotbar[ti]
				Inventory.hotbar[ti] = a2
				Inventory.changed.emit()
		elif tk == "item":
			if fk == "item":
				Inventory.swap_slots(0, fi, ti)
				AudioManager.play_ui("select")
			elif fk == "quick":
				Inventory.assign_hotbar(fi, null)
				AudioManager.play_ui("back")
	_sel_kind = tk
	_sel_idx = ti
	_refresh()


func _flat() -> Array:
	var f: Array = []
	for i in CHEST_SLOTS:
		f.append(["chest", i])
	for i in 8:
		f.append(["item", i])
	for i in 2:
		f.append(["quick", i])
	return f


func _nav(d: int) -> void:
	var f := _flat()
	var cur := 0
	for i in f.size():
		if f[i][0] == _sel_kind and f[i][1] == _sel_idx:
			cur = i
	var n := posmod(cur + d, f.size())
	_sel_kind = f[n][0]
	_sel_idx = f[n][1]
	AudioManager.play_ui("move")
	_refresh()


func _input(event: InputEvent) -> void:
	if not active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var handled := true
	match event.physical_keycode:
		KEY_E, KEY_ESCAPE:
			if _lock > 0.0:
				get_viewport().set_input_as_handled()
				return
			close()
		KEY_LEFT, KEY_A:
			_nav(-1)
		KEY_RIGHT, KEY_D:
			_nav(1)
		KEY_UP, KEY_W:
			_nav(-5)
		KEY_DOWN, KEY_S:
			_nav(5)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
			if _lock <= 0.0:
				_transfer(_sel_kind, _sel_idx)
		KEY_R:
			_take_all()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
