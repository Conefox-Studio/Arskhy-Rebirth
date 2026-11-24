extends "res://scripts/topdown_level.gd"

const TdEnemy = preload("res://scripts/td_enemy.gd")
const TdCat = preload("res://scripts/td_cat.gd")
const ChestUI = preload("res://scripts/chest_ui.gd")
const ChoiceBox = preload("res://scripts/choice_box.gd")
const QuestPanel = preload("res://scripts/quest_panel.gd")
const InputIcons = preload("res://scripts/input_icons.gd")
const MAP_DIR := "res://maps/library/"
const CHEST_TEX := "res://assets/maps/dungeon_4/chest.png"
const PROMPT_FONT := "res://assets/fonts/pixelify_sans_bold.ttf"
const NEXT_SCENE := "res://scenes/death_castle_a.tscn"
const SOLID := ["pot_bunga", "meja", "bookshelf_copy", "bookshelf", "tembok", "tembok_copy"]
const MAX_ENEMIES := [25, 35, 50, 60]
const KINDS := ["td_black_knight_a", "td_demon_a", "td_demoness_a", "td_hellhound", "td_lava_slime", "td_minotaur", "td_eyeball", "td_blood_a"]
const BOOKS_NEEDED := 15
const FIVE_MIN := 300.0
const STUCK_HOUR := 3600.0

static var books_found: Array = []
static var mission_given := false
static var chest_data := {}

var _meta := {}
var _restricted := Rect2()
var _seat := Vector2.ZERO
var _cat
var _enemies: Array = []
var _front: TileMapLayer
var _books_layer: TileMapLayer
var _book_pos: Array = []
var _chests: Array = []
var _chest_ui
var _chest_open := -1
var _choice
var _quest
var _prompt: Node2D
var _prompt_label: Label
var _prompt_t := 0.0
var _busy := false
var _reviving := false
var _pending_revive := false
var _clock5 := 0.0
var _since_book := 0.0
var _respawn_t := 0.0
var _cam_target: Node2D
var _cam_off := Vector2(0.0, -20.0)


func _configure() -> void:
	map_json = MAP_DIR + "map.json"
	tileset_path = MAP_DIR + "tileset.tres"
	location_name = "LIBRARY"
	show_location_name = false
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_layers = []
	behind_player_layers = []
	td_front_layers = ["bookshelf_front"]
	td_solid_layers = SOLID
	enemies_enabled = false
	wildlife_count = 0
	force_night = true
	lit_night = true
	night_tint = Color(0.80, 0.78, 0.92)
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
	var txt := FileAccess.get_file_as_string(map_json)
	var j = JSON.parse_string(txt)
	if j is Dictionary:
		_meta = j.get("meta", {})
		td_map_px = Vector2(float(j.get("mapWidth", 190)) * TILE, float(j.get("mapHeight", 162)) * TILE)
		var r: Array = _meta.get("restricted", [0, 0, 0, 0])
		_restricted = Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
		var s: Array = _meta.get("cat_seat", [0, 0])
		_seat = Vector2(float(s[0]), float(s[1]))
		_book_pos = _meta.get("books", [])


func in_restricted(p: Vector2) -> bool:
	return _restricted.has_point(p)


func nearest_outside(p: Vector2) -> Vector2:
	var dl := p.x - _restricted.position.x
	var dr := _restricted.end.x - p.x
	var dt := p.y - _restricted.position.y
	var db := _restricted.end.y - p.y
	var m := minf(minf(dl, dr), minf(dt, db))
	if m == dl:
		return Vector2(_restricted.position.x - 40.0, p.y)
	if m == dr:
		return Vector2(_restricted.end.x + 40.0, p.y)
	if m == dt:
		return Vector2(p.x, _restricted.position.y - 40.0)
	return Vector2(p.x, _restricted.end.y + 40.0)


func _is_solid_cell(c: Vector2i) -> bool:
	for n in SOLID:
		var l := _layer_named(_map_root, String(n))
		if l != null and l.get_cell_source_id(c) != -1:
			return true
	return false


