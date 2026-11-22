extends Node
## ZMP — an EMP for zombies. Detonates instantly from the player: a crackling
## pulse expands to cover ~80% of the screen and fries every zombie it touches.

const PULSE_TIME := 0.55

var main


func setup(m) -> void:
	main = m


## Radius (world units) of a circle whose area is 80% of the visible screen.
func _blast_radius() -> float:
	var view: Vector2 = main.get_viewport().get_visible_rect().size
	if main.player and main.player.camera:
		view /= main.player.camera.zoom
	return sqrt(0.8 * view.x * view.y / PI)


## Fires the pulse from `pos`. Always succeeds.
func detonate(pos: Vector2) -> void:
	Game.say("ZMP detonated!", Color(0.5, 0.9, 1.0))
	Sfx.play(&"zmp_blast", pos)
	Game.emit_noise(pos, 1400.0, &"explosion")
	if main.player and main.player.has_method("shake"):
		main.player.shake(12.0)
	_flash(pos)
	_sparks(pos)
	_run_pulse(pos, _blast_radius())


## Expands the ring over PULSE_TIME, frying zombies as the edge passes them.
func _run_pulse(pos: Vector2, radius: float) -> void:
	var ring := _make_ring(pos)
	var elapsed := 0.0
	var fried := 0
	while elapsed < PULSE_TIME:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / PULSE_TIME, 0.0, 1.0)
		var eased := 1.0 - (1.0 - t) * (1.0 - t)  # ease-out
		var r := radius * eased
		ring.scale = Vector2.ONE * (r / 100.0)
		ring.modulate.a = 0.9 * (1.0 - t * t)
		fried += _fry_within(pos, r)
	ring.queue_free()
	if fried > 0:
		Game.say("%d zombie%s fried!" % [fried, "" if fried == 1 else "s"], Color(0.6, 1.0, 0.9))


## Crushes every hostile zombie within `r` of pos (never the player, never
## fed allies). Returns how many were hit.
func _fry_within(pos: Vector2, r: float) -> int:
	var n := 0
	for z in get_tree().get_nodes_in_group(&"zombies"):
		if not z is Node2D or z.is_in_group(&"player") or not z.has_method("crush"):
			continue
		if pos.distance_to(z.global_position) <= r:
			_zap_burst(z.global_position)
			z.crush()
			n += 1
	return n


func _make_ring(pos: Vector2) -> Line2D:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 49:
		pts.append(Vector2.from_angle(TAU * i / 48.0) * 100.0)
	ring.points = pts
	ring.width = 7.0
	ring.default_color = Color(0.45, 0.9, 1.0, 0.9)
	ring.z_index = 30
	ring.global_position = pos
	ring.scale = Vector2(0.01, 0.01)
	main.add_child(ring)
	return ring


func _flash(pos: Vector2) -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.6, 0.9, 1.0, 0.35)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud: Node = main.get_node_or_null("HUD")
	(hud if hud else main).add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.35)
	tw.tween_callback(flash.queue_free)


func _sparks(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 70
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 220.0
	p.initial_velocity_max = 620.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.55, 0.95, 1.0)
	p.global_position = pos
	p.z_index = 28
	p.finished.connect(p.queue_free)
	main.add_child(p)


## Small electric pop where a zombie fries.
func _zap_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.35
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.7, 1.0, 1.0)
	p.global_position = pos
	p.z_index = 28
	p.finished.connect(p.queue_free)
	main.add_child(p)
