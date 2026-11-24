extends Node2D

const SHEET_COLUMNS := 8
const PlayerScript = preload("res://scripts/player.gd")
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const PauseMenu = preload("res://scripts/pause_menu.gd")
const AtmosphereScript = preload("res://scripts/atmosphere.gd")
const DayNightScript = preload("res://scripts/day_night.gd")
const NightFxScript = preload("res://scripts/night_fx.gd")
const NIGHT_MUSIC := "res://assets/audio/music/night_theme.mp3"
const EmoteBubble = preload("res://scripts/emote_bubble.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const DragonflyScript = preload("res://scripts/dragonfly.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const ScreenFxScript = preload("res://scripts/screen_fx.gd")
const WindFxScript = preload("res://scripts/wind_fx.gd")
const PerfMonitorScript = preload("res://scripts/perf_monitor.gd")
const PushableScript = preload("res://scripts/pushable.gd")
const BarrelScript = preload("res://scripts/rolling_barrel.gd")

const ENEMY_COUNTS: Array[int] = [5, 10, 20, 50]
const ENEMY_MIX: Array = [["ghost", 0.5], ["demon", 0.28], ["blood_monster", 0.22]]
const GOBLIN_KINDS: Array[String] = ["goblin_rogue", "goblin_poison", "goblin_warrior", "goblin_barbarian", "goblin_hunter"]
const DialogBox = preload("res://scripts/dialog_box.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const InventoryUI = preload("res://scripts/inventory_ui.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxLib = preload("res://scripts/fx.gd")
const RESTART_SCENE := "res://scenes/chapter_intro.tscn"
const BG_DIR := "res://assets/maps/shynetown/"
const FONT_TITLE := "res://assets/fonts/cinzel_decorative_bold.ttf"
const FONT_UI := "res://assets/fonts/pixelify_sans.ttf"

const TILE := 16
const SHADOW_MAX_TILES := 4000
const FOOT_OFFSET := 13.0
const DEFAULT_SPAWN_X := 88.0
const VOID_INSET := 6.0
const DIALOG_ZONE := 220.0

const BACKGROUNDS: Array = [
	{"file": "forest_sky.png", "scale": 1.24, "move": 0.0, "top": -180.0, "wrap": false, "x": -589.0},
	{"file": "forest_moon.png", "scale": 0.5, "move": 0.0, "top": -157.0, "wrap": false, "x": 167.0},
	{"file": "forest_mountain.png", "scale": 0.6, "move": 0.05, "top": -153.0, "wrap": true},
	{"file": "forest_back.png", "scale": 0.6, "move": 0.12, "top": -95.0, "wrap": true},
	{"file": "forest_mid.png", "scale": 0.6, "move": 0.22, "top": -45.0, "wrap": true},
	{"file": "forest_long.png", "scale": 0.6, "move": 0.35, "top": -20.0, "wrap": true},
	{"file": "forest_short.png", "scale": 0.6, "move": 0.5, "top": 10.0, "wrap": true},
]

const LOW_SKIP: Array[String] = ["forest_back.png", "forest_long.png"]

const THORN_PROBES: Array[Vector2] = [
	Vector2(-5, -3), Vector2(5, -3), Vector2(0, -18),
	Vector2(-5, -18), Vector2(5, -18), Vector2(-5, -32), Vector2(5, -32),
]

var _bg_root: Node2D
var _bg_layers: Array = []
var _cam: Camera2D
var _cam0 := Vector2.ZERO
var _bg_ready := false
var _player: CharacterBody2D
var _fade: ColorRect
var _leaving := false
var _pause: CanvasLayer
var _atmo: Node2D
var _daynight: Node
var snap_layers: Array[String] = []
var tile_collision := false
var ground_sink := 0.0
var pushable_layers: Array[String] = []
var barrel_layers: Array[String] = []
var barrel_min_tiles := 10
var foot_offset := FOOT_OFFSET
var cam_limit_top := -300
var cam_limit_bottom := 1200
var enemy_x_from := -1.0
var enemy_x_to := -1.0
var enemy_kinds: Array[String] = []
var enemy_count_scale := 1.0
var player_after_layer := ""
var exit_choices: Array = []
var exit_choice_title := "Mau kemana?"
var _choice_layer: CanvasLayer
var enemies_enabled := false
var wildlife_count := 0
var _objects: Array = []
var _inv: CanvasLayer
var _hud: CanvasLayer
var _touch_ui: CanvasLayer
var _dialog: CanvasLayer
var _dialog_active := false
var _shadow_items: Array = []
var exits_locked := false
var _shake_t := 0.0
var _shake_total := 0.01
var _shake_pow := 0.0
var _edge_grace := 0.8
var _errors: Array[String] = []
var _spawn := Vector2.ZERO
var _kill_cells := {}
var _dying := false
var _atlas_img: Image
var _thorn_cells := {}
var _thorn_center := {}

var map_json := ""
var tileset_path := ""
var location_name := "MAP"
var next_scene := ""
var prev_scene := ""
var show_location_name := true
var ground_layers: Array[String] = ["jalan"]
var ground_fill_layers: Array[String] = []
var shadow_layers: Array[String] = []
var behind_player_layers: Array[String] = []
var lit_night := false
var force_night := false
var night_tint := Color(0.30, 0.34, 0.58)
var rain_mode := "auto"
var night_eyes := true
var night_fireflies := true
var night_aurora := false
var _night_fx: CanvasLayer
var _sleeping := false
var _music_t := 0.0
var _cur_music := ""
var music_path := ""
var thorn_layers: Array[String] = []
var bg_dir := BG_DIR
var backgrounds: Array = BACKGROUNDS
var bg_boost := 1.15
var low_skip: Array[String] = LOW_SKIP
var clear_color := Color("4a8ab8")
var player_size_mult := 1.0
var spawn_override := Vector2(-1.0, -1.0)
var kill_text := ""
var kill_visible := false
var flat_tile_ids: Array[int] = []
var flat_tile_top := 12
var ambient_path := ""
var ambient_db := -6.0
var no_night_ambient := false
var reverb_sfx := false
var black_fill_layers: Array[String] = []
var black_fill_min_row := 0
var jump_boost := 1.0
var green_motes := false
var black_tint_layers: Array[String] = []
var hide_layers: Array[String] = []
const RiseMotes = preload("res://scripts/rise_motes.gd")
var player_glow := 0.0
var void_death_y := 1.0e9
var no_atmosphere := false
var _death_cause := ""
var kill_layers: Array[String] = ["instant_death"]
var void_color := Color(0, 0, 0, 0)
var underground_layers: Array[String] = []
var dialogs: Array = []

var _layers_data: Array = []
var _map_root: Node2D
var _ground_min_x := 0.0
var _ground_max_x := 0.0
var _ground_pts := {}


func _configure() -> void:
	pass


func _ready() -> void:
	_configure()
	_build_backgrounds()

	RenderingServer.set_default_clear_color(clear_color)

	var map := _build_map()
	_map_root = map
	add_child(map)

	_build_player(map)
	_build_kill_zones(map)
	_build_thorns(map)
	if enemies_enabled:
		_build_enemies()
	_build_shadows(map)
	_build_atmosphere()
	_build_ui()
	_build_hud()
	_build_pause()
	_build_touch()
	_build_inventory()
	_build_dialog()

	_show_errors()
	if GameState.pending_notice != "":
		_hud.show_notice(GameState.pending_notice, Color("ff9a8a"), 2.6)
		GameState.pending_notice = ""
	if force_night:
		DayNightScript.begin_forced_night(night_tint, get_instance_id(), lit_night)
	_cur_music = _wanted_music()
	if _cur_music != "":
		AudioManager.play_music_if_new(_cur_music, 3.0)
	if ambient_path != "":
		AudioManager.play_ambient(ambient_path, 3.0, ambient_db)
	elif not AudioManager.is_ambient_playing():
		AudioManager.play_ambient(AudioManager.AMBIENT_WIND)
	if no_night_ambient:
		AudioManager.stop_night_ambient()
	AudioManager.set_reverb(reverb_sfx)
	if green_motes:
		add_child(RiseMotes.new())

	if ResourceLoader.exists("res://scripts/cheat.gd"):
		var ch = load("res://scripts/cheat.gd")
		if ch != null:
			var c = ch.new()
			c.set("level", self)
			c.set("player", _player)
			add_child(c)


func _build_player(map: Node) -> void:
	var spawn_x := DEFAULT_SPAWN_X
	var best_x := 1000000
	var marker_y := -1
	for ld in _layers_data:
		if String(ld.get("name", "")).begins_with("Player"):
			for t in ld.get("tiles", []):
				if int(t.x) < best_x:
					best_x = int(t.x)
					spawn_x = int(t.x) * TILE + TILE / 2.0
					marker_y = int(t.y) * TILE
	if marker_y >= 0:
		var x := int(spawn_x)
		while x < int(_ground_max_x) and x < int(spawn_x) + 600:
			if _ground_pts.has(x) and _ground_pts[x] >= marker_y - 16.0:
				spawn_x = float(x)
				break
			x += 4
	var arrive := GameSettings.arrive_side
	GameSettings.arrive_side = ""
	var from_right := arrive == "right" and GameSettings.pending_load.is_empty()
	if from_right:
		spawn_x = _ground_max_x - 56.0
	var spawn_y := _ground_y_at(spawn_x) - 2.0
	if spawn_override.x >= 0.0 and not from_right:
		spawn_x = spawn_override.x
		spawn_y = spawn_override.y

	_player = PlayerScript.new()
	_player.size_mult = player_size_mult
	_player.jump_boost = jump_boost
	_player.min_x = maxf(12.0, _ground_min_x + 8.0)
	_player.max_x = _ground_max_x - 8.0
	_player.position = Vector2(spawn_x, spawn_y)
	_spawn = _player.position
	_player.died.connect(_on_player_died)
	var loaded: Dictionary = GameSettings.pending_load
	if not loaded.is_empty():
		_player.position = Vector2(loaded.x, loaded.y)
		GameSettings.pending_load = {}
	map.add_child(_player)
	if player_glow > 0.0:
		_add_player_glow()
	if not loaded.is_empty():
		_player.set_flip(loaded.flip)
	elif from_right:
		_player.set_flip(true)
	var place_order: Array = ground_layers if player_after_layer == "" else [player_after_layer]
	for n in place_order:
		for c in map.get_children():
			if c.has_meta("src_name") and c.get_meta("src_name") == n:
				map.move_child(_player, c.get_index() + 1)
				break
	for o in _objects:
		if is_instance_valid(o):
			map.move_child(o, _player.get_index())
			if "player" in o:
				o.player = _player
	var behind: Array = []
	for c in map.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) in behind_player_layers:
			behind.append(c)
	for c in behind:
		if c.get_index() > _player.get_index():
			map.move_child(c, _player.get_index())

	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	_cam.position = Vector2(0, -20)
	_cam.limit_left = int(maxf(0.0, _ground_min_x))
	_cam.limit_right = int(_ground_max_x)
	_cam.limit_top = cam_limit_top
	_cam.limit_bottom = cam_limit_bottom
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	_player.add_child(_cam)
	_cam.make_current()
	_cam.reset_smoothing()
	_cam0 = Vector2(maxf(320.0, spawn_x), spawn_y - 20.0)
	_bg_ready = true


func _build_map() -> Node2D:
	var root := Node2D.new()
	root.name = "Map"
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var tileset := load(tileset_path) as TileSet
	var json := load(map_json) as JSON
	if tileset == null or json == null or not (json.data is Dictionary):
		_errors.append("Map gagal dimuat: cek %s dan %s" % [map_json, tileset_path])
		return root

	if tile_collision:
		tileset = _fit_tile_collision(tileset)

	var layers: Array = json.data.get("layers", [])
	_layers_data = layers
	for i in range(layers.size() - 1, -1, -1):
		var ld: Dictionary = layers[i]
		var layer := TileMapLayer.new()
		layer.name = String(ld.get("name", "Layer%d" % i)).replace(" ", "_")
		layer.set_meta("src_name", String(layer.name).to_lower())
		layer.tile_set = tileset
		var is_ground := String(layer.name).to_lower() in ground_layers
		layer.collision_enabled = bool(ld.get("collider", false)) and (tile_collision or not is_ground) \
			and not (String(layer.name).to_lower() in thorn_layers)
		for t in ld.get("tiles", []):
			var id := int(t.id)
			layer.set_cell(Vector2i(int(t.x), int(t.y)), 0,
				Vector2i(id % SHEET_COLUMNS, floori(float(id) / SHEET_COLUMNS)))
		if String(layer.name).to_lower() in thorn_layers:
			for t in ld.get("tiles", []):
				_thorn_cells[Vector2i(int(t.x), int(t.y))] = int(t.id)
		if _is_kill_layer(String(layer.name).to_lower()):
			layer.visible = kill_visible
			layer.collision_enabled = false
			for t in ld.get("tiles", []):
				_kill_cells[Vector2i(int(t.x), int(t.y))] = true
		if layer.name == "Player_Spawn":
			layer.visible = false
		root.add_child(layer)
	_build_ground(root, tileset, layers)
	_build_objects(root)
	_trim_stray_underground(root)
	_build_void_fill(root)
	_snap_to_ground(root)
	return root


static func round_face(img: Image) -> void:
	var d := float(mini(img.get_width(), img.get_height()))
	var c := Vector2(img.get_width(), img.get_height()) * 0.5
	var rr := d * 0.5
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(c) > rr:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


static func inner_face(img: Image) -> void:
	var d := float(mini(img.get_width(), img.get_height()))
	var c := Vector2(img.get_width(), img.get_height()) * 0.5
	var rr := d * 0.5 - maxf(2.0, roundf(d * 0.12))
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x + 0.5, y + 0.5).distance_to(c) > rr:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


