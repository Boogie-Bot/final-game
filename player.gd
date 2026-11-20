extends Area2D

@export var speed: float = 300.0

const IDLE_ANIMATION: StringName = &"Idle"
const LEFT_ANIMATION: StringName = &"Left"
const RIGHT_ANIMATION: StringName = &"Right"
const UP_ANIMATION: StringName = &"Up"
const DOWN_ANIMATION: StringName = &"Down"

@onready var animated_sprite: AnimatedSprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("Left", "Right", "Up", "Down")
	global_position += direction * speed * delta
	_update_animation(direction)


func _update_animation(direction: Vector2) -> void:
	var animation := IDLE_ANIMATION
	if direction != Vector2.ZERO:
		if absf(direction.x) > absf(direction.y):
			animation = RIGHT_ANIMATION if direction.x > 0.0 else LEFT_ANIMATION
		else:
			animation = DOWN_ANIMATION if direction.y > 0.0 else UP_ANIMATION

	if animated_sprite.animation != animation or not animated_sprite.is_playing():
		animated_sprite.play(animation)
	
	
	
