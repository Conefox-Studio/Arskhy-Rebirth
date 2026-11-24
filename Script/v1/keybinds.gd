extends RefCounted

const ACTIONS := [
	{"a": "move_left", "label": "Move Left"},
	{"a": "move_right", "label": "Move Right"},
	{"a": "jump", "label": "Jump / Double Jump"},
	{"a": "attack", "label": "Attack"},
	{"a": "dash", "label": "Dash"},
	{"a": "sprint", "label": "Sprint (hold)"},
	{"a": "range_mode", "label": "Range Mode (bar full)"},
	{"a": "magic_cast", "label": "Cast Magic"},
	{"a": "magic_prev", "label": "Magic Left (0)"},
	{"a": "magic_next", "label": "Magic Right (-)"},
	{"a": "use_quick", "label": "Use Item"},
	{"a": "hotbar_1", "label": "Quick Slot 1"},
	{"a": "hotbar_2", "label": "Quick Slot 2"},
	{"a": "inventory", "label": "Bag"},
]

const PAD_NAMES := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "Back", 6: "Start", 7: "L3", 8: "R3",
	9: "LB", 10: "RB", 11: "D-Up", 12: "D-Down", 13: "D-Left", 14: "D-Right"}
const AXIS_NAMES := {0: "L-Stick X", 1: "L-Stick Y", 2: "R-Stick X", 3: "R-Stick Y", 4: "LT", 5: "RT"}

static var _defaults := {}


static func _snapshot(a: String) -> void:
	if _defaults.has(a) or not InputMap.has_action(a):
		return
	var evs: Array = []
	for e in InputMap.action_get_events(a):
		evs.append(e.duplicate())
	_defaults[a] = evs


static func apply_all(bind: Dictionary) -> void:
	for d in ACTIONS:
		var a: String = d["a"]
		var b: Dictionary = bind.get(a, {})
		apply_action(a, b)


static func apply_action(a: String, b: Dictionary) -> void:
	if not InputMap.has_action(a):
		return
	_snapshot(a)
	InputMap.action_erase_events(a)
	for e in _defaults[a]:
		if e is InputEventKey and b.has("k"):
			continue
		if (e is InputEventJoypadButton or e is InputEventJoypadMotion) and b.has("p"):
			continue
		InputMap.action_add_event(a, e.duplicate())
	if b.has("k") and int(b["k"]) > 0:
		var ke := InputEventKey.new()
		ke.physical_keycode = int(b["k"]) as Key
		InputMap.action_add_event(a, ke)
	if b.has("p"):
		var pe := pad_event(b["p"])
		if pe != null:
			InputMap.action_add_event(a, pe)


static func pad_event(spec: Array) -> InputEvent:
	if spec.size() < 2 or int(spec[1]) < 0:
		return null
	if str(spec[0]) == "b":
		var e := InputEventJoypadButton.new()
		e.button_index = int(spec[1]) as JoyButton
		return e
	var m := InputEventJoypadMotion.new()
	m.axis = int(spec[1]) as JoyAxis
	m.axis_value = float(spec[2]) if spec.size() > 2 else 1.0
	return m


static func key_of(a: String) -> int:
	if not InputMap.has_action(a):
		return 0
	for e in InputMap.action_get_events(a):
		if e is InputEventKey:
			if int(e.physical_keycode) != 0:
				return int(e.physical_keycode)
			return int(e.keycode)
	return 0


static func pad_of(a: String) -> Array:
	if not InputMap.has_action(a):
		return []
	for e in InputMap.action_get_events(a):
		if e is InputEventJoypadButton:
			return ["b", int(e.button_index)]
		if e is InputEventJoypadMotion:
			return ["a", int(e.axis), signf(e.axis_value)]
	return []


static func key_text(code: int) -> String:
	if code <= 0:
		return "-"
	return OS.get_keycode_string(code as Key)


static func pad_text(spec: Array) -> String:
	if spec.is_empty():
		return "-"
	if str(spec[0]) == "b":
		return str(PAD_NAMES.get(int(spec[1]), "Btn %d" % int(spec[1])))
	var n: String = str(AXIS_NAMES.get(int(spec[1]), "Axis %d" % int(spec[1])))
	if int(spec[1]) <= 3:
		n += " +" if float(spec[2]) > 0.0 else " -"
	return n


static func pad_slot(spec: Array) -> String:
	if spec.is_empty():
		return ""
	if str(spec[0]) == "b":
		match int(spec[1]):
			0: return "S"
			1: return "E"
			2: return "W"
			3: return "N"
			4: return "BACK"
			6: return "START"
			9: return "LB"
			10: return "RB"
		return ""
	match int(spec[1]):
		4: return "LT"
		5: return "RT"
	return ""