func _cluster_art(layer: TileMapLayer, group: Array) -> Array:
	if _atlas_img == null:
		return []
	var minx := 1000000
	var miny := 1000000
	var maxx := -1000000
	var maxy := -1000000
	for c in group:
		minx = mini(minx, c.x)
		miny = mini(miny, c.y)
		maxx = maxi(maxx, c.x)
		maxy = maxi(maxy, c.y)
	var img := Image.create((maxx - minx + 1) * TILE, (maxy - miny + 1) * TILE, false, Image.FORMAT_RGBA8)
	for c in group:
		var ac := layer.get_cell_atlas_coords(c)
		img.blit_rect(_atlas_img, Rect2i(ac.x * TILE, ac.y * TILE, TILE, TILE), Vector2i((c.x - minx) * TILE, (c.y - miny) * TILE))
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return []
	var crop := img.get_region(used)
	return [ImageTexture.create_from_image(crop), Rect2(Vector2(minx * TILE + used.position.x, miny * TILE + used.position.y), Vector2(used.size))]


func _build_black_fill(root: Node2D) -> void:
	for lay in root.get_children():
		if lay is TileMapLayer:
			var nm := String(lay.get_meta("src_name", ""))
			if nm in black_tint_layers:
				(lay as TileMapLayer).modulate = Color.BLACK
			if nm in hide_layers:
				(lay as TileMapLayer).visible = false
	if black_fill_layers.is_empty():
		return
	var bottoms := {}
	for lay in root.get_children():
		if lay is TileMapLayer and String(lay.get_meta("src_name", "")) in black_fill_layers:
			for c in (lay as TileMapLayer).get_used_cells():
				bottoms[c.x] = maxi(int(bottoms.get(c.x, -1000000)), c.y)
	var xs: Array = bottoms.keys()
	xs.sort()
	var end_y := float(cam_limit_bottom) + 500.0
	var i := 0
	while i < xs.size():
		var x0: int = xs[i]
		var by: int = bottoms[x0]
		if by < black_fill_min_row:
			i += 1
			continue
		var j := i
		while j + 1 < xs.size() and int(xs[j + 1]) == int(xs[j]) + 1 and int(bottoms[xs[j + 1]]) == by:
			j += 1
		var x1: int = xs[j]
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.position = Vector2(x0 * TILE, (by + 1) * TILE - 1)
		r.size = Vector2((x1 - x0 + 1) * TILE, end_y - r.position.y)
		root.add_child(r)
		root.move_child(r, 0)
		i = j + 1


