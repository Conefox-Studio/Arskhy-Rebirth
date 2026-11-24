extends StaticBody2D

const GHOST_DIR := "res://assets/creatures/ghost/"
const ArrowScript = preload("res://scripts/goblin_arrow.gd")

const KINDS := {
	"ghost": {"name": "Ghost", "hp": 10, "damage": 2, "speed": 38.0, "chase_speed": 62.0,
		"aggro": 190.0, "scale": 1.3, "radius": 11.0, "flying": true},
	"demon": {"name": "Demon", "hp": 18, "damage": 2, "speed": 30.0, "chase_speed": 58.0,
		"aggro": 170.0, "scale": 1.8, "radius": 8.0, "flying": false,
		"dir": "demon", "att_frames": 7, "off": Vector2(-3.0, -9.0), "reach": 34.0},
	"blood_monster": {"name": "Blood Monster", "hp": 26, "damage": 3, "speed": 24.0, "chase_speed": 48.0,
		"aggro": 150.0, "scale": 1.8, "radius": 8.0, "flying": false,
		"dir": "blood_monster", "att_frames": 8, "off": Vector2(-3.0, -8.0), "reach": 32.0},
	"black_knight_c": {"name": "Black Knight", "hp": 36, "damage": 3, "speed": 30.0, "chase_speed": 58.0,
		"aggro": 210.0, "scale": 1.8, "radius": 8.0, "flying": false,
		"dir": "black_knight_c", "att_frames": 8, "off": Vector2(-3.0, -9.0), "reach": 36.0},
	"cat": {"name": "Cat", "hp": 20, "damage": 2, "speed": 34.0, "chase_speed": 84.0,
		"aggro": 190.0, "scale": 1.4, "radius": 9.0, "flying": false,
		"dir": "cat", "cat": true, "att_frames": 4, "off": Vector2(0.0, -15.0), "reach": 26.0},
	"goblin_rogue": {"name": "Goblin Rogue", "hp": 12, "damage": 1, "speed": 34.0, "chase_speed": 82.0,
		"aggro": 175.0, "scale": 1.0, "radius": 12.0, "flying": false, "cy": 18.0,
		"dir": "goblin_rogue", "att_frames": 8, "off": Vector2(0.0, -10.0), "reach": 28.0, "hit_from": 2,
		"idle_ms": [200], "att_ms": [150, 150, 75, 75, 150, 75, 75, 150], "voice": "hi", "v_aggro": "gob_cackle"},
	"goblin_poison": {"name": "Goblin Rogue Poison", "hp": 12, "damage": 1, "speed": 32.0, "chase_speed": 76.0,
		"aggro": 175.0, "scale": 1.0, "radius": 12.0, "flying": false, "cy": 18.0, "poison": 3,
		"dir": "goblin_poison", "att_frames": 8, "off": Vector2(0.0, -10.0), "reach": 28.0, "hit_from": 2,
		"idle_ms": [200], "att_ms": [150, 150, 75, 75, 150, 75, 75, 150], "voice": "hi", "v_aggro": "gob_cackle"},
	"goblin_warrior": {"name": "Goblin Warrior", "hp": 20, "damage": 2, "speed": 26.0, "chase_speed": 54.0,
		"aggro": 165.0, "scale": 1.0, "radius": 13.0, "flying": false, "cy": 18.0,
		"dir": "goblin_warrior", "att_frames": 4, "off": Vector2(0.0, -10.0), "reach": 46.0, "hit_from": 1,
		"idle_ms": [200], "att_ms": [220, 110, 110, 240], "voice": "mid", "v_aggro": "gob_snarl"},
	"goblin_barbarian": {"name": "Goblin Barbarian", "hp": 28, "damage": 3, "speed": 22.0, "chase_speed": 46.0,
		"aggro": 150.0, "scale": 1.0, "radius": 14.0, "flying": false, "cy": 19.0,
		"dir": "goblin_barbarian", "att_frames": 4, "off": Vector2(0.0, -10.0), "reach": 40.0, "hit_from": 1,
		"idle_ms": [200], "att_ms": [260, 120, 120, 260], "voice": "lo", "v_aggro": "gob_grunt"},
	"goblin_hunter": {"name": "Goblin Hunter", "hp": 10, "damage": 1, "speed": 22.0, "chase_speed": 44.0,
		"aggro": 260.0, "scale": 1.0, "radius": 11.0, "flying": false, "cy": 18.0,
		"dir": "goblin_hunter", "att_frames": 11, "off": Vector2(0.0, -10.0), "reach": 0.0,
		"archer": true, "release_frame": 8, "arrow_damage": 2, "shot_cd": 2.6, "range": 250.0,
		"idle_ms": [200], "ranged_ms": [130, 130, 70, 130, 70, 130, 100, 100, 70, 100, 100],
		"voice": "hi", "v_aggro": "gob_shout_hi"},
}

