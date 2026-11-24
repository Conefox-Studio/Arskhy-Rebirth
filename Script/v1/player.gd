extends CharacterBody2D

signal hp_changed(hp: int, max_hp: int)
signal mp_changed(mp: int, max_mp: int)
signal range_changed(value: int, max_value: int)
signal attacked(dir: float)
signal died
signal magic_changed(index: int)

const FxSprites = preload("res://scripts/fx_sprites.gd")
const MagicFx = preload("res://scripts/magic_fx.gd")
const SPEED := 84.0
const PUSH_SPEED := 40.0
const PUSH_GRACE := 0.12
const GRAVITY := 900.0
const STEP_MAX := 34.0
const FOOT_SINK := 0.0
const DayNightScript = preload("res://scripts/day_night.gd")
const FxLib = preload("res://scripts/fx.gd")
const FRAMES_DIR := "res://assets/characters/shyrn/"
const PUSH_SFX := "res://assets/audio/sfx/push_effect.mp3"
const WALK_FRAMES := 20
const WAVE_FRAMES := 25
const IDLE_FRAMES := 25
const PUSH_FRAMES := 25
const WALK_FPS := 16.0
const WAVE_FPS := 14.0
const IDLE_FPS := 8.0
const PUSH_FPS := 12.0
const HURT_FPS := 14.0
const HURT_ANIM_TIME := 0.36
const LAYER_GROUND := 1
const LAYER_PUSHABLE := 4

const ANIM_SCALE := {"wave": 0.23}
const ANIM_OFFSET_X := {"idle": -63.5, "walk": -77.5, "wave": -48.5, "push": -58.0, "jump": -72.0, "hurt": -56.0, "attack": -72.0, "dash": -72.0, "sprint": -72.0, "hurt_air": -80.0, "hurt_land": -73.0}
const TexUtil = preload("res://scripts/tex_util.gd")
const HandFrames = preload("res://scripts/hand_frames.gd")
const HIDE_HELD_ANIMS := ["attack", "push"]
const DEFAULT_SCALE := 0.26
const CLING_SLIDE := 28.0
const WALL_PUSH := 175.0
const SHOW_HELD_ITEM := true
const HAND_OFFSETS := {"idle": Vector2(6, -17), "walk": Vector2(6, -16), "sprint": Vector2(8, -16), "dash": Vector2(9, -16), "attack": Vector2(11, -18), "hurt": Vector2(-3, -14), "hurt_air": Vector2(-3, -15), "hurt_land": Vector2(-3, -12), "jump": Vector2(6, -20), "push": Vector2(8, -16), "wave": Vector2(7, -22), "cling": Vector2(5, -20), "use": Vector2(7, -19), "death": Vector2(2, -8)}
var _clinging := false
var _wall_n := 0.0
var _wall_lock := 0.0
var _wall_vx := 0.0
var _hand: Node2D
var _held: Sprite2D
var jump_boost := 1.0
var size_mult := 1.0

const JUMP_VELOCITY := -330.0
const JUMP_CUT := 0.45
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
const FIRST_JUMP_LOCK := 0.07
const DOUBLE_JUMP_LOCK := 0.14

const MAX_AIR_JUMPS := 1
const DOUBLE_JUMP_VELOCITY := -300.0
const SPRINT_MULT := 1.75
const DASH_ANIM_FPS := 30.0
const SPRINT_FRAME_MS := 110.0
const SPRINT_ANIM_FPS := 1000.0 / SPRINT_FRAME_MS
const HURT_AIR_FPS := 12.0
const HURT_LAND_FPS := 14.0
const AIR_STUN_MAX := 1.6
const AIR_KNOCK_SPEED := 120.0
const AIR_KNOCK_POP := -110.0
const LAND_LOCK_TIME := 0.5
const LAND_ANIM_TIME := 13.0 / 14.0

const ATTACK_TIME := 0.28
const ATTACK_COOLDOWN := 0.38
const ATTACK_DAMAGE := 5
const ATTACK_REACH := 26.0
const ATTACK_PUSH := 120.0
const ATTACK_MOVE_FACTOR := 0.5

const RANGE_ON_DAMAGE := 5
const RANGE_ON_HIT := 1

const RANGE_DURATION := 10.0
const RANGE_DAMAGE_MULT := 2
const RANGE_REGEN_GAP := 0.8
signal range_mode_changed(active: bool)
var range_active := false
var _range_drain := 0.0
var _range_regen := 0.0
var _range_aura := 0.0

const THORN_DAMAGE := 3
const BLEED_DAMAGE := 1
const BLEED_TICKS := 3
const THORN_KNOCK_DIST := 40.0
const THORN_KNOCK_TIME := 0.25
const THORN_IFRAMES := 0.7

var controls_enabled := true
var magic_blocked := false
var min_x := 12.0
var max_x := 1.0e9

var max_hp: int = GameState.DIFF_HP[GameState.difficulty]
var hp: int = GameState.DIFF_HP[GameState.difficulty]
var max_mp := 5
var mp := 5
var max_range := 10
var _base_max := {}
var _last_crit := false
var stun_cap := 0.0
var top_down := false
var td_bounds := Rect2()
var _td_face := Vector2.RIGHT
var _td_dash_dir := Vector2.RIGHT
var _col_shape: CollisionShape2D
var god_mode := false
var speed_mult := 1.0
var spam_jump := false
var lever_magic := false
var _cling_done := false
var _was_clinging := false
var range_pts := 0

var _coyote := 0.0
var _air_jumps := 0
var _air_stun := false
var _air_stun_t := 0.0
var _air_vx := 0.0
var _land_lock_t := 0.0
var _land_anim_t := 0.0
var _sprinting := false
var _jump_buffer := 0.0
var _jumping := false
var _attack_t := 0.0
var _attack_cd := 0.0
var _slash: Node2D
var _slash_t := 0.0
var _hit_ids := {}
var _anims := {}
var _hurt_anim_t := 0.0
var _hurt_cd := 0.0
var _knock_t := 0.0
var _knock_dir := 1.0
var _bleed_ticks := 0
var _poison := false
var _bleed_acc := 0.0

var _sprite: AnimatedSprite2D
var _waving := false
var _pushing := false
var _push_timer := 0.0
var _push_sfx: AudioStreamPlayer
var _shadow: Node2D
var _shadow_main: Sprite2D
var _shadow_soft: Sprite2D


