extends StaticBody2D

signal broken(prop)
const Debris = preload("res://scripts/debris.gd")

var kind := "vase"
var hits_left := 1
var art_tex: Texture2D
var art_rect := Rect2()
var _spr: Sprite2D
var _dead := false


func setup(tex: Texture2D, rect: Rect2, hits: int, k: String) -> void:
	art_tex = tex
	art_rect = rect
	hits_left = hits
	kind = k
	collision_layer = 8
	collision_mask = 0
	position = rect.get_center()
	_spr = Sprite2D.new()
	_spr.texture = tex
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = rect.size
	cs.shape = sh
	add_child(cs)


func hit(_dmg: int, _dir: float) -> void:
	if _dead:
		return
	hits_left -= 1
	if hits_left > 0:
		AudioManager.play_sfx_named("hit_body")
		var tw := create_tween()
		tw.tween_property(_spr, "position:x", 1.5, 0.03)
		tw.tween_property(_spr, "position:x", -1.5, 0.05)
		tw.tween_property(_spr, "position:x", 0.0, 0.03)
		return
	_dead = true
	collision_layer = 0
	AudioManager.play_sfx_named("vase_break")
	Debris.burst(get_parent(), art_tex, art_rect, 14 if kind == "vase" else 22, 1.0)
	_spr.visible = false
	broken.emit(self)
	queue_free()
