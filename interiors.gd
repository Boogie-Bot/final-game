extends Node
## Enterable buildings: 4 interiors (zombies, crates) and 2 safe houses. Every
## building's room is built off-map and is much bigger on the inside. Inside,
## the only light is the player's vision circle.

const INTERIOR_COUNT := 4
const SAFE_COUNT := 2
const ROOM_ORIGIN := Vector2(3200.0, 200.0)
const ROOM_STRIDE := 1400.0
const TILE := 48.0
const MAP_LIMITS := Rect2(-48, -48, 2496, 1536)
const VISION_RADIUS := 200.0
const SAFE_HEAL := 1.5
const NAMES: Array[String] = [
	"Abandoned Apartment", "Looted Pharmacy", "Dusty Office", "Boarded-up Arcade"]
const ZOMBIE_VARIANTS: Array[StringName] = [&"walker", &"walker", &"runner", &"brute"]

var main = null
var _root: Node2D
var _rooms: Array[Dictionary] = []
var _current: int = -1
var _cooldown: float = 0.0
var _door_areas: Array = []  # [area, room index, is_exit]
var _prompt: Label
var _dark: Node2D
var _dark_sprite: Sprite2D
var _dark_extent: float = 0.0


func setup(m) -> void:
	main = m
	_root = Node2D.new()
	_root.name = "Interiors"
	main.add_child(_root)
	_choose_buildings()
	_make_darkness()


func is_inside() -> bool:
	return _current >= 0


# --- Setup --------------------------------------------------------------------


func _choose_buildings() -> void:
	var pool: Array[Dictionary] = []
	for b in main.buildings:
		if b.alive and b.kind == &"normal":
			pool.append(b)
	pool.shuffle()
	# Greedy farthest-point pick from a random start keeps them spread out.
	var picked: Array[Dictionary] = []
	var total := INTERIOR_COUNT + SAFE_COUNT
	while picked.size() < total and not pool.is_empty():
		if picked.is_empty():
			picked.append(pool.pop_back())
			continue
		var best_i := 0
		var best_d := -1.0
		for i in pool.size():
			var d := INF
			for p in picked:
				d = minf(d, (pool[i].center as Vector2).distance_to(p.center))
			# a little randomness so every run differs
			d *= randf_range(0.7, 1.0)
			if d > best_d:
				best_d = d
				best_i = i
		picked.append(pool[best_i])
		pool.remove_at(best_i)
	picked.shuffle()
	# Rooms 0..1 are safe houses, the rest interiors.
	for i in picked.size():
		var is_safe: bool = i < SAFE_COUNT
		var idx := _rooms.size()
		picked[i].kind = &"safehouse" if is_safe else &"interior"
		_build_room(idx, picked[i], is_safe)


func _build_room(i: int, b: Dictionary, is_safe: bool) -> void:
	var cols := randi_range(17, 22)
	var rows := randi_range(11, 14)
	var size := Vector2(cols * TILE, rows * TILE)
	var origin := ROOM_ORIGIN + Vector2(i * ROOM_STRIDE, 0.0)
	var rect := Rect2(origin, size)
	var style := 1 if is_safe else (i % 3)
	var room := {
		rect = rect,
		safe = is_safe,
		building = b,
		entry = origin + Vector2(110.0, size.y / 2.0),
		name = "Safe House" if is_safe else NAMES[i % NAMES.size()],
		populated = false,
		blocked = [],
	}
	_rooms.append(room)
	var holder := Node2D.new()
	holder.name = "Room%d" % i
	_root.add_child(holder)

	# Floor
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = StackModels.interior_floor_texture(style)
	floor_sprite.centered = false
	floor_sprite.region_enabled = true
	floor_sprite.region_rect = Rect2(Vector2.ZERO, size / 4.0)
	floor_sprite.scale = Vector2(4, 4)
	floor_sprite.position = origin
	floor_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_sprite.z_index = -5
	holder.add_child(floor_sprite)

	_build_walls(holder, rect)
	_build_exit(holder, i, rect)
	_build_furniture(holder, room, style)
	_build_door(i, b, is_safe)


