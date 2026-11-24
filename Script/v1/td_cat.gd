extends CharacterBody2D

const EnemyScript = preload("res://scripts/enemy.gd")
const SPEED := 118.0
const ATTACK_DAMAGE := 30
const REACH := 26.0

var level: Node
var player: Node2D
var seat := Vector2.ZERO
var _spr: AnimatedSprite2D
var _busy := false


func setup(lvl: Node, p: Node2D, pos: Vector2) -> void:
	level = lvl
	player = p
	seat = pos
	position = pos
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(12.0, 8.0)
	cs.shape = sh
	cs.position = Vector2(0.0, -4.0)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = EnemyScript.frames_for("cat")
	_spr.scale = Vector2(1.4, 1.4)
	_spr.offset = Vector2(0.0, -15.0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_spr.play("idle")


func face(dx: float) -> void:
	if absf(dx) > 0.5:
		_spr.flip_h = dx < 0.0


func sit() -> void:
	velocity = Vector2.ZERO
	_spr.play("idle")


func walk_to(dest: Vector2, timeout := 25.0, stop_dist := 18.0) -> void:
	var t := 0.0
	var path: PackedVector2Array = level.call("find_path", global_position, dest)
	var i := 0
	var stuck := 0.0
	var last := global_position
	var fails := 0
	while t < timeout and global_position.distance_to(dest) > stop_dist:
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		t += d
		if i >= path.size():
			path = level.call("find_path", global_position, dest + Vector2(randf_range(-24.0, 24.0), randf_range(-24.0, 24.0)))
			i = 0
			if path.is_empty():
				fails += 1
				if fails > 3:
					break
				continue
		var wp := path[i]
		if global_position.distance_to(wp) < 7.0:
			i += 1
			continue
		var dir := (wp - global_position).normalized()
		velocity = dir * SPEED
		face(dir.x)
		if _spr.animation != "chase":
			_spr.play("chase")
		move_and_slide()
		stuck += d
		if stuck > 0.45:
			if global_position.distance_to(last) < 3.0:
				fails += 1
				path = level.call("find_path", global_position, dest + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0)))
				i = 0
				if fails > 6:
					break
			last = global_position
			stuck = 0.0
	if global_position.distance_to(dest) > stop_dist + 60.0:
		global_position = dest
	velocity = Vector2.ZERO
	_spr.play("idle")


func nearest_enemy(from: Vector2, radius: float) -> Node2D:
	var best: Node2D = null
	var bd := radius
	var list = level.get("_enemies") if level != null else null
	if list is Array:
		for e in list:
			if e != null and is_instance_valid(e) and not bool(e.get("_dead")):
				var d: float = (e as Node2D).global_position.distance_to(from)
				if d < bd:
					bd = d
					best = e
	return best


func fight(e: Node2D, timeout := 7.0) -> void:
	var t := 0.0
	var cd := 0.0
	while t < timeout and e != null and is_instance_valid(e) and not bool(e.get("_dead")):
		await get_tree().physics_frame
		var d := get_physics_process_delta_time()
		t += d
		cd -= d
		var to := e.global_position - global_position
		face(to.x)
		if to.length() > REACH:
			var path: PackedVector2Array = level.call("find_path", global_position, e.global_position)
			if path.size() > 1:
				var dir := (path[mini(1, path.size() - 1)] - global_position).normalized()
				velocity = dir * SPEED
			else:
				velocity = to.normalized() * SPEED
			move_and_slide()
			if _spr.animation != "chase":
				_spr.play("chase")
		else:
			velocity = Vector2.ZERO
			if cd <= 0.0:
				cd = 0.75
				_spr.play("attack")
				await get_tree().create_timer(0.2).timeout
				if e != null and is_instance_valid(e) and not bool(e.get("_dead")):
					e.call("hit", ATTACK_DAMAGE, signf(to.x))
	velocity = Vector2.ZERO
	_spr.play("idle")


func walk_fighting(dest: Vector2, radius := 190.0, timeout := 40.0) -> void:
	var t := 0.0
	while t < timeout and global_position.distance_to(dest) > 22.0:
		var e := nearest_enemy(global_position, radius)
		if e != null:
			await fight(e, 6.0)
			t += 3.0
			continue
		await walk_to(dest, 2.0, 22.0)
		t += 2.0
