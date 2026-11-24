extends RefCounted

const TexUtil = preload("res://scripts/tex_util.gd")
const DIR := "res://assets/traps/all_traps_with_name/"
const SAW_TEX := DIR + "saw_trap_lv1__sheet-1024x64__frame-64x64__16f.png"
const FIRE_TEX := DIR + "fire_trap_lv3__sheet-384x64__frame-32x64__12f.png"
const ARROW_TEX := DIR + "arrow_trap_lv1__sheet-1632x32__frame-96x32__17f.png"
const ARROW_PROJ_TEX := DIR + "arrow_projectile__sheet-29x3__frame-29x3__1f.png"
const CEIL_BLOCK_TEX := "res://assets/traps/parts/ceiling_block__32x13.png"
const CEIL_CHAIN_TEX := "res://assets/traps/parts/ceiling_chain_tile__32x16.png"
const S := 2.0


static func tex(path: String) -> Texture2D:
	return TexUtil.load_tex(path)


static func player_rect(p: Node2D) -> Rect2:
	return Rect2(p.global_position + Vector2(-6.0, -34.0), Vector2(12.0, 34.0))


static func sprite(t: Texture2D, region: Rect2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.scale = Vector2(S, S)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s
