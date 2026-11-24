extends Node2D

const TexUtil = preload("res://scripts/tex_util.gd")
const FxLib = preload("res://scripts/fx.gd")
const DIR := "res://assets/fx/magic/"
const FW := 72
const SFX_OF := {"fireball": "m_fireball", "spark": "m_spark", "wind": "m_wind", "sky_slash": "m_sky", "flame": "m_flame", "roots": "m_roots", "spikes": "m_spikes", "charm": "m_charm", "smoke": "m_smoke"}

const SPELLS := [
	{"name": "Fireball", "type": "proj", "file": "fireball", "frames": 4, "fps": 14.0, "speed": 230.0, "range": 260.0, "cost": 1, "dmg": 6, "scale": 2.2, "impact": "impact", "pierce": false},
	{"name": "Spark Bolt", "type": "proj", "file": "spark", "frames": 4, "fps": 16.0, "speed": 320.0, "range": 300.0, "cost": 1, "dmg": 4, "scale": 2.2, "impact": "impact", "pierce": false},
	{"name": "Wind Slash", "type": "proj", "file": "wind", "frames": 8, "fps": 20.0, "speed": 200.0, "range": 150.0, "cost": 1, "dmg": 5, "scale": 0.55, "impact": "", "pierce": true},
	{"name": "Sky Slash", "type": "ground", "file": "sky_slash", "frames": 8, "fps": 16.0, "ahead": 60.0, "cost": 2, "dmg": 8, "scale": 0.75, "hit_frame": 3, "w": 52.0},
	{"name": "Flame Pillar", "type": "ground", "file": "flame", "frames": 4, "fps": 9.0, "ahead": 54.0, "cost": 2, "dmg": 8, "scale": 1.4, "hit_frame": 1, "w": 40.0, "after": "flame_burst"},
	{"name": "Thorn Roots", "type": "ground", "file": "roots", "frames": 8, "fps": 14.0, "ahead": 56.0, "cost": 2, "dmg": 7, "scale": 0.85, "hit_frame": 3, "w": 56.0},
	{"name": "Stone Spikes", "type": "ground", "file": "spikes", "frames": 8, "fps": 14.0, "ahead": 64.0, "cost": 2, "dmg": 9, "scale": 0.85, "hit_frame": 3, "w": 58.0},
	{"name": "Charm", "type": "ground", "file": "charm", "frames": 8, "fps": 12.0, "ahead": 46.0, "cost": 1, "dmg": 3, "scale": 1.0, "hit_frame": 2, "w": 56.0, "from_air": true},
	{"name": "Smoke Veil", "type": "self", "file": "smoke", "frames": 8, "fps": 14.0, "cost": 1, "dmg": 0, "scale": 0.7, "iframes": 1.2},
]

static var _frames_cache := {}
static var current_name := ""


static func frames_for(file: String, count: int, fps: float, loop: bool) -> SpriteFrames:
	var key := "%s_%d_%s" % [file, count, str(loop)]
	if _frames_cache.has(key):
		return _frames_cache[key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("a")
	sf.set_animation_speed("a", fps)
	sf.set_animation_loop("a", loop)
	var tex := TexUtil.load_tex(DIR + file + ".png")
	if tex != null:
		for i in count:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FW, 0, FW, FW)
			sf.add_frame("a", at)
	_frames_cache[key] = sf
	return sf


static func cast(player: CharacterBody2D, idx: int) -> bool:
	var sp: Dictionary = SPELLS[clampi(idx, 0, SPELLS.size() - 1)]
	if not player.use_mp(int(sp.cost)):
		return false
	var fx = load("res://scripts/magic_fx.gd").new()
	var dir: float = player._facing()
	var parent := player.get_parent()
	parent.add_child(fx)
	fx.setup(sp, player, dir)
	return true


var spell: Dictionary
var dir := 1.0
var player: CharacterBody2D
var _spr: AnimatedSprite2D
var _hit_ids := {}
var _travel := 0.0
var _done_hit := false
var _impact := false


