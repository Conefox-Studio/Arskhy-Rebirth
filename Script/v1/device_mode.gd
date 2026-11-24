extends Node

enum Mode { KEYBOARD, CONTROLLER, TOUCH }
signal mode_changed(mode: int)

var mode: int = Mode.KEYBOARD
var pad_type := "xbox"
var _locked := false
var _cmd_locked := false
var _no_touch := false
var _was_forced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--touch" in OS.get_cmdline_user_args() or "--touch" in OS.get_cmdline_args():
		_cmd_locked = true
	Input.joy_connection_changed.connect(func(_d, _c): _detect_pad())
	GameSettings.controls_changed.connect(_apply_setting)
	_apply_setting()
	_detect_pad()


func _platform_is_touch() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		if DisplayServer.is_touchscreen_available():
			return true
		var js = JavaScriptBridge.eval("(('ontouchstart' in window) || (navigator.maxTouchPoints > 0)) ? 1 : 0", true)
		return int(js) == 1
	return false


func _apply_setting() -> void:
	_no_touch = false
	_locked = _cmd_locked
	match GameSettings.touch_mode_index:
		1:
			_locked = true
			_was_forced = true
			set_mode(Mode.TOUCH)
		2:
			_no_touch = true
			_was_forced = false
			if mode == Mode.TOUCH:
				set_mode(Mode.KEYBOARD)
		_:
			if _cmd_locked or _platform_is_touch():
				set_mode(Mode.TOUCH)
			elif _was_forced and mode == Mode.TOUCH:
				set_mode(Mode.KEYBOARD)
			_was_forced = false


func is_touch() -> bool:
	return mode == Mode.TOUCH


func set_mode(m: int) -> void:
	if m == mode:
		return
	mode = m
	mode_changed.emit(mode)


func _detect_pad() -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var n := Input.get_joy_name(pads[0]).to_lower()
	if "playstation" in n or "ps3" in n or "ps4" in n or "ps5" in n or "dualshock" in n or "dualsense" in n or "sony" in n:
		pad_type = "ps"
	elif "nintendo" in n or "switch" in n or "joy-con" in n or "pro controller" in n:
		pad_type = "switch"
	else:
		pad_type = "xbox"


func _input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not _no_touch:
			set_mode(Mode.TOUCH)
	elif event is InputEventKey and event.pressed:
		set_mode(Mode.KEYBOARD)
	elif event is InputEventJoypadButton and event.pressed:
		_detect_pad()
		set_mode(Mode.CONTROLLER)
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		_detect_pad()
		set_mode(Mode.CONTROLLER)
