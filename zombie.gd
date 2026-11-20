extends CharacterBody2D

@export var wander_speed: float = 80.0
@export var chase_speed: float = 270.0
@export var sight_range: float = 280.0
@export var infection_rate: float = 35.0  # vs the human player
@export var survivor_infection_rate: float = 17.5  # half the rate used on the human player

@onready var stack: SpriteStack = $Stack
@onready var hitbox: Area2D = $Hitbox

var _wander_dir := Vector2.ZERO
var _wander_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var target := _nearest_survivor()
	var target_velocity := Vector2.ZERO
	var chasing := false

	if target:
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() < sight_range:
			chasing = true
			target_velocity = to_target.normalized() * chase_speed

	if not chasing:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(1.0, 3.0)
			_wander_dir = Vector2.ZERO if randf() < 0.3 else Vector2.from_angle(randf() * TAU)
		target_velocity = _wander_dir * wander_speed

	velocity = velocity.move_toward(target_velocity, 600.0 * delta)
	move_and_slide()

	if velocity.length() > 5.0:
		stack.stack_rotation = lerp_angle(stack.stack_rotation, velocity.angle(), 8.0 * delta)
		stack.play_walk(delta, clampf(velocity.length() / 16.0, 4.0, 10.0))
	else:
		stack.stand()

	if target and hitbox.overlaps_body(target):
		var rate := infection_rate if target.is_in_group("player") else survivor_infection_rate
		target.add_infection(rate * delta)


## Nearest member of the "survivor" group: the human player while alive,
## the CPU survivor after the player has turned.
func _nearest_survivor() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("survivor"):
		var d: float = global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best
