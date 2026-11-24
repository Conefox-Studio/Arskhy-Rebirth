extends "res://scripts/level.gd"

const BarrelFace := "res://assets/fx/barrel_face.png"
const LEVER_MUSIC := "res://assets/audio/music/dungeon/lever_theme.mp3"
const CHAIN_LOOP := "res://assets/audio/ambient/chain_loop.wav"
const ACID_SHADER := "res://shaders/acid_wave.gdshader"
const SPAWN := Vector2(340.0, 2055.0)
const CAM2 := Vector2(528.0, 272.0)
const TRIGGER := Rect2(296.0, 280.0, 432.0, 32.0)
const ACID_TOP := 2152.0
const ACID_X0 := 304.0
const ACID_X1 := 720.0
const WALL_RISE := 96.0
const HALF_W := 568.0
const ACID_SPEED := 2.0
const PLAT_PERIOD := 7.0
const TOP_PLAT_REACH := 20.0
const BARREL_EVERY := Vector2(2.6, 4.2)
const BARREL_MAX := 7

var _root_d: Node2D
var _tuas_on: TileMapLayer
var _tuas_off: TileMapLayer
var _acid: TileMapLayer
var _wall: TileMapLayer
var _ji_l: TileMapLayer
var _ji_r: TileMapLayer
var _plats: Array = []
var _lever_on := false
var _plat_k := 0.0
var _plat_t := 0.0
var _acid_rising := false
var _barrels_on := false
var _barrel_t := 2.0
var _barrels: Array = []
var _barrel_tex: ImageTexture
var _closing := false


func _configure() -> void:
	map_json = "res://maps/dungeon_2/map.json"
	tileset_path = "res://maps/dungeon_2/tileset.tres"
	location_name = "DUNGEON II"
	show_location_name = false
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan", "tembok"]
	player_after_layer = "plat_5"
	behind_player_layers = ["tuas_on", "tuas_off"]
	spawn_override = SPAWN
	cam_limit_top = 0
	cam_limit_bottom = 2590
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
	void_death_y = 2900.0
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
	_tuas_on = _layer_named(root, "tuas_on")
	_tuas_off = _layer_named(root, "tuas_off")
	if _tuas_on != null:
		_tuas_on.visible = false
	_acid = _layer_named(root, "asam")
	if _acid != null:
		var m := ShaderMaterial.new()
		m.shader = load(ACID_SHADER)
		_acid.material = m
	_wall = _layer_named(root, "tembok_langsung")
	_make_moving(_wall)
	_ji_l = _layer_named(root, "jalan_i_kiri")
	_ji_r = _layer_named(root, "jalan_i_kanan")
	for l in [_ji_l, _ji_r]:
		if l != null:
			_make_moving(l)
			l.visible = false
			l.collision_enabled = false
	_collect_plats(root)
	_build_lever(root)
	var img := (load(BarrelFace) as Texture2D).get_image()
	img.resize(32, 32, Image.INTERPOLATE_NEAREST)
	round_face(img)
	_barrel_tex = ImageTexture.create_from_image(img)


func _collect_plats(root: Node2D) -> void:
	var found: Array = []
	for i in 6:
		var l := _layer_named(root, "plat_%d" % i)
		if l == null:
			continue
		_make_moving(l)
		var cells := l.get_used_cells()
		if cells.is_empty():
			continue
		var sy := 0.0
		var top_y := 1.0e9
		for c in cells:
			sy += c.y * TILE + 8.0
			top_y = minf(top_y, float(c.y * TILE))
		found.append({"layer": l, "y": sy / cells.size(), "top": top_y})
	found.sort_custom(func(a, b): return a.y < b.y)
	for i in found.size():
		var gap := 1.0e9
		if i > 0:
			gap = minf(gap, float(found[i].y) - float(found[i - 1].y))
		if i < found.size() - 1:
			gap = minf(gap, float(found[i + 1].y) - float(found[i].y))
		found[i]["amp"] = clampf(gap * 0.42, 24.0, 110.0)
		found[i]["phase"] = PI * float(i % 2)
	if not found.is_empty():
		var need: float = float(found[0].top) - (TRIGGER.end.y + TOP_PLAT_REACH)
		found[0]["amp"] = maxf(float(found[0].amp), need)
	_plats = found


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
	if _player != null:
		_player.lever_damage()
	music_override = LEVER_MUSIC
	_cur_music = LEVER_MUSIC
	AudioManager.play_music(LEVER_MUSIC, 0.4)
	_lever_sequence()


