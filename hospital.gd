extends Node
## The abandoned Mercy Hospital: the lab at its east door where the cure is
## brewed. Brewing needs a survivor carrying all four cures to stand at the lab
## for BREW_TIME seconds; zombies smash in through the windows meanwhile.

const BREW_TIME := 20.0
const LAB_RADIUS := 90.0
const SMASH_START := 2.5
const SMASH_END := 1.2
const VARIANTS: Array[StringName] = [&"walker", &"runner", &"brute"]

var main = null
var _root: Node2D
var _building: Dictionary = {}
var _lab: Vector2 = Vector2.ZERO
var _progress: float = 0.0
var _active: bool = false
var _done: bool = false
var _hinted: bool = false
var _smash_timer: float = SMASH_START
var _bubbles: CPUParticles2D
var _loop: AudioStreamPlayer2D


func setup(m) -> void:
	main = m
	_root = Node2D.new()
	_root.name = "Hospital"
	main.add_child(_root)
	_pick_building()
	if _building.is_empty():
		return
	_build_visuals()


## Where the brew happens: just outside the hospital's east door.
func lab_position() -> Vector2:
	return _lab


func building() -> Dictionary:
	return _building


func progress() -> float:
	return _progress


func _pick_building() -> void:
	var best: Dictionary = {}
	var options: Array[Dictionary] = []
	for b in main.buildings:
		if b.alive and b.kind == &"normal" and Game.district_index(b.center) == 3:
			options.append(b)
	if options.is_empty():  # fallback: any normal building
		for b in main.buildings:
			if b.alive and b.kind == &"normal":
				options.append(b)
	if options.is_empty():
		return
	best = options[randi() % options.size()]
	best.kind = &"hospital"
	_building = best
	var center: Vector2 = best.center
	var size: Vector2 = best.size
	_lab = center + Vector2(size.x / 2.0 + 44.0, 0.0)


