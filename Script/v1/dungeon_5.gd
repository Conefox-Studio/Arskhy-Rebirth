extends "res://scripts/level.gd"

const PixelTraps = preload("res://scripts/pixel_traps.gd")
const TexLoader = preload("res://scripts/tex_util.gd")
const ACID_SHADER := "res://shaders/acid_wave.gdshader"
const CLIP_SHADER := "res://shaders/clip_below.gdshader"
const MAP_DIR := "res://maps/dungeon_5/"
const OLD_PX := 8.0
const GATE_TIME := 3.2

var _tuas_on: TileMapLayer
var _tuas_off: TileMapLayer
var _gate: TileMapLayer
var _lever_on := false
var _cam1 := Vector2.ZERO
var _gate_rect := Rect2()
var _traps: Array = []


func _configure() -> void:
	map_json = MAP_DIR + "map.json"
	tileset_path = MAP_DIR + "tileset.tres"
	location_name = "DUNGEON V"
	show_location_name = false
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan"]
	behind_player_layers = ["tuas_on", "tuas_off"]
	cam_limit_top = 0
	cam_limit_bottom = 544
	enemies_enabled = false
	wildlife_count = 0
	force_night = true
	lit_night = true
	night_tint = Color(0.62, 0.64, 0.80)
	rain_mode = "never"
	night_eyes = false
	night_fireflies = false
	night_aurora = false
	no_atmosphere = true
	green_motes = true
	jump_boost = 1.15
	ambient_path = "res://assets/audio/ambient/dungeon_ambience.wav"
	ambient_db = -9.0
	no_night_ambient = true
	reverb_sfx = true
	kill_layers = ["asam"]
	kill_text = "Terlarut asam"
	kill_visible = true
	void_death_y = 700.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _raw_marks(n: String) -> Array:
	var out: Array = []
	for ld in _layers_data:
		if String(ld.get("name", "")) == n:
			for t in ld.get("tiles", []):
				out.append(Vector2i(int(t.get("ox", int(t.x) * 2)), int(t.get("oy", int(t.y) * 2))))
	return out


func _hide_layer(root: Node, n: String) -> void:
	var l := _layer_named(root, n)
	if l != null:
		l.visible = false


func _surface_below(map: Node, cx: int, cy: int, px: float) -> float:
	var layer := _layer_named(map, "jalan")
	var tex := load(MAP_DIR + "tileset.png") as Texture2D
	if layer == null or tex == null:
		return -1.0
	var img := tex.get_image()
	var lx := clampi(int(px) - cx * TILE, 0, TILE - 1)
	for y in range(cy, cy + 40):
		var c := Vector2i(cx, y)
		if layer.get_cell_source_id(c) == -1:
			continue
		var ac := layer.get_cell_atlas_coords(c)
		for yy in TILE:
			if img.get_pixel(ac.x * TILE + lx, ac.y * TILE + yy).a > 0.04:
				return float(y * TILE + yy)
		return float(y * TILE)
	return -1.0


func _ceiling_bottom(map: Node, cx: int) -> float:
	var layer := _layer_named(map, "jalan")
	if layer == null:
		return 32.0
	for y in range(0, 12):
		if layer.get_cell_source_id(Vector2i(cx, y)) == -1:
			return float(y * TILE)
	return 32.0


func _build_player(map: Node) -> void:
	var had_load := not GameSettings.pending_load.is_empty()
	super._build_player(map)
	if had_load or _player == null:
		return
	for ld in _layers_data:
		if String(ld.get("name", "")) == "Player_Spawn":
			var tiles: Array = ld.get("tiles", [])
			if tiles.is_empty():
				return
			var t = tiles[0]
			var sx := int(t.x) * TILE + TILE / 2.0
			var sy := int(t.y) * TILE + TILE / 2.0 - 2.0
			var fy := _surface_below(map, int(t.x), int(t.y), sx)
			if fy >= 0.0:
				sy = fy - 1.0
			_player.position = Vector2(sx, sy)
			_spawn = _player.position
			return


