extends RefCounted

const KB := preload("res://assets/ui/icons/kb_dark_all.png")
const XBOX := preload("res://assets/ui/icons/controller_xbox.png")
const PS := preload("res://assets/ui/icons/controller_ps.png")
const SWITCH := preload("res://assets/ui/icons/controller_switch.png")
const CELL := 16

const KEYS := {"jump": "space", "attack": "z", "dash": "shift", "inventory": "i",
	"use_quick": "y", "range_mode": "q", "hotbar_1": "1", "hotbar_2": "2", "pocket_prev": "q", "pocket_next": "e", "move_left": "a", "move_right": "d", "pause": "esc"}
const PAD := {"jump": "S", "attack": "W", "dash": "RT", "use_quick": "LT", "range_mode": "E",
	"hotbar_1": "LB", "hotbar_2": "RB", "pocket_prev": "LB", "pocket_next": "RB", "inventory": "BACK", "pause": "START"}
const FACE_ROWS := {"xbox": [4, 2, 6, 0], "ps": [4, 2, 6, 0], "switch": [4, 2, 6, 0]}
const XBOX_ROWS := {"LB": 16, "LT": 19, "RB": 22, "RT": 25, "START": 11, "BACK": 13}


static func _atlas(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(col * CELL, row * CELL, CELL, CELL)
	return a


static func key_texture(name: String) -> Texture2D:
	var n := name.to_lower()
	if n.length() == 1 and n >= "a" and n <= "z":
		return _atlas(KB, 0, n.unicode_at(0) - 97)
	if n.length() == 1 and n >= "1" and n <= "9":
		return _atlas(KB, 4, 11 + int(n))
	match n:
		"0": return _atlas(KB, 4, 21)
		"esc": return _atlas(KB, 8, 0)
		"tab": return _atlas(KB, 8, 2)
		"shift": return _atlas(KB, 8, 5)
		"ctrl": return _atlas(KB, 8, 6)
		"alt": return _atlas(KB, 8, 7)
		"space": return _atlas(KB, 8, 8)
		"enter": return _atlas(KB, 8, 25)
		"up": return _atlas(KB, 12, 12)
		"left": return _atlas(KB, 12, 13)
		"down": return _atlas(KB, 12, 14)
		"right": return _atlas(KB, 12, 15)
	return null


static func pad_texture(slot: String, pad_type: String = "xbox") -> Texture2D:
	var faces: Array = FACE_ROWS.get(pad_type, FACE_ROWS["xbox"])
	var sheet: Texture2D = XBOX
	match pad_type:
		"ps": sheet = PS
		"switch": sheet = SWITCH
	match slot:
		"S": return _atlas(sheet, 0, faces[0])
		"W": return _atlas(sheet, 0, faces[1])
		"E": return _atlas(sheet, 0, faces[2])
		"N": return _atlas(sheet, 0, faces[3])
	if XBOX_ROWS.has(slot):
		return _atlas(XBOX, 0, XBOX_ROWS[slot])
	return null


static func texture_for(action: String) -> Texture2D:
	var style := _hint_style()
	var kn := _key_name(action)
	var ps := _pad_slot(action)
	match style:
		1: return key_texture(kn)
		2: return pad_texture(ps, "xbox")
		3: return pad_texture(ps, "ps")
		4: return pad_texture(ps, "switch")
	if DeviceMode_mode() == 1:
		return pad_texture(ps, DeviceMode_pad())
	return key_texture(kn)


static func _key_name(action: String) -> String:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				var code: int = int(e.physical_keycode) if int(e.physical_keycode) != 0 else int(e.keycode)
				var n := OS.get_keycode_string(code as Key).to_lower()
				if n == "escape":
					n = "esc"
				if key_texture(n) != null:
					return n
	return KEYS.get(action, "")


static func _pad_slot(action: String) -> String:
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			var spec := []
			if e is InputEventJoypadButton:
				spec = ["b", int(e.button_index)]
			elif e is InputEventJoypadMotion:
				spec = ["a", int(e.axis), signf(e.axis_value)]
			if not spec.is_empty():
				var slot := ""
				if str(spec[0]) == "b":
					match int(spec[1]):
						0: slot = "S"
						1: slot = "E"
						2: slot = "W"
						3: slot = "N"
						4: slot = "BACK"
						6: slot = "START"
						9: slot = "LB"
						10: slot = "RB"
				else:
					match int(spec[1]):
						4: slot = "LT"
						5: slot = "RT"
				if slot != "":
					return slot
	return PAD.get(action, "")


static func _hint_style() -> int:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameSettings").hint_style_index


static func DeviceMode_mode() -> int:
	return (Engine.get_main_loop() as SceneTree).root.get_node("DeviceMode").mode


static func DeviceMode_pad() -> String:
	return (Engine.get_main_loop() as SceneTree).root.get_node("DeviceMode").pad_type
