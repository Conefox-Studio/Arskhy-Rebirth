extends "res://scripts/topdown_level.gd"

const TdEnemy = preload("res://scripts/td_enemy.gd")
const TdCat = preload("res://scripts/td_cat.gd")
const QuestPanel = preload("res://scripts/quest_panel.gd")
const InputIcons = preload("res://scripts/input_icons.gd")
const MAP_DIR := "res://maps/death_castle_a/"
const PROMPT_FONT := "res://assets/fonts/pixelify_sans_bold.ttf"
const DEATH_CASTLE := "res://scenes/death_castle.tscn"
const CASTLE_B := "res://scenes/death_castle_b.tscn"
const SOLID := ["tembok", "object", "portal"]
const KINDS := ["td_black_knight_a", "td_demon_a", "td_demoness_a", "td_hellhound", "td_minotaur", "td_blood_a"]
const MAX_ENEMIES := [8, 8, 8, 8]
const DMG_MULT := [2, 3, 4, 10]
const GATE_COLS := [[6, 7, 8], [38, 39, 40]]
const K := 2
const BOX_SPEED := 36.0
const CAT_MAX_HP := 100.0
const CAT_REVIVE_COST := 0.05
const CAT_RESPAWN := 600.0
const CAT_BAR_W := 151.0

static var _intro_done := false

var _enemies: Array = []
var _cat
var _front: TileMapLayer
var _prompt: Node2D
var _prompt_label: Label
var _prompt_t := 0.0
var _busy := false
var _reviving := false
var _pending_revive := false
var _respawn_t := 0.0
var _boxes: Array = []
var _vents: Array = []
var _graves: Array = []
var _gate_open := false
var _travel_cd := 0.0
var _glow_tex: GradientTexture2D
var _shadow_tex: GradientTexture2D
var _cat_hp := CAT_MAX_HP
var _cat_dead := false
var _cat_t := 0.0
var _cat_fill: ColorRect
var _quest


func _configure() -> void:
	map_json = MAP_DIR + "map.json"
	tileset_path = MAP_DIR + "tileset.tres"
	location_name = "DEATH CASTLE A"
	show_location_name = true
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/death_castle.mp3"
	tile_collision = true
	ground_layers = []
	behind_player_layers = []
	td_front_layers = ["front_fade"]
	td_solid_layers = SOLID
	td_map_px = Vector2(59.0, 30.0) * TILE * K
	enemies_enabled = false
	wildlife_count = 0
	force_night = true
	lit_night = true
	night_tint = Color(0.40, 0.40, 0.46)
	rain_mode = "never"
	night_eyes = false
	night_fireflies = false
	night_aurora = false
	no_atmosphere = true
	green_motes = false
	ambient_path = "res://assets/audio/ambient/dungeon_ambience.wav"
	ambient_db = -11.0
	no_night_ambient = true
	reverb_sfx = true
	kill_layers = []
	void_death_y = 99999.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


func _td_spawn() -> Vector2:
	return Vector2(1.5, 24.5) * TILE * K


func in_restricted(_p: Vector2) -> bool:
	return false


func nearest_outside(p: Vector2) -> Vector2:
	return p


func _is_solid_cell(c: Vector2i) -> bool:
	for n in SOLID:
		var l := _layer_named(_map_root, String(n))
		if l != null and l.get_cell_source_id(c) != -1:
			return true
	return false


func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	super._ready()
	_player.stun_cap = 1.0
	_cat = TdCat.new()
	_cat.call("setup", self, _player, _player.global_position + Vector2(28.0, 0.0))
	_map_root.add_child(_cat)
	_shadow(_cat, Vector2.ZERO, 22.0, true)
	_quest = QuestPanel.new()
	add_child(_quest)
	_fill_enemies(true)
	_cat_loop()
	if not _intro_done:
		_intro()


func _clusters(l: TileMapLayer) -> Array:
	var rest := {}
	for c in l.get_used_cells():
		rest[c] = true
	var out: Array = []
	while not rest.is_empty():
		var s: Vector2i = rest.keys()[0]
		var stack: Array = [s]
		rest.erase(s)
		var r := Rect2i(s, Vector2i.ONE)
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			r = r.expand(c).expand(c + Vector2i.ONE)
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = c + d
				if rest.has(n):
					rest.erase(n)
					stack.append(n)
		out.append(Rect2(Vector2(r.position) * TILE, Vector2(r.size) * TILE))
	return out


