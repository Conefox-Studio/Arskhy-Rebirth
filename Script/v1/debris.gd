extends Node2D

const GRAVITY := 700.0
var _pieces: Array = []
var _t := 0.0
var _life := 1.6


static func burst(parent: Node, tex: Texture2D, rect: Rect2, count: int = 14, power: float = 1.0, src_region: Rect2 = Rect2()) -> void:
	if parent == null or tex == null:
		return
	var d = load("res://scripts/debris.gd").new()
	parent.add_child(d)
	d.z_index = 8
	d._fill(tex, rect, count, power, src_region)


func _fill(tex: Texture2D, rect: Rect2, count: int, power: float, src_region: Rect2) -> void:
	var sr := src_region if src_region.size.x > 0.0 else Rect2(Vector2.ZERO, tex.get_size())
	for i in count:
		var ps := randf_range(3.0, 7.0)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(sr.position + Vector2(randf() * maxf(1.0, sr.size.x - ps), randf() * maxf(1.0, sr.size.y - ps)), Vector2(ps, ps))
		var s := Sprite2D.new()
		s.texture = at
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = rect.position + Vector2(randf() * rect.size.x, randf() * rect.size.y)
		add_child(s)
		var c := rect.get_center()
		var out := (s.position - c)
		var v := Vector2(out.x * 2.0 + randf_range(-60, 60), -randf_range(60.0, 220.0) + out.y) * power
		_pieces.append({"n": s, "v": v, "w": randf_range(-9.0, 9.0)})


func _process(delta: float) -> void:
	_t += delta
	for p in _pieces:
		var n: Sprite2D = p.n
		p.v.y += GRAVITY * delta
		n.position += p.v * delta
		n.rotation += p.w * delta
		n.modulate.a = clampf((_life - _t) / 0.5, 0.0, 1.0)
	if _t >= _life:
		queue_free()
