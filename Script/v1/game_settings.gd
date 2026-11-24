extends Node

signal graphics_changed
signal controls_changed

const PATH := "user://settings.cfg"
const Keybinds = preload("res://scripts/keybinds.gd")

const BUSES: Array[String] = ["Master", "Music", "Ambient", "SFX", "UI", "Voice"]
const BUS_LABELS := {
	"Master": "Master Volume",
	"Music": "Music",
	"Ambient": "Ambient",
	"SFX": "Sound Effects",
	"UI": "UI Sounds",
	"Voice": "Voice / Dialog",
}

const WINDOW_MODES: Array[String] = ["Windowed", "Borderless", "Fullscreen"]
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440),
]
const SCALES: Array[float] = [0.75, 0.9, 1.0, 1.1, 1.25]

const SHADOW_NAMES: Array[String] = ["Off", "Simple", "Soft"]
const RENDER_MAP_NAMES: Array[String] = ["Low", "Medium", "High"]

const TEXT_SPEED_NAMES: Array[String] = ["Slow", "Normal", "Fast", "Instant"]
const TEXT_SPEED_CPS: Array[float] = [20.0, 36.0, 64.0, 0.0]
const TEXT_SIZE_NAMES: Array[String] = ["Small", "Medium", "Large"]
const TEXT_SIZES: Array[int] = [22, 28, 34]
const BOX_OPACITY_NAMES: Array[String] = ["Low", "Medium", "High", "Solid"]
const BOX_OPACITIES: Array[float] = [0.55, 0.72, 0.86, 1.0]

const HINT_STYLE_NAMES: Array[String] = ["Auto", "Keyboard", "Xbox", "PlayStation", "Switch"]
const TOUCH_MODE_NAMES: Array[String] = ["Auto", "On", "Off"]
const TOUCH_OPACITY_NAMES: Array[String] = ["Low", "Medium", "High"]
const HUD_LAYOUT_NAMES: Array[String] = ["Auto", "Top", "Bottom", "Vertical"]
const TOUCH_SIZE_NAMES: Array[String] = ["Small", "Medium", "Large"]
const TOUCH_SIZES: Array[float] = [0.85, 1.0, 1.2]
const TOUCH_OPACITIES: Array[float] = [0.6, 0.85, 1.15]

var pending_load := {}

var arrive_side := ""

var window_mode := 0
var resolution_index := 0
var scale_index := 2
var vsync := true
var shadow_index := 1
var render_map_index := 1
var fog := true
var godrays := true
var godray_strength := 1.0
var flashes := false
var wildlife := true
var day_night := true
var soft_lighting := false
const IS_DEMO := true
var completed_modes: Array = []
const PERF_NAMES: Array[String] = ["Auto", "High", "Medium", "Low"]
var perf_index := 0
var wind := true
var shadow_shader := true
var bloom := false
var film_grain := false
var chromatic := false
var text_speed_index := 1
var text_size_index := 1
var box_opacity_index := 2
var typing_sound := true
var control_hints := true
var hint_style_index := 0
var touch_mode_index := 0
var touch_opacity_index := 1
var touch_size_index := 1
var hud_layout_index := 0
var touch_layout := {}
var bindings := {}
var volumes := {
	"Master": 0.8, "Music": 0.7, "Ambient": 0.6,
	"SFX": 0.8, "UI": 0.8, "Voice": 0.8,
}


func _ready() -> void:
	_ensure_buses()
	load_settings()
	DisplayServer.window_set_title("Arskhy Rebirth")
	apply_all()
	apply_bindings()


func _ensure_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func reset_to_default() -> void:
	window_mode = 0
	resolution_index = 0
	scale_index = 2
	vsync = true
	shadow_index = 1
	render_map_index = 1
	fog = true
	godrays = true
	godray_strength = 1.0
	flashes = false
	wildlife = true
	day_night = true
	soft_lighting = false
	shadow_shader = true
	wind = true
	perf_index = 0
	bloom = false
	film_grain = false
	chromatic = false
	text_speed_index = 1
	text_size_index = 1
	box_opacity_index = 2
	typing_sound = true
	control_hints = true
	hint_style_index = 0
	touch_opacity_index = 1
	touch_mode_index = 0
	touch_size_index = 1
	hud_layout_index = 0
	touch_layout = {}
	bindings = {}
	volumes = {"Master": 0.8, "Music": 0.7, "Ambient": 0.6, "SFX": 0.8, "UI": 0.8, "Voice": 0.8}
	apply_all()
	apply_bindings()
	apply_controls()
	save_settings()