func _shadow(parent: Node, pos: Vector2, w: float, behind := false) -> void:
	if _shadow_tex == null:
		_shadow_tex = GradientTexture2D.new()
		_shadow_tex.fill = GradientTexture2D.FILL_RADIAL
		_shadow_tex.fill_from = Vector2(0.5, 0.5)
		_shadow_tex.fill_to = Vector2(1.0, 0.5)
		_shadow_tex.width = 64
		_shadow_tex.height = 64
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_shadow_tex.gradient = g
	var s := Sprite2D.new()
	s.texture = _shadow_tex
	s.position = pos
	s.scale = Vector2(w / 64.0, w / 64.0 * 0.4)
	s.show_behind_parent = behind
	if not behind:
		s.z_index = 0
	parent.add_child(s)


func _glow(root: Node, pos: Vector2, scl: float, col: Color) -> void:
	if _glow_tex == null:
		_glow_tex = GradientTexture2D.new()
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 1.0])
		_glow_tex.gradient = g
	var s := Sprite2D.new()
	s.texture = _glow_tex
	s.position = pos
	s.scale = Vector2(scl, scl)
	s.modulate = col
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	s.z_index = 3
	root.add_child(s)
	var tw := s.create_tween().set_loops()
	tw.tween_property(s, "modulate:a", col.a * 0.65, 0.35 + randf() * 0.2)
	tw.tween_property(s, "modulate:a", col.a, 0.3 + randf() * 0.2)


func _say(speaker: String, lines: Array, emotes: Array = []) -> void:
	await _open_dialog(speaker, lines, emotes)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _lock_player(on: bool) -> void:
	_busy = on
	_dialog_active = on
	if _player != null:
		_player.controls_enabled = (not on) and _player.hp > 0 and not _leaving and not _dying
	if _touch_ui:
		_touch_ui.suspended = on


func _notice(t: String, c := Color("f6d776")) -> void:
	if _hud != null:
		_hud.show_notice(t, c, 3.0)


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	var sp := _layer_named(root, "player_spawn")
	if sp != null:
		sp.visible = false
	_front = _layer_named(root, "front_fade")
	if _front != null:
		_front.z_index = 4000
	_build_boxes(root)
	_build_vents(root)
	for r in _clusters(_layer_named(root, "torch")):
		_glow(root, r.get_center(), 4.8, Color(1.0, 0.62, 0.2, 0.9))
	var cl := _layer_named(root, "candle")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("burn")
	sf.set_animation_speed("burn", 8.0)
	sf.set_animation_loop("burn", true)
	for i in range(1, 5):
		sf.add_frame("burn", load("res://assets/props/candle_a_%d.png" % i))
	for r in _clusters(cl):
		var pos := Vector2(r.get_center().x, r.end.y - 4.0)
		var cs := AnimatedSprite2D.new()
		cs.sprite_frames = sf
		cs.scale = Vector2(K, K)
		cs.offset = Vector2(0.0, -8.0)
		cs.position = pos
		cs.z_index = 1 + int(pos.y / 8.0)
		cs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(cs)
		cs.play("burn")
		cs.frame = randi() % 4
		_glow(root, pos + Vector2(0.0, -20.0), 2.6, Color(1.0, 0.8, 0.4, 0.8))
	cl.clear()
	for r in _clusters(_layer_named(root, "kuburan")):
		_graves.append(r.get_center())
		_shadow(root, Vector2(r.get_center().x, r.end.y - 1.0), r.size.x * 1.3)
	for r in _clusters(_layer_named(root, "object")):
		_shadow(root, Vector2(r.get_center().x, r.end.y - 1.0), r.size.x * 1.2)
	td_build_grid(root, Rect2())
	_prompt = Node2D.new()
	_prompt.z_index = 4500
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
	root.add_child(_prompt)
	_build_cat_bar()


func _build_boxes(root: Node2D) -> void:
	var la := _layer_named(root, "box_a")
	var lb := _layer_named(root, "box_b")
	var tex := load(MAP_DIR + "tileset.png") as Texture2D
	for r in _clusters(lb):
		var body := StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		body.position = Vector2(r.get_center().x, r.end.y)
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size - Vector2(2.0, 2.0)
		cs.shape = sh
		cs.position = Vector2(0.0, -r.size.y / 2.0)
		body.add_child(cs)
		for l in [la, lb]:
			for c in (l as TileMapLayer).get_used_cells():
				if c.x * TILE < r.position.x or c.x * TILE >= r.end.x:
					continue
				var ac: Vector2i = (l as TileMapLayer).get_cell_atlas_coords(c)
				var sp := Sprite2D.new()
				sp.texture = tex
				sp.region_enabled = true
				sp.region_rect = Rect2(ac.x * TILE, ac.y * TILE, TILE, TILE)
				sp.centered = false
				sp.position = Vector2(c.x * TILE - body.position.x, c.y * TILE - body.position.y)
				sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				body.add_child(sp)
		_shadow(body, Vector2(0.0, -2.0), r.size.x * 1.6, true)
		body.z_index = 1 + int(r.end.y / 8.0)
		root.add_child(body)
		_boxes.append({"body": body, "w": r.size.x, "h": r.size.y})
	la.clear()
	lb.clear()


