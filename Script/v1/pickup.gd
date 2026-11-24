extends Node2D

var kind := "coin"
var player: Node2D
var _vel := Vector2.ZERO
var _t := randf() * 2.0
var _life := 22.0
var _spr: Sprite2D
var _grounded := false
var _taken := false


func setup(k: String, pos: Vector2, p: Node2D) -> void:
	kind = k
	player = p
	position = pos
	_vel = Vector2(randf_range(-80.0, 80.0), randf_range(-190.0, -120.0))


func _ready() -> void:
	z_index = 6
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/fx/coin.png" if kind == "coin" else "res://assets/fx/gems.png")
	_spr.hframes = 4
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.1, 1.1)
	add_child(_spr)


func _physics_process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	_life -= delta
	_spr.frame = int(_t * 9.0) % 4
	if _life <= 0.0:
		queue_free()
		return
	_spr.visible = _life > 3.0 or int(_life * 8.0) % 2 == 0
	if player != null and is_instance_valid(player):
		var to: Vector2 = player.global_position + Vector2(0.0, -16.0) - global_position
		if to.length() < 14.0:
			_collect()
			return
		if to.length() < 46.0 and _life < 21.4:
			position += to.normalized() * 230.0 * delta
			return
	var space := get_world_2d().direct_space_state
	if _grounded:
		var q0 := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, 7.0))
		q0.collision_mask = 1
		if space.intersect_ray(q0).is_empty():
			_grounded = false
		return
	_vel.y += 700.0 * delta
	var step := _vel * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0.0, maxf(step.y, 0.0) + 5.0))
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and _vel.y > 0.0:
		position.y = (hit.position as Vector2).y - 4.0
		_vel.y *= -0.35
		_vel.x *= 0.6
		if absf(_vel.y) < 35.0:
			_vel = Vector2.ZERO
			_grounded = true
	else:
		position += step


func _collect() -> void:
	_taken = true
	if kind == "coin":
		GameState.add_coins(1)
	else:
		GameState.add_gems(1)
	AudioManager.play_ui("tick")
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_spr, "scale", Vector2(1.8, 1.8), 0.18)
	tw.tween_property(_spr, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(queue_free)