const GHOST_FW := 170
const GHOST_FH := 35
const GHOST_BODY_X := 58.0
const ATTACK_CX: Array = [56.0, 56.0, 56.0, 58.0, 58.0, 84.0, 92.0, 121.0, 134.0, 148.0]
const ATTACK_HIT_FRAMES := [5, 6, 7, 8, 9]
const RANGED_PROJ_X: Array = [-1.0, -1.0, -1.0, 80.0, 81.0, 84.0, 110.0, 135.0, 156.0]
const RANGED_HIT_FRAMES := [4, 5, 6, 7, 8]
const RANGED_DAMAGE := 1

static var _cache := {}

var free_float := false
var _ranged_cd := 3.0
var _ranged := false
var kind := "ghost"
var cfg: Dictionary
var player: CharacterBody2D
var ground_fn: Callable
var min_x := 0.0
var max_x := 0.0
var home := Vector2.ZERO
var hp := 10
var dead := false

var _sprite: AnimatedSprite2D
var _t := randf() * 50.0
var _dir := 1.0
var _aggro := false
var _wander_t := 0.0
var _wander_dir := 0.0
var _hurt_t := 0.0
var _attack_cd := 1.0
var _attacking := false
var _react_t := 0.0
var _touch_cd := 0.0
var _knock := 0.0
var _arrow_fired := false
static var _voice_ms := 0
var _busy_t := 0.0


static func _add_sheet(sf: SpriteFrames, anim: String, tex: Texture2D, fw: int, fh: int, row: int, count: int, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for i in count:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * fw, row * fh, fw, fh)
		sf.add_frame(anim, a)


static func _add_strip(sf: SpriteFrames, anim: String, tex: Texture2D, fw: int, fh: int, count: int, ms: Array, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, 10.0)
	sf.set_animation_loop(anim, loop)
	for i in count:
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame(anim, a, float(ms[i % ms.size()]) / 100.0)


static func _goblin_frames(k: String) -> SpriteFrames:
	var c: Dictionary = KINDS[k]
	var d: String = "res://assets/creatures/%s/" % String(c.dir)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var f := func(n: String) -> Texture2D: return preload("res://scripts/tex_util.gd").load_tex(d + n + ".png")
	_add_strip(sf, "idle", f.call("idle"), 100, 100, 6, c.idle_ms, true)
	_add_strip(sf, "idle_red", f.call("idle"), 100, 100, 6, [110], true)
	_add_strip(sf, "walk", f.call("walk"), 100, 100, 6, [120], true)
	_add_strip(sf, "chase", f.call("walk"), 100, 100, 6, [75], true)
	_add_strip(sf, "hurt", f.call("hurt"), 100, 100, 4, [80, 80, 80, 120], false)
	_add_strip(sf, "death", f.call("death"), 100, 100, 6, [90, 90, 90, 100, 160, 260], false)
	if c.has("ranged_ms"):
		_add_strip(sf, "ranged", f.call("ranged"), 100, 100, int(c.att_frames), c.ranged_ms, false)
	else:
		_add_strip(sf, "attack", f.call("attack01"), 100, 100, int(c.att_frames), c.att_ms, false)
	return sf