func _ready() -> void:
	_build_hand_deferred()
	add_to_group("player")
	_ensure_actions()
	magic_index = clampi(GameState.magic_index, 0, MagicFx.SPELLS.size() - 1)
	MagicFx.current_name = String(MagicFx.SPELLS[magic_index].name)
	collision_layer = 2
	collision_mask = LAYER_GROUND | LAYER_PUSHABLE
	floor_snap_length = 34.0
	floor_max_angle = deg_to_rad(50.0)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 36) * size_mult
	shape.shape = rect
	shape.position = Vector2(0, -18) * size_mult
	add_child(shape)
	_col_shape = shape

	_build_shadow()
	_build_sprite()
	_build_sfx()
	GameSettings.graphics_changed.connect(_apply_shadow)
	_apply_shadow()
	_build_slash()
	_base_max = {"hp": max_hp, "mp": max_mp, "range": max_range}
	_apply_gem_stats(false)
	if not GameState.has_stats:
		hp = max_hp
	GameState.gem_changed.connect(refresh_gem_stats)
	if GameState.has_stats:
		hp = clampi(GameState.hp, 1, max_hp)
		mp = clampi(GameState.mp, 0, max_mp)
		range_pts = clampi(GameState.range_pts, 0, max_range)
	_sync_state()
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	range_changed.emit(range_pts, max_range)


func take_damage(amount: int) -> void:
	_lose_hp(amount, true)


func _lose_hp(amount: int, gain_range: bool) -> void:
	if god_mode or hp <= 0 or amount <= 0:
		return
	if _dash_t > 0.0:
		return
	if get_parent() != null:
		FxSprites.spawn_blood(get_parent(), global_position + Vector2(0, -10), -_facing(), "hurt")
	hp = clampi(hp - amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)
	if gain_range:
		restore_range(RANGE_ON_DAMAGE)
		if hp > 0:
			_start_hurt_anim()
	_sync_state()
	if hp == 0:
		_bleed_ticks = 0
		died.emit()


func _start_hurt_anim() -> void:
	if _sprite == null or not _anims.has("hurt"):
		return
	if not top_down and not is_on_floor() and _anims.has("hurt_air"):
		return
	_hurt_anim_t = HURT_ANIM_TIME if stun_cap <= 0.0 else minf(HURT_ANIM_TIME, stun_cap)
	_waving = false
	_play("hurt")


func _sync_state() -> void:
	GameState.has_stats = true
	GameState.hp = hp
	GameState.mp = mp
	GameState.range_pts = range_pts


func can_be_thorned() -> bool:
	return hp > 0 and _hurt_cd <= 0.0 and _knock_t <= 0.0


func thorn_hit(dir: float) -> void:
	if god_mode or not can_be_thorned():
		return
	_hurt_cd = THORN_IFRAMES
	take_damage(THORN_DAMAGE)
	if hp <= 0:
		return
	_bleed_ticks = BLEED_TICKS
	_poison = false
	_bleed_acc = 0.0
	_knock_dir = dir if dir != 0.0 else -_facing()
	_knock_t = THORN_KNOCK_TIME
	_attack_t = 0.0
	_waving = false
	_begin_air_stun()
	AudioManager.play_sfx_named("hurt")


func lever_damage(amount: int = 3) -> void:
	if lever_magic:
		lever_magic = false
		return
	if hp <= 0:
		return
	take_damage(amount)
	AudioManager.play_sfx_named("hurt")


func apply_poison(seconds: int = 5) -> void:
	if god_mode or hp <= 0:
		return
	_bleed_ticks = seconds
	_bleed_acc = 0.0
	_poison = true


func heal(amount: int) -> void:
	var _before := hp
	hp = clampi(hp + amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)
	_sync_state()


func use_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	mp_changed.emit(mp, max_mp)
	_sync_state()
	return true


func restore_mp(amount: int) -> void:
	mp = clampi(mp + amount, 0, max_mp)
	mp_changed.emit(mp, max_mp)
	_sync_state()


func use_range(amount: int) -> bool:
	if range_pts < amount:
		return false
	range_pts -= amount
	range_changed.emit(range_pts, max_range)
	_sync_state()
	return true


func restore_range(amount: int) -> void:
	if range_active:
		return
	range_pts = clampi(range_pts + amount, 0, max_range)
	range_changed.emit(range_pts, max_range)
	_sync_state()


func _apply_gem_stats(refill: bool) -> void:
	if _base_max.is_empty():
		return
	var old_hp := max_hp
	var old_mp := max_mp
	var old_rg := max_range
	max_hp = int(round(GameState.gem_scale("hp", float(_base_max.hp))))
	max_mp = int(round(GameState.gem_scale("mp", float(_base_max.mp))))
	max_range = int(round(GameState.gem_scale("range", float(_base_max.range))))
	if not refill:
		hp = clampi(hp + maxi(0, max_hp - old_hp), 0, max_hp) if hp > 0 else 0
		mp = clampi(mp + maxi(0, max_mp - old_mp), 0, max_mp)
		range_pts = clampi(range_pts + maxi(0, max_range - old_rg), 0, max_range)


func refresh_gem_stats() -> void:
	_apply_gem_stats(false)
	hp_changed.emit(hp, max_hp)
	mp_changed.emit(mp, max_mp)
	range_changed.emit(range_pts, max_range)
	_sync_state()


func add_max(kind: String, amount: int) -> void:
	match kind:
		"hp":
			_base_max.hp = mini(int(_base_max.hp) + amount, int(MaxCaps.hp))
			_apply_gem_stats(true)
			hp = max_hp
			hp_changed.emit(hp, max_hp)
		"mp":
			_base_max.mp = mini(int(_base_max.mp) + amount, int(MaxCaps.mp))
			_apply_gem_stats(true)
			mp = max_mp
			mp_changed.emit(mp, max_mp)
		"range":
			_base_max.range = mini(int(_base_max.range) + amount, int(MaxCaps.range))
			_apply_gem_stats(true)
			range_pts = max_range
			range_changed.emit(range_pts, max_range)
	_sync_state()


func revive() -> void:
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_attack_t = 0.0
	_jumping = false
	_bleed_ticks = 0
	_bleed_acc = 0.0
	_knock_t = 0.0
	_hurt_cd = 0.0
	_hurt_anim_t = 0.0
	range_active = false
	_air_stun = false
	_land_lock_t = 0.0
	_land_anim_t = 0.0
	_sprite.modulate = Color.WHITE
	_sync_state()


