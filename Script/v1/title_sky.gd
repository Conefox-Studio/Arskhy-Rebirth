extends Node2D

signal hero_exited

const DIR := "res://assets/title_sky/"
const STRATA := [["day_cloud_upper", 240.0, 0.92], ["day_cloud_lower", 155.0, 0.95]]
const GIANTS := ["giant_day_1", "giant_day_2", "giant_day_3", "giant_day_4"]
const BOTTOM := [["cloud_bright", 130.0, 0.78, 1.0], ["cloud_wisps", 95.0, 0.86, 1.0], ["cloud_mid", 78.0, 0.88, 0.98], ["cloud_low", 58.0, 0.92, 0.86], ["cloud_dark", 42.0, 0.95, 0.72]]

var _t := 0.0
var _tex := {}
var _giants: Array = []
var _plane_x := -0.3


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -50
	for n in ["sky_day", "day_cloud_upper", "day_cloud_lower", "cloud_bright", "cloud_wisps", "cloud_mid", "cloud_low", "cloud_dark", "airplane", "contrail"] + GIANTS:
		_tex[n] = load(DIR + n + ".png")
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in GIANTS.size():
		_giants.append({"tex": GIANTS[i], "x": rng.randf(), "y": rng.randf_range(0.18, 0.5), "speed": rng.randf_range(0.004, 0.009), "bottom": i == 0})


func hero_walk_out() -> void:
	hero_exited.emit.call_deferred()


func start_hero() -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	_plane_x += delta / 70.0
	if _plane_x > 1.3:
		_plane_x = -0.3
	queue_redraw()


func _strip(tex: Texture2D, vs: Vector2, speed_px: float, alpha: float, bright: float) -> void:
	var off := fmod(_t * speed_px, vs.x)
	var col := Color(bright, bright, bright, alpha)
	draw_texture_rect(tex, Rect2(-off, 0.0, vs.x, vs.y), false, col)
	draw_texture_rect(tex, Rect2(-off + vs.x, 0.0, vs.x, vs.y), false, col)


func _draw() -> void:
	var vs := get_viewport_rect().size
	var sky: Texture2D = _tex["sky_day"]
	var sc := maxf(vs.x / sky.get_width(), vs.y / sky.get_height())
	var sw := sky.get_width() * sc
	var sh := sky.get_height() * sc
	draw_texture_rect(sky, Rect2((vs.x - sw) * 0.5, vs.y - sh, sw, sh), false)
	for s in STRATA:
		_strip(_tex[String(s[0])], vs, vs.x / float(s[1]), float(s[2]), 1.0)
	var k := vs.y / 720.0
	for g in _giants:
		var gt: Texture2D = _tex[String(g.tex)]
		var gw := gt.get_width() * 2.0 * k
		var gh := gt.get_height() * 2.0 * k
		var span := vs.x + gw
		var gx := fmod(float(g.x) + _t * float(g.speed), 1.0) * span - gw
		var gy := (vs.y - gh) if bool(g.bottom) else (float(g.y) * vs.y)
		draw_texture_rect(gt, Rect2(gx, gy, gw, gh), false)
	var px := _plane_x * vs.x
	var py := vs.y * 0.2
	var ct: Texture2D = _tex["contrail"]
	var pt: Texture2D = _tex["airplane"]
	draw_texture_rect(ct, Rect2(px - ct.get_width() * 2.0 * k + 4.0, py + 4.0 * k, ct.get_width() * 2.0 * k, ct.get_height() * 2.0 * k), false, Color(1, 1, 1, 0.85))
	draw_texture_rect(pt, Rect2(px, py, pt.get_width() * 2.0 * k, pt.get_height() * 2.0 * k), false)
	for b in BOTTOM:
		_strip(_tex[String(b[0])], vs, vs.x / float(b[1]), float(b[2]), float(b[3]))
