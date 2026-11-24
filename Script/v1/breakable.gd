extends StaticBody2D

signal broken
signal shake_requested(power: float, duration: float)

var hits_left := 5
var visual: Node2D
var _shake_t := 0.0
var _base := Vector2.ZERO
var _done := false


func setup(rect: Rect2, vis: Node2D, hits: int) -> void:
	position = rect.get_center()
	collision_layer = 8
	collision_mask = 0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	add_child(col)
	visual = vis
	hits_left = hits
	if visual != null:
		_base = visual.position


func hit(_dmg: int, dir: float) -> void:
	if _done:
		return
	hits_left -= 1
	_shake_t = 0.22
	AudioManager.play_sfx_named("boom")
	if hits_left > 0:
		shake_requested.emit(1.2, 0.2)
		return
	_done = true
	collision_layer = 0
	shake_requested.emit(3.0, 0.9)
	if visual != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(visual, "position:y", _base.y + 90.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(visual, "modulate:a", 0.0, 1.1).set_delay(0.3)
		tw.chain().tween_callback(func():
			if visual != null:
				visual.queue_free()
			broken.emit()
			queue_free())
	else:
		broken.emit()
		queue_free()


func _process(delta: float) -> void:
	if visual == null or not is_instance_valid(visual) or _done:
		return
	if _shake_t > 0.0:
		_shake_t -= delta
		visual.position = _base + Vector2(randf_range(-2.0, 2.0), 0.0)
	else:
		visual.position = _base