func _td_spawn() -> Vector2:
	var base := _seat + Vector2(0.0, 72.0)
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var p := base + Vector2(dx * TILE, dy * TILE)
				var c := _td_cell(p)
				if not _is_solid_cell(c) and not _is_solid_cell(Vector2i(c.x, c.y - 1)):
					return p
	return base


func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	super._ready()
	_player.stun_cap = 1.0
	_choice = ChoiceBox.new()
	add_child(_choice)
	_quest = QuestPanel.new()
	add_child(_quest)
	_chest_ui = ChestUI.new()
	add_child(_chest_ui)
	_chest_ui.closed.connect(_on_chest_closed)
	if _cat != null:
		_cat.player = _player
	_fill_enemies(true)
	if not mission_given:
		_intro()


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	var sp := _layer_named(root, "spawn1")
	if sp != null:
		sp.visible = false
	_front = _layer_named(root, "bookshelf_front")
	if _front != null:
		_front.z_index = 4000
	_books_layer = _layer_named(root, "buku")
	for idx in books_found:
		_erase_book_cells(int(idx))
	td_build_grid(root, _restricted)
	var tex := load(CHEST_TEX) as Texture2D
	var chests: Array = _meta.get("chests", [])
	for i in chests.size():
		var pos := Vector2(float(chests[i][0]), float(chests[i][1]))
		var spr := Sprite2D.new()
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, 64, 96)
		spr.centered = false
		spr.scale = Vector2(0.5, 0.5)
		spr.position = pos + Vector2(-16.0, -40.0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(spr)
		_chests.append({"pos": pos, "spr": spr})
	_cat = TdCat.new()
	_cat.call("setup", self, null, _seat)
	root.add_child(_cat)
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


func _erase_book_cells(idx: int) -> void:
	if _books_layer == null or idx < 0 or idx >= _book_pos.size():
		return
	var bp := Vector2(float(_book_pos[idx][0]), float(_book_pos[idx][1]))
	for c in _books_layer.get_used_cells():
		if Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0).distance_to(bp) < 44.0:
			_books_layer.erase_cell(c)


func _enemy_limit() -> int:
	return int(MAX_ENEMIES[clampi(GameState.difficulty, 0, MAX_ENEMIES.size() - 1)])


func _random_spawn_point() -> Vector2:
	for _i in 60:
		var p := Vector2(randf_range(48.0, td_map_px.x - 48.0), randf_range(48.0, td_map_px.y - 48.0))
		if in_restricted(p) or _player.global_position.distance_to(p) < 480.0:
			continue
		var c := _td_cell(p)
		if _is_solid_cell(c) or _is_solid_cell(Vector2i(c.x, c.y - 1)) or _is_solid_cell(Vector2i(c.x + 1, c.y)) or _is_solid_cell(Vector2i(c.x - 1, c.y)):
			continue
		return p
	return Vector2.ZERO


func _fill_enemies(initial := false) -> void:
	_enemies = _enemies.filter(func(e): return e != null and is_instance_valid(e) and not bool(e.get("_dead")))
	var need := _enemy_limit() - _enemies.size()
	var n := need if initial else mini(need, 1)
	for _i in n:
		var p := _random_spawn_point()
		if p == Vector2.ZERO:
			continue
		var e: CharacterBody2D = TdEnemy.new()
		e.call("setup", KINDS[randi() % KINDS.size()], p, _player, self)
		e.connect("died", _on_enemy_died)
		_map_root.add_child(e)
		_enemies.append(e)


func _on_enemy_died(e: Node) -> void:
	_enemies.erase(e)


func _say(speaker: String, lines: Array, emotes: Array = []) -> void:
	await _open_dialog(speaker, lines, emotes)


func _ask(speaker: String, lines: Array, emotes: Array, options: Array) -> int:
	await _open_dialog(speaker, lines, emotes, true)
	var pick: int = await _choice.ask(options)
	_dialog.call("release")
	EmoteBubble.clear_on(_player)
	return pick


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _lock_player(on: bool) -> void:
	_busy = on
	_dialog_active = on
	if _player != null:
		_player.controls_enabled = (not on) and _player.hp > 0 and not _leaving and not _dying
	if _touch_ui:
		_touch_ui.suspended = on


