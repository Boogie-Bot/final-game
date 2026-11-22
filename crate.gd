extends StaticBody2D
## A lootable crate. Press E to break it open; contents are a weighted roll.

@export var guaranteed_loot := false
## Interior crates never contain clue notes.
@export var no_clues := false
## This crate always holds a ZMP (one per run is guaranteed).
@export var guaranteed_zmp := false

const CURE_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.88), Color(0.68, 0.52, 0.88), Color(0.85, 0.45, 0.62), Color(0.92, 0.9, 0.8),
]
## Weighted loot table (weights from the design).
const LOOT := [
	[&"herb", 25], [&"tonic", 15], [&"bottle", 20], [&"note", 12], [&"zmp", 8], [&"nothing", 20],
]

const FLOAT_HEIGHT := 10.0

var opened := false
var _float_t := randf() * TAU

@onready var _stack: SpriteStack = $Stack


func _ready() -> void:
	add_to_group(&"crates")
	add_to_group(&"interactable")
	# Chests hover: purely decorative, never block anyone's movement.
	collision_layer = 0
	collision_mask = 0


## Unopened chests float, bob and slowly spin; an opened one settles down.
func _process(delta: float) -> void:
	if opened:
		_stack.bob_offset = move_toward(_stack.bob_offset, 0.0, 30.0 * delta)
		return
	_float_t += delta
	_stack.bob_offset = -FLOAT_HEIGHT + sin(_float_t * 2.2) * 2.5
	_stack.stack_rotation += delta * 1.1


func can_interact(body: Node) -> bool:
	return not opened and body != null and body.is_in_group(&"player") and body.get("is_zombie") != true


func interact(body: Node) -> void:
	if not can_interact(body):
		return
	opened = true
	var stack := get_node_or_null("Stack") as SpriteStack
	if stack:
		stack.build(StackModels.get_frames(&"crate_open"))
	Sfx.play(&"crate_break", global_position)
	_splinters()
	Game.emit_noise(global_position, 380.0, &"crate")
	var text := _roll(body)
	_float_text(text)


func _roll(body: Node) -> String:
	# Reroll notes when clues are impossible (interior crate) or pointless
	# (every cure herb already collected) — never "nothing useful".
	var kind := &"zmp" if guaranteed_zmp else _pick()
	while (guaranteed_loot and kind == &"nothing") or (kind == &"note" and not _clue_available()):
		kind = _pick()
	match kind:
		&"herb":
			if Game.main != null and Game.main.has_method("spawn_herb"):
				Game.main.spawn_herb(global_position + Vector2(randf_range(-26, 26), 34.0))
			return "Healing herb!"
		&"tonic":
			body.give_item(&"tonic")
			return "Stamina tonic!"
		&"bottle":
			body.give_item(&"bottle")
			return "Bottle!"
		&"zmp":
			body.give_item(&"zmp")
			return "ZMP device!"
		&"note":
			return _clue()
	return "Empty..."


func _clue_available() -> bool:
	return not no_clues and not get_tree().get_nodes_in_group(&"cure_herb").is_empty()


func _pick() -> StringName:
	var total := 0
	for l in LOOT:
		total += l[1]
	var r := randi() % total
	for l in LOOT:
		r -= l[1]
		if r < 0:
			return l[0]
	return &"nothing"


## Clues always point at the herb in the quadrant diagonally opposite the
## crate (a note found bottom-left leads top-right), falling back to the
## farthest herb when that quadrant is empty.
func _clue() -> String:
	var cures := get_tree().get_nodes_in_group(&"cure_herb")
	if cures.is_empty():
		return "A note: nothing useful."
	var opposite := 3 - Game.district_index(global_position)
	var best: Node2D = null
	for c in cures:
		if c is Node2D and Game.district_index(c.global_position) == opposite:
			best = c
			break
	if best == null:
		best = cures[0]
		for c in cures:
			if c.global_position.distance_to(global_position) > best.global_position.distance_to(global_position):
				best = c
	var idx: int = clampi(int(best.get("cure_index")), 0, 3)
	var player := get_tree().get_first_node_in_group(&"player")
	var names: Array = player.get("CURE_NAMES") if player and player.get("CURE_NAMES") != null else ["Chamomile", "Lavender", "Echinacea", "Garlic"]
	var msg := "A note: \"%s grows near %s\"" % [names[clampi(idx, 0, names.size() - 1)], Game.district_name(best.global_position)]
	Game.ping(best.global_position, CURE_COLORS[idx], 1.2)
	Game.herb_hint.emit(best.global_position)
	Game.say(msg, CURE_COLORS[idx])
	return "Clue note!"


func _float_text(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.add_theme_constant_override(&"outline_size", 5)
	l.z_index = 40
	l.position = Vector2(-60, -50)
	l.custom_minimum_size = Vector2(120, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", -110.0, 1.4)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.9)
	t.chain().tween_callback(l.queue_free)


func _splinters() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = 18
	p.lifetime = 0.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 300)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(0.6, 0.4, 0.2)
	p.position = Vector2(0, -10)
	p.z_index = 20
	p.finished.connect(p.queue_free)
	add_child(p)
