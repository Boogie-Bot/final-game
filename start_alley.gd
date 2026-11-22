extends Node
## The starting alley (replaces the difficulty menu): three doors on the north
## wall pick the difficulty; signs explain the controls and unlockable perks.

const ALLEY_RECT := Rect2(3200, -1600, 1000, 800)
## Walkable floor (12 x 12 wall tiles); walls surround it.
const FLOOR := Rect2(3412, -1440, 576, 576)
const TILE := 48.0
const DOORS := [
	{x = 3508.0, model = &"door_clean", diff = 0, title = "EASY - The Clean Door",
		flavor = "Fresh paint. Four herbs, few zombies."},
	{x = 3700.0, model = &"door_dirty", diff = 1, title = "MEDIUM - The Dirty Door",
		flavor = "Scuffed and stained. Two herbs, more of them."},
	{x = 3892.0, model = &"door_ruin", diff = 2, title = "HARD - The Ruined Door",
		flavor = "Splintered. One herb. Triple the dead."},
]

var main = null
var _root: Node2D
var _fade: ColorRect
var _used: bool = false


func setup(m) -> void:
	main = m
	_root = Node2D.new()
	_root.name = "StartAlley"
	main.add_child(_root)
	_make_ground()
	_make_walls()
	_make_props()
	_make_doors()
	_make_signs()
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)
	if main.player and main.player.has_method("set_camera_limits"):
		main.player.set_camera_limits(ALLEY_RECT)


## South end of the alley, where the player starts.
func spawn_point() -> Vector2:
	return Vector2(FLOOR.get_center().x, FLOOR.end.y - 50.0)


func alley_rect() -> Rect2:
	return ALLEY_RECT


# --- Build --------------------------------------------------------------------


func _make_ground() -> void:
	_tile(StackModels.concrete_texture(), FLOOR, -5)
	var strip := Rect2(FLOOR.get_center().x - 72.0, FLOOR.position.y, 144.0, FLOOR.size.y)
	_tile(StackModels.road_texture(true), strip, -4)


func _tile(tex: ImageTexture, rect: Rect2, z: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, rect.size / 4.0)
	sprite.scale = Vector2(4, 4)
	sprite.position = rect.position
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z
	_root.add_child(sprite)


func _make_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	_root.add_child(body)
	var bounds: Array[Rect2] = [
		Rect2(FLOOR.position.x - TILE, FLOOR.position.y - TILE, FLOOR.size.x + 2.0 * TILE, TILE),
		Rect2(FLOOR.position.x - TILE, FLOOR.end.y, FLOOR.size.x + 2.0 * TILE, TILE),
		Rect2(FLOOR.position.x - TILE, FLOOR.position.y, TILE, FLOOR.size.y),
		Rect2(FLOOR.end.x, FLOOR.position.y, TILE, FLOOR.size.y),
	]
	for r in bounds:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		collider.shape = shape
		collider.position = r.get_center()
		body.add_child(collider)
	var n := int(FLOOR.size.x / TILE)
	for i in range(-1, n + 1):
		_wall_stack(Vector2(FLOOR.position.x + (i + 0.5) * TILE, FLOOR.position.y - 0.5 * TILE))
		_wall_stack(Vector2(FLOOR.position.x + (i + 0.5) * TILE, FLOOR.end.y + 0.5 * TILE))
	for j in n:
		var y := FLOOR.position.y + (j + 0.5) * TILE
		_wall_stack(Vector2(FLOOR.position.x - 0.5 * TILE, y))
		_wall_stack(Vector2(FLOOR.end.x + 0.5 * TILE, y))


func _wall_stack(pos: Vector2) -> void:
	var stack := SpriteStack.new()
	stack.model = &"wall"
	stack.cast_shadow = false
	stack.position = pos
	_root.add_child(stack)


