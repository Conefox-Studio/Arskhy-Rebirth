extends CharacterBody2D

const GRAVITY := 900.0
const DRAG := 0.12
const BARREL_DAMAGE := 1
const HIT_SPEED := 50.0
const FALL_LIMIT := 99999.0

var radius := 16.0
var wake_dx := 260.0
var wake_dy := 200.0
var fall_limit := FALL_LIMIT
var player: Node2D
var _awake := false
var _sprite: Sprite2D
var _hit_cd := 0.0
var _nudge := 1.0


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


func setup(tex: Texture2D, r: float, center: Vector2, p: Node2D) -> void:
	radius = r
	player = p
	position = center
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_make_body(1.0)
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = maxf(4.0, r - 1.0)
	col.shape = sh
	add_child(col)


func _ready() -> void:
	add_to_group("pushable")
	collision_layer = 4
	collision_mask = 1
	floor_stop_on_slope = false
	floor_constant_speed = false
	floor_max_angle = deg_to_rad(70.0)
	floor_snap_length = 3.0


func push(dir_x: float, speed: float) -> void:
	_wake(dir_x)
	velocity.x = dir_x * maxf(absf(velocity.x), speed * 1.6)


func hit(_dmg: int, dir: float) -> void:
	push(dir, 120.0)


func _wake(dir: float = 1.0) -> void:
	if _awake:
		return
	_awake = true
	Achievements.unlock("barrel_roll")
	_nudge = dir if dir != 0.0 else 1.0
	velocity.x = _nudge * 40.0


func _physics_process(delta: float) -> void:
	if position.y > fall_limit:
		queue_free()
		return
	if not _awake:
		if player != null and is_instance_valid(player):
			var d: Vector2 = player.global_position - global_position
			if absf(d.x) < wake_dx and absf(d.y) < wake_dy:
				_wake(1.0)
		if not _awake:
			return
	_hit_cd -= delta
	velocity.y += GRAVITY * delta
	var x0 := position.x
	move_and_slide()
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, absf(velocity.x) * DRAG * delta)
	if is_on_wall() and absf(get_last_motion().x) < 0.01:
		velocity.x = -velocity.x * 0.35
	_sprite.rotation += (position.x - x0) / radius
	if velocity.length() > HIT_SPEED:
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and e.has_method("crush") and not e.dead and e.body_center().distance_to(global_position) < radius + 14.0:
				e.crush(signf(velocity.x) if velocity.x != 0.0 else 1.0)
	if player != null and is_instance_valid(player) and _hit_cd <= 0.0 and velocity.length() > HIT_SPEED and BARREL_DAMAGE > 0:
		var pc: Vector2 = player.global_position + Vector2(0, -16)
		if pc.distance_to(global_position) < radius + 9.0 and player.has_method("enemy_hit"):
			_hit_cd = 1.0
			player.call("enemy_hit", BARREL_DAMAGE, signf(pc.x - global_position.x))
