extends "res://scripts/level.gd"

const BossScript = preload("res://scripts/boss.gd")
const BossBarScript = preload("res://scripts/boss_bar.gd")
const BreakableScript = preload("res://scripts/breakable.gd")

const BOSS_ID := "boss_ghost_executor"
const BOSS_MUSIC := "res://assets/audio/music/boss_fight.mp3"
const TRIGGER_X := 100.0 * 16.0
const ARENA_BACK := 150.0

var _boss
var _bar: CanvasLayer
var _triggered := false
var _boss_down := false
var _min_x_default := 0.0


func _configure() -> void:
	map_json = "res://maps/boss_map/map.json"
	tileset_path = "res://maps/boss_map/tileset.tres"
	location_name = "BOSS MAP"
	show_location_name = false
	prev_scene = "res://scenes/jungle_route_3.tscn"
	next_scene = "res://scenes/before_ending.tscn"
	music_path = "res://assets/audio/music/horror_ambience.ogg"
	tile_collision = true
	ground_sink = 13.0
	foot_offset = 13.0
	cam_limit_top = 0
	cam_limit_bottom = 420
	ground_layers = ["jalan_1", "jalan_2"]
	player_after_layer = "jalan_2"
	behind_player_layers = ["tunggul"]
	thorn_layers = ["duri"]
	enemies_enabled = false
	force_night = true
	lit_night = true
	night_tint = Color(0.02, 0.02, 0.024)
	player_glow = 0.30
	rain_mode = "always"
	bg_dir = "res://assets/maps/boss_map/"
	clear_color = Color("08060f")
	backgrounds = [
		{"file": "bg_sky.png", "scale": 2.0, "move": 0.0, "ymove": 0.0, "top": -180.0, "wrap": true},
		{"file": "bg_far.png", "scale": 2.0, "move": 0.08, "ymove": 0.0, "top": -180.0, "wrap": true},
		{"file": "bg_near.png", "scale": 2.0, "move": 0.18, "ymove": 0.0, "top": -180.0, "wrap": true},
	]
	low_skip = ["bg_far.png"]


func _ready() -> void:
	super._ready()
	if _player == null:
		return
	_min_x_default = _player.min_x
	_bar = BossBarScript.new()
	add_child(_bar)
	if GameState.seen_dialogs.has(BOSS_ID):
		_triggered = true
		_boss_down = true
	else:
		exits_locked = true
	_setup_tower()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _triggered or _player == null or _leaving or _dying:
		return
	if _player.global_position.x >= TRIGGER_X and _player.controls_enabled and _player.hp > 0 and not get_tree().paused:
		_triggered = true
		_boss_intro()


func _setup_tower() -> void:
	if _map_root == null:
		return
	for c in _map_root.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) == "tower":
			var used: Rect2i = c.get_used_rect()
			var tile := float(TILE)
			var base := Rect2(used.position.x * tile, (used.end.y - 5) * tile, used.size.x * tile, 5.0 * tile)
			var b := StaticBody2D.new()
			b.set_script(BreakableScript)
			_map_root.add_child(b)
			b.call("setup", base, c, 5)
			b.connect("shake_requested", shake_camera)
			return


func _boss_intro() -> void:
	exits_locked = true
	_player.controls_enabled = false
	_player.velocity.x = 0.0
	if _touch_ui:
		_touch_ui.suspended = true
	AudioManager.stop_music(0.8)
	AudioManager.play_sfx_named("rumble")
	shake_camera(3.2, 4.2)
	var dark := create_tween()
	dark.tween_property(_fade, "color:a", 0.65, 0.7)
	await get_tree().create_timer(1.6).timeout
	if _dying or _leaving:
		return
	var px := clampf(_player.global_position.x + 250.0, TRIGGER_X + 160.0, _ground_max_x - 60.0)
	_boss = BossScript.new()
	_map_root.add_child(_boss)
	_boss.setup(_player, Callable(self, "_ground_y_at"), Vector2(px, _ground_y_at(px) - 40.0), GameState.difficulty)
	_boss.bounds_x = Vector2(TRIGGER_X - ARENA_BACK, _ground_max_x - 40.0)
	_boss.hp_changed.connect(_on_boss_hp)
	_boss.mp_changed.connect(_on_boss_mp)
	_boss.shake_requested.connect(shake_camera)
	_boss.defeated.connect(_on_boss_defeated)
	_boss.appear(1.4)
	AudioManager.play_sfx_named("boom")
	_bar.call("show_bar", String(_boss.display_name))
	_bar.call("set_hp", _boss.hp, _boss.max_hp)
	_bar.call("set_mp", _boss.mp, 100.0)
	var clear := create_tween()
	clear.tween_property(_fade, "color:a", 0.0, 1.2)
	await get_tree().create_timer(2.0).timeout
	if _dying or _leaving:
		return
	music_override = BOSS_MUSIC
	_cur_music = BOSS_MUSIC
	AudioManager.play_music_if_new(BOSS_MUSIC, 1.0)
	_player.min_x = maxf(_min_x_default, TRIGGER_X - ARENA_BACK)
	if _touch_ui:
		_touch_ui.suspended = false
	await _run_dialog("Shyrn", ["aduhhh salah tempat lagi .w."])
	if _boss != null and is_instance_valid(_boss) and not _dying:
		_boss.activate()


func _on_boss_hp(hp: int, max_hp: int) -> void:
	_bar.call("set_hp", hp, max_hp)


func _on_boss_mp(mp: float, max_mp: float) -> void:
	_bar.call("set_mp", mp, max_mp)


func _on_boss_defeated() -> void:
	_boss_down = true
	GameState.seen_dialogs[BOSS_ID] = true
	exits_locked = false
	_player.min_x = _min_x_default
	_bar.call("hide_bar")
	music_override = ""
	_cur_music = _wanted_music()
	AudioManager.stop_music(2.5)
	pass
	Achievements.unlock("ghost_hunter")
	if GameState.difficulty >= 3:
		Achievements.unlock("hardcore")
	await get_tree().create_timer(4.5).timeout
	if not _leaving and not _dying and _player != null and _player.hp > 0:
		_goto("res://scenes/before_ending.tscn", "")


func _on_player_died() -> void:
	super._on_player_died()
	if _boss_down or not _triggered:
		return
	if _boss != null and is_instance_valid(_boss):
		_boss.clear_minions()
		_boss.queue_free()
	_boss = null
	_bar.call("hide_bar")
	_triggered = false
	exits_locked = true
	_player.min_x = _min_x_default
	music_override = ""
	_cur_music = _wanted_music()
	AudioManager.play_music_if_new(music_path, 1.5)