func _build_shadow() -> void:
	_shadow = Node2D.new()
	_shadow.z_index = 0
	add_child(_shadow)
	_shadow_soft = Sprite2D.new()
	_shadow_soft.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow_soft.material = FxLib.shadow_material(0.0, 150.0, 0.1)
	_shadow_soft.modulate = Color(0, 0, 0, 0.14)
	_shadow.add_child(_shadow_soft)
	_shadow_main = Sprite2D.new()
	_shadow_main.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow_main.material = FxLib.shadow_material(0.0, 150.0, 0.15)
	_shadow_main.modulate = Color(0, 0, 0, 0.3)
	_shadow.add_child(_shadow_main)


func _apply_shadow() -> void:
	var mode := GameSettings.shadow_index
	_shadow.visible = mode > 0
	_shadow_soft.visible = mode >= 2
	var bl := FxLib.shadow_blur(mode)
	for sp in [_shadow_main, _shadow_soft]:
		(sp.material as ShaderMaterial).set_shader_parameter("blur_near", bl.x)
		(sp.material as ShaderMaterial).set_shader_parameter("blur_far", bl.y * (1.3 if sp == _shadow_soft else 1.0))
	if mode > 0:
		var p := FxLib.shadow_params(mode)
		_shadow_main.modulate = Color(0, 0, 0, p.alpha)
		_shadow_soft.modulate = Color(0, 0, 0, p.soft_alpha)
	_sync_shadow()


func _clip_shadow_to_ground() -> void:
	if _shadow_main == null:
		return
	var space := get_world_2d().direct_space_state
	var cmin := -1000000.0
	var cmax := 1000000.0
	for side in [-1.0, 1.0]:
		var x := 0.0
		while x <= 56.0:
			x += 4.0
			var d := FxLib.ground_drop(space, global_position + Vector2(side * x, -12.0), LAYER_GROUND | LAYER_PUSHABLE, [get_rid()], 90.0)
			if d < 0.0:
				if side < 0.0:
					cmin = global_position.x - x + 2.0
				else:
					cmax = global_position.x + x - 2.0
				break
	for sp in [_shadow_main, _shadow_soft]:
		var m := sp.material as ShaderMaterial
		if m != null:
			m.set_shader_parameter("clip_min", cmin)
			m.set_shader_parameter("clip_max", cmax)


func _update_shadow_ground() -> void:
	if _shadow == null or not _shadow.visible:
		return
	_clip_shadow_to_ground()
	var d := FxLib.ground_drop(get_world_2d().direct_space_state, global_position + Vector2(0.0, -4.0),
			LAYER_GROUND | LAYER_PUSHABLE, [get_rid()])
	if d < 0.0:
		_shadow.modulate.a = 0.0
		return
	var h := maxf(d - 4.0, 0.0)
	var f := FxLib.shadow_height_fade(h)
	_shadow.position = Vector2(0.0, h)
	_shadow.scale = Vector2(f.x, 1.0)
	_shadow.modulate.a = f.y


func _sync_shadow() -> void:
	if _sprite == null or GameSettings.shadow_index <= 0:
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var p := FxLib.shadow_params(GameSettings.shadow_index)
	var s := _sprite.scale.x
	var lean: float = float(p.lean) * DayNightScript.shadow_lean_factor()
	var items := [[_shadow_main, 1.0], [_shadow_soft, float(p.soft_grow)]]
	for it in items:
		var sp: Sprite2D = it[0]
		var g: float = it[1]
		sp.texture = tex
		sp.flip_h = _sprite.flip_h
		sp.offset = _sprite.offset
		sp.transform = Transform2D(Vector2(s, 0.0), Vector2(lean * g * s, -p.squash * DayNightScript.shadow_length_factor() * g * s), Vector2.ZERO)
		sp.modulate.a = (p.alpha if sp == _shadow_main else p.soft_alpha) * DayNightScript.shadow_alpha_factor()


func _begin_air_stun() -> void:
	if top_down or is_on_floor() or not _anims.has("hurt_air"):
		return
	_air_stun = true
	_air_stun_t = AIR_STUN_MAX if stun_cap <= 0.0 else minf(AIR_STUN_MAX, stun_cap * 0.5)
	_air_vx = _knock_dir * AIR_KNOCK_SPEED
	velocity.y = AIR_KNOCK_POP
	_jumping = false
	_dash_t = 0.0
	_hurt_anim_t = 0.0
	_land_anim_t = 0.0
	_play("hurt_air")


func _stunned() -> bool:
	return _air_stun or _land_lock_t > 0.0


var _stun_fx: Node2D


func _update_stun_fx() -> void:
	var on := _stunned()
	if on and _stun_fx == null:
		_stun_fx = Node2D.new()
		_stun_fx.z_index = 8
		_stun_fx.position = Vector2(0, -50)
		_stun_fx.draw.connect(func():
			var t := Time.get_ticks_msec() / 1000.0
			for i in 3:
				var a := t * 7.0 + i * TAU / 3.0
				var p := Vector2(cos(a) * 11.0, sin(a) * 3.5)
				var c := Color(1.0, 0.92, 0.35, 0.55 + 0.45 * (0.5 + 0.5 * sin(a)))
				var s := 2.6 if sin(a) > 0.0 else 1.8
				_stun_fx.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.45, -s * 0.3), p + Vector2(s, 0), p + Vector2(s * 0.45, s * 0.3), p + Vector2(0, s), p + Vector2(-s * 0.45, s * 0.3), p + Vector2(-s, 0), p + Vector2(-s * 0.45, -s * 0.3)]), c))
		add_child(_stun_fx)
	elif not on and _stun_fx != null:
		_stun_fx.queue_free()
		_stun_fx = null
	if _stun_fx != null:
		_stun_fx.queue_redraw()


func _update_air_stun(delta: float, dir: float) -> void:
	if _land_lock_t > 0.0:
		_land_lock_t -= delta
	if _land_anim_t > 0.0:
		_land_anim_t -= delta
		if _land_lock_t <= 0.0 and dir != 0.0:
			_land_anim_t = 0.0
	elif _sprite != null and _sprite.speed_scale != 1.0:
		_sprite.speed_scale = 1.0
	if not _air_stun:
		return
	_air_stun_t -= delta
	var near_ground: bool = velocity.y > 0.0 and test_move(global_transform, Vector2(0.0, 10.0))
	if is_on_floor() or near_ground or _air_stun_t <= 0.0:
		_air_stun = false
		if _anims.has("hurt_land") and hp > 0:
			_land_lock_t = LAND_LOCK_TIME if stun_cap <= 0.0 else minf(LAND_LOCK_TIME, stun_cap * 0.3)
			_land_anim_t = LAND_ANIM_TIME if stun_cap <= 0.0 else minf(LAND_ANIM_TIME, stun_cap * 0.5)
			_play("hurt_land")
			if stun_cap > 0.0:
				_sprite.speed_scale = maxf(1.0, LAND_ANIM_TIME / maxf(_land_anim_t, 0.05))