func text_speed_cps() -> float:
	return TEXT_SPEED_CPS[clampi(text_speed_index, 0, TEXT_SPEED_CPS.size() - 1)]


func text_size() -> int:
	return TEXT_SIZES[clampi(text_size_index, 0, TEXT_SIZES.size() - 1)]


func box_opacity() -> float:
	return BOX_OPACITIES[clampi(box_opacity_index, 0, BOX_OPACITIES.size() - 1)]


func apply_graphics() -> void:
	graphics_changed.emit()


func apply_controls() -> void:
	controls_changed.emit()


func apply_bindings() -> void:
	Keybinds.apply_all(bindings)


func touch_scale() -> float:
	return TOUCH_SIZES[clampi(touch_size_index, 0, TOUCH_SIZES.size() - 1)]


func touch_opacity() -> float:
	return TOUCH_OPACITIES[clampi(touch_opacity_index, 0, TOUCH_OPACITIES.size() - 1)]


func apply_all() -> void:
	apply_display()
	apply_graphics()
	for bus_name in BUSES:
		apply_volume(bus_name)


func apply_volume(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var v: float = volumes.get(bus_name, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))


func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	apply_volume(bus_name)


func apply_display() -> void:
	var win := get_window()
	if win == null:
		return
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	win.content_scale_factor = SCALES[clampi(scale_index, 0, SCALES.size() - 1)]

	match window_mode:
		2:
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			var screen := DisplayServer.window_get_current_screen()
			DisplayServer.window_set_position(DisplayServer.screen_get_position(screen))
			DisplayServer.window_set_size(DisplayServer.screen_get_size(screen))
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var usable := DisplayServer.screen_get_usable_rect()
			var size: Vector2i = RESOLUTIONS[clampi(resolution_index, 0, RESOLUTIONS.size() - 1)]
			size = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)


func mode_unlocked(i: int) -> bool:
	match i:
		0, 1:
			return true
		2:
			return completed_modes.has(1)
		3:
			return completed_modes.has(2)
		4:
			return not IS_DEMO and completed_modes.has(0) and completed_modes.has(1) and completed_modes.has(2) and completed_modes.has(3)
	return false


func apply_perf_preset(level: int) -> void:
	if level >= 2:
		soft_lighting = false
		godrays = false
		bloom = false
		film_grain = false
		chromatic = false
		render_map_index = mini(render_map_index, 1)
	if level >= 3:
		fog = false
		wildlife = false
		wind = false
		shadow_shader = false
		shadow_index = mini(shadow_index, 1)
		render_map_index = 0
	apply_graphics()


