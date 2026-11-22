extends CharacterBody2D

signal infection_changed(value: float)
signal herbs_changed(count: int)
signal cure_collected(index: int)
signal won
signal turned_zombie
signal stamina_changed(value: float, max_value: float)
signal inventory_changed(inventory: Dictionary)
signal serum_changed(time_left: float)
signal all_cures_collected
signal cooldowns_changed(shove_left: float, roar_left: float)
signal cures_spent(indices: Array)

const CURE_NAMES: Array[String] = ["Chamomile", "Lavender", "Echinacea", "Garlic"]

@export var speed: float = 300.0
@export var zombie_speed: float = 290.0  # slightly above the horde (270), above the survivor (285)
@export var herb_cure: float = 20.0
@export var attack_rate: float = 120.0  # player-zombie drain vs CPU survivor; set per difficulty by main.gd
@export var sprint_mult: float = 1.6
@export var max_stamina: float = 100.0
@export var stamina_drain: float = 35.0
@export var stamina_regen: float = 20.0
@export var stamina_regen_delay: float = 0.8
@export var sprint_resume_fraction: float = 0.3
@export var tonic_free_time: float = 8.0
@export var shove_cooldown: float = 2.0
@export var shove_range: float = 70.0
@export var serum_duration: float = 60.0
@export var serum_factor: float = 0.4
@export var interact_range: float = 56.0
@export var feed_range: float = 70.0
@export var roar_cooldown: float = 10.0
@export var roar_radius: float = 700.0
@export var lunge_cooldown: float = 3.0
@export var lunge_time: float = 0.3
@export var lunge_mult: float = 2.5

var infection: float = 0.0
var herbs: int = 0
var cures: Array[bool] = [false, false, false, false]
var is_zombie: bool = false
var dead: bool = false  # only set when the run ends; freezes input
var stamina: float = 100.0
var inventory := {bottle = 0, tonic = 0, zmp = 0}
var rooted: bool = false
var interior_id: int = -1
var in_safe_house: bool = false
var outside_position: Vector2 = Vector2.ZERO
var speed_mult: float = 1.0
var serum_time: float = 0.0

@onready var stack: SpriteStack = $Stack
@onready var camera: Camera2D = $Camera2D
@onready var infect_particles: CPUParticles2D = $InfectParticles
@onready var hitbox: Area2D = $ZombieHitbox

var _bob_time: float = 0.0
var _shake_strength: float = 0.0
var _infected_recently: float = 0.0
var _speed_base: float = 300.0
var _sprinting: bool = false
var _exhausted: bool = false
var _regen_wait: float = 0.0
var _footstep_t: float = 0.0
var _no_drain_time: float = 0.0
var _shove_left: float = 0.0
var _shove_anim: float = -1.0
var _roar_left: float = 0.0
var _lunge_left: float = 0.0
var _lunge_t: float = 0.0
var _lunge_dir := Vector2.RIGHT
var _kb_vel := Vector2.ZERO
var _kb_time: float = 0.0
var _slows: Array = []  # [mult, time_left]
var _was_in_building: bool = false
var _cd_sent := Vector2(-1, -1)
var _serum_sent: int = -1
var _theme_loop: Node = null


func _ready() -> void:
	_speed_base = speed
	if Game.perks.get("fast_walk", false):
		speed *= 1.12
		zombie_speed *= 1.12
	stamina = max_stamina
	outside_position = global_position


func _physics_process(delta: float) -> void:
	_update_juice(delta)
	if dead:
		return
	if interior_id == -1:
		outside_position = global_position
	_tick_timers(delta)

	var direction := Input.get_vector("Left", "Right", "Up", "Down")
	if rooted:
		direction = Vector2.ZERO

	var mult := speed_mult
	if is_zombie:
		_zombie_actions(delta, direction)
		velocity = direction * zombie_speed * mult
		if _lunge_t > 0.0:
			velocity = _lunge_dir * zombie_speed * lunge_mult
	else:
		_human_actions(direction)
		_update_sprint(delta, direction)
		velocity = direction * speed * mult * (sprint_mult if _sprinting else 1.0)
	if _kb_time > 0.0:
		velocity = _kb_vel * (_kb_time / 0.25)
	if rooted and _kb_time <= 0.0:
		velocity = Vector2.ZERO
	move_and_slide()

	if is_zombie:
		_check_building_entry()

	if _shove_anim >= 0.0:
		_update_shove_anim(delta)
	elif direction != Vector2.ZERO or _lunge_t > 0.0:
		var face := direction if direction != Vector2.ZERO else _lunge_dir
		stack.stack_rotation = lerp_angle(stack.stack_rotation, face.angle(), 12.0 * delta)
		stack.play_walk(delta, 9.0 * (1.5 if _sprinting else 1.0))
		_bob_time += delta * (16.0 if _sprinting else 12.0)
		stack.bob_offset = -absf(sin(_bob_time)) * 3.0
	else:
		stack.stand()
		stack.bob_offset = move_toward(stack.bob_offset, 0.0, 20.0 * delta)

	if is_zombie:
		_attack_survivors(delta)