func _add_anim(frames: SpriteFrames, anim: String, folder: String, count: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for i in range(1, count + 1):
		frames.add_frame(anim, TexUtil.load_tex(FRAMES_DIR + "%s/%s_%02d.png" % [folder, folder, i]))


func _add_optional_anim(frames: SpriteFrames, anim: String, fps: float, loop: bool) -> void:
	var first := FRAMES_DIR + "%s/%s_01.png" % [anim, anim]
	if not TexUtil.exists(first):
		return
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var i := 1
	while TexUtil.exists(FRAMES_DIR + "%s/%s_%02d.png" % [anim, anim, i]):
		frames.add_frame(anim, TexUtil.load_tex(FRAMES_DIR + "%s/%s_%02d.png" % [anim, anim, i]))
		i += 1
	_anims[anim] = true


func _build_sprite() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, "walk", "walk", WALK_FRAMES, WALK_FPS, true)
	_add_anim(frames, "wave", "wave", WAVE_FRAMES, WAVE_FPS, false)
	_add_anim(frames, "idle", "idle", IDLE_FRAMES, IDLE_FPS, true)
	_add_anim(frames, "push", "push", PUSH_FRAMES, PUSH_FPS, true)
	_add_optional_anim(frames, "jump", 12.0, false)
	_add_optional_anim(frames, "attack", 18.0, false)
	_add_optional_anim(frames, "hurt", HURT_FPS, false)
	_add_optional_anim(frames, "dash", DASH_ANIM_FPS, true)
	if _anims.has("dash"):
		frames.add_animation("sprint")
		frames.set_animation_speed("sprint", SPRINT_ANIM_FPS)
		frames.set_animation_loop("sprint", true)
		for i in frames.get_frame_count("dash"):
			frames.add_frame("sprint", frames.get_frame_texture("dash", i))
		_anims["sprint"] = true
	_add_optional_anim(frames, "hurt_air", HURT_AIR_FPS, true)
	_add_optional_anim(frames, "hurt_land", HURT_LAND_FPS, false)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.frame_changed.connect(_sync_shadow)
	_sprite.animation_changed.connect(_sync_shadow)
	add_child(_sprite)
	_play("idle")


func _build_hand_deferred() -> void:
	call_deferred("_build_hand")


func _build_hand() -> void:
	_hand = Node2D.new()
	_hand.name = "HandAnchor"
	_hand.z_index = 2
	add_child(_hand)
	_held = Sprite2D.new()
	_held.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_held.scale = Vector2(0.5, 0.5)
	_held.position = Vector2(0.0, -1.5)
	_hand.add_child(_held)
	Inventory.selected_changed.connect(_refresh_held)
	Inventory.changed.connect(_refresh_held)
	_refresh_held()


func _refresh_held() -> void:
	if _held == null:
		return
	var it = Inventory.hotbar[Inventory.selected] if Inventory.hotbar.size() > Inventory.selected else null
	_held.texture = it.get("icon") if it is Dictionary else null


func _process(_delta: float) -> void:
	if _hand == null or _sprite == null:
		return
	var anim := String(_sprite.animation)
	_hand.visible = SHOW_HELD_ITEM and _held != null and _held.texture != null and hp > 0 and not (anim in HIDE_HELD_ANIMS) and not _attack_visual_active()
	var o: Vector2 = HAND_OFFSETS.get(anim, Vector2(6, -17)) * size_mult
	var key := "dash" if anim == "sprint" else anim
	var tbl = HandFrames.DATA.get(key)
	if tbl != null and _sprite.sprite_frames != null:
		var fr := clampi(_sprite.frame, 0, tbl.size() - 1)
		var tex := _sprite.sprite_frames.get_frame_texture(anim, fr)
		if tex != null:
			var pt: Vector2 = tbl[fr]
			var s: float = ANIM_SCALE.get(anim, DEFAULT_SCALE) * size_mult
			var ox: float = ANIM_OFFSET_X.get(anim, 0.0)
			o = Vector2((pt.x - tex.get_width() / 2.0 + ox) * s, (pt.y - tex.get_height()) * s + FOOT_SINK)
			if _sprite.flip_h:
				o.x = -o.x
	elif _sprite.flip_h:
		o.x = -o.x
	_hand.position = o
	_held.flip_h = _sprite.flip_h


func _attack_visual_active() -> bool:
	return _attack_t > 0.0


func _play(anim: String) -> void:
	var s: float = ANIM_SCALE.get(anim, DEFAULT_SCALE) * size_mult
	_sprite.scale = Vector2(s, s)
	var h: float = _sprite.sprite_frames.get_frame_texture(anim, 0).get_height()
	_sprite.offset = Vector2(0, -h / 2.0 + FOOT_SINK / s)
	_sprite.play(anim)
	_apply_flip_offset()
	_sync_shadow()


func _apply_flip_offset() -> void:
	if _sprite == null:
		return
	var ox: float = ANIM_OFFSET_X.get(_sprite.animation, 0.0)
	if _sprite.flip_h:
		ox = -ox
	if not is_equal_approx(_sprite.offset.x, ox):
		_sprite.offset.x = ox
		_sync_shadow()


func _build_sfx() -> void:
	_push_sfx = AudioStreamPlayer.new()
	_push_sfx.bus = "SFX"
	var stream := load(PUSH_SFX) as AudioStream
	if stream is AudioStreamMP3:
		stream.loop = true
	_push_sfx.stream = stream
	add_child(_push_sfx)


static func ensure_actions() -> void:
	_ensure_actions()


static func _ensure_actions() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("move_down", [KEY_S, KEY_DOWN])
	_add_action("attack", [KEY_J, KEY_Z])
	_add_action("dash", [KEY_K, KEY_X])
	_add_action("td_up", [KEY_W, KEY_UP])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("range_mode", [KEY_Q])
	_add_action("magic_cast", [KEY_E])
	_add_action("magic_prev", [KEY_0, KEY_KP_0])
	_add_action("magic_next", [KEY_MINUS, KEY_KP_SUBTRACT])
	_add_action("run_hold", [])
	_add_pad()
	GameSettings.apply_bindings()


static func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		for k in keys:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


