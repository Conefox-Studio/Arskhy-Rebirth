extends "res://scripts/level.gd"

const CREDITS_SCENE := "res://scenes/credits.tscn"


func _configure() -> void:
	map_json = "res://maps/before_ending/map.json"
	tileset_path = "res://maps/before_ending/tileset.tres"
	location_name = "BEFORE ENDING"
	show_location_name = false
	prev_scene = "res://scenes/boss_map.tscn"
	next_scene = ""
	music_path = "res://assets/audio/music/before_ending.mp3"
	tile_collision = true
	ground_sink = 13.0
	foot_offset = 13.0
	cam_limit_top = 0
	cam_limit_bottom = 420
	ground_layers = ["jalan"]
	enemies_enabled = false
	force_night = true
	lit_night = true
	night_tint = Color(0.50, 0.55, 0.82)
	rain_mode = "never"
	night_aurora = true
	bg_dir = "res://assets/maps/before_ending/"
	clear_color = Color("1a1230")
	backgrounds = [
		{"file": "bg_sky.png", "scale": 2.0, "move": 0.0, "ymove": 0.0, "top": -180.0, "wrap": true},
		{"file": "bg_far.png", "scale": 2.0, "move": 0.08, "ymove": 0.0, "top": -180.0, "wrap": true},
		{"file": "bg_near.png", "scale": 2.0, "move": 0.18, "ymove": 0.0, "top": -180.0, "wrap": true},
	]
	low_skip = ["bg_far.png"]


func _ready() -> void:
	super._ready()
	if _player != null:
		_player.scale = Vector2(0.72, 0.72)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _leaving or _dying or _player == null or _edge_grace > 0.0 or not _player.controls_enabled:
		return
	if _player.global_position.x >= _player.max_x - 1.0 and Input.get_axis("move_left", "move_right") > 0.0:
		GameSettings.mark_mode_completed(GameState.difficulty)
		_goto(CREDITS_SCENE, "")
