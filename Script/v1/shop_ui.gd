extends CanvasLayer

signal closed
const UiSkin = preload("res://scripts/ui_skin.gd")
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const GOLD := Color("f6d776")
const STOCK := [0, 1, 2, 3, 4, 5]
const COLS := 3

var active := false
var _root: Control
var _font: Font
var _bold: Font
var _slots: Array = []
var _sel := 0
var _lock := 0.0
var _desc_icon: TextureRect
var _desc_name: Label
var _desc_text: Label
var _price: Label
var _wallet: Label
var _msg: Label


class ShopSlot extends Panel:
	var idx := 0
	var on_click: Callable

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_click.call(idx, ev.double_click)


static func price_of(idx: int) -> int:
	return 20 + idx * 12


func _ready() -> void:
	layer = 13
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_font = load(FONT_UI)
	_bold = load(FONT_BOLD)


func _label(text: String, size_px: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _bold if bold else _font)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", _bold)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", UiSkin.plaque(false))
	b.add_theme_stylebox_override("hover", UiSkin.plaque(true))
	b.add_theme_stylebox_override("pressed", UiSkin.plaque(true))
	b.position = pos
	b.size = sz
	return b


func open() -> void:
	_build()
	active = true
	_lock = 0.3
	_select(0)
	await closed


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_slots.clear()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var vs := get_viewport().get_visible_rect().size
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var P := Vector2(minf(780.0, vs.x - 20.0), minf(470.0, vs.y - 16.0))
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiSkin.box("panel_ornate", 22, 0.0))
	panel.size = P
	panel.position = ((vs - P) * 0.5).floor()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(panel)
	var m := 34.0
	var gap := 8.0
	var cell := minf(86.0, (P.y - 2.0 * m - 190.0) / 2.0)
	var t := _label("MEOW SHOP", 24, GOLD, true)
	t.position = Vector2(m, m - 10.0)
	panel.add_child(t)
	var y0 := m + 26.0
	for i in STOCK.size():
		var s := ShopSlot.new()
		s.idx = i
		s.size = Vector2(cell, cell + 22.0)
		s.position = Vector2(m + (i % COLS) * (cell + gap), y0 + (i / COLS) * (cell + 22.0 + gap))
		s.add_theme_stylebox_override("panel", UiSkin.slot(false))
		s.on_click = Callable(self, "_on_click")
		var pot: Array = Inventory.POTIONS[int(STOCK[i])]
		var ic := TextureRect.new()
		ic.texture = load("res://assets/items/potion_%02d_%s.png" % [int(STOCK[i]) + 1, String(pot[0])])
		ic.position = Vector2(8, 6)
		ic.size = Vector2(cell - 16.0, cell - 16.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_child(ic)
		var pr := _label("%d c" % price_of(int(STOCK[i])), 16, Color("f6e7b0"), true)
		pr.position = Vector2(8, cell - 8.0)
		s.add_child(pr)
		panel.add_child(s)
		_slots.append(s)
	var gw := float(COLS) * cell + float(COLS - 1) * gap
	var rx := m + gw + 22.0
	var rw := P.x - rx - m
	var rh := 2.0 * (cell + 22.0) + gap
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
	_desc_text.position = Vector2(12, 64)
	_desc_text.size = Vector2(rw - 24.0, rh - 110.0)
	_desc_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_desc_text)
	_price = _label("", 18, Color("f6e7b0"), true)
	_price.position = Vector2(12, rh - 34.0)
	box.add_child(_price)
	var by := y0 + rh + 14.0
	_wallet = _label("", 20, Color("f6e7b0"))
	_wallet.position = Vector2(m, by + 8.0)
	panel.add_child(_wallet)
	var bw := 130.0
	var b_buy := _button("Buy", Vector2(P.x - m - 2.0 * bw - 10.0, by), Vector2(bw, 40))
	var b_close := _button("Close", Vector2(P.x - m - bw, by), Vector2(bw, 40))
	b_buy.pressed.connect(_buy)
	b_close.pressed.connect(_close)
	panel.add_child(b_buy)
	panel.add_child(b_close)
	_msg = _label("Double-click / Enter: buy    Arrows: move    Esc / E: leave", 16, Color("cfd6ff"))
	_msg.position = Vector2(m, P.y - 34.0)
	_msg.size = Vector2(P.x - 2.0 * m, 22)
	_msg.clip_text = true
	panel.add_child(_msg)


func _select(i: int) -> void:
	_sel = clampi(i, 0, STOCK.size() - 1)
	for k in _slots.size():
		(_slots[k] as Panel).add_theme_stylebox_override("panel", UiSkin.slot(k == _sel))
	var idx: int = int(STOCK[_sel])
	var pot: Array = Inventory.POTIONS[idx]
	_desc_icon.texture = load("res://assets/items/potion_%02d_%s.png" % [idx + 1, String(pot[0])])
	_desc_name.text = String(pot[1])
	_desc_text.text = String(pot[4])
	_price.text = "Price: %d coins" % price_of(idx)
	_wallet.text = "Coins: %d" % GameState.coins


func _on_click(i: int, dbl: bool) -> void:
	var same := i == _sel
	_select(i)
	if not same:
		AudioManager.play_ui("tick")
	if dbl and _lock <= 0.0:
		_buy()


func _buy() -> void:
	var idx: int = int(STOCK[_sel])
	var price := price_of(idx)
	if GameState.coins < price:
		_msg.text = "Not enough coins."
		AudioManager.play_ui("error")
		return
	if not Inventory.add_item(Inventory.potion_item(idx, 1)):
		_msg.text = "Your bag is full."
		AudioManager.play_ui("error")
		return
	GameState.add_coins(-price)
	_msg.text = "Bought %s. Thanks, meow!" % String(Inventory.POTIONS[idx][1])
	AudioManager.play_ui("select")
	_select(_sel)


func _close() -> void:
	if not active:
		return
	active = false
	_root.queue_free()
	_root = null
	AudioManager.play_ui("back")
	closed.emit()


func _process(delta: float) -> void:
	if _lock > 0.0:
		_lock -= delta


func _input(event: InputEvent) -> void:
	if not active or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var handled := true
	match event.physical_keycode:
		KEY_E, KEY_ESCAPE:
			if _lock <= 0.0:
				_close()
		KEY_LEFT, KEY_A:
			_select(_sel - 1)
		KEY_RIGHT, KEY_D:
			_select(_sel + 1)
		KEY_UP, KEY_W:
			_select(_sel - COLS)
		KEY_DOWN, KEY_S:
			_select(_sel + COLS)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z:
			if _lock <= 0.0:
				_buy()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
