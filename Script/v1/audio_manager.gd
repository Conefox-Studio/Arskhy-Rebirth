extends Node

const MUSIC_TITLE_OLD := "res://assets/audio/music/close.mp3"
const MUSIC_TITLE_NEW := "res://assets/audio/music/title_theme.mp3"
var MUSIC_TITLE: String:
	get:
		return MUSIC_TITLE_NEW if ResourceLoader.exists(MUSIC_TITLE_NEW) else MUSIC_TITLE_OLD
const MUSIC_MAP0 := "res://assets/audio/music/horror_ambience.ogg"
const AMBIENT_WIND := "res://assets/audio/ambient/night_wind.wav"
const AMBIENT_NIGHT := "res://assets/audio/ambient/night_crickets.wav"
const UI_SOUNDS := {
	"move": "res://assets/audio/sfx/ui_move.wav",
	"select": "res://assets/audio/sfx/ui_select.wav",
	"back": "res://assets/audio/sfx/ui_back.mp3",
	"error": "res://assets/audio/sfx/ui_error.wav",
	"tick": "res://assets/audio/sfx/ui_tick.wav",
	"type": "res://assets/audio/sfx/type.wav",
	"chapter": "res://assets/audio/sfx/chapter_start.wav",
}

var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _night: AudioStreamPlayer
var _night_stream: AudioStreamWAV
var _ui: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_cache := {}
var _music_tween: Tween
var _music_path := ""
var _sfx_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = _make_player("Music")
	_ambient = _make_player("Ambient")
	_night = _make_player("Ambient")
	_ui = _make_player("UI")
	for i in 8:
		_sfx_pool.append(_make_player("SFX"))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func play_music_if_new(path: String, fade_time := 2.5) -> void:
	if _music_path == path and _music.playing:
		return
	play_music(path, fade_time)


func play_music(path: String, fade_time := 2.5) -> void:
	_music_path = path
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Musik tidak ditemukan: " + path)
		return
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", 0.0, fade_time)


func stop_music(fade_time := 1.0) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -40.0, fade_time)
	_music_tween.tween_callback(_music.stop)


func play_ambient(path: String, fade_time := 3.0, volume_db := -6.0) -> void:
	var stream := load(path) as AudioStreamWAV
	if stream == null:
		return
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.data.size() / ((2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if stream.stereo else 1)))
	_ambient.stream = stream
	_ambient.volume_db = -40.0
	_ambient.play()
	create_tween().tween_property(_ambient, "volume_db", volume_db, fade_time)


func silence_game_sounds() -> void:
	stop_ambient(0.0)
	stop_night_ambient()
	for k in _loops.keys():
		stop_loop(k)
	set_reverb(false)
	for c in get_children():
		if c is AudioStreamPlayer and String((c as AudioStreamPlayer).bus) in ["SFX", "Ambient", "UI"]:
			(c as AudioStreamPlayer).stop()


func stop_ambient(fade_time := 1.0) -> void:
	if not _ambient.playing:
		return
	if fade_time <= 0.0:
		_ambient.stop()
		return
	var tw := create_tween()
	tw.tween_property(_ambient, "volume_db", -50.0, fade_time)
	tw.tween_callback(func(): _ambient.stop())


var _loops := {}


func start_loop(key: String, path: String, volume_db := -10.0, bus := "Ambient") -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		return
	var st := _load_audio(path)
	if st == null:
		return
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.data.size() / ((2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if w.stereo else 1)))
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	var p := _make_player(bus)
	p.stream = st
	p.volume_db = volume_db
	p.play()
	_loops[key] = p


func stop_loop(key: String) -> void:
	if _loops.has(key):
		var p: AudioStreamPlayer = _loops[key]
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
		_loops.erase(key)


var _reverb_fx := {}