func _intro() -> void:
	_lock_player(true)
	_cat.face(_player.global_position.x - _cat.global_position.x)
	await _wait(0.6)
	await _say("???", ["Hey Shyrn, bantu aku ya untuk spelling kekuatan ku :3c"], ["question"])
	await _say("???", ["Ada 15 buku yang hilang dan tersebar di perpustakaan ini. Tolong carikan ya, manis~"], ["exclaim"])
	mission_given = true
	_lock_player(false)
	if _hud != null:
		_hud.show_notice("Find the 15 lost books! (%d/%d)" % [books_found.size(), BOOKS_NEEDED], Color("f6d776"), 3.5)


func _cat_talk() -> void:
	_lock_player(true)
	_cat.face(_player.global_position.x - _cat.global_position.x)
	var pick: int = await _ask("???", ["Apakah kamu sudah mengumpulkan buku manis?"], ["question"], ["Ya", "Tidak"])
	var n := books_found.size()
	if pick == 1:
		await _say("???", ["Semangat :D!"], ["heart"])
	elif n >= BOOKS_NEEDED:
		await _say("???", ["Wah, lengkap semuanya! Makasih ya, Shyrn~"], ["heart"])
		_finish()
		return
	elif n == 0:
		await _say("???", ["Bukunya mana manis?"], ["question"])
		await _say("Shyrn", ["eummm... ntahlah"], ["sweat"])
		await _say("???", ["cari dulu dong~"], ["heart"])
	else:
		await _say("???", ["Uhh... bukunya mana? kamu baru ngumpulin buku sebanyak %d, ayo semangat nyarinya!" % n], ["sweat"])
	_lock_player(false)


func _finish() -> void:
	await _wait(0.4)
	_goto(NEXT_SCENE, "")


func _collect_book(idx: int) -> void:
	books_found.append(idx)
	_erase_book_cells(idx)
	_since_book = 0.0
	AudioManager.play_ui("select")
	AudioManager.play_sfx_named("m_charm")
	if _hud != null:
		if books_found.size() >= BOOKS_NEEDED:
			_hud.show_notice("All 15 books found! Bring them to the cat.", Color("9be8a8"), 4.0)
		else:
			_hud.show_notice("Book %d / %d" % [books_found.size(), BOOKS_NEEDED], Color("f6d776"), 2.0)


func _on_player_died() -> void:
	if _leaving:
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
	_cam_target = _cat
	var dest: Vector2 = _player.global_position + Vector2(-30.0, 4.0)
	await _cat.walk_fighting(dest)
	_cat.face(_player.global_position.x - _cat.global_position.x)
	_cam_target = null
	_dialog_active = true
	await _say("???", ["W...waduh, pingsan dong enak nih ~"], ["dots"])
	await _say("???", ["[Menyembuhkan...]"], [])
	AudioManager.play_sfx_named("m_charm")
	_player.revive()
	GameState.faints = maxf(0.0, GameState.faints - 1.0)
	_player.call("_play", "idle")
	_dying = false
	_dialog_active = false
	_player.controls_enabled = true
	if _touch_ui:
		_touch_ui.suspended = false
	var guard := 0
	while guard < 6:
		var e = _cat.nearest_enemy(_player.global_position, 260.0)
		if e == null:
			break
		await _cat.fight(e, 7.0)
		guard += 1
	await _cat.walk_to(_seat, 30.0, 14.0)
	_cat.sit()
	_cat.face(_player.global_position.x - _cat.global_position.x)
	_reviving = false
	if _pending_revive or _player.hp <= 0:
		_pending_revive = false
		_on_player_died()


func _chest_frame(i: int, f: int) -> void:
	var spr: Sprite2D = _chests[i].spr
	spr.region_rect = Rect2(f * 96, 0, 64, 96)


