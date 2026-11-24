extends CanvasLayer

const InputIcons = preload("res://scripts/input_icons.gd")
const MagicFxScript = preload("res://scripts/magic_fx.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const FONT_UI := "res://assets/fonts/pixelify_sans_bold.ttf"

const PX_PER_POINT := 12.0
const MAX_BAR_PX := 260.0
const OUTLINE := 2.0
const TIP := 6.0
const ROW_GAP := 6.0
const MARGIN := Vector2(18, 16)
const TOUCH_BAR_LIFT := 244.0
const DMG_HOLD := 2.0
const DMG_FADE := 0.3
const HEAL_HOLD := 4.0
const HEAL_HOLD_FULL := 0.4
const GLINT_PERIOD := 3.0
const GLINT_SWEEP := 1.2

const COL_OUTLINE := Color("000000")
const COL_TRACK := Color("555555")
const COL_DMG := Color("ff3c00")
const COL_HEAL := Color("6cff00")

const BARS := [
	{"key": "hp", "cap": 40, "h": 16.0, "c1": Color("2f7bff"), "c2": Color("2f7bff"), "delay": 0.0, "text": true},
	{"key": "magic", "cap": 15, "h": 12.0, "c1": Color("8a3fd1"), "c2": Color("2a0a4a"), "delay": 0.4, "text": false},
	{"key": "range", "cap": 20, "h": 12.0, "c1": Color("d62020"), "c2": Color("4a0606"), "delay": 0.8, "text": false},
]

var _ppp := PX_PER_POINT
var _touch := false
var _player: CharacterBody2D
var _canvas: Control
var _font: Font
var _clock := 0.0
var _stats := {}
var _effects: Control
var _notice: Label
var _notice_tween: Tween


func _ready() -> void:
	layer = 8
	_font = load(FONT_UI)
	for b in BARS:
		_stats[b.key] = {
			"max": 20.0, "cur": 20.0, "shown": 20.0,
			"d_from": 0.0, "d_to": 0.0, "d_t": 0.0,
			"h_t": 0.0,
			"h_wait": false,
		}
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bars)
	add_child(_canvas)

	_build_hints()
	_build_currency()
	_effects = EffectBar.new()
	_effects.name = "Effects"
	add_child(_effects)

	var nl := CanvasLayer.new()
	nl.layer = 11
	add_child(nl)
	_notice = Label.new()
	_notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.add_theme_font_override("font", _font)
	_notice.add_theme_font_size_override("font_size", 34)
	_notice.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
	_notice.add_theme_constant_override("outline_size", 10)
	_notice.modulate.a = 0.0
	nl.add_child(_notice)


const EffectBar = preload("res://scripts/effect_bar.gd")
const HINTS := [["jump", "Jump"], ["attack", "Attack"], ["dash", "Dash"], ["range_mode", "Range"], ["use_quick", "Item"], ["inventory", "Bag"], ["pause", "Pause"]]
var _hints: HBoxContainer


var _coin_lbl: Label
var _gem_lbl: Label


func _build_currency() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -170.0
	box.offset_right = -18.0
	box.offset_top = 14.0
	box.offset_bottom = 72.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	for k in ["coin", "gem"]:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 6)
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/fx/coin.png" if k == "coin" else "res://assets/fx/gems.png")
		at.region = Rect2(0, 0, 16, 16)
		var icon := TextureRect.new()
		icon.texture = at
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color("f6d776") if k == "coin" else Color("d9a8ff"))
		lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.08))
		lbl.add_theme_constant_override("outline_size", 6)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
		row.add_child(icon)
		box.add_child(row)
		if k == "coin":
			_coin_lbl = lbl
		else:
			_gem_lbl = lbl
	GameState.currency_changed.connect(_refresh_currency)
	_refresh_currency()


func _refresh_currency() -> void:
	if _coin_lbl != null:
		_coin_lbl.text = str(GameState.coins)
	if _gem_lbl != null:
		_gem_lbl.text = str(GameState.gems)


