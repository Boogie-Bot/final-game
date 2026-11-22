extends Area2D
## A floating pickup. cure_index -1 = common healing herb (reduces infection);
## 0-3 = one of the four unique cure ingredients.

const PARTICLE_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.88),  # Chamomile white
	Color(0.68, 0.52, 0.88),  # Lavender purple
	Color(0.85, 0.45, 0.62),  # Echinacea pink
	Color(0.92, 0.9, 0.8),    # Garlic cream
]
const HEAL_COLOR := Color(0.45, 0.85, 0.4)

@export var cure_index: int = -1

@onready var stack: SpriteStack = $Stack

var _time: float = randf() * TAU


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group(&"cure_herb" if cure_index >= 0 else &"heal_herb")
	if cure_index >= 0:
		stack.build(StackModels.cure_herb(cure_index))
		# Cure herbs "sing": louder as you approach.
		var hum: AudioStreamPlayer2D = Sfx.attach_loop(&"herb_hum_%d" % cure_index, self)
		hum.max_distance = 1600.0
		hum.attenuation = 2.0


func _process(delta: float) -> void:
	_time += delta
	stack.bob_offset = -8.0 + sin(_time * 2.5) * 3.0
	stack.stack_rotation += delta * 1.8


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("survivor"):
		return
	_burst(HEAL_COLOR if cure_index < 0 else PARTICLE_COLORS[cure_index])
	if cure_index >= 0:
		body.collect_cure(cure_index)
	else:
		body.collect_herb()
	queue_free()


func _burst(color: Color) -> void:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.amount = 24
	particles.lifetime = 0.55
	particles.direction = Vector2(0, -1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 140)
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 170.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = color
	particles.position = global_position + Vector2(0, -12)
	particles.z_index = 20
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
