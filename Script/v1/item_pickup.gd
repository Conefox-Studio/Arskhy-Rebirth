extends Node2D

var item: Dictionary = {}
var player: Node2D
var _age := 0.0
var _spr: Sprite2D
var _base_y := 0.0


func setup(it: Dictionary, p: Node2D, pos: Vector2) -> void:
	item = it
	player = p
	position = pos
	_base_y = pos.y
	z_index = 3
	_spr = Sprite2D.new()
	_spr.texture = it.get("icon")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.offset = Vector2(0, -9)
	add_child(_spr)


func _process(delta: float) -> void:
	_age += delta
	if _spr != null:
		_spr.position.y = sin(_age * 3.0) * 1.5
	if _age < 1.2 or player == null or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < 18.0:
		var copy: Dictionary = item.duplicate()
		if Inventory.add_item(copy):
			AudioManager.play_ui("select")
			queue_free()
		else:
			_age = 0.6
