extends StaticBody2D

const DIR := "res://assets/creatures/dragonfly/"
static var _frames: SpriteFrames

var home := Vector2.ZERO
var _t := randf() * 100.0
var _spd := 1.0
var _rx := 40.0
var _ry := 14.0
var _sprite: AnimatedSprite2D
var dead := false


static func frames() -> SpriteFrames:
	if _frames == null:
		_frames = SpriteFrames.new()
		_frames.remove_animation("default")
		_frames.add_animation("idle")
		_frames.set_animation_speed("idle", 12.0)
		for i in range(1, 5):
			_frames.add_frame("idle", load(DIR + "idle_%02d.png" % i))
		_frames.add_animation("death")
		_frames.set_animation_loop("death", false)
		_frames.set_animation_speed("death", 14.0)
		for i in range(1, 8):
			_frames.add_frame("death", load(DIR + "death_%02d.png" % i))
	return _frames


func setup(pos: Vector2, size_scale: float) -> void:
	home = pos
	add_to_group("ambient")
	position = pos
	_spd = randf_range(0.6, 1.3)
	_rx = randf_range(24.0, 70.0)
	_ry = randf_range(8.0, 22.0)
	collision_layer = 8
	collision_mask = 0
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(size_scale, size_scale)
	_sprite.z_index = 3
	add_child(_sprite)
	_sprite.play("idle")
	_sprite.frame = randi() % 4
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 9.0 * size_scale + 3.0
	cs.shape = sh
	add_child(cs)


func _process(delta: float) -> void:
	if dead:
		return
	_t += delta * _spd
	var p := home + Vector2(sin(_t * 0.7) * _rx, sin(_t * 1.3 + 1.0) * _ry)
	_sprite.flip_h = p.x < position.x
	position = p


func hit(_dmg: int, _dir: float) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	_sprite.play("death")
	_sprite.animation_finished.connect(queue_free)