func _build_objects(root: Node2D) -> void:
	_build_black_fill(root)
	if _atlas_img == null or (pushable_layers.is_empty() and barrel_layers.is_empty()):
		return
	var box_parts: Array = []
	for lay in root.get_children().duplicate():
		if not (lay is TileMapLayer):
			continue
		var lname := String(lay.get_meta("src_name", ""))
		var is_box := lname in pushable_layers
		var is_barrel := lname in barrel_layers
		if not is_box and not is_barrel:
			continue
		var layer := lay as TileMapLayer
		for group in _tile_clusters(layer):
			if is_box:
				box_parts.append({"layer": layer, "cells": group})
				continue
			if is_barrel and group.size() < barrel_min_tiles:
				continue
			var art := _cluster_art(layer, group)
			if art.is_empty():
				continue
			var tex: Texture2D = art[0]
			var r: Rect2 = art[1]
			for c in group:
				layer.erase_cell(c)
			var d := int(minf(r.size.x, r.size.y))
			var face := Image.create(d, d, false, Image.FORMAT_RGBA8)
			face.blit_rect(tex.get_image(), Rect2i(0, int(r.size.y) - d, d, d), Vector2i.ZERO)
			inner_face(face)
			var fr := Rect2(r.position.x, r.end.y - d, d, d)
			var barrel: CharacterBody2D = CharacterBody2D.new()
			barrel.set_script(BarrelScript)
			barrel.set("fall_limit", float(cam_limit_bottom) + 400.0)
			_attach_barrel_body(barrel, tex, r, d, fr)
			if String(lay.get_meta("src_name", "")) == "barrel_fall":
				barrel.set("wake_dy", 1400.0)
			barrel.call("setup", ImageTexture.create_from_image(face), float(d) * 0.5, fr.get_center(), null)
			root.add_child(barrel)
			_objects.append(barrel)
	_build_box_objects(root, box_parts)


func _part_top(part: Dictionary) -> int:
	var t := 1000000
	for c in part.cells:
		t = mini(t, c.y)
	return t


func _attach_barrel_body(barrel: Object, tex: Texture2D, r: Rect2, _d: int, fr: Rect2) -> void:
	barrel.set("body_tex", tex)
	barrel.set("body_offset", r.get_center() - fr.get_center())


func _uf_find(parent: Array, i: int) -> int:
	while int(parent[i]) != i:
		parent[i] = parent[int(parent[i])]
		i = int(parent[i])
	return i


func _parts_touch(set_a: Dictionary, cells_b: Array) -> bool:
	for c in cells_b:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if set_a.has(Vector2i(c.x + dx, c.y + dy)):
					return true
	return false


func _build_box_objects(root: Node2D, parts: Array) -> void:
	if parts.is_empty():
		return
	if _atlas_img.get_format() != Image.FORMAT_RGBA8:
		_atlas_img.convert(Image.FORMAT_RGBA8)
	var n := parts.size()
	var parent: Array = []
	var sets: Array = []
	for i in n:
		parent.append(i)
		var st := {}
		for c in parts[i].cells:
			st[c] = true
		sets.append(st)
	for i in n:
		for j in range(i + 1, n):
			if _uf_find(parent, i) != _uf_find(parent, j) and _parts_touch(sets[i], parts[j].cells):
				parent[_uf_find(parent, j)] = _uf_find(parent, i)
	var groups := {}
	for i in n:
		var root_i := _uf_find(parent, i)
		if not groups.has(root_i):
			groups[root_i] = []
		groups[root_i].append(i)
	for key in groups.keys():
		var idxs: Array = groups[key]
		var union := {}
		var minx := 1000000
		var miny := 1000000
		var maxx := -1000000
		var maxy := -1000000
		for i in idxs:
			for c in parts[i].cells:
				union[c] = true
				minx = mini(minx, c.x)
				miny = mini(miny, c.y)
				maxx = maxi(maxx, c.x)
				maxy = maxi(maxy, c.y)
		var img := Image.create((maxx - minx + 1) * TILE, (maxy - miny + 1) * TILE, false, Image.FORMAT_RGBA8)
		var order: Array = idxs.duplicate()
		order.sort_custom(func(a, b): return _part_top(parts[a]) > _part_top(parts[b]))
		for i in order:
			var layer: TileMapLayer = parts[i].layer
			for c in parts[i].cells:
				var ac := layer.get_cell_atlas_coords(c)
				img.blend_rect(_atlas_img, Rect2i(ac.x * TILE, ac.y * TILE, TILE, TILE), Vector2i((c.x - minx) * TILE, (c.y - miny) * TILE))
		var used := img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			continue
		for i in idxs:
			for c in parts[i].cells:
				(parts[i].layer as TileMapLayer).erase_cell(c)
		var origin := Vector2(minx * TILE, miny * TILE)
		var art_rect := Rect2(origin + Vector2(used.position), Vector2(used.size))
		var b := CharacterBody2D.new()
		b.set_script(PushableScript)
		b.position = Vector2(art_rect.position.x + art_rect.size.x * 0.5, art_rect.end.y)
		b.set("fall_limit", float(cam_limit_bottom) + 400.0)
		var spr := Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(img.get_region(used))
		spr.centered = false
		spr.position = Vector2(-art_rect.size.x * 0.5, -art_rect.size.y)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_child(spr)
		var rects: Array = []
		for y in range(miny, maxy + 1):
			var x := minx
			while x <= maxx:
				if not union.has(Vector2i(x, y)):
					x += 1
					continue
				var x0 := x
				while union.has(Vector2i(x + 1, y)):
					x += 1
				var px0 := (x0 - minx) * TILE
				var px1 := (x - minx + 1) * TILE
				var py0 := (y - miny) * TILE
				var lo := Vector2i(1000000, 1000000)
				var hi := Vector2i(-1, -1)
				for yy in range(py0, py0 + TILE):
					for xx in range(px0, px1):
						if img.get_pixel(xx, yy).a > 0.5:
							lo = Vector2i(mini(lo.x, xx), mini(lo.y, yy))
							hi = Vector2i(maxi(hi.x, xx), maxi(hi.y, yy))
				if hi.x >= 0:
					var rr := Rect2(Vector2(lo), Vector2(hi - lo + Vector2i.ONE))
					var merged := false
					for m in rects:
						if absf(m.position.x - rr.position.x) < 1.5 and absf(m.size.x - rr.size.x) < 1.5 and absf(m.end.y - rr.position.y) <= 1.5:
							m.size.y = rr.end.y - m.position.y
							merged = true
							break
					if not merged:
						rects.append(rr)
				x += 1
		for rr in rects:
			var col := CollisionShape2D.new()
			var sh := RectangleShape2D.new()
			sh.size = Vector2(maxf(rr.size.x - 2.0, 2.0), maxf(rr.size.y - 1.0, 2.0))
			col.shape = sh
			col.position = origin + rr.position + rr.size * 0.5 - b.position - Vector2(0.0, 0.5)
			b.add_child(col)
		root.add_child(b)
		_objects.append(b)


