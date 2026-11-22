extends StaticBody2D
## A payphone. Rings now and then; answer it (E) for one true tip, but you are
## rooted for the whole call and hanging up early garbles the message.

const RING_TIME := 6.0
const CALL_TIME := 4.0
const GRACE := 0.3
const CURE_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.88), Color(0.68, 0.52, 0.88), Color(0.85, 0.45, 0.62), Color(0.92, 0.9, 0.8),
]
const GLYPHS := "#%&?@$*!"

var ringing := false
var in_call := false

var _stack: SpriteStack
var _label: Label
var _ring_loop: AudioStreamPlayer2D
var _ring_left := 0.0
var _call_time := 0.0
var _caller: Node2D
var _tip_text := ""
var _tip_pos := Vector2.ZERO
var _tip_color := Color.WHITE
var _tip_has_pos := false
var _tip_is_herb := false
var _t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"payphones")
	add_to_group(&"interactable")
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10.0
	cs.shape = shape
	add_child(cs)
	_stack = SpriteStack.new()
	add_child(_stack)
	_stack.build(StackModels.get_frames(&"payphone"))
	_stack.set_frame(0)
	_label = Label.new()
	_label.position = Vector2(-90, -90)
	_label.custom_minimum_size = Vector2(180, 0)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override(&"font_size", 14)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.z_index = 30
	_label.visible = false
	add_child(_label)
	_ring_loop = Sfx.attach_loop(&"phone_ring", self, 0.0, false)


func is_human(body: Node) -> bool:
	return body != null and body.is_in_group(&"player") and body.get("is_zombie") != true


func can_interact(body: Node) -> bool:
	return (ringing or in_call) and is_human(body)


func ring() -> void:
	if ringing or in_call:
		return
	ringing = true
	_ring_left = RING_TIME
	_stack.set_frame(1)
	if _ring_loop.stream:
		_ring_loop.play()
	Game.emit_noise(global_position, 350.0, &"phone")


func _stop_ring() -> void:
	ringing = false
	_ring_loop.stop()
	_stack.stack_rotation = 0.0
	_stack.set_frame(0)


func interact(body: Node) -> void:
	if in_call:
		_end_call(true)
		return
	if not can_interact(body):
		return
	_stop_ring()
	in_call = true
	_caller = body
	_call_time = 0.0
	_roll_tip()
	if body.has_method("set_rooted"):
		body.set_rooted(true)
	Sfx.play(&"phone_voice", global_position)
	_label.visible = true


func _roll_tip() -> void:
	_tip_has_pos = true
	_tip_is_herb = false
	var cures := get_tree().get_nodes_in_group(&"cure_herb")
	var main = Game.main
	if not cures.is_empty() and randf() < 0.5:
		# Clues point at the herb in the quadrant diagonally opposite the
		# phone; fall back to the farthest herb when that quadrant is empty.
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
		var idx: int = int(best.get("cure_index"))
		_tip_is_herb = true
		var names: Array = _caller.get("CURE_NAMES") if _caller.get("CURE_NAMES") != null else ["herb"]
		_tip_pos = best.global_position
		_tip_color = CURE_COLORS[clampi(idx, 0, 3)]
		_tip_text = "Voice: \"The %s grows in %s...\"" % [names[clampi(idx, 0, names.size() - 1)], Game.district_name(_tip_pos)]
		return
	if not cures.is_empty() and main.get("horde") != null:
		_tip_pos = main.horde.next_road_start()
		_tip_color = Color(1.0, 0.3, 0.25)
		_tip_text = "Voice: \"A horde comes down %s. Stay off it!\"" % main.horde.next_road_name()
		return
	if main.get("hospital") != null and main.hospital.has_method("lab_position"):
		_tip_pos = main.hospital.lab_position()
		_tip_color = Color(0.4, 1.0, 0.6)
		_tip_text = "Voice: \"Take the herbs to the hospital lab. Hurry.\""
		return
	_tip_has_pos = false
	_tip_text = "Voice: \"...stay alive out there.\""


func _scramble(text: String) -> String:
	var out := ""
	for ch in text:
		if ch != " " and ch != "\"" and randf() < 0.55:
			out += GLYPHS[randi() % GLYPHS.length()]
		else:
			out += ch
	return out


func _end_call(early: bool) -> void:
	in_call = false
	_label.visible = false
	if is_instance_valid(_caller) and _caller.has_method("set_rooted"):
		_caller.set_rooted(false)
	_caller = null
	if early:
		Sfx.play(&"phone_garble", global_position)
		Game.say(_scramble(_tip_text), Color(0.75, 0.75, 0.75))
		return
	Game.say(_tip_text, _tip_color)
	if _tip_has_pos:
		Game.ping(_tip_pos, _tip_color, 4.0)
		if _tip_is_herb:
			Game.herb_hint.emit(_tip_pos)
		var fog = Game.main.get("fog")
		if fog != null and fog.has_method("reveal"):
			fog.reveal(_tip_pos, 140.0)


func _process(delta: float) -> void:
	_t += delta
	if ringing:
		_ring_left -= delta
		_stack.stack_rotation = sin(_t * 40.0) * 0.12
		if _ring_left <= 0.0:
			_stop_ring()
	if in_call:
		_call_time += delta
		if not is_instance_valid(_caller):
			in_call = false
			_label.visible = false
			return
		var moved := Input.get_vector(&"Left", &"Right", &"Up", &"Down").length() > 0.1
		if _call_time > GRACE and moved:
			_end_call(true)
			return
		var k := clampf(_call_time / CALL_TIME, 0.0, 1.0)
		var shown := int(k * _tip_text.length())
		_label.text = _tip_text.substr(0, shown) if shown > 0 else "..."
		if _call_time >= CALL_TIME:
			_end_call(false)