static func _walker_frames(k: String) -> SpriteFrames:
	var d: String = "res://assets/creatures/%s/" % String(KINDS[k].dir)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var f := func(n: String) -> Texture2D: return preload("res://scripts/tex_util.gd").load_tex(d + n + ".png")
	_add_sheet(sf, "idle", f.call("idle"), 100, 100, 0, 6, 8.0, true)
	_add_sheet(sf, "idle_red", f.call("idle"), 100, 100, 0, 6, 10.0, true)
	_add_sheet(sf, "walk", f.call("walk"), 100, 100, 0, 8, 10.0, true)
	_add_sheet(sf, "chase", f.call("walk"), 100, 100, 0, 8, 14.0, true)
	_add_sheet(sf, "hurt", f.call("hurt"), 100, 100, 0, 4, 12.0, false)
	_add_sheet(sf, "death", f.call("death"), 100, 100, 0, 4, 8.0, false)
	_add_sheet(sf, "attack", f.call("attack01"), 100, 100, 0, int(KINDS[k].att_frames), 12.0, false)
	return sf


static func _cat_frames(k: String) -> SpriteFrames:
	var d: String = "res://assets/creatures/%s/" % String(KINDS[k].dir)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var f := func(n: String) -> Texture2D: return preload("res://scripts/tex_util.gd").load_tex(d + n + ".png")
	_add_sheet(sf, "idle", f.call("idle"), 32, 32, 0, 3, 5.0, true)
	_add_sheet(sf, "idle_red", f.call("idle"), 32, 32, 0, 3, 8.0, true)
	_add_sheet(sf, "walk", f.call("walk"), 32, 32, 0, 3, 7.0, true)
	_add_sheet(sf, "chase", f.call("run"), 32, 32, 0, 4, 12.0, true)
	_add_sheet(sf, "hurt", f.call("hit"), 32, 32, 0, 4, 12.0, false)
	_add_sheet(sf, "death", f.call("dead"), 32, 32, 0, 5, 8.0, false)
	_add_sheet(sf, "attack", f.call("attack"), 32, 32, 0, int(KINDS[k].att_frames), 12.0, false)
	return sf


static func frames_for(k: String) -> SpriteFrames:
	if _cache.has(k):
		return _cache[k]
	if k != "ghost":
		_cache[k] = _goblin_frames(k) if KINDS[k].has("idle_ms") else (_cat_frames(k) if KINDS[k].has("cat") else _walker_frames(k))
		return _cache[k]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var f := func(n: String) -> Texture2D: return preload("res://scripts/tex_util.gd").load_tex(GHOST_DIR + n + ".png")
	_add_sheet(sf, "idle", f.call("idle"), GHOST_FW, GHOST_FH, 0, 7, 8.0, true)
	_add_sheet(sf, "walk", f.call("walk"), GHOST_FW, GHOST_FH, 0, 5, 8.0, true)
	_add_sheet(sf, "chase", f.call("chase"), GHOST_FW, GHOST_FH, 0, 5, 12.0, true)
	_add_sheet(sf, "hurt", f.call("hurt"), GHOST_FW, GHOST_FH, 0, 6, 14.0, false)
	_add_sheet(sf, "death", f.call("death"), GHOST_FW, GHOST_FH, 0, 12, 12.0, false)
	_add_sheet(sf, "attack", f.call("attack"), GHOST_FW, GHOST_FH, 0, 10, 14.0, false)
	_add_sheet(sf, "idle_red", f.call("idle_red"), GHOST_FW, GHOST_FH, 0, 7, 8.0, true)
	_add_sheet(sf, "ranged", f.call("attack_ranged"), GHOST_FW, GHOST_FH, 0, 9, 12.0, false)
	_add_sheet(sf, "react", f.call("react"), GHOST_FW, GHOST_FH, 0, 4, 10.0, false)
	_cache[k] = sf
	return sf


func setup(k: String, pos: Vector2, p: CharacterBody2D, ground: Callable, lo: float, hi: float) -> void:
	kind = k
	cfg = KINDS[k]
	hp = int(cfg.hp)
	player = p
	ground_fn = ground
	min_x = lo
	max_x = hi
	home = pos
	position = pos
	add_to_group("enemy")
	collision_layer = 8
	collision_mask = 0
	_dir = -1.0 if randf() < 0.5 else 1.0
	_attack_cd = randf_range(0.5, 2.0)

	var sc: float = cfg.scale
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames_for(k)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(sc, sc)
	_sprite.z_index = 4
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	_play("idle")
	_sprite.frame = randi() % 5

	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = float(cfg.radius) * sc * 0.75 + 4.0
	cs.shape = sh
	if not bool(cfg.flying):
		cs.position = Vector2(0, -_cy())
	add_child(cs)
	_apply_flip()


