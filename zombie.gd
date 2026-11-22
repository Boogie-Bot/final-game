extends CharacterBody2D
## Hostile zombie. Variants (walker / runner / brute / screamer) differ in speed,
## senses and quirks. Slow variants move in a "messed up" way (lurching surges,
## twitch pauses, head jerks, a limp, sway). They hear noises, follow the
## player's footprint trail, lunge when close, can be knocked down, fed (turning
## into a calm shield) or rallied by the player-zombie roar.

@export var variant: StringName = &"walker"
@export var wander_speed: float = 80.0
@export var chase_speed: float = 270.0
@export var sight_range: float = 280.0
@export var infection_rate: float = 35.0  # vs the human player
@export var survivor_infection_rate: float = 9.0  # vs the CPU survivor; set per difficulty by main.gd

## Only survivors with the same interior_id are targeted (-1 = outside).
var interior_id := -1

# --- Tunables ---
const RAIN_SIGHT_MULT := 0.65
const LUNGE_RANGE := 110.0
const LUNGE_SPEED_MULT := 2.2
const LUNGE_TIME := 0.3
const LUNGE_COOLDOWN := 2.5
const HORDE_SPEED := 240.0
const FED_FOLLOW_DIST := 50.0
const FED_SHIELD_RANGE := 220.0
const DOWN_TIME := 3.0
const TOPPLE_TIME := 0.25
const RISE_TIME := 0.8
const SCREAM_RADIUS := 1000.0
const STRONG_LURES: Array[StringName] = [&"car_alarm", &"bottle", &"scream", &"explosion"]
const FED_COLOR := Color(0.72, 0.76, 1.0)

@onready var stack: SpriteStack = $Stack
@onready var hitbox: Area2D = $Hitbox

# per-variant config (set in _configure)
var _forget_time := 0.0
var _lurch_depth := 0.0  # 0 = smooth mover
var _twitch_range := Vector2(0, 0)  # seconds between twitch pauses; zero = none
var _jerk_amount := 0.0
var _limp := 0.0
var _sway := 0.0

# state
var _wander_dir := Vector2.ZERO
var _wander_timer := 0.0
var _chase_target: Node2D = null
var _lost_t := 0.0
var _invest_pos := Vector2.ZERO
var _invest_t := 0.0
var _rally_target: Node2D = null
var _rally_t := 0.0
var _horde := false
var _was_horde := false  # spawned as part of a horde: rejoins it when idle
var _horde_path := PackedVector2Array()
var _horde_i := 0
var _horde_speed := HORDE_SPEED
var _lunge_t := 0.0
var _lunge_cd := 0.0
var _lunge_dir := Vector2.RIGHT
var _shove_cd := 0.0
var _scream_cd := 0.0
var _scream_t := 0.0
var _down := false
var _down_elapsed := 0.0
var _rising := false
var _fed := false
var _fed_by: Node2D = null
var _dead := false
var _frames_normal: Array = []
var _frames_scream: Array = []
var _shuffle: AudioStreamPlayer2D

# messed-up gait
var _lurch_phase := 0.0
var _lurch_rate := 3.0
var _gait_seed := 0.0
var _twitch_cd := 0.0
var _twitch_t := 0.0
var _jerk := 0.0
var _limp_phase := 0.0
var _sway_phase := 0.0
var _time := 0.0

# trail following
var _trail_query_t := 0.0
var _trail_pos := Vector2.ZERO
var _trail_t := 0.0
var _last_print_born := -INF

# dodge tracking
var _dodge_node: Node2D = null
var _dodge_close := false
var _dodge_touched := false

# unstick steering (detour along walls when wedged behind an obstacle)
var _stuck_t := 0.0
var _avoid_dir := Vector2.ZERO
var _avoid_t := 0.0
var _avoid_again_t := 0.0
var _avoid_side := 1.0


func _ready() -> void:
	_configure()
	_gait_seed = randf() * TAU
	_lurch_phase = randf() * TAU
	_limp_phase = randf() * TAU
	_sway_phase = randf() * TAU
	_lurch_rate = randf_range(2.6, 3.8)
	_twitch_cd = _next_twitch()
	_trail_query_t = randf() * 0.25
	_horde_speed = HORDE_SPEED * randf_range(0.93, 1.07)
	Game.noise_emitted.connect(hear)
	_shuffle = Sfx.attach_loop(StringName("zombie_shuffle_" + String(variant)), self, -8.0, not Game.raining)


