extends "res://scripts/level.gd"

const DebrisScript = preload("res://scripts/debris.gd")

const BRIDGE_SEG := 4
const CRACK_T := 1.1
const WARN_T := 0.9
const COL_STEP := 0.14
const BARREL_STEP := 0.7
const COLLAPSE_PER_FRAME := 40

var _root3: Node2D
var _bridge: TileMapLayer
var _atlas_tex: ImageTexture
var _seg_dead := {}
var _collapse: Array = []
var _fall_boxes: Array = []
var _barrels: Array = []
var _barrels_go := false
var _barrel_trigger_x := 0.0
var _release_t := 0.0


func _configure() -> void:
	map_json = "res://maps/jungle_route_3/map.json"
	tileset_path = "res://maps/jungle_route_3/tileset.tres"
	location_name = "ROUTE 3"
	prev_scene = "res://scenes/jungle_route_2.tscn"
	next_scene = "res://scenes/jungle_route_4.tscn"
	music_path = "res://assets/audio/music/jungle_route_3/route_3.mp3"
	tile_collision = true
	ground_sink = 13.0
	foot_offset = 13.0
	pushable_layers = ["box", "box_jatuh"]
	barrel_layers = ["barrel_roll"]
	ground_layers = ["jalan", "jembatan"]
	black_fill_layers = ["jalan", "tanah"]
	black_fill_min_row = 100
	player_after_layer = "jalan"
	behind_player_layers = ["tiang_c", "box"]
	cam_limit_top = -300
	cam_limit_bottom = 1900
	wildlife_count = 6
	bg_dir = "res://assets/maps/jungle_route_1/"
	clear_color = Color("0a1e13")
	backgrounds = [
		{"file": "bg_far.png", "scale": 1.5, "move": 0.05, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_mid.png", "scale": 1.5, "move": 0.16, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_near.png", "scale": 1.5, "move": 0.32, "ymove": 0.0, "top": -204.0, "wrap": true},
	]
	low_skip = ["bg_mid.png"]


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_root3 = root
	_bridge = _layer_named(root, "jembatan")
	for o in _objects:
		if not is_instance_valid(o):
			continue
		if o.get("wake_dx") != null:
			o.set("wake_dx", 0.0)
			o.set("wake_dy", 0.0)
			_barrels.append(o)
		elif o.position.y < 200.0:
			o.set("max_fall", 150.0)
			_fall_boxes.append({"n": o, "home": o.position})
	_barrels.sort_custom(func(a, b): return a.position.x < b.position.x)
	if not _barrels.is_empty():
		_barrel_trigger_x = _barrels[0].position.x - 22.0 * 16.0


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _player == null:
		return
	_tick_barrels(delta)
	_tick_boxes()
	_tick_bridge(delta)
	_tick_collapse()


func _tick_barrels(delta: float) -> void:
	if _barrels.is_empty():
		return
	if not _barrels_go:
		if _player.is_on_floor() and _player.global_position.x >= _barrel_trigger_x \
				and _player.global_position.x < _barrels[_barrels.size() - 1].position.x:
			_barrels_go = true
			_release_t = 0.0
		return
	_release_t -= delta
	if _release_t <= 0.0:
		var b = _barrels.pop_front()
		if is_instance_valid(b):
			b.call("_wake", -1.0)
			b.velocity = Vector2(-70.0, b.velocity.y)
		_release_t = BARREL_STEP


func _tick_boxes() -> void:
	for fb in _fall_boxes:
		var n = fb.n
		if not is_instance_valid(n):
			continue
		if n.position.y > float(cam_limit_bottom) - 120.0:
			n.position = fb.home
			n.velocity = Vector2.ZERO


var _chain_on := false
var _chain_col := 0
var _chain_warn := 0.0
var _chain_t := 0.0
var _bridge_max_x := 0


