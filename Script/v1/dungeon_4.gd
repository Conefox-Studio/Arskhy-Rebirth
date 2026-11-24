extends "res://scripts/level.gd"

const VaseScript = preload("res://scripts/vase.gd")
const InputIcons = preload("res://scripts/input_icons.gd")
const ChestUI = preload("res://scripts/chest_ui.gd")
const Debris = preload("res://scripts/debris.gd")
const CHAIN_LOOP := "res://assets/audio/ambient/chain_loop.wav"
const ACID_SHADER := "res://shaders/acid_wave.gdshader"
const PROMPT_FONT := "res://assets/fonts/pixelify_sans_bold.ttf"

const CHEST_TEX := "res://assets/maps/dungeon_4/chest.png"
const CHEST_POS := Vector2(328.0, 792.0)
const CHEST_FRAME_PITCH := 96
const CHEST_FRAME_W := 64
const CHEST_FRAME_H := 96
const CHEST_REACH_X := 34.0
const CHEST_REACH_Y := 44.0
const CHEST_FRAME_TIME := 0.09
const CHEST_POTIONS := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]
static var chest_slots: Array = []
static var chest_ready := false

const LIFT_TIME := 12.0
const CAGE_HITS := 5
const CAGE_DAMAGE := 3

var _chain: TileMapLayer
var _chain_t := 0.0

var _chest_spr: Sprite2D
var _chest_prompt: Node2D
var _chest_ui
var _chest_busy := false
var _prompt_t := 0.0
var _prompt_anchor := Vector2.ZERO

var _cam_marks: Array = []
var _trigger_x := -1.0
var _intro_busy := false
var _story_busy := false

var _tuas_on: TileMapLayer
var _tuas_off: TileMapLayer
var _lever_on := false
var _lift: TileMapLayer
var _lift_k := 0.0
var _lift_d := Vector2.ZERO
var _lift_rect := Rect2()

var _cage: TileMapLayer
var _cage_chain: TileMapLayer
var _cage_rect := Rect2()
var _cage_all := Rect2()
var _cage_pivot := Vector2.ZERO
var _cage_state := 0
var _cage_hits := 0
var _swing_t := -1.0
var _swing_dir := 1.0
var _cage_hit_body: StaticBody2D
var _cage_walls: StaticBody2D


func _configure() -> void:
	map_json = "res://maps/dungeon_4/map.json"
	tileset_path = "res://maps/dungeon_4/tileset.tres"
	location_name = "DUNGEON IV"
	show_location_name = false
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan"]
	behind_player_layers = ["tuas_on", "tuas_off", "rantai_diam"]
	cam_limit_top = 0
	cam_limit_bottom = 1088
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
	void_death_y = 1150.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


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
			var floor_y := _surface_below(map, int(t.x), int(t.y), sx)
			if floor_y >= 0.0:
				sy = floor_y - 1.0
			_player.position = Vector2(sx, sy)
			_spawn = _player.position
			return


func _surface_below(map: Node, cx: int, cy: int, px: float) -> float:
	var layer := _layer_named(map, "jalan")
	var tex := load("res://maps/dungeon_4/tileset.png") as Texture2D
	if layer == null or tex == null:
		return -1.0
	var img := tex.get_image()
	var lx := clampi(int(px) - cx * TILE, 0, TILE - 1)
	for y in range(cy, cy + 60):
		var c := Vector2i(cx, y)
		if layer.get_cell_source_id(c) == -1:
			continue
		var ac := layer.get_cell_atlas_coords(c)
		for yy in TILE:
			if img.get_pixel(ac.x * TILE + lx, ac.y * TILE + yy).a > 0.04:
				return float(y * TILE + yy)
		return float(y * TILE)
	return -1.0


func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	super._ready()
	AudioManager.start_loop("chain", CHAIN_LOOP, -13.0)
	_calc_lift_dx()
	_chest_ui = ChestUI.new()
	add_child(_chest_ui)
	_chest_ui.closed.connect(_on_chest_closed)
	_intro()