func mark_mode_completed(i: int) -> void:
	if not completed_modes.has(i):
		completed_modes.append(i)
		save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "scale_index", scale_index)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("graphics", "shadow_index", shadow_index)
	cfg.set_value("graphics", "render_map_index", render_map_index)
	cfg.set_value("graphics", "fog", fog)
	cfg.set_value("graphics", "godrays", godrays)
	cfg.set_value("graphics", "godray_strength", godray_strength)
	cfg.set_value("graphics", "flashes", flashes)
	cfg.set_value("graphics", "soft_lighting", soft_lighting)
	cfg.set_value("graphics", "shadow_shader", shadow_shader)
	cfg.set_value("graphics", "bloom", bloom)
	cfg.set_value("graphics", "film_grain", film_grain)
	cfg.set_value("graphics", "chromatic", chromatic)
	cfg.set_value("graphics", "wind", wind)
	cfg.set_value("graphics", "perf_index", perf_index)
	cfg.set_value("progress", "completed", completed_modes)
	cfg.set_value("graphics", "wildlife", wildlife)
	cfg.set_value("graphics", "day_night", day_night)
	cfg.set_value("dialog", "text_speed_index", text_speed_index)
	cfg.set_value("dialog", "text_size_index", text_size_index)
	cfg.set_value("dialog", "box_opacity_index", box_opacity_index)
	cfg.set_value("dialog", "typing_sound", typing_sound)
	cfg.set_value("controls", "control_hints", control_hints)
	cfg.set_value("controls", "hint_style_index", hint_style_index)
	cfg.set_value("controls", "touch_opacity_index", touch_opacity_index)
	cfg.set_value("controls", "touch_mode_index", touch_mode_index)
	cfg.set_value("controls", "touch_size_index", touch_size_index)
	cfg.set_value("controls", "hud_layout_index", hud_layout_index)
	cfg.set_value("controls", "touch_layout", touch_layout)
	for a in bindings:
		cfg.set_value("bindings", String(a), bindings[a])
	for bus_name in BUSES:
		cfg.set_value("audio", bus_name, volumes[bus_name])
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	window_mode = clampi(int(cfg.get_value("display", "window_mode", window_mode)), 0, WINDOW_MODES.size() - 1)
	resolution_index = clampi(int(cfg.get_value("display", "resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1)
	scale_index = clampi(int(cfg.get_value("display", "scale_index", scale_index)), 0, SCALES.size() - 1)
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	shadow_index = clampi(int(cfg.get_value("graphics", "shadow_index", shadow_index)), 0, SHADOW_NAMES.size() - 1)
	render_map_index = clampi(int(cfg.get_value("graphics", "render_map_index", render_map_index)), 0, RENDER_MAP_NAMES.size() - 1)
	fog = bool(cfg.get_value("graphics", "fog", fog))
	godrays = bool(cfg.get_value("graphics", "godrays", godrays))
	godray_strength = clampf(float(cfg.get_value("graphics", "godray_strength", godray_strength)), 0.0, 1.0)
	flashes = bool(cfg.get_value("graphics", "flashes", flashes))
	soft_lighting = bool(cfg.get_value("graphics", "soft_lighting", soft_lighting))
	shadow_shader = bool(cfg.get_value("graphics", "shadow_shader", shadow_shader))
	bloom = bool(cfg.get_value("graphics", "bloom", bloom))
	film_grain = bool(cfg.get_value("graphics", "film_grain", film_grain))
	chromatic = bool(cfg.get_value("graphics", "chromatic", chromatic))
	wind = bool(cfg.get_value("graphics", "wind", wind))
	perf_index = clampi(int(cfg.get_value("graphics", "perf_index", perf_index)), 0, PERF_NAMES.size() - 1)
	completed_modes = Array(cfg.get_value("progress", "completed", []))
	wildlife = bool(cfg.get_value("graphics", "wildlife", wildlife))
	day_night = bool(cfg.get_value("graphics", "day_night", day_night))
	text_speed_index = clampi(int(cfg.get_value("dialog", "text_speed_index", text_speed_index)), 0, TEXT_SPEED_NAMES.size() - 1)
	text_size_index = clampi(int(cfg.get_value("dialog", "text_size_index", text_size_index)), 0, TEXT_SIZE_NAMES.size() - 1)
	box_opacity_index = clampi(int(cfg.get_value("dialog", "box_opacity_index", box_opacity_index)), 0, BOX_OPACITY_NAMES.size() - 1)
	typing_sound = bool(cfg.get_value("dialog", "typing_sound", typing_sound))
	control_hints = bool(cfg.get_value("controls", "control_hints", control_hints))
	hint_style_index = clampi(int(cfg.get_value("controls", "hint_style_index", hint_style_index)), 0, HINT_STYLE_NAMES.size() - 1)
	touch_opacity_index = clampi(int(cfg.get_value("controls", "touch_opacity_index", touch_opacity_index)), 0, TOUCH_OPACITY_NAMES.size() - 1)
	touch_mode_index = clampi(int(cfg.get_value("controls", "touch_mode_index", touch_mode_index)), 0, TOUCH_MODE_NAMES.size() - 1)
	touch_size_index = clampi(int(cfg.get_value("controls", "touch_size_index", touch_size_index)), 0, TOUCH_SIZE_NAMES.size() - 1)
	hud_layout_index = clampi(int(cfg.get_value("controls", "hud_layout_index", hud_layout_index)), 0, HUD_LAYOUT_NAMES.size() - 1)
	var tl = cfg.get_value("controls", "touch_layout", {})
	touch_layout = tl if tl is Dictionary else {}
	bindings = {}
	if cfg.has_section("bindings"):
		for a in cfg.get_section_keys("bindings"):
			var v = cfg.get_value("bindings", a, {})
			if v is Dictionary:
				bindings[a] = v
	for bus_name in BUSES:
		volumes[bus_name] = clampf(float(cfg.get_value("audio", bus_name, volumes[bus_name])), 0.0, 1.0)
