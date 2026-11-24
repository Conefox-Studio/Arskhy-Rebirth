extends "res://scripts/level.gd"

const ChaseBarrel = preload("res://scripts/chase_barrel.gd")
const DebrisScript = preload("res://scripts/debris.gd")
const RUSH_MUSIC := "res://assets/audio/music/jungle_route_2/rush.mp3"
const BARREL_SCALE := 4.0

var _r2_root: Node2D
var _statues: Array = []
var _statue_sfx_cd := 0.0


func _configure() -> void:
	map_json = "res://maps/jungle_route_2/map.json"
	tileset_path = "res://maps/jungle_route_2/tileset.tres"
	location_name = "ROUTE 2"
	prev_scene = "res://scenes/jungle_route_1.tscn"
	next_scene = "res://scenes/jungle_route_3.tscn"
	music_path = "res://assets/audio/music/jungle_route_1/jungle_route_1.mp3"
	tile_collision = true
	ground_sink = 13.0
	foot_offset = 13.0
	pushable_layers = ["box_1", "box_2", "box_3"]
	behind_player_layers = []
	barrel_layers = []
	cam_limit_top = -400
	cam_limit_bottom = 1800
	void_death_y = 1400.0
	ground_layers = ["jalan"]
	thorn_layers = []
	shadow_layers = []
	enemies_enabled = true
	enemy_kinds = ["demon", "blood_monster"]
	enemy_count_scale = 0.5
	enemy_x_from = 1300.0
	wildlife_count = 10
	bg_dir = "res://assets/maps/jungle_route_2/"
	clear_color = Color("0a1e13")
	backgrounds = [
		{"file": "bg_far.png", "scale": 1.5, "move": 0.05, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_mid.png", "scale": 1.5, "move": 0.16, "ymove": 0.0, "top": -204.0, "wrap": true},
		{"file": "bg_near.png", "scale": 1.5, "move": 0.32, "ymove": 0.0, "top": -204.0, "wrap": true},
	]
	low_skip = ["bg_mid.png"]


func _build_map() -> Node2D:
	var root: Node2D = super._build_map()
	var l9 := _layer_named(root, "layer_9")
	if l9 != null:
		root.move_child(l9, 0)
	var pt := _layer_named(root, "patung_hancur")
	if pt != null:
		root.move_child(pt, 1 if l9 != null else 0)
	return root


func _layer_named(root: Node, n: String) -> TileMapLayer:
	for lay in root.get_children():
		if lay is TileMapLayer and String(lay.get_meta("src_name", "")) == n:
			return lay
	return null


func _first_cell_pos(layer: TileMapLayer) -> Vector2:
	if layer == null:
		return Vector2(1.0e9, 0.0)
	var cells := layer.get_used_cells()
	if cells.is_empty():
		return Vector2(1.0e9, 0.0)
	return layer.to_global(layer.map_to_local(cells[0]))


func _build_objects(root: Node2D) -> void:
	super._build_objects(root)
	_r2_root = root
	_stack_boxes()
	_collect_statues(root)
	var bl := _layer_named(root, "barrel_chase")
	if bl == null:
		return
	var clusters := _tile_clusters(bl)
	if clusters.is_empty():
		return
	var group: Array = clusters[0]
	for g in clusters:
		if g.size() > group.size():
			group = g
	var art := _cluster_art(bl, group)
	if art.is_empty():
		return
	var tex: Texture2D = art[0]
	var r: Rect2 = art[1]
	for c in group:
		bl.erase_cell(c)
	var d := int(minf(r.size.x, r.size.y))
	var face := Image.create(d, d, false, Image.FORMAT_RGBA8)
	face.blit_rect(tex.get_image(), Rect2i(0, int(r.size.y) - d, d, d), Vector2i.ZERO)
	inner_face(face)
	var fr := Rect2(r.position.x, r.end.y - d, d, d)
	var b: CharacterBody2D = CharacterBody2D.new()
	b.set_script(ChaseBarrel)
	b.set("route", self)
	b.set("trigger_x", _first_cell_pos(_layer_named(root, "barrel_start")).x - 8.0)
	b.set("end_pos", _first_cell_pos(_layer_named(root, "hancur_setelah_barrel")))
	_attach_barrel_body(b, tex, r, d, fr)
	b.call("setup", ImageTexture.create_from_image(face), float(d) * 0.5, fr.get_center(), _player, BARREL_SCALE)
	root.add_child(b)
	_objects.append(b)


func _stack_boxes() -> void:
	var boxes: Array = []
	for o in _objects:
		if is_instance_valid(o) and o is CharacterBody2D:
			var spr: Sprite2D = null
			for c in o.get_children():
				if c is Sprite2D and c.texture != null:
					spr = c
					break
			if spr != null:
				o.set("stack_mask", true)
				boxes.append({"n": o, "w": float(spr.texture.get_width()), "h": float(spr.texture.get_height())})
	boxes.sort_custom(func(a, b): return a.n.position.y > b.n.position.y)
	for i in boxes.size():
		var a: Dictionary = boxes[i]
		for j in i:
			var b: Dictionary = boxes[j]
			if absf(a.n.position.x - b.n.position.x) >= (a.w + b.w) * 0.5 - 4.0:
				continue
			var btop: float = b.n.position.y - b.h
			if a.n.position.y < b.n.position.y - 1.0 and a.n.position.y > btop + 1.0:
				a.n.position.y = btop


func _collect_statues(root: Node2D) -> void:
	_statues.clear()
	var layer := _layer_named(root, "patung_hancur")
	if layer == null:
		return
	for group in _tile_clusters(layer):
		var r := Rect2()
		var first := true
		for c in group:
			var p := layer.to_global(layer.map_to_local(c))
			var cr := Rect2(p - Vector2(8, 8), Vector2(16, 16))
			r = cr if first else r.merge(cr)
			first = false
		_statues.append({"cells": group, "rect": r, "alive": true})


func _chase_started() -> void:
	music_override = RUSH_MUSIC
	_cur_music = RUSH_MUSIC
	AudioManager.play_music(RUSH_MUSIC, 0.4)
	if _hud != null and _hud.has_method("show_notice"):
		_hud.show_notice("Run!", Color("ff8a6a"), 2.0)


func _chase_ended() -> void:
	music_override = ""


func _crush_at(center: Vector2, r: float) -> void:
	if _r2_root == null or _atlas_img == null:
		return
	var layer := _layer_named(_r2_root, "patung_hancur")
	if layer == null:
		return
	for st in _statues:
		if not st.alive:
			continue
		var rect: Rect2 = st.rect
		var cp := Vector2(clampf(center.x, rect.position.x, rect.end.x), clampf(center.y, rect.position.y, rect.end.y))
		if cp.distance_to(center) > r:
			continue
		st.alive = false
		var atlas_tex := ImageTexture.create_from_image(_atlas_img)
		for cell in st.cells:
			if layer.get_cell_source_id(cell) == -1:
				continue
			var wp := layer.to_global(layer.map_to_local(cell))
			var ac := layer.get_cell_atlas_coords(cell)
			if randf() < 0.3:
				DebrisScript.burst(_r2_root, atlas_tex, Rect2(wp - Vector2(8, 8), Vector2(16, 16)), 3, 1.1, Rect2(ac.x * TILE, ac.y * TILE, TILE, TILE))
			layer.erase_cell(cell)
		AudioManager.play_sfx_named("statue_break")
		shake_camera(6.0, 0.5)