func set_reverb(on: bool, room_size := 0.8, damping := 0.45, wet := 0.30) -> void:
	for bus_name in ["SFX", "UI", "Ambient"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx == -1:
			continue
		if on:
			if _reverb_fx.has(bus_name):
				continue
			var fx := AudioEffectReverb.new()
			fx.room_size = room_size
			fx.damping = damping
			fx.wet = wet
			fx.dry = 1.0
			fx.spread = 1.0
			AudioServer.add_bus_effect(idx, fx)
			_reverb_fx[bus_name] = fx
		elif _reverb_fx.has(bus_name):
			for i in AudioServer.get_bus_effect_count(idx):
				if AudioServer.get_bus_effect(idx, i) == _reverb_fx[bus_name]:
					AudioServer.remove_bus_effect(idx, i)
					break
			_reverb_fx.erase(bus_name)


func is_ambient_playing() -> bool:
	return _ambient.playing


func play_ui(sound_name: String) -> void:
	if not _ui_cache.has(sound_name):
		_ui_cache[sound_name] = _load_audio(UI_SOUNDS.get(sound_name, "")) if UI_SOUNDS.has(sound_name) else null
	var s: AudioStream = _ui_cache[sound_name]
	if s == null:
		return
	_ui.stream = s
	_ui.play()


func play_sfx(stream: AudioStream) -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.play()
			return p
	if not _sfx_pool.is_empty():
		var p0: AudioStreamPlayer = _sfx_pool[_steal_i % _sfx_pool.size()]
		_steal_i += 1
		p0.stream = stream
		p0.play()
		return p0
	return null


var _pool_name := {}
const CUT_DASH_BY := ["swing", "hit_body", "cast"]


var _steal_i := 0


static func _load_audio(path: String) -> AudioStream:
	var r := load(path)
	if r is AudioStream:
		return r
	if path.get_extension().to_lower() == "mp3" and FileAccess.file_exists(path):
		var st := AudioStreamMP3.new()
		st.data = FileAccess.get_file_as_bytes(path)
		return st
	return null


const SFX_SOUNDS := {
	"jump": "res://assets/audio/sfx/jump.wav",
	"swing": "res://assets/audio/sfx/swing.wav",
	"hurt": "res://assets/audio/sfx/hurt.wav",
	"rumble": "res://assets/audio/sfx/rumble.wav",
	"boom": "res://assets/audio/sfx/boom.wav",
	"cast": "res://assets/audio/sfx/cast.wav",
	"m_fireball": "res://assets/audio/sfx/m_fireball.wav",
	"m_spark": "res://assets/audio/sfx/m_spark.wav",
	"m_wind": "res://assets/audio/sfx/m_wind.wav",
	"m_sky": "res://assets/audio/sfx/m_sky.wav",
	"m_flame": "res://assets/audio/sfx/m_flame.wav",
	"m_roots": "res://assets/audio/sfx/m_roots.wav",
	"m_spikes": "res://assets/audio/sfx/m_spikes.wav",
	"m_charm": "res://assets/audio/sfx/m_charm.wav",
	"library_faint": "res://assets/audio/sfx/library_faint.mp3",
	"library_5min": "res://assets/audio/sfx/library_5min.mp3",
	"thunder": "res://assets/audio/sfx/thunder.wav",
	"roar": "res://assets/audio/sfx/roar.wav",
	"m_smoke": "res://assets/audio/sfx/m_smoke.wav",
	"m_impact": "res://assets/audio/sfx/m_impact.wav",
	"hit_body": "res://assets/audio/sfx/hit_body.wav",
	"sleep": "res://assets/audio/sfx/sleep_chime.wav",
	"dash": "res://assets/audio/sfx/dash.wav",
	"game_start": "res://assets/audio/sfx/game_start.mp3",
	"barrel_explosion": "res://assets/audio/sfx/barrel_explosion.mp3",
	"crate_break": "res://assets/audio/sfx/crate_break.mp3",
	"statue_break": "res://assets/audio/sfx/statue_break.mp3",
	"vase_break": "res://assets/audio/sfx/vase_break.mp3",
	"gob_cackle": "res://assets/audio/sfx/gob_cackle.wav",
	"gob_snarl": "res://assets/audio/sfx/gob_snarl.wav",
	"gob_grunt": "res://assets/audio/sfx/gob_grunt.wav",
	"gob_shout_hi": "res://assets/audio/sfx/gob_shout_hi.wav",
	"gob_shout_mid": "res://assets/audio/sfx/gob_shout_mid.wav",
	"gob_shout_lo": "res://assets/audio/sfx/gob_shout_lo.wav",
	"gob_hurt_hi": "res://assets/audio/sfx/gob_hurt_hi.wav",
	"gob_hurt_mid": "res://assets/audio/sfx/gob_hurt_mid.wav",
	"gob_hurt_lo": "res://assets/audio/sfx/gob_hurt_lo.wav",
	"gob_death_hi": "res://assets/audio/sfx/gob_death_hi.wav",
	"gob_death_mid": "res://assets/audio/sfx/gob_death_mid.wav",
	"gob_death_lo": "res://assets/audio/sfx/gob_death_lo.wav",
	"bow_shot": "res://assets/audio/sfx/bow_shot.wav",
	"arrow_hit": "res://assets/audio/sfx/arrow_hit.wav",
}

const QUAKE_LOOP := "res://assets/audio/sfx/earthquake_loop.ogg"
var _quake: AudioStreamPlayer
var _quake_tween: Tween


func start_quake(fade_time := 0.6, volume_db := -4.0) -> void:
	if _quake == null:
		_quake = _make_player("SFX")
	var st := load(QUAKE_LOOP) as AudioStreamOggVorbis
	if st == null:
		return
	st.loop = true
	if _quake_tween:
		_quake_tween.kill()
	if not _quake.playing:
		_quake.stream = st
		_quake.volume_db = -40.0
		_quake.play()
	_quake_tween = create_tween()
	_quake_tween.tween_property(_quake, "volume_db", volume_db, fade_time)


func set_quake_distance(dist: float) -> void:
	if _quake == null or not _quake.playing or (_quake_tween != null and _quake_tween.is_running()):
		return
	var k := clampf(1.0 - dist / 1100.0, 0.0, 1.0)
	_quake.volume_db = lerpf(-40.0, -4.0, k * k)


func stop_quake(fade_time := 0.8) -> void:
	if _quake == null or not _quake.playing:
		return
	if _quake_tween:
		_quake_tween.kill()
	_quake_tween = create_tween()
	_quake_tween.tween_property(_quake, "volume_db", -40.0, fade_time)
	_quake_tween.tween_callback(_quake.stop)


func play_sfx_named(sound_name: String) -> void:
	if not _sfx_cache.has(sound_name):
		_sfx_cache[sound_name] = _load_audio(SFX_SOUNDS[sound_name]) if SFX_SOUNDS.has(sound_name) else null
	var s: AudioStream = _sfx_cache[sound_name]
	if s != null:
		if sound_name in CUT_DASH_BY:
			for p in _sfx_pool:
				if p.playing and String(_pool_name.get(p, "")) == "dash":
					p.stop()
		var pl := play_sfx(s)
		if pl != null:
			_pool_name[pl] = sound_name


func update_night_ambient(darkness: float) -> void:
	if darkness <= 0.01:
		if _night.playing:
			_night.volume_db = move_toward(_night.volume_db, -50.0, 0.6)
			if _night.volume_db <= -48.0:
				_night.stop()
		return
	if not _night.playing:
		if _night_stream == null:
			_night_stream = load(AMBIENT_NIGHT) as AudioStreamWAV
			if _night_stream == null:
				return
			var bytes := 2 if _night_stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
			var ch := 2 if _night_stream.stereo else 1
			_night_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			_night_stream.loop_begin = 0
			_night_stream.loop_end = int(_night_stream.data.size() / (bytes * ch))
		_night.stream = _night_stream
		_night.volume_db = -50.0
		_night.play()
	_night.volume_db = move_toward(_night.volume_db, lerpf(-30.0, -7.0, darkness), 0.6)


func stop_night_ambient() -> void:
	if _night.playing:
		_night.stop()
