extends Node
const DayNight = preload("res://scripts/day_night.gd")

enum Difficulty { EASY, NORMAL, HARD, HARDCORE }

const DIFF_NAMES: Array[String] = ["Easy", "Normal", "Hard", "Hardcore"]
const DIFF_HP: Array[int] = [30, 20, 15, 10]
const DIFF_SAVES: Array[int] = [-1, 5, 3, 1]
const DIFF_DESC: Array[String] = [
	"Unlimited saves.",
	"5 save slots per journey.",
	"3 save slots per journey.",
	"1 save slot per journey. Choose wisely.",
]

const MAX_FAINTS := 2
const MAX_SLOT_FILES := 5
const SLEEP_FAINT_HEAL := 0.5

const GEM_SLOTS := 2
const GEM_MAX_LEVEL := 100
const GEM_CAPS := {"attack": 9500000.0, "hp": 1500.0, "crit": 0.89, "range": 650.0, "mp": 2000.0}
signal gem_changed
var gem_levels: Array = [1, 1]
const META_PATH := "user://run_meta.cfg"
const SLOT_PATH := "user://save_slot_%d.dat"

var difficulty: int = Difficulty.NORMAL
var saves_used := 0
var faints := 0.0
signal currency_changed
var coins := 0
var gems := 0


func add_coins(n: int) -> void:
	coins += n
	currency_changed.emit()


func add_gems(n: int) -> void:
	gems += n
	currency_changed.emit()
var pending_notice := ""

var seen_dialogs := {}
var has_stats := false
var magic_index := 0
var hp := 10
var mp := 5
var range_pts := 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(META_PATH) == OK:
		difficulty = clampi(int(cfg.get_value("run", "difficulty", Difficulty.NORMAL)), 0, DIFF_NAMES.size() - 1)
		saves_used = maxi(0, int(cfg.get_value("run", "saves_used", 0)))


func _save_meta() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "difficulty", difficulty)
	cfg.set_value("run", "saves_used", saves_used)
	cfg.save(META_PATH)


func new_journey(diff: int) -> void:
	difficulty = clampi(diff, 0, DIFF_NAMES.size() - 1)
	saves_used = 0
	faints = 0.0
	gem_levels = [1, 1]
	coins = 0
	gems = 0
	has_stats = false
	DayNight.reset_world()
	seen_dialogs.clear()
	for i in range(1, MAX_SLOT_FILES + 1):
		if FileAccess.file_exists(SLOT_PATH % i):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_PATH % i))
	_save_meta()


func restart_journey() -> void:
	faints = 0.0
	gem_levels = [1, 1]
	has_stats = false
	seen_dialogs.clear()
	GameSettings.pending_load = {}
	GameSettings.arrive_side = ""


func difficulty_name() -> String:
	return DIFF_NAMES[difficulty]


func save_limit() -> int:
	return DIFF_SAVES[difficulty]


func is_unlimited() -> bool:
	return save_limit() < 0


func saves_left() -> int:
	return 999 if is_unlimited() else maxi(0, save_limit() - saves_used)


func can_save() -> bool:
	return is_unlimited() or saves_used < save_limit()


func saves_left_text() -> String:
	if is_unlimited():
		return "Saves: Unlimited"
	return "Saves left: %d/%d" % [saves_left(), save_limit()]


func write_save(scene_path: String, label: String, player: Node, slot_choice := -1) -> int:
	if not can_save():
		return -1
	var slot := slot_choice
	if slot < 1 or slot > MAX_SLOT_FILES:
		slot = 1 if is_unlimited() else saves_used + 1
	var cfg := ConfigFile.new()
	cfg.set_value("state", "scene", scene_path)
	cfg.set_value("state", "x", player.global_position.x)
	cfg.set_value("state", "y", player.global_position.y)
	cfg.set_value("state", "flip", player.is_flipped())
	cfg.set_value("state", "label", label)
	cfg.set_value("state", "time", Time.get_datetime_string_from_system(false, true))
	cfg.set_value("stats", "hp", player.hp)
	cfg.set_value("stats", "mp", player.mp)
	cfg.set_value("stats", "range", player.range_pts)
	cfg.set_value("stats", "faints", faints)
	cfg.set_value("stats", "coins", coins)
	cfg.set_value("stats", "gems", gems)
	cfg.set_value("state", "dialogs", seen_dialogs.keys())
	cfg.set_value("stats", "difficulty", difficulty)
	cfg.set_value("stats", "max_hp", player.max_hp)
	cfg.set_value("stats", "gem_lv1", int(gem_levels[0]))
	cfg.set_value("stats", "gem_lv2", int(gem_levels[1]))
	cfg.set_value("world", "day", DayNight.day)
	cfg.set_value("world", "elapsed", DayNight.elapsed)
	if cfg.save(SLOT_PATH % slot) != OK:
		return -1
	if not is_unlimited():
		saves_used += 1
	_save_meta()
	return slot


func has_any_save() -> bool:
	for i in range(1, MAX_SLOT_FILES + 1):
		if FileAccess.file_exists(SLOT_PATH % i):
			return true
	return false


