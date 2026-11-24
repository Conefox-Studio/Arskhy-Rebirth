extends "res://scripts/level.gd"

const CatBoss = preload("res://scripts/cat_boss.gd")
const BreakableProp = preload("res://scripts/breakable_prop.gd")
const ChoiceBox = preload("res://scripts/choice_box.gd")
const ShopUI = preload("res://scripts/shop_ui.gd")
const ItemPickup = preload("res://scripts/item_pickup.gd")
const InputIcons = preload("res://scripts/input_icons.gd")
const MAP_DIR := "res://maps/dungeon_6/"
const BOSS_MUSIC := "res://assets/audio/music/cat_boss.mp3"
const PROMPT_FONT := "res://assets/fonts/pixelify_sans_bold.ttf"
const CREDITS_SCENE := "res://scenes/library.tscn"
const BossBarScript = preload("res://scripts/boss_bar.gd")

static var cat_met := false
static var cat_healed_once := false

var _cat
var _chain: TileMapLayer
var _door_closed: TileMapLayer
var _door_opened: TileMapLayer
var _door_pos := Vector2.ZERO
var _pickups: Array = []
var _fight := false
var _busy := false
var _door_open := false
var _choice
var _shop
var _prompt: Node2D
var _prompt_label: Label
var _prompt_t := 0.0
var _chain_t := 0.0
var _bar
var _cat_home := 0.0


func _configure() -> void:
	map_json = MAP_DIR + "map.json"
	tileset_path = MAP_DIR + "tileset.tres"
	location_name = "DUNGEON VI"
	show_location_name = false
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/dungeon/dungeon.mp3"
	tile_collision = true
	ground_sink = 1.0
	foot_offset = 1.0
	ground_layers = ["jalan"]
	behind_player_layers = ["pintu_closed", "pintu_opened", "tulang", "jaring"]
	cam_limit_top = 0
	cam_limit_bottom = 416
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
	kill_layers = []
	kill_visible = false
	void_death_y = 800.0
	clear_color = Color("14121f")
	void_color = Color(0, 0, 0, 0)
	backgrounds = []


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for c in root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == n:
			return c
	return null


func _surface_below(map: Node, cx: int, cy: int, px: float) -> float:
	var layer := _layer_named(map, "jalan")
	var tex := load(MAP_DIR + "tileset.png") as Texture2D
	if layer == null or tex == null:
		return -1.0
	var img := tex.get_image()
	var lx := clampi(int(px) - cx * TILE, 0, TILE - 1)
	for y in range(cy, cy + 12):
		var c := Vector2i(cx, y)
		if layer.get_cell_source_id(c) == -1:
			continue
		var ac := layer.get_cell_atlas_coords(c)
		for yy in TILE:
			if img.get_pixel(ac.x * TILE + lx, ac.y * TILE + yy).a > 0.04:
				return float(y * TILE + yy)
		return float(y * TILE)
	return -1.0


func _marks(n: String) -> Array:
	var out: Array = []
	for ld in _layers_data:
		if String(ld.get("name", "")) == n:
			for t in ld.get("tiles", []):
				out.append(Vector2i(int(t.x), int(t.y)))
	return out


func _hide_layer(root: Node, n: String) -> void:
	var l := _layer_named(root, n)
	if l != null:
		l.visible = false


func _groups(cells: Array) -> Array:
	var xs: Array = []
	for c in cells:
		xs.append(int(c.x))
	xs.sort()
	var out: Array = []
	var cur: Array = []
	for x in xs:
		if not cur.is_empty() and int(x) != int(cur[cur.size() - 1]) + 1:
			out.append(cur)
			cur = []
		cur.append(int(x))
	if not cur.is_empty():
		out.append(cur)
	return out


