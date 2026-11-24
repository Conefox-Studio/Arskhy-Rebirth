extends Node2D

signal hero_exited

const BG_DIR := "res://assets/backgrounds/title/"
const MAP_SCENE := "res://maps/title/Map.tscn"
const LEAF_TEX := "res://assets/fx/leaf_sheet.png"
const HeroScript = preload("res://scripts/title_hero.gd")
const FxLib = preload("res://scripts/fx.gd")

const WORLD_H := 240.0
const ROAD_LEFT_FRAC := 0.60
const SURFACE_Y := 121.0
const SURFACE_SCREEN_FRAC := 0.665
var _map_w_px := 0.0
const ROAD_EXTEND := 14
const HERO_STOP_X := 26.0
const HERO_FEET_Y := 128.0
const TREE_LEFT_SHIFT := 0

const DAY_TIME := 120.0
const TO_NIGHT := 8.0
const NIGHT_TIME := 60.0
const TO_DAY := 8.0
const NIGHT_SKY := Color(0.20, 0.23, 0.44)
const NIGHT_WORLD := Color(0.30, 0.33, 0.55)
const NIGHT_LEAF := Color(0.55, 0.58, 0.78)

const SKY_LAYERS: Array = [
	{"file": "bg_photo.png", "speed": 0.0},
]

var hero: Node2D

var _clock := 0.0
var _night := 0.0
var _layers: Array = []
var _stars: Node2D
var _world: Node2D
var _map: Node
var _tree_shadows: Array = []
var _leaves: CPUParticles2D
var _tint_nodes: Array = []
var _hero_started := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_sky()
	_build_world()
	_build_leaves()
	get_viewport().size_changed.connect(_layout)
	GameSettings.graphics_changed.connect(_on_graphics_changed)
	_layout()
	_on_graphics_changed()
	_apply_time()


func _build_sky() -> void:
	for i in SKY_LAYERS.size():
		var def: Dictionary = SKY_LAYERS[i]
		var holder := Node2D.new()
		holder.name = "Sky_" + String(def.file).get_basename()
		add_child(holder)
		var tex := load(BG_DIR + String(def.file)) as Texture2D
		holder.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		for k in 3:
			var s := Sprite2D.new()
			s.texture = tex
			s.centered = false
			holder.add_child(s)
		_layers.append({"node": holder, "speed": float(def.speed), "w": 0.0, "tex": tex})
		_tint_nodes.append({"node": holder, "color": NIGHT_SKY})
		if i == 0:
			_stars = Node2D.new()
			_stars.name = "Stars"
			_stars.draw.connect(_draw_stars)
			add_child(_stars)


func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	_tint_nodes.append({"node": _world, "color": NIGHT_WORLD})

	var packed := load(MAP_SCENE) as PackedScene
	if packed != null:
		_map = packed.instantiate()
		_world.add_child(_map)
		var road := _map.get_node_or_null("Jalan_background_0") as TileMapLayer
		if road != null:
			var cells := road.get_used_cells()
			var mx := 0
			for c in cells:
				mx = maxi(mx, c.x)
			_map_w_px = float(mx + 1) * 16.0
			_extend_road(road)
		_lock_tree_left()
		_build_tree_shadows(road)

	hero = HeroScript.new()
	hero.name = "Hero"
	_world.add_child(hero)
	hero.exited.connect(func(): hero_exited.emit())


func _extend_road(road: TileMapLayer) -> void:
	var used := road.get_used_cells()
	if used.is_empty():
		return
	var max_x: int = used[0].x
	var rows := {}
	for c in used:
		max_x = maxi(max_x, c.x)
		rows[c.y] = true
	for x in range(max_x + 1, max_x + 1 + ROAD_EXTEND):
		for y in rows.keys():
			var from := Vector2i(x - 3, y)
			var sid := road.get_cell_source_id(from)
			if sid != -1:
				road.set_cell(Vector2i(x, y), sid, road.get_cell_atlas_coords(from))