func _build_vents(root: Node2D) -> void:
	for r in _clusters(_layer_named(root, "vent_area")):
		var p := CPUParticles2D.new()
		p.position = Vector2(r.get_center().x, r.position.y + 12.0)
		p.amount = 14
		p.lifetime = 1.8
		p.direction = Vector2(0.0, -1.0)
		p.spread = 14.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = 28.0
		p.initial_velocity_max = 48.0
		p.scale_amount_min = 4.0
		p.scale_amount_max = 9.0
		p.color = Color(0.78, 0.8, 0.85, 0.55)
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
		p.color_ramp = g
		p.z_index = 60
		root.add_child(p)
		_vents.append({"rect": r, "smoke": p})


func _build_cat_bar() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 50
	add_child(cl)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.position = Vector2(10.0, 10.0)
	bg.size = Vector2(CAT_BAR_W + 2.0, 10.0)
	cl.add_child(bg)
	_cat_fill = ColorRect.new()
	_cat_fill.color = Color("f2c94c")
	_cat_fill.position = Vector2(11.0, 11.0)
	_cat_fill.size = Vector2(CAT_BAR_W, 8.0)
	cl.add_child(_cat_fill)


func _hit_cat(frac: float) -> void:
	_cat_hp = maxf(0.0, _cat_hp - CAT_MAX_HP * frac)
	if _cat_hp <= 0.0:
		_cat_dead = true
		_cat_t = 0.0
		_cat.visible = false
		_notice("The cat collapsed... back in 10 minutes.", Color("ff9a8a"))


func _tick_cat(delta: float) -> void:
	if _cat_dead:
		_cat_t += delta
		_cat_hp = CAT_MAX_HP * clampf(_cat_t / CAT_RESPAWN, 0.0, 1.0)
		if _cat_t >= CAT_RESPAWN:
			_cat_dead = false
			_cat_hp = CAT_MAX_HP
			_cat.global_position = _player.global_position + Vector2(-28.0, 6.0)
			_cat.visible = true
	_cat_fill.size.x = CAT_BAR_W * _cat_hp / CAT_MAX_HP


func _cat_loop() -> void:
	while is_inside_tree() and not _leaving:
		if _cat_dead or _reviving or _busy or _player.hp <= 0:
			await _wait(0.3)
			continue
		var e = _cat.nearest_enemy(_cat.global_position, 110.0)
		if e != null:
			await _cat.fight(e, 5.0)
			continue
		if _cat.global_position.distance_to(_player.global_position) > 72.0:
			await _cat.walk_to(_player.global_position + Vector2(-26.0, 6.0), 2.5, 40.0)
		else:
			await _wait(0.25)


func _intro() -> void:
	_intro_done = true
	_lock_player(true)
	_cat.face(_player.global_position.x - _cat.global_position.x)
	await _wait(0.6)
	await _say("???", ["Hey bolehkah aku bantu soalnya, di sini bahaya banget!"], ["exclaim"])
	await _say("Shyrn", ["Oh boleh, sekarang aku harus ngapain di map ini?"], ["question"])
	await _say("???", ["Ada tuh box, coba kamu dorong dan tutupi uap itu dengan box."], ["idea"])
	_lock_player(false)


func _on_player_died() -> void:
	if _leaving:
		return
	if _cat_dead or _cat == null:
		super._on_player_died()
		return
	if _reviving:
		_pending_revive = true
		return
	_reviving = true
	_dying = true
	_player.controls_enabled = false
	AudioManager.play_sfx_named("library_faint")
	GameState.faints += 1.0
	await _wait(1.0)
	await _cat.walk_fighting(_player.global_position + Vector2(-30.0, 4.0))
	_cat.face(_player.global_position.x - _cat.global_position.x)
	_dialog_active = true
	await _say("???", ["Bertahanlah"], ["exclaim"])
	AudioManager.play_sfx_named("m_charm")
	_player.revive()
	GameState.faints = maxf(0.0, GameState.faints - 1.0)
	_player.call("_play", "idle")
	_hit_cat(CAT_REVIVE_COST)
	_dying = false
	_dialog_active = false
	_player.controls_enabled = true
	if _touch_ui:
		_touch_ui.suspended = false
	_reviving = false
	if _pending_revive or _player.hp <= 0:
		_pending_revive = false
		_on_player_died()