func _configure() -> void:
	var model: StringName = &"zombie" if variant == &"walker" else variant
	match variant:
		&"runner":
			chase_speed = 330.0
			wander_speed = 110.0
			sight_range = 190.0
			_forget_time = 0.8
		&"brute":
			chase_speed = 170.0
			wander_speed = 60.0
			sight_range = 430.0
			_lurch_depth = 0.4
			_twitch_range = Vector2(3.0, 7.0)
			_jerk_amount = 0.3
			_limp = 1.0
			_sway = 25.0
			var shape := ($CollisionShape2D as CollisionShape2D)
			shape.shape = shape.shape.duplicate()
			(shape.shape as CircleShape2D).radius = 18.0
			var hshape := hitbox.get_node("CollisionShape2D") as CollisionShape2D
			hshape.shape = hshape.shape.duplicate()
			(hshape.shape as CircleShape2D).radius = 28.0
		&"screamer":
			chase_speed = 110.0
			wander_speed = 45.0
			sight_range = 320.0
			_lurch_depth = 0.65
			_twitch_range = Vector2(1.5, 4.0)
			_jerk_amount = 0.6
			_limp = 1.6
			_sway = 45.0
		_:
			_lurch_depth = 0.45
			_twitch_range = Vector2(2.5, 6.0)
			_jerk_amount = 0.35
			_limp = 1.0
			_sway = 25.0
	_frames_normal = StackModels.get_frames(model)
	if variant != &"walker":
		stack.build(_frames_normal)
	if variant == &"screamer":
		_frames_scream = StackModels.get_frames(&"screamer_scream")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	_lunge_cd = maxf(0.0, _lunge_cd - delta)
	_shove_cd = maxf(0.0, _shove_cd - delta)
	_scream_cd = maxf(0.0, _scream_cd - delta)

	if _down:
		_process_down(delta)
		return
	if _fed:
		_process_fed(delta)
		return

	if _rally_t > 0.0:
		_rally_t -= delta
		if _rally_t <= 0.0 or not _valid_target(_rally_target):
			_rally_t = 0.0
			_rally_target = null

	var sight := sight_range * (RAIN_SIGHT_MULT if Game.raining else 1.0)
	var near := _nearest_survivor()
	var seen: Node2D = null
	if near and global_position.distance_to(near.global_position) < sight:
		seen = near

	# --- target acquisition ---
	var chase: Node2D = null
	if _rally_target:
		chase = _rally_target
		_chase_target = _rally_target
		_lost_t = 0.0
	elif seen:
		if _chase_target == null:
			_on_spotted(seen)
		_chase_target = seen
		_lost_t = 0.0
		chase = seen
		_horde = false
	elif _chase_target:
		_lost_t += delta
		if _lost_t >= _forget_time or not _valid_target(_chase_target):
			_chase_target = null
		else:
			chase = _chase_target

	# A horde member that lost its quarry (and has nothing else to do)
	# rejoins the march and leaves with the horde.
	if _was_horde and not _horde and chase == null and _invest_t <= 0.0 \
			and not _horde_path.is_empty():
		_horde = true
		# Resume at the closest remaining waypoint rather than backtracking.
		var best := _horde_i
		var best_d := INF
		for i in range(_horde_i, _horde_path.size()):
			var d := global_position.distance_squared_to(_horde_path[i])
			if d < best_d:
				best_d = d
				best = i
		_horde_i = best

	var moving_speed := 0.0
	var dir := Vector2.ZERO
	var accel := 900.0 if _lurch_depth > 0.0 else 600.0
	var gait := 1.0

	if _scream_t > 0.0:
		_scream_t -= delta
		if _scream_t <= 0.0:
			_end_scream()
	elif _lunge_t > 0.0:
		_lunge_t -= delta
		dir = _lunge_dir
		moving_speed = chase_speed * LUNGE_SPEED_MULT
		accel = 4000.0
	elif _horde:
		dir = _horde_dir()
		moving_speed = _horde_speed
	elif chase:
		_invest_t = 0.0
		var to: Vector2 = chase.global_position - global_position
		dir = to.normalized()
		moving_speed = chase_speed
		if to.length() < LUNGE_RANGE and _lunge_cd <= 0.0:
			_start_lunge(dir)
		gait = _gait(delta)
	elif _invest_t > 0.0:
		_invest_t -= delta
		var to_spot := _invest_pos - global_position
		if to_spot.length() > 28.0:
			dir = to_spot.normalized()
			moving_speed = chase_speed * 0.85
			gait = _gait(delta)
	else:
		gait = _gait(delta)
		var trail := _trail_step(delta)
		if trail != Vector2.ZERO:
			dir = trail
			moving_speed = wander_speed * 1.8
		else:
			_wander_timer -= delta
			if _wander_timer <= 0.0:
				_wander_timer = randf_range(1.0, 3.0)
				_wander_dir = Vector2.ZERO if randf() < 0.3 else Vector2.from_angle(randf() * TAU)
			dir = _wander_dir
			moving_speed = wander_speed

	if _lunge_t <= 0.0:
		dir = _steer(delta, dir, moving_speed)

	var target_velocity := dir * moving_speed * gait
	if _sway > 0.0 and dir != Vector2.ZERO and _lunge_t <= 0.0:
		_sway_phase += delta * 2.3
		target_velocity += dir.orthogonal() * sin(_sway_phase) * _sway * gait

	velocity = velocity.move_toward(target_velocity, accel * delta)
	move_and_slide()
	_animate(delta)
	_contact(delta, near, chase)
	_track_dodge(delta, chase)


