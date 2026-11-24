extends CanvasLayer

const ADMIN_CODE := "arskhy-admin"
const TOGGLE_KEY := KEY_F9
const BIG := 99999999

var level: Node
var player: Node

var _unlocked := false
var _root: Control
var _code_box: PanelContainer
var _menu: PanelContainer
var _code_edit: LineEdit
var _code_msg: Label
var _badge: Label
var _opts := {"never_die": false, "invulnerable": false, "inf_health": false, "inf_magic": false, "inf_range": false,
	"inf_coins": false, "inf_gems": false, "spam_jump": false, "fast": false}
var _prev_controls := true


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_badge = Label.new()
	_badge.text = "CHEAT"
	_badge.position = Vector2(8, 6)
	_badge.add_theme_color_override("font_color", Color("ff5a5a"))
	_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.visible = false
	_root.add_child(_badge)
	_build_code_box()
	_build_menu()


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.10, 0.96)
	sb.border_color = Color("ff5a5a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", sb)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.visible = false
	return p


func _build_code_box() -> void:
	_code_box = _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_code_box.add_child(v)
	var t := Label.new()
	t.text = "ADMIN CODE"
	t.add_theme_color_override("font_color", Color("ff5a5a"))
	v.add_child(t)
	_code_edit = LineEdit.new()
	_code_edit.secret = true
	_code_edit.custom_minimum_size = Vector2(260, 0)
	_code_edit.placeholder_text = "enter code, press Enter"
	_code_edit.text_submitted.connect(_submit_code)
	v.add_child(_code_edit)
	_code_msg = Label.new()
	_code_msg.add_theme_color_override("font_color", Color("ffb0b0"))
	v.add_child(_code_msg)
	_root.add_child(_code_box)


func _build_menu() -> void:
	_menu = _panel()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_menu.add_child(v)
	var t := Label.new()
	t.text = "CHEAT MENU  (F9 close)"
	t.add_theme_color_override("font_color", Color("ff5a5a"))
	v.add_child(t)
	var rows := [["never_die", "Never Die"], ["invulnerable", "Invulnerable (kebal apapun)"], ["inf_health", "Infinite Health"],
		["inf_magic", "Infinite Magic"], ["inf_range", "Infinite Range"], ["inf_coins", "Infinite Coins"], ["inf_gems", "Infinite Gems"],
		["spam_jump", "Spam Jump"], ["fast", "Faster Speed (x2)"]]
	for r in rows:
		var cb := CheckButton.new()
		cb.text = r[1]
		cb.focus_mode = Control.FOCUS_NONE
		var key: String = r[0]
		cb.toggled.connect(func(on: bool):
			_opts[key] = on
			_apply_flags())
		v.add_child(cb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for b in [["Full HP", "hp"], ["Max Items", "items"], ["Close", "close"]]:
		var btn := Button.new()
		btn.text = b[0]
		btn.focus_mode = Control.FOCUS_NONE
		var act: String = b[1]
		btn.pressed.connect(func(): _action(act))
		row.add_child(btn)
	_root.add_child(_menu)


func _submit_code(txt: String) -> void:
	if txt == ADMIN_CODE:
		_unlocked = true
		_code_edit.text = ""
		_code_msg.text = ""
		_show(false, true)
	else:
		_code_msg.text = "Wrong code."
		_code_edit.text = ""


func _show(code: bool, menu: bool) -> void:
	_code_box.visible = code
	_menu.visible = menu
	var open := code or menu
	_root.mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if player != null and is_instance_valid(player):
		if open:
			_prev_controls = bool(player.get("controls_enabled"))
			player.set("controls_enabled", false)
		else:
			player.set("controls_enabled", _prev_controls and int(player.get("hp")) > 0)
	if code:
		_code_edit.grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == TOGGLE_KEY:
		var open := _code_box.visible or _menu.visible
		if open:
			_show(false, false)
		elif _unlocked:
			_show(false, true)
		else:
			_show(true, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE and (_code_box.visible or _menu.visible):
		_show(false, false)
		get_viewport().set_input_as_handled()


func _action(act: String) -> void:
	match act:
		"hp":
			_full_hp()
		"items":
			_max_items()
		"close":
			_show(false, false)


func _full_hp() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set("hp", int(player.get("max_hp")))
	player.set("mp", int(player.get("max_mp")))
	player.set("range_pts", int(player.get("max_range")))
	player.set("_bleed_ticks", 0)
	player.set("_poison", false)
	player.emit_signal("hp_changed", player.get("hp"), player.get("max_hp"))
	player.emit_signal("mp_changed", player.get("mp"), player.get("max_mp"))
	player.emit_signal("range_changed", player.get("range_pts"), player.get("max_range"))


func _max_items() -> void:
	for i in Inventory.POTIONS.size():
		for k in 5:
			Inventory.add_item(Inventory.potion_item(i, 99))
	Inventory.changed.emit()


func _apply_flags() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.set("god_mode", bool(_opts.never_die) or bool(_opts.invulnerable))
	player.set("spam_jump", bool(_opts.spam_jump))
	player.set("speed_mult", 2.0 if bool(_opts.fast) else 1.0)
	var any := false
	for k in _opts:
		any = any or bool(_opts[k])
	_badge.visible = any


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	if bool(_opts.inf_health) and int(player.get("hp")) > 0:
		if int(player.get("hp")) != int(player.get("max_hp")):
			player.set("hp", int(player.get("max_hp")))
			player.emit_signal("hp_changed", player.get("hp"), player.get("max_hp"))
	if bool(_opts.inf_magic) and int(player.get("mp")) != int(player.get("max_mp")):
		player.set("mp", int(player.get("max_mp")))
		player.emit_signal("mp_changed", player.get("mp"), player.get("max_mp"))
	if bool(_opts.inf_range) and int(player.get("range_pts")) != int(player.get("max_range")):
		player.set("range_pts", int(player.get("max_range")))
		player.emit_signal("range_changed", player.get("range_pts"), player.get("max_range"))
	if bool(_opts.inf_coins) and GameState.coins < BIG:
		GameState.coins = BIG
	if bool(_opts.inf_gems) and GameState.gems < BIG:
		GameState.gems = BIG
	if bool(player.get("god_mode")) and level != null:
		var vy: float = float(level.get("void_death_y"))
		if (player as Node2D).global_position.y > vy:
			(player as Node2D).global_position = level.get("_spawn")
			player.set("velocity", Vector2.ZERO)