func _random_spawn_point() -> Vector2:
	for _i in 60:
		var p := Vector2(randf_range(40.0, td_map_px.x - 40.0), randf_range(7.0 * TILE * K, td_map_px.y - 24.0))
		if _player.global_position.distance_to(p) < 260.0:
			continue
		var c := Vector2i(int(p.x / TILE), int(p.y / TILE))
		if _is_solid_cell(c) or _is_solid_cell(Vector2i(c.x, c.y - 1)) or _is_solid_cell(Vector2i(c.x + 1, c.y)) or _is_solid_cell(Vector2i(c.x - 1, c.y)):
			continue
		return p
	return Vector2.ZERO


func _fill_enemies(initial := false) -> void:
	_enemies = _enemies.filter(func(e): return e != null and is_instance_valid(e) and not bool(e.get("_dead")))
	var diff := clampi(GameState.difficulty, 0, 3)
	var need: int = int(MAX_ENEMIES[diff]) - _enemies.size()
	for _i in (need if initial else mini(need, 1)):
		var p := _random_spawn_point()
		if p == Vector2.ZERO:
			continue
		var e: CharacterBody2D = TdEnemy.new()
		e.call("setup", KINDS[randi() % KINDS.size()], p, _player, self)
		e.set("dmg_mult", int(DMG_MULT[diff]))
		e.connect("died", func(x): _enemies.erase(x))
		_map_root.add_child(e)
		_shadow(e, Vector2.ZERO, 22.0, true)
		_enemies.append(e)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _player == null:
		return
	_zsort()
	_tick_front()
	_tick_cat(delta)
	_travel_cd = maxf(0.0, _travel_cd - delta)
	_respawn_t += delta
	if _respawn_t >= 8.0:
		_respawn_t = 0.0
		_fill_enemies(false)
	if not _reviving and not _busy:
		_tick_boxes(delta)
		_tick_vents()
		_tick_portals()
		_tick_interact(delta)
	else:
		_prompt.visible = false
		_player.magic_blocked = false


func _zsort() -> void:
	_player.z_index = 1 + int(_player.global_position.y / 8.0)
	if _cat != null:
		_cat.z_index = 1 + int(_cat.global_position.y / 8.0)
	for e in _enemies:
		if e != null and is_instance_valid(e):
			e.z_index = 1 + int((e as Node2D).global_position.y / 8.0)


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


func _box_free(b: Dictionary, x: float) -> bool:
	var body: StaticBody2D = b.body
	var w: float = b.w
	var h: float = b.h
	var r := Rect2(x - w / 2.0, body.position.y - h, w, h)
	if r.position.x < 8.0 or r.end.x > td_map_px.x - 8.0:
		return false
	for cx in range(floori((r.position.x + 1.0) / TILE), floori((r.end.x - 1.0) / TILE) + 1):
		for cy in range(floori((r.position.y + 1.0) / TILE), floori((r.end.y - 1.0) / TILE) + 1):
			if _is_solid_cell(Vector2i(cx, cy)):
				return false
	for o in _boxes:
		if o != b and absf((o.body as StaticBody2D).position.x - x) < w:
			return false
	return true


func _tick_boxes(delta: float) -> void:
	if _player.hp <= 0 or not _player.controls_enabled:
		return
	var ax := Input.get_axis("move_left", "move_right")
	var ay := Input.get_axis("td_up", "move_down")
	if absf(ax) < 0.3 or absf(ay) > absf(ax):
		return
	var pc: Vector2 = _player.td_center()
	for b in _boxes:
		var body: StaticBody2D = b.body
		var dx := body.position.x - pc.x
		if absf(pc.y - (body.position.y - float(b.h) / 2.0)) > float(b.h) / 2.0 + 6.0 or signf(dx) != signf(ax) or absf(dx) > float(b.w) / 2.0 + 10.0:
			continue
		var nx := body.position.x + signf(ax) * BOX_SPEED * delta
		if _box_free(b, nx):
			body.position.x = nx
		break


