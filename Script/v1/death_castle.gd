extends "res://scripts/level.gd"

const MAP_DIR := "res://maps/death_castle/"
const InputIcons = preload("res://scripts/input_icons.gd")
const PROMPT_FONT := "res://assets/fonts/pixelify_sans_bold.ttf"
const ENEMY_NUMS := [1, 2, 3, 8]
const TORCH_X := [190.0, 400.0, 610.0]
const TORCH_Y := 132.0

var _front: TileMapLayer
var _prompt: Node2D
var _prompt_label: Label
var _prompt_t := 0.0
var _graves: Array = []
var _busy := false
var _torches: Array = []


func _configure() -> void:
	map_json = MAP_DIR + "map.json"
	tileset_path = MAP_DIR + "tileset.tres"
	location_name = "DEATH CASTLE"
	show_location_name = true
	prev_scene = ""
	next_scene = "res://scenes/death_castle_a.tscn"
	music_path = "res://assets/audio/music/death_castle.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan"]
	behind_player_layers = ["batu_nisan", "latar", "tembok_copy"]
	cam_limit_top = 0
	cam_limit_bottom = 384
	enemies_enabled = true
	enemy_kinds = ["black_knight_c"]
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
	kill_layers = []
	void_death_y = 700.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	super._ready()
	_player.stun_cap = 1.0


func _build_enemies() -> void:
	var total: int = int(ENEMY_NUMS[clampi(GameState.difficulty, 0, ENEMY_NUMS.size() - 1)])
	var x_from := maxf(_ground_min_x + 60.0, _player.position.x + 260.0)
	var x_to := _ground_max_x - 60.0
	if x_to <= x_from:
		return
	var gfn := Callable(self, "_ground_y_at")
	for i in total:
		var x := x_from + (x_to - x_from) * (float(i) + randf_range(0.15, 0.85)) / float(total)
		var e: StaticBody2D = EnemyScript.new()
		e.free_float = tile_collision
		var found := false
		for off in range(0, 240, 8):
			for sgn in [1, -1]:
				var xx := x + float(off * sgn)
				if _ground_pts.has(int(xx)) and _ground_pts.has(int(xx) - 14) and _ground_pts.has(int(xx) + 14):
					x = xx
					found = true
					break
			if found:
				break
		if not found:
			e.free()
			continue
		e.setup("black_knight_c", Vector2(x, _ground_y_at(x)), _player, gfn, _ground_min_x + 20.0, _ground_max_x - 20.0)
		add_child(e)


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_front = _layer_named(root, "tembok_front")
	if _front != null:
		_front.z_index = 50
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("burn")
	sf.set_animation_speed("burn", 8.0)
	sf.set_animation_loop("burn", true)
	for i in range(1, 5):
		sf.add_frame("burn", load("res://assets/props/torch_%d.png" % i))
	var glow_tex := GradientTexture2D.new()
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 128
	glow_tex.height = 128
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1.0, 0.62, 0.2, 0.55), Color(1.0, 0.45, 0.1, 0.0)])
	gr.offsets = PackedFloat32Array([0.0, 1.0])
	glow_tex.gradient = gr
	for tx in TORCH_X:
		var glow := Sprite2D.new()
		glow.texture = glow_tex
		glow.position = Vector2(tx, TORCH_Y)
		glow.scale = Vector2(2.6, 2.6)
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = mat
		glow.z_index = 3
		root.add_child(glow)
		var tw := glow.create_tween().set_loops()
		tw.tween_property(glow, "modulate:a", 0.65, 0.35 + randf() * 0.2)
		tw.tween_property(glow, "modulate:a", 1.0, 0.3 + randf() * 0.2)
		var torch := AnimatedSprite2D.new()
		torch.sprite_frames = sf
		torch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		torch.scale = Vector2(2.0, 2.0)
		torch.position = Vector2(tx, TORCH_Y)
		torch.z_index = 4
		root.add_child(torch)
		_torches.append(torch.position)
		torch.play("burn")
		torch.frame = randi() % 4
	var nl := _layer_named(root, "batu_nisan")
	if nl != null:
		var cells: Array = nl.get_used_cells()
		var left: Array = []
		var right: Array = []
		for c in cells:
			if c.x < 26:
				left.append(c)
			else:
				right.append(c)
		for g in [[left, false], [right, true]]:
			var arr: Array = g[0]
			if arr.is_empty():
				continue
			var art := _cluster_art(nl, arr)
			if not art.is_empty():
				var r: Rect2 = art[1]
				_graves.append({"pos": r.get_center(), "hollow": bool(g[1])})
	_prompt = Node2D.new()
	_prompt.z_index = 100
	_prompt.visible = false
	var key := Sprite2D.new()
	key.texture = InputIcons.key_texture("e")
	key.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	key.position = Vector2(-16.0, 0.0)
	_prompt.add_child(key)
	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 8)
	_prompt_label.add_theme_color_override("font_color", Color("f6e7b0"))
	_prompt_label.add_theme_color_override("font_outline_color", Color("1d1530"))
	_prompt_label.add_theme_constant_override("outline_size", 3)
	var f := load(PROMPT_FONT) as Font
	if f != null:
		_prompt_label.add_theme_font_override("font", f)
	_prompt_label.position = Vector2(-6.0, -7.0)
	_prompt.add_child(_prompt_label)
	_prompt_label.text = "Read"
	root.add_child(_prompt)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	_tick_front()
	_tick_grave(delta)


func _tick_front() -> void:
	if _front == null:
		return
	var hit := false
	for dy in [0.0, -16.0, -38.0]:
		var p := _player.global_position + Vector2(0.0, dy)
		if _front.get_cell_source_id(_front.local_to_map(_front.to_local(p))) != -1:
			hit = true
			break
	_front.modulate.a = lerpf(_front.modulate.a, 0.25 if hit else 1.0, 0.25)


func _tick_grave(delta: float) -> void:
	var target := -1
	if not _busy and _player.hp > 0 and _player.controls_enabled:
		for i in _graves.size():
			var gp: Vector2 = _graves[i].pos
			if absf(_player.global_position.x - gp.x) < 64.0 and absf(_player.global_position.y - gp.y) < 80.0:
				target = i
				break
	_prompt_label.text = "Read"
	_player.magic_blocked = target >= 0
	_prompt.visible = target >= 0
	if target >= 0:
		_prompt_t += delta
		var gp2: Vector2 = _graves[target].pos
		_prompt.position = gp2 + Vector2(0.0, -40.0 + sin(_prompt_t * 4.0) * 1.2)
		if Input.is_action_just_pressed("interact"):
			_read_grave(target)


func _read_grave(i: int) -> void:
	_busy = true
	_dialog_active = true
	_player.controls_enabled = false
	if _graves[i].hollow:
		await _open_dialog("Shyrn", ["Wah bolong, dan kebetulan ada mayatnya di sana ngeri..."], ["shock"])
	else:
		await _open_dialog("Shyrn", ["Ini hanya batu nisan peninggalan zaman dulu sebelum aku lahir di sini."], ["question"])
	_dialog_active = false
	_busy = false
	if not _leaving and not _dying and _player.hp > 0:
		_player.controls_enabled = true