func _tick_timers(delta: float) -> void:
	_shove_left = maxf(_shove_left - delta, 0.0)
	_roar_left = maxf(_roar_left - delta, 0.0)
	_lunge_left = maxf(_lunge_left - delta, 0.0)
	_lunge_t = maxf(_lunge_t - delta, 0.0)
	_no_drain_time = maxf(_no_drain_time - delta, 0.0)
	_kb_time = maxf(_kb_time - delta, 0.0)
	for i in range(_slows.size() - 1, -1, -1):
		_slows[i][1] -= delta
		if _slows[i][1] <= 0.0:
			_slows.remove_at(i)
	speed_mult = 1.0
	for s in _slows:
		speed_mult = minf(speed_mult, s[0])
	if serum_time > 0.0:
		serum_time = maxf(serum_time - delta, 0.0)
		var whole := ceili(serum_time)
		if whole != _serum_sent:
			_serum_sent = whole
			serum_changed.emit(serum_time)
	var cd := Vector2(snappedf(_shove_left, 0.05), snappedf(_roar_left, 0.05))
	if cd != _cd_sent:
		_cd_sent = cd
		cooldowns_changed.emit(_shove_left, _roar_left)


# --- Human actions -------------------------------------------------------------

func _human_actions(_direction: Vector2) -> void:
	if Input.is_action_just_pressed("Shove"):
		_space_action()
	if Input.is_action_just_pressed("Throw"):
		_throw()
	if Input.is_action_just_pressed("Charge"):
		_use_zmp()
	if Input.is_action_just_pressed("Interact"):
		_interact()
	if Input.is_action_just_pressed("Eat"):
		_eat_herb()
	if Input.is_action_just_pressed("Feed"):
		_feed_zombie()


func _update_sprint(delta: float, direction: Vector2) -> void:
	var want := Input.is_action_pressed("Sprint") and direction != Vector2.ZERO \
			and not _exhausted and not rooted and _kb_time <= 0.0
	_sprinting = want
	var before := stamina
	if _sprinting:
		if _no_drain_time <= 0.0:
			stamina = maxf(stamina - stamina_drain * delta, 0.0)
		_regen_wait = stamina_regen_delay
		_footstep_t -= delta
		if _footstep_t <= 0.0:
			_footstep_t = 0.3
			Game.emit_noise(global_position, 260.0, &"footsteps", true)
			Sfx.play(&"footstep", global_position)
		if stamina <= 0.0:
			_exhausted = true
			_sprinting = false
	else:
		_footstep_t = 0.0
		_regen_wait = maxf(_regen_wait - delta, 0.0)
		if _regen_wait <= 0.0:
			stamina = minf(stamina + stamina_regen * delta, max_stamina)
		if _exhausted and stamina >= max_stamina * sprint_resume_fraction:
			_exhausted = false
	if stamina != before:
		stamina_changed.emit(stamina, max_stamina)


func is_sprinting() -> bool:
	return _sprinting


func _nearest_zombie(range_px: float, require: StringName = &"") -> Node2D:
	var best: Node2D = null
	var best_d := range_px * range_px
	for z in get_tree().get_nodes_in_group("zombies"):
		if z == self or not z is Node2D:
			continue
		if require != &"" and not z.has_method(require):
			continue
		var d: float = global_position.distance_squared_to(z.global_position)
		if d <= best_d:
			best_d = d
			best = z
	return best


## Space bar, by preference: use a building door, else open a nearby crate,
## else shove.
func _space_action() -> void:
	if rooted:
		return
	var interiors = Game.main.get("interiors") if Game.main else null
	if interiors and interiors.try_use_door(self):
		return
	var crate: Node = null
	var best_d := interact_range * interact_range
	for c in get_tree().get_nodes_in_group("crates"):
		if not c is Node2D or not c.has_method("can_interact") or not c.can_interact(self):
			continue
		var d: float = global_position.distance_squared_to(c.global_position)
		if d <= best_d:
			best_d = d
			crate = c
	if crate:
		crate.interact(self)
		return
	_shove()