## Unstick steering. When the zombie wants to move but last frame's
## move_and_slide left it pinned against something, detour along the wall
## (the side closer to the desired direction) for a short burst. If it jams
## again right away — a concave pocket — try the other side.
func _steer(delta: float, dir: Vector2, speed: float) -> Vector2:
	_avoid_again_t = maxf(_avoid_again_t - delta, 0.0)
	if dir == Vector2.ZERO or speed <= 0.0:
		_stuck_t = 0.0
		_avoid_t = 0.0
		return dir
	if _avoid_t > 0.0:
		_avoid_t -= delta
		return _avoid_dir
	var blocked := get_slide_collision_count() > 0 \
			and get_real_velocity().length() < speed * 0.35
	if blocked:
		_stuck_t += delta
	else:
		_stuck_t = maxf(_stuck_t - delta * 2.0, 0.0)
	if _stuck_t < 0.3 or get_slide_collision_count() == 0:
		return dir
	_stuck_t = 0.0
	var normal := get_slide_collision(0).get_normal()
	var tangent := normal.orthogonal()
	if tangent.dot(dir) < 0.0:
		tangent = -tangent
	if _avoid_again_t > 0.0:  # just tried this: take the other side of the wall
		_avoid_side = -_avoid_side
	else:
		_avoid_side = 1.0
	_avoid_dir = (tangent * _avoid_side + normal * 0.5).normalized()
	_avoid_t = randf_range(0.45, 0.8)
	_avoid_again_t = _avoid_t + 1.2
	return _avoid_dir


## Lurching speed multiplier (|sin| surges with an irregular phase) plus twitch pauses.
func _gait(delta: float) -> float:
	if _lurch_depth <= 0.0:
		return 1.0
	if _twitch_t > 0.0:
		_twitch_t -= delta
		return 0.0
	_twitch_cd -= delta
	if _twitch_cd <= 0.0:
		_twitch_cd = _next_twitch()
		_twitch_t = randf_range(0.15, 0.4)
		_jerk = randf_range(-1.0, 1.0) * _jerk_amount * 2.0
	_lurch_phase += delta * _lurch_rate * (1.0 + 0.45 * sin(_time * 1.7 + _gait_seed))
	return (1.0 - _lurch_depth) + _lurch_depth * 1.57 * absf(sin(_lurch_phase))


func _next_twitch() -> float:
	if _twitch_range.y <= 0.0:
		return INF
	return randf_range(_twitch_range.x, _twitch_range.y)


func _animate(delta: float) -> void:
	var speed := velocity.length()
	_jerk = move_toward(_jerk, 0.0, 3.0 * delta)
	if speed > 5.0:
		if _jerk_amount > 0.0 and randf() < delta * 0.5:
			_jerk = randf_range(-1.0, 1.0) * _jerk_amount
		var ang := velocity.angle() + _jerk
		stack.stack_rotation = lerp_angle(stack.stack_rotation, ang, 8.0 * delta)
		stack.play_walk(delta, clampf(speed / 16.0, 4.0, 10.0))
		if _limp > 0.0:
			_limp_phase += delta * clampf(speed / 14.0, 2.0, 9.0)
			var s := sin(_limp_phase)
			stack.bob_offset = -(s * 3.0 if s > 0.0 else -s * 0.8) * _limp
	else:
		stack.stand()
		if _jerk != 0.0:
			stack.stack_rotation += _jerk * delta * 4.0
		if _limp > 0.0 and stack.bob_offset != 0.0:
			stack.bob_offset = move_toward(stack.bob_offset, 0.0, 12.0 * delta)


