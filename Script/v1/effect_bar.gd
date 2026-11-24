extends Control

const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const GEM_TEX := "res://assets/gems/arskhy_gem_00.png"
const ICON := 24.0
const GAP := 5.0
const HOVER_DELAY := 5.0
const CLICK_SHOW := 5.0

var _player: Node
var _icons := {}
var _tip: PanelContainer
var _tip_name: Label
var _tip_desc: Label
var _tip_for := ""
var _hover_id := ""
var _hover_t := 0.0
var _tip_t := 0.0
var _font: Font
var _bold: Font


class EffectIcon extends Control:
	var id := ""
	var tint := Color.WHITE
	var tex: Texture2D
	var label := ""
	var on_click: Callable
	var on_enter: Callable
	var on_exit: Callable

	func _init() -> void:
		custom_minimum_size = Vector2(24, 24)
		size = Vector2(24, 24)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func(): on_enter.call(id))
		mouse_exited.connect(func(): on_exit.call(id))

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			on_click.call(id)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.05, 0.04, 0.10, 0.88))
		draw_rect(r, tint, false, 2.0)
		var c := size * 0.5
		match id:
			"bleed", "poison":
				var pts := PackedVector2Array([c + Vector2(0, -9), c + Vector2(6, 1), c + Vector2(5, 5), c + Vector2(2, 8), c + Vector2(-2, 8), c + Vector2(-5, 5), c + Vector2(-6, 1)])
				draw_colored_polygon(pts, tint)
				draw_circle(c + Vector2(-2, 2), 1.6, Color(1, 1, 1, 0.6))
			"range":
				var f := PackedVector2Array([c + Vector2(0, -10), c + Vector2(5, -3), c + Vector2(7, 3), c + Vector2(4, 8), c + Vector2(-4, 8), c + Vector2(-7, 3), c + Vector2(-4, -3), c + Vector2(-2, -1)])
				draw_colored_polygon(f, Color("ff7a2a"))
				var g := PackedVector2Array([c + Vector2(0, -2), c + Vector2(3, 3), c + Vector2(2, 7), c + Vector2(-2, 7), c + Vector2(-3, 3)])
				draw_colored_polygon(g, Color("ffe27a"))
			"gem":
				if tex != null:
					draw_texture_rect(tex, Rect2(c - Vector2(8, 9), Vector2(16, 18)), false)
		if label != "":
			var fnt := ThemeDB.fallback_font
			draw_string(fnt, Vector2(2, size.y - 2), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


func setup(player: Node) -> void:
	_player = player


func _ready() -> void:
	_font = load(FONT_UI)
	_bold = load(FONT_BOLD)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var defs := [["bleed", Color("e0394a")], ["poison", Color("5bd66b")], ["range", Color("ff7a2a")], ["gem", Color("5ec8ff")]]
	for d in defs:
		var ic := EffectIcon.new()
		ic.id = d[0]
		ic.tint = d[1]
		ic.on_click = Callable(self, "_on_click")
		ic.on_enter = Callable(self, "_on_enter")
		ic.on_exit = Callable(self, "_on_exit")
		if d[0] == "gem":
			ic.tex = load(GEM_TEX)
		ic.visible = false
		add_child(ic)
		_icons[d[0]] = ic
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.z_index = 60
	_tip.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.09, 0.96)
	sb.border_color = Color("5a4a86")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_tip.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_tip.add_child(v)
	_tip_name = Label.new()
	_tip_name.add_theme_font_override("font", _bold)
	_tip_name.add_theme_font_size_override("font_size", 18)
	_tip_name.add_theme_color_override("font_color", Color("f6d776"))
	v.add_child(_tip_name)
	_tip_desc = Label.new()
	_tip_desc.add_theme_font_override("font", _font)
	_tip_desc.add_theme_font_size_override("font_size", 15)
	_tip_desc.add_theme_color_override("font_color", Color("e9e4d0"))
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(240, 0)
	v.add_child(_tip_desc)
	add_child(_tip)


func _is_active(id: String) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	match id:
		"bleed":
			return int(_player.get("_bleed_ticks")) > 0 and not bool(_player.get("_poison"))
		"poison":
			return int(_player.get("_bleed_ticks")) > 0 and bool(_player.get("_poison"))
		"range":
			return bool(_player.get("range_active"))
		"gem":
			return GameState.gem_progress() > 0.0
	return false


func _info(id: String) -> Array:
	match id:
		"bleed":
			return ["Bleeding", "Thorns cut you. You lose 1 HP every second for a few seconds."]
		"poison":
			return ["Poison", "You lose 1 HP every second while poisoned. Your body turns green."]
		"range":
			return ["Range Mode", "Your damage is doubled and your HP slowly regenerates while the Range bar drains."]
		"gem":
			var lv1 := int(GameState.gem_levels[0])
			var lv2 := int(GameState.gem_levels[1])
			var atk := int(round(GameState.gem_scale("attack", 5.0)))
			return ["Arskhy Gems  (Lv %d / Lv %d)" % [lv1, lv2], "Your gems empower you: Attack %d, Crit %.1f%%. Upgrade them in the Bag (T)." % [atk, GameState.gem_crit() * 100.0]]
	return ["", ""]


func _on_click(id: String) -> void:
	_show_tip(id, CLICK_SHOW)


func _on_enter(id: String) -> void:
	_hover_id = id
	_hover_t = 0.0


func _on_exit(id: String) -> void:
	if _hover_id == id:
		_hover_id = ""
		_hover_t = 0.0
	if _tip_for == id and _tip_t <= 0.0:
		_hide_tip()


func _show_tip(id: String, seconds: float) -> void:
	var ic: Control = _icons.get(id)
	if ic == null or not ic.visible:
		return
	var inf := _info(id)
	_tip_name.text = String(inf[0])
	_tip_desc.text = String(inf[1])
	_tip.reset_size()
	_tip_for = id
	_tip_t = seconds
	_tip.visible = true
	_place_tip()


func _hide_tip() -> void:
	_tip.visible = false
	_tip_for = ""
	_tip_t = 0.0


func _place_tip() -> void:
	var ic: Control = _icons.get(_tip_for)
	if ic == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var gp := ic.global_position + Vector2(0.0, -_tip.size.y - 8.0)
	gp.x = clampf(gp.x, 6.0, maxf(6.0, vs.x - _tip.size.x - 6.0))
	gp.y = maxf(6.0, gp.y)
	_tip.global_position = gp


func _process(delta: float) -> void:
	var x := 0.0
	for id in _icons:
		var ic: EffectIcon = _icons[id]
		var on := _is_active(id)
		ic.visible = on
		if on:
			ic.position = Vector2(x, 0.0)
			x += ICON + GAP
			if id == "bleed" or id == "poison":
				var t := str(int(_player.get("_bleed_ticks")))
				if ic.label != t:
					ic.label = t
					ic.queue_redraw()
	if _hover_id != "" and not (_icons[_hover_id] as Control).visible:
		_hover_id = ""
		_hover_t = 0.0
	if _hover_id != "":
		_hover_t += delta
		if _hover_t >= HOVER_DELAY and _tip_for != _hover_id:
			_show_tip(_hover_id, 0.0)
	if _tip.visible:
		if _tip_for == "" or not (_icons[_tip_for] as Control).visible:
			_hide_tip()
		else:
			_place_tip()
			if _tip_t > 0.0:
				_tip_t -= delta
				if _tip_t <= 0.0 and _hover_id != _tip_for:
					_hide_tip()
				elif _tip_t <= 0.0:
					_tip_t = 0.0
