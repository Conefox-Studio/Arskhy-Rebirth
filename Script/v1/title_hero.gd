extends Node2D

signal arrived
signal exited

const FxLib = preload("res://scripts/fx.gd")

const FRAMES_DIR := "res://assets/characters/shyrn/"
const SPEED := 84.0
const ANIM_OFFSET_X := {"walk": -77.5, "idle": -63.5, "wave": -48.5}
const SPRITE_SCALE := 0.26
const ANIM_SCALE := {"wave": 0.23}
const ANIMS := {
	"walk": [20, 16.0, true],
	"idle": [25, 8.0, true],
	"wave": [25, 14.0, false],
}
const WAVE_DELAY_MIN := 5.0
const WAVE_DELAY_MAX := 9.0

enum State { HIDDEN, ENTER, IDLE, EXIT }

var state: State = State.HIDDEN
var stop_x := 24.0
var exit_x := 600.0

var _sprite: AnimatedSprite2D
var _shadow: Node2D
var _shadow_main: Sprite2D
var _shadow_soft: Sprite2D
var _wave_timer := 0.0


func _ready() -> void:
	visible = false
	_build_shadow()
	_build_sprite()
	GameSettings.graphics_changed.connect(_apply_shadow)
	_apply_shadow()


func _build_sprite() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ANIMS.keys():
		var info: Array = ANIMS[anim]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, float(info[1]))
		frames.set_animation_loop(anim, bool(info[2]))
		for i in range(1, int(info[0]) + 1):
			frames.add_frame(anim, preload("res://scripts/tex_util.gd").load_tex(FRAMES_DIR + "%s/%s_%02d.png" % [anim, anim, i]))
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.animation_finished.connect(_on_anim_finished)
	_sprite.frame_changed.connect(_sync_shadow)
	_sprite.animation_changed.connect(_sync_shadow)
	add_child(_sprite)
	_play("idle")


func _play(anim: String) -> void:
	var sc: float = ANIM_SCALE.get(anim, SPRITE_SCALE)
	_sprite.scale = Vector2(sc, sc)
	var h: float = _sprite.sprite_frames.get_frame_texture(anim, 0).get_height()
	_sprite.offset = Vector2(0.0, -h / 2.0)
	_sprite.play(anim)
	_fix_offset()
	_sync_shadow()


func _fix_offset() -> void:
	var ox: float = ANIM_OFFSET_X.get(_sprite.animation, 0.0)
	if _sprite.flip_h:
		ox = -ox
	if not is_equal_approx(_sprite.offset.x, ox):
		_sprite.offset.x = ox
		_sync_shadow()


func _on_anim_finished() -> void:
	if _sprite.animation == "wave" and state == State.IDLE:
		_play("idle")
		_wave_timer = randf_range(WAVE_DELAY_MIN, WAVE_DELAY_MAX)


func start_enter(from_x: float, to_x: float, ground_y: float) -> void:
	position = Vector2(from_x, ground_y)
	stop_x = to_x
	state = State.ENTER
	visible = true
	_sprite.flip_h = true
	_play("walk")
	_sync_shadow()


func walk_out(to_x: float) -> void:
	if state == State.HIDDEN:
		exited.emit.call_deferred()
		return
	exit_x = to_x
	state = State.EXIT
	_sprite.flip_h = false
	_play("walk")


func _process(delta: float) -> void:
	if _sprite != null:
		_fix_offset()
	match state:
		State.ENTER:
			position.x -= SPEED * delta
			if position.x <= stop_x:
				position.x = stop_x
				state = State.IDLE
				_play("idle")
				_wave_timer = randf_range(WAVE_DELAY_MIN * 0.5, WAVE_DELAY_MAX * 0.5)
				arrived.emit()
		State.IDLE:
			_wave_timer -= delta
			pass
		State.EXIT:
			position.x += SPEED * delta
			if position.x >= exit_x:
				state = State.HIDDEN
				visible = false
				exited.emit()


func _build_shadow() -> void:
	_shadow = Node2D.new()
	add_child(_shadow)
	_shadow_soft = Sprite2D.new()
	_shadow_soft.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow.add_child(_shadow_soft)
	_shadow_main = Sprite2D.new()
	_shadow_main.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_shadow.add_child(_shadow_main)


func _apply_shadow() -> void:
	var mode := GameSettings.shadow_index
	_shadow.visible = mode > 0
	_shadow_soft.visible = mode >= 2
	if mode > 0:
		var p := FxLib.shadow_params(mode)
		_shadow_main.modulate = Color(0, 0, 0, p.alpha)
		_shadow_soft.modulate = Color(0, 0, 0, p.soft_alpha)
	_sync_shadow()


func _sync_shadow() -> void:
	if _sprite == null or _shadow_main == null or GameSettings.shadow_index <= 0:
		return
	var tex := _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	if tex == null:
		return
	var p := FxLib.shadow_params(GameSettings.shadow_index)
	var s := _sprite.scale.x
	var items := [[_shadow_main, 1.0], [_shadow_soft, float(p.soft_grow)]]
	for it in items:
		var sp: Sprite2D = it[0]
		var g: float = it[1]
		sp.texture = tex
		sp.flip_h = _sprite.flip_h
		sp.offset = _sprite.offset
		sp.transform = Transform2D(Vector2(s, 0.0), Vector2(p.lean * g * s, -p.squash * g * s), Vector2.ZERO)