func _exit_tree() -> void:
	AudioManager.stop_loop("chain")
	super._exit_tree()


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _marks(root: Node, n: String) -> Array:
	var out: Array = []
	var l := _layer_named(root, n)
	if l != null:
		for c in l.get_used_cells():
			out.append(l.to_global(l.map_to_local(c)))
		l.visible = false
	return out


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_chain = _layer_named(root, "rantai")
	_cam_marks = _marks(root, "camera_1") + _marks(root, "camera_2")
	var trig := _marks(root, "dialog_trigger")
	if not trig.is_empty():
		_trigger_x = (trig[0] as Vector2).x
	_tuas_on = _layer_named(root, "tuas_on")
	_tuas_off = _layer_named(root, "tuas_off")
	if _tuas_on != null:
		_tuas_on.visible = false
	var acid := _layer_named(root, "asam")
	if acid != null:
		var m := ShaderMaterial.new()
		m.shader = load(ACID_SHADER)
		acid.material = m
	_lift = _layer_named(root, "lift")
	_make_moving(_lift)
	_setup_lift()
	_build_lever(root)
	_build_cage(root)
	_build_vases(root)
	_build_chest(root)


func _build_vases(root: Node2D) -> void:
	var f := FileAccess.open("res://maps/dungeon_4/vases.json", FileAccess.READ)
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


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	_tick_chest(delta)
	_tick_lift(delta)
	_tick_cage(delta)
	if _chain != null:
		_chain_t += delta
		_chain.position.y = fmod(_chain_t * 12.0, 8.0)
	if _player.global_position.x < 36.0 and _player.global_position.y > 700.0 and not _story_busy and not _intro_busy:
		_goto("res://scenes/dungeon_5.tscn", "")
		return
	if not _story_busy and not _intro_busy and _trigger_x >= 0.0 and not GameState.seen_dialogs.has("d4_story") \
			and _player.global_position.x <= _trigger_x and _player.is_on_floor() and _player.hp > 0:
		_story()


