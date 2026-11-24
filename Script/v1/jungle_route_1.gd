extends "res://scripts/level.gd"

func _configure() -> void:
	map_json = "res://maps/jungle_route_1/map.json"
	tileset_path = "res://maps/jungle_route_1/tileset.tres"
	location_name = "ROUTE 1"
	prev_scene = "res://scenes/jungle.tscn"
	next_scene = "res://scenes/jungle_route_2.tscn"
	music_path = "res://assets/audio/music/jungle_route_1/jungle_route_1.mp3"
	tile_collision = true
	ground_sink = 13.0
	foot_offset = 13.0
	pushable_layers = ["box"]
	barrel_layers = ["barrel_roll", "barrel_fall"]
	cam_limit_top = -300
	cam_limit_bottom = 3300
	black_tint_layers = ["tanah"]
	hide_layers = ["daun_bawah"]
	ground_layers = ["jalan"]
	player_after_layer = "jalan"
	thorn_layers = ["duri"]
	shadow_layers = ["object_shade_a", "object_shade_b"]
	enemies_enabled = true
	enemy_x_from = 30.0 * 16.0
	enemy_x_to = 230.0 * 16.0
	wildlife_count = 20
	bg_dir = "res://assets/maps/jungle_route_1/"
	clear_color = Color("0a1e13")
	backgrounds = [
		{"file": "bg_far.png", "scale": 1.5, "move": 0.05, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_mid.png", "scale": 1.5, "move": 0.16, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_near.png", "scale": 1.5, "move": 0.32, "ymove": 0.0, "top": -204.0, "wrap": true},
	]
	low_skip = ["bg_mid.png"]