func _fit_tile_collision(src: TileSet) -> TileSet:
	var ts := src.duplicate(true) as TileSet
	var atlas := ts.get_source(0) as TileSetAtlasSource
	if atlas == null or atlas.texture == null or ts.get_physics_layers_count() == 0:
		return src
	var img := atlas.texture.get_image()
	if img == null:
		return src
	if img.is_compressed():
		img.decompress()
	var cols := maxi(1, int(img.get_width() / TILE))
	var seg := 4
	for i in atlas.get_tiles_count():
		var ac: Vector2i = atlas.get_tile_id(i)
		var td := atlas.get_tile_data(ac, 0)
		if td == null or td.get_collision_polygons_count(0) == 0:
			continue
		var ax := ac.x * TILE
		var ay := ac.y * TILE
		if ax + TILE > img.get_width() or ay + TILE > img.get_height():
			continue
		var top := PackedInt32Array()
		var bot := PackedInt32Array()
		for cx in TILE:
			var t := -1
			var b := -1
			for r in TILE:
				if img.get_pixel(ax + cx, ay + r).a > 0.5:
					if t < 0:
						t = r
					b = r
			top.append(t)
			bot.append(b)
		var rects: Array = []
		for sx in range(0, TILE, seg):
			var tsum := 0
			var bmax := -1
			var n := 0
			for cx in range(sx, sx + seg):
				if top[cx] >= 0:
					tsum += top[cx]
					bmax = maxi(bmax, bot[cx])
					n += 1
			if n == 0:
				continue
			var y0 := int(roundf(float(tsum) / float(n) / 2.0)) * 2
			var y1 := clampi(bmax + 1, y0 + 1, TILE)
			if ground_sink > 4.0 and (y1 - y0) <= 3:
				continue
			rects.append([sx, sx + seg, y0, y1])
		if (ac.y * cols + ac.x) in flat_tile_ids:
			rects = [[0, TILE, flat_tile_top, TILE]]
		var merged: Array = []
		for r in rects:
			if not merged.is_empty():
				var m: Array = merged[merged.size() - 1]
				if m[1] == r[0] and m[2] == r[2] and m[3] == r[3]:
					m[1] = r[1]
					continue
			merged.append(r.duplicate())
		while td.get_collision_polygons_count(0) > 0:
			td.remove_collision_polygon(0, 0)
		var h := TILE / 2.0
		for m in merged:
			var k := td.get_collision_polygons_count(0)
			td.add_collision_polygon(0)
			var ytop := minf(float(m[2]) + ground_sink, float(m[3]) - 1.0) - h
			td.set_collision_polygon_points(0, k, PackedVector2Array([
				Vector2(m[0] - h, ytop), Vector2(m[1] - h, ytop),
				Vector2(m[1] - h, m[3] - h), Vector2(m[0] - h, m[3] - h)]))
	return ts


func _build_void_fill(root: Node2D) -> void:
	if void_color.a <= 0.0 or _ground_pts.is_empty():
		return
	var xs: Array = _ground_pts.keys()
	xs.sort()
	var lowest := -1.0e9
	for x in xs:
		lowest = maxf(lowest, float(_ground_pts[x]))
	var bottom := lowest + 1600.0
	var runs: Array = []
	var cur: Array = []
	for x in xs:
		if not cur.is_empty() and int(x) - int(cur[cur.size() - 1]) > 8:
			runs.append(cur)
			cur = []
		cur.append(int(x))
	if not cur.is_empty():
		runs.append(cur)
	for i in runs.size():
		var run: Array = runs[i]
		var xa: int = run[0]
		var xb: int = run[run.size() - 1]
		var pts := PackedVector2Array()
		var left_pad := 48.0 if i == 0 else 0.0
		var right_pad := 48.0 if i == runs.size() - 1 else 0.0
		pts.append(Vector2(xa - left_pad, float(_ground_pts[xa]) + VOID_INSET))
		var x := xa
		while x < xb:
			pts.append(Vector2(x, float(_ground_pts[x]) + VOID_INSET))
			x += 4
		pts.append(Vector2(xb + right_pad, float(_ground_pts[xb]) + VOID_INSET))
		pts.append(Vector2(xb + right_pad, bottom))
		pts.append(Vector2(xa - left_pad, bottom))
		var poly := Polygon2D.new()
		poly.name = "VoidFill"
		poly.color = void_color
		poly.polygon = pts
		root.add_child(poly)
		root.move_child(poly, 0)


func _trim_stray_underground(root: Node2D) -> void:
	if underground_layers.is_empty():
		return
	for c in root.get_children():
		if not (c is TileMapLayer) or not (String(c.get_meta("src_name", "")) in underground_layers):
			continue
		var layer := c as TileMapLayer
		for cell in layer.get_used_cells():
			var surf := 1.0e9
			for dx in TILE:
				var xi := cell.x * TILE + dx
				if _ground_pts.has(xi):
					surf = minf(surf, float(_ground_pts[xi]))
			if surf < 1.0e8 and float((cell.y + 1) * TILE) <= surf - 8.0:
				layer.erase_cell(cell)


func _snap_to_ground(root: Node2D) -> void:
	for lay in root.get_children().duplicate():
		if not (lay is TileMapLayer) or not (String(lay.get_meta("src_name", "")) in snap_layers):
			continue
		var src := lay as TileMapLayer
		var ts := 16
		for group in _tile_clusters(src):
			var minx := 99999
			var maxx := -99999
			var maxy := -99999
			for c in group:
				minx = mini(minx, c.x)
				maxx = maxi(maxx, c.x)
				maxy = maxi(maxy, c.y)
			var x0 := float(minx * ts) + 2.0
			var x1 := float((maxx + 1) * ts) - 2.0
			var gy := maxf(_ground_y_at(x0), _ground_y_at(x1))
			gy = maxf(gy, _ground_y_at((x0 + x1) * 0.5))
			var delta := clampf(gy - float((maxy + 1) * ts) + 1.0, -24.0, 24.0)
			var piece := TileMapLayer.new()
			piece.name = String(src.name) + "_c"
			piece.set_meta("src_name", src.get_meta("src_name"))
			piece.tile_set = src.tile_set
			piece.collision_enabled = src.collision_enabled
			for c in group:
				piece.set_cell(c, 0, src.get_cell_atlas_coords(c))
			piece.position = Vector2(0, delta)
			root.add_child(piece)
			root.move_child(piece, src.get_index())
		src.queue_free()