static func _add_pad() -> void:
	_pad_btn("sprint", JOY_BUTTON_LEFT_STICK)
	_pad_btn("move_left", JOY_BUTTON_DPAD_LEFT)
	_pad_btn("move_right", JOY_BUTTON_DPAD_RIGHT)
	_pad_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_pad_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_pad_btn("jump", JOY_BUTTON_A)
	_pad_btn("attack", JOY_BUTTON_X)
	_pad_btn("range_mode", JOY_BUTTON_B)
	_pad_btn("magic_cast", JOY_BUTTON_RIGHT_STICK)
	_pad_btn("magic_prev", JOY_BUTTON_DPAD_UP)
	_pad_btn("magic_next", JOY_BUTTON_DPAD_DOWN)
	_pad_axis("dash", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_pad_axis("use_quick", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_pad_btn("hotbar_1", JOY_BUTTON_LEFT_SHOULDER)
	_pad_btn("hotbar_2", JOY_BUTTON_RIGHT_SHOULDER)
	_pad_btn("inventory", JOY_BUTTON_BACK)
	_pad_btn("ui_cancel", JOY_BUTTON_START)


static func _pad_btn(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventJoypadButton.new()
	ev.button_index = button as JoyButton
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return
	InputMap.action_add_event(action, ev)


static func _pad_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and e.axis == axis and signf(e.axis_value) == signf(value):
			return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis as JoyAxis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


var _shadow_tick := 0.0


func _physics_process(delta: float) -> void:
	if top_down:
		_td_physics(delta)
		return
	_shadow_tick -= delta
	if _shadow_tick <= 0.0:
		_shadow_tick = 0.25
		_sync_shadow()
	var dir := 0.0
	_update_hurt_timers(delta)
	_update_range_mode(delta)
	_update_stun_fx()
	if controls_enabled and _knock_t <= 0.0 and not _stunned():
		dir = Input.get_axis("move_left", "move_right")
		if dir != 0.0:
			_sprite.flip_h = dir < 0.0
			if _waving:
				_waving = false

	var on_floor := is_on_floor()
	_coyote = COYOTE_TIME if on_floor else _coyote - delta
	if on_floor:
		_air_jumps = MAX_AIR_JUMPS
		_cling_done = false
	var can_act: bool = controls_enabled and not _stunned()
	_was_clinging = _clinging
	_clinging = false
	if can_act and not _cling_done and not on_floor and _dash_t <= 0.0 and _knock_t <= 0.0 and _attack_t <= 0.0 and is_on_wall() and velocity.y > -60.0:
		var wn := get_wall_normal().x
		if dir != 0.0 and signf(dir) == -signf(wn):
			_clinging = true
			_wall_n = wn
			_air_jumps = MAX_AIR_JUMPS
			_sprite.flip_h = wn > 0.0
	if _was_clinging and not _clinging:
		_cling_done = true
	_cut_lock = maxf(0.0, _cut_lock - delta)
	if can_act and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer -= delta
	if can_act and _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY * jump_boost
		_jump_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		_cut_lock = FIRST_JUMP_LOCK
		_waving = false
		FxSprites.spawn_dust(get_parent(), "run", global_position, _facing(), 0.55)
		AudioManager.play_sfx_named("jump")
	elif can_act and _jump_buffer > 0.0 and _clinging:
		velocity.y = JUMP_VELOCITY * jump_boost
		_wall_vx = _wall_n * WALL_PUSH
		_wall_lock = 0.16
		_jump_buffer = 0.0
		_jumping = true
		_cut_lock = FIRST_JUMP_LOCK
		_clinging = false
		_cling_done = true
		_waving = false
		AudioManager.play_sfx_named("jump")
	elif can_act and _jump_buffer > 0.0 and not on_floor and (_air_jumps > 0 or spam_jump):
		_air_jumps = maxi(0, _air_jumps - 1)
		velocity.y = DOUBLE_JUMP_VELOCITY * jump_boost
		_jump_buffer = 0.0
		_jumping = true
		_cut_lock = DOUBLE_JUMP_LOCK
		_dash_t = 0.0
		_waving = false
		_spawn_jump_ring()
		AudioManager.play_sfx_named("jump")
	elif on_floor and not _jumping:
		velocity.y = 0.0
	else:
		velocity.y += GRAVITY * delta
	if _clinging:
		velocity.y = minf(velocity.y, CLING_SLIDE)
	if _jumping:
		if controls_enabled and _cut_lock <= 0.0 and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			velocity.y *= JUMP_CUT
			_jumping = false
		elif velocity.y >= 0.0:
			_jumping = false

	_attack_cd -= delta
	if can_act and Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_start_attack()
	if _attack_t > 0.0:
		_attack_t -= delta
		_update_attack_hits()

	_update_magic(delta, can_act)

	_dash_cd -= delta
	if on_floor:
		_air_dash_ready = true
	if can_act and _dash_pressed() and _dash_cd <= 0.0 and _knock_t <= 0.0 and (on_floor or _air_dash_ready):
		_start_dash(dir, on_floor)
	_dust_t -= delta
	if _dash_t > 0.0:
		_dash_t -= delta
		if not on_floor:
			velocity.y = 0.0
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = AFTERIMAGE_GAP
			_spawn_afterimage()
		if _dust_t <= 0.0:
			_dust_t = 0.06
			FxSprites.spawn_dust(get_parent(), "dash", global_position, _dash_dir, 0.5)

	var pushing_now := _pushing and _push_timer > 0.0
	_sprinting = can_act and dir != 0.0 and not pushing_now and _attack_t <= 0.0 and (Input.is_action_pressed("sprint") or Input.is_action_pressed("run_hold"))
	var spd := PUSH_SPEED if pushing_now else SPEED
	if _sprinting:
		spd *= SPRINT_MULT
	spd *= speed_mult
	if _attack_t > 0.0:
		spd *= ATTACK_MOVE_FACTOR
	velocity.x = dir * spd
	if _dash_t > 0.0:
		velocity.x = _dash_dir * DASH_SPEED
	if _air_stun:
		_air_vx = move_toward(_air_vx, 0.0, 220.0 * delta)
		velocity.x = _air_vx
		_knock_t = 0.0
	elif _knock_t > 0.0:
		_dash_t = 0.0
		_knock_t -= delta
		velocity.x = _knock_dir * (THORN_KNOCK_DIST / THORN_KNOCK_TIME)

	if _wall_lock > 0.0:
		_wall_lock -= delta
		velocity.x = _wall_vx
	var was_on_floor := on_floor
	var y_before := global_position.y
	if not _jumping:
		_try_step_up(delta)
	var vy_before := velocity.y
	move_and_slide()
	if not was_on_floor and is_on_floor() and vy_before > 140.0:
		FxSprites.spawn_dust(get_parent(), "land", global_position, 1.0, 0.85)
	position.x = clampf(position.x, min_x, max_x)
	_update_push(dir, delta)
	_update_slash(delta)
	_update_shadow_ground()

	if was_on_floor and is_on_floor():
		var dy := global_position.y - y_before
		if absf(dy) > 8.0:
			_sprite.position.y -= dy
	_sprite.position.y *= exp(-delta * 14.0)

	_update_air_stun(delta, dir)
	_pick_animation(dir)
	_apply_flip_offset()


func _update_hurt_timers(delta: float) -> void:
	if _hurt_anim_t > 0.0:
		_hurt_anim_t -= delta
	if _hurt_cd > 0.0:
		_hurt_cd -= delta
	if _bleed_ticks > 0 and hp > 0:
		_bleed_acc += delta
		if _bleed_acc >= 1.0:
			_bleed_acc -= 1.0
			_bleed_ticks -= 1
			_lose_hp(BLEED_DAMAGE, false)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
		if _poison:
			_sprite.modulate = Color(0.55 + 0.2 * pulse, 1.0, 0.55 + 0.2 * pulse)
		else:
			_sprite.modulate = Color(1.0, 0.55 + 0.2 * pulse, 0.55 + 0.2 * pulse)
	elif _sprite.modulate != Color.WHITE and _range_aura <= 0.0:
		_poison = false
		_sprite.modulate = Color.WHITE


func _pick_animation(dir: float) -> void:
	var airborne := not is_on_floor()
	if _land_anim_t > 0.0 and _anims.has("hurt_land"):
		if _sprite.animation != "hurt_land":
			_play("hurt_land")
	elif _air_stun and _anims.has("hurt_air"):
		if _sprite.animation != "hurt_air":
			_play("hurt_air")
	elif _hurt_anim_t > 0.0 and _anims.has("hurt"):
		if _sprite.animation != "hurt":
			_play("hurt")
	elif _attack_t > 0.0 and _anims.has("attack"):
		if _sprite.animation != "attack":
			_play("attack")
	elif _dash_t > 0.0 and _anims.has("dash"):
		_pose_dash()
	elif _clinging and _anims.has("cling"):
		if _sprite.animation != "cling":
			_play("cling")
	elif airborne:
		var want := "jump" if _anims.has("jump") else "idle"
		if _sprite.animation != want:
			_play(want)
		if want == "jump":
			_pose_jump()
	elif _pushing and _push_timer > 0.0 and dir != 0.0:
		if _sprite.animation != "push":
			_play("push")
	elif _sprinting and _anims.has("sprint"):
		if _sprite.animation != "sprint":
			_play("sprint")
		elif not _sprite.is_playing():
			_sprite.play("sprint")
	elif dir != 0.0:
		if _sprite.animation != "walk":
			_play("walk")
	elif not _waving and _sprite.animation != "idle":
		_play("idle")
	if not _anims.has("jump"):
		var stretch := 1.0
		if airborne:
			stretch = 1.0 + clampf(absf(velocity.y) / 1400.0, 0.0, 0.12)
		_sprite.scale.y = lerpf(_sprite.scale.y, ANIM_SCALE.get(_sprite.animation, DEFAULT_SCALE) * size_mult * stretch, 0.3)


func _pose_jump() -> void:
	var n := _sprite.sprite_frames.get_frame_count("jump")
	if n <= 1:
		return
	_sprite.pause()
	var t := clampf((velocity.y - JUMP_VELOCITY) / (-2.0 * JUMP_VELOCITY), 0.0, 1.0)
	_sprite.frame = clampi(int(t * n), 0, n - 1)


func _facing() -> float:
	return -1.0 if _sprite.flip_h else 1.0


func _start_attack() -> void:
	_attack_t = ATTACK_TIME
	_attack_cd = ATTACK_COOLDOWN
	_waving = false
	_hit_ids.clear()
	if _anims.has("attack"):
		_play("attack")
	AudioManager.play_sfx_named("swing")
	attacked.emit(_facing())


func enemy_hit(amount: int, dir: float) -> void:
	if god_mode or not can_be_thorned() or _dash_t > 0.0:
		return
	_hurt_cd = THORN_IFRAMES + 0.3
	FxSprites.spawn_slash(get_parent(), "hurt", global_position + Vector2(0.0, -18.0 * size_mult), -dir if dir != 0.0 else _facing(), size_mult)
	take_damage(amount)
	if hp <= 0:
		return
	_knock_dir = dir if dir != 0.0 else -_facing()
	_knock_t = THORN_KNOCK_TIME
	_attack_t = 0.0
	_waving = false
	_begin_air_stun()
	AudioManager.play_sfx_named("hurt")


func _update_attack_hits() -> void:
	if _attack_t > ATTACK_TIME * 0.8 or _attack_t < ATTACK_TIME * 0.2:
		return
	var dir := _facing()
	var rect := Rect2(global_position + Vector2(dir * 8.0 - (0.0 if dir > 0.0 else ATTACK_REACH), -34.0), Vector2(ATTACK_REACH, 34.0))
	if top_down:
		var c := td_center() + _td_face * (ATTACK_REACH * 0.55)
		rect = Rect2(c - Vector2(ATTACK_REACH, ATTACK_REACH) * 0.6, Vector2(ATTACK_REACH, ATTACK_REACH) * 1.2)
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	q.shape = shape
	q.transform = Transform2D(0.0, rect.get_center())
	q.collision_mask = LAYER_PUSHABLE | 8
	q.exclude = [get_rid()]
	for r in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var body := r.collider as Node
		if body == null or _hit_ids.has(body.get_instance_id()):
			continue
		_hit_ids[body.get_instance_id()] = true
		var is_enemy := false
		if body.has_method("hit"):
			body.call("hit", attack_damage(), dir)
			is_enemy = not body.is_in_group("pushable") and not body.is_in_group("ambient")
		elif body.has_method("take_damage"):
			body.call("take_damage", attack_damage())
			is_enemy = not body.is_in_group("pushable") and not body.is_in_group("ambient")
		if not body.is_in_group("pushable") and body is Node2D:
			FxSprites.spawn_blood(get_parent(), (body as Node2D).global_position, dir, "hit" if is_enemy else "small")
		if is_enemy:
			AudioManager.play_sfx_named("hit_body")
			FxSprites.spawn_slash(get_parent(), "hit", _body_center(body), dir)
			restore_range(RANGE_ON_HIT)
		if body.is_in_group("pushable") and body.has_method("push"):
			body.call("push", dir, ATTACK_PUSH)


func _body_center(body: Node) -> Vector2:
	for c in body.get_children():
		if c is CollisionShape2D:
			return (c as CollisionShape2D).global_position
	return (body as Node2D).global_position if body is Node2D else global_position


func attack_damage() -> int:
	var dmg: float = GameState.gem_scale("attack", float(ATTACK_DAMAGE)) * (RANGE_DAMAGE_MULT if range_active else 1)
	_last_crit = randf() < GameState.gem_crit()
	if _last_crit:
		dmg *= 2.0
	return int(round(dmg))


func _update_range_mode(delta: float) -> void:
	if not range_active:
		if controls_enabled and hp > 0 and InputMap.has_action("range_mode") and Input.is_action_just_pressed("range_mode") \
				and range_pts >= max_range and max_range > 0:
			range_active = true
			_range_drain = 0.0
			_range_regen = 0.0
			range_mode_changed.emit(true)
			Achievements.unlock("rage")
			AudioManager.play_sfx_named("cast")
		_range_aura = move_toward(_range_aura, 0.0, delta * 3.0)
	else:
		_range_aura = move_toward(_range_aura, 1.0, delta * 4.0)
		_range_drain += delta * float(max_range) / RANGE_DURATION
		while _range_drain >= 1.0 and range_pts > 0:
			_range_drain -= 1.0
			range_pts -= 1
			range_changed.emit(range_pts, max_range)
			_sync_state()
		_range_regen += delta
		if _range_regen >= RANGE_REGEN_GAP:
			_range_regen = 0.0
			if hp > 0 and hp < max_hp:
				heal(1)
		if range_pts <= 0 or hp <= 0:
			range_active = false
			range_mode_changed.emit(false)
	if _sprite != null and _bleed_ticks <= 0 and _range_aura > 0.0:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 110.0)
		_sprite.modulate = Color(1.0, 0.72 + 0.1 * pulse, 0.55 + 0.1 * pulse).lerp(Color.WHITE, 1.0 - _range_aura)


func _build_slash() -> void:
	_slash = Node2D.new()
	_slash.z_index = 5
	_slash.visible = false
	_slash.draw.connect(_draw_slash)
	add_child(_slash)


func _draw_slash() -> void:
	var life := clampf(_slash_t / ATTACK_TIME, 0.0, 1.0)
	var prog := 1.0 - life
	var a0 := deg_to_rad(-80.0 + 40.0 * prog)
	var a1 := deg_to_rad(-80.0 + 40.0 * prog + 95.0 * minf(1.0, prog * 2.5 + 0.2))
	var c := Vector2(2.0, -19.0)
	var alpha := clampf(life * 1.6, 0.0, 1.0)
	_slash.draw_arc(c, ATTACK_REACH - 2.0, a0, a1, 18, Color(1.0, 0.95, 0.75, 0.9 * alpha), 4.0)
	_slash.draw_arc(c, ATTACK_REACH - 7.0, a0 + 0.08, a1 - 0.05, 18, Color(1.0, 1.0, 1.0, 0.7 * alpha), 2.0)


func _update_slash(delta: float) -> void:
	if _slash_t > 0.0:
		_slash_t -= delta
		_slash.queue_redraw()
		if _slash_t <= 0.0:
			_slash.visible = false


func _update_push(dir: float, delta: float) -> void:
	var hit := false
	if dir != 0.0:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			var body := c.get_collider() as Node
			if body != null and body.is_in_group("pushable") and absf(c.get_normal().x) > 0.5 \
					and signf(c.get_normal().x) == -signf(dir):
				hit = true
				if body.has_method("push"):
					body.call("push", dir, PUSH_SPEED)
	if hit:
		_pushing = true
		_push_timer = PUSH_GRACE
	else:
		_push_timer -= delta
		if _push_timer <= 0.0:
			_pushing = false
	var want_sound := _pushing and _push_timer > 0.0 and dir != 0.0
	if want_sound and not _push_sfx.playing:
		_push_sfx.play()
	elif not want_sound and _push_sfx.playing:
		_push_sfx.stop()


func _try_step_up(delta: float) -> void:
	if not is_on_floor() or velocity.x == 0.0:
		return
	var motion := Vector2(velocity.x * delta, 0.0)
	var res := KinematicCollision2D.new()
	if not test_move(global_transform, motion, res):
		return
	var blocker := res.get_collider() as Node
	if blocker != null and blocker.is_in_group("pushable"):
		return
	var h := 2.0
	while h <= STEP_MAX:
		var raised := global_transform.translated(Vector2(0, -h))
		if not test_move(raised, motion):
			global_position.y -= h
			return
		h += 2.0


func set_flip(f: bool) -> void:
	_sprite.flip_h = f


func is_flipped() -> bool:
	return _sprite.flip_h


func _on_anim_finished() -> void:
	if _sprite.animation == "wave":
		_waving = false
		_play("idle")


func _dash_pressed() -> bool:
	return Input.is_action_just_pressed("dash") or Input.is_action_just_pressed("sprint")


func _start_dash(dir: float, on_floor: bool) -> void:
	AudioManager.play_sfx_named("dash")
	_dash_t = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_dash_dir = dir if dir != 0.0 else _facing()
	_sprite.flip_h = _dash_dir < 0.0
	_waving = false
	_jumping = false
	_afterimage_t = 0.0
	if not on_floor:
		_air_dash_ready = false
		velocity.y = 0.0
	if _anims.has("dash"):
		_pose_dash()
	FxSprites.spawn_dust(get_parent(), "dash", global_position, _dash_dir, 0.7)
	AudioManager.play_sfx_named("swing")


func _pose_dash() -> void:
	if _sprite.animation != "dash":
		_play("dash")
	_sprite.pause()
	var n := _sprite.sprite_frames.get_frame_count("dash")
	var prog := clampf(1.0 - _dash_t / DASH_TIME, 0.0, 0.999)
	_sprite.frame = int(prog * float(n))


func _spawn_afterimage() -> void:
	var parent := get_parent()
	if parent == null or _sprite == null:
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	g.flip_h = _sprite.flip_h
	g.offset = _sprite.offset
	g.scale = _sprite.scale
	g.modulate = Color(0.75, 0.9, 1.0, 0.45)
	parent.add_child(g)
	parent.move_child(g, get_index())
	g.global_position = _sprite.global_position
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


func _spawn_jump_ring() -> void:
	var parent := get_parent()
	if parent == null:
		return
	FxSprites.spawn_air_burst(parent, global_position + Vector2(0.0, -4.0))
	if true:
		return
	var ring := Node2D.new()
	ring.z_index = 3
	ring.scale = Vector2(1.0, 0.35)
	parent.add_child(ring)
	ring.global_position = global_position + Vector2(0.0, -2.0)
	var state := {"t": 0.0}
	ring.draw.connect(_draw_jump_ring.bind(ring, state))
	var tw := ring.create_tween()
	tw.tween_method(_set_jump_ring.bind(ring, state), 0.0, 1.0, 0.32)
	tw.tween_callback(ring.queue_free)


func _set_jump_ring(v: float, ring: Node2D, state: Dictionary) -> void:
	state["t"] = v
	if is_instance_valid(ring):
		ring.queue_redraw()


func _draw_jump_ring(ring: Node2D, state: Dictionary) -> void:
	var t: float = state["t"]
	var r := 6.0 + 24.0 * t
	ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.85 * (1.0 - t)), 3.0)
	ring.draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 24, Color(0.8, 0.95, 1.0, 0.6 * (1.0 - t)), 2.0)


