extends Node

const MORNING := 180.0
const NOON := 420.0
const EVENING := 600.0
const CYCLE := 1080.0
const PHASES := ["Morning", "Noon", "Evening", "Night"]
const DAY_LEN := 600.0
const NIGHT_LEN := 480.0

const KEYS := [
	[0.0, Color(1.0, 0.86, 0.76), 1.5, Color(1.0, 0.78, 0.5)],
	[150.0, Color(1.0, 1.0, 1.0), 0.9, Color(1.0, 0.96, 0.82)],
	[450.0, Color(1.0, 1.0, 1.0), 0.9, Color(1.0, 0.96, 0.82)],
	[570.0, Color(1.0, 0.70, 0.52), 1.6, Color(1.0, 0.62, 0.34)],
	[630.0, Color(0.012, 0.014, 0.03), 0.12, Color(0.60, 0.70, 1.0)],
	[1050.0, Color(0.012, 0.014, 0.03), 0.12, Color(0.60, 0.70, 1.0)],
	[1080.0, Color(1.0, 0.86, 0.76), 1.5, Color(1.0, 0.78, 0.5)],
]

static var elapsed := 0.0
static var time_scale := 1.0
static var day := 1
static var locked := false
static var lock_color := Color(0.012, 0.014, 0.03)
static var _saved_elapsed := 0.0
static var _lock_owner := 0
static var _bright := 1.0
static var enabled := true


static func begin_forced_night(tint: Color, owner: int, lit := false) -> void:
	if not locked:
		_saved_elapsed = elapsed
	locked = true
	_lock_owner = owner
	lock_color = tint if lit else Color(0.012, 0.014, 0.03)
	elapsed = DAY_LEN + NIGHT_LEN * 0.4


static func end_forced_night(owner: int) -> void:
	if locked and _lock_owner == owner:
		locked = false
		elapsed = _saved_elapsed


static func sleep() -> void:
	day += 1
	elapsed = 0.0


static func reset_world() -> void:
	day = 1
	elapsed = 0.0
	locked = false


static func is_night() -> bool:
	return locked or (enabled and elapsed >= DAY_LEN)


static func darkness() -> float:
	if locked:
		return 1.0
	return clampf((0.5 - _bright) / 0.4, 0.0, 1.0)


static func is_day() -> bool:
	return elapsed < DAY_LEN


static func light_progress() -> float:
	if elapsed < DAY_LEN:
		return elapsed / DAY_LEN
	return clampf((elapsed - DAY_LEN) / NIGHT_LEN, 0.0, 1.0)


static func light_pos() -> Vector2:
	if not enabled:
		return Vector2(0.92, -0.05)
	var a := light_progress() * PI
	return Vector2(0.5 - 0.62 * cos(a), 0.95 - 1.0 * sin(a))


static func sun_elevation() -> float:
	if locked or not enabled and false:
		return 0.0
	if not is_day():
		return 0.0
	return sin(light_progress() * PI)


static func shadow_length_factor() -> float:
	if not enabled:
		return 1.0
	return lerpf(2.4, 0.75, pow(sun_elevation(), 0.6))


static func shadow_alpha_factor() -> float:
	if not enabled:
		return 1.0
	if not is_day():
		return 0.0
	return lerpf(0.45, 1.0, pow(sun_elevation(), 0.5))


static func shadow_lean_factor() -> float:
	if not enabled:
		return 0.8
	var f := light_progress()
	var k := -cos(f * PI)
	return k if is_day() else k * 0.5


static func clock_text() -> String:
	var minutes: float
	if elapsed < DAY_LEN:
		minutes = 360.0 + elapsed / DAY_LEN * 720.0
	else:
		minutes = fmod(1080.0 + (elapsed - DAY_LEN) / NIGHT_LEN * 720.0, 1440.0)
	var m := int(minutes)
	return "%02d:%02d" % [m / 60, m % 60]

var world_color := Color.WHITE
var ray_mult := 1.0
var ray_color := Color(1.0, 0.96, 0.82)
var brightness := 1.0
var phase_name := "Morning"
var _mod: CanvasModulate


func _ready() -> void:
	_mod = CanvasModulate.new()
	add_child(_mod)
	_apply()


func _process(delta: float) -> void:
	if not locked:
		elapsed = fmod(elapsed + delta * time_scale, CYCLE)
	_apply()


func phase_index() -> int:
	if elapsed < MORNING: return 0
	if elapsed < NOON: return 1
	if elapsed < EVENING: return 2
	return 3


func _apply() -> void:
	enabled = GameSettings.day_night
	if locked:
		world_color = lock_color
		ray_mult = 0.12
		ray_color = Color(0.60, 0.70, 1.0)
		phase_name = "Night"
	elif not GameSettings.day_night:
		world_color = Color.WHITE
		ray_mult = 1.0
		ray_color = Color(1.0, 0.96, 0.82)
		phase_name = "Noon"
	else:
		for i in KEYS.size() - 1:
			var a: Array = KEYS[i]
			var b: Array = KEYS[i + 1]
			if elapsed >= float(a[0]) and elapsed <= float(b[0]):
				var k := (elapsed - float(a[0])) / (float(b[0]) - float(a[0]))
				k = k * k * (3.0 - 2.0 * k)
				world_color = (a[1] as Color).lerp(b[1], k)
				ray_mult = lerpf(float(a[2]), float(b[2]), k)
				ray_color = (a[3] as Color).lerp(b[3], k)
				break
		phase_name = PHASES[phase_index()]
	brightness = clampf((world_color.r + world_color.g + world_color.b) / 3.0, 0.0, 1.0)
	_bright = brightness
	_mod.color = world_color