func _lock_tree_left() -> void:
	var trees := _map.get_node_or_null("latar_belakang_pohon_1") as TileMapLayer
	if trees == null:
		return
	var used := trees.get_used_cells()
	if used.is_empty():
		return
	var min_x: int = used[0].x
	for c in used:
		min_x = mini(min_x, c.x)
	var shift := mini(min_x, TREE_LEFT_SHIFT)
	if shift <= 0:
		return
	var data := []
	for c in used:
		data.append([c, trees.get_cell_source_id(c), trees.get_cell_atlas_coords(c), trees.get_cell_alternative_tile(c)])
	trees.clear()
	for d in data:
		trees.set_cell(Vector2i(d[0].x - shift, d[0].y), d[1], d[2], d[3])


func _build_tree_shadows(road: TileMapLayer) -> void:
	var trees := _map.get_node_or_null("latar_belakang_pohon_1") as TileMapLayer
	if trees == null or road == null:
		return
	var insert_at := road.get_index() + 1
	for soft in [true, false]:
		var sh := TileMapLayer.new()
		sh.name = "TreeShadow" + ("Soft" if soft else "")
		sh.tile_set = trees.tile_set
		sh.collision_enabled = false
		sh.navigation_enabled = false
		sh.occlusion_enabled = false
		for cell in trees.get_used_cells():
			sh.set_cell(cell, trees.get_cell_source_id(cell), trees.get_cell_atlas_coords(cell))
		_map.add_child(sh)
		_map.move_child(sh, insert_at)
		_tree_shadows.append({"node": sh, "soft": soft})


func _build_leaves() -> void:
	var tex := MoonTex.load_tex(LEAF_TEX)
	if tex == null:
		return
	_leaves = CPUParticles2D.new()
	_leaves.name = "Leaves"
	_leaves.texture = tex
	_leaves.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_leaves.lifetime = 18.0
	_leaves.preprocess = 18.0
	_leaves.randomness = 1.0
	_leaves.local_coords = false
	_leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_leaves.direction = Vector2(-0.7, 1.0)
	_leaves.spread = 16.0
	_leaves.initial_velocity_min = 55.0
	_leaves.initial_velocity_max = 100.0
	_leaves.gravity = Vector2.ZERO
	_leaves.angle_min = 0.0
	_leaves.angle_max = 360.0
	_leaves.angular_velocity_min = -70.0
	_leaves.angular_velocity_max = 70.0
	_leaves.scale_amount_min = 0.11
	_leaves.scale_amount_max = 0.24
	var lm := CanvasItemMaterial.new()
	lm.particles_animation = true
	lm.particles_anim_h_frames = 6
	lm.particles_anim_v_frames = 2
	lm.particles_anim_loop = false
	_leaves.material = lm
	_leaves.anim_speed_min = 0.0
	_leaves.anim_speed_max = 0.0
	_leaves.anim_offset_min = 0.0
	_leaves.anim_offset_max = 1.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.04, 0.92, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	_leaves.color_ramp = fade
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(1.0, 0.78, 0.55), Color(1.0, 1.0, 0.85)])
	_leaves.color_initial_ramp = ramp
	add_child(_leaves)
	_tint_nodes.append({"node": _leaves, "color": NIGHT_LEAF})


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var w := size.x
	var h := size.y

	for l in _layers:
		var tex: Texture2D = l.tex
		var sc := maxf(h / tex.get_height(), w / tex.get_width())
		var node: Node2D = l.node
		var tw := tex.get_width() * sc
		l.w = tw
		var i := 0
		for s in node.get_children():
			(s as Sprite2D).scale = Vector2(sc, sc)
			(s as Sprite2D).position = Vector2(i * tw, h - tex.get_height() * sc)
			i += 1

	var zoom := maxf(h / WORLD_H, w / (WORLD_H * 2.2))
	_world.scale = Vector2(zoom, zoom)
	var wx := w * ROAD_LEFT_FRAC
	if _map_w_px > 0.0:
		wx = clampf(w - _map_w_px * zoom + 2.0 * zoom, w * 0.45, w * ROAD_LEFT_FRAC + 200.0 * zoom)
	_world.position = Vector2(wx, h * SURFACE_SCREEN_FRAC - SURFACE_Y * zoom)

	if _leaves != null:
		_leaves.position = Vector2(w * 0.62, -30.0)
		_leaves.emission_rect_extents = Vector2(w * 0.62 + 160.0, 8.0)

	_stars.queue_redraw()