func _build_walls(holder: Node2D, rect: Rect2) -> void:
	var door_y: float = rect.position.y + rect.size.y / 2.0
	var body := StaticBody2D.new()
	body.collision_layer = 1
	holder.add_child(body)
	var bounds: Array[Rect2] = [
		Rect2(rect.position.x - TILE, rect.position.y - TILE, rect.size.x + 2.0 * TILE, TILE),
		Rect2(rect.position.x - TILE, rect.end.y, rect.size.x + 2.0 * TILE, TILE),
		Rect2(rect.position.x - TILE, rect.position.y, TILE, rect.size.y),
		Rect2(rect.end.x, rect.position.y, TILE, rect.size.y),
	]
	for r in bounds:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		collider.shape = shape
		collider.position = r.get_center()
		body.add_child(collider)
	var nx := int(rect.size.x / TILE)
	var ny := int(rect.size.y / TILE)
	for ix in range(-1, nx + 1):
		_wall_stack(holder, Vector2(rect.position.x + (ix + 0.5) * TILE, rect.position.y - 0.5 * TILE))
		_wall_stack(holder, Vector2(rect.position.x + (ix + 0.5) * TILE, rect.end.y + 0.5 * TILE))
	for iy in ny:
		var y: float = rect.position.y + (iy + 0.5) * TILE
		_wall_stack(holder, Vector2(rect.end.x + 0.5 * TILE, y))
		if absf(y - door_y) > TILE * 0.9:  # leave a gap for the exit doorway
			_wall_stack(holder, Vector2(rect.position.x - 0.5 * TILE, y))


func _wall_stack(holder: Node2D, pos: Vector2) -> void:
	var stack := SpriteStack.new()
	stack.model = &"wall"
	stack.cast_shadow = false
	stack.position = pos
	holder.add_child(stack)


## West-wall doorway: dark opening, light spill and the exit trigger.
func _build_exit(holder: Node2D, i: int, rect: Rect2) -> void:
	var door_y: float = rect.position.y + rect.size.y / 2.0
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.02, 0.02)
	dark.position = Vector2(rect.position.x - TILE, door_y - TILE)
	dark.size = Vector2(TILE, TILE * 2.0)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.z_index = 2
	holder.add_child(dark)
	_light_spill(holder, Vector2(rect.position.x + 30.0, door_y), Color(1.0, 0.85, 0.5, 0.45), 1.0)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	area.position = Vector2(rect.position.x + 22.0, door_y)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, TILE * 2.0)
	collider.shape = shape
	area.add_child(collider)
	holder.add_child(area)
	_door_areas.append([area, i, true])


func _light_spill(parent: Node, pos: Vector2, color: Color, scale_mult: float) -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.position = pos
	sprite.modulate = color
	sprite.scale = Vector2.ONE * scale_mult
	sprite.z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	parent.add_child(sprite)


func _build_furniture(holder: Node2D, room: Dictionary, style: int) -> void:
	var rect: Rect2 = room.rect
	var entry: Vector2 = room.entry
	var door := Vector2(rect.position.x + 22.0, rect.position.y + rect.size.y / 2.0)
	var models: Array[StringName] = [&"shelf", &"shelf", &"bed", &"table", &"table"]
	if style == 2:
		models = [&"hospital_bed", &"hospital_bed", &"shelf", &"table"]
	var count := randi_range(8, 12)
	var placed: Array[Vector2] = []
	var inner := rect.grow(-90.0)
	for n in count:
		for attempt in 40:
			var p := Vector2(
				randf_range(inner.position.x, inner.end.x),
				randf_range(inner.position.y, inner.end.y))
			if p.distance_to(entry) < 170.0 or p.distance_to(door) < 140.0:
				continue
			var ok := true
			for q in placed:
				if p.distance_to(q) < 120.0:
					ok = false
					break
			if not ok:
				continue
			placed.append(p)
			var body := StaticBody2D.new()
			body.position = p
			var collider := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size = Vector2(46, 46)
			collider.shape = shape
			body.add_child(collider)
			var stack := SpriteStack.new()
			stack.model = models[randi() % models.size()]
			stack.stack_rotation = (randi() % 4) * PI / 2.0
			body.add_child(stack)
			holder.add_child(body)
			break
	room.blocked = placed