func _tick_bridge(delta: float) -> void:
	if _bridge == null:
		return
	if _bridge_max_x == 0:
		for c in _bridge.get_used_cells():
			_bridge_max_x = maxi(_bridge_max_x, c.x)
	if _chain_on:
		_tick_chain(delta)
		return
	var col := -1
	if _player.is_on_floor():
		var c := _bridge.local_to_map(_bridge.to_local(_player.global_position + Vector2(0, 2)))
		for dy in [0, 1, -1]:
			if _bridge.get_cell_source_id(Vector2i(c.x, c.y + dy)) != -1:
				col = c.x
				break
	if col < 0:
		_stand_t = maxf(_stand_t - delta * 0.6, 0.0)
		return
	_stand_t += delta
	if _stand_t > CRACK_T * 0.5 and randf() < 0.1:
		_crumble(col)
	if _stand_t > CRACK_T:
		_chain_on = true
		_chain_col = col
		_chain_warn = WARN_T
		_chain_t = 0.0
		shake_camera(2.0, 0.3)


var _stand_t := 0.0


func _tick_chain(delta: float) -> void:
	if _chain_warn > 0.0:
		_chain_warn -= delta
		if randf() < 0.35:
			shake_camera(1.6, 0.12)
			_crumble(_chain_col + randi() % 3)
		return
	_chain_t -= delta
	while _chain_t <= 0.0:
		_chain_t += COL_STEP
		if _chain_col > _bridge_max_x:
			_chain_on = false
			return
		_break_column(_chain_col)
		_chain_col += 1


func _crumble(cx: int) -> void:
	for cell in _bridge.get_used_cells():
		if cell.x == cx:
			_debris_at(_bridge, cell, 1)
			break


func _break_column(cx: int) -> void:
	_shatter(_bridge, cx, cx, -100000, 100000, 0.6)
	if cx % 3 == 0:
		AudioManager.play_sfx_named("crate_break")
		shake_camera(2.5, 0.2)
	var seg := int(floor(float(cx) / float(BRIDGE_SEG)))
	if _seg_dead.has(seg):
		return
	_seg_dead[seg] = true
	var x0 := seg * BRIDGE_SEG
	var x1 := x0 + BRIDGE_SEG - 1
	_queue_collapse(_layer_named(_root3, "kayu_hancur"), x0 - 1, x1 + 1)
	for nm in ["tiang_a", "tiang_b", "tiang_c"]:
		_queue_collapse(_layer_named(_root3, nm), x0 - 1, x1 + 1)


func _shatter(layer: TileMapLayer, x0: int, x1: int, y0: int, y1: int, chance: float) -> void:
	if layer == null:
		return
	for cell in layer.get_used_cells():
		if cell.x >= x0 and cell.x <= x1 and cell.y >= y0 and cell.y <= y1:
			if randf() < chance:
				_debris_at(layer, cell, 2)
			layer.erase_cell(cell)


func _queue_collapse(layer: TileMapLayer, x0: int, x1: int) -> void:
	if layer == null:
		return
	var items: Array = []
	for cell in layer.get_used_cells():
		if cell.x >= x0 and cell.x <= x1:
			items.append([layer, cell])
	if items.is_empty():
		return
	items.sort_custom(func(a, b): return a[1].y < b[1].y)
	_collapse.append({"items": items, "i": 0})


func _tick_collapse() -> void:
	for job in _collapse.duplicate():
		var items: Array = job.items
		var n := 0
		while job.i < items.size() and n < COLLAPSE_PER_FRAME:
			var it = items[job.i]
			var layer: TileMapLayer = it[0]
			if is_instance_valid(layer) and layer.get_cell_source_id(it[1]) != -1:
				if randf() < 0.25:
					_debris_at(layer, it[1], 2)
				layer.erase_cell(it[1])
			job.i += 1
			n += 1
		if job.i >= items.size():
			_collapse.erase(job)


func _debris_at(layer: TileMapLayer, cell: Vector2i, count: int) -> void:
	if _atlas_img == null:
		return
	if _atlas_tex == null:
		_atlas_tex = ImageTexture.create_from_image(_atlas_img)
	var ac := layer.get_cell_atlas_coords(cell)
	if ac.x < 0:
		return
	var wp := layer.to_global(layer.map_to_local(cell))
	DebrisScript.burst(_root3, _atlas_tex, Rect2(wp - Vector2(8, 8), Vector2(16, 16)), count, 1.1, Rect2(ac.x * TILE, ac.y * TILE, TILE, TILE))
