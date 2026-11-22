extends StaticBody2D
## A parked car. Touching it as the human player sets off the alarm: it flashes,
## and shouts for 4s so every zombie nearby comes running.

const ALARM_TIME := 4.0
const COOLDOWN := 6.0
const RADIUS := 1000.0

var car_rot := 0.0
var _stack: SpriteStack
var _trigger: Area2D
var _loop: AudioStreamPlayer2D
var _alarm_left := 0.0
var _cooldown := 0.0
var _noise_timer := 0.0
var _ring: Node2D
var _ring_t := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group(&"cars")


## Builds collider, sprite stack and the alarm trigger. Call before add_child.
func setup(pos: Vector2, rot: float, color_index: int) -> void:
	position = pos
	car_rot = rot
	collision_layer = 1
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72, 38)
	collider.shape = shape
	collider.rotation = rot
	add_child(collider)

	_stack = SpriteStack.new()
	add_child(_stack)
	_stack.build(StackModels.car(color_index))
	_stack.stack_rotation = rot

	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 4
	var tc := CollisionShape2D.new()
	var ts := RectangleShape2D.new()
	ts.size = Vector2(84, 50)
	tc.shape = ts
	tc.rotation = rot
	_trigger.add_child(tc)
	add_child(_trigger)
	_trigger.body_entered.connect(_on_body_entered)

	_loop = Sfx.attach_loop(&"car_alarm", self, 0.0, false)

	_ring = Node2D.new()
	_ring.z_index = 15
	_ring.top_level = true
	_ring.visible = false
	_ring.draw.connect(_draw_ring)
	add_child(_ring)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") and body.get("is_zombie") != true:
		trigger_alarm()


func trigger_alarm() -> void:
	if _alarm_left > 0.0 or _cooldown > 0.0:
		return
	_alarm_left = ALARM_TIME
	_noise_timer = 0.0
	_ring_t = 0.0
	_ring.global_position = global_position
	_ring.visible = true
	if _loop.stream:
		_loop.play()


func _process(delta: float) -> void:
	_t += delta
	if _alarm_left > 0.0:
		_alarm_left -= delta
		_noise_timer -= delta
		if _noise_timer <= 0.0:
			_noise_timer = 0.5
			Game.emit_noise(global_position, RADIUS, &"car_alarm")
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		_stack.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.9, 1.7, 0.6), pulse)
		_ring_t = fmod(_ring_t + delta, 1.0)
		_ring.queue_redraw()
		if _alarm_left <= 0.0:
			_alarm_left = 0.0
			_cooldown = COOLDOWN
			_stack.modulate = Color.WHITE
			_ring.visible = false
			_loop.stop()
	elif _cooldown > 0.0:
		_cooldown -= delta
	elif _trigger != null:
		for b in _trigger.get_overlapping_bodies():
			if b.is_in_group(&"player") and b.get("is_zombie") != true:
				trigger_alarm()
				break


func _draw_ring() -> void:
	var r := RADIUS * _ring_t
	_ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1.0, 0.4, 0.2, 0.5 * (1.0 - _ring_t)), 3.0)
	_ring.draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 96, Color(1.0, 0.3, 0.2, 0.12), 2.0)