func _shove() -> void:
	if _shove_left > 0.0 or rooted:
		return
	_shove_left = shove_cooldown
	var target := _nearest_zombie(shove_range)
	var dir := Vector2.from_angle(stack.stack_rotation)
	if target:
		dir = (target.global_position - global_position).normalized()
	stack.stack_rotation = dir.angle()
	_shove_anim = 0.0
	stack.build(StackModels.get_frames(&"player_shove"))
	stack.set_frame(0)
	if target and target.has_method("knock_down"):
		var already: bool = target.has_method("is_down") and target.is_down()
		if not already:
			target.knock_down(dir)
			Game.stats.zombies_shoved += 1
	Game.emit_noise(global_position, 200.0, &"shove", true)
	Sfx.play(&"shove", global_position)


func _update_shove_anim(delta: float) -> void:
	_shove_anim += delta
	var total := 0.35
	if _shove_anim >= total:
		_shove_anim = -1.0
		stack.build(StackModels.get_frames(&"zombie" if is_zombie else &"player"))
		return
	stack.set_frame(mini(int(_shove_anim / total * 3.0), 2))


func _throw() -> void:
	if inventory.bottle <= 0 or rooted:
		return
	var main = Game.main
	if main == null:
		return
	# Throw the way we're facing, about half a screen-width far.
	var dir := Vector2.from_angle(stack.stack_rotation)
	var dist: float = get_viewport_rect().size.x / camera.zoom.x * 0.5
	var bottle: Node = load("res://thrown_bottle.gd").new()
	main.add_child(bottle)
	bottle.launch(global_position, global_position + dir * dist)
	inventory.bottle -= 1
	inventory_changed.emit(inventory)
	Sfx.play(&"throw", global_position)


func _use_zmp() -> void:
	if inventory.zmp <= 0 or Game.main == null:
		return
	var zmp = Game.main.get("zmp")
	if zmp:
		zmp.detonate(global_position)
		inventory.zmp -= 1
		inventory_changed.emit(inventory)


func _interact() -> void:
	var best: Node = null
	var best_d := interact_range * interact_range
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n is Node2D:
			continue
		var d: float = global_position.distance_squared_to(n.global_position)
		if d <= best_d and n.has_method("can_interact") and n.can_interact(self):
			best_d = d
			best = n
	if best:
		best.interact(self)


func _eat_herb() -> void:
	if herbs <= 0 or infection <= 0.0:
		return
	herbs -= 1
	Game.stats.herbs_used += 1
	herbs_changed.emit(herbs)
	add_infection(-herb_cure)


func _feed_zombie() -> void:
	if herbs <= 0:
		return
	var z := _nearest_zombie(feed_range, &"feed")
	if z == null:
		return
	z.feed(self)
	herbs -= 1
	Game.stats.herbs_used += 1
	herbs_changed.emit(herbs)


# --- Zombie-player actions -----------------------------------------------------

func _zombie_actions(_delta: float, direction: Vector2) -> void:
	if Input.is_action_just_pressed("Shove") and _roar_left <= 0.0:
		_roar()
	if Input.is_action_just_pressed("Sprint") and _lunge_left <= 0.0:
		_lunge_left = lunge_cooldown
		_lunge_t = lunge_time
		_lunge_dir = direction if direction != Vector2.ZERO else Vector2.from_angle(stack.stack_rotation)
		Sfx.play(&"lunge", global_position)
		_shake_strength = maxf(_shake_strength, 3.0)


func _roar() -> void:
	_roar_left = roar_cooldown
	var target: Node2D = null
	var best := INF
	for s in get_tree().get_nodes_in_group("survivor"):
		if s == self or not s is Node2D:
			continue
		var d: float = global_position.distance_squared_to(s.global_position)
		if d < best:
			best = d
			target = s
	if target:
		for z in get_tree().get_nodes_in_group("zombies"):
			if z == self or not z is Node2D or not z.has_method("rally_to"):
				continue
			if global_position.distance_to(z.global_position) <= roar_radius:
				z.rally_to(target, 6.0)
	Sfx.play(&"roar", global_position)
	shake(10.0)
	_roar_ring()


func _roar_ring() -> void:
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.from_angle(TAU * i / 32.0) * 100.0)
	ring.points = pts
	ring.width = 6.0
	ring.default_color = Color(1.0, 0.3, 0.25, 0.8)
	ring.z_index = 30
	ring.global_position = global_position
	ring.scale = Vector2(0.1, 0.1)
	var parent: Node = Game.main if Game.main else get_parent()
	parent.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * roar_radius / 100.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)