func slot_infos() -> Array:
	var out: Array = []
	for i in range(1, MAX_SLOT_FILES + 1):
		var cfg := ConfigFile.new()
		if cfg.load(SLOT_PATH % i) != OK:
			continue
		out.append({
			"slot": i,
			"label": str(cfg.get_value("state", "label", "")),
			"time": str(cfg.get_value("state", "time", "")).replace("T", "  "),
			"faints": float(cfg.get_value("stats", "faints", 0.0)),
			"scene": str(cfg.get_value("state", "scene", "")),
		})
	return out


func all_slot_infos() -> Array:
	var out: Array = []
	for i in range(1, MAX_SLOT_FILES + 1):
		var cfg := ConfigFile.new()
		if cfg.load(SLOT_PATH % i) != OK:
			out.append({"slot": i, "empty": true})
			continue
		out.append({
			"slot": i,
			"empty": false,
			"label": str(cfg.get_value("state", "label", "")),
			"time": str(cfg.get_value("state", "time", "")).replace("T", "  "),
			"faints": float(cfg.get_value("stats", "faints", 0.0)),
			"scene": str(cfg.get_value("state", "scene", "")),
			"day": int(cfg.get_value("world", "day", 1)),
			"hp": int(cfg.get_value("stats", "hp", 0)),
			"difficulty": int(cfg.get_value("stats", "difficulty", 1)),
		})
	return out


static func faint_text(f: float) -> String:
	return str(int(f)) if is_equal_approx(f, floorf(f)) else "%.1f" % f


func slot_line(info: Dictionary) -> String:
	if bool(info.get("empty", false)):
		return "Slot %d     - Empty -" % int(info.slot)
	return "Slot %d   %s   Day %d   Faint %s/%d   %s" % [int(info.slot), String(info.label), int(info.day), faint_text(float(info.faints)), MAX_FAINTS, String(info.time).left(17).strip_edges()]


func load_slot(slot: int, fallback_scene: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SLOT_PATH % slot) != OK:
		return ""
	var scene_path := str(cfg.get_value("state", "scene", fallback_scene))
	if not scene_path.begins_with("res://") or not ResourceLoader.exists(scene_path):
		scene_path = fallback_scene
	GameSettings.pending_load = {
		"x": float(cfg.get_value("state", "x", 0.0)),
		"y": float(cfg.get_value("state", "y", 0.0)),
		"flip": bool(cfg.get_value("state", "flip", false)),
	}
	DayNight.day = int(cfg.get_value("world", "day", 1))
	DayNight.elapsed = float(cfg.get_value("world", "elapsed", 0.0))
	seen_dialogs.clear()
	for id in cfg.get_value("state", "dialogs", []):
		seen_dialogs[str(id)] = true
	if cfg.has_section("stats"):
		has_stats = true
		hp = int(cfg.get_value("stats", "hp", 10))
		mp = int(cfg.get_value("stats", "mp", 5))
		range_pts = int(cfg.get_value("stats", "range", 0))
		faints = float(cfg.get_value("stats", "faints", 0.0))
		gem_levels = [clampi(int(cfg.get_value("stats", "gem_lv1", 1)), 1, GEM_MAX_LEVEL), clampi(int(cfg.get_value("stats", "gem_lv2", 1)), 1, GEM_MAX_LEVEL)]
		coins = int(cfg.get_value("stats", "coins", 0))
		gems = int(cfg.get_value("stats", "gems", 0))
	else:
		has_stats = false
		faints = 0.0
		gem_levels = [1, 1]
	return scene_path


func gem_progress() -> float:
	var t := 0.0
	for lv in gem_levels:
		t += float(clampi(int(lv), 1, GEM_MAX_LEVEL) - 1) / float(GEM_MAX_LEVEL - 1)
	return t / float(GEM_SLOTS)


func gem_scale(kind: String, base: float) -> float:
	return gem_scale_at(kind, base, gem_progress())


func gem_scale_at(kind: String, base: float, t: float) -> float:
	var cap: float = GEM_CAPS[kind]
	if base <= 0.0 or cap <= base:
		return base
	return base * pow(cap / base, t)


func gem_crit() -> float:
	return gem_crit_at(gem_progress())


func gem_crit_at(t: float) -> float:
	return float(GEM_CAPS["crit"]) * t


func gem_progress_next(slot: int) -> float:
	if int(gem_levels[slot]) >= GEM_MAX_LEVEL:
		return gem_progress()
	return gem_progress() + 1.0 / float((GEM_MAX_LEVEL - 1) * GEM_SLOTS)


func gem_upgrade_cost(slot: int) -> Dictionary:
	var lv := int(gem_levels[slot])
	if lv >= GEM_MAX_LEVEL:
		return {}
	return {"gems": 1 + lv / 12, "coins": 10 + int(lv * lv * 0.5)}


func gem_can_upgrade(slot: int) -> bool:
	var c := gem_upgrade_cost(slot)
	return not c.is_empty() and gems >= int(c.gems) and coins >= int(c.coins)


func gem_upgrade(slot: int) -> bool:
	if slot < 0 or slot >= GEM_SLOTS or not gem_can_upgrade(slot):
		return false
	var c := gem_upgrade_cost(slot)
	gems -= int(c.gems)
	coins -= int(c.coins)
	gem_levels[slot] = int(gem_levels[slot]) + 1
	gem_changed.emit()
	return true
