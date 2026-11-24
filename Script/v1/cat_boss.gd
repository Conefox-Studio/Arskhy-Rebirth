extends CharacterBody2D

signal fight_over(reason: String)
signal arrived

const EnemyScript = preload("res://scripts/enemy.gd")
const GRAVITY := 900.0
const MAX_HP := 3000
const STOP_HP := 1500
const PLAYER_STOP_HP := 5
const RUN := 92.0
const WALK := 46.0
const REACH := 28.0
const ATK_DAMAGE := 2
const ATK_CD := 1.1

var player: Node2D
var level: Node
var hp := MAX_HP
var mode := "idle"
var facing := -1.0
var _target_x := 0.0
var _spr: AnimatedSprite2D
var _cd := 0.6
var _attacking := false
var _hurt_t := 0.0


func setup(p: Node2D, lvl: Node, pos: Vector2) -> void:
	player = p
	level = lvl
	position = pos
	collision_layer = 8
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(14.0, 30.0)
	cs.shape = sh
	cs.position = Vector2(0.0, -15.0)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = EnemyScript.frames_for("cat")
	_spr.scale = Vector2(1.4, 1.4)
	_spr.offset = Vector2(0.0, -15.0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	face(-1.0)
	_spr.play("idle")


func face(dir: float) -> void:
	if dir != 0.0:
		facing = signf(dir)
		_spr.flip_h = facing < 0.0


func goto_x(x: float) -> void:
	_target_x = x
	mode = "goto"
	await arrived


func start_fight() -> void:
	hp = MAX_HP
	_cd = 0.8
	mode = "fight"


func end_fight(reason: String) -> void:
	if mode != "fight":
		return
	mode = "idle"
	_attacking = false
	fight_over.emit(reason)


func hit(dmg: int, dir: float) -> void:
	if mode != "fight":
		return
	hp = maxi(1, hp - dmg)
	_hurt_t = 0.12
	_spr.modulate = Color(1.0, 0.55, 0.55)
	velocity.x = dir * 70.0
	AudioManager.play_sfx_named("hit_body")
	if hp <= STOP_HP:
		end_fight("hp")


func _nearest_pickup() -> Node2D:
	var best: Node2D = null
	var bd := 170.0
	var list = level.get("_pickups") if level != null else null
	if list is Array:
		for pk in list:
			if pk != null and is_instance_valid(pk):
				var d := absf((pk as Node2D).global_position.x - global_position.x)
				if d < bd:
					bd = d
					best = pk
	return best


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if _hurt_t > 0.0:
		_hurt_t -= delta
		if _hurt_t <= 0.0:
			_spr.modulate = Color.WHITE
	var want_x := 0.0
	var anim := "idle"
	match mode:
		"goto":
			var dx := _target_x - global_position.x
			if absf(dx) < 4.0:
				mode = "idle"
				arrived.emit()
			else:
				want_x = signf(dx) * RUN
				face(dx)
				anim = "chase"
		"npc":
			if player != null and is_instance_valid(player):
				face(player.global_position.x - global_position.x)
		"fight":
			if player != null and is_instance_valid(player):
				if int(player.get("hp")) <= PLAYER_STOP_HP:
					end_fight("player")
				else:
					var pdx := player.global_position.x - global_position.x
					var pk := _nearest_pickup()
					if pk != null and absf(pdx) > 60.0:
						var kdx := pk.global_position.x - global_position.x
						if absf(kdx) < 10.0:
							pk.queue_free()
							hp = mini(MAX_HP, hp + 150)
							AudioManager.play_ui("select")
						else:
							want_x = signf(kdx) * RUN
							face(kdx)
							anim = "chase"
					elif absf(pdx) > REACH:
						want_x = signf(pdx) * RUN
						face(pdx)
						anim = "chase"
					else:
						face(pdx)
					_cd -= delta
					if not _attacking and _cd <= 0.0 and absf(pdx) <= REACH + 4.0 and absf(player.global_position.y - global_position.y) < 34.0:
						_attack()
	if _attacking:
		want_x = 0.0
		anim = "attack"
	velocity.x = move_toward(velocity.x, want_x, 900.0 * delta) if _hurt_t <= 0.0 else velocity.x
	if want_x != 0.0 and anim == "chase" and mode == "idle":
		anim = "walk"
	if _spr.animation != anim and not (_spr.animation == "attack" and _spr.is_playing() and _attacking):
		_spr.play(anim)
	move_and_slide()


func _attack() -> void:
	_attacking = true
	_spr.play("attack")
	await get_tree().create_timer(0.2).timeout
	if mode == "fight" and player != null and is_instance_valid(player):
		var d := player.global_position - global_position
		if absf(d.x) <= REACH + 10.0 and absf(d.y) < 36.0:
			player.call("enemy_hit", ATK_DAMAGE, signf(d.x) if d.x != 0.0 else facing)
	await get_tree().create_timer(0.22).timeout
	_attacking = false
	_cd = ATK_CD