func _build_ground(root: Node2D, tileset: TileSet, layers: Array) -> void:
	var atlas := tileset.get_source(0) as TileSetAtlasSource
	if atlas == null or atlas.texture == null:
		_errors.append("Tileset tidak punya atlas: " + tileset_path)
		return
	var img := atlas.texture.get_image()
	_atlas_img = img
	var tops := {}
	var surf := {}
	var surf_fill := {}
	for ld in layers:
		var lname := String(ld.get("name", "")).replace(" ", "_").to_lower()
		var primary := lname in ground_layers
		if not primary and not (lname in ground_fill_layers):
			continue
		var target: Dictionary = surf if primary else surf_fill
		for t in ld.get("tiles", []):
			var id := int(t.id)
			if not tops.has(id):
				var arr := PackedInt32Array()
				arr.resize(TILE)
				var ax := (id % SHEET_COLUMNS) * TILE
				var ay := floori(float(id) / SHEET_COLUMNS) * TILE
				for cx in TILE:
					arr[cx] = -1
					for r in TILE:
						if img.get_pixel(ax + cx, ay + r).a > 0.5:
							arr[cx] = r
							break
				tops[id] = arr
			var a: PackedInt32Array = tops[id]
			for cx in TILE:
				if a[cx] >= 0:
					var x := int(t.x) * TILE + cx
					var y := int(t.y) * TILE + a[cx]
					if not target.has(x) or y < target[x]:
						target[x] = y
	for fx in surf_fill:
		if not surf.has(fx):
			surf[fx] = surf_fill[fx]
	if surf.is_empty():
		_errors.append("Layer tanah kosong: %s" % [ground_layers])
		return

	var xs: Array = surf.keys()
	xs.sort()
	var x0: int = xs[0]
	var x1: int = xs[xs.size() - 1]
	var raw := {}
	for x in range(x0, x1 + 1):
		if surf.has(x):
			raw[x] = float(surf[x])
	var gap_start := -1
	for x in range(x0, x1 + 2):
		if raw.has(x):
			if gap_start >= 0 and x - gap_start <= 40 and raw.has(gap_start - 1):
				var ya: float = raw[gap_start - 1]
				var yb: float = raw[x]
				for gx in range(gap_start, x):
					raw[gx] = lerpf(ya, yb, float(gx - gap_start + 1) / float(x - gap_start + 1))
			gap_start = -1
		elif gap_start < 0:
			gap_start = x
	var radius := 6
	_ground_pts.clear()
	for x in range(x0, x1 + 1):
		if not raw.has(x):
			continue
		var sum := 0.0
		var n := 0
		for k in range(x - radius, x + radius + 1):
			if raw.has(k):
				sum += raw[k]
				n += 1
		_ground_pts[x] = sum / float(n) + foot_offset
	_ground_min_x = float(x0)
	_ground_max_x = float(x1)

	var segs := PackedVector2Array()
	var step := 4
	var prev_x := -1
	for x in range(x0, x1 + 1, step):
		if not _ground_pts.has(x):
			prev_x = -1
			continue
		if prev_x >= 0:
			segs.append(Vector2(prev_x, _ground_pts[prev_x]))
			segs.append(Vector2(x, _ground_pts[x]))
		prev_x = x
	if tile_collision:
		return
	var body := StaticBody2D.new()
	body.name = "GroundCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segs
	cs.shape = shape
	body.add_child(cs)
	root.add_child(body)


func _ground_y_at(x: float) -> float:
	var xi := int(x)
	for d in range(0, 64):
		if _ground_pts.has(xi + d):
			return _ground_pts[xi + d]
		if _ground_pts.has(xi - d):
			return _ground_pts[xi - d]
	if tile_collision:
		for d in range(64, 1200, 4):
			if _ground_pts.has(xi + d):
				return _ground_pts[xi + d]
			if _ground_pts.has(xi - d):
				return _ground_pts[xi - d]
	return 200.0


func _show_errors() -> void:
	if _errors.is_empty():
		return
	for e in _errors:
		push_error(e)
	var lbl := Label.new()
	lbl.text = "\n".join(_errors)
	lbl.position = Vector2(24, 24)
	lbl.add_theme_color_override("font_color", Color("ff8a8a"))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	var ui := CanvasLayer.new()
	ui.layer = 50
	ui.add_child(lbl)
	add_child(ui)


func _build_backgrounds() -> void:
	_bg_root = Node2D.new()
	_bg_root.z_index = -100
	add_child(_bg_root)
	for d in backgrounds:
		var tex := load(bg_dir + d.file) as Texture2D
		if tex == null:
			_errors.append("Background tidak ditemukan: " + bg_dir + d.file)
			continue
		var layer := Node2D.new()
		_bg_root.add_child(layer)
		var bs: float = float(d.scale) * bg_boost
		var w: float = tex.get_width() * bs
		var copies := 3 if d.wrap else 1
		var x0: float = float(d.get("x", 0.0)) * bg_boost
		for i in copies:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			s.scale = Vector2(bs, bs)
			s.position = Vector2(i * w if d.wrap else x0, 0)
			layer.add_child(s)
		var top0: float = float(d.top) * bg_boost
		_bg_layers.append({"node": layer, "width": w, "move": d.move, "ymove": 0.0, "top": top0, "wrap": d.wrap, "x": x0, "file": d.file,
			"top0": top0, "base_scale": bs, "x0": x0, "tex_w": float(tex.get_width()), "extra": 1.0,
			"full": (top0 + tex.get_height() * bs) >= 150.0})
	GameSettings.graphics_changed.connect(_apply_render)
	_apply_render()


func _set_bg_scale(l: Dictionary, extra: float) -> void:
	var s: float = float(l.base_scale) * extra
	var w: float = float(l.tex_w) * s
	l["width"] = w
	l["top"] = float(l.top0) * extra
	l["extra"] = extra
	var i := 0
	for sp in (l.node as Node2D).get_children():
		(sp as Sprite2D).scale = Vector2(s, s)
		(sp as Sprite2D).position = Vector2(i * w if l.wrap else float(l.x0) * extra, 0.0)
		i += 1


func _apply_render() -> void:
	var low := GameSettings.render_map_index == 0
	for l in _bg_layers:
		var skip: bool = low and (l.file in low_skip)
		(l.node as Node2D).visible = not skip


func _physics_process(delta: float) -> void:
	if _leaving or _player == null:
		return
	_check_kill_zone()
	_check_thorns()
	_check_dialogs()
	if _edge_grace > 0.0:
		_edge_grace -= delta
		return
	var axis := Input.get_axis("move_left", "move_right")
	if exits_locked:
		return
	if next_scene != "" and _player.global_position.x >= _player.max_x - 1.0 and axis > 0.0:
		_goto(next_scene, "")
	elif not exit_choices.is_empty() and _player.global_position.x >= _player.max_x - 1.0 and axis > 0.0 and _choice_layer == null:
		_open_exit_choice()
	elif prev_scene != "" and _player.global_position.x <= _player.min_x + 1.0 and axis < 0.0:
		_goto(prev_scene, "right")


func _open_exit_choice() -> void:
	_player.controls_enabled = false
	_choice_layer = CanvasLayer.new()
	_choice_layer.layer = 60
	_choice_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_choice_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choice_layer.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.96)
	sb.border_color = Color("e8c964")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = exit_choice_title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e8c964"))
	box.add_child(title)
	var first: Button = null
	for ch in exit_choices:
		var b := Button.new()
		b.text = String(ch.label)
		b.custom_minimum_size = Vector2(260, 40)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(_choose_exit.bind(String(ch.scene)))
		box.add_child(b)
		if first == null:
			first = b
	var back := Button.new()
	back.text = "Kembali"
	back.custom_minimum_size = Vector2(260, 36)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_close_exit_choice)
	box.add_child(back)
	get_tree().paused = true
	AudioManager.play_ui("select")
	if first != null:
		first.grab_focus()


func _close_exit_choice() -> void:
	get_tree().paused = false
	if _choice_layer != null:
		_choice_layer.queue_free()
		_choice_layer = null
	AudioManager.play_ui("back")
	_player.controls_enabled = true
	_player.global_position.x -= 48.0
	_edge_grace = 0.8


func _choose_exit(scene: String) -> void:
	get_tree().paused = false
	if _choice_layer != null:
		_choice_layer.queue_free()
		_choice_layer = null
	AudioManager.play_ui("select")
	_goto(scene, "")


func _goto(scene: String, arrive_side: String) -> void:
	_leaving = true
	_player.controls_enabled = false
	if _inv:
		_inv.shutdown()
	GameSettings.arrive_side = arrive_side
	Transition.change_scene(scene, "wipe", 0.55)


var _shadow_tick := 0.0


func shake_camera(power: float, duration: float) -> void:
	_shake_pow = maxf(power, _shake_pow * clampf(_shake_t / _shake_total, 0.0, 1.0))
	_shake_t = duration
	_shake_total = maxf(duration, 0.01)