func _covered(v: Dictionary) -> bool:
	var r: Rect2 = v.rect
	for b in _boxes:
		if absf((b.body as StaticBody2D).position.x - r.get_center().x) <= 6.0:
			return true
	return false


func _tick_vents() -> void:
	var all := true
	var n := 0
	for v in _vents:
		var cov := _covered(v)
		n += 1 if cov else 0
		(v.smoke as CPUParticles2D).emitting = not cov
		all = all and cov
	_quest.set_text("Push the boxes over the 3 steam vents (%d/3)." % n if not _gate_open else "The gates are open. Go through the left or right gate.")
	if all and not _gate_open and not _vents.is_empty():
		_open_gates()


func _open_gates() -> void:
	_gate_open = true
	AudioManager.play_sfx_named("statue_break")
	_notice("The gates are open!", Color("9be8a8"))
	var gate := _layer_named(_map_root, "vent_area")
	if gate != null:
		gate.visible = false
	var wall := _layer_named(_map_root, "tembok")
	var zone := _layer_named(_map_root, "portal_zone")
	for g in GATE_COLS:
		for ox in g:
			for oy in [4, 5]:
				for q in K * K:
					var c := Vector2i(int(ox) * K + q % K, int(oy) * K + q / K)
					wall.erase_cell(c)
					zone.erase_cell(c)
					if _grid != null:
						_grid.set_point_solid(c, false)
						_grid_enemy.set_point_solid(c, false)


func _tick_portals() -> void:
	if _travel_cd > 0.0 or _player.hp <= 0:
		return
	var pc: Vector2 = _player.td_center()
	var c := Vector2i(int(pc.x / TILE), int(pc.y / TILE))
	if c.y > 6 * K - 1:
		return
	if _layer_named(_map_root, "teleport_zone").get_cell_source_id(c) != -1:
		_travel(CASTLE_B)
	elif _gate_open:
		for g in GATE_COLS:
			if c.x / K in g:
				_travel(DEATH_CASTLE)


func _travel(scene: String) -> void:
	if not ResourceLoader.exists(scene):
		_travel_cd = 4.0
		_notice("This way is not available yet.", Color("ff9a8a"))
		return
	_leaving = true
	_player.controls_enabled = false
	if _inv:
		_inv.shutdown()
	GameSettings.arrive_side = ""
	var cl := CanvasLayer.new()
	cl.layer = 200
	add_child(cl)
	var r := ColorRect.new()
	r.color = Color.BLACK
	var vs := get_viewport().get_visible_rect().size
	r.size = Vector2(vs.x, 0.0)
	cl.add_child(r)
	var tw := create_tween()
	tw.tween_property(r, "size:y", vs.y, 0.6)
	await tw.finished
	get_tree().change_scene_to_file(scene)


func _tick_interact(delta: float) -> void:
	var target := ""
	var at := Vector2.ZERO
	var cell := Vector2i.ZERO
	var idx := -1
	if _player.hp > 0 and _player.controls_enabled:
		var pc: Vector2 = _player.td_center()
		for i in _graves.size():
			if pc.distance_to(_graves[i]) < 56.0:
				target = "grave"
				idx = i
				at = (_graves[i] as Vector2) + Vector2(0.0, -34.0)
				break
		if target == "":
			var rub := _layer_named(_map_root, "rubble")
			for c in rub.get_used_cells():
				var cp := Vector2(c.x * TILE + 8.0, c.y * TILE + 8.0)
				if pc.distance_to(cp) < 34.0:
					target = "clear"
					cell = c
					at = cp + Vector2(0.0, -22.0)
					break
	_player.magic_blocked = target != ""
	_prompt.visible = target != ""
	if target == "":
		return
	_prompt_t += delta
	_prompt.position = at + Vector2(0.0, sin(_prompt_t * 4.0) * 1.2)
	_prompt_label.text = "Read" if target == "grave" else "Clear"
	if Input.is_action_just_pressed("interact"):
		if target == "grave":
			_read_grave()
		else:
			_clear_rubble(cell)


func _clear_rubble(start: Vector2i) -> void:
	var rub := _layer_named(_map_root, "rubble")
	var stack: Array = [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if rub.get_cell_source_id(c) == -1:
			continue
		rub.erase_cell(c)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				stack.append(c + Vector2i(dx, dy))
	AudioManager.play_sfx_named("crate_break")


func _read_grave() -> void:
	_lock_player(true)
	await _say("Shyrn", ["...", "Ini hanya kuburan..."], ["dots", "sweat"])
	_lock_player(false)
