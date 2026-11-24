extends RefCounted

const TexUtil = preload("res://scripts/tex_util.gd")
const DIR := "res://assets/ui/darkages/"
static var _cache := {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = TexUtil.load_tex(DIR + name + ".png")
	return _cache[name]


static func box(name: String, margin: int, content: float = 0.0) -> StyleBox:
	var t := tex(name)
	if t == null:
		var f := StyleBoxFlat.new()
		f.bg_color = Color("2e322a")
		f.border_color = Color("dcc47c")
		f.set_border_width_all(2)
		return f
	var sb := StyleBoxTexture.new()
	sb.texture = t
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content
	sb.content_margin_bottom = content
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return sb


static func panel(content: float = 18.0) -> StyleBox:
	return box("panel_ornate", 22, content)


static func panel_dark(content: float = 14.0) -> StyleBox:
	return box("panel_dark_a", 14, content)


static func slot(selected: bool = false) -> StyleBox:
	return box("slot_gold" if selected else "slot_dark", 8, 4.0)


static func plaque(selected: bool = false) -> StyleBox:
	return box("bar_blue" if selected else "bar_dark", 10, 6.0)