func _screen_to_world_x(screen_x: float) -> float:
	return (screen_x - _world.position.x) / _world.scale.x


func start_hero() -> void:
	if _hero_started or hero == null:
		return
	_hero_started = true
	var w := get_viewport().get_visible_rect().size.x
	hero.start_enter(_screen_to_world_x(w) + 40.0, HERO_STOP_X, HERO_FEET_Y)


func hero_walk_out() -> void:
	var w := get_viewport().get_visible_rect().size.x
	hero.walk_out(_screen_to_world_x(w) + 70.0)


func _process(delta: float) -> void:
	_clock += delta
	for l in _layers:
		var sp: float = l.speed
		if sp == 0.0 or l.w <= 0.0:
			continue
		var node: Node2D = l.node
		node.position.x = fposmod(node.position.x + sp * delta, l.w) - l.w
	_apply_time()
	if _night > 0.01:
		_stars.queue_redraw()


func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _night_amount() -> float:
	if not GameSettings.day_night:
		return 0.0
	var t := fmod(_clock, DAY_TIME + TO_NIGHT + NIGHT_TIME + TO_DAY)
	if t < DAY_TIME:
		return 0.0
	t -= DAY_TIME
	if t < TO_NIGHT:
		return _smooth(t / TO_NIGHT)
	t -= TO_NIGHT
	if t < NIGHT_TIME:
		return 1.0
	t -= NIGHT_TIME
	return 1.0 - _smooth(t / TO_DAY)


func _apply_time() -> void:
	var n := _night_amount()
	var was_night := _night > 0.01
	_night = n
	for e in _tint_nodes:
		var node: CanvasItem = e.node
		node.modulate = Color.WHITE.lerp(e.color, n)
	if was_night and n <= 0.01:
		_stars.queue_redraw()


func _on_graphics_changed() -> void:
	var q := clampi(GameSettings.render_map_index, 0, 2)
	if _leaves != null:
		_leaves.amount = [16, 28, 44][q]
	var p := FxLib.shadow_params(GameSettings.shadow_index)
	for e in _tree_shadows:
		var sh: TileMapLayer = e.node
		sh.visible = GameSettings.shadow_index > 0 and (not bool(e.soft) or GameSettings.shadow_index >= 2)
		if not sh.visible:
			continue
		var g: float = float(p.soft_grow) if bool(e.soft) else 1.0
		sh.modulate = Color(0, 0, 0, float(p.soft_alpha) if bool(e.soft) else float(p.alpha))
		sh.transform = FxLib.shadow_transform(SURFACE_Y, float(p.lean) * g * 0.75, float(p.squash) * g * 0.6)


const DayNightTitle = preload("res://scripts/day_night.gd")
const MoonTex = preload("res://scripts/tex_util.gd")
const STAR_COUNT := 70
var _star_data: Array = []


func _make_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260
	for i in STAR_COUNT:
		_star_data.append({
			"x": rng.randf(), "y": rng.randf() * 0.5,
			"s": rng.randi_range(2, 4), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.8, 2.2),
		})


func _draw_stars() -> void:
	if _night <= 0.01:
		return
	if _star_data.is_empty():
		_make_stars()
	var size := get_viewport().get_visible_rect().size
	for st in _star_data:
		var tw := 0.55 + 0.45 * sin(_clock * float(st.sp) + float(st.ph))
		var a := _night * tw
		var px := Vector2(floorf(float(st.x) * size.x), floorf(float(st.y) * size.y))
		var s := float(st.s)
		_stars.draw_rect(Rect2(px, Vector2(s, s)), Color(0.95, 0.97, 1.0, a))
	var moon := Vector2(size.x * 0.80, size.y * 0.20)
	var r := size.y * 0.07
	var mtex: Texture2D = MoonTex.load_tex("res://assets/ui/moon_phases.png")
	if mtex != null:
		var fr := (DayNightTitle.day - 1) % 8
		for k in 5:
			_stars.draw_circle(moon, r * (2.6 - k * 0.4), Color(0.75, 0.82, 1.0, _night * 0.05))
		_stars.draw_texture_rect_region(mtex, Rect2(moon - Vector2(r, r), Vector2(r, r) * 2.0), Rect2(fr * 64, 0, 64, 64), Color(1, 1, 1, _night))
