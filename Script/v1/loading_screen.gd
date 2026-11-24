extends Control

signal finished

const NEXT_SCENE := "res://scenes/title_screen.tscn"
const DIR := "res://assets/loading/"
const MIN_TIME := 4.0
const SPRITE_FRAMES := 24
const SPRITE_FPS := 10.0
const GAME_TITLE := "Arskhy Rebirth  ·  1.0"
const LAYERS := [["buildings_4", 110.0], ["shade_3", 92.0], ["buildings_3", 76.0], ["shade_2", 62.0], ["buildings_2", 48.0], ["buildings_1", 36.0]]
const FONT_BOLD := "res://assets/fonts/pixelify_sans_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"

var _t := 0.0
var _real := 0.0
var _shown := 0.0
var _done := false
var _tex := {}
var _sprite: Texture2D
var _font_b: Font
var _font: Font
var _fade := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 200
	for n in ["sky", "tiny_cloud", "tiny_cloud_2"] + LAYERS.map(func(l): return l[0]):
		_tex[n] = load(DIR + String(n) + ".png")
	_sprite = load(DIR + "sprite_strip.png")
	_font_b = load(FONT_BOLD)
	_font = load(FONT_UI)
	ResourceLoader.load_threaded_request(NEXT_SCENE)


func _process(delta: float) -> void:
	_t += delta
	var arr := []
	var st := ResourceLoader.load_threaded_get_status(NEXT_SCENE, arr)
	if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_real = float(arr[0]) * 100.0
	else:
		_real = 100.0
	var target := minf(_real, (_t / MIN_TIME) * 100.0)
	_shown = minf(target, _shown + maxf(0.6, (target - _shown) * 0.12))
	if _shown >= 99.5 and not _done:
		_done = true
		_shown = 100.0
		_finish()
	if _done:
		_fade = maxf(0.0, _fade - delta * 1.6)
		modulate.a = _fade
	queue_redraw()


func _finish() -> void:
	await get_tree().create_timer(0.45).timeout
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	await tw.finished
	finished.emit()
	queue_free()


func _scroll_layer(tex: Texture2D, vs: Vector2, dur: float) -> void:
	var h := vs.y - 48.0
	var sc := h / float(tex.get_height())
	var tw := float(tex.get_width()) * sc
	var off := fmod(_t * vs.x / dur, tw)
	var x := -off
	while x < vs.x:
		draw_texture_rect(tex, Rect2(x, vs.y - 48.0 - h, tw, h), false)
		x += tw


func _draw() -> void:
	var vs := size
	var sky: Texture2D = _tex["sky"]
	var ssc := vs.y / float(sky.get_height())
	var sx := 0.0
	while sx < vs.x:
		draw_texture_rect(sky, Rect2(sx, 0.0, sky.get_width() * ssc, vs.y), false)
		sx += sky.get_width() * ssc
	for c in [["tiny_cloud", 0.16, 55.0, 0.0], ["tiny_cloud_2", 0.26, 72.0, 24.0], ["tiny_cloud", 0.11, 64.0, 40.0]]:
		var ct: Texture2D = _tex[String(c[0])]
		var cw := ct.get_width() * 2.8
		var ch := ct.get_height() * 2.8
		var ph := fmod((_t + float(c[3])) / float(c[2]), 1.0)
		var cx := lerpf(vs.x * 1.05, -vs.x * 0.15, ph)
		draw_texture_rect(ct, Rect2(cx, vs.y * 0.45 * float(c[1]), cw, ch), false, Color(1, 1, 1, 0.85))
	for l in LAYERS:
		_scroll_layer(_tex[String(l[0])], vs, float(l[1]))
	var dock_h := 118.0
	var grad_top := vs.y - dock_h - 30.0
	for i in 30:
		draw_rect(Rect2(0.0, grad_top + i, vs.x, 1.0), Color(0.04, 0.043, 0.055, 0.98 * float(i) / 30.0 * 0.0 + 0.95 * float(i) / 30.0))
	draw_rect(Rect2(0.0, grad_top + 30.0, vs.x, vs.y - grad_top - 30.0), Color(0.04, 0.043, 0.055, 0.97))
	draw_string(_font_b, Vector2(35.0, 52.0), GAME_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, 0.45))
	draw_string(_font_b, Vector2(34.0, 50.0), GAME_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	var fw := _sprite.get_width() / SPRITE_FRAMES
	var fi := int(_t * SPRITE_FPS) % SPRITE_FRAMES
	var sh := 76.0
	var sw := sh * float(fw) / float(_sprite.get_height())
	draw_texture_rect_region(_sprite, Rect2(24.0, vs.y - 118.0 + 20.0, sw, sh), Rect2(fi * fw, 0, fw, _sprite.get_height()))
	var bx := 24.0 + sw + 16.0
	var bw := vs.x - bx - 28.0
	draw_string(_font_b, Vector2(bx, vs.y - 72.0), "Extracting...", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f1f5f9"))
	var left := maxi(1, int(ceil(MIN_TIME - _t)))
	var cd := "SELESAI" if _done else ("TUNGGU %d DETIK" % left)
	draw_string(_font, Vector2(bx, vs.y - 52.0), cd, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("64748b"))
	draw_rect(Rect2(bx, vs.y - 40.0, bw, 4.0), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bx, vs.y - 40.0, bw * _shown / 100.0, 4.0), Color("e2e8f0"))
	var est := "Mengekstrak file estimasi %d%%" % int(_shown)
	draw_string(_font, Vector2(0.0, vs.y - 14.0), est, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color("cbd5e1"))
