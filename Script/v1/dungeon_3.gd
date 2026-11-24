extends "res://scripts/level.gd"

const VaseScript = preload("res://scripts/vase.gd")
const LEVER_MUSIC := "res://assets/audio/music/dungeon/lever_theme.mp3"
const CHAIN_LOOP := "res://assets/audio/ambient/chain_loop.wav"
const ACID_SHADER := "res://shaders/acid_wave.gdshader"
const SPAWN := Vector2(3440.0, 391.0)
const CAM_MARK := Vector2(2896.0, 264.0)
const PLAT_PERIOD := 8.0
const SPIKE_EVERY := 3.0
const SPIKE_UP := 0.25

var _root_d: Node2D
var _tuas_on: TileMapLayer
var _tuas_off: TileMapLayer
var _gate: TileMapLayer
var _chain: TileMapLayer
var _grow: TileMapLayer
var _plats: Array = []
var _lever_on := false
var _plat_k := 0.0
var _plat_t := 0.0
var _chain_t := 0.0
var _spike_t := 0.0
var _spikes_up := false


func _configure() -> void:
	map_json = "res://maps/dungeon_3/map.json"
	tileset_path = "res://maps/dungeon_3/tileset.tres"
	location_name = "DUNGEON III"
	show_location_name = false
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan"]
	player_after_layer = "plat_5"
	behind_player_layers = ["tuas_on", "tuas_off"]
	spawn_override = SPAWN
	cam_limit_top = 0
	cam_limit_bottom = 700
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
	void_death_y = 900.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


func _ready() -> void:
	super._ready()
	AudioManager.start_loop("chain", CHAIN_LOOP, -13.0)
	_intro()


func _exit_tree() -> void:
	AudioManager.stop_loop("chain")
	AudioManager.stop_loop("chain_grow")
	super._exit_tree()


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_root_d = root
	_tuas_on = _layer_named(root, "tuas_on")
	_tuas_off = _layer_named(root, "tuas_off")
	if _tuas_on != null:
		_tuas_on.visible = false
	_gate = _layer_named(root, "porta")
	_make_moving(_gate)
	_chain = _layer_named(root, "rantai")
	_grow = _layer_named(root, "rantai_tumbuh")
	_extend_grow_chain(root)
	_put_behind_world(root)
	var acid := _layer_named(root, "asam")
	if acid != null:
		var m := ShaderMaterial.new()
		m.shader = load(ACID_SHADER)
		acid.material = m
	_collect_plats(root)
	_build_lever(root)
	_build_vases(root)
	if _grow != null:
		_grow.position.y = -700.0


func _layer_x_range(l: TileMapLayer) -> Vector2:
	var lo := 1.0e9
	var hi := -1.0e9
	for c in l.get_used_cells():
		lo = minf(lo, float(c.x * TILE))
		hi = maxf(hi, float(c.x * TILE + TILE))
	return Vector2(lo, hi)


func _collect_plats(root: Node2D) -> void:
	var found: Array = []
	for i in 6:
		var l := _layer_named(root, "plat_%d" % i)
		var d := _layer_named(root, "duri_%d" % i)
		if l == null:
			continue
		_make_moving(l)
		var xr := _layer_x_range(l)
		found.append({"layer": l, "spikes": d, "x0": xr.x, "x1": xr.y, "rects": _spike_rects(d)})
	found.sort_custom(func(a, b): return a.x0 < b.x0)
	for i in found.size():
		var amp := 100.0
		var left_gap: float = (float(found[i].x0) - (float(found[i - 1].x1) if i > 0 else 104.0))
		var right_gap: float = ((float(found[i + 1].x0) if i < found.size() - 1 else 1824.0) - float(found[i].x1))
		amp = minf(amp, left_gap * (0.35 if i > 0 else 0.5))
		amp = minf(amp, right_gap * (0.35 if i < found.size() - 1 else 0.5))
		found[i]["amp"] = clampf(amp, 12.0, 100.0)
		found[i]["phase"] = PI * float(i % 2)
		if found[i].spikes != null:
			(found[i].spikes as TileMapLayer).visible = false
	_plats = found