func _contact(delta: float, near: Node2D, chase: Node2D) -> void:
	for t in [near, chase]:
		if t == null or not is_instance_valid(t) or not hitbox.overlaps_body(t):
			continue
		var rate := infection_rate if t.is_in_group("player") else survivor_infection_rate
		t.add_infection(rate * delta)
		if variant == &"brute" and _shove_cd <= 0.0 and t.has_method("knockback"):
			_shove_cd = 1.5
			t.knockback((t.global_position - global_position).normalized() * 700.0)
			t.add_infection(rate * 0.15)
			Sfx.play(&"brute_shove", global_position)
		if t == chase and t == near:
			break


func _track_dodge(_delta: float, chase: Node2D) -> void:
	if chase and chase.is_in_group("player") and chase != _dodge_node:
		_dodge_node = chase
		_dodge_close = false
		_dodge_touched = false
	if _dodge_node == null:
		return
	if not is_instance_valid(_dodge_node):
		_dodge_node = null
		return
	var d := global_position.distance_to(_dodge_node.global_position)
	if chase == _dodge_node and d < 55.0:
		_dodge_close = true
	if hitbox.overlaps_body(_dodge_node):
		_dodge_touched = true
	if d > 180.0:
		if _dodge_close and not _dodge_touched:
			Game.stats["zombies_dodged"] = int(Game.stats.get("zombies_dodged", 0)) + 1
		_dodge_close = false
		_dodge_touched = false
		if chase != _dodge_node:
			_dodge_node = null


func _start_lunge(dir: Vector2) -> void:
	_lunge_t = LUNGE_TIME
	_lunge_cd = LUNGE_COOLDOWN
	_lunge_dir = dir
	Sfx.play(&"zombie_lunge", global_position)


func _on_spotted(seen: Node2D) -> void:
	if variant != &"screamer" or _scream_cd > 0.0 or _scream_t > 0.0:
		return
	_scream_cd = 8.0
	_scream_t = 1.0
	if not _frames_scream.is_empty():
		stack.build(_frames_scream)
	_chase_target = seen  # set first so our own hear() ignores the scream
	Sfx.play(&"scream", global_position)
	Game.emit_noise(global_position, SCREAM_RADIUS, &"scream")


func _end_scream() -> void:
	_scream_t = 0.0
	if not _frames_scream.is_empty():
		stack.build(_frames_normal)


# --- Hearing / lures ---

func hear(pos: Vector2, radius: float, source: StringName) -> void:
	if _dead or _down or _fed or _horde or _rally_target or _chase_target:
		return
	if global_position.distance_to(pos) > radius:
		return
	if source in STRONG_LURES:
		lure(pos, randf_range(9.0, 13.0))
	else:
		_invest_pos = pos
		_invest_t = randf_range(4.0, 6.0)
		_trail_t = 0.0


## Walk to `pos` and linger for `duration` seconds (strong lure).
func lure(pos: Vector2, duration: float) -> void:
	if _fed or _dead:
		return
	_invest_pos = pos
	_invest_t = duration
	_trail_t = 0.0
	_horde = false


## Chase `target` regardless of sight for `duration` (player-zombie roar).
func rally_to(target: Node2D, duration: float) -> void:
	if _fed or _dead or target == null:
		return
	_rally_target = target
	_rally_t = duration
	_invest_t = 0.0
	_horde = false


# --- Trail following ---

## Direction toward the freshest nearby footprint, or ZERO when none to follow.
func _trail_step(delta: float) -> Vector2:
	_trail_query_t -= delta
	if _trail_query_t <= 0.0:
		_trail_query_t = 0.25
		if Game.main != null:
			var fp = Game.main.get("footprints")
			if fp != null and fp.has_method("freshest_near"):
				var hit: Dictionary = fp.freshest_near(global_position, 140.0)
				if not hit.is_empty() and float(hit.born) > _last_print_born:
					_last_print_born = float(hit.born)
					_trail_pos = hit.pos
					_trail_t = 2.0
	if _trail_t > 0.0:
		_trail_t -= delta
		var to := _trail_pos - global_position
		if to.length() > 12.0:
			return to.normalized()
		_trail_t = 0.0
		_trail_query_t = 0.0
	return Vector2.ZERO


# --- Horde ---

