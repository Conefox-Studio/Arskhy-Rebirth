extends CanvasLayer

const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const OUTLINE := 2.0
const TIP := 6.0
const DMG_HOLD := 1.2
const DMG_FADE := 0.3
const COL_TRACK := Color("555555")
const COL_DMG := Color("ff3c00")
const HP_C1 := Color("ffb42e")
const HP_C2 := Color("8a3d00")
const MP_C1 := Color("2fd6c0")
const MP_C2 := Color("07423c")

var boss_name := "GHOST EXECUTOR"
var _root: Control
var _font: Font
var _hp := 1.0
var _hp_n := 1
var _hp_max := 1
var _trail_from := 1.0
var _trail_t := 0.0
var _mp := 1.0
var _shown := 0.0
var _want := 0.0
var _clock := 0.0


func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_BOLD)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_all)
	add_child(_root)
	_root.visible = false


func show_bar(n: String) -> void:
	boss_name = n
	_hp = 1.0
	_trail_t = 0.0
	_want = 1.0
	_root.visible = true


func hide_bar() -> void:
	_want = 0.0


func set_hp(hp: int, max_hp: int) -> void:
	var v := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	if v < _hp:
		_trail_from = maxf(_hp, _trail_from if _trail_t > 0.0 else 0.0)
		_trail_t = DMG_HOLD + DMG_FADE
	_hp = v
	_hp_n = hp
	_hp_max = max_hp


func set_mp(mp: float, max_mp: float) -> void:
	_mp = clampf(mp / maxf(max_mp, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	_shown = move_toward(_shown, _want, delta * 2.2)
	if _trail_t > 0.0:
		_trail_t -= delta
	if _shown <= 0.0 and _want <= 0.0:
		_root.visible = false
	elif _root.visible:
		_root.queue_redraw()


func _top(x: float, w: float, h: float) -> float:
	if x <= w - TIP:
		return 0.0
	return clampf((x - (w - TIP)) / TIP, 0.0, 1.0) * h * 0.5


func _band(o: Vector2, w: float, h: float, x0: float, x1: float) -> PackedVector2Array:
	x0 = clampf(x0, 0.0, w)
	x1 = clampf(x1, 0.0, w)
	var pts := PackedVector2Array()
	if x1 - x0 < 0.5:
		return pts
	var xs: Array[float] = [x0]
	if x0 < w - TIP and x1 > w - TIP:
		xs.append(w - TIP)
	xs.append(x1)
	for x in xs:
		pts.append(o + Vector2(x, _top(x, w, h)))
	for i in range(xs.size() - 1, -1, -1):
		pts.append(o + Vector2(xs[i], h - _top(xs[i], w, h)))
	return pts


func _fill(o: Vector2, w: float, h: float, x0: float, x1: float, c0: Color, c1: Color) -> void:
	var pts := _band(o, w, h, x0, x1)
	if pts.size() < 3:
		return
	var cols := PackedColorArray()
	var span := maxf(x1 - x0, 0.001)
	for p in pts:
		cols.append(c0.lerp(c1, clampf((p.x - o.x - x0) / span, 0.0, 1.0)))
	_root.draw_polygon(pts, cols)


func _bar(pos: Vector2, iw: float, h: float, frac: float, trail: float, c1: Color, c2: Color, delay: float) -> void:
	var ih := h - OUTLINE * 2.0
	var inner := pos + Vector2(OUTLINE, OUTLINE)
	var ow := iw + OUTLINE * 2.0
	_root.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(ow - TIP, 0), pos + Vector2(ow, h * 0.5),
		pos + Vector2(ow - TIP, h), pos + Vector2(0, h)]), Color.BLACK)
	_fill(inner, iw, ih, 0.0, iw, COL_TRACK, COL_TRACK)
	if trail > frac and _trail_t > 0.0:
		var a := 1.0 if _trail_t > DMG_FADE else _trail_t / DMG_FADE
		_fill(inner, iw, ih, frac * iw, trail * iw, Color(COL_DMG, a), Color(COL_DMG, a))
	if frac > 0.0:
		_fill(inner, iw, ih, 0.0, frac * iw, c1, c2)
	_fill(inner, iw, ih * 0.5, 0.0, iw, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0))
	var lower := _band(inner + Vector2(0, ih * 0.5), iw, ih, 0.0, iw)
	var ph := fposmod(_clock - delay, 3.0) / 1.2
	if ph <= 1.0:
		var gw := maxf(6.0, iw / 4.0)
		var gx := iw * (ph * 1.6 - 0.4)
		_fill(inner, iw, ih, gx, gx + gw * 0.5, Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.6))
		_fill(inner, iw, ih, gx + gw * 0.5, gx + gw, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.0))
	var dark := PackedVector2Array([inner + Vector2(0, ih * 0.5), inner + Vector2(iw - TIP, ih * 0.5),
		inner + Vector2(iw - TIP * 0.5, ih * 0.75), inner + Vector2(iw - TIP, ih), inner + Vector2(0, ih)])
	_root.draw_colored_polygon(dark, Color(0, 0, 0, 0.18))
	if lower.is_empty():
		pass


func _draw_all() -> void:
	var s := _root.size
	var iw := minf(440.0, s.x * 0.5)
	var x := (s.x - iw - OUTLINE * 2.0) * 0.5
	var y := 64.0 - (1.0 - _shown) * 90.0
	var tw := _font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var np := Vector2((s.x - tw) * 0.5, y - 6.0)
	_root.draw_string_outline(_font, np, boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color.BLACK)
	_root.draw_string(_font, np, boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd98a"))
	_bar(Vector2(x, y), iw, 16.0, _hp, _trail_from, HP_C1, HP_C2, 0.0)
	var t := "%d/%d" % [_hp_n, _hp_max]
	var base := Vector2(x + OUTLINE + 4.0, y + 16.0 - OUTLINE - 1.0)
	_root.draw_string_outline(_font, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color.BLACK)
	_root.draw_string(_font, base, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	_bar(Vector2(x, y + 22.0), iw * 0.7, 12.0, _mp, 0.0, MP_C1, MP_C2, 0.4)
