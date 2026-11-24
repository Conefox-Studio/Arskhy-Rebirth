extends CharacterBody2D

const GRAVITY := 900.0
const FxLib = preload("res://scripts/fx.gd")
const DayNightScript = preload("res://scripts/day_night.gd")

var stack_mask := false
var max_fall := 1.0e9
var fall_limit := 1.0e9
@export var friction := 700.0

var _push_dir := 0.0
var _push_speed := 0.0
var _push_time := 0.0
var _shadows: Array = []
var _shadow_root: Node2D
var _shadow_base := 0.0


func _ready() -> void:
	add_to_group("pushable")
	collision_layer = 4
	collision_mask = 5 if stack_mask else 1
	floor_snap_length = 8.0
	_build_shadows()
	GameSettings.graphics_changed.connect(_apply_shadows)
	_apply_shadows()


func _build_shadows() -> void:
	_shadow_root = Node2D.new()
	_shadow_root.show_behind_parent = true
	add_child(_shadow_root)
	move_child(_shadow_root, 0)
	for c in get_children():
		var spr := c as Sprite2D
		if spr == null or spr.texture == null or spr.get_parent() != self:
			continue
		var h := float(spr.texture.get_height())
		var yb := spr.position.y + (h * 0.5 if spr.centered else h) * spr.scale.y - spr.offset.y * spr.scale.y * 0.0
		var pair := []
		for soft in [true, false]:
			var sh := Sprite2D.new()
			sh.texture = spr.texture
			sh.centered = spr.centered
			sh.offset = spr.offset
			sh.region_enabled = spr.region_enabled
			sh.region_rect = spr.region_rect
			sh.flip_h = spr.flip_h
			sh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if GameSettings.shadow_shader else spr.texture_filter
			var lh := float(spr.texture.get_height())
			sh.material = FxLib.shadow_material(lh * 0.5 if spr.centered else lh, maxf(lh, 16.0), 1.0)
			_shadow_root.add_child(sh)
			pair.append(sh)
		_shadow_base = maxf(_shadow_base, yb)
		_shadows.append({"sprite": spr, "soft": pair[0], "main": pair[1], "yb": yb})


func _apply_shadows() -> void:
	var mode := GameSettings.shadow_index
	var p := FxLib.shadow_params(mode)
	for it in _shadows:
		var spr: Sprite2D = it.sprite
		var main: Sprite2D = it.main
		var soft: Sprite2D = it.soft
		main.visible = mode > 0
		soft.visible = mode >= 2
		var bl := FxLib.shadow_blur(mode)
		for shs in [main, soft]:
			var mat := shs.material as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("blur_near", bl.x)
				mat.set_shader_parameter("blur_far", bl.y * (1.3 if shs == soft else 1.0))
		if mode <= 0:
			continue
		var lean: float = float(p.lean) * DayNightScript.shadow_lean_factor()
		var sq: float = float(p.squash) * DayNightScript.shadow_length_factor()
		var af := DayNightScript.shadow_alpha_factor()
		main.modulate = Color(0, 0, 0, p.alpha * af)
		soft.modulate = Color(0, 0, 0, p.soft_alpha * af)
		main.transform = FxLib.shadow_transform(it.yb, lean, sq) * spr.transform
		soft.transform = FxLib.shadow_transform(it.yb, lean * p.soft_grow, sq * p.soft_grow) * spr.transform


func push(dir_x: float, speed: float) -> void:
	Achievements.unlock("pusher")
	_push_dir = dir_x
	_push_speed = speed
	_push_time = 0.1


func _physics_process(delta: float) -> void:
	if global_position.y > fall_limit:
		queue_free()
		return
	_push_time -= delta
	if _push_time > 0.0:
		velocity.x = _push_dir * _push_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, max_fall)
	_step_up(delta)
	move_and_slide()
	_update_shadow_ground()


func _step_up(delta: float) -> void:
	if velocity.x == 0.0 or not is_on_floor():
		return
	var motion := Vector2(velocity.x * delta, 0.0)
	if not test_move(global_transform, motion):
		return
	for h in [2.0, 4.0, 6.0, 8.0, 10.0]:
		var up := global_transform.translated(Vector2(0, -h))
		if not test_move(global_transform, Vector2(0, -h)) and not test_move(up, motion):
			global_position.y -= h
			return


func _update_shadow_ground() -> void:
	if _shadow_root == null or _shadows.is_empty():
		return
	var from := global_position + Vector2(0.0, _shadow_base - 4.0)
	var d := FxLib.ground_drop(get_world_2d().direct_space_state, from, 1, [get_rid()])
	if d < 0.0:
		_shadow_root.modulate.a = 0.0
		return
	var h := maxf(d - 4.0, 0.0)
	var f := FxLib.shadow_height_fade(h)
	_shadow_root.position = Vector2(0.0, h)
	_shadow_root.scale = Vector2(f.x, 1.0)
	_shadow_root.modulate.a = f.y