## Run along `points` and despawn at the end (drops out if a survivor is spotted).
func set_horde_path(points: PackedVector2Array) -> void:
	_horde_path = points
	_horde_i = 0
	_horde = points.size() > 0
	_was_horde = _horde
	_invest_t = 0.0


func _horde_dir() -> Vector2:
	while _horde_i < _horde_path.size():
		var to := _horde_path[_horde_i] - global_position
		if to.length() < 28.0:
			_horde_i += 1
			continue
		return to.normalized()
	queue_free()
	_dead = true
	return Vector2.ZERO


# --- Knockdown / feed / crush ---

## Topples away from `from_dir`, lies still, gets up; 3 s total. Harmless while down.
func knock_down(from_dir: Vector2) -> void:
	if _down or _dead:
		return
	var d := from_dir.normalized() if from_dir.length_squared() > 0.0001 else Vector2.RIGHT
	_down = true
	_down_elapsed = 0.0
	_rising = false
	_lunge_t = 0.0
	if _scream_t > 0.0:
		_end_scream()
	velocity = d * 140.0
	stack.stand()
	stack.topple(d, TOPPLE_TIME)
	Sfx.play(&"zombie_knockdown", global_position)


func is_down() -> bool:
	return _down


func _process_down(delta: float) -> void:
	_down_elapsed += delta
	velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	if not _rising and _down_elapsed >= DOWN_TIME - RISE_TIME:
		_rising = true
		stack.rise(RISE_TIME)
		Sfx.play(&"zombie_getup", global_position)
	if _down_elapsed >= DOWN_TIME:
		_down = false
		_rising = false
		velocity = Vector2.ZERO


## Zombie empathy: becomes a calm, permanent follower that shields `by`.
func feed(by: Node2D) -> void:
	if _fed or _dead:
		return
	_fed = true
	_fed_by = by
	_chase_target = null
	_rally_target = null
	_horde = false
	_was_horde = false
	_invest_t = 0.0
	remove_from_group("zombies")
	add_to_group("fed_zombie")
	if Game.noise_emitted.is_connected(hear):
		Game.noise_emitted.disconnect(hear)
	var tw := create_tween()
	tw.tween_property(stack, "modulate", FED_COLOR, 0.6)
	Sfx.play(&"zombie_fed", global_position)


func _process_fed(delta: float) -> void:
	var goal := global_position
	var go := false
	if _fed_by and is_instance_valid(_fed_by):
		var by_pos := _fed_by.global_position
		var threat := _nearest_hostile(by_pos)
		if threat:
			goal = by_pos + (threat.global_position - by_pos).normalized() * FED_FOLLOW_DIST
			go = global_position.distance_to(goal) > 10.0
		elif global_position.distance_to(by_pos) > FED_FOLLOW_DIST + 12.0:
			goal = by_pos
			go = true
	var tv := Vector2.ZERO
	if go:
		var to := goal - global_position
		var sp := minf(chase_speed * 0.8, to.length() * 6.0 + 40.0)
		tv = _steer(delta, to.normalized(), sp) * sp
	velocity = velocity.move_toward(tv, 800.0 * delta)
	move_and_slide()
	if velocity.length() > 5.0:
		stack.stack_rotation = lerp_angle(stack.stack_rotation, velocity.angle(), 8.0 * delta)
		stack.play_walk(delta, clampf(velocity.length() / 16.0, 4.0, 10.0))
	else:
		stack.stand()


func _nearest_hostile(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := FED_SHIELD_RANGE * FED_SHIELD_RANGE
	for node in get_tree().get_nodes_in_group("zombies"):
		if node == self or node.is_in_group("player") or not (node is Node2D):
			continue
		var d: float = from.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


## Die instantly (falling building) with a small splat.
func crush() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("zombies")
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 150.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 5.0
	p.color = Color(0.42, 0.55, 0.25)
	p.position = global_position + Vector2(0, -8)
	p.z_index = 20
	p.finished.connect(p.queue_free)
	get_parent().add_child(p)
	queue_free()


# --- Targeting ---

func _valid_target(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return false
	var iid = node.get("interior_id")
	if (iid if iid != null else -1) != interior_id:
		return false
	if node.get("in_safe_house") == true:
		return false
	return true


## Nearest eligible member of the "survivor" group: the human player while alive,
## the CPU survivor after the player has turned.
func _nearest_survivor() -> Node2D:
	var best: Node2D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("survivor"):
		if not _valid_target(node):
			continue
		var d: float = global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best
