extends CharacterBody2D
## CPU-controlled survivor that appears after the player turns. Seeks the
## remaining cure herbs, flees zombies early, and shrugs off chip damage from
## the horde (passive recovery + reduced zombie damage) — only the player
## zombie's sustained attack realistically kills them.

signal infection_changed(value: float)
signal cure_collected(index: int)
signal cured
signal died

@export var speed: float = 285.0  # slower than the player zombie (300), faster than the horde (270)
@export var flee_radius: float = 250.0
@export var recovery_rate: float = 5.0  # passive infection decay per second

var infection: float = 0.0
var cures: Array[bool] = [false, false, false, false]
var dead: bool = false

@onready var stack: SpriteStack = $Stack
@onready var hitbox: Area2D = $Hitbox

var _wander_offset := Vector2.ZERO
var _retarget: float = 0.0
var _bob_time: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_dir := Vector2.ZERO
var _desired_dir := Vector2.ZERO


func _ready() -> void:
	stack.modulate = Color(0.78, 0.88, 1.05)  # bluish tint to tell them apart


func _physics_process(delta: float) -> void:
	if dead:
		return
	if infection > 0.0:
		infection = maxf(infection - recovery_rate * delta, 0.0)
		infection_changed.emit(infection)

	var direction := _decide_direction(delta)
	# Zombies never block movement, but wading through one costs 25% speed.
	var effective_speed := speed * (0.75 if _touching_zombie() else 1.0)
	velocity = direction * effective_speed
	move_and_slide()

	# Cornered against a wall: detour perpendicular to the blocked heading
	# instead of flailing randomly, which rounds building corners.
	if direction != Vector2.ZERO and get_real_velocity().length() < 20.0 and _stuck_timer <= 0.0:
		_stuck_timer = 0.7
		# Of the two perpendicular escape routes, take the one leading away
		# from the nearest zombie so a pin becomes a slip, not a death.
		var left := _desired_dir.rotated(PI / 2.0)
		var right := _desired_dir.rotated(-PI / 2.0)
		var threat := _nearest_in_group("zombies")
		if threat:
			var away := (global_position - threat.global_position).normalized()
			_stuck_dir = left if left.dot(away) > right.dot(away) else right
		else:
			_stuck_dir = left if randf() < 0.5 else right

	if direction != Vector2.ZERO:
		stack.stack_rotation = lerp_angle(stack.stack_rotation, direction.angle(), 12.0 * delta)
		stack.play_walk(delta, 9.0)
		_bob_time += delta * 12.0
		stack.bob_offset = -absf(sin(_bob_time)) * 3.0
	else:
		stack.stand()
		stack.bob_offset = move_toward(stack.bob_offset, 0.0, 20.0 * delta)


func _touching_zombie() -> bool:
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("zombies"):
			return true
	return false


func _decide_direction(delta: float) -> Vector2:
	if _stuck_timer > 0.0:
		_stuck_timer -= delta
		return _stuck_dir

	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = randf_range(0.8, 1.6)
		_wander_offset = Vector2.from_angle(randf() * TAU) * randf_range(0.15, 0.45)

	var target := _pick_target_herb()
	var herb_dir := Vector2.ZERO
	if target:
		herb_dir = (target.global_position - global_position).normalized()

	# Collect threats; the danger zone is a bit wider than the reaction radius
	# so escape routes account for zombies just beyond it.
	var danger := flee_radius * 1.2
	var threats: Array[Node2D] = []
	var threatened := false
	for zombie in get_tree().get_nodes_in_group("zombies"):
		var dist: float = global_position.distance_to(zombie.global_position)
		if dist < danger:
			threats.append(zombie)
			if dist < flee_radius:
				threatened = true

	if threatened:
		# Escape through the biggest gap: score 16 headings by how much zombie
		# threat lies that way (a vector-sum flee cancels out when surrounded
		# and gets the survivor dogpiled). Small bias toward the target herb
		# keeps evasion making progress.
		var best_dir := Vector2.ZERO
		var best_score := INF
		for k in 16:
			var dir := Vector2.from_angle(k * TAU / 16.0)
			var score := 0.0
			for zombie in threats:
				var to_zombie: Vector2 = zombie.global_position - global_position
				var dist := maxf(to_zombie.length(), 1.0)
				score += maxf(dir.dot(to_zombie / dist), 0.0) * (1.0 - dist / danger)
			score -= 0.15 * dir.dot(herb_dir)
			if score < best_score:
				best_score = score
				best_dir = dir
		_desired_dir = (best_dir + _wander_offset * 0.2).normalized()
		return _desired_dir

	if herb_dir != Vector2.ZERO:
		_desired_dir = (herb_dir + _wander_offset * 0.35).normalized()
		return _desired_dir
	_desired_dir = _wander_offset.normalized() if _wander_offset != Vector2.ZERO else Vector2.ZERO
	return _desired_dir


func _pick_target_herb() -> Node2D:
	# Detour to a healing herb when getting sick
	if infection > 35.0:
		var heal := _nearest_in_group("heal_herb")
		if heal and global_position.distance_to(heal.global_position) < 450.0:
			return heal
	return _nearest_in_group("cure_herb")


func _nearest_in_group(group: StringName) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group(group):
		var d: float = global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func add_infection(amount: float) -> void:
	if dead:
		return
	infection = clampf(infection + amount, 0.0, 100.0)
	infection_changed.emit(infection)
	if infection >= 100.0:
		_die()


func collect_herb() -> void:
	if dead:
		return
	add_infection(-20.0)


func collect_cure(index: int) -> void:
	if dead or cures[index]:
		return
	cures[index] = true
	cure_collected.emit(index)
	if cures.all(func(c: bool) -> bool: return c):
		cured.emit()


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	remove_from_group("survivor")
	stack.modulate = Color(0.55, 0.65, 0.5)
	stack.collapse()
	died.emit()
