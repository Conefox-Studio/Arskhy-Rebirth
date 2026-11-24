extends Node2D

var vel := Vector2.ZERO
var damage := 2
var player: CharacterBody2D
var _life := 2.4
var _done := false


func setup(from: Vector2, target: Vector2, p: CharacterBody2D, dmg: int, speed: float = 260.0) -> void:
	global_position = from
	player = p
	damage = dmg
	var dv := target - from
	var sx := 1.0 if dv.x >= 0.0 else -1.0
	var ax := maxf(absf(dv.x), 24.0)
	dv = Vector2(sx * ax, clampf(dv.y, -ax * 0.35, ax * 0.35))
	vel = dv.normalized() * speed
	rotation = vel.angle()
	z_index = 5
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(-10, 0), Vector2(8, 0), Color("8a6a3c"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -2.5), Vector2(14, 0), Vector2(8, 2.5)]), Color("cfd4da"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-14, -3), Vector2(-8, 0)]), Color("c9c4b6"))
	draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-14, 3), Vector2(-8, 0)]), Color("c9c4b6"))


func _physics_process(delta: float) -> void:
	if _done:
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var prev := global_position
	var nxt := prev + vel * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(prev, nxt + vel.normalized() * 8.0, 5)
	if not space.intersect_ray(q).is_empty():
		_done = true
		AudioManager.play_sfx_named("arrow_hit")
		queue_free()
		return
	global_position = nxt
	if player != null and is_instance_valid(player) and player.hp > 0:
		var d: Vector2 = player.global_position + Vector2(0.0, -16.0) - (global_position + vel.normalized() * 8.0)
		if absf(d.x) < 11.0 and absf(d.y) < 22.0:
			_done = true
			if player.has_method("enemy_hit"):
				player.call("enemy_hit", damage, 1.0 if vel.x >= 0.0 else -1.0)
			AudioManager.play_sfx_named("arrow_hit")
			queue_free()