## Door visuals and trigger on the building's east face.
func _build_door(i: int, b: Dictionary, is_safe: bool) -> void:
	var center: Vector2 = b.center
	var size: Vector2 = b.size
	var door := center + Vector2(size.x / 2.0, 0.0)
	var dark := ColorRect.new()
	dark.color = Color(0.04, 0.03, 0.03)
	dark.position = door + Vector2(-5, -26)
	dark.size = Vector2(12, 52)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.z_index = 2
	_root.add_child(dark)
	var spill_color := Color(0.5, 1.0, 0.55, 0.35) if is_safe else Color(1.0, 0.8, 0.45, 0.35)
	_light_spill(_root, door + Vector2(22, 0), spill_color, 0.8)

	if is_safe:
		var body = b.body
		if is_instance_valid(body):
			var marker := SpriteStack.new()
			marker.model = &"safehouse_marker"
			marker.cast_shadow = false
			marker.position = Vector2(0, -float(b.height_px))
			body.add_child(marker)
		var label := Label.new()
		label.text = "SAFE"
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
		label.add_theme_color_override("font_outline_color", Color(0, 0.15, 0))
		label.add_theme_constant_override("outline_size", 4)
		label.size = Vector2(60, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = door + Vector2(-8, -58)
		label.z_index = 50
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(label)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	area.position = door + Vector2(22, 0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 56)
	collider.shape = shape
	area.add_child(collider)
	_root.add_child(area)
	_door_areas.append([area, i, false])


# --- Darkness -----------------------------------------------------------------


func _make_darkness() -> void:
	_dark = Node2D.new()
	_dark.z_index = 99
	_dark.visible = false
	_root.add_child(_dark)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 1)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	_dark_sprite = Sprite2D.new()
	_dark_sprite.texture = tex
	_dark.add_child(_dark_sprite)
	# Opaque black frame around the gradient square (built in _set_darkness_size).
	for n in 4:
		var r := ColorRect.new()
		r.color = Color.BLACK
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.name = "Frame%d" % n
		_dark.add_child(r)
	_set_darkness_size(VISION_RADIUS)


func _set_darkness_size(radius: float) -> void:
	if is_equal_approx(radius, _dark_extent):
		return
	_dark_extent = radius
	_dark_sprite.scale = Vector2.ONE * (radius / 128.0)
	var e := radius
	var big := 4000.0
	var frames: Array[Rect2] = [
		Rect2(-big, -big, 2.0 * big, big - e),
		Rect2(-big, e, 2.0 * big, big - e),
		Rect2(-big, -e, big - e, 2.0 * e),
		Rect2(e, -e, big - e, 2.0 * e),
	]
	for n in 4:
		var r: ColorRect = _dark.get_node("Frame%d" % n)
		r.position = frames[n].position
		r.size = frames[n].size


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_update_prompt()
	var p: Node2D = main.player
	_dark.visible = _current >= 0
	if _current < 0:
		return
	var mult := 1.3 if Game.perks.get("long_vision", false) else 1.0
	_set_darkness_size(VISION_RADIUS * mult)
	_dark.global_position = p.global_position
	if _rooms[_current].safe and p.has_method("add_infection") and not p.get("dead"):
		p.add_infection(-SAFE_HEAL * delta)


# --- Transitions ----------------------------------------------------------------


func _is_human(body: Node) -> bool:
	if body != main.player:
		return false
	var z = body.get("is_zombie")
	return z == null or not z


