extends Node

const LOW_FPS := 42.0
const SAMPLE_EVERY := 0.5
const BAD_SECONDS := 6.0
const WARMUP := 6.0

static var auto_level := 1

var _t := 0.0
var _sample_t := 0.0
var _bad := 0.0


func _process(delta: float) -> void:
	if GameSettings.perf_index != 0 or auto_level >= 3:
		return
	_t += delta
	if _t < WARMUP:
		return
	_sample_t += delta
	if _sample_t < SAMPLE_EVERY:
		return
	var dt := _sample_t
	_sample_t = 0.0
	if Engine.get_frames_per_second() < LOW_FPS:
		_bad += dt
	else:
		_bad = maxf(_bad - dt, 0.0)
	if _bad >= BAD_SECONDS:
		_bad = 0.0
		_t = 0.0
		auto_level += 1
		GameSettings.apply_perf_preset(auto_level)
		print("[Performance] FPS rendah -> preset otomatis level ", auto_level)