func _process(_delta: float) -> void:
	if _cam != null:
		if _shake_t > 0.0:
			_shake_t -= _delta
			var k := clampf(_shake_t / _shake_total, 0.0, 1.0)
			_cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_pow * k
		elif _cam.offset != Vector2.ZERO:
			_cam.offset = Vector2.ZERO
			_shake_pow = 0.0
	_shadow_tick -= _delta
	if _shadow_tick <= 0.0 and not _shadow_items.is_empty():
		_shadow_tick = 0.5
		_apply_shadows()
	if _daynight != null and not no_night_ambient:
		AudioManager.update_night_ambient(DayNightScript.darkness())
		_night_notice_tick()
	_music_tick(_delta)
	if not _bg_ready:
		return
	var cam := _cam.get_screen_center_position()
	var d := cam - _cam0
	var need_top: float = get_viewport().get_visible_rect().size.y / maxf(_cam.zoom.y, 0.01) * 0.5 + 24.0
	for l in _bg_layers:
		if l.full and float(l.top0) < 0.0:
			var extra := maxf(1.0, need_top / -float(l.top0))
			if absf(extra - float(l.extra)) > 0.01:
				_set_bg_scale(l, extra)
	for l in _bg_layers:
		var node: Node2D = l.node
		if not node.visible:
			continue
		var y: float = cam.y + l.top - l.ymove * d.y
		if l.wrap:
			var shift := fposmod(-l.move * d.x, l.width)
			node.position = Vector2(cam.x - l.width * 1.5 + shift, y)
		else:
			node.position = Vector2(cam.x, y)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	var name_lbl := Label.new()
	name_lbl.text = location_name
	name_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_lbl.offset_bottom = -150
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_override("font", load(FONT_TITLE))
	name_lbl.add_theme_font_size_override("font_size", 64)
	name_lbl.add_theme_color_override("font_color", Color("f6d776"))
	name_lbl.add_theme_color_override("font_outline_color", Color("1a0f3a"))
	name_lbl.add_theme_constant_override("outline_size", 10)
	name_lbl.modulate.a = 0.0
	name_lbl.visible = show_location_name
	root.add_child(name_lbl)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)

	if Transition.is_busy():
		_fade.color.a = 0.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, 0.2 if Transition.is_busy() else 1.4)
	t.tween_property(name_lbl, "modulate:a", 1.0, 0.8)
	t.tween_interval(2.2)
	t.tween_property(name_lbl, "modulate:a", 0.0, 1.2)


func _find_layer(map: Node, lname: String) -> TileMapLayer:
	for c in map.get_children():
		if c is TileMapLayer and String(c.name).to_lower() == lname:
			return c
	return null


func _tile_clusters(layer: TileMapLayer) -> Array:
	var left := {}
	for c in layer.get_used_cells():
		left[c] = true
	var out: Array = []
	for c in layer.get_used_cells():
		if not left.has(c):
			continue
		left.erase(c)
		var group: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		while not stack.is_empty():
			var cur: Vector2i = stack.pop_back()
			group.append(cur)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var n := cur + Vector2i(dx, dy)
					if left.has(n):
						left.erase(n)
						stack.append(n)
		out.append(group)
	return out


func _build_shadows(map: Node2D) -> void:
	if shadow_layers.is_empty():
		return
	var insert_at := 0
	for c in map.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) in ground_layers:
			insert_at = maxi(insert_at, c.get_index() + 1)
	var sources: Array[TileMapLayer] = []
	for c in map.get_children():
		if c is TileMapLayer and String(c.get_meta("src_name", "")) in shadow_layers:
			sources.append(c)
	for src in sources:
		if src.get_used_cells().size() > SHADOW_MAX_TILES:
			continue
		var lname := String(src.get_meta("src_name", "obj"))
		for group in _tile_clusters(src):
			var bottom := -1000000
			var min_x := 1000000
			var max_x := -1000000
			for cell in group:
				bottom = maxi(bottom, cell.y)
				min_x = mini(min_x, cell.x)
				max_x = maxi(max_x, cell.x)
			var yb := float(bottom + 1) * TILE
			if not _stands_on_ground(float(min_x * TILE), float((max_x + 1) * TILE), yb):
				continue
			for soft in [false, true]:
				var sh := TileMapLayer.new()
				sh.name = "Shadow_" + lname
				sh.tile_set = src.tile_set
				sh.collision_enabled = false
				sh.navigation_enabled = false
				sh.occlusion_enabled = false
				for cell in group:
					sh.set_cell(cell, 0, src.get_cell_atlas_coords(cell))
				map.add_child(sh)
				map.move_child(sh, insert_at)
				_shadow_items.append({"node": sh, "yb": yb, "soft": soft})
	GameSettings.graphics_changed.connect(_apply_shadows)
	_apply_shadows()


func _stands_on_ground(x0: float, x1: float, yb: float) -> bool:
	var best := 1.0e9
	var x := x0
	while x <= x1:
		var xi := int(x)
		if _ground_pts.has(xi):
			best = minf(best, absf(float(_ground_pts[xi]) - yb))
		x += 4.0
	return best <= 28.0


func _apply_shadows() -> void:
	var mode := GameSettings.shadow_index
	var p := FxLib.shadow_params(mode)
	for it in _shadow_items:
		var sh: TileMapLayer = it.node
		var soft: bool = it.soft
		sh.visible = mode > 0 and (not soft or mode >= 2)
		if not sh.visible:
			continue
		var g: float = float(p.soft_grow) if soft else 1.0
		sh.modulate = Color(0, 0, 0, (p.soft_alpha if soft else p.alpha) * DayNightScript.shadow_alpha_factor())
		sh.transform = FxLib.shadow_transform(it.yb, p.lean * g * DayNightScript.shadow_lean_factor(), p.squash * DayNightScript.shadow_length_factor() * g)
		if sh.material == null:
			sh.material = FxLib.shadow_material(float(it.yb), 130.0, 0.15)


func _build_hud() -> void:
	_hud = HudScript.new()
	add_child(_hud)
	_hud.setup(_player)


var music_override := ""


func _wanted_music() -> String:
	if music_override != "":
		return music_override
	if force_night:
		return music_path
	return NIGHT_MUSIC if DayNightScript.is_night() else music_path


var _shadow_t := 0.0


func _music_tick(delta: float) -> void:
	_shadow_t -= delta
	if _shadow_t <= 0.0:
		_shadow_t = 1.5
		_apply_shadows()
		for n in get_tree().get_nodes_in_group("pushable"):
			if n.has_method("_apply_shadows"):
				n.call("_apply_shadows")
	_music_t -= delta
	if _music_t > 0.0:
		return
	_music_t = 1.0
	var want := _wanted_music()
	if want != "" and want != _cur_music:
		_cur_music = want
		AudioManager.play_music_if_new(want, 2.5)


var _night_notice_day := 0


func _night_notice_tick() -> void:
	if force_night or _hud == null or _sleeping or not DayNightScript.is_night():
		return
	if _night_notice_day == DayNightScript.day:
		return
	_night_notice_day = DayNightScript.day
	pass


func _build_night_fx() -> void:
	_night_fx = NightFxScript.new()
	_night_fx.cam = _cam
	_night_fx.player = _player
	_night_fx.ground_fn = Callable(self, "_ground_y_at")
	_night_fx.x_min = _ground_min_x
	_night_fx.x_max = _ground_max_x
	_night_fx.use_eyes = night_eyes
	_night_fx.use_fireflies = false
	_night_fx.use_aurora = night_aurora
	_night_fx.rain = false
	add_child(_night_fx)


func _exit_tree() -> void:
	_exit_tree_drop()
	if ambient_path != "":
		AudioManager.stop_ambient(0.0)
	if force_night:
		DayNightScript.end_forced_night(get_instance_id())


