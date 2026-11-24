extends CharacterBody2D

signal died(enemy)

const TYPES := {
	"td_black_knight_a": {"name": "Black Knight", "hp": 40, "dmg": 3, "speed": 54.0, "aggro": 220.0, "scale": 1.5, "idle": 6, "walk": 8, "attack": 16, "hit_frame": 6, "hurt": 4, "death": 4},
	"td_demon_a": {"name": "Demon", "hp": 30, "dmg": 2, "speed": 60.0, "aggro": 210.0, "scale": 1.5, "idle": 6, "walk": 8, "attack": 7, "hit_frame": 3, "hurt": 4, "death": 4},
	"td_demoness_a": {"name": "Demoness", "hp": 28, "dmg": 2, "speed": 62.0, "aggro": 210.0, "scale": 1.5, "idle": 6, "walk": 8, "attack": 9, "hit_frame": 4, "hurt": 4, "death": 4},
	"td_hellhound": {"name": "Hellhound", "hp": 24, "dmg": 2, "speed": 92.0, "aggro": 260.0, "scale": 1.4, "idle": 6, "walk": 8, "attack": 8, "hit_frame": 3, "hurt": 4, "death": 4},
	"td_lava_slime": {"name": "Lava Slime", "hp": 20, "dmg": 1, "speed": 38.0, "aggro": 170.0, "scale": 1.4, "idle": 6, "walk": 6, "attack": 6, "hit_frame": 3, "hurt": 4, "death": 4},
	"td_minotaur": {"name": "Minotaur", "hp": 70, "dmg": 4, "speed": 44.0, "aggro": 200.0, "scale": 1.7, "idle": 6, "walk": 8, "attack": 8, "hit_frame": 4, "hurt": 4, "death": 4},
	"td_eyeball": {"name": "Eyeball", "hp": 18, "dmg": 2, "speed": 50.0, "aggro": 200.0, "scale": 1.4, "idle": 6, "walk": 6, "attack": 8, "hit_frame": 4, "hurt": 4, "death": 4},
	"td_blood_a": {"name": "Blood Monster", "hp": 36, "dmg": 3, "speed": 52.0, "aggro": 200.0, "scale": 1.5, "idle": 6, "walk": 8, "attack": 8, "hit_frame": 4, "hurt": 4, "death": 4},
}
const REACH := 30.0
const ATK_CD := 1.2
static var _cache := {}

var kind := "td_demon_a"
var player: Node2D
var level: Node
var hp := 20
var max_hp := 20
var _cfg: Dictionary
var _spr: AnimatedSprite2D
var _path := PackedVector2Array()
var _pi := 0
var _repath := 0.0
var _cd := 0.5
var _attacking := false
var _hurt_t := 0.0
var _dead := false
var dmg_mult := 1
var _wander_t := 0.0
var _wander_dir := Vector2.ZERO


static func frames_for(k: String) -> SpriteFrames:
	if _cache.has(k):
		return _cache[k]
	var c: Dictionary = TYPES[k]
	var d := "res://assets/creatures/%s/" % k
	var tu = preload("res://scripts/tex_util.gd")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for spec in [["idle", "idle", int(c.idle), 8.0, true], ["walk", "walk", int(c.walk), 10.0, true], ["attack", "attack01", int(c.attack), 14.0, false], ["hurt", "hurt", int(c.hurt), 12.0, false], ["death", "death", int(c.death), 8.0, false]]:
		var tex: Texture2D = tu.load_tex(d + String(spec[1]) + ".png")
		sf.add_animation(String(spec[0]))
		sf.set_animation_speed(String(spec[0]), float(spec[3]))
		sf.set_animation_loop(String(spec[0]), bool(spec[4]))
		for i in int(spec[2]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 100, 0, 100, 100)
			sf.add_frame(String(spec[0]), at)
	_cache[k] = sf
	return sf


func setup(k: String, pos: Vector2, p: Node2D, lvl: Node) -> void:
	kind = k
	_cfg = TYPES[k]
	hp = int(_cfg.hp)
	max_hp = hp
	player = p
	level = lvl
	position = pos
	collision_layer = 8
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(12.0, 8.0)
	cs.shape = sh
	cs.position = Vector2(0.0, -4.0)
	add_child(cs)
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = frames_for(k)
	_spr.scale = Vector2.ONE * float(_cfg.scale)
	_spr.offset = Vector2(-3.0, -9.0)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	_spr.play("idle")
	_repath = randf() * 0.6


func hit(dmg: int, _dir: float) -> void:
	if _dead:
		return
	hp -= dmg
	_hurt_t = 0.25
	_attacking = false
	AudioManager.play_sfx_named("hit_body")
	if player != null and is_instance_valid(player):
		var kb := (global_position - player.global_position).normalized()
		velocity = kb * 120.0
	if hp <= 0:
		_die()
	else:
		_spr.play("hurt")


func _die() -> void:
	_dead = true
	collision_layer = 0
	_spr.play("death")
	died.emit(self)
	await get_tree().create_timer(1.4).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	if _dead or player == null or not is_instance_valid(player):
		return
	if level != null and bool(level.get("_dialog_active")):
		velocity = Vector2.ZERO
		return
	var pc: Vector2 = player.global_position
	var dist := global_position.distance_to(pc)
	if dist > 900.0:
		return
	if _hurt_t > 0.0:
		_hurt_t -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
	var alive: bool = int(player.get("hp")) > 0
	var want := Vector2.ZERO
	var in_restricted: bool = level != null and level.has_method("in_restricted") and bool(level.call("in_restricted", global_position))
	if in_restricted:
		var out: Vector2 = level.call("nearest_outside", global_position)
		want = (out - global_position).normalized()
	elif alive and dist < float(_cfg.aggro) and not (level != null and bool(level.call("in_restricted", pc))):
		if dist <= REACH:
			want = Vector2.ZERO
			_cd -= delta
			if not _attacking and _cd <= 0.0:
				_attack()
		else:
			_repath -= delta
			if _repath <= 0.0 or _pi >= _path.size():
				_repath = 0.7
				_path = level.call("find_path", global_position, pc, true)
				_pi = 0
			if _pi < _path.size():
				var wp := _path[_pi]
				if global_position.distance_to(wp) < 6.0:
					_pi += 1
				else:
					want = (wp - global_position).normalized()
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.0, 3.0)
			_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.5 else Vector2.ZERO
		want = _wander_dir * 0.4
	if _attacking:
		want = Vector2.ZERO
	var spd := float(_cfg.speed)
	velocity = velocity.move_toward(want * spd, 700.0 * delta)
	move_and_slide()
	if absf(velocity.x) > 4.0 and not _attacking:
		_spr.flip_h = velocity.x < 0.0
	elif _attacking or dist < REACH:
		_spr.flip_h = (pc.x - global_position.x) < 0.0
	if not _attacking:
		var an := "walk" if velocity.length() > 6.0 else "idle"
		if _spr.animation != an:
			_spr.play(an)


func _attack() -> void:
	_attacking = true
	_spr.play("attack")
	var frames := int(_cfg.attack)
	var t_hit := float(int(_cfg.hit_frame)) / 14.0
	await get_tree().create_timer(t_hit).timeout
	if not _dead and player != null and is_instance_valid(player) and global_position.distance_to(player.global_position) <= REACH + 12.0:
		var dx := signf(player.global_position.x - global_position.x)
		player.call("enemy_hit", int(_cfg.dmg) * dmg_mult, dx if dx != 0.0 else 1.0)
	await get_tree().create_timer(maxf(0.05, float(frames) / 14.0 - t_hit)).timeout
	_attacking = false
	_cd = ATK_CD