func _ready() -> void:
	super._ready()
	AudioManager.start_loop("chain", "res://assets/audio/ambient/chain_loop.wav", -14.0)
	for t in _traps:
		t.player = _player
		t.level = self


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null or _dialog_active:
		return
	if _player.global_position.x < 40.0 and _player.hp > 0:
		_goto("res://scenes/dungeon_6.tscn", "")


func _exit_tree() -> void:
	AudioManager.stop_loop("chain")
	super._exit_tree()


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	for n in ["Player_Spawn", "seq_after_lever", "prompt_lever", "camera_1", "ceiling_trap", "arrow_trap", "saw", "fire_trap", "blood_drip", "vas", "chest", "jalan_bergerak"]:
		_hide_layer(root, n)
	_tuas_on = _layer_named(root, "tuas_on")
	_tuas_off = _layer_named(root, "tuas_off")
	if _tuas_on != null:
		_tuas_on.visible = false
	var acid := _layer_named(root, "asam")
	if acid != null:
		var m := ShaderMaterial.new()
		m.shader = load(ACID_SHADER)
		acid.material = m
	_setup_gate(root)
	_build_lever(root)
	_build_traps(root)
	_build_blood(root)


func _setup_gate(root: Node) -> void:
	_gate = _layer_named(root, "gerbang")
	if _gate == null:
		return
	_make_moving(_gate)
	var art := _cluster_art(_gate, _gate.get_used_cells())
	if not art.is_empty():
		_gate_rect = art[1]
	var cam := _raw_marks("camera_1")
	if cam.is_empty():
		_cam1 = _gate_rect.get_center()
	else:
		_cam1 = Vector2(cam[0].x * OLD_PX + 4.0, cam[0].y * OLD_PX + 4.0)
	var fy := _surface_below(root, int(_gate_rect.get_center().x / TILE), 4, _gate_rect.get_center().x)
	var m := ShaderMaterial.new()
	m.shader = load(CLIP_SHADER)
	m.set_shader_parameter("clip_y", (fy if fy >= 0.0 else 240.0) + 3.0 * TILE)
	_gate.material = m


func _build_lever(root: Node2D) -> void:
	if _tuas_off == null:
		return
	var r := Rect2()
	var first := true
	for c in _tuas_off.get_used_cells():
		var cr := Rect2(Vector2(c.x * TILE, c.y * TILE), Vector2(TILE, TILE))
		r = cr if first else r.merge(cr)
		first = false
	if first:
		return
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = r.get_center()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size + Vector2(8, 8)
	cs.shape = sh
	body.add_child(cs)
	body.set_script(load("res://scripts/lever_body.gd"))
	body.set("owner_level", self)
	root.add_child(body)


func _add_trap(root: Node2D, t: Node2D) -> void:
	root.add_child(t)
	_objects.append(t)
	_traps.append(t)


func _build_traps(root: Node2D) -> void:
	var saws := {}
	for m in _raw_marks("saw"):
		if not saws.has(m.x):
			saws[m.x] = []
		saws[m.x].append(m.y)
	var si := 0
	var keys := saws.keys()
	keys.sort()
	for kx in keys:
		var ys: Array = saws[kx]
		var px := float(kx) * OLD_PX + 4.0
		var top := _ceiling_bottom(root, int(px / TILE))
		var t := PixelTraps.SawTrap.new()
		t.setup(px, top, float(ys.max()) * OLD_PX + 4.0, si * 1.3)
		_add_trap(root, t)
		si += 1
	var ceils := {}
	for m in _raw_marks("ceiling_trap"):
		if not ceils.has(m.x):
			ceils[m.x] = []
		ceils[m.x].append(m.y)
	var ci := 0
	for kx in ceils:
		var px := float(kx) * OLD_PX + 4.0
		var fy := _surface_below(root, int(px / TILE), 6, px)
		if fy < 0.0:
			fy = float((ceils[kx] as Array).max()) * OLD_PX + 8.0
		var t2 := PixelTraps.CeilingTrap.new()
		t2.setup(px, _ceiling_bottom(root, int(px / TILE)), fy, 0.8 + ci * 1.7)
		_add_trap(root, t2)
		ci += 1
	var fi := 0
	for m in _raw_marks("fire_trap"):
		var px := float(m.x) * OLD_PX + 4.0
		var is_up: bool = int(m.y) > 16
		var by := _surface_below(root, int(px / TILE), 6, px) if is_up else _ceiling_bottom(root, int(px / TILE))
		if by < 0.0:
			by = float(m.y) * OLD_PX + 8.0
		var t3 := PixelTraps.FireTrap.new()
		t3.setup(px, by, is_up, fi * 1.0)
		_add_trap(root, t3)
		fi += 1
	for m in _raw_marks("arrow_trap"):
		var px := float(m.x) * OLD_PX + 4.0
		var fy := _surface_below(root, int(px / TILE), 6, px)
		if fy < 0.0:
			fy = float(m.y) * OLD_PX + 8.0
		var mid := float(_map_width_px()) * 0.5
		var t4 := PixelTraps.ArrowTrap.new()
		t4.setup(px, fy, 1.0 if px < mid else -1.0, 1.5)
		_add_trap(root, t4)


