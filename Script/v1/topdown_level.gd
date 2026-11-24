extends "res://scripts/level.gd"

var td_front_layers: Array = []
var td_solid_layers: Array = []
var td_map_px := Vector2.ZERO
var _grid: AStarGrid2D
var _grid_enemy: AStarGrid2D
var _td_cells_built := false


func _build_ground(_root: Node2D, _tileset: TileSet, _layers: Array) -> void:
	pass


func _build_void_fill(_root: Node2D) -> void:
	pass


func _trim_stray_underground(_root: Node2D) -> void:
	pass


func _snap_to_ground(_root: Node2D) -> void:
	pass


func _build_black_fill(_root: Node2D) -> void:
	pass


func _build_shadows(_map: Node2D) -> void:
	pass


func _ground_y_at(_x: float) -> float:
	return 0.0


func _td_spawn() -> Vector2:
	return Vector2(64.0, 64.0)


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _build_player(map: Node) -> void:
	_player = PlayerScript.new()
	_player.size_mult = player_size_mult
	_player.position = _td_spawn()
	_spawn = _player.position
	_player.died.connect(_on_player_died)
	var loaded: Dictionary = GameSettings.pending_load
	if not loaded.is_empty():
		_player.position = Vector2(loaded.x, loaded.y)
		GameSettings.pending_load = {}
	GameSettings.arrive_side = ""
	map.add_child(_player)
	_player.set_top_down(true)
	_player.td_bounds = Rect2(8.0, 8.0, td_map_px.x - 16.0, td_map_px.y - 16.0)
	if player_glow > 0.0:
		_add_player_glow()
	for n in td_front_layers:
		var l := _layer_named(map, String(n))
		if l != null:
			map.move_child(l, map.get_child_count() - 1)
	for o in _objects:
		if is_instance_valid(o) and o.get_parent() == map:
			map.move_child(o, _player.get_index())
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	_cam.position = Vector2(0, -20)
	_cam.limit_left = 0
	_cam.limit_top = 0
	_cam.limit_right = int(td_map_px.x)
	_cam.limit_bottom = int(td_map_px.y)
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	_player.add_child(_cam)
	_cam.make_current()
	_cam.reset_smoothing()
	_cam0 = _player.position
	_bg_ready = true
	for o in _objects:
		if is_instance_valid(o) and "player" in o:
			o.player = _player


func td_build_grid(root: Node2D, restricted: Rect2) -> void:
	var cols := int(td_map_px.x / TILE)
	var rows := int(td_map_px.y / TILE)
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, cols, rows)
	_grid.cell_size = Vector2(TILE, TILE)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	_grid_enemy = AStarGrid2D.new()
	_grid_enemy.region = Rect2i(0, 0, cols, rows)
	_grid_enemy.cell_size = Vector2(TILE, TILE)
	_grid_enemy.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid_enemy.update()
	for n in td_solid_layers:
		var l := _layer_named(root, String(n))
		if l == null:
			continue
		for c in l.get_used_cells():
			if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
				_grid.set_point_solid(c, true)
				_grid_enemy.set_point_solid(c, true)
	if restricted.size != Vector2.ZERO:
		for y in range(int(restricted.position.y / TILE), int(restricted.end.y / TILE)):
			for x in range(int(restricted.position.x / TILE), int(restricted.end.x / TILE)):
				if x >= 0 and y >= 0 and x < cols and y < rows:
					_grid_enemy.set_point_solid(Vector2i(x, y), true)
	_td_cells_built = true


func _td_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _td_free_near(g: AStarGrid2D, c: Vector2i) -> Vector2i:
	if g.is_in_boundsv(c) and not g.is_point_solid(c):
		return c
	for r in range(1, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := Vector2i(c.x + dx, c.y + dy)
				if g.is_in_boundsv(q) and not g.is_point_solid(q):
					return q
	return Vector2i(-1, -1)


func find_path(from: Vector2, to: Vector2, enemy := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not _td_cells_built:
		return out
	var g: AStarGrid2D = _grid_enemy if enemy else _grid
	var a := _td_free_near(g, _td_cell(from))
	var b := _td_free_near(g, _td_cell(to))
	if a.x < 0 or b.x < 0:
		return out
	for c in g.get_id_path(a, b):
		out.append(Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0))
	return out