func setup(sp: Dictionary, p: CharacterBody2D, d: float) -> void:
	spell = sp
	player = p
	dir = d
	z_index = 6
	_spr = AnimatedSprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(float(sp.scale) * (1.0 if d > 0.0 else 1.0), float(sp.scale))
	_spr.flip_h = d < 0.0
	add_child(_spr)
	_spr.animation_finished.connect(_on_finished)
	_spr.frame_changed.connect(_on_frame)
	match String(sp.type):
		"proj":
			global_position = p.global_position + Vector2(d * 14.0, -20.0)
			_spr.sprite_frames = frames_for(sp.file, int(sp.frames), float(sp.fps), true)
		"self":
			global_position = p.global_position
			_spr.offset = Vector2(0, -FW * 0.5)
			_spr.sprite_frames = frames_for(sp.file, int(sp.frames), float(sp.fps), false)
			p.grant_invuln(float(sp.get("iframes", 1.0)))
		_:
			var from := p.global_position + Vector2(d * float(sp.ahead), -30.0)
			var drop: float = FxLib.ground_drop(p.get_world_2d().direct_space_state, from, 1 | 4, [p.get_rid()], 140.0)
			global_position = Vector2(from.x, from.y + (drop if drop >= 0.0 else 30.0))
			if bool(sp.get("from_air", false)):
				_spr.offset = Vector2(0, -FW * 0.5 - 18.0)
			else:
				_spr.offset = Vector2(0, -FW * 0.5)
			_spr.sprite_frames = frames_for(sp.file, int(sp.frames), float(sp.fps), false)
	_spr.play("a")
	AudioManager.play_sfx_named(SFX_OF.get(String(sp.file), "cast"))


func _physics_process(delta: float) -> void:
	if String(spell.type) != "proj" or _impact:
		return
	var step: float = float(spell.speed) * delta
	global_position.x += dir * step
	_travel += step
	if _damage_at(global_position, 9.0, 1.0) and not bool(spell.pierce):
		_start_impact()
	elif _travel >= float(spell.range):
		_start_impact()


func _start_impact() -> void:
	_impact = true
	AudioManager.play_sfx_named("m_impact")
	var imp := String(spell.impact)
	if imp == "":
		queue_free()
		return
	_spr.sprite_frames = frames_for(imp, 4, 18.0, false)
	_spr.scale = Vector2(1.4, 1.4)
	_spr.offset = Vector2.ZERO
	_spr.play("a")


func _on_frame() -> void:
	if String(spell.type) == "ground" and not _done_hit and _spr.frame >= int(spell.hit_frame):
		_done_hit = true
		var w: float = float(spell.w)
		_damage_rect(Rect2(global_position + Vector2(-w * 0.5, -46.0), Vector2(w, 52.0)))


func _on_finished() -> void:
	if String(spell.type) == "ground" and String(spell.get("after", "")) != "" and not _impact:
		_impact = true
		_spr.sprite_frames = frames_for(String(spell.after), 4, 14.0, false)
		_spr.play("a")
		return
	queue_free()


func _dmg() -> int:
	var mult := 2 if player != null and "range_active" in player and player.range_active else 1
	return int(spell.dmg) * mult


func _damage_at(pos: Vector2, radius: float, _unused: float) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var s := CircleShape2D.new()
	s.radius = radius
	q.shape = s
	q.transform = Transform2D(0.0, pos)
	q.collision_mask = 8
	return _apply(q)


func _damage_rect(r: Rect2) -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	var s := RectangleShape2D.new()
	s.size = r.size
	q.shape = s
	q.transform = Transform2D(0.0, r.get_center())
	q.collision_mask = 8
	return _apply(q)


func _apply(q: PhysicsShapeQueryParameters2D) -> bool:
	var any := false
	for r in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var body := r.collider as Node
		if body == null or _hit_ids.has(body.get_instance_id()):
			continue
		if body.is_in_group("ambient") or body.is_in_group("pushable"):
			continue
		if body.has_method("hit"):
			_hit_ids[body.get_instance_id()] = true
			body.set_meta("by_magic", true)
			body.call("hit", _dmg(), dir)
			body.set_meta("by_magic", false)
			any = true
			if player != null and player.has_method("restore_range"):
				player.restore_range(1)
	return any
