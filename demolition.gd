extends Node
## Demolition charges: plant, 3s fuse, boom, and the building topples south,
## crushing everything in its shadow and leaving a permanent shortcut.

const FUSE := 3.0

var main


func setup(m) -> void:
	main = m


func _find_building(pos: Vector2) -> Variant:
	for b in main.buildings:
		if b.alive and b.kind == &"normal" and b.rect.grow(36.0).has_point(pos):
			return b
	return null


## Plants a charge at pos next to a normal building. Returns false (and hints) if there is none.
func place_charge(pos: Vector2) -> bool:
	var b = _find_building(pos)
	if b == null:
		Game.say("Place the charge next to a building.", Color(1.0, 0.8, 0.4))
		return false
	Game.say("Charge planted! Get clear!", Color(1.0, 0.45, 0.25))
	var stack := SpriteStack.new()
	stack.cast_shadow = false
	stack.position = pos
	main.add_child(stack)
	stack.build(StackModels.get_frames(&"charge"))
	_run_fuse(b, pos, stack)
	return true


func _run_fuse(b: Dictionary, pos: Vector2, stack: SpriteStack) -> void:
	var left := FUSE
	var next_beep := 0.0
	while left > 0.0:
		if next_beep <= 0.0:
			Sfx.play(&"charge_beep", pos)
			next_beep = lerpf(0.18, 0.5, left / FUSE)
			stack.modulate = Color(2.0, 0.6, 0.5)
		elif next_beep < lerpf(0.18, 0.5, left / FUSE) - 0.08:
			stack.modulate = Color.WHITE
		await get_tree().process_frame
		var d := get_process_delta_time()
		left -= d
		next_beep -= d
	stack.queue_free()
	_explode(b, pos)


func _explode(b: Dictionary, pos: Vector2) -> void:
	Sfx.play(&"explosion", pos)
	_burst(pos, 60, 320.0, Color(1.0, 0.6, 0.2), 0.8)
	_burst(pos, 40, 200.0, Color(0.3, 0.3, 0.3, 0.8), 1.4)
	Game.emit_noise(pos, 1400.0, &"explosion")
	if main.player and main.player.has_method("shake"):
		main.player.shake(14.0)
	if not b.alive:
		return
	_collapse(b)


func _collapse(b: Dictionary) -> void:
	var stack: SpriteStack = b.stack
	var rect: Rect2 = b.rect
	for s in stack.get_slices():
		s.material = null
	Sfx.play(&"building_collapse", b.center)
	var dust := Timer.new()
	dust.wait_time = 0.15
	dust.autostart = true
	add_child(dust)
	dust.timeout.connect(func() -> void:
		var p := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y + float(b.height_px)))
		_burst(p, 14, 90.0, Color(0.6, 0.57, 0.52, 0.7), 1.2))
	var tween: Tween = stack.topple(Vector2.DOWN, 1.4)
	if tween:
		await tween.finished
	dust.queue_free()
	_land(b)


func _land(b: Dictionary) -> void:
	var rect: Rect2 = b.rect
	var fall := Rect2(rect.position.x, rect.position.y, rect.size.x, rect.size.y + float(b.height_px))
	var map_r: Rect2 = main.map_rect() if main.has_method("map_rect") else Rect2(0, 0, 2400, 1440)
	fall = fall.intersection(map_r)
	Game.emit_noise(fall.get_center(), 900.0, &"explosion")
	if main.player and main.player.has_method("shake"):
		main.player.shake(10.0)
	for z in get_tree().get_nodes_in_group(&"zombies") + get_tree().get_nodes_in_group(&"fed_zombie"):
		if z is Node2D and fall.has_point(z.global_position) and not z.is_in_group(&"player") and z.has_method("crush"):
			z.crush()
	for s in get_tree().get_nodes_in_group(&"survivor"):
		if s is Node2D and fall.has_point(s.global_position) and s.get("is_zombie") != true and s.has_method("add_infection"):
			s.add_infection(1000.0)
	for c in get_tree().get_nodes_in_group(&"crates"):
		if c is Node2D and fall.has_point(c.global_position):
			c.queue_free()
	var col: Node = b.body.get_node_or_null("CollisionShape2D")
	if col == null:
		for ch in b.body.get_children():
			if ch is CollisionShape2D:
				col = ch
				break
	if col:
		col.set_deferred("disabled", true)
	var stack: SpriteStack = b.stack
	stack.slice_material = null
	stack.material_from_layer = 0
	stack.stack_rotation = 0.0
	stack.build(StackModels.rubble(int(b.canvas_w), int(b.canvas_d)))
	b.alive = false
	for i in 6:
		var r := SpriteStack.new()
		r.cast_shadow = false
		r.position = Vector2(randf_range(fall.position.x + 12, fall.end.x - 12), randf_range(fall.position.y + 12, fall.end.y - 12))
		main.add_child(r)
		r.build(StackModels.rubble(10, 8))
		r.stack_rotation = randf() * TAU
	_burst(fall.get_center(), 50, 160.0, Color(0.6, 0.57, 0.52, 0.8), 1.6)
	Game.say("The building collapses — a new shortcut!", Color(1.0, 0.8, 0.4))


func _burst(pos: Vector2, amount: int, speed: float, color: Color, life: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 30)
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = color
	p.global_position = pos
	p.z_index = 25
	p.finished.connect(p.queue_free)
	main.add_child(p)
