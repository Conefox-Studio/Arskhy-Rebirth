extends RefCounted

const DUST := {
	"run":  {"tex": "res://assets/fx/dust_run.png",  "w": 64,  "h": 64, "n": 9,  "fps": 16.0},
	"dash": {"tex": "res://assets/fx/dash_smoke.png", "w": 48, "h": 32, "n": 8, "fps": 20.0},
	"land": {"tex": "res://assets/fx/dust_land.png", "w": 252, "h": 61, "n": 16, "fps": 22.0},
}
const BLOOD_COUNTS := [7, 9, 5, 10, 8, 8, 14, 7, 10]
const BLOOD_TEX := "res://assets/fx/blood_rows.png"

static var _cache := {}


static func _frames(key: String, tex_path: String, fw: int, fh: int, row: int, n: int, fps: float, cols: int = 0) -> SpriteFrames:
	if _cache.has(key):
		return _cache[key]
	var tex := load(tex_path) as Texture2D
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("play")
	sf.set_animation_loop("play", false)
	sf.set_animation_speed("play", fps)
	for i in n:
		var at := AtlasTexture.new()
		at.atlas = tex
		if cols > 0:
			at.region = Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
		else:
			at.region = Rect2(i * fw, row * fh, fw, fh)
		sf.add_frame("play", at)
	_cache[key] = sf
	return sf


static func _play(parent: Node, sf: SpriteFrames, pos: Vector2, scale: Vector2, z: int, rot: float = 0.0, offset := Vector2.ZERO) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = sf
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	s.scale = scale
	s.rotation = rot
	s.offset = offset
	s.z_index = z
	parent.add_child(s)
	s.animation_finished.connect(s.queue_free)
	s.play("play")
	return s


static func spawn_dust(parent: Node, kind: String, pos: Vector2, dir: float = 1.0, scale: float = 0.6) -> void:
	var d: Dictionary = DUST[kind]
	var sf := _frames("dust_" + kind, d.tex, d.w, d.h, 0, d.n, d.fps)
	var off := Vector2(0, -float(d.h) * 0.5 + 2.0)
	if kind == "run":
		off.x = -float(d.w) * 0.25
	elif kind == "dash":
		off.x = -11.0
		scale *= 2.2
	var sc := Vector2(scale, scale)
	if kind == "dash":
		sc.x *= dir
	elif kind != "land":
		sc.x *= -dir
	_play(parent, sf, pos, sc, 4, 0.0, off)


static func spawn_blood(parent: Node, pos: Vector2, dir: float = 1.0, kind: String = "hit") -> void:
	var row := 1
	var sc := 0.55
	match kind:
		"hurt":
			row = 1
			sc = 0.95
		"hit":
			row = 3
			sc = 0.8
		"small":
			row = 4
			sc = 0.5
	var sf := _frames("blood_%d" % row, BLOOD_TEX, 110, 93, row, BLOOD_COUNTS[row], 24.0)
	var s := _play(parent, sf, pos, Vector2(sc * -dir, sc), 6)
	s.offset = Vector2(0, -20)


static func spawn_air_burst(parent: Node, pos: Vector2) -> void:
	var sf := _frames("air_burst", "res://assets/fx/double_jump.png", 200, 127, 0, 19, 30.0, 5)
	_play(parent, sf, pos, Vector2(0.45, 0.45), 5, 0.0, Vector2(0, 23))


static func spawn_heal(parent: Node, pos: Vector2) -> void:
	var sf := _frames("heal_fx", "res://assets/fx/healed.png", 68, 84, 0, 48, 28.0, 8)
	_play(parent, sf, pos, Vector2(0.85, 0.85), 5, 0.0, Vector2(0, -36))


static func spawn_slash(parent: Node, kind: String, pos: Vector2, dir: float = 1.0, scale: float = 1.0) -> void:
	var path := "res://assets/fx/slash_hit.png" if kind == "hit" else "res://assets/fx/slash_hurt.png"
	var sf := _frames("slash_" + kind, path, 64, 64, 0, 6, 16.0)
	var sc := Vector2(scale * (dir if dir != 0.0 else 1.0), scale)
	_play(parent, sf, pos, sc, 7)