func _sleep() -> void:
	if _sleeping or _leaving:
		return
	if force_night:
		_pause.show_toast("You can't sleep here.")
		AudioManager.play_ui("error")
		return
	_sleeping = true
	_pause.close()
	await get_tree().process_frame
	AudioManager.play_sfx_named("sleep")
	var cl := CanvasLayer.new()
	cl.layer = 99
	add_child(cl)
	var blk := ColorRect.new()
	blk.color = Color.BLACK
	blk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blk.modulate.a = 0.0
	cl.add_child(blk)
	var lab := Label.new()
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_override("font", load("res://assets/fonts/cinzel_decorative_bold.ttf"))
	lab.add_theme_font_size_override("font_size", 72)
	lab.add_theme_color_override("font_color", Color("f6d776"))
	lab.modulate.a = 0.0
	cl.add_child(lab)
	if _player != null:
		_player.controls_enabled = false
	var tw := create_tween()
	tw.tween_property(blk, "modulate:a", 1.0, 0.9)
	await tw.finished
	DayNightScript.sleep()
	if _player != null and _player.hp > 0:
		_player.hp = _player.max_hp
		_player.hp_changed.emit(_player.hp, _player.max_hp)
	var healed_faint := GameState.faints > 0.0
	if healed_faint:
		GameState.faints = maxf(0.0, GameState.faints - GameState.SLEEP_FAINT_HEAL)
	lab.text = "Day %d" % DayNightScript.day
	var tw2 := create_tween()
	tw2.tween_property(lab, "modulate:a", 1.0, 0.8)
	tw2.tween_interval(1.6)
	tw2.tween_property(lab, "modulate:a", 0.0, 0.7)
	tw2.tween_property(blk, "modulate:a", 0.0, 0.9)
	await tw2.finished
	cl.queue_free()
	if _player != null:
		_player.controls_enabled = true
	if healed_faint and _hud != null:
		_hud.show_notice("You slept well.  Faint recovered by half a life  (%s/%d)" % [GameState.faint_text(GameState.faints), GameState.MAX_FAINTS], Color("9be8a8"), 3.0)
	_sleeping = false


func _build_atmosphere() -> void:
	_atmo = AtmosphereScript.new()
	_atmo.use_canvas_modulate = false
	add_child(_atmo)
	_atmo.setup(_cam, _player)
	_daynight = DayNightScript.new()
	add_child(_daynight)
	_atmo.day_night = _daynight
	_atmo.effects_off = no_atmosphere
	_atmo.refresh()
	_build_night_fx()
	add_child(WindFxScript.new())
	add_child(ScreenFxScript.new())
	add_child(PerfMonitorScript.new())
	if wildlife_count > 0:
		_build_wildlife()


func _build_enemies() -> void:
	var total: int = maxi(1, int(round(float(ENEMY_COUNTS[clampi(GameState.difficulty, 0, ENEMY_COUNTS.size() - 1)]) * enemy_count_scale)))
	var x_from := maxf(_ground_min_x + 60.0, _player.position.x + 450.0)
	var x_to := _ground_max_x - 120.0
	if enemy_x_from >= 0.0:
		x_from = maxf(x_from, enemy_x_from)
	if enemy_x_to >= 0.0:
		x_to = minf(x_to, enemy_x_to)
	if x_to <= x_from:
		return
	var gfn := Callable(self, "_ground_y_at")
	for i in total:
		var x := x_from + (x_to - x_from) * (float(i) + randf_range(0.15, 0.85)) / float(total)
		var e: StaticBody2D = EnemyScript.new()
		e.free_float = tile_collision
		var roll := randf()
		var ek := "ghost"
		var acc := 0.0
		for m in ENEMY_MIX:
			acc += float(m[1])
			if roll < acc:
				ek = String(m[0])
				break
		if not enemy_kinds.is_empty():
			ek = enemy_kinds[randi() % enemy_kinds.size()]
		if ek != "ghost":
			var found := false
			for off in range(0, 240, 8):
				for sgn in [1, -1]:
					var xx := x + float(off * sgn)
					if _ground_pts.has(int(xx)) and _ground_pts.has(int(xx) - 14) and _ground_pts.has(int(xx) + 14):
						x = xx
						found = true
						break
				if found:
					break
			if not found:
				e.free()
				continue
		e.setup(ek, Vector2(x, _ground_y_at(x)), _player, gfn, _ground_min_x + 20.0, _ground_max_x - 20.0)
		add_child(e)


func _build_wildlife() -> void:
	if not GameSettings.wildlife:
		return
	var n := randi_range(wildlife_count, wildlife_count + 10)
	var span := _ground_max_x - _ground_min_x
	for i in n:
		var x := _ground_min_x + 40.0 + span * (float(i) + randf()) / float(n)
		x = clampf(x, _ground_min_x + 20.0, _ground_max_x - 20.0)
		var d: StaticBody2D = DragonflyScript.new()
		var small := randf() < 0.5
		d.setup(Vector2(x, _ground_y_at(x) - randf_range(30.0, 90.0)), randf_range(0.8, 1.0) if small else randf_range(1.2, 1.5))
		add_child(d)


func _build_dialog() -> void:
	_dialog = DialogBox.new()
	add_child(_dialog)


func _check_dialogs() -> void:
	if dialogs.is_empty() or _dialog_active or _leaving or _dying or _player == null or _dialog == null:
		return
	if not _player.controls_enabled or _player.hp <= 0 or get_tree().paused or _fade.color.a > 0.3:
		return
	var px := _player.global_position.x
	for d in dialogs:
		var id := String(d.get("id", ""))
		if id == "" or GameState.seen_dialogs.has(id):
			continue
		var x0 := float(d.get("x", 0.0))
		if px >= x0 and px <= x0 + float(d.get("width", DIALOG_ZONE)):
			GameState.seen_dialogs[id] = true
			_run_dialog(String(d.get("speaker", "")), d.get("lines", []), d.get("emotes", []))
			return


func _emote(emote: String, hold := 1.4) -> void:
	if _player != null and is_instance_valid(_player):
		EmoteBubble.play_on(_player, emote, hold)


func _open_dialog(speaker: String, lines: Array, emotes: Array = [], hold := false) -> void:
	var cb := func(i: int):
		if i < emotes.size() and String(emotes[i]) != "":
			_emote(String(emotes[i]), 60.0)
		else:
			EmoteBubble.clear_on(_player)
	if not emotes.is_empty():
		_dialog.page_started.connect(cb)
	_dialog.open(speaker, lines, hold)
	await _dialog.finished
	if _dialog.page_started.is_connected(cb):
		_dialog.page_started.disconnect(cb)
	if not hold:
		EmoteBubble.clear_on(_player)


func _run_dialog(speaker: String, lines: Array, emotes: Array = []) -> void:
	_dialog_active = true
	_player.controls_enabled = false
	if _touch_ui:
		_touch_ui.suspended = true
	await _open_dialog(speaker, lines, emotes)
	_dialog_active = false
	if _touch_ui:
		_touch_ui.suspended = false
	if not _leaving and not _dying and _player.hp > 0:
		_player.controls_enabled = true


func _build_touch() -> void:
	_touch_ui = TouchScript.new()
	add_child(_touch_ui)


func _build_inventory() -> void:
	_inv = InventoryUI.new()
	add_child(_inv)
	_inv.setup(_player)
	if not Inventory.dropped.is_connected(_on_item_dropped):
		Inventory.dropped.connect(_on_item_dropped)


func _on_item_dropped(item: Dictionary) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pk = load("res://scripts/item_pickup.gd").new()
	var x: float = _player.global_position.x + _player._facing() * 22.0
	_map_root.add_child(pk)
	pk.setup(item, _player, Vector2(x, _ground_y_at(x)))


func _exit_tree_drop() -> void:
	if Inventory.dropped.is_connected(_on_item_dropped):
		Inventory.dropped.disconnect(_on_item_dropped)


