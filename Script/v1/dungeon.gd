extends "res://scripts/level.gd"

const VaseScript = preload("res://scripts/vase.gd")
const AMP := 48.0
const PERIOD := 6.5
const RAMP := 1.6
const EXIT_X := 156.0 * 16.0
const EXIT_Y := 26.0 * 16.0
const LEVER_MUSIC := "res://assets/audio/music/dungeon/lever_theme.mp3"
const CHAIN_LOOP := "res://assets/audio/ambient/chain_loop.wav"
const ACID_SHADER := "res://shaders/acid_wave.gdshader"

var _root_d: Node2D
var _mover: TileMapLayer
var _group: Array = []
var _vases: Array = []
var _tuas_on: TileMapLayer
var _tuas_off: TileMapLayer
var _lever_on := false
var _phase := 0.0
var _amp_k := 0.0
var _off_x := 0.0
var _spikes: Array = []


func _configure() -> void:
	map_json = "res://maps/dungeon/map.json"
	tileset_path = "res://maps/dungeon/tileset.tres"
	location_name = "DUNGEON"
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan"]
	player_after_layer = "mover"
	behind_player_layers = ["tuas_on", "tuas_off"]
	spawn_override = Vector2(20.0, 65.0 * 8.0 - 1.0)
	cam_limit_top = 0
	cam_limit_bottom = 860
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
	void_death_y = 960.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


func _ready() -> void:
	super._ready()
	AudioManager.start_loop("chain", CHAIN_LOOP, -13.0)


func _exit_tree() -> void:
	AudioManager.stop_loop("chain")
	super._exit_tree()


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_root_d = root
	_mover = _layer_named(root, "mover")
	for n in ["mover", "duri"]:
		var l := _layer_named(root, n)
		if l != null:
			_group.append(l)
			_make_moving(l)
	_tuas_on = _layer_named(root, "tuas_on")
	_tuas_off = _layer_named(root, "tuas_off")
	if _tuas_on != null:
		_tuas_on.visible = false
	var acid := _layer_named(root, "asam")
	if acid != null:
		var m := ShaderMaterial.new()
		m.shader = load(ACID_SHADER)
		acid.material = m
	_build_spikes(root)
	_build_lever(root)
	_build_vases(root)


func _build_vases(root: Node2D) -> void:
	var f := FileAccess.open("res://maps/dungeon/vases.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Array):
		return
	for v in data:
		var vase: StaticBody2D = VaseScript.new()
		vase.call("setup", Vector2(float(v.x), float(v.y)), self)
		root.add_child(vase)
		var behind := _layer_named(root, "jalan")
		if behind != null:
			root.move_child(vase, behind.get_index())
		if bool(v.mover):
			_vases.append(vase)


func _build_spikes(root: Node2D) -> void:
	var layer := _layer_named(root, "duri")
	if layer == null or _atlas_img == null:
		return
	layer.collision_enabled = false
	for group in _tile_clusters(layer):
		var r := Rect2()
		var first := true
		for c in group:
			var ac := layer.get_cell_atlas_coords(c)
			var lo := Vector2i(1000, 1000)
			var hi := Vector2i(-1, -1)
			for yy in TILE:
				for xx in TILE:
					if _atlas_img.get_pixel(ac.x * TILE + xx, ac.y * TILE + yy).a > 0.5:
						lo = Vector2i(mini(lo.x, xx), mini(lo.y, yy))
						hi = Vector2i(maxi(hi.x, xx), maxi(hi.y, yy))
			if hi.x < 0:
				continue
			var cr := Rect2(Vector2(c.x * TILE + lo.x, c.y * TILE + lo.y), Vector2(hi - lo + Vector2i.ONE))
			r = cr if first else r.merge(cr)
			first = false
		if not first:
			_spikes.append(r.grow(-1.0))


func _build_lever(root: Node2D) -> void:
	var layer := _tuas_off
	if layer == null:
		return
	var r := Rect2()
	var first := true
	for c in layer.get_used_cells():
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


func lever_hit() -> void:
	if _lever_on:
		return
	_lever_on = true
	if _tuas_off != null:
		_tuas_off.visible = false
	if _tuas_on != null:
		_tuas_on.visible = true
	AudioManager.play_sfx_named("boom")
	shake_camera(2.0, 0.3)
	if _player != null:
		_player.lever_damage()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	_tick_movers(delta)
	_check_spikes()
	if _player.global_position.x > EXIT_X and _player.global_position.y < EXIT_Y:
		_goto("res://scenes/dungeon_2.tscn", "")


func _tick_movers(delta: float) -> void:
	if _mover == null or not _lever_on:
		return
	_amp_k = minf(1.0, _amp_k + delta / RAMP)
	_phase += delta * TAU / PERIOD
	var new_off := AMP * _amp_k * sin(_phase)
	var dx := new_off - _off_x
	if absf(dx) < 0.001:
		return
	var carry := _standing_on_mover() and _carry_needed()
	for l in _group:
		(l as TileMapLayer).position.x = new_off
	for v in _vases:
		if is_instance_valid(v) and not (v as StaticBody2D).get("broken"):
			(v as StaticBody2D).position.x = float((v as StaticBody2D).get("base_x")) + new_off
	if carry:
		_player.position.x += dx
	_off_x = new_off


func _standing_on_mover() -> bool:
	if not _player.is_on_floor():
		return false
	for dy in [2.0, 5.0]:
		var c := _mover.local_to_map(_mover.to_local(_player.global_position + Vector2(0.0, dy)))
		if _mover.get_cell_source_id(c) != -1:
			return true
	return false


func _check_spikes() -> void:
	if _spikes.is_empty() or not _player.can_be_thorned():
		return
	var p: Vector2 = _player.global_position
	var body := Rect2(p.x - 5.0, p.y - 30.0 * player_size_mult, 10.0, 28.0 * player_size_mult)
	for s in _spikes:
		var r := Rect2((s as Rect2).position + Vector2(_off_x, 0.0), (s as Rect2).size)
		if r.intersects(body):
			_player.thorn_hit(1.0 if p.x >= r.get_center().x else -1.0)
			return