func _spike_rects(layer: TileMapLayer) -> Array:
	var out: Array = []
	if layer == null or _atlas_img == null:
		return out
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
			out.append(r.grow(-1.0))
	return out


func _build_vases(root: Node2D) -> void:
	var f := FileAccess.open("res://maps/dungeon_3/vases.json", FileAccess.READ)
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


func _intro() -> void:
	if _player == null or _cam == null:
		return
	_player.controls_enabled = false
	await get_tree().create_timer(0.7).timeout
	if _grow != null:
		AudioManager.start_loop("chain_grow", CHAIN_LOOP, -2.0)
		var tw := create_tween()
		tw.tween_property(_grow, "position:y", 0.0, 1.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await tw.finished
		AudioManager.stop_loop("chain_grow")
		_chain_particles()
		shake_camera(2.0, 0.25)
	var rest := Vector2(0.0, -20.0)
	var t1 := create_tween()
	t1.tween_property(_cam, "position", CAM_MARK - _player.global_position, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t1.finished
	await _run_dialog("", ["(Suara kaki melangkah...)"], ["exclaim"])
	var t2 := create_tween()
	t2.tween_property(_cam, "position", rest, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t2.finished
	_player.controls_enabled = true


func _chain_particles() -> void:
	if _grow == null:
		return
	var cols := {}
	for c in _grow.get_used_cells():
		cols[c.x] = maxi(int(cols.get(c.x, -1)), c.y)
	var xs: Array = cols.keys()
	xs.sort()
	var i := 0
	while i < xs.size():
		var j := i
		while j + 1 < xs.size() and int(xs[j + 1]) == int(xs[j]) + 1:
			j += 1
		_chain_dust(float(xs[i]) * TILE, float(int(xs[j]) + 1) * TILE, float(int(cols[xs[i]]) + 1) * TILE - 4.0)
		i = j + 1


func _chain_dust(x0: float, x1: float, y: float) -> void:
	var lo := Vector2(x0, y)
	var hi := Vector2(x1, y)
	var ps := CPUParticles2D.new()
	ps.position = Vector2((lo.x + hi.x) * 0.5, y)
	ps.z_index = 6
	ps.amount = 18
	ps.lifetime = 1.4
	ps.one_shot = true
	ps.explosiveness = 0.15
	ps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ps.emission_rect_extents = Vector2((hi.x - lo.x) * 0.5, 2.0)
	ps.direction = Vector2(0.0, -1.0)
	ps.spread = 60.0
	ps.gravity = Vector2(0.0, 40.0)
	ps.initial_velocity_min = 8.0
	ps.initial_velocity_max = 28.0
	ps.scale_amount_min = 1.0
	ps.scale_amount_max = 2.0
	ps.color = Color(0.78, 0.74, 0.82, 0.9)
	_root_d.add_child(ps)
	ps.emitting = true
	get_tree().create_timer(3.0).timeout.connect(ps.queue_free)


func lever_hit() -> void:
	if _lever_on:
		return
	_lever_on = true
	if _tuas_off != null:
		_tuas_off.visible = false
	if _tuas_on != null:
		_tuas_on.visible = true
	AudioManager.play_sfx_named("boom")
	if _player != null:
		_player.lever_damage()
	shake_camera(5.0, 1.8)
	_open_gate()


func _open_gate() -> void:
	if _gate == null:
		return
	var top := 1.0e9
	var bottom := -1.0e9
	for c in _gate.get_used_cells():
		top = minf(top, float(c.y * TILE))
		bottom = maxf(bottom, float(c.y * TILE + TILE))
	var tw := create_tween()
	tw.tween_property(_gate, "position:y", (bottom - top) + 8.0, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_gate.collision_enabled = false
		_gate.visible = false)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	_tick_chain(delta)
	_tick_plats(delta)
	_tick_spikes(delta)
	if _player.global_position.x < 84.0 and _player.global_position.y > 400.0:
		_goto("res://scenes/dungeon_4.tscn", "")


func _tick_chain(delta: float) -> void:
	if _chain == null:
		return
	_chain_t += delta
	_chain.position.y = fmod(_chain_t * 12.0, 8.0)


func _tick_plats(delta: float) -> void:
	if not _lever_on or _plats.is_empty():
		return
	_plat_k = minf(1.0, _plat_k + delta / 1.6)
	_plat_t += delta * TAU / PLAT_PERIOD
	for p in _plats:
		var l: TileMapLayer = p.layer
		var nx: float = float(p.amp) * _plat_k * sin(_plat_t + float(p.phase))
		var dx := nx - l.position.x
		if absf(dx) < 0.001:
			continue
		var carry: bool = _player.is_on_floor() and _carry_needed() and l.get_cell_source_id(l.local_to_map(l.to_local(_player.global_position + Vector2(0.0, 2.0)))) != -1
		l.position.x = nx
		if p.spikes != null:
			(p.spikes as TileMapLayer).position.x = nx
		if carry:
			_player.position.x += dx


func _tick_spikes(delta: float) -> void:
	_spike_t += delta
	if _spike_t >= SPIKE_EVERY:
		_spike_t -= SPIKE_EVERY
		_spikes_up = true
		AudioManager.play_sfx_named("swing")
		for p in _plats:
			if p.spikes != null:
				(p.spikes as TileMapLayer).visible = true
	elif _spikes_up and _spike_t >= SPIKE_UP:
		_spikes_up = false
		for p in _plats:
			if p.spikes != null:
				(p.spikes as TileMapLayer).visible = false
	if not _spikes_up or not _player.can_be_thorned():
		return
	var pp: Vector2 = _player.global_position
	var body := Rect2(pp.x - 5.0, pp.y - 30.0 * player_size_mult, 10.0, 28.0 * player_size_mult)
	for p in _plats:
		var ox: float = (p.layer as TileMapLayer).position.x
		for s in p.rects:
			var r := Rect2((s as Rect2).position + Vector2(ox, 0.0), (s as Rect2).size)
			if r.intersects(body):
				_player.thorn_hit(1.0 if pp.x >= r.get_center().x else -1.0)
				return


func _extend_grow_chain(root: Node2D) -> void:
	var road := _layer_named(root, "jalan")
	if _grow == null or road == null:
		return
	var bottoms := {}
	for c in _grow.get_used_cells():
		bottoms[c.x] = maxi(int(bottoms.get(c.x, -1)), c.y)
	for xk in bottoms.keys():
		var x: int = int(xk)
		var yb: int = int(bottoms[xk])
		var floor_y := -1
		for y in range(yb + 1, yb + 80):
			if road.get_cell_source_id(Vector2i(x, y)) != -1:
				floor_y = y
				break
		if floor_y < 0 or floor_y - 1 <= yb:
			continue
		var end_c := Vector2i(x, yb)
		var mid_c := Vector2i(x, yb - 1)
		var src := _grow.get_cell_source_id(end_c)
		var end_atlas := _grow.get_cell_atlas_coords(end_c)
		var end_alt := _grow.get_cell_alternative_tile(end_c)
		var mid_src := _grow.get_cell_source_id(mid_c)
		var mid_atlas := _grow.get_cell_atlas_coords(mid_c)
		var mid_alt := _grow.get_cell_alternative_tile(mid_c)
		for y in range(yb, floor_y - 1):
			_grow.set_cell(Vector2i(x, y), mid_src, mid_atlas, mid_alt)
		_grow.set_cell(Vector2i(x, floor_y - 1), src, end_atlas, end_alt)


func _put_behind_world(root: Node2D) -> void:
	var prev := _layer_named(root, "latar")
	if prev == null:
		return
	for n in ["rantai", "jendela", "rantai_tumbuh"]:
		var l := _layer_named(root, n)
		if l == null:
			continue
		root.move_child(l, prev.get_index() + 1)
		prev = l
