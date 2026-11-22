extends Node
## "I wish it would rain": screen rain, gloom, thunder and slowing, noisy puddles.

const MAX_PUDDLES := 30

var main
var _active := false
var _modulate: CanvasModulate
var _flash: ColorRect
var _puddles: Array[Area2D] = []
var _puddle_timer := 6.0
var _thunder_timer := 25.0
var _rain_layer: CanvasLayer
var _rain: CPUParticles2D
var _inside: Dictionary = {}  # puddle instance id -> true while player in it
var _step_timer := 0.0


func setup(m) -> void:
	main = m


func _start_rain() -> void:
	_active = true
	_modulate = CanvasModulate.new()
	_modulate.color = Color(0.72, 0.76, 0.86)
	add_child(_modulate)
	_rain_layer = CanvasLayer.new()
	_rain_layer.layer = 4
	add_child(_rain_layer)
	_rain = CPUParticles2D.new()
	_rain.texture = StackModels.raindrop_texture()
	_rain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var vp := get_viewport().get_visible_rect().size
	_rain.position = Vector2(vp.x * 0.5, -40)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(vp.x * 0.75, 10)
	_rain.amount = 260
	_rain.lifetime = 0.9
	_rain.preprocess = 1.0
	_rain.direction = Vector2(-0.25, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = vp.y * 1.1
	_rain.initial_velocity_max = vp.y * 1.4
	_rain.scale_amount_min = 2.0
	_rain.scale_amount_max = 3.0
	_rain.angle_min = 14.0
	_rain.angle_max = 14.0
	_rain.color = Color(0.8, 0.88, 1.0, 0.7)
	_rain_layer.add_child(_rain)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain_layer.add_child(_flash)
	Sfx.attach_global_loop(&"rain_loop", self)
	_thunder_timer = randf_range(20.0, 45.0)


func _process(delta: float) -> void:
	if not Game.started or main == null or main.player == null:
		return
	if not Game.raining:
		return
	if not _active:
		_start_rain()
	var vp := get_viewport().get_visible_rect().size
	_rain.position = Vector2(vp.x * 0.5, -40)
	_thunder_timer -= delta
	if _thunder_timer <= 0.0:
		_thunder_timer = randf_range(20.0, 45.0)
		_thunder()
	_puddle_timer -= delta
	if _puddle_timer <= 0.0:
		_puddle_timer = randf_range(5.0, 12.0)
		_spawn_puddle()
	_check_player_puddles(delta)


func _thunder() -> void:
	Sfx.play(&"thunder")
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.55, 0.05)
	t.tween_property(_flash, "color:a", 0.1, 0.08)
	t.tween_property(_flash, "color:a", 0.4, 0.05)
	t.tween_property(_flash, "color:a", 0.0, 0.5)


func _spawn_puddle() -> void:
	var player = main.player
	var origin: Vector2 = player.global_position
	if int(player.get("interior_id")) >= 0 and player.get("outside_position") is Vector2:
		origin = player.outside_position
	var rect: Rect2 = main.map_rect() if main.has_method("map_rect") else Rect2(0, 0, 2400, 1440)
	rect = rect.grow(-60.0)
	for attempt in 12:
		var p := origin + Vector2.from_angle(randf() * TAU) * randf_range(250.0, 650.0)
		if rect.has_point(p) and not main.point_in_building(p):
			_make_puddle(p)
			return


func _make_puddle(pos: Vector2) -> void:
	var a := Area2D.new()
	a.add_to_group(&"puddles")
	a.collision_layer = 0
	a.collision_mask = 4
	a.z_index = -7
	a.position = pos
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 24.0
	cs.shape = shape
	a.add_child(cs)
	var s := Sprite2D.new()
	s.texture = StackModels.puddle_texture(randi() % 4)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ZERO
	a.add_child(s)
	main.add_child(a)
	create_tween().tween_property(s, "scale", Vector2.ONE * 4.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_puddles.append(a)
	if _puddles.size() > MAX_PUDDLES:
		var old: Area2D = _puddles.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func _check_player_puddles(delta: float) -> void:
	var player = main.player
	_step_timer -= delta
	if player.get("is_zombie") == true:
		return
	var in_any := false
	for pd in _puddles:
		if not is_instance_valid(pd):
			continue
		var id := pd.get_instance_id()
		if pd.overlaps_body(player):
			in_any = true
			player.apply_slow(0.75, 0.3)
			var moving: bool = player.velocity.length() > 20.0 if "velocity" in player else true
			if not _inside.has(id):
				_inside[id] = true
				_splash(player.global_position)
				_step_timer = 0.45
			elif moving and _step_timer <= 0.0:
				_step_timer = 0.45
				_splash(player.global_position)
		else:
			_inside.erase(id)
	if not in_any:
		_inside.clear()


func _splash(pos: Vector2) -> void:
	Game.emit_noise(pos, 300.0, &"puddle")
	Sfx.play(&"puddle_splash", pos)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.gravity = Vector2(0, 260)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.6, 0.75, 0.95, 0.85)
	p.global_position = pos
	p.z_index = 20
	p.finished.connect(p.queue_free)
	main.add_child(p)