func _cy() -> float:
	return float(cfg.get("cy", 10.0 * float(cfg.scale)))


func _play(anim: String) -> void:
	if _sprite.animation != anim or not _sprite.is_playing():
		_sprite.play(anim)


func _apply_flip() -> void:
	_sprite.flip_h = _dir < 0.0
	if kind == "ghost":
		var ox := (GHOST_FW * 0.5 - GHOST_BODY_X)
		_sprite.offset = Vector2(-ox if _sprite.flip_h else ox, -1.5)
	else:
		var off: Vector2 = cfg.get("off", Vector2(0.0, -15.0))
		_sprite.offset = Vector2(-off.x if _sprite.flip_h else off.x, off.y)


func _ground_y(x: float) -> float:
	if ground_fn.is_valid():
		return float(ground_fn.call(x))
	return home.y


func _process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_hurt_t = maxf(0.0, _hurt_t - delta)
	_touch_cd = maxf(0.0, _touch_cd - delta)
	_attack_cd = maxf(0.0, _attack_cd - delta)

	if absf(_knock) > 1.0:
		_step_x(_knock * delta)
		_knock = move_toward(_knock, 0.0, 600.0 * delta)

	var active: bool = player != null and is_instance_valid(player) and player.hp > 0 and player.controls_enabled
	var to_p := Vector2.ZERO
	if active:
		to_p = player.global_position + Vector2(0, -16) - global_position
	var dist := to_p.length()
	var was_aggro := _aggro
	_aggro = active and dist < float(cfg.aggro) * (1.35 if _aggro else 1.0)
	if _aggro and not was_aggro:
		_voice("aggro")

	_ranged_cd = maxf(0.0, _ranged_cd - delta)

	if _attacking or _ranged or _react_t > 0.0:
		_busy_t += delta
		if _busy_t > 1.8:
			_attacking = false
			_ranged = false
			_react_t = 0.0
			_busy_t = 0.0
			_play("idle")
	else:
		_busy_t = 0.0

	if _hurt_t > 0.0 or _attacking or _ranged or _react_t > 0.0:
		_react_t = maxf(0.0, _react_t - delta)
		_float_y(delta, to_p)
		_touch_damage(active, to_p)
		return

	if _aggro and not was_aggro and kind == "ghost":
		_react_t = 0.4
		_face(to_p.x)
		_play("react")
		return

	var speed := 0.0
	if _aggro:
		_face(to_p.x)
		if bool(cfg.get("archer", false)):
			var ax := absf(to_p.x)
			if _ranged_cd <= 0.0 and active and ax > 60.0 and ax < float(cfg.get("range", 240.0)) and absf(to_p.y) < 60.0:
				_start_shot()
				return
			if ax < 85.0:
				speed = -float(cfg.chase_speed) * signf(to_p.x) * 0.9
				_play("walk")
			elif ax > 190.0:
				speed = float(cfg.chase_speed) * signf(to_p.x)
				_play("chase")
			else:
				_play("idle_red")
			_step_x(speed * delta)
			_float_y(delta, to_p)
			_touch_damage(active, to_p)
			return
		if kind == "ghost" and dist < 62.0 and _attack_cd <= 0.0 and active:
			_start_attack()
			return
		if kind != "ghost" and dist < float(cfg.reach) + 8.0 and absf(to_p.y) < 34.0 and _attack_cd <= 0.0 and active:
			_start_attack()
			return
		if kind == "ghost" and dist >= 70.0 and dist <= 125.0 and absf(to_p.y) < 30.0 and _ranged_cd <= 0.0 and active:
			_ranged = true
			_ranged_cd = 4.0
			_play("ranged")
			return
		if kind != "ghost" and absf(to_p.x) < 22.0:
			_play("idle_red")
		elif absf(to_p.x) > 6.0:
			speed = float(cfg.chase_speed) * signf(to_p.x)
			_play("chase")
		else:
			_play("idle_red")
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(1.5, 3.5)
			_wander_dir = [-1.0, 0.0, 1.0][randi() % 3]
		if home.x - position.x > 90.0:
			_wander_dir = 1.0
		elif position.x - home.x > 90.0:
			_wander_dir = -1.0
		if _wander_dir != 0.0:
			_face(_wander_dir)
			speed = float(cfg.speed) * _wander_dir
			_play("walk")
		else:
			_play("idle")

	_step_x(speed * delta)
	_float_y(delta, to_p)
	_touch_damage(active, to_p)


