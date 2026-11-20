extends CharacterBody2D

signal infection_changed(value: float)
signal herbs_changed(count: int)
signal cure_collected(index: int)
signal won
signal turned_zombie

const CURE_NAMES: Array[String] = ["Chamomile", "Lavender", "Echinacea", "Garlic"]

@export var speed: float = 300.0
@export var zombie_speed: float = 290.0  # slightly above the horde (270), above the survivor (285)
@export var herb_cure: float = 20.0
@export var attack_rate: float = 60.0

var infection: float = 0.0
var herbs: int = 0
var cures: Array[bool] = [false, false, false, false]
var is_zombie: bool = false
var dead: bool = false  # only set when the run ends; freezes input

@onready var stack: SpriteStack = $Stack
@onready var camera: Camera2D = $Camera2D
@onready var infect_particles: CPUParticles2D = $InfectParticles
@onready var hitbox: Area2D = $ZombieHitbox

var _bob_time: float = 0.0
var _shake_strength: float = 0.0
var _infected_recently: float = 0.0


func _physics_process(delta: float) -> void:
	_update_juice(delta)
	if dead:
		return
	var direction := Input.get_vector("Left", "Right", "Up", "Down")
	velocity = direction * (zombie_speed if is_zombie else speed)
	move_and_slide()

	if direction != Vector2.ZERO:
		stack.stack_rotation = lerp_angle(stack.stack_rotation, direction.angle(), 12.0 * delta)
		stack.play_walk(delta, 9.0)
		_bob_time += delta * 12.0
		stack.bob_offset = -absf(sin(_bob_time)) * 3.0
	else:
		stack.stand()
		stack.bob_offset = move_toward(stack.bob_offset, 0.0, 20.0 * delta)

	if is_zombie:
		_attack_survivors(delta)


func _attack_survivors(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("survivor"):
		if hitbox.overlaps_body(node):
			node.add_infection(attack_rate * delta)
			_shake_strength = maxf(_shake_strength, 4.0)


func _update_juice(delta: float) -> void:
	if _shake_strength > 0.05:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, 30.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	_infected_recently = maxf(_infected_recently - delta, 0.0)
	infect_particles.emitting = _infected_recently > 0.0 and not dead


func add_infection(amount: float) -> void:
	if dead or is_zombie:
		return
	if amount > 0.0:
		_shake_strength = maxf(_shake_strength, 6.0)
		_infected_recently = 0.2
	infection = clampf(infection + amount, 0.0, 100.0)
	infection_changed.emit(infection)
	if infection >= 100.0:
		_turn_zombie()


func collect_herb() -> void:
	if dead or is_zombie:
		return
	herbs += 1
	_shake_strength = maxf(_shake_strength, 3.0)
	herbs_changed.emit(herbs)
	add_infection(-herb_cure)


func collect_cure(index: int) -> void:
	if dead or is_zombie or cures[index]:
		return
	cures[index] = true
	_shake_strength = maxf(_shake_strength, 4.0)
	cure_collected.emit(index)
	if cures.all(func(c: bool) -> bool: return c):
		dead = true
		velocity = Vector2.ZERO
		won.emit()


func _turn_zombie() -> void:
	is_zombie = true
	remove_from_group("survivor")
	add_to_group("zombies")
	stack.build(StackModels.get_frames(&"zombie"))
	_shake_strength = 12.0
	turned_zombie.emit()