var magic_index := 0
var _magic_cd := 0.0
var _mp_regen_t := 0.0
const MAGIC_COOLDOWN := 0.45
const MP_REGEN_GAP := 8.0
const MaxCaps := {"hp": 40, "mp": 15, "range": 20}
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := 1.0
var _dust_t := 0.0
const DASH_SPEED := 600.0
const DASH_TIME := 0.10
const DASH_COOLDOWN := 0.5
const AFTERIMAGE_GAP := 0.025
var _air_dash_ready := true
var _afterimage_t := 0.0
var _cut_lock := 0.0


func _update_magic(delta: float, can_act: bool) -> void:
	_magic_cd = maxf(0.0, _magic_cd - delta)
	if mp < max_mp and hp > 0:
		_mp_regen_t += delta
		if _mp_regen_t >= MP_REGEN_GAP:
			_mp_regen_t = 0.0
			restore_mp(1)
	if not controls_enabled:
		return
	if InputMap.has_action("magic_prev") and Input.is_action_just_pressed("magic_prev"):
		switch_magic(-1)
	if InputMap.has_action("magic_next") and Input.is_action_just_pressed("magic_next"):
		switch_magic(1)
	if can_act and not magic_blocked and _magic_cd <= 0.0 and InputMap.has_action("magic_cast") and Input.is_action_just_pressed("magic_cast"):
		if MagicFx.cast(self, magic_index):
			_magic_cd = MAGIC_COOLDOWN
			_waving = false
		else:
			AudioManager.play_ui("error")


