extends RefCounted

const U = preload("res://scripts/trap_util.gd")

class Trap extends Node2D:
	var player: Node2D
	var level: Node
	var _cd := 0.0

	func _process(delta: float) -> void:
		if _cd > 0.0:
			_cd -= delta

	func hurt_if(rect: Rect2, dmg: int, from_x: float) -> void:
		if _cd > 0.0 or player == null or not is_instance_valid(player) or int(player.get("hp")) <= 0:
			return
		if rect.intersects(U.player_rect(player)):
			var d := signf(player.global_position.x - from_x)
			player.call("enemy_hit", dmg, d if d != 0.0 else 1.0)
			_cd = 0.9

	func near_player(d: float) -> bool:
		return player != null and is_instance_valid(player) and player.global_position.distance_to(global_position) < d

	func shake(power: float, sec: float, within := 420.0) -> void:
		if level != null and is_instance_valid(level) and level.has_method("shake_camera") and near_player(within):
			level.call("shake_camera", power, sec)


class SawTrap extends Trap:
	var x := 0.0
	var mount_y := 0.0
	var bottom_y := 0.0
	var period := 2.6
	var phase := 0.0
	var _spr: Sprite2D
	var _rod: ColorRect
	var _t := 0.0

	func setup(px: float, top: float, bot: float, ph: float) -> void:
		x = px
		mount_y = top
		bottom_y = bot
		phase = ph
		_rod = ColorRect.new()
		_rod.color = Color("8a4a3c")
		add_child(_rod)
		_spr = U.sprite(U.tex(U.SAW_TEX), Rect2(0, 0, 64, 64))
		add_child(_spr)

	func _process(delta: float) -> void:
		super._process(delta)
		_t += delta
		var k := (sin(_t * TAU / period + phase) + 1.0) * 0.5
		var cy := lerpf(mount_y + 40.0, bottom_y, k)
		_spr.region_rect = Rect2((int(_t * 14.0) % 16) * 64, 0, 64, 64)
		_spr.position = Vector2(x - 32.0 * U.S, cy - 17.0 * U.S)
		var top := _spr.position.y + 2.0 * U.S
		_rod.position = Vector2(x - 2.0, mount_y)
		_rod.size = Vector2(4.0, maxf(0.0, top - mount_y))
		if _cd > 0.0 or player == null or not is_instance_valid(player):
			return
		var r := U.player_rect(player)
		var c := Vector2(x, cy)
		var nearest := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		if c.distance_to(nearest) <= 19.0:
			hurt_if(r, 3, x)