func _build_player(map: Node) -> void:
	var had_load := not GameSettings.pending_load.is_empty()
	super._build_player(map)
	if had_load or _player == null:
		return
	var sp := _marks("Player_Spawn")
	if sp.is_empty():
		return
	var t: Vector2i = sp[0]
	var sx := float(t.x * TILE) + TILE / 2.0
	var fy := _surface_below(map, t.x, t.y, sx)
	_player.position = Vector2(sx, (fy - 1.0) if fy >= 0.0 else float(t.y * TILE + TILE - 2))
	_spawn = _player.position


func _ready() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	super._ready()
	AudioManager.start_loop("chain", "res://assets/audio/ambient/chain_loop.wav", -14.0)
	if _player != null and _cat != null and _player.global_position.x > _cat.global_position.x:
		(_player.get("_sprite") as AnimatedSprite2D).flip_h = true
	_bar = BossBarScript.new()
	add_child(_bar)
	_choice = ChoiceBox.new()
	add_child(_choice)
	_shop = ShopUI.new()
	add_child(_shop)
	if _cat != null:
		_cat.player = _player
		_cat.level = self
		_cat.fight_over.connect(_on_fight_over)
		if cat_met:
			_cat.mode = "npc"
		else:
			_intro()


func _exit_tree() -> void:
	AudioManager.stop_loop("chain")
	super._exit_tree()


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	for n in ["Player_Spawn", "cat_spawn", "barrel", "vas"]:
		_hide_layer(root, n)
	_chain = _layer_named(root, "rantai")
	_door_closed = _layer_named(root, "pintu_closed")
	_door_opened = _layer_named(root, "pintu_opened")
	if _door_opened != null:
		_door_opened.visible = false
	if _door_closed != null:
		var da := _cluster_art(_door_closed, _door_closed.get_used_cells())
		if not da.is_empty():
			var r: Rect2 = da[1]
			_door_pos = Vector2(r.get_center().x, r.end.y)
	_build_props(root)
	_build_cat(root)
	_build_prompt(root)


func _by_original_tile(layer: TileMapLayer) -> Array:
	var groups := {}
	for c in layer.get_used_cells():
		var k := Vector2i(c.x >> 1, c.y >> 1)
		if not groups.has(k):
			groups[k] = []
		groups[k].append(c)
	var out: Array = []
	var keys := groups.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x)
	for k in keys:
		out.append(groups[k])
	return out


func _build_props(root: Node2D) -> void:
	var vl := _layer_named(root, "vas")
	var bl := _layer_named(root, "barrel")
	if vl != null:
		for g in _by_original_tile(vl):
			var art := _cluster_art(vl, g)
			if art.is_empty():
				continue
			var p: StaticBody2D = BreakableProp.new()
			p.call("setup", art[0], art[1], 1, "vase")
			root.add_child(p)
			_objects.append(p)
	if bl != null:
		for g2 in _by_original_tile(bl):
			var art2 := _cluster_art(bl, g2)
			if art2.is_empty():
				continue
			var p2: StaticBody2D = BreakableProp.new()
			p2.call("setup", art2[0], art2[1], 5, "barrel")
			p2.connect("broken", _on_barrel_broken)
			root.add_child(p2)
			_objects.append(p2)


func _on_barrel_broken(prop: Node) -> void:
	var rect: Rect2 = prop.get("art_rect")
	var it: Dictionary = Inventory.potion_item(randi() % 14, 1)
	var pk: Node2D = ItemPickup.new()
	pk.call("setup", it, _player, Vector2(rect.get_center().x, rect.end.y))
	add_child(pk)
	_pickups.append(pk)


func _build_cat(root: Node2D) -> void:
	var cs := _marks("cat_spawn")
	if cs.is_empty():
		return
	var t: Vector2i = cs[0]
	var px := float(t.x * TILE) + TILE / 2.0
	var fy := _surface_below(root, t.x, t.y, px)
	_cat_home = px + 16.0
	_cat = CatBoss.new()
	_cat.call("setup", null, self, Vector2(px, (fy - 1.0) if fy >= 0.0 else 380.0))
	root.add_child(_cat)
	_objects.append(_cat)


