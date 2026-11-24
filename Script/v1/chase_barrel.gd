extends CharacterBody2D

const GRAVITY := 1400.0
const START_SPEED := 62.0
const MAX_SPEED := 92.0
const ACCEL := 40.0
const DAMAGE := 2
const Debris = preload("res://scripts/debris.gd")

var radius := 96.0
var player: Node2D
var route: Node
var trigger_x := 1.0e9
var end_pos := Vector2(1.0e9, 0.0)
var face_tex: Texture2D
var _sprite: Sprite2D
var _state := 0
var _speed := START_SPEED
var _hit_cd := 0.0
var _shake_cd := 0.0
var _landed := false


var body_tex: Texture2D = null
var body_offset := Vector2.ZERO
var _body: Sprite2D


func _make_body(scale_f: float) -> void:
	if body_tex == null:
		return
	_body = Sprite2D.new()
	_body.texture = body_tex
	_body.scale = Vector2(scale_f, scale_f)
	_body.position = body_offset * scale_f
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)
	move_child(_body, 0)


func setup(tex: Texture2D, base_r: float, center: Vector2, p: Node2D, scale_f: float) -> void:
	face_tex = tex
	player = p
	radius = base_r * scale_f
	position = center
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(scale_f, scale_f)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_make_body(scale_f)
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius - 3.0
	col.shape = sh
	add_child(col)
	visible = false
	z_index = 5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_stop_on_slope = false
	floor_constant_speed = false
	floor_max_angle = deg_to_rad(70.0)
	floor_snap_length = 4.0


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if _state == 0:
		if player != null and player.global_position.x >= trigger_x:
			_begin()
		return
	if _state == 2:
		return
	_hit_cd -= delta
	_shake_cd -= delta
	_speed = minf(MAX_SPEED, _speed + ACCEL * delta * 0.1)
	velocity.y += GRAVITY * delta
	velocity.x = _speed
	var x0 := position.x
	move_and_slide()
	_sprite.rotation += (position.x - x0) / radius
	if is_on_floor():
		if not _landed:
			_landed = true
			if route != null and player != null and absf(player.global_position.x - global_position.x) < 1000.0:
				route.shake_camera(7.0, 0.7)
			AudioManager.play_sfx_named("m_spikes")
		if _shake_cd <= 0.0:
			_shake_cd = 0.18
			_shake()
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("crush") and not e.dead and e.body_center().distance_to(global_position) < radius + 14.0:
			e.crush(1.0)
	for n in get_tree().get_nodes_in_group("pushable"):
		if n == self or not (n is Node2D):
			continue
		var nn := n as Node2D
		if _touches_box(nn):
			_smash(nn)
	if player != null and is_instance_valid(player):
		AudioManager.set_quake_distance(absf(player.global_position.x - global_position.x))
	if route != null:
		route.call("_crush_at", global_position, radius)
	if player != null and is_instance_valid(player) and _hit_cd <= 0.0:
		var pc: Vector2 = player.global_position + Vector2(0, -16)
		if pc.distance_to(global_position) < radius * 0.92:
			_hit_cd = 1.2
			if route != null and route.has_method("crush_death"):
				route.call("crush_death")
			elif player.has_method("enemy_hit"):
				player.call("enemy_hit", DAMAGE, signf(pc.x - global_position.x))
	if global_position.distance_to(end_pos) < radius + 8.0 or global_position.x > end_pos.x:
		_shatter()


func _begin() -> void:
	_state = 1
	visible = true
	if route != null:
		route.call("_chase_started")
		route.shake_camera(5.0, 1.0)
	AudioManager.start_quake()


func _shake() -> void:
	if route == null or player == null or not is_instance_valid(player):
		return
	var dist := absf(player.global_position.x - global_position.x)
	var pw := 3.4 * clampf(1.0 - dist / 1000.0, 0.0, 1.0)
	if pw < 0.3:
		return
	route.shake_camera(pw, 0.25)


func _touches_box(n: Node2D) -> bool:
	var has_rect := false
	for c in n.get_children():
		var cs := c as CollisionShape2D
		if cs == null or not (cs.shape is RectangleShape2D):
			continue
		has_rect = true
		var sz: Vector2 = (cs.shape as RectangleShape2D).size
		var ctr: Vector2 = cs.global_position
		var cp := Vector2(clampf(global_position.x, ctr.x - sz.x * 0.5, ctr.x + sz.x * 0.5), clampf(global_position.y, ctr.y - sz.y * 0.5, ctr.y + sz.y * 0.5))
		if cp.distance_to(global_position) < radius - 2.0:
			return true
	if has_rect:
		return false
	return n.global_position.distance_to(global_position) < radius + 10.0


func _smash(n: Node2D) -> void:
	var parent := n.get_parent()
	for c in n.get_children():
		var spr := c as Sprite2D
		if spr != null and spr.texture != null and parent != null:
			var sz := spr.texture.get_size()
			var rect := Rect2(n.global_position + spr.position, sz) if not spr.centered else Rect2(n.global_position + spr.position - sz * 0.5, sz)
			Debris.burst(parent, spr.texture, rect, clampi(int(sz.x * sz.y / 100.0), 12, 40), 1.0)
	AudioManager.play_sfx_named("crate_break")
	n.queue_free()


func _shatter() -> void:
	_state = 2
	var parent := get_parent()
	if parent != null and face_tex != null:
		var rect := Rect2(global_position - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
		Debris.burst(parent, face_tex, rect, 42, 1.4)
	if route != null:
		route.shake_camera(9.0, 0.9)
		route.call("_chase_ended")
	AudioManager.stop_quake(0.5)
	AudioManager.play_sfx_named("barrel_explosion")
	queue_free()


func _exit_tree() -> void:
	if _state == 1:
		AudioManager.stop_quake(0.3)