func _step_x(dx: float) -> void:
	var nx := clampf(position.x + dx, min_x, max_x)
	if kind == "ghost" or is_equal_approx(nx, position.x) or _walk_ok(nx):
		position.x = nx


func _walk_ok(nx: float) -> bool:
	var gy := _ground_y(nx)
	if absf(gy - position.y) > 14.0:
		return false
	if not is_inside_tree():
		return true
	var space := get_world_2d().direct_space_state
	var dir := signf(nx - position.x)
	var fx := nx + dir * float(cfg.radius) * float(cfg.scale) * 0.5
	for h in [-22.0, -34.0, -46.0]:
		var q := PhysicsRayQueryParameters2D.create(Vector2(position.x, position.y + h), Vector2(fx, position.y + h), 5)
		if not space.intersect_ray(q).is_empty():
			return false
	var gq := PhysicsRayQueryParameters2D.create(Vector2(nx, gy - 30.0), Vector2(nx, gy + 40.0), 1)
	return not space.intersect_ray(gq).is_empty()


func body_center() -> Vector2:
	return global_position + (Vector2.ZERO if bool(cfg.flying) else Vector2(0, -_cy()))


func crush(dir: float) -> void:
	if dead:
		return
	hp = 0
	dead = true
	_drop_loot()
	_attacking = false
	_ranged = false
	collision_layer = 0
	_dir = signf(dir) if dir != 0.0 else _dir
	_apply_flip()
	_sprite.play("death")
	_voice("death")


func _face(dx: float) -> void:
	if absf(dx) < 2.0:
		return
	var nd := signf(dx)
	if nd != _dir:
		_dir = nd
		_apply_flip()


func _float_y(delta: float, to_p: Vector2) -> void:
	var gy := _ground_y(position.x)
	if kind == "ghost":
		var want := gy - 38.0 + sin(_t * 2.0) * 4.0
		if _aggro:
			want = global_position.y + to_p.y - 6.0
			if not free_float:
				want = clampf(want, gy - 90.0, gy - 14.0)
			want += sin(_t * 3.0) * 3.0
		position.y = lerpf(position.y, want, minf(1.0, 4.0 * delta))
	else:
		position.y = lerpf(position.y, gy, minf(1.0, 14.0 * delta))


func _drop_loot() -> void:
	var lvl := get_tree().current_scene
	if lvl != null and lvl.has_method("drop_loot"):
		lvl.drop_loot(global_position + Vector2(0.0, -14.0), "enemy")


func _start_attack() -> void:
	_attacking = true
	_attack_cd = 2.2
	_play("attack")
	_voice("attack")


func _start_shot() -> void:
	_ranged = true
	_arrow_fired = false
	_ranged_cd = float(cfg.get("shot_cd", 2.6))
	_play("ranged")


func _fire_arrow() -> void:
	_arrow_fired = true
	if player == null or not is_instance_valid(player) or get_parent() == null:
		return
	var a: Node2D = ArrowScript.new()
	get_parent().add_child(a)
	var from := global_position + Vector2(_dir * 24.0, -_cy() - 1.0)
	a.call("setup", from, player.global_position + Vector2(0.0, -16.0), player, int(cfg.get("arrow_damage", 2)))
	if global_position.distance_to(player.global_position) < 520.0:
		AudioManager.play_sfx_named("bow_shot")


func _voice(ev: String) -> void:
	var reg := String(cfg.get("voice", ""))
	if reg == "" or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > 480.0:
		return
	var now := Time.get_ticks_msec()
	if now - _voice_ms < 140:
		return
	var key := ""
	match ev:
		"aggro":
			key = String(cfg.get("v_aggro", ""))
		"attack":
			key = "gob_shout_" + reg
		"hurt":
			key = "gob_hurt_" + reg
		"death":
			key = "gob_death_" + reg
	if key == "":
		return
	_voice_ms = now
	AudioManager.play_sfx_named(key)