func _build_prompt(root: Node2D) -> void:
	_prompt = Node2D.new()
	_prompt.z_index = 20
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


func _cam_to(world: Vector2, sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(_cam, "position", world - _player.global_position, sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _cam_back(sec: float) -> void:
	var tw := create_tween()
	tw.tween_property(_cam, "position", Vector2(0.0, -20.0), sec).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _intro() -> void:
	cat_met = true
	_lock_player(true)
	await _wait(0.6)
	await _cam_to(_cat.global_position + Vector2(0.0, -20.0), 1.8)
	await _wait(0.5)
	_cat.face(1.0)
	AudioManager.play_sfx_named("swing")
	await _wait(0.5)
	var pick: int = await _ask("???", ["Hey! Siapa kau meow!"], ["exclaim"], ["Eh... Aku Shyrn...", "Mampir", "..."])
	match pick:
		0:
			await _say("Shyrn", ["Ehhh maaf kucing, kenapa kamu ada di sini apakah, kamu sedang mencari makanan?"], ["question"])
			await _approach()
			var p2: int = await _ask("???", ["grrrr... tidak! aku tinggal di sini di tempat terkutuk ini, kau ngapain di sini huh mau melawan ku?"], ["shock"], ["Tidak", "GAS!"])
			if p2 == 0:
				await _say("Shyrn", ["Eh tidak tidak, aku tidak suka bertarung..."], ["sweat"])
				await _say("???", ["Hmph. Ya sudah, jangan bikin ribut di sini. Mau beli sesuatu?"], ["dots"])
				await _to_npc()
			else:
				await _say("Shyrn", ["EH... anu aku gak mau bertarung but yaudah lah yuk kita tarung, siapa yang paling kuat"], ["sweat"])
				await _start_fight()
		1:
			await _say("Shyrn", ["Aku cuma mampir ke sini aja aku salah jalan ternyata aku kira lanjut ke tempat lain ;w;"], ["sweat"])
			await _approach()
			await _say("???", ["Owalah tersesat ya manis~ tapi aku pengen melawan mu sesekali <3 dan sekali kali pengen crush kamu ege~"], ["blush"])
			await _say("Shyrn", ["Boleh aja sih kucing ngerush aku, cuman klo ngelawan masa iya harus bertarung di saat saling suka =w= klo mau bertarung untuk pemanasan ok lah yuk!"], ["blush"])
			await _start_fight()
		_:
			await _say("Shyrn", ["..."], ["dots"])
			await _say("???", ["Ah sudah lah, ku harap kau gak ngeganggu ku sini, mau beli sesuatu?"], ["question"])
			await _to_npc()


func _approach() -> void:
	await _cat.goto_x(_player.global_position.x - 52.0)
	_cat.face(1.0)
	await _wait(0.3)


func _to_npc() -> void:
	await _cat.goto_x(_cat_home)
	_cat.mode = "npc"
	await _cam_back(1.2)
	_lock_player(false)


func _start_fight() -> void:
	await _cam_back(0.8)
	_fight = true
	music_override = BOSS_MUSIC
	_cur_music = BOSS_MUSIC
	AudioManager.play_music_if_new(BOSS_MUSIC, 1.0)
	_cat.start_fight()
	_bar.show_bar("???")
	_bar.set_hp(_cat.hp, _cat.MAX_HP)
	_lock_player(false)
	if _hud != null:
		_hud.show_notice("Fight! The cat stops at half HP, or when your HP is 5.", Color("f6d776"), 3.0)


func _on_fight_over(reason: String) -> void:
	_fight = false
	_bar.hide_bar()
	music_override = ""
	_cur_music = music_path
	AudioManager.play_music_if_new(music_path, 2.0)
	_lock_player(true)
	_player.velocity = Vector2.ZERO
	await _wait(0.5)
	_cat.face(_player.global_position.x - _cat.global_position.x)
	if not cat_healed_once:
		cat_healed_once = true
		await _say("???", ["yaudah... aku sembuhin maaf klo terlalu keras ;w; aku suka main keras ketimbang main beras eh maksudnya..."], ["blush"])
		_heal_player()
		await _say("Shyrn", ["beras apa, berasa kamu peduli sama cewek XD"], ["blush"])
		await _say("???", ["Kurang ajar ya kamu astaga ;w;"], ["angry"])
		await _say("Shyrn", ["(Kurang ajar? ajarin ~)"], ["heart"])
		await _say("???", ["He'eh lah serah maneh..."], ["dots"])
	else:
		await _say("???", ["Yaudah... aku sembuhin ya, maaf keras-keras."], ["sweat"])
		_heal_player()
	_cat.mode = "npc"
	_lock_player(false)


func _heal_player() -> void:
	AudioManager.play_sfx_named("m_charm")
	_player.hp = _player.max_hp
	_player.hp_changed.emit(_player.hp, _player.max_hp)
	_player.set("_bleed_ticks", 0)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	if _chain != null:
		_chain_t += delta
		_chain.position.y = fmod(_chain_t * 24.0, 16.0)
	_tick_interact(delta)
	if _fight and _cat != null:
		_bar.set_hp(_cat.hp, _cat.MAX_HP)


func _near_cat() -> bool:
	return _cat != null and _cat.mode == "npc" and absf(_player.global_position.x - _cat.global_position.x) < 40.0 and absf(_player.global_position.y - _cat.global_position.y) < 40.0


func _near_door() -> bool:
	return not _door_open and absf(_player.global_position.x - _door_pos.x) < 30.0 and absf(_player.global_position.y - _door_pos.y) < 48.0


func _tick_interact(delta: float) -> void:
	var target := ""
	if not _busy and _player.hp > 0 and _player.controls_enabled:
		if _near_cat():
			target = "cat"
		elif _near_door():
			target = "door"
	_player.magic_blocked = target != ""
	if _prompt != null:
		_prompt.visible = target != ""
		if target != "":
			_prompt_t += delta
			var at: Vector2 = (_cat.global_position + Vector2(0.0, -52.0)) if target == "cat" else (_door_pos + Vector2(0.0, -48.0))
			_prompt.position = at + Vector2(0.0, sin(_prompt_t * 4.0) * 1.2)
			_prompt_label.text = "Talk" if target == "cat" else "Open"
	if Input.is_action_just_pressed("interact"):
		if target == "cat":
			_cat_menu()
		elif target == "door":
			_open_door()
		elif _fight and _near_door() and _hud != null:
			_hud.show_notice("You can't leave during the fight!", Color("ff9a8a"), 2.0)


func _open_door() -> void:
	if _fight or _busy:
		return
	_door_open = true
	_lock_player(true)
	if _door_closed != null:
		_door_closed.visible = false
	if _door_opened != null:
		_door_opened.visible = true
	AudioManager.play_sfx_named("boom")
	await _wait(0.9)
	_goto(CREDITS_SCENE, "")


func _cat_menu() -> void:
	_lock_player(true)
	_cat.face(_player.global_position.x - _cat.global_position.x)
	var pick: int = await _ask("???", ["Meow? Ada apa?"], ["question"], ["Talk", "Shop", "Leave"])
	match pick:
		0:
			var lines := ["Aku sudah lama tinggal di sini. Sepi sih, tapi tenang.", "Barel itu isinya lumayan loh. Kalau kamu pecahin, aku juga ikut ambil ya~", "Pintu itu ke kamarku. Jangan ngintip, meow.", "Vasnya jangan dipecahin semua dong, itu koleksiku!"]
			await _say("???", [lines[randi() % lines.size()]], ["heart"])
			_lock_player(false)
		1:
			_shop.open()
			await _shop.closed
			_lock_player(false)
		_:
			_lock_player(false)