func switch_magic(d: int) -> void:
	var n: int = MagicFx.SPELLS.size()
	magic_index = (magic_index + d + n) % n
	MagicFx.current_name = String(MagicFx.SPELLS[magic_index].name)
	GameState.magic_index = magic_index
	AudioManager.play_ui("move")
	magic_changed.emit(magic_index)


func grant_invuln(t: float) -> void:
	_hurt_cd = maxf(_hurt_cd, t)


func set_top_down(on: bool) -> void:
	top_down = on
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if on else CharacterBody2D.MOTION_MODE_GROUNDED
	if _col_shape != null and _col_shape.shape is RectangleShape2D:
		if on:
			(_col_shape.shape as RectangleShape2D).size = Vector2(12, 8) * size_mult
			_col_shape.position = Vector2(0, -4) * size_mult
		else:
			(_col_shape.shape as RectangleShape2D).size = Vector2(12, 36) * size_mult
			_col_shape.position = Vector2(0, -18) * size_mult
	velocity = Vector2.ZERO


func td_center() -> Vector2:
	return global_position + Vector2(0.0, -16.0 * size_mult)


func _td_physics(delta: float) -> void:
	_update_hurt_timers(delta)
	_update_range_mode(delta)
	_update_stun_fx()
	var can_act: bool = controls_enabled and not _stunned()
	var v := Vector2.ZERO
	if controls_enabled and _knock_t <= 0.0 and not _stunned():
		v = Input.get_vector("move_left", "move_right", "td_up", "move_down")
		if v != Vector2.ZERO:
			_td_face = v.normalized()
			if absf(v.x) > 0.1:
				_sprite.flip_h = v.x < 0.0
			_waving = false
	_attack_cd -= delta
	if can_act and Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
		_start_attack()
	if _attack_t > 0.0:
		_attack_t -= delta
		_update_attack_hits()
	_update_magic(delta, can_act)
	_dash_cd -= delta
	if can_act and _dash_pressed() and _dash_cd <= 0.0 and _knock_t <= 0.0:
		AudioManager.play_sfx_named("dash")
		_dash_t = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_td_dash_dir = v.normalized() if v != Vector2.ZERO else _td_face
		_waving = false
		_afterimage_t = 0.0
		if _anims.has("dash"):
			_pose_dash()
	_sprinting = can_act and v != Vector2.ZERO and _attack_t <= 0.0 and (Input.is_action_pressed("sprint") or Input.is_action_pressed("run_hold"))
	var spd := SPEED
	if _sprinting:
		spd *= SPRINT_MULT
	spd *= speed_mult
	if _attack_t > 0.0:
		spd *= ATTACK_MOVE_FACTOR
	velocity = v * spd
	if _dash_t > 0.0:
		_dash_t -= delta
		velocity = _td_dash_dir * DASH_SPEED
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = AFTERIMAGE_GAP
			_spawn_afterimage()
	elif _knock_t > 0.0:
		_knock_t -= delta
		velocity = _td_face * -1.0 * (THORN_KNOCK_DIST / THORN_KNOCK_TIME) * 0.6
	move_and_slide()
	if td_bounds.size != Vector2.ZERO:
		position.x = clampf(position.x, td_bounds.position.x, td_bounds.end.x)
		position.y = clampf(position.y, td_bounds.position.y, td_bounds.end.y)
	_update_slash(delta)
	_sprite.position.y *= exp(-delta * 14.0)
	_td_pick_animation(v)
	_apply_flip_offset()


func _td_pick_animation(v: Vector2) -> void:
	if _hurt_anim_t > 0.0 and _anims.has("hurt"):
		if _sprite.animation != "hurt":
			_play("hurt")
	elif _attack_t > 0.0 and _anims.has("attack"):
		if _sprite.animation != "attack":
			_play("attack")
	elif _dash_t > 0.0 and _anims.has("dash"):
		_pose_dash()
	elif _sprinting and _anims.has("sprint"):
		if _sprite.animation != "sprint":
			_play("sprint")
		elif not _sprite.is_playing():
			_sprite.play("sprint")
	elif v != Vector2.ZERO:
		if _sprite.animation != "walk":
			_play("walk")
	elif not _waving and _sprite.animation != "idle":
		_play("idle")