func _chest_slots(i: int) -> Array:
	if not chest_data.has(i):
		var s: Array = []
		s.append({"kind": "item", "item": Inventory.potion_item(randi() % 14, randi_range(1, 2))})
		for _k in 2:
			if randf() < 0.5:
				s.append({"kind": "coin", "n": randi_range(8, 30)})
			else:
				s.append({"kind": "gem", "n": randi_range(1, 3), "frame": randi() % 4})
		while s.size() < 10:
			s.append(null)
		chest_data[i] = s
	return chest_data[i]


func _open_chest(i: int) -> void:
	_lock_player(true)
	_chest_open = i
	AudioManager.play_ui("select")
	for f in range(1, 4):
		_chest_frame(i, f)
		await _wait(0.09)
	if _inv:
		_inv.enabled = false
	_chest_ui.open(_chest_slots(i))


func _on_chest_closed() -> void:
	if _chest_open < 0:
		return
	var i := _chest_open
	for f in [2, 1, 0]:
		_chest_frame(i, f)
		await _wait(0.09)
	_chest_open = -1
	if _inv:
		_inv.enabled = true
	_lock_player(false)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _player == null:
		return
	_zsort()
	_tick_front()
	_tick_camera(delta)
	_tick_timers(delta)
	if not _reviving and not _busy:
		_tick_books()
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
	for c in _chests:
		(c.spr as Sprite2D).z_index = 1 + int((c.pos as Vector2).y / 8.0)


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


func _tick_camera(delta: float) -> void:
	var target := Vector2(0.0, -20.0)
	if _cam_target != null and is_instance_valid(_cam_target):
		target = _cam_target.global_position - _player.global_position + Vector2(0.0, -20.0)
	_cam_off = _cam_off.lerp(target, 1.0 - exp(-6.0 * delta))
	_cam.position = _cam_off


func _tick_timers(delta: float) -> void:
	_clock5 += delta
	if _clock5 >= FIVE_MIN:
		_clock5 = 0.0
		AudioManager.play_sfx_named("library_5min")
	if mission_given and books_found.size() < BOOKS_NEEDED and not _busy and not _reviving:
		_since_book += delta
		if _since_book >= STUCK_HOUR:
			_since_book = 0.0
			_stuck_dialog()
	_respawn_t += delta
	if _respawn_t >= 6.0:
		_respawn_t = 0.0
		_fill_enemies(false)


func _stuck_dialog() -> void:
	_lock_player(true)
	await _say("Shyrn", ["DUhhhhhhhhhhh kok susah ya, jangan-jangan dia ingin menjebak ku dengan hal sybaw ini ;w;."], ["scribble"])
	_lock_player(false)


func _tick_books() -> void:
	if _quest != null:
		_quest.set_text("Find the lost books (%d/%d), then bring them to the cat." % [books_found.size(), BOOKS_NEEDED])
	var pc: Vector2 = _player.td_center()
	for i in _book_pos.size():
		if books_found.has(i):
			continue
		if pc.distance_to(Vector2(float(_book_pos[i][0]), float(_book_pos[i][1]))) < 38.0:
			_collect_book(i)
			break


func _tick_interact(delta: float) -> void:
	var target := ""
	var at := Vector2.ZERO
	var idx := -1
	if _player.hp > 0 and _player.controls_enabled:
		if _cat != null and _cat.global_position.distance_to(_seat) < 24.0 and _player.global_position.distance_to(_cat.global_position) < 64.0:
			target = "cat"
			at = _cat.global_position + Vector2(0.0, -56.0)
		else:
			for i in _chests.size():
				if _player.global_position.distance_to(_chests[i].pos) < 52.0:
					target = "chest"
					idx = i
					at = (_chests[i].pos as Vector2) + Vector2(0.0, -52.0)
					break
	_player.magic_blocked = target != ""
	_prompt.visible = target != ""
	if target != "":
		_prompt_t += delta
		_prompt.position = at + Vector2(0.0, sin(_prompt_t * 4.0) * 1.2)
		_prompt_label.text = "Talk" if target == "cat" else "Open"
		if Input.is_action_just_pressed("interact"):
			if target == "cat":
				_cat_talk()
			else:
				_open_chest(idx)