## The usable door (entrance outside, or the current room's exit) the body is
## standing in, as [area, room index, is_exit], or [] when none.
func _door_at(body: Node) -> Array:
	if not _is_human(body):
		return []
	for d in _door_areas:
		var usable: bool = (d[2] and _current == d[1]) or (not d[2] and _current < 0)
		if usable and d[0].overlaps_body(body):
			return d
	return []


## Space bar: enter/exit through the door the player stands at. Returns true
## when a door was used (so the key doesn't also shove).
func try_use_door(body: Node) -> bool:
	if _cooldown > 0.0:
		return false
	var d := _door_at(body)
	if d.is_empty():
		return false
	_cooldown = 0.8
	if d[2]:
		_exit.call_deferred(d[1])
	else:
		_enter.call_deferred(d[1])
	return true


## Floating "SPACE" hint above the player while they stand at a usable door.
func _update_prompt() -> void:
	if _prompt == null:
		_prompt = Label.new()
		_prompt.text = "SPACE"
		_prompt.add_theme_font_size_override("font_size", 12)
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
		_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
		_prompt.add_theme_constant_override("outline_size", 4)
		_prompt.z_index = 110
		_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main.add_child(_prompt)
	var p = main.player
	_prompt.visible = _cooldown <= 0.0 and not _door_at(p).is_empty()
	if _prompt.visible:
		_prompt.position = p.global_position + Vector2(-20, -70)


func _enter(i: int) -> void:
	var room: Dictionary = _rooms[i]
	var p = main.player
	_current = i
	Sfx.play(&"door_open", p.global_position)
	var rect: Rect2 = room.rect
	if p.has_method("teleport"):
		p.teleport(room.entry)
	else:
		p.global_position = room.entry
	p.set("interior_id", i)
	p.set("in_safe_house", room.safe)
	if p.has_method("set_camera_limits"):
		p.set_camera_limits(rect.grow(120.0))
	Game.say(room.name, Color(0.5, 1.0, 0.55) if room.safe else Color(1.0, 0.85, 0.5))
	if not room.populated:
		room.populated = true
		if not room.safe:
			_populate(i)


func _exit(i: int) -> void:
	var room: Dictionary = _rooms[i]
	var p = main.player
	var b: Dictionary = room.building
	var size: Vector2 = b.size
	var outside: Vector2 = (b.center as Vector2) + Vector2(size.x / 2.0 + 44.0, 0.0)
	_current = -1
	Sfx.play(&"door_open", outside)
	if p.has_method("teleport"):
		p.teleport(outside)
	else:
		p.global_position = outside
	p.set("interior_id", -1)
	p.set("in_safe_house", false)
	if p.has_method("set_camera_limits"):
		p.set_camera_limits(MAP_LIMITS)


## Crates and zombies are created the first time a room is entered.
func _populate(i: int) -> void:
	var room: Dictionary = _rooms[i]
	var rect: Rect2 = room.rect
	var entry: Vector2 = room.entry
	var blocked: Array = room.blocked
	var spots: Array[Vector2] = []
	var inner := rect.grow(-80.0)
	var zombie_count := randi_range(1, 2)
	var crate_count := 2
	for n in crate_count + zombie_count:
		var is_crate := n < crate_count
		for attempt in 40:
			var p := Vector2(
				randf_range(inner.position.x, inner.end.x),
				randf_range(inner.position.y, inner.end.y))
			if p.distance_to(entry) < (160.0 if is_crate else 320.0):
				continue
			var ok := true
			for q in blocked:
				if p.distance_to(q) < 60.0:
					ok = false
			for q in spots:
				if p.distance_to(q) < 70.0:
					ok = false
			if not ok:
				continue
			spots.append(p)
			if is_crate:
				if main.has_method("spawn_crate"):
					main.spawn_crate(p, false, true)  # interior crates never roll clues
			elif main.has_method("spawn_zombie"):
				main.spawn_zombie(p, ZOMBIE_VARIANTS[randi() % ZOMBIE_VARIANTS.size()], i)
			break
