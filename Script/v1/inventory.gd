extends Node

signal changed
signal selected_changed
signal dropped(item: Dictionary)

const POCKETS: Array[String] = ["Items", "Key Items"]
const ITEM_SLOTS := 8
const KEY_SLOTS := 5
const SLOT_COUNT := ITEM_SLOTS
const POCKET_SIZES: Array[int] = [ITEM_SLOTS, KEY_SLOTS]
const HOTBAR_COUNT := 2
const MAX_STACK := 99
const DEBUG_DEMO_ITEMS := false

var pockets: Array = []
var hotbar: Array = []
var selected := 0
var ui_open := false


func _ready() -> void:
	for i in POCKETS.size():
		var arr: Array = []
		arr.resize(POCKET_SIZES[i])
		pockets.append(arr)
	hotbar.resize(HOTBAR_COUNT)
	_add_action("inventory", [KEY_I, KEY_TAB])
	_add_action("hotbar_1", [KEY_1, KEY_KP_1])
	_add_action("hotbar_2", [KEY_2, KEY_KP_2])
	_add_action("use_quick", [KEY_Y])
	if DEBUG_DEMO_ITEMS and OS.is_debug_build():
		_seed_demo()


static func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func select(i: int) -> void:
	i = clampi(i, 0, HOTBAR_COUNT - 1)
	if i == selected:
		return
	selected = i
	selected_changed.emit()


func add_item(item: Dictionary) -> bool:
	var pk := 1 if int(item.get("pocket", 0)) >= 3 or int(item.get("pocket", 0)) == 1 and bool(item.get("key", false)) else 0
	var arr: Array = pockets[pk]
	var left := int(item.get("count", 1))
	for slot in arr:
		if slot is Dictionary and slot.get("id", "") == item.get("id", "") and int(slot["count"]) < MAX_STACK:
			var add := mini(left, MAX_STACK - int(slot["count"]))
			slot["count"] = int(slot["count"]) + add
			left -= add
			if left <= 0:
				changed.emit()
				return true
	for i in arr.size():
		if arr[i] == null and left > 0:
			var d: Dictionary = item.duplicate()
			d["count"] = mini(left, MAX_STACK)
			left -= int(d["count"])
			arr[i] = d
			if left <= 0:
				break
	changed.emit()
	return left <= 0


static func is_usable(item) -> bool:
	return item is Dictionary and item.get("use") is Dictionary and not (item["use"] as Dictionary).is_empty()


func use_item(item, player: Node) -> bool:
	if not is_usable(item) or player == null:
		return false
	var u: Dictionary = item["use"]
	var did := false
	if int(u.get("hp", 0)) > 0 and player.hp < player.max_hp:
		player.heal(int(u["hp"]))
		did = true
	if int(u.get("mp", 0)) > 0 and player.mp < player.max_mp:
		player.restore_mp(int(u["mp"]))
		did = true
	if int(u.get("range", 0)) > 0 and player.range_pts < player.max_range:
		player.restore_range(int(u["range"]))
		did = true
	if not did:
		return false
	item["count"] = int(item["count"]) - 1
	if int(item["count"]) <= 0:
		_remove(item)
	changed.emit()
	return true


func use_quick(player: Node) -> bool:
	if use_item(hotbar[selected], player):
		return true
	for i in HOTBAR_COUNT:
		if i != selected and use_item(hotbar[i], player):
			selected = i
			selected_changed.emit()
			return true
	if hotbar[0] == null and hotbar[1] == null:
		for slot in pockets[0]:
			if slot != null and use_item(slot, player):
				return true
	return false


func assign_hotbar(slot: int, item) -> void:
	slot = clampi(slot, 0, HOTBAR_COUNT - 1)
	if item != null:
		for i in HOTBAR_COUNT:
			if hotbar[i] != null and is_same(hotbar[i], item):
				hotbar[i] = null
	hotbar[slot] = item
	changed.emit()


func hotbar_index_of(item) -> int:
	if item == null:
		return -1
	for i in HOTBAR_COUNT:
		if hotbar[i] != null and is_same(hotbar[i], item):
			return i
	return -1


func swap_slots(pocket: int, a: int, b: int) -> void:
	var arr: Array = pockets[pocket]
	if a < 0 or b < 0 or a >= arr.size() or b >= arr.size() or a == b:
		return
	var t = arr[a]
	arr[a] = arr[b]
	arr[b] = t
	changed.emit()


func equip(item) -> int:
	if not (item is Dictionary) or bool(item.get("key", false)):
		return -1
	var cur := hotbar_index_of(item)
	if cur >= 0:
		return cur
	var slot := 0 if hotbar[0] == null else (1 if hotbar[1] == null else selected)
	assign_hotbar(slot, item)
	return slot


func unequip(item) -> void:
	var i := hotbar_index_of(item)
	if i >= 0:
		assign_hotbar(i, null)


func drop_item(item: Dictionary) -> void:
	if bool(item.get("key", false)):
		return
	var copy: Dictionary = item.duplicate()
	_remove(item)
	changed.emit()
	dropped.emit(copy)


func discard_item(item: Dictionary) -> void:
	if bool(item.get("key", false)):
		return
	_remove(item)
	changed.emit()


func _remove(item: Dictionary) -> void:
	for arr in pockets:
		for i in arr.size():
			if arr[i] != null and is_same(arr[i], item):
				arr[i] = null
	for i in HOTBAR_COUNT:
		if hotbar[i] != null and is_same(hotbar[i], item):
			hotbar[i] = null


