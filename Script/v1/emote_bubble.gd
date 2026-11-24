extends Node2D

const SHEET := "res://assets/ui/bubble_emotes.png"
const CELL := 16
const FRAME_TIME := 0.09
const NODE_NAME := "EmoteBubble"
const HEAD_OFFSET := Vector2(0.0, -50.0)

const EMOTES := {
	"exclaim": {"row": 8, "cols": [0, 1, 2]},
	"question": {"row": 8, "cols": [3, 4, 5]},
	"shock": {"row": 10, "cols": [0, 1, 2]},
	"dots": {"row": 10, "cols": [3, 4, 5]},
	"sweat": {"row": 2, "cols": [6, 7, 8]},
	"idea": {"row": 2, "cols": [9, 10, 11]},
	"scribble": {"row": 0, "cols": [9, 10, 11]},
	"angry": {"row": 6, "cols": [9, 10, 11]},
	"sad": {"row": 6, "cols": [3, 4, 5]},
	"heart": {"row": 6, "cols": [0, 1, 2]},
	"blush": {"row": 6, "cols": [6, 7, 8]},
	"sleep": {"row": 4, "cols": [6, 7, 8]},
	"thumbs_up": {"row": 2, "cols": [0, 1, 2]},
	"skull": {"row": 4, "cols": [11, 11, 11]},
}

static var _tex: Texture2D

var _spr: Sprite2D
var _frames: Array = []
var _hold := 1.4
var _t := 0.0
var _closing := false


static func play_on(target: Node2D, emote: String, hold: float = 1.4) -> Node2D:
	if target == null or not is_instance_valid(target) or not EMOTES.has(emote):
		return null
	clear_on(target, true)
	var b := (load("res://scripts/emote_bubble.gd") as GDScript).new() as Node2D
	b.name = NODE_NAME
	b.set("_hold", hold)
	b.set("_frames", (EMOTES[emote]["cols"] as Array).map(func(c): return Vector2i(int(c), int(EMOTES[emote]["row"]))))
	target.add_child(b)
	return b


static func clear_on(target: Node2D, instant := false) -> void:
	if target == null or not is_instance_valid(target):
		return
	var old := target.get_node_or_null(NODE_NAME)
	if old == null:
		return
	if instant:
		target.remove_child(old)
		old.queue_free()
	elif old.has_method("close"):
		old.call("close")


func _ready() -> void:
	z_index = 40
	if _tex == null:
		_tex = load(SHEET) as Texture2D
	_spr = Sprite2D.new()
	_spr.texture = _tex
	_spr.region_enabled = true
	_spr.centered = false
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.position = Vector2(-CELL * 0.5, -CELL)
	add_child(_spr)
	var sm: float = 1.0
	var p := get_parent()
	if p != null and p.get("size_mult") != null:
		sm = float(p.get("size_mult"))
	position = HEAD_OFFSET * sm
	_set_frame(0)
	scale = Vector2(0.01, 0.01)
	_run()


func _set_frame(i: int) -> void:
	var c: Vector2i = _frames[clampi(i, 0, _frames.size() - 1)]
	_spr.region_rect = Rect2(c.x * CELL, c.y * CELL, CELL, CELL)


func _run() -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.15, FRAME_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(1, _frames.size()):
		tw.tween_callback(_set_frame.bind(i))
		tw.tween_interval(FRAME_TIME)
	tw.tween_property(self, "scale", Vector2.ONE, 0.06)
	tw.tween_interval(maxf(0.0, _hold))
	tw.tween_callback(close)


func _process(delta: float) -> void:
	_t += delta
	if not _closing:
		_spr.position.y = -CELL + sin(_t * 5.0) * 0.8


func close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(0.01, 0.01), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