func _build_hints() -> void:
	_hints = HBoxContainer.new()
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hints.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints.offset_right = -18.0
	_hints.offset_bottom = -14.0
	_hints.add_theme_constant_override("separation", 14)
	_hints.modulate.a = 0.8
	add_child(_hints)
	DeviceMode.mode_changed.connect(func(_m): _refresh_hints())
	GameSettings.controls_changed.connect(_refresh_hints)
	Input.joy_connection_changed.connect(func(_d, _c): _refresh_hints())
	_refresh_hints()


func _refresh_hints() -> void:
	for c in _hints.get_children():
		c.queue_free()
	_hints.visible = not DeviceMode.is_touch() and GameSettings.control_hints
	if not _hints.visible:
		return
	for hnt in HINTS:
		var tex := InputIcons.texture_for(hnt[0])
		if tex == null:
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 4)
		var ic := TextureRect.new()
		ic.texture = tex
		ic.custom_minimum_size = Vector2(26, 26)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		var l := Label.new()
		l.text = hnt[1]
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		row.add_child(l)
		_hints.add_child(row)


func setup(player: CharacterBody2D) -> void:
	_player = player
	if _effects != null:
		_effects.call("setup", player)
	if player.has_signal("hp_changed"):
		player.hp_changed.connect(func(v, m): set_stat("hp", v, m))
		player.mp_changed.connect(func(v, m): set_stat("magic", v, m))
		set_stat("hp", player.hp, player.max_hp)
		set_stat("magic", player.mp, player.max_mp)
	if player.has_signal("range_changed"):
		player.range_changed.connect(func(v, m): set_stat("range", v, m))
		set_stat("range", player.range_pts, player.max_range)


func show_notice(text: String, color: Color = Color("f6d776"), duration: float = 2.4) -> void:
	_notice.text = text
	_notice.add_theme_color_override("font_color", color)
	if _notice_tween:
		_notice_tween.kill()
	_notice.modulate.a = 0.0
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice, "modulate:a", 1.0, 0.25)
	_notice_tween.tween_interval(maxf(0.1, duration - 0.75))
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5)


func _cap(key: String) -> float:
	for b in BARS:
		if b.key == key:
			return float(b.cap)
	return 100.0


func set_stat(key: String, value: int, max_value: int) -> void:
	var s: Dictionary = _stats[key]
	s["real_cur"] = value
	s["real_max"] = max_value
	var cap := _cap(key)
	var shown_value := float(value)
	if float(max_value) > cap:
		shown_value = float(value) * cap / float(max_value)
	var mx := minf(float(max_value), cap)
	var v := clampf(shown_value, 0.0, mx)
	if mx != s.max:
		s.max = mx
		s.cur = v
		s.shown = v
		s.d_t = 0.0
		s.h_wait = false
		return
	if v < s.cur:
		_hit(s, s.cur - v)
	elif v > s.cur:
		_heal(s, v - s.cur)


func _hit(s: Dictionary, amount: float) -> void:
	var prev_shown: float = s.shown
	s.cur = maxf(0.0, s.cur - amount)
	if s.cur < s.shown:
		s.h_wait = false
		s.shown = s.cur
		s.d_from = s.cur
		s.d_to = ceilf(prev_shown)
		s.d_t = DMG_HOLD + DMG_FADE


func _heal(s: Dictionary, amount: float) -> void:
	s.cur = minf(s.max, s.cur + amount)
	s.h_wait = true
	s.h_t = HEAL_HOLD_FULL if s.cur >= s.max else HEAL_HOLD


func _process(delta: float) -> void:
	_clock += delta
	for k in _stats:
		var s: Dictionary = _stats[k]
		if s.d_t > 0.0:
			s.d_t -= delta
		if s.h_wait:
			s.h_t -= delta
			if s.h_t <= 0.0:
				s.h_wait = false
		if not s.h_wait and s.shown < s.cur:
			s.shown = move_toward(s.shown, s.cur, delta * maxf(8.0, s.max * 1.4))
	_canvas.queue_redraw()