const POTIONS := [
	["blue", "Aqua Potion", "mp", 3, "Cool blue liquid. Restores 3 Magic."],
	["cyan", "Frost Potion", "mp", 5, "Icy and clear. Restores 5 Magic."],
	["green", "Herb Potion", "hp", 3, "Brewed from jungle herbs. Restores 3 HP."],
	["lime", "Vital Potion", "hp", 6, "Bright and potent. Restores 6 HP."],
	["purple", "Mystic Potion", "mp", 2, "Smells of old spells. Restores 2 Magic."],
	["pink", "Rose Potion", "hp", 4, "Sweet and warm. Restores 4 HP."],
	["maroon", "Dark Tonic", "range", 3, "Bitter and heavy. Adds 3 Range."],
	["brown", "Root Tonic", "range", 2, "Earthy tonic. Adds 2 Range."],
	["red", "Crimson Elixir", "hp", 10, "A strong elixir. Restores 10 HP."],
	["orange", "Ember Elixir", "range", 5, "Burns in the throat. Adds 5 Range."],
	["peach", "Soft Potion", "hp", 2, "Gentle healing. Restores 2 HP."],
	["cream", "Milk Potion", "hp", 5, "Creamy and calming. Restores 5 HP."],
	["gray", "Ash Potion", "mp", 4, "Gritty. Restores 4 Magic."],
	["white", "Holy Potion", "hp", 8, "Pure light. Restores 8 HP."],
	["empty", "Empty Flask", "", 0, "An empty glass flask. Cannot be used, only kept."],
]


func potion_item(idx: int, count: int = 1) -> Dictionary:
	var p: Array = POTIONS[idx]
	var d := {"id": "potion_" + String(p[0]), "name": p[1], "desc": p[4], "count": count,
		"pocket": 2 if p[2] == "" else 0,
		"icon": load("res://assets/items/potion_%02d_%s.png" % [idx + 1, p[0]])}
	if p[2] != "":
		d["use"] = {p[2]: p[3]}
	return d


func _seed_demo() -> void:
	for i in [2, 3, 0, 1, 6]:
		add_item(potion_item(i, 3))
	add_item({"id": "herb", "name": "Herb", "pocket": 0, "count": 5, "icon": _icon("leaf"),
		"desc": "A fresh jungle herb. Restores 3 HP when used.", "use": {"hp": 3}})
	add_item({"id": "magic_dew", "name": "Magic Dew", "pocket": 0, "count": 3, "icon": _icon("drop"),
		"desc": "Dew from a glowing leaf. Restores 2 Magic.", "use": {"mp": 2}})
	add_item({"id": "rage_tonic", "name": "Rage Tonic", "pocket": 0, "count": 2, "icon": _icon("flask"),
		"desc": "A bitter red tonic. Adds 3 to the Range bar.", "use": {"range": 3}})
	add_item({"id": "old_map", "name": "Old Map", "pocket": 3, "count": 1, "icon": _icon("scroll"), "key": true,
		"desc": "A worn map of the jungle. It cannot be used, only kept."})
	hotbar[0] = pockets[0][0]
	hotbar[1] = pockets[0][1]


func _icon(kind: String) -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var dark := Color("1d1530")
	for y in 16:
		for x in 16:
			var p := Vector2(x + 0.5, y + 0.5)
			var c := Color(0, 0, 0, 0)
			match kind:
				"leaf":
					var u := (p - Vector2(8, 8)).rotated(deg_to_rad(40.0))
					var e := u.x * u.x / 49.0 + u.y * u.y / 15.0
					if e < 1.0:
						c = Color("7bd94a") if absf(u.y) > 0.7 else Color("c9f59a")
					elif e < 1.5:
						c = dark
				"drop":
					var in_body := p.distance_to(Vector2(8, 10)) < 5.0
					var in_tip := p.y < 10.0 and p.y > 2.0 and absf(p.x - 8.0) < (p.y - 2.0) * 0.62
					if in_body or in_tip:
						c = Color("5ab4ff") if p.x > 6.5 or p.y < 7.0 else Color("d5f0ff")
					elif p.distance_to(Vector2(8, 10)) < 6.2 or (p.y < 10.5 and p.y > 1.2 and absf(p.x - 8.0) < (p.y - 1.2) * 0.62 + 1.0):
						c = dark
				"flask":
					var body := p.distance_to(Vector2(8, 10.5)) < 4.8
					var neck := p.x > 6.0 and p.x < 10.0 and p.y > 2.5 and p.y < 7.0
					if body or neck:
						c = Color("e8434f") if p.y > 9.0 or neck else Color("ff9aa0")
						if neck and p.y < 4.5:
							c = Color("c9a46a")
					elif p.distance_to(Vector2(8, 10.5)) < 6.0 or (p.x > 5.0 and p.x < 11.0 and p.y > 1.5 and p.y < 7.5):
						c = dark
				"scroll":
					if p.x > 3.0 and p.x < 13.0 and p.y > 3.0 and p.y < 13.0:
						c = Color("e8d49a")
						if int(p.y) % 3 == 0 and p.x > 5.0 and p.x < 11.0:
							c = Color("a8844a")
					elif p.x > 2.0 and p.x < 14.0 and p.y > 2.0 and p.y < 14.0:
						c = dark
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
