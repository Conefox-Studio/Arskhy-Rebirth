extends StaticBody2D

signal defeated
signal hp_changed(hp: int, max_hp: int)
signal mp_changed(mp: float, max_mp: float)
signal shake_requested(power: float, duration: float)

const DIR := "res://assets/creatures/ghost_executor/"
const MinionScript = preload("res://scripts/boss_minion.gd")
const TexUtil = preload("res://scripts/tex_util.gd")

const CELL := 100
const SPRITE_SCALE := 1.25
const BODY := Vector2(56.0, 52.0)
const HP_BY_DIFF := [500, 750, 1000, 2000]
const MINIONS_BY_DIFF := [2, 3, 4, 5]
const MELEE_DMG := [2, 3, 4, 5]
const SKILL_DMG := [2, 3, 4, 5]
const MAX_MP := 100.0
const MAX_MINIONS := 8
const COST_SKILL := 25.0
const COST_SUMMON := 40.0

static var _frames_cache: SpriteFrames

var display_name := "GHOST EXECUTOR"
var max_hp := 100
var hp := 100
var mp := 60.0
var player: CharacterBody2D
var ground_fn: Callable
var bounds_x := Vector2(0.0, 99999.0)
var active := false
var dead := false

var _diff := 1
var _state := "idle"
var _dir := -1.0
var _sprite: AnimatedSprite2D
var _t := 0.0
var _melee_cd := 2.0
var _skill_cd := 5.0
var _summon_cd := 3.5
var _marks := {}
var _flash := 0.0
var _knock := 0.0
var _minions: Array = []


func setup(p: CharacterBody2D, gfn: Callable, pos: Vector2, diff: int) -> void:
	player = p
	ground_fn = gfn
	position = pos
	_diff = clampi(diff, 0, 3)
	max_hp = HP_BY_DIFF[_diff]
	hp = max_hp
	collision_layer = 8
	collision_mask = 0
	z_index = 4
	var col := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 20.0
	shape.height = 76.0
	col.shape = shape
	add_child(col)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.frame_changed.connect(_on_frame_changed)
	add_child(_sprite)
	_sprite.play("idle2")
	_apply_flip()


static func _frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_add_sheet(sf, "idle", "idle.png", 4, 6.0, true)
	_add_sheet(sf, "idle2", "idle2.png", 8, 8.0, true)
	_add_sheet(sf, "attack", "attack.png", 13, 14.0, false)
	_add_sheet(sf, "skill", "skill.png", 12, 12.0, false)
	_add_sheet(sf, "summon", "summon.png", 5, 8.0, false)
	_add_sheet(sf, "death", "death.png", 18, 10.0, false)
	_frames_cache = sf
	return sf


static func _add_sheet(sf: SpriteFrames, anim: String, file: String, count: int, fps: float, loop: bool) -> void:
	var tex: Texture2D = TexUtil.load_tex(DIR + file)
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	if tex == null:
		return
	var cols := maxi(1, tex.get_width() / CELL)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((i % cols) * CELL, (i / cols) * CELL, CELL, CELL)
		sf.add_frame(anim, at)


func _apply_flip() -> void:
	_sprite.flip_h = _dir < 0.0
	var ox := 50.0 - BODY.x
	_sprite.offset = Vector2(-ox if _sprite.flip_h else ox, 50.0 - BODY.y)


func _ground_y(x: float) -> float:
	if ground_fn.is_valid():
		return float(ground_fn.call(x))
	return position.y + 40.0


func appear(duration: float) -> void:
	_state = "appear"
	modulate.a = 0.0
	var end_y := position.y
	position.y += 36.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, duration)
	tw.tween_property(self, "position:y", end_y, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if not dead:
			_state = "idle")


func activate() -> void:
	active = true


func _process(delta: float) -> void:
	if dead or player == null or not is_instance_valid(player):
		return
	_t += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
		_sprite.modulate = Color(1.0 + _flash * 8.0, 1.0 + _flash * 8.0, 1.0 + _flash * 8.0)
	else:
		_sprite.modulate = Color.WHITE
	var phase2 := hp * 2 <= max_hp
	var alive: bool = player.hp > 0 and player.controls_enabled
	var to_p := player.global_position.x - global_position.x

	if active:
		mp = minf(MAX_MP, mp + (9.0 if phase2 else 6.0) * delta)
		mp_changed.emit(mp, MAX_MP)
		_melee_cd -= delta
		_skill_cd -= delta
		_summon_cd -= delta

	if _state == "idle" and absf(to_p) > 4.0:
		_dir = signf(to_p)
		_apply_flip()

	var want_y := _ground_y(global_position.x) - 40.0 + sin(_t * 2.0) * 5.0
	if _state != "appear":
		position.y = lerpf(position.y, want_y, minf(1.0, 6.0 * delta))

	_knock = move_toward(_knock, 0.0, 260.0 * delta)
	var vx := _knock
	if _state == "idle" and active and alive:
		var speed := 58.0 if phase2 else 46.0
		if absf(to_p) > 96.0:
			vx += signf(to_p) * speed
		elif absf(to_p) < 44.0:
			vx -= signf(to_p) * speed * 0.7
	position.x = clampf(position.x + vx * delta, bounds_x.x, bounds_x.y)

	if _state == "idle" and active and alive:
		_decide(to_p, phase2)


