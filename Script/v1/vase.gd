extends StaticBody2D

var owner_level
var base_x := 0.0
var broken := false
var _spr: Sprite2D


func setup(bottom_center: Vector2, lvl) -> void:
	position = bottom_center
	base_x = bottom_center.x
	owner_level = lvl
	add_to_group("enemy")
	collision_layer = 8
	collision_mask = 0
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/fx/vase_break.png")
	_spr.hframes = 4
	_spr.frame = 0
	_spr.centered = false
	_spr.scale = Vector2(2.0, 2.0)
	_spr.position = Vector2(-16.0, -32.0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(20.0, 28.0)
	cs.shape = sh
	cs.position = Vector2(0.0, -15.0)
	add_child(cs)


func hit(_dmg: int, _dir: float) -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	AudioManager.play_sfx_named("vase_break")
	if owner_level != null and is_instance_valid(owner_level) and owner_level.has_method("drop_loot"):
		owner_level.drop_loot(global_position + Vector2(0.0, -14.0), "vase")
	var tw := create_tween()
	tw.tween_callback(func(): _spr.frame = 1)
	tw.tween_interval(0.09)
	tw.tween_callback(func(): _spr.frame = 2)
	tw.tween_interval(0.09)
	tw.tween_callback(func(): _spr.frame = 3)
	tw.tween_interval(0.5)
	tw.tween_property(_spr, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