func _map_width_px() -> int:
	var f := FileAccess.open(map_json, FileAccess.READ)
	if f == null:
		return 2944
	var j = JSON.parse_string(f.get_as_text())
	return int(j.get("mapWidth", 184)) * TILE if j is Dictionary else 2944


func _build_blood(root: Node2D) -> void:
	for m in _raw_marks("blood_drip"):
		var px := float(m.x) * OLD_PX + 4.0
		var cy := _ceiling_bottom(root, int(px / TILE))
		var stain := ColorRect.new()
		stain.color = Color("7a0d16")
		stain.position = Vector2(px - 5.0, cy - 2.0)
		stain.size = Vector2(10.0, 5.0)
		root.add_child(stain)
		var drop := ColorRect.new()
		drop.color = Color("b0121e")
		drop.position = Vector2(px - 1.0, cy)
		drop.size = Vector2(2.0, 2.0)
		root.add_child(drop)
		var tw := drop.create_tween().set_loops()
		tw.tween_interval(randf() * 1.2)
		tw.tween_property(drop, "size:y", 9.0, 0.7)
		tw.tween_property(drop, "modulate:a", 0.0, 0.12)
		tw.tween_property(drop, "size:y", 2.0, 0.01)
		tw.tween_property(drop, "modulate:a", 1.0, 0.01)
		var p := CPUParticles2D.new()
		p.position = Vector2(px, cy + 8.0)
		p.amount = 2
		p.lifetime = 1.0
		p.explosiveness = 0.0
		p.randomness = 0.4
		p.direction = Vector2(0, 1)
		p.spread = 2.0
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 4.0
		p.gravity = Vector2(0, 420)
		p.scale_amount_min = 1.4
		p.scale_amount_max = 2.4
		p.color = Color("c0121f")
		p.z_index = 2
		root.add_child(p)


func lever_hit() -> void:
	if _lever_on:
		return
	_lever_on = true
	if _tuas_off != null:
		_tuas_off.visible = false
	if _tuas_on != null:
		_tuas_on.visible = true
	AudioManager.play_sfx_named("boom")
	shake_camera(3.0, 0.8)
	if _player != null:
		_player.lever_damage()
	_open_gate()


func _open_gate() -> void:
	_dialog_active = true
	_player.controls_enabled = false
	if _touch_ui:
		_touch_ui.suspended = true
	await get_tree().create_timer(0.5).timeout
	await _open_dialog("Shyrn", ["..."], ["dots"])
	var tw := create_tween()
	tw.tween_property(_cam, "position", _cam1 - _player.global_position, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(0.4).timeout
	if _gate != null:
		AudioManager.start_quake(0.3)
		shake_camera(3.0, GATE_TIME)
		var g := create_tween()
		g.tween_property(_gate, "position:y", _gate_rect.size.y + 12.0, GATE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await g.finished
		AudioManager.stop_quake(0.6)
		_gate.collision_enabled = false
		_gate.visible = false
	await get_tree().create_timer(0.6).timeout
	var back := create_tween()
	back.tween_property(_cam, "position", Vector2(0.0, -20.0), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	_dialog_active = false
	if _touch_ui:
		_touch_ui.suspended = false
	if not _leaving and not _dying and _player.hp > 0:
		_player.controls_enabled = true