func _build_visuals() -> void:
	var body = _building.body
	var height_px: float = _building.height_px
	if is_instance_valid(body):
		var cross := SpriteStack.new()
		cross.model = &"hospital_cross"
		cross.cast_shadow = false
		cross.position = Vector2(0, -height_px)
		body.add_child(cross)

	var center: Vector2 = _building.center
	var size: Vector2 = _building.size
	var label := Label.new()
	label.text = "MERCY HOSPITAL"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.0))
	label.add_theme_constant_override("outline_size", 5)
	label.size = Vector2(160, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(center.x + size.x / 2.0 - 40.0, center.y - 78.0)
	label.z_index = 50
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(label)

	# Ground decal: red circle outline and cross.
	var decal := Node2D.new()
	decal.position = _lab
	decal.z_index = -6
	decal.draw.connect(func() -> void:
		decal.draw_arc(Vector2.ZERO, LAB_RADIUS * 0.55, 0.0, TAU, 40, Color(0.85, 0.15, 0.15, 0.7), 4.0)
		decal.draw_rect(Rect2(-5, -22, 10, 44), Color(0.85, 0.15, 0.15, 0.7))
		decal.draw_rect(Rect2(-22, -5, 44, 10), Color(0.85, 0.15, 0.15, 0.7)))
	_root.add_child(decal)
	decal.queue_redraw()

	var bench := StaticBody2D.new()
	bench.position = _lab + Vector2(34, -58)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(48, 40)
	collider.shape = shape
	bench.add_child(collider)
	var bench_stack := SpriteStack.new()
	bench_stack.model = &"lab_bench"
	bench.add_child(bench_stack)
	_root.add_child(bench)
	main.register_obstacle(bench.position, 32.0)

	_bubbles = CPUParticles2D.new()
	_bubbles.position = _lab
	_bubbles.emitting = false
	_bubbles.amount = 18
	_bubbles.lifetime = 1.0
	_bubbles.direction = Vector2(0, -1)
	_bubbles.spread = 40.0
	_bubbles.initial_velocity_min = 25.0
	_bubbles.initial_velocity_max = 55.0
	_bubbles.gravity = Vector2.ZERO
	_bubbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_bubbles.emission_sphere_radius = 22.0
	_bubbles.scale_amount_min = 2.0
	_bubbles.scale_amount_max = 5.0
	_bubbles.color = Color(0.4, 1.0, 0.45, 0.75)
	_bubbles.z_index = 20
	_root.add_child(_bubbles)

	var loop_holder := Node2D.new()
	loop_holder.position = _lab
	_root.add_child(loop_holder)
	_loop = Sfx.attach_loop(&"brew_bubble", loop_holder, 0.0, false)


func _process(delta: float) -> void:
	if main == null or _building.is_empty() or _done:
		return
	var brewer: Node = _find_brewer()
	var now_active := brewer != null
	if now_active and not _active and not _hinted:
		_hinted = true
		Game.say("Brewing... survive %d seconds!" % int(BREW_TIME), Color(0.5, 1.0, 0.5))
	elif now_active and not _active and _progress > 0.0:
		Game.say("Brewing resumed...", Color(0.5, 1.0, 0.5))
	_active = now_active
	_bubbles.emitting = _active
	if _loop.stream:
		if _active and not _loop.playing:
			_loop.play()
		elif not _active and _loop.playing:
			_loop.stop()

	if _active:
		_progress = minf(_progress + delta, BREW_TIME)
		_smash_timer -= delta
		if _smash_timer <= 0.0:
			_smash_timer = lerpf(SMASH_START, SMASH_END, _progress / BREW_TIME)
			_smash_window()
	if _progress > 0.0:
		Game.brew_progress.emit(_progress, BREW_TIME, _active)
	if _active and _progress >= BREW_TIME:
		_done = true
		_active = false
		_bubbles.emitting = false
		if _loop.stream:
			_loop.stop()
		Game.brew_progress.emit(_progress, BREW_TIME, false)
		if brewer.has_method("finish_cure"):
			brewer.finish_cure()


## A survivor with every cure standing at the lab, or null.
func _find_brewer() -> Node:
	for body in get_tree().get_nodes_in_group("survivor"):
		if not (body is Node2D) or not is_instance_valid(body):
			continue
		var dead = body.get("dead")
		if dead != null and dead:
			continue
		var iid = body.get("interior_id")
		if iid != null and int(iid) >= 0:
			continue
		var cures = body.get("cures")
		if not (cures is Array) or cures.is_empty():
			continue
		var all_cures := true
		for c in cures:
			if not c:
				all_cures = false
		if all_cures and (body as Node2D).global_position.distance_to(_lab) <= LAB_RADIUS:
			return body
	return null


func _smash_window() -> void:
	var rect: Rect2 = _building.rect
	# Pick a point on the perimeter (side weighted by length).
	var t := randf() * (rect.size.x + rect.size.y) * 2.0
	var edge: Vector2
	var normal: Vector2
	if t < rect.size.x:
		edge = Vector2(rect.position.x + t, rect.position.y)
		normal = Vector2.UP
	elif t < rect.size.x + rect.size.y:
		edge = Vector2(rect.end.x, rect.position.y + t - rect.size.x)
		normal = Vector2.RIGHT
	elif t < rect.size.x * 2.0 + rect.size.y:
		edge = Vector2(rect.end.x - (t - rect.size.x - rect.size.y), rect.end.y)
		normal = Vector2.DOWN
	else:
		edge = Vector2(rect.position.x, rect.end.y - (t - rect.size.x * 2.0 - rect.size.y))
		normal = Vector2.LEFT
	_glass_burst(edge)
	Sfx.play(&"window_smash", edge)
	Game.emit_noise(edge, 300.0, &"window_smash")
	var spawn_at: Vector2 = edge + normal * 34.0
	if main.has_method("spawn_zombie"):
		main.spawn_zombie(spawn_at, VARIANTS[randi() % VARIANTS.size()])


func _glass_burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 22
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.75, 0.92, 1.0, 0.9)
	p.z_index = 30
	_root.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