func _draw_bars() -> void:
	var total_h := 0.0
	for b in BARS:
		total_h += b.h
	total_h += ROW_GAP * (BARS.size() - 1)
	_touch = DeviceMode.is_touch()
	_draw_clock()
	var layout := GameSettings.hud_layout_index
	var vertical := layout == 3 or (layout == 0 and _touch)
	if vertical:
		var longest := 1.0
		for k in _stats:
			longest = maxf(longest, float(_stats[k].max))
		var base := Vector2(MARGIN.x, _canvas.size.y - MARGIN.y - TOUCH_BAR_LIFT)
		var avail := minf(_canvas.size.y * 0.58, base.y - 70.0)
		_ppp = minf(PX_PER_POINT, maxf(avail, 40.0) / longest)
		_draw_faints_touch(Vector2(MARGIN.x, base.y - longest * _ppp - 44.0))
		_canvas.draw_set_transform(base, -PI / 2.0, Vector2.ONE)
		var x := 0.0
		for b in BARS:
			_draw_bar(b, Vector2(0.0, x))
			x += b.h + ROW_GAP
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_ppp = PX_PER_POINT * (0.8 if _touch else 1.0)
	var longest_h := 1.0
	for k in _stats:
		longest_h = maxf(longest_h, float(_stats[k].max))
	_ppp = minf(_ppp, MAX_BAR_PX / longest_h)
	var y: float
	if layout == 1:
		y = MARGIN.y + 26.0
	else:
		y = _canvas.size.y - MARGIN.y - total_h - (TOUCH_BAR_LIFT if _touch else 0.0)
	_draw_faints(Vector2(MARGIN.x, y - 26.0))
	for b in BARS:
		_draw_bar(b, Vector2(MARGIN.x, y))
		if b.key == "magic":
			_draw_magic_label(Vector2(MARGIN.x + float(_stats.magic.max) * _ppp + TIP + 14.0, y + float(b.h) - 1.0))
		y += b.h + ROW_GAP


func _draw_magic_label(pos: Vector2) -> void:
	var t := "< " + MagicFxScript.current_name + " >"
	_canvas.draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(0, 0, 0, 0.85))
	_canvas.draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.86, 0.78, 1.0, 0.95))


func _draw_clock() -> void:
	if not GameSettings.day_night:
		return
	var t: String = DayNightScript.clock_text()
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var pos := Vector2((_canvas.size.x - w) * 0.5, 30.0)
	_canvas.draw_string_outline(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.8))
	_canvas.draw_string(_font, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.95, 0.78, 0.85))


func _draw_faint_dot(c: Vector2, used: float) -> void:
	_canvas.draw_circle(c, 9.0, Color.BLACK)
	if used >= 1.0:
		_canvas.draw_circle(c, 7.0, Color(0.16, 0.08, 0.1))
		_canvas.draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), Color("ff4a4a"), 2.0)
		_canvas.draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), Color("ff4a4a"), 2.0)
		return
	_canvas.draw_circle(c, 7.0, Color("d8344a"))
	_canvas.draw_circle(c + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.55))
	if used > 0.0:
		var pts := PackedVector2Array()
		for k in 13:
			var ang := -PI * 0.5 + PI * float(k) / 12.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * 7.0)
		_canvas.draw_colored_polygon(pts, Color(0.16, 0.08, 0.1))


func _draw_faints_touch(pos: Vector2) -> void:
	if _effects != null:
		_effects.position = Vector2(pos.x, pos.y - 30.0)
	for i in GameState.MAX_FAINTS:
		_draw_faint_dot(pos + Vector2(9.0 + i * 22.0, 9.0), clampf(GameState.faints - float(i), 0.0, 1.0))


