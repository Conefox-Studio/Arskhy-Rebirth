extends "res://scripts/level.gd"

const SPAWN_CELL := Vector2i(139, 15)
const EXIT_CELL := Vector2i(178, 74)
const VISIBLE_DARK := 0.05


func _configure() -> void:
	map_json = "res://maps/cave/map.json"
	tileset_path = "res://maps/cave/tileset.tres"
	location_name = "CAVE"
	show_location_name = true
	prev_scene = ""
	next_scene = ""
	music_path = "res://assets/audio/music/cave/cave.mp3"
	tile_collision = true
	ground_sink = 3.0
	foot_offset = 3.0
	ground_layers = ["jalan"]
	cam_limit_top = -16
	cam_limit_bottom = 2430
	enemies_enabled = false
	wildlife_count = 0
	player_size_mult = 48.0 / 36.0
	spawn_override = Vector2(SPAWN_CELL.x * TILE + 8.0, SPAWN_CELL.y * TILE - 1.0)
	force_night = true
	lit_night = true
	night_tint = Color(VISIBLE_DARK, VISIBLE_DARK, VISIBLE_DARK * 1.2)
	rain_mode = "never"
	night_eyes = false
	night_fireflies = false
	night_aurora = false
	no_atmosphere = true
	player_glow = 0.30
	kill_layers = ["langsung_mati"]
	kill_text = "Menghantam bebatuan cukup keras"
	kill_visible = true
	bg_dir = "res://assets/maps/cave/"
	clear_color = Color("0c1114")
	backgrounds = [
		{"file": "bg_far.png", "scale": 1.0, "move": 0.04, "ymove": 0.0, "top": -240.0, "wrap": true},
		{"file": "bg_mid2.png", "scale": 1.0, "move": 0.10, "ymove": 0.0, "top": -240.0, "wrap": true},
		{"file": "bg_mid.png", "scale": 1.0, "move": 0.20, "ymove": 0.0, "top": -240.0, "wrap": true},
		{"file": "bg_near.png", "scale": 1.0, "move": 0.35, "ymove": 0.0, "top": -240.0, "wrap": true},
	]
	low_skip = ["bg_mid2.png"]


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null:
		return
	var ex := Vector2(EXIT_CELL.x * TILE + 8.0, EXIT_CELL.y * TILE + 16.0)
	if absf(_player.global_position.x - ex.x) < 40.0 and absf(_player.global_position.y - ex.y) < 56.0:
		_goto("res://scenes/boss_map.tscn", "")