func _intro() -> void:
	if _player == null or _cam == null or _cam_marks.size() < 2 or GameState.seen_dialogs.has("d4_intro"):
		return
	GameState.seen_dialogs["d4_intro"] = true
	_intro_busy = true
	_player.controls_enabled = false
	_cam.position = (_cam_marks[0] as Vector2) - _player.global_position
	await get_tree().create_timer(1.6).timeout
	var t := create_tween()
	t.tween_property(_cam, "position", (_cam_marks[1] as Vector2) - _player.global_position, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	await get_tree().create_timer(0.8).timeout
	var back := create_tween()
	back.tween_property(_cam, "position", Vector2(0.0, -20.0), 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await back.finished
	_intro_busy = false
	if not _leaving and not _dying and _player.hp > 0 and not _story_busy:
		_player.controls_enabled = true


func _say(speaker: String, lines: Array, emotes: Array = []) -> void:
	await _open_dialog(speaker, lines, emotes)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _story() -> void:
	_story_busy = true
	GameState.seen_dialogs["d4_story"] = true
	_dialog_active = true
	_player.controls_enabled = false
	if _touch_ui:
		_touch_ui.suspended = true
	await _wait(0.4)
	_thunder_fx(6.0)
	_emote("exclaim", 1.6)
	await _wait(1.7)
	await _say("???", ["T... Tolong, jangan ikat aku...", "Aku tidak bisa mati. Aku sudah terkutuk hidup abadi selama hampir 10 ribu tahun sekarang... umurku 9,999 tahun."], ["question", "shock"])
	AudioManager.play_sfx_named("hit_body")
	_thunder_fx(5.0)
	_emote("exclaim", 1.4)
	await _wait(1.5)
	await _say("???", ["Arghhh... s... sakit lenganku! Kamu mau apa denganku, Shadow!"], ["shock"])
	AudioManager.play_sfx_named("roar")
	shake_camera(7.0, 2.0)
	_emote("shock", 2.0)
	await _wait(2.2)
	await _say("Shadow", ["Kutukanmu akan berakhir di 17 November ini...", "Sekarang... aku bisa membunuhmu dan membelah tubuhmu yang tua ini menjadi dua bagian."], ["sweat", "shock"])
	AudioManager.play_sfx_named("swing")
	_emote("exclaim", 1.0)
	await _wait(0.12)
	AudioManager.play_sfx_named("hit_body")
	shake_camera(4.0, 0.4)
	await _say("???", ["Asc..."], ["shock"])
	AudioManager.stop_music(0.2)
	AudioManager.stop_ambient(0.2)
	AudioManager.stop_loop("chain")
	_emote("dots", 2.2)
	await _wait(2.4)
	_thunder_fx(6.0)
	_emote("exclaim", 1.6)
	await _wait(1.8)
	AudioManager.play_music(music_path, 2.5)
	AudioManager.play_ambient(ambient_path, 2.5, ambient_db)
	AudioManager.start_loop("chain", CHAIN_LOOP, -13.0)
	await _say("Shyrn", ["Apa-apaan suara tadi?..."], ["question"])
	AudioManager.start_quake(0.4)
	shake_camera(6.0, 5.0)
	_emote("exclaim", 2.2)
	for i in 5:
		_dust_burst()
		if i == 2:
			_emote("sweat", 2.0)
		await _wait(1.0)
	AudioManager.stop_quake(0.8)
	await _say("Shyrn", ["..."], ["dots"])
	_dialog_active = false
	if _touch_ui:
		_touch_ui.suspended = false
	_story_busy = false
	if not _leaving and not _dying and _player.hp > 0:
		_player.controls_enabled = true


func _thunder_fx(power: float) -> void:
	AudioManager.play_sfx_named("thunder")
	shake_camera(power, 1.1)
	_dust_burst()
	if GameSettings.flashes:
		var cl := CanvasLayer.new()
		cl.layer = 11
		add_child(cl)
		var r := ColorRect.new()
		r.color = Color(1, 1, 1, 0)
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cl.add_child(r)
		var tw := create_tween()
		tw.tween_property(r, "color:a", 0.85, 0.04)
		tw.tween_property(r, "color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(cl.queue_free)


func _dust_burst() -> void:
	if _cam == null:
		return
	var p := CPUParticles2D.new()
	p.position = _cam.get_screen_center_position() + Vector2(0.0, -150.0)
	p.amount = 60
	p.lifetime = 2.0
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(320.0, 8.0)
	p.direction = Vector2(0.0, 1.0)
	p.spread = 25.0
	p.gravity = Vector2(0.0, 170.0)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.6
	p.color = Color(0.72, 0.69, 0.80, 0.85)
	p.z_index = 20
	add_child(p)
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


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


func _setup_lift() -> void:
	if _lift == null:
		return
	var art := _cluster_art(_lift, _lift.get_used_cells())
	if not art.is_empty():
		_lift_rect = art[1]


func _calc_lift_dx() -> void:
	if _lift == null or _cam_marks.size() < 2 or _lift_rect.size == Vector2.ZERO:
		return
	_lift_d = (_cam_marks[1] as Vector2) - _lift_rect.get_center()


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
	if _hud != null:
		_hud.show_notice("The lift starts moving...", Color("f6d776"), 2.4)


func _tick_lift(delta: float) -> void:
	if not _lever_on or _lift == null or _lift_k >= 1.0:
		return
	_lift_k = minf(1.0, _lift_k + delta / LIFT_TIME)
	var e := _lift_k * _lift_k * (3.0 - 2.0 * _lift_k)
	var np := _lift_d * e
	var dp := np - _lift.position
	var carry: bool = _player.is_on_floor() and _carry_needed() and _lift.get_cell_source_id(_lift.local_to_map(_lift.to_local(_player.global_position + Vector2(0.0, 2.0)))) != -1
	_lift.position = np
	if carry:
		_player.position += dp


func _build_cage(root: Node2D) -> void:
	_cage = _layer_named(root, "kurung")
	_cage_chain = _layer_named(root, "rantai_diam")
	if _cage == null or _cage_chain == null:
		return
	var a := _cluster_art(_cage, _cage.get_used_cells())
	var b := _cluster_art(_cage_chain, _cage_chain.get_used_cells())
	if a.is_empty() or b.is_empty():
		return
	_cage_rect = a[1]
	var chain_rect: Rect2 = b[1]
	_cage_all = _cage_rect.merge(chain_rect)
	_cage_pivot = Vector2(chain_rect.get_center().x, chain_rect.position.y)
	_cage_hit_body = _make_hit_body(_cage_all)
	root.add_child(_cage_hit_body)


func _make_hit_body(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = r.get_center()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	body.add_child(cs)
	body.set_script(load("res://scripts/cage_body.gd"))
	body.set("owner_level", self)
	return body


func _set_swing(a: float) -> void:
	for l in [_cage_chain, _cage]:
		var layer := l as TileMapLayer
		layer.rotation = a
		layer.position = _cage_pivot - _cage_pivot.rotated(a)


func _tick_cage(delta: float) -> void:
	if _cage == null or _cage_state != 0:
		return
	var pr := Rect2(_player.global_position + Vector2(-6.0, -36.0), Vector2(12.0, 36.0))
	if (_swing_t < 0.0 or _swing_t > 1.2) and pr.intersects(_cage_rect.grow(2.0)):
		_swing_t = 0.0
		_swing_dir = 1.0 if _player.global_position.x < _cage_rect.get_center().x else -1.0
		AudioManager.play_sfx_named("swing")
	if _swing_t >= 0.0:
		_swing_t += delta
		_set_swing(_swing_dir * 0.2 * exp(-_swing_t * 0.8) * sin(_swing_t * 3.4))
		if _swing_t > 6.0:
			_swing_t = -1.0
			_set_swing(0.0)


func cage_hit() -> void:
	if _cage_state == 0:
		_break_chain()
	elif _cage_state == 2:
		_cage_hits += 1
		AudioManager.play_sfx_named("hit_body")
		shake_camera(1.5, 0.15)
		var tw := create_tween()
		tw.tween_property(_cage, "position:x", _cage.position.x + 1.5, 0.03)
		tw.tween_property(_cage, "position:x", _cage.position.x - 1.5, 0.05)
		tw.tween_property(_cage, "position:x", _cage.position.x, 0.03)
		if _hud != null and _cage_hits < CAGE_HITS:
			_hud.show_notice("Cage %d / %d" % [_cage_hits, CAGE_HITS], Color("c9c2e8"), 0.8)
		if _cage_hits >= CAGE_HITS:
			_destroy_cage()


func _break_chain() -> void:
	_cage_state = 1
	if _cage_hit_body != null:
		_cage_hit_body.queue_free()
		_cage_hit_body = null
	var chain_art := _cluster_art(_cage_chain, _cage_chain.get_used_cells())
	if not chain_art.is_empty():
		Debris.burst(self, chain_art[0], chain_art[1], 10, 0.8)
	_cage_chain.visible = false
	AudioManager.play_sfx_named("crate_break")
	_player.controls_enabled = false
	var px: float = _player.global_position.x
	_cage.rotation = 0.0
	_cage.position = Vector2.ZERO
	var ground := _ground_y_at(px)
	var dx := px - _cage_rect.get_center().x
	var dy := ground - _cage_rect.end.y
	var tw := create_tween()
	tw.tween_property(_cage, "position", Vector2(dx, dy), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	var waited := 0.0
	while not _player.is_on_floor() and waited < 1.5:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	var r := Rect2(_cage_rect.position + Vector2(dx, dy), _cage_rect.size)
	_cage_walls = StaticBody2D.new()
	_cage_walls.collision_layer = 1
	_cage_walls.collision_mask = 0
	add_child(_cage_walls)
	for part in [Rect2(r.position.x + 3.0, r.position.y, 4.0, r.size.y), Rect2(r.end.x - 7.0, r.position.y, 4.0, r.size.y), Rect2(r.position.x + 3.0, r.position.y, r.size.x - 6.0, 14.0)]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = (part as Rect2).size
		cs.shape = sh
		cs.position = (part as Rect2).get_center()
		_cage_walls.add_child(cs)
	_cage_hit_body = _make_hit_body(r)
	add_child(_cage_hit_body)
	_cage_state = 2
	_cage_hits = 0
	AudioManager.play_sfx_named("boom")
	shake_camera(4.0, 0.4)
	_player.take_damage(CAGE_DAMAGE)
	if _hud != null:
		_hud.show_notice("Trapped! Hit the cage %d times to break out." % CAGE_HITS, Color("ff9a8a"), 3.0)
	if not _leaving and not _dying and _player.hp > 0 and not _story_busy:
		_player.controls_enabled = true


func _destroy_cage() -> void:
	_cage_state = 3
	var art := _cluster_art(_cage, _cage.get_used_cells())
	if not art.is_empty():
		var rr: Rect2 = art[1]
		rr.position += _cage.position
		Debris.burst(self, art[0], rr, 22, 1.2)
	_cage.visible = false
	AudioManager.play_sfx_named("crate_break")
	shake_camera(3.0, 0.3)
	if _cage_walls != null:
		_cage_walls.queue_free()
		_cage_walls = null
	if _cage_hit_body != null:
		_cage_hit_body.queue_free()
		_cage_hit_body = null


func _chest_frame(i: int) -> void:
	if _chest_spr != null:
		_chest_spr.region_rect = Rect2(i * CHEST_FRAME_PITCH, 0, CHEST_FRAME_W, CHEST_FRAME_H)


func _build_chest(root: Node2D) -> void:
	var old := _layer_named(root, "chest")
	if old != null:
		old.visible = false
	var tex := load(CHEST_TEX) as Texture2D
	if tex == null:
		return
	_chest_spr = Sprite2D.new()
	_chest_spr.texture = tex
	_chest_spr.region_enabled = true
	_chest_spr.centered = false
	_chest_spr.scale = Vector2(0.5, 0.5)
	_chest_spr.position = CHEST_POS + Vector2(-CHEST_FRAME_W * 0.25, -80.0 * 0.5)
	_chest_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(_chest_spr)
	_objects.append(_chest_spr)
	_chest_frame(0)

	_prompt_anchor = CHEST_POS + Vector2(0.0, -48.0)
	var pl := _layer_named(root, "prompt")
	if pl != null:
		var cells := pl.get_used_cells()
		if not cells.is_empty():
			_prompt_anchor = pl.to_global(pl.map_to_local(cells[0]))
		pl.visible = false

	_chest_prompt = Node2D.new()
	_chest_prompt.z_index = 20
	_chest_prompt.visible = false
	var key := Sprite2D.new()
	key.texture = InputIcons.key_texture("e")
	key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	key.position = Vector2(-13.0, 0.0)
	_chest_prompt.add_child(key)
	var lb := Label.new()
	lb.text = "Open"
	lb.add_theme_font_size_override("font_size", 8)
	lb.add_theme_color_override("font_color", Color("f6e7b0"))
	lb.add_theme_color_override("font_outline_color", Color("1d1530"))
	lb.add_theme_constant_override("outline_size", 3)
	var f := load(PROMPT_FONT) as Font
	if f != null:
		lb.add_theme_font_override("font", f)
	lb.position = Vector2(-3.0, -7.0)
	_chest_prompt.add_child(lb)
	root.add_child(_chest_prompt)


func _chest_near() -> bool:
	if _chest_busy or _story_busy or _intro_busy or _cage_state == 1 or _player == null or not is_instance_valid(_player) or _chest_spr == null:
		return false
	if not _player.controls_enabled or _player.hp <= 0:
		return false
	var d: Vector2 = _player.global_position - CHEST_POS
	return absf(d.x) <= CHEST_REACH_X and absf(d.y) <= CHEST_REACH_Y


func _tick_chest(delta: float) -> void:
	if _chest_spr == null or _player == null:
		return
	var near := _chest_near()
	_player.magic_blocked = near
	if _chest_prompt != null:
		_chest_prompt.visible = near
		if near:
			_prompt_t += delta
			_chest_prompt.position = _prompt_anchor + Vector2(0.0, sin(_prompt_t * 4.0) * 1.2)
	if near and Input.is_action_just_pressed("interact"):
		_open_chest()


func _init_chest_slots() -> void:
	if chest_ready:
		return
	chest_ready = true
	chest_slots = []
	var pool: Array = CHEST_POTIONS.duplicate()
	pool.shuffle()
	for i in 3:
		chest_slots.append({"kind": "item", "item": Inventory.potion_item(int(pool[i]), randi_range(1, 2))})
	for i in 4:
		if randf() < 0.5:
			chest_slots.append({"kind": "coin", "n": randi_range(8, 30)})
		else:
			chest_slots.append({"kind": "gem", "n": randi_range(1, 3), "frame": randi() % 4})
	for i in 3:
		chest_slots.append(null)


func _open_chest() -> void:
	if _chest_busy:
		return
	_chest_busy = true
	_player.magic_blocked = false
	_player.controls_enabled = false
	if _chest_prompt != null:
		_chest_prompt.visible = false
	_init_chest_slots()
	AudioManager.play_ui("select")
	AudioManager.play_sfx_named("m_charm")
	var tw := create_tween()
	for i in range(1, 4):
		tw.tween_callback(_chest_frame.bind(i))
		tw.tween_interval(CHEST_FRAME_TIME)
	await tw.finished
	if _inv:
		_inv.enabled = false
	_chest_ui.open(chest_slots)


func _on_chest_closed() -> void:
	if _inv:
		_inv.enabled = true
	var tw := create_tween()
	for i in [2, 1, 0]:
		tw.tween_callback(_chest_frame.bind(i))
		tw.tween_interval(CHEST_FRAME_TIME)
	await tw.finished
	_chest_busy = false
	if not _leaving and not _dying and _player != null and _player.hp > 0 and not _story_busy and not _intro_busy:
		_player.controls_enabled = true