func _on_anim_finished() -> void:
	if dead:
		queue_free()
		return
	if _sprite.animation == "attack":
		_attacking = false
		if kind == "ghost":
			position.x = clampf(position.x + _dir * (ATTACK_CX[9] - GHOST_BODY_X) * float(cfg.scale), min_x, max_x)
		_play("idle")
	elif _sprite.animation == "ranged":
		_ranged = false
		_play("idle")
	elif _sprite.animation == "hurt":
		_play("idle")
	elif _sprite.animation == "react":
		_react_t = 0.0
		_play("chase")


func _on_frame_changed() -> void:
	if bool(cfg.get("archer", false)):
		if _sprite.animation == "ranged" and _ranged and not _arrow_fired and _sprite.frame >= int(cfg.release_frame):
			_fire_arrow()
		return
	if kind == "ghost" and _sprite.animation == "ranged" and _ranged and _sprite.frame in RANGED_HIT_FRAMES:
		if player != null and is_instance_valid(player) and player.hp > 0:
			var px := global_position.x + _dir * (float(RANGED_PROJ_X[_sprite.frame]) - GHOST_BODY_X) * float(cfg.scale)
			var dd := player.global_position + Vector2(0, -16) - Vector2(px, global_position.y)
			if absf(dd.x) < 22.0 and absf(dd.y) < 30.0 and _touch_cd <= 0.0:
				_touch_cd = 1.0
				if player.has_method("enemy_hit"):
					player.call("enemy_hit", RANGED_DAMAGE, signf(dd.x) if dd.x != 0.0 else _dir)
	if kind != "ghost" and _sprite.animation == "attack" and _attacking and _sprite.frame >= int(cfg.get("hit_from", int(cfg.att_frames) - 3)):
		if player != null and is_instance_valid(player) and player.hp > 0 and _touch_cd <= 0.0:
			var wd := player.global_position + Vector2(0, -16) - Vector2(global_position.x + _dir * float(cfg.reach) * 0.5, global_position.y - 14.0)
			if absf(wd.x) < float(cfg.reach) * 0.75 and absf(wd.y) < 30.0:
				_deal_damage(signf(wd.x) if wd.x != 0.0 else _dir)
		return
	if _sprite.animation == "attack" and _attacking and _sprite.frame in ATTACK_HIT_FRAMES:
		if player != null and is_instance_valid(player) and player.hp > 0:
			var vx := global_position.x + _dir * (float(ATTACK_CX[_sprite.frame]) - GHOST_BODY_X) * float(cfg.scale)
			var d := player.global_position + Vector2(0, -16) - Vector2(vx, global_position.y)
			if absf(d.x) < 24.0 and absf(d.y) < 30.0:
				_deal_damage(signf(d.x) if d.x != 0.0 else _dir)


func _touch_damage(active: bool, to_p: Vector2) -> void:
	if not active or _touch_cd > 0.0:
		return
	var r: float = float(cfg.radius) * float(cfg.scale) * 0.6 + 8.0
	var center_off := Vector2(0, -_cy()) if not bool(cfg.flying) else Vector2.ZERO
	var d := to_p - center_off
	if absf(d.x) < r and absf(d.y) < r + 10.0:
		_deal_damage(signf(d.x) if d.x != 0.0 else _dir)


func _deal_damage(dir_to_player: float) -> void:
	_touch_cd = 1.0
	if player.has_method("enemy_hit"):
		var hp_before: int = int(player.hp)
		player.call("enemy_hit", int(cfg.damage), dir_to_player)
		if int(cfg.get("poison", 0)) > 0 and int(player.hp) < hp_before and player.has_method("apply_poison"):
			player.call("apply_poison", int(cfg.poison))


func hit(dmg: int, dir: float) -> void:
	if dead:
		return
	hp -= dmg
	_attacking = false
	_ranged = false
	_knock = dir * 140.0
	if hp <= 0:
		dead = true
		_drop_loot()
		collision_layer = 0
		_sprite.play("death")
		_voice("death")
		return
	_hurt_t = 0.45
	_sprite.play("hurt")
	_voice("hurt")