func _build_pause() -> void:
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.save_slot_chosen.connect(_save_state)
	_pause.load_slot_chosen.connect(_load_state)
	_pause.quit_requested.connect(_quit_to_title)
	_pause.sleep_requested.connect(_sleep)


func _save_state(slot_choice: int) -> void:
	if not GameState.can_save():
		_pause.show_toast("No save slots left!")
		AudioManager.play_ui("error")
		return
	var slot := GameState.write_save(scene_file_path, location_name, _player, slot_choice)
	if slot > 0:
		_pause.show_toast("Saved to slot %d!  %s" % [slot, GameState.saves_left_text()])
		AudioManager.play_ui("select")
	else:
		_pause.show_toast("Failed to save")
		AudioManager.play_ui("error")
	_pause.refresh_info()


func _load_state(slot: int) -> void:
	if _leaving:
		return
	var path := GameState.load_slot(slot, scene_file_path)
	if path == "":
		_pause.show_toast("Save data not found")
		AudioManager.play_ui("error")
		return
	_leaving = true
	_pause.enabled = false
	_pause.close()
	if _inv:
		_inv.shutdown()
	_player.controls_enabled = false
	AudioManager.stop_music(0.8)
	AudioManager.stop_night_ambient()
	Transition.change_scene(path, "wipe", 0.55)


func _quit_to_title() -> void:
	if _leaving:
		return
	_leaving = true
	_pause.enabled = false
	_pause.close()
	if _inv:
		_inv.shutdown()
	_player.controls_enabled = false
	AudioManager.stop_music(0.8)
	AudioManager.stop_night_ambient()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.8)
	t.tween_callback(func(): get_tree().change_scene_to_file(TITLE_SCENE))


func _is_kill_layer(lname: String) -> bool:
	for k in kill_layers:
		if lname.begins_with(k):
			return true
	return false


func _build_kill_zones(_map: Node) -> void:
	pass


func _check_kill_zone() -> void:
	if _player != null and not _dying and _player.global_position.y > void_death_y:
		_death_cause = ""
		_player.take_damage(_player.hp)
		return
	if _kill_cells.is_empty() or _dying or _player == null:
		return
	var p := _player.global_position
	for off in [-2.0, -16.0]:
		var cell := Vector2i(floori(p.x / TILE), floori((p.y + off) / TILE))
		if _kill_cells.has(cell):
			_death_cause = kill_text
			_player.take_damage(_player.hp)
			return


func _on_player_died() -> void:
	if _dying or _leaving:
		return
	_dying = true
	_player.controls_enabled = false
	AudioManager.play_sfx_named("hurt")
	GameState.faints += 1.0
	if GameState.faints >= GameState.MAX_FAINTS:
		_game_over()
		return
	_hud.show_notice(_death_msg(), Color("ff9a8a"), 1.6)
	_leaving = true
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.45)
	t.tween_callback(_reload_after_faint)


func crush_death() -> void:
	if _dying or _leaving or _player == null:
		return
	_dying = true
	_player.controls_enabled = false
	GameState.faints = GameState.MAX_FAINTS
	var spr = _player.get("_sprite")
	if spr != null:
		var tw := create_tween()
		tw.tween_property(spr, "scale:y", 0.06, 0.1)
	AudioManager.play_sfx_named("hurt")
	_player.velocity = Vector2.ZERO
	_game_over("You Are Death\nterjepit oleh tong, hanya menyisakan kulitnya saja")


func _game_over(msg: String = "Your character has fallen...\nThe journey begins again.") -> void:
	_leaving = true
	_pause.enabled = false
	_pause.close()
	if _inv:
		_inv.shutdown()
	_hud.show_notice((_death_cause + "\n" + msg) if _death_cause != "" else msg, Color("ff6a6a"), 3.4)
	AudioManager.stop_music(2.0)
	AudioManager.stop_night_ambient()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 1.0)
	t.tween_interval(3.0)
	t.tween_callback(func():
		GameState.restart_journey()
		get_tree().change_scene_to_file(RESTART_SCENE))


func _add_player_glow() -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.3, 0.3, 0.3, 1), Color(0, 0, 0, 1)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var l := PointLight2D.new()
	l.name = "PlayerGlow"
	l.texture = t
	l.texture_scale = 0.75
	l.energy = player_glow
	l.color = Color(0.78, 0.86, 1.0)
	l.position = Vector2(0.0, -18.0 * player_size_mult)
	_player.add_child(l)


func drop_loot(pos: Vector2, source: String = "enemy") -> void:
	var coins := 0
	var gems := 0
	match source:
		"enemy":
			coins = randi_range(1, 3) if randf() < 0.85 else 0
			gems = 1 if randf() < 0.30 else 0
		"bee":
			coins = 1 if randf() < 0.35 else 0
		"vase":
			coins = randi_range(0, 2)
			gems = 1 if randf() < 0.20 else 0
	for i in coins:
		_spawn_pickup("coin", pos)
	for i in gems:
		_spawn_pickup("gem", pos)
	if randf() < 0.01:
		var pk = load("res://scripts/item_pickup.gd").new()
		pk.setup(Inventory.potion_item(randi_range(0, 13), 1), _player, pos)
		add_child(pk)


func _spawn_pickup(kind: String, pos: Vector2) -> void:
	var p: Node2D = PickupScript.new()
	p.call("setup", kind, pos, _player)
	add_child(p)


func _make_moving(l: TileMapLayer) -> void:
	if l != null:
		l.use_kinematic_bodies = true


func _carry_needed() -> bool:
	return _player != null and _player.get_platform_velocity().length() < 0.5


func _death_msg() -> String:
	var m := "You fainted!  (%s/%d)\nOne more time and your journey starts over." % [GameState.faint_text(GameState.faints), GameState.MAX_FAINTS]
	if _death_cause != "":
		m = _death_cause + "\n" + m
	return m


func _reload_after_faint() -> void:
	_player.revive()
	GameState.hp = _player.max_hp
	GameState.has_stats = true
	GameState.pending_notice = _death_msg()
	GameSettings.arrive_side = ""
	GameSettings.pending_load = {}
	if _inv:
		_inv.shutdown()
	music_override = ""
	get_tree().change_scene_to_file(scene_file_path)


func _respawn() -> void:
	_player.global_position = _spawn
	_player.velocity = Vector2.ZERO
	_player.revive()
	_cam.reset_smoothing()


func _build_thorns(map: Node) -> void:
	for lname in thorn_layers:
		var lay := _find_layer(map, lname)
		if lay == null:
			continue
		for group in _tile_clusters(lay):
			var min_x := 1000000
			var max_x := -1000000
			for cell in group:
				min_x = mini(min_x, cell.x)
				max_x = maxi(max_x, cell.x)
			var cx := float(min_x + max_x + 1) * TILE / 2.0
			for cell in group:
				_thorn_center[cell] = cx


func _check_thorns() -> void:
	if _thorn_cells.is_empty() or _atlas_img == null or _dying or _player == null or not _player.can_be_thorned():
		return
	var p := _player.global_position
	for off in THORN_PROBES:
		var q: Vector2 = p + off
		var cell := Vector2i(floori(q.x / TILE), floori(q.y / TILE))
		if not _thorn_cells.has(cell):
			continue
		var id: int = _thorn_cells[cell]
		var px: int = (id % SHEET_COLUMNS) * TILE + posmod(floori(q.x), TILE)
		var py: int = floori(float(id) / SHEET_COLUMNS) * TILE + posmod(floori(q.y), TILE)
		if _atlas_img.get_pixel(px, py).a < 0.4:
			continue
		var cx: float = _thorn_center.get(cell, p.x)
		_player.thorn_hit(1.0 if p.x >= cx else -1.0)
		return