func _check_building_entry() -> void:
	if Game.main == null or not Game.main.has_method("point_in_building"):
		return
	var inside: bool = Game.main.point_in_building(global_position)
	if inside and not _was_in_building and interior_id == -1:
		Sfx.play(&"glass_break" if randf() < 0.5 else &"door_clatter", global_position)
		Game.emit_noise(global_position, 300.0, &"glass")
		_glass_burst()
	_was_in_building = inside


func _glass_burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.6
	p.spread = 180.0
	p.direction = Vector2(0, -1)
	p.gravity = Vector2(0, 220)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.75, 0.92, 1.0, 0.9)
	p.z_index = 25
	p.global_position = global_position + Vector2(0, -12)
	p.finished.connect(p.queue_free)
	get_parent().add_child(p)


func _attack_survivors(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("survivor"):
		if hitbox.overlaps_body(node):
			node.add_infection(attack_rate * delta)
			_shake_strength = maxf(_shake_strength, 4.0)


# --- State API -----------------------------------------------------------------

func _update_juice(delta: float) -> void:
	if _shake_strength > 0.05:
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, 30.0 * delta)
	else:
		camera.offset = Vector2.ZERO
	_infected_recently = maxf(_infected_recently - delta, 0.0)
	infect_particles.emitting = _infected_recently > 0.0 and not dead


func shake(amount: float) -> void:
	_shake_strength = maxf(_shake_strength, amount)


func set_rooted(on: bool) -> void:
	rooted = on


func knockback(impulse: Vector2) -> void:
	_kb_vel = impulse
	_kb_time = 0.25


func apply_slow(mult: float, duration: float) -> void:
	_slows.append([mult, duration])
	speed_mult = minf(speed_mult, mult)


func teleport(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_kb_time = 0.0
	if interior_id == -1:
		outside_position = pos
	_was_in_building = false
	if camera:
		camera.reset_smoothing()


func set_camera_limits(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
	camera.reset_smoothing()


func give_item(item: StringName, count: int = 1) -> void:
	if dead or is_zombie:
		return
	if item == &"tonic":
		stamina = max_stamina
		_exhausted = false
		_no_drain_time = tonic_free_time
		stamina_changed.emit(stamina, max_stamina)
		Sfx.play(&"drink_tonic", global_position)
		Game.say("Tonic! Unlimited sprint for %ds." % int(tonic_free_time), Color(0.5, 0.9, 1.0))
		return
	if not inventory.has(item):
		return
	inventory[item] += count
	inventory_changed.emit(inventory)


func add_infection(amount: float) -> void:
	if dead or is_zombie:
		return
	if amount > 0.0:
		if serum_time > 0.0:
			amount *= serum_factor
		_shake_strength = maxf(_shake_strength, 6.0)
		_infected_recently = 0.2
	infection = clampf(infection + amount, 0.0, 100.0)
	infection_changed.emit(infection)
	if infection >= 100.0:
		_turn_zombie()


## Healing herbs are stored; C eats one, R feeds a zombie.
func collect_herb() -> void:
	if dead or is_zombie:
		return
	herbs += 1
	_shake_strength = maxf(_shake_strength, 3.0)
	herbs_changed.emit(herbs)
	Sfx.play(&"pickup_herb", global_position)


func collect_cure(index: int) -> void:
	if dead or is_zombie or cures[index]:
		return
	cures[index] = true
	Game.stats.cures_found += 1
	_shake_strength = maxf(_shake_strength, 4.0)
	Sfx.play(&"pickup_cure", global_position)
	cure_collected.emit(index)
	if cures.all(func(c: bool) -> bool: return c):
		all_cures_collected.emit()
		Game.say("All 4 ingredients! Brew the cure at Mercy Hospital (red cross).", Color(1.0, 0.88, 0.45))
		if _theme_loop == null:
			_theme_loop = Sfx.attach_global_loop(&"main_theme", self)


## The hospital calls this when the brew completes.
func finish_cure() -> void:
	dead = true
	velocity = Vector2.ZERO
	won.emit()


func _turn_zombie() -> void:
	is_zombie = true
	_sprinting = false
	remove_from_group("survivor")
	add_to_group("zombies")
	collision_mask = 1  # zombie parkour: shamble through buildings
	Game.stats.time_as_human = Game.run_time
	_shove_anim = -1.0
	stack.build(StackModels.get_frames(&"zombie"))
	_shake_strength = 12.0
	_was_in_building = Game.main != null and Game.main.has_method("point_in_building") \
			and Game.main.point_in_building(global_position)
	turned_zombie.emit()