func _lever_sequence() -> void:
	shake_camera(4.0, 1.0)
	if _acid != null:
		_acid.position.y -= 1.0
	if _wall != null:
		var tw := create_tween()
		tw.tween_property(_wall, "position:y", -WALL_RISE, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(0.9).timeout
	if _leaving or _dying or _cam == null:
		return
	_player.controls_enabled = false
	var rest := Vector2(0.0, -20.0)
	var to_cam := CAM2 - _player.global_position
	var t1 := create_tween()
	t1.tween_property(_cam, "position", to_cam, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t1.finished
	await _run_dialog("", ["Uhhh... Apakah ini jebakan atau apa ya?"], ["sweat"])
	var t2 := create_tween()
	t2.tween_property(_cam, "position", rest, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t2.finished
	_acid_rising = true
	_barrels_on = true


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	_tick_plats(delta)
	_tick_acid(delta)
	_tick_barrels(delta)
	if not _closing and TRIGGER.intersects(Rect2(_player.global_position.x - 5.0, _player.global_position.y - 30.0, 10.0, 28.0)):
		_close_road()


func _tick_plats(delta: float) -> void:
	if not _lever_on or _plats.is_empty():
		return
	_plat_k = minf(1.0, _plat_k + delta / 1.6)
	_plat_t += delta * TAU / PLAT_PERIOD
	for p in _plats:
		var l: TileMapLayer = p.layer
		var ny: float = float(p.amp) * _plat_k * sin(_plat_t + float(p.phase))
		var dy := ny - l.position.y
		if absf(dy) < 0.001:
			continue
		var carry: bool = _player.is_on_floor() and _carry_needed() and l.get_cell_source_id(l.local_to_map(l.to_local(_player.global_position + Vector2(0.0, 3.0)))) != -1
		l.position.y = ny
		if carry:
			_player.position.y += dy


func _tick_acid(delta: float) -> void:
	if _acid == null:
		return
	if _acid_rising:
		_acid.position.y -= ACID_SPEED * delta
	var top := ACID_TOP + _acid.position.y
	var p: Vector2 = _player.global_position
	if p.x > ACID_X0 and p.x < ACID_X1 and p.y - 2.0 > top:
		_death_cause = "Terlarut asam"
		_player.take_damage(_player.hp)


func _tick_barrels(delta: float) -> void:
	_barrels = _barrels.filter(func(b): return is_instance_valid(b))
	if _acid != null:
		for b in _barrels:
			if (b as Node2D).global_position.y > ACID_TOP + _acid.position.y + 40.0:
				(b as Node2D).queue_free()
	if not _barrels_on or _barrels.size() >= BARREL_MAX:
		return
	_barrel_t -= delta
	if _barrel_t > 0.0:
		return
	_barrel_t = randf_range(BARREL_EVERY.x, BARREL_EVERY.y)
	var cy: float = _cam.get_screen_center_position().y
	var b: CharacterBody2D = BarrelScript.new()
	b.set("fall_limit", 99999.0)
	b.set("wake_dx", 99999.0)
	b.set("wake_dy", 99999.0)
	b.call("setup", _barrel_tex, 15.0, Vector2(randf_range(ACID_X0 + 24.0, ACID_X1 - 24.0), maxf(20.0, cy - 240.0)), _player)
	_root_d.add_child(b)
	_barrels.append(b)


func _shake_roads(t: float) -> void:
	var j := sin(t * 90.0) * 1.2 * (1.0 - t)
	for l in [_ji_l, _ji_r]:
		if l != null:
			l.position.y = j


func _close_road() -> void:
	_closing = true
	_player.controls_enabled = false
	AudioManager.play_sfx_named("statue_break")
	shake_camera(7.0, 1.7)
	for l in [_ji_l, _ji_r]:
		if l != null:
			l.visible = true
	var left_edge := 0.0
	var right_edge := 0.0
	var have_l := false
	var have_r := false
	if _ji_l != null and not _ji_l.get_used_cells().is_empty():
		var mx := -1000000
		for c in _ji_l.get_used_cells():
			mx = maxi(mx, c.x)
		left_edge = float(mx + 1) * TILE
		have_l = true
	if _ji_r != null and not _ji_r.get_used_cells().is_empty():
		var mn := 1000000
		for c in _ji_r.get_used_cells():
			mn = mini(mn, c.x)
		right_edge = float(mn) * TILE
		have_r = true
	var mid := snappedf((left_edge + right_edge) * 0.5, TILE) if (have_l and have_r) else HALF_W
	if _ji_l != null:
		_ji_l.position.x = 0.0
	if _ji_r != null:
		_ji_r.position.x = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	if _ji_l != null:
		tw.tween_property(_ji_l, "position:x", mid - left_edge, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	if _ji_r != null:
		tw.tween_property(_ji_r, "position:x", mid - right_edge, 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	var sh := create_tween()
	sh.tween_method(_shake_roads, 0.0, 1.0, 1.5)
	await tw.finished
	await sh.finished
	for l in [_ji_l, _ji_r]:
		if l != null:
			l.position.y = 0.0
	for l in [_ji_l, _ji_r]:
		if l != null:
			l.collision_enabled = true
	AudioManager.play_sfx_named("boom")
	shake_camera(9.0, 0.7)
	var tf := create_tween()
	tf.tween_property(_fade, "color:a", 1.0, 0.8)
	await tf.finished
	_goto("res://scenes/dungeon_3.tscn", "")