class CeilingTrap extends Trap:
	const BW := 32.0 * 2.0
	const BH := 13.0 * 2.0
	var x := 0.0
	var ceil_y := 0.0
	var floor_y := 0.0
	var state := "hang"
	var _by := 0.0
	var _shake := 0.0
	var _block: Sprite2D
	var _chain: Sprite2D

	func setup(px: float, cy: float, fy: float, delay: float) -> void:
		x = px
		ceil_y = cy
		floor_y = fy
		_by = cy + 22.0
		_chain = Sprite2D.new()
		_chain.texture = U.tex(U.CEIL_CHAIN_TEX)
		_chain.region_enabled = true
		_chain.centered = false
		_chain.scale = Vector2(U.S, U.S)
		_chain.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_chain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_chain)
		_block = Sprite2D.new()
		_block.texture = U.tex(U.CEIL_BLOCK_TEX)
		_block.centered = false
		_block.scale = Vector2(U.S, U.S)
		_block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_block)
		_run(delay)

	func _run(delay: float) -> void:
		await get_tree().create_timer(delay).timeout
		var rest := ceil_y + 22.0
		var slam := floor_y - BH
		while is_inside_tree():
			state = "hang"
			await get_tree().create_timer(2.4).timeout
			state = "warn"
			var w := create_tween()
			for i in 6:
				w.tween_property(self, "_shake", 1.5 if i % 2 == 0 else -1.5, 0.05)
			w.tween_property(self, "_shake", 0.0, 0.03)
			await w.finished
			state = "fall"
			var f := create_tween()
			f.tween_property(self, "_by", slam, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			await f.finished
			state = "down"
			_impact()
			await get_tree().create_timer(0.8).timeout
			state = "rise"
			var r := create_tween()
			r.tween_property(self, "_by", rest, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			await r.finished

	func _impact() -> void:
		shake(3.0, 0.3)
		AudioManager.play_sfx_named("boom")
		var p := CPUParticles2D.new()
		p.position = Vector2(x, floor_y - 2.0)
		p.amount = 18
		p.lifetime = 0.9
		p.one_shot = true
		p.explosiveness = 1.0
		p.direction = Vector2(0, -1)
		p.spread = 80.0
		p.gravity = Vector2(0, 90)
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 95.0
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3.2
		p.color = Color(0.74, 0.71, 0.82, 0.85)
		add_child(p)
		p.emitting = true
		get_tree().create_timer(1.4).timeout.connect(p.queue_free)

	func _process(delta: float) -> void:
		super._process(delta)
		_block.position = Vector2(x - BW * 0.5 + _shake, _by)
		_chain.position = Vector2(x - BW * 0.5 + _shake, ceil_y)
		_chain.region_rect = Rect2(0, 0, 32, maxf(0.0, (_by - ceil_y) / U.S))
		hurt_if(Rect2(x - BW * 0.5 + 4.0, _by + 4.0, BW - 8.0, BH - 2.0), 5, x)


class FireTrap extends Trap:
	const IDLE := 0.3
	const WARN := 0.4
	const BURN := 2.0
	const SMOKE := 0.3
	const SEQ := [4, 5, 8, 9, 5, 8, 9, 5]
	var x := 0.0
	var base_y := 0.0
	var up := true
	var burning := false
	var _spr: Sprite2D

	func setup(px: float, by: float, is_up: bool, delay: float) -> void:
		x = px
		base_y = by
		up = is_up
		_spr = U.sprite(U.tex(U.FIRE_TEX), Rect2(0, 0, 32, 64))
		_spr.flip_v = not up
		_spr.position = Vector2(px - 16.0 * U.S, (by - 64.0 * U.S) if up else by)
		add_child(_spr)
		_run(delay)

	func _frame(i: int) -> void:
		_spr.region_rect = Rect2(i * 32, 0, 32, 64)

	func _run(delay: float) -> void:
		_frame(0)
		await get_tree().create_timer(delay).timeout
		while is_inside_tree():
			_frame(0)
			await get_tree().create_timer(IDLE).timeout
			for i in [1, 2, 3, 3]:
				_frame(i)
				await get_tree().create_timer(WARN / 4.0).timeout
			burning = true
			AudioManager.play_sfx_named("m_charm")
			for i in int(BURN / 0.1):
				_frame(SEQ[i % SEQ.size()])
				await get_tree().create_timer(0.1).timeout
			burning = false
			for i in [10, 11, 11]:
				_frame(i)
				await get_tree().create_timer(SMOKE / 3.0).timeout

	func _process(delta: float) -> void:
		super._process(delta)
		if burning:
			var r := Rect2(x - 17.0, (base_y - 100.0) if up else base_y, 34.0, 100.0)
			hurt_if(r, 2, x)


class Arrow extends Node2D:
	var player: Node2D
	var dir := 1.0
	var speed := 260.0
	var _travel := 0.0
	var _spr: Sprite2D

	func _ready() -> void:
		_spr = Sprite2D.new()
		_spr.texture = U.tex(U.ARROW_PROJ_TEX)
		_spr.scale = Vector2(U.S, U.S)
		_spr.flip_h = dir > 0.0
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_spr)
		z_index = 6

	func _process(delta: float) -> void:
		var step := speed * delta * dir
		position.x += step
		_travel += absf(step)
		if player != null and is_instance_valid(player) and int(player.get("hp")) > 0:
			var rect := Rect2(global_position + Vector2(-14.0, -2.0), Vector2(28.0, 4.0))
			if rect.intersects(U.player_rect(player)):
				player.call("enemy_hit", 2, dir)
				queue_free()
				return
		if _travel > 900.0:
			queue_free()


class ArrowTrap extends Trap:
	const INTERVAL := 5.0
	const NEAR := 120.0
	var x := 0.0
	var floor_y := 0.0
	var dir := 1.0
	var _spr: Sprite2D

	func setup(px: float, fy: float, d: float, delay: float) -> void:
		x = px
		floor_y = fy
		dir = d
		_spr = U.sprite(U.tex(U.ARROW_TEX), Rect2(0, 0, 96, 32))
		_spr.position = Vector2(px - 48.0 * U.S, fy - 32.0 * U.S)
		_spr.flip_h = d > 0.0
		_spr.visible = false
		add_child(_spr)
		_run(delay)

	func _run(delay: float) -> void:
		await get_tree().create_timer(delay).timeout
		while is_inside_tree():
			var close := player != null and is_instance_valid(player) and absf(player.global_position.x - x) < NEAR and absf(player.global_position.y - floor_y) < 120.0
			if not close:
				_cycle()
			await get_tree().create_timer(INTERVAL).timeout

	func _cycle() -> void:
		_spr.visible = true
		for i in 17:
			_spr.region_rect = Rect2(i * 96, 0, 96, 32)
			if i == 8:
				_fire()
			await get_tree().create_timer(0.1).timeout
			if not is_inside_tree():
				return
		_spr.visible = false

	func _fire() -> void:
		var a := Arrow.new()
		a.player = player
		a.dir = dir
		a.position = Vector2(x + dir * 30.0, floor_y - 32.0)
		get_parent().add_child(a)
		AudioManager.play_sfx_named("swing")