func _make_props() -> void:
	var props := [
		[&"dumpster", Vector2(3470, -1010), Vector2(52, 36)],
		[&"dumpster", Vector2(3935, -1130), Vector2(52, 36)],
		[&"trash_can", Vector2(3450, -920), Vector2(22, 22)],
		[&"trash_can", Vector2(3955, -930), Vector2(22, 22)],
		[&"trash_can", Vector2(3440, -1080), Vector2(22, 22)],
		[&"trash_can", Vector2(3960, -1040), Vector2(22, 22)],
	]
	for p in props:
		var body := StaticBody2D.new()
		body.position = p[1]
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = p[2]
		collider.shape = shape
		body.add_child(collider)
		var stack := SpriteStack.new()
		stack.model = p[0]
		body.add_child(stack)
		_root.add_child(body)


func _make_doors() -> void:
	for d in DOORS:
		var x: float = d.x
		var door := SpriteStack.new()
		door.model = d.model
		door.cast_shadow = false
		door.position = Vector2(x, FLOOR.position.y + 6.0)  # unrotated: face on the south side
		_root.add_child(door)

		var label := _label("%s\n%s" % [d.title, d.flavor], Vector2(x - 95.0, FLOOR.position.y - 126.0),
			Vector2(190, 50), 11, Color(1.0, 0.95, 0.8), false)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.z_index = 50

		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 4
		area.position = Vector2(x, FLOOR.position.y + 22.0)
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(64, 44)
		collider.shape = shape
		area.add_child(collider)
		area.body_entered.connect(_on_door_entered.bind(d.diff))
		_root.add_child(area)


func _make_signs() -> void:
	var perks: Dictionary = Game.perks
	var lines: Array[String] = ["UNLOCKED PERKS"]
	lines.append("%s Faster walk  (win Easy)" % ("[x]" if perks.get("fast_walk", false) else "[ ]"))
	lines.append("%s Bonus chest  (win Medium)" % ("[x]" if perks.get("bonus_chest", false) else "[ ]"))
	lines.append("%s Longer vision circle  (win Hard)" % ("[x]" if perks.get("long_vision", false) else "[ ]"))
	_label("\n".join(lines), Vector2(FLOOR.position.x + 300.0, FLOOR.position.y + 56.0),
		Vector2(268, 0), 13, Color(1.0, 0.95, 0.7), true)

	var hard := "HARD: you only see your vision circle. The fog never clears."
	_label(hard, Vector2(FLOOR.position.x + 300.0, FLOOR.position.y + 170.0),
		Vector2(268, 0), 13, Color(1.0, 0.5, 0.45), true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var controls: Array[String] = [
		"CONTROLS",
		"WASD  move      Shift  sprint",
		"Space  enter door / open crate / shove",
		"E  interact",
		"Q  throw bottle at cursor",
		"R  feed herb to zombie",
		"C  eat herb     F  plant charge",
		"F1  80's mode",
		"",
		"AS A ZOMBIE",
		"Space  roar     Shift  lunge",
		"",
		"Pick a door to begin.",
	]
	_label("\n".join(controls), Vector2(FLOOR.position.x + 12.0, FLOOR.position.y + 56.0),
		Vector2(280, 0), 13, Color(0.85, 0.95, 1.0), true)


func _label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color,
		boxed: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = -3
	if boxed:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.08, 0.6)
		sb.set_content_margin_all(8)
		sb.set_corner_radius_all(4)
		label.add_theme_stylebox_override("normal", sb)
	_root.add_child(label)
	return label


# --- Doors ----------------------------------------------------------------------


func _on_door_entered(body: Node, difficulty: int) -> void:
	if _used or body != main.player:
		return
	var z = body.get("is_zombie")
	if z != null and z:
		return
	_used = true
	_enter_door.call_deferred(difficulty)


func _enter_door(difficulty: int) -> void:
	Sfx.play(&"door_open", main.player.global_position)
	var tween: Tween = main.create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.9)
	tween.tween_callback(func() -> void:
		Sfx.play(&"door_lock")
		Game.say("The door locks behind you.", Color(1.0, 0.8, 0.6)))
	tween.tween_interval(0.5)
	tween.tween_callback(func() -> void:
		main.start_game(difficulty))
	tween.tween_property(_fade, "color:a", 0.0, 0.8)
