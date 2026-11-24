extends "res://scripts/level.gd"


func _configure() -> void:
	map_json = "res://maps/jungle/map.json"
	tileset_path = "res://maps/jungle/tileset.tres"
	location_name = "JUNGLE"
	show_location_name = true
	prev_scene = "res://scenes/shynetown.tscn"
	ground_layers = ["jalan"]
	ground_fill_layers = []
	next_scene = "res://scenes/jungle_route_1.tscn"
	music_path = "res://assets/audio/music/jungle.mp3"
	shadow_layers = ["pillar", "box", "object_8"]
	thorn_layers = ["duri"]
	behind_player_layers = ["pillar"]
	snap_layers = ["box"]
	enemies_enabled = true
	wildlife_count = 20

	bg_dir = "res://assets/maps/jungle/"
	clear_color = Color("0a1e13")
	backgrounds = [
		{"file": "bg_far.png", "scale": 1.5, "move": 0.05, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_mid.png", "scale": 1.5, "move": 0.16, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_near.png", "scale": 1.5, "move": 0.32, "ymove": 0.0, "top": -204.0, "wrap": true},
	]
	low_skip = ["bg_mid.png"]

	void_color = Color("050806")
	underground_layers = ["fill"]

	dialogs = [
		{"id": "jungle_masuk", "x": 0.0, "width": 600.0, "speaker": "Shyrn", "lines": [
			"Ah let's gro eh ngapain aku pakai bahasa inggris kan bukan standarku.",
		]},
	]
