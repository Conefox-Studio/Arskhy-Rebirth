extends "res://scripts/level.gd"


func _configure() -> void:
	map_json = "res://maps/shynetown/map.json"
	tileset_path = "res://maps/shynetown/tileset.tres"
	location_name = "SHYNETOWN"
	next_scene = "res://scenes/jungle.tscn"
	music_path = "res://assets/audio/music/shynetown_ambience.ogg"
	shadow_layers = ["pillar", "layer_5", "layer_6", "layer_9"]
	void_color = Color("030304")

	dialogs = [
		{"id": "shyne_masuk", "x": 0.0, "width": 600.0, "speaker": "Shyrn", "lines": [
			"Aku harap kamu player menjagaku, jangan sampai aku mati ;w; dan mengecewakan orang tuaku ya!",
		]},
	]