func _draw_faints(pos: Vector2) -> void:
	if _effects != null:
		_effects.position = Vector2(pos.x, pos.y - 30.0)
	var label := "FAINT"
	_canvas.draw_string_outline(_font, pos + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	_canvas.draw_string(_font, pos + Vector2(0, 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e8e2ff"))
	for i in GameState.MAX_FAINTS:
		_draw_faint_dot(pos + Vector2(58.0 + i * 22.0, 9.0), clampf(GameState.faints - float(i), 0.0, 1.0))
	var dn: String = GameState.difficulty_name()
	var dx := 58.0 + GameState.MAX_FAINTS * 22.0 + 8.0
	_canvas.draw_string_outline(_font, pos + Vector2(dx, 15), dn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	_canvas.draw_string(_font, pos + Vector2(dx, 15), dn, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f6d776"))


func _top(x: float, w: float, h: float) -> float:
	if x <= w - TIP:
		return 0.0
	return clampf((x - (w - TIP)) / TIP, 0.0, 1.0) * h * 0.5


func _bot(x: float, w: float, h: float) -> float:
	return h - _top(x, w, h)


func _band(origin: Vector2, w: float, h: float, x0: float, x1: float, ya: float, yb: float) -> PackedVector2Array:
	x0 = clampf(x0, 0.0, w)
	x1 = clampf(x1, 0.0, w)
	var pts := PackedVector2Array()
	if x1 <= x0:
		return pts
	var xs: Array[float] = [x0]
	if x0 < w - TIP and x1 > w - TIP:
		xs.append(w - TIP)
	xs.append(x1)
	for x in xs:
		pts.append(origin + Vector2(x, maxf(ya, _top(x, w, h))))
	for i in range(xs.size() - 1, -1, -1):
		var x: float = xs[i]
		pts.append(origin + Vector2(x, minf(yb, _bot(x, w, h))))
	return pts


func _fill_band(origin: Vector2, w: float, h: float, x0: float, x1: float, ya: float, yb: float, c0: Color, c1: Color) -> void:
	var pts := _band(origin, w, h, x0, x1, ya, yb)
	if pts.size() < 3:
		return
	var area := 0.0
	for k in pts.size():
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[(k + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	if absf(area) < 1.0:
		return
	x0 = clampf(x0, 0.0, w)
	x1 = clampf(x1, 0.0, w)
	var cols := PackedColorArray()
	for p in pts:
		var t := 0.0 if x1 == x0 else clampf((p.x - origin.x - x0) / (x1 - x0), 0.0, 1.0)
		cols.append(c0.lerp(c1, t))
	_canvas.draw_polygon(pts, cols)


func _draw_bar(b: Dictionary, pos: Vector2) -> void:
	var s: Dictionary = _stats[b.key]
	var h: float = b.h
	var iw: float = s.max * _ppp
	var ih := h - OUTLINE * 2.0
	var inner := pos + Vector2(OUTLINE, OUTLINE)

	var ow := iw + OUTLINE * 2.0
	var outline := PackedVector2Array([
		pos, pos + Vector2(ow - TIP, 0), pos + Vector2(ow, h * 0.5),
		pos + Vector2(ow - TIP, h), pos + Vector2(0, h)])
	_canvas.draw_colored_polygon(outline, COL_OUTLINE)

	_fill_band(inner, iw, ih, 0.0, iw, 0.0, ih, COL_TRACK, COL_TRACK)

	var cur_px: float = s.cur / s.max * iw
	var shown_px: float = s.shown / s.max * iw

	if s.d_t > 0.0:
		var a: float = 1.0 if s.d_t > DMG_FADE else s.d_t / DMG_FADE
		var c := Color(COL_DMG, a)
		_fill_band(inner, iw, ih, s.d_from * _ppp, s.d_to * _ppp, 0.0, ih, c, c)

	if cur_px > shown_px:
		_fill_band(inner, iw, ih, shown_px, cur_px, 0.0, ih, COL_HEAL, COL_HEAL)

	if shown_px > 0.0:
		_fill_band(inner, iw, ih, 0.0, shown_px, 0.0, ih, b.c1, b.c2)

	_fill_band(inner, iw, ih, 0.0, iw, ih * 0.5, ih, Color(0, 0, 0, 0.18), Color(0, 0, 0, 0.18))

	var ph := fposmod(_clock - b.delay, GLINT_PERIOD) / GLINT_SWEEP
	if ph <= 1.0:
		var gw := maxf(6.0, iw / 4.0)
		var gx := iw * (ph * 1.6 - 0.4)
		var mid := gx + gw * 0.5
		_fill_band(inner, iw, ih, gx, mid, 0.0, ih, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.6))
		_fill_band(inner, iw, ih, mid, gx + gw, 0.0, ih, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0))

	if b.text and not _touch:
		var t := "%d/%d" % [int(s.get("real_cur", round(s.cur))), int(s.get("real_max", round(s.max)))]
		var fs := 11
		var base := inner + Vector2(4.0, ih - 1.0)
		_canvas.draw_string_outline(_font, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color.BLACK)
		_canvas.draw_string(_font, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


