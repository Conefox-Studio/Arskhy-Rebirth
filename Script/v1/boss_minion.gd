extends StaticBody2D

const DIR := "res://assets/creatures/ghost_executor/"
const TexUtil = preload("res://scripts/tex_util.gd")
const CELL := 50
const SPRITE_SCALE := 1.5
const HP_BY_DIFF := [5, 5, 5, 10]
const DMG_BY_DIFF := [1, 1, 2, 2]

static var _frames_cache: SpriteFrames

var dead := false
var player: CharacterBody2D
var ground_fn: Callable
var hp := 5
var _diff := 1
var _sprite: AnimatedSprite2D
var _appearing := true
var _life := 14.0
var _t := randf() * 6.0
var _knock := 0.0
var _touch_cd := 0.0


func setup(p: CharacterBody2D, gfn: Callable, pos: Vector2, diff: int) -> void:
	player = p
	ground_fn = gfn
	position = pos
	_diff = clampi(diff, 0, 3)
	hp = HP_BY_DIFF[_diff]
	add_to_group("boss_minion")
	collision_layer = 8
	collision_mask = 0
	z_index = 4
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	col.shape = shape
	add_child(col)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.animation_finished.connect(_on_anim_finished)
	add_child(_sprite)
	_sprite.play("appear")


static func _frames() -> SpriteFrames:
	if _frames_cache != null:
		return _frames_cache
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_add(sf, "appear", "minion_appear.png", 6, 12.0, false)
	_add(sf, "idle", "minion_idle.png", 4, 8.0, true)
	_add(sf, "death", "minion_death.png", 5, 14.0, false)
	_frames_cache = sf
	return sf


static func _add(sf: SpriteFrames, anim: String, file: String, count: int, fps: float, loop: bool) -> void:
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


func _on_anim_finished() -> void:
	if dead:
		queue_free()
	elif _sprite.animation == "appear":
		_appearing = false
		_sprite.play("idle")


func _process(delta: float) -> void:
	if dead or player == null or not is_instance_valid(player):
		return
	_t += delta
	_life -= delta
	_touch_cd = maxf(0.0, _touch_cd - delta)
	_knock = move_toward(_knock, 0.0, 300.0 * delta)
	if _life <= 0.0:
		die()
		return
	if _appearing:
		return
	var target := player.global_position + Vector2(0.0, -22.0)
	var to_p := target - global_position
	var dist := to_p.length()
	var alive: bool = player.hp > 0
	if alive and dist > 1.0:
		var speed := 52.0 + 6.0 * float(_diff)
		position += to_p / dist * speed * delta
	position.x += _knock * delta
	position.y += sin(_t * 5.0) * 10.0 * delta
	_sprite.flip_h = to_p.x < 0.0
	if alive and dist < 17.0 and _touch_cd <= 0.0:
		_touch_cd = 1.0
		if player.has_method("enemy_hit"):
			player.call("enemy_hit", DMG_BY_DIFF[_diff], signf(to_p.x) * -1.0)
		die()


func hit(dmg: int, dir: float) -> void:
	if dead:
		return
	hp -= dmg
	_knock = dir * 120.0
	if hp <= 0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	_sprite.play("death")
