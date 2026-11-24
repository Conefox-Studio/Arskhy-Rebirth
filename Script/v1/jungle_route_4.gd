extends "res://scripts/level.gd"

const BeeScript = preload("res://scripts/bee.gd")
const DebrisScript = preload("res://scripts/debris.gd")
const HIVE_HITS := 3
const BEE_COUNTS := [4, 6, 9, 14]

var _root4: Node2D
var _tp_cells := {}
var _swing: TileMapLayer
var _swing_off_t := 0.0
var _hive_cells: Array[Vector2i] = []
var _hive_layer: TileMapLayer
var _hive_body: StaticBody2D
var _hive_hits := HIVE_HITS
var _hive_done := false
var _bees: Array = []


func _configure() -> void:
	map_json = "res://maps/jungle_route_4/map.json"
	tileset_path = "res://maps/jungle_route_4/tileset.tres"
	location_name = "ROUTE 4"
	prev_scene = "res://scenes/jungle_route_3.tscn"
	next_scene = ""
	music_path = "res://assets/audio/music/jungle_route_4/route_4.mp3"
	tile_collision = true
	ground_sink = 4.0
	foot_offset = 4.0
	flat_tile_ids = [42, 43, 44]
	flat_tile_top = 8
	ground_layers = ["jalan"]
	player_after_layer = "jalan"
	behind_player_layers = ["jalan_cave", "teleport_cave"]
	cam_limit_top = 600
	cam_limit_bottom = 2300
	void_death_y = 2200.0
	enemies_enabled = false
	wildlife_count = 8
	bg_dir = "res://assets/maps/jungle_route_1/"
	clear_color = Color("0a1e13")
	backgrounds = [
		{"file": "bg_far.png", "scale": 1.5, "move": 0.05, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_mid.png", "scale": 1.5, "move": 0.16, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_near.png", "scale": 1.5, "move": 0.32, "ymove": 0.0, "top": -204.0, "wrap": true},
	]
	low_skip = ["bg_mid.png"]


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_root4 = root
	var tp := _layer_named(root, "teleport_cave")
	if tp != null:
		for c in tp.get_used_cells():
			_tp_cells[c] = true
		tp.collision_enabled = false
	_swing = _layer_named(root, "ayunan")
	if _swing != null and _swing.tile_set != null:
		var ts := _swing.tile_set.duplicate(true) as TileSet
		var src := ts.get_source(0) as TileSetAtlasSource
		if src != null and ts.get_physics_layers_count() > 0:
			for i in src.get_tiles_count():
				var td := src.get_tile_data(src.get_tile_id(i), 0)
				for pi in td.get_collision_polygons_count(0):
					td.set_collision_polygon_one_way(0, pi, true)
					td.set_collision_polygon_one_way_margin(0, pi, 2.0)
		_swing.tile_set = ts
	_hive_layer = _layer_named(root, "sarang_lebah")
	if _hive_layer != null:
		_hive_layer.collision_enabled = false
		var r := Rect2()
		var first := true
		for c in _hive_layer.get_used_cells():
			if c.x >= 14:
				_hive_cells.append(c)
				var cr := Rect2(Vector2(c.x * TILE, c.y * TILE), Vector2(TILE, TILE))
				r = cr if first else r.merge(cr)
				first = false
		if not _hive_cells.is_empty():
			_hive_body = StaticBody2D.new()
			_hive_body.collision_layer = 8
			_hive_body.collision_mask = 0
			_hive_body.position = r.get_center()
			var cs := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			sh.size = r.size + Vector2(8, 8)
			cs.shape = sh
			_hive_body.add_child(cs)
			_hive_body.set_script(load("res://scripts/hive_body.gd"))
			_hive_body.set("owner_level", self)
			root.add_child(_hive_body)


func hive_hit() -> void:
	if _hive_done:
		return
	_hive_hits -= 1
	shake_camera(1.6, 0.2)
	AudioManager.play_sfx_named("boom")
	if _hive_hits <= 0:
		_hive_done = true
		_break_hive()


func _break_hive() -> void:
	if _hive_body != null and is_instance_valid(_hive_body):
		_hive_body.collision_layer = 0
	var r := Rect2()
	var first := true
	for c in _hive_cells:
		var cr := Rect2(Vector2(c.x * TILE, c.y * TILE), Vector2(TILE, TILE))
		r = cr if first else r.merge(cr)
		first = false
	var atlas_tex: ImageTexture = null
	if _atlas_img != null:
		atlas_tex = ImageTexture.create_from_image(_atlas_img)
	var landing_y := _ground_y_at(r.get_center().x) - 4.0
	var fall := TileMapLayer.new()
	fall.tile_set = _hive_layer.tile_set
	for c in _hive_cells:
		fall.set_cell(c, 0, _hive_layer.get_cell_atlas_coords(c))
		_hive_layer.erase_cell(c)
	_root4.add_child(fall)
	_root4.move_child(fall, _hive_layer.get_index())
	var drop := maxf(landing_y - r.end.y, 8.0)
	var tw := create_tween()
	tw.tween_property(fall, "position:y", drop, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		AudioManager.play_sfx_named("crate_break")
		shake_camera(3.0, 0.35)
		if atlas_tex != null:
			for c in _hive_cells:
				var ac := fall.get_cell_atlas_coords(c)
				var wp := Vector2(c.x * TILE + 8.0, c.y * TILE + 8.0 + drop)
				DebrisScript.burst(_root4, atlas_tex, Rect2(wp - Vector2(8, 8), Vector2(16, 16)), 3, 1.1, Rect2(ac.x * TILE, ac.y * TILE, TILE, TILE))
		fall.queue_free()
		_release_bees(Vector2(r.get_center().x, landing_y - 10.0)))


func _release_bees(at: Vector2) -> void:
	var n: int = BEE_COUNTS[clampi(GameState.difficulty, 0, BEE_COUNTS.size() - 1)]
	for i in n:
		var b: StaticBody2D = BeeScript.new()
		b.setup(at + Vector2(randf_range(-14.0, 14.0), randf_range(-12.0, 6.0)), _player, Callable(self, "_ground_y_at"))
		_root4.add_child(b)
		_bees.append(b)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _player == null:
		return
	_tick_swing(delta)
	_tick_teleport()


func _tick_swing(delta: float) -> void:
	if _swing == null:
		return
	if _swing_off_t > 0.0:
		_swing_off_t -= delta
		if _swing_off_t <= 0.0:
			_swing.collision_enabled = true
		return
	if InputMap.has_action("move_down") and Input.is_action_pressed("move_down") and _player.is_on_floor() and _player.controls_enabled:
		var p: Vector2 = _player.global_position + Vector2(0, 4)
		var c := _swing.local_to_map(_swing.to_local(p))
		for dy in [0, -1]:
			if _swing.get_cell_source_id(Vector2i(c.x, c.y + dy)) != -1:
				_swing.collision_enabled = false
				_swing_off_t = 0.28
				_player.position.y += 3.0
				return


func _tick_teleport() -> void:
	if _tp_cells.is_empty() or _dying:
		return
	var p: Vector2 = _player.global_position
	for off in [-4.0, -18.0]:
		var cell := Vector2i(floori(p.x / TILE), floori((p.y + off) / TILE))
		if _tp_cells.has(cell):
			_goto("res://scenes/dungeon.tscn", "")
			return
