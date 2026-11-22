extends Node2D
## A bottle flying in an arc; on landing it shatters and lures zombies.

const FLIGHT := 0.6
const ARC := 70.0

var _stack: SpriteStack


func launch(from: Vector2, to: Vector2) -> void:
	global_position = from
	z_index = 10
	_stack = SpriteStack.new()
	_stack.cast_shadow = false
	add_child(_stack)
	_stack.build(StackModels.get_frames(&"bottle"))
	var shadow := Sprite2D.new()
	shadow.texture = StackModels.shadow_texture(8, 5)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.scale = Vector2.ONE * 4.0
	shadow.z_index = -1
	add_child(shadow)
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		global_position = from.lerp(to, v)
		_stack.bob_offset = -sin(v * PI) * ARC - 4.0
		_stack.stack_rotation = v * TAU * 3.0
		shadow.scale = Vector2.ONE * (4.0 - sin(v * PI) * 1.2)
		, 0.0, 1.0, FLIGHT)
	t.tween_callback(_land.bind(to))


func _land(to: Vector2) -> void:
	Sfx.play(&"bottle_break", to)
	Game.emit_noise(to, 450.0, &"bottle")
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 22
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.6, 0.9, 0.75, 0.9)
	p.global_position = to + Vector2(0, -6)
	p.z_index = 20
	p.finished.connect(p.queue_free)
	get_parent().add_child(p)
	queue_free()
