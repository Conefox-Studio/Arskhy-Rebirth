extends CanvasLayer

signal unlocked(id: String)

const PATH := "user://achievements.cfg"
const SFX_PATH := "res://assets/audio/sfx/achievement_unlocked.mp3"
const SHOW_TIME := 5.0
const UiSkin = preload("res://scripts/ui_skin.gd")
const LIST: Array = [
	{"id": "first_steps", "name": "First Steps", "desc": "Mulai perjalanan baru."},
	{"id": "pusher", "name": "Heavy Lifter", "desc": "Dorong sebuah kotak."},
	{"id": "barrel_roll", "name": "Barrel Roll", "desc": "Buat sebuah barel menggelinding."},
	{"id": "rage", "name": "Rage Unleashed", "desc": "Aktifkan Range Mode (Q)."},
	{"id": "ghost_hunter", "name": "Ghost Hunter", "desc": "Kalahkan Ghost Executor."},
	{"id": "hardcore", "name": "Hardcore Survivor", "desc": "Kalahkan Ghost Executor di mode Hardcore."},
	{"id": "demo_clear", "name": "Demo Complete", "desc": "Tamatkan demo sampai kredit."},
]

var _got := {}
var _queue: Array = []
var _showing := false
var _panel: PanelContainer
var _title: Label
var _name: Label
var _sfx: AudioStreamPlayer
var _show_left := 0.0


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for e in LIST:
			if bool(cfg.get_value("got", e.id, false)):
				_got[e.id] = true
	_build_toast()
	_build_sfx()


func is_unlocked(id: String) -> bool:
	return _got.has(id)


func count() -> int:
	return _got.size()


func unlock(id: String) -> void:
	if _got.has(id):
		return
	var info := {}
	for e in LIST:
		if e.id == id:
			info = e
	if info.is_empty():
		return
	_got[id] = true
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("got", id, true)
	cfg.save(PATH)
	unlocked.emit(id)
	_queue.append(info)
	if not _showing:
		_next_toast()


func _build_toast() -> void:
	_panel = PanelContainer.new()
	var sb: StyleBox = UiSkin.box("bar_blue", 10, 12.0)
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = Label.new()
	_title.text = "ACHIEVEMENT UNLOCKED"
	_title.add_theme_font_override("font", load("res://assets/fonts/pixelify_sans_bold.ttf"))
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", Color("f6e7a8"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_name = Label.new()
	_name.add_theme_font_override("font", load("res://assets/fonts/pixelify_sans.ttf"))
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color("efe6ff"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name)
	_panel.modulate.a = 0.0
	add_child(_panel)


func _build_sfx() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	var st: AudioStream = null
	if ResourceLoader.exists(SFX_PATH):
		st = load(SFX_PATH) as AudioStream
	elif FileAccess.file_exists(SFX_PATH):
		var mp := AudioStreamMP3.new()
		mp.data = FileAccess.get_file_as_bytes(SFX_PATH)
		st = mp
	_sfx.stream = st
	add_child(_sfx)


func _player_node() -> Node2D:
	var p := get_tree().get_first_node_in_group("player")
	return p as Node2D if p != null and is_instance_valid(p) else null


func _place_toast() -> void:
	var vs := get_viewport().get_visible_rect().size
	var pl := _player_node()
	var pos: Vector2
	if pl != null:
		var sp: Vector2 = get_viewport().get_canvas_transform() * pl.global_position
		if DeviceMode.is_touch():
			pos = Vector2(sp.x + 26.0, sp.y - 70.0 - _panel.size.y)
		else:
			pos = Vector2(sp.x + 26.0, sp.y - 14.0)
	else:
		pos = Vector2(vs.x - _panel.size.x - 20.0, 20.0)
	pos.x = clampf(pos.x, 6.0, maxf(6.0, vs.x - _panel.size.x - 6.0))
	pos.y = clampf(pos.y, 6.0, maxf(6.0, vs.y - _panel.size.y - 6.0))
	_panel.position = pos


func _process(delta: float) -> void:
	if _show_left > 0.0:
		_show_left -= delta
		_place_toast()


func _next_toast() -> void:
	if _queue.is_empty():
		_showing = false
		_show_left = 0.0
		return
	_showing = true
	var info: Dictionary = _queue.pop_front()
	_name.text = "* " + String(info.name)
	_panel.reset_size()
	_show_left = SHOW_TIME
	_place_toast()
	if _sfx != null and _sfx.stream != null:
		_sfx.play()
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(SHOW_TIME - 0.7)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next_toast)