func _decide(to_p: float, phase2: bool) -> void:
	_minions = _minions.filter(func(m): return is_instance_valid(m) and not m.dead)
	var cd := 0.7 if phase2 else 1.0
	if absf(to_p) < 64.0 and _melee_cd <= 0.0:
		_melee_cd = 1.8 * cd
		_start("melee", "attack")
		AudioManager.play_sfx_named("swing")
	elif _summon_cd <= 0.0 and mp >= COST_SUMMON and _minions.size() < MAX_MINIONS - 1:
		_summon_cd = 11.0 * cd
		mp -= COST_SUMMON
		_start("summon", "summon")
		AudioManager.play_sfx_named("cast")
	elif _skill_cd <= 0.0 and mp >= COST_SKILL and absf(to_p) < 84.0:
		_skill_cd = 5.5 * cd
		mp -= COST_SKILL
		_start("skill", "skill")
		AudioManager.play_sfx_named("cast")


func _start(state: String, anim: String) -> void:
	_state = state
	_marks.clear()
	_sprite.play(anim)
	_apply_flip()


func _on_anim_finished() -> void:
	if dead:
		if _sprite.animation == "death":
			defeated.emit()
			var tw := create_tween()
			tw.tween_interval(1.0)
			tw.tween_property(self, "modulate:a", 0.0, 1.4)
			tw.tween_callback(queue_free)
		return
	if _state in ["melee", "skill", "summon"]:
		_state = "idle"
		_sprite.play("idle2" if hp * 2 <= max_hp else "idle")


func _on_frame_changed() -> void:
	if dead or _sprite == null:
		return
	var f := _sprite.frame
	if _marks.has(f):
		return
	match _state:
		"melee":
			if f == 3 or f == 10:
				_marks[f] = true
				_melee_strike()
		"skill":
			if f == 7:
				_marks[f] = true
				_skill_strike()
		"summon":
			if f == 3:
				_marks[f] = true
				_spawn_minions()


func _melee_strike() -> void:
	if player == null or player.hp <= 0:
		return
	var dx := player.global_position.x - global_position.x
	var dy := player.global_position.y - 16.0 - global_position.y
	var in_front := signf(dx) == _dir or absf(dx) < 18.0
	if in_front and absf(dx) <= 66.0 and absf(dy) <= 48.0:
		player.call("enemy_hit", MELEE_DMG[_diff], signf(dx) if dx != 0.0 else _dir)


func _skill_strike() -> void:
	shake_requested.emit(2.0, 0.35)
	AudioManager.play_sfx_named("boom")
	if player == null or player.hp <= 0:
		return
	var dx := player.global_position.x - global_position.x
	var on_ground: bool = player.global_position.y >= _ground_y(player.global_position.x) - 26.0
	if absf(dx) <= 66.0 and on_ground:
		player.call("enemy_hit", SKILL_DMG[_diff], signf(dx) if dx != 0.0 else _dir)


func _spawn_minions() -> void:
	var n: int = MINIONS_BY_DIFF[_diff] + (1 if hp * 2 <= max_hp else 0)
	var parent := get_parent()
	if parent == null:
		return
	for i in n:
		if _minions.size() >= MAX_MINIONS:
			break
		var m := StaticBody2D.new()
		m.set_script(MinionScript)
		var side := -1.0 if i % 2 == 0 else 1.0
		var px := clampf(global_position.x + side * (46.0 + 34.0 * float(i / 2)), bounds_x.x, bounds_x.y)
		parent.add_child(m)
		m.call("setup", player, ground_fn, Vector2(px, global_position.y - 6.0), _diff)
		_minions.append(m)


func hit(dmg: int, dir: float) -> void:
	if dead or _state == "appear":
		return
	hp = maxi(0, hp - dmg)
	_flash = 0.12
	_knock = dir * 70.0
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	active = false
	_state = "dead"
	collision_layer = 0
	for m in _minions:
		if is_instance_valid(m):
			m.call("die")
	_minions.clear()
	_sprite.modulate = Color.WHITE
	_sprite.play("death")
	shake_requested.emit(3.0, 1.4)
	AudioManager.play_sfx_named("boom")


func clear_minions() -> void:
	for m in _minions:
		if is_instance_valid(m):
			m.queue_free()
	_minions.clear()
