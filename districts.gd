extends Node
## District flavor: a faint tint per map quadrant, a few themed props, street
## signs at every intersection, and the "entering <district>" announcement.
##
## Street sign placement: each sign tries the corner-sidewalk offsets in
## SIGN_OFFSETS and takes the first spot with walkable clearance from
## streetlights, buildings, trees and other solid props. If none is clear the
## sign is placed without a collider so it can never pinch a path shut.
## Payphones (phones.gd) check `solids` to keep clear of everything here.

const SIGN_OFFSETS: Array[Vector2] = [
	Vector2(-112, -112), Vector2(112, -112), Vector2(-112, 112), Vector2(112, 112),
	Vector2(-150, -60), Vector2(150, -60), Vector2(-150, 60), Vector2(150, 60),
	Vector2(-60, -150), Vector2(60, -150), Vector2(-60, 150), Vector2(60, 150),
]
const TINT_ALPHA := 0.10
const PROPS_PER_DISTRICT := 9

## World positions of every blocking prop placed here (cans, dumpsters, signs),
## so later placements (payphones) can keep a walkable gap.
var solids: Array[Vector2] = []

var main = null
var _root: Node2D
var _used: Array[Vector2] = []
var _last_index: int = -1
var _current: String = ""


func setup(m) -> void:
	main = m
	_root = Node2D.new()
	_root.name = "Districts"
	main.add_child(_root)
	_make_tints()
	_make_props()
	_make_signs()


## Name of the district the player is in (empty string indoors / before start).
func current_district() -> String:
	return _current


func _process(_delta: float) -> void:
	if main == null or not Game.started:
		return
	var p = main.player
	if p == null:
		return
	var interior = p.get("interior_id")
	if interior != null and int(interior) >= 0:
		return
	var idx: int = Game.district_index(p.global_position)
	if idx == _last_index:
		return
	_last_index = idx
	_current = Game.DISTRICT_NAMES[idx]
	Game.district_changed.emit(_current)
	Game.say(_current, Game.DISTRICT_COLORS[idx].lightened(0.3))


# --- Tint ---------------------------------------------------------------------


func _make_tints() -> void:
	var half_w: float = main.COLS * main.CELL / 2.0
	var half_h: float = main.ROWS * main.CELL / 2.0
	for i in 4:
		var rect := ColorRect.new()
		rect.position = Vector2((i % 2) * half_w, (i / 2) * half_h)
		rect.size = Vector2(half_w, half_h)
		var c: Color = Game.DISTRICT_COLORS[i]
		if i == 3:
			c = Color(0.92, 0.95, 1.0)  # Mercy Hill: clean and pale
		rect.color = Color(c, TINT_ALPHA if i != 3 else 0.08)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = -10
		_root.add_child(rect)


# --- Props --------------------------------------------------------------------


func _make_props() -> void:
	var half_w: float = main.COLS * main.CELL / 2.0
	var half_h: float = main.ROWS * main.CELL / 2.0
	for i in 4:
		var quad := Rect2((i % 2) * half_w, (i / 2) * half_h, half_w, half_h)
		match i:
			0:  # Old Market: dumpsters and trash cans
				for n in 3:
					_solid(&"dumpster", _pick(quad), Vector2(52, 36))
				for n in 2:
					_solid(&"trash_can", _pick(quad), Vector2(22, 22))
			1:  # Neon Heights: glowing neon blobs near the streetlights
				_neon_lights(quad)
				_solid(&"trash_can", _pick(quad), Vector2(22, 22))
			2:  # Rustwater Docks: grime and barrel-like trash cans
				for n in 10:
					_stain(_pick(quad))
				_solid(&"trash_can", _pick(quad), Vector2(22, 22))
				_solid(&"dumpster", _pick(quad), Vector2(52, 36))
			3:  # Mercy Hill: clean; a single tidy bin
				_solid(&"trash_can", _pick(quad), Vector2(22, 22))


## A random sidewalk spot in `quad`, clear of roads, parks, buildings and corners.
func _pick(quad: Rect2) -> Vector2:
	for attempt in 120:
		var p := Vector2(
			randf_range(quad.position.x + 30.0, quad.end.x - 30.0),
			randf_range(quad.position.y + 30.0, quad.end.y - 30.0))
		if _spot_ok(p):
			_used.append(p)
			return p
	return Vector2(-1000, -1000)  # nothing found: park it off-map (harmless)


func _spot_ok(p: Vector2) -> bool:
	if p.x < 70.0 or p.y < 70.0 or p.x > main.COLS * main.CELL - 70.0 \
			or p.y > main.ROWS * main.CELL - 70.0:
		return false
	for vx: float in main.VROADS:
		if absf(p.x - vx) < main.ROAD_HALF + 34.0:
			return false
	for hy: float in main.HROADS:
		if absf(p.y - hy) < main.ROAD_HALF + 34.0:
			return false
	for park: Rect2 in main.PARKS:
		if park.grow(34.0).has_point(p):
			return false
	for vx: float in main.VROADS:
		for hy: float in main.HROADS:
			if p.distance_to(Vector2(vx, hy)) < 190.0:
				return false
	if main.point_in_building(p) or main.point_hidden(p):
		return false
	for q in _used:
		if p.distance_to(q) < 80.0:
			return false
	for s in solids:
		if p.distance_to(s) < 70.0:
			return false
	return true


func _solid(model: StringName, pos: Vector2, collider_size: Vector2) -> void:
	if pos.x < 0.0:
		return
	solids.append(pos)
	main.register_obstacle(pos, maxf(collider_size.x, collider_size.y) * 0.5 + 6.0)
	var body := StaticBody2D.new()
	body.position = pos
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = collider_size
	collider.shape = shape
	body.add_child(collider)
	var stack := SpriteStack.new()
	stack.model = model
	stack.stack_rotation = randf_range(-0.4, 0.4)
	body.add_child(stack)
	_root.add_child(body)


func _stain(pos: Vector2) -> void:
	if pos.x < 0.0:
		return
	var w := 14
	var h := 9
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var tone := Color(0.12, 0.16, 0.12, 0.55) if randf() < 0.6 else Color(0.25, 0.18, 0.1, 0.5)
	for y in h:
		for x in w:
			var nx := (x - w / 2.0 + 0.5) / (w / 2.0)
			var ny := (y - h / 2.0 + 0.5) / (h / 2.0)
			if nx * nx + ny * ny < 0.9 + sin(x * 3.1 + y * 1.7) * 0.15:
				img.set_pixel(x, y, tone)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * randf_range(3.0, 6.0)
	sprite.rotation = randf() * TAU
	sprite.position = pos
	sprite.z_index = -10  # added after the tint, so it draws over it
	_root.add_child(sprite)


func _neon_lights(quad: Rect2) -> void:
	var tex := _glow_texture()
	var colors: Array[Color] = [
		Color(1.0, 0.2, 0.85), Color(0.2, 0.95, 1.0), Color(1.0, 0.9, 0.25), Color(0.6, 0.3, 1.0)]
	var spots: Array[Vector2] = []
	for vx: float in main.VROADS:
		for hy: float in main.HROADS:
			var center := Vector2(vx, hy)
			if not quad.has_point(center):
				continue
			for corner: Vector2 in [Vector2(-70, -70), Vector2(70, -70), Vector2(-70, 70), Vector2(70, 70)]:
				spots.append(center + corner + Vector2(0, -8))
	for n in 5:
		var p := _pick(quad)
		if p.x > 0.0:
			spots.append(p)
	for n in spots.size():
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.position = spots[n]
		sprite.modulate = Color(colors[n % colors.size()], 0.55)
		sprite.scale = Vector2.ONE * randf_range(0.8, 1.3)
		sprite.z_index = 4
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = mat
		_root.add_child(sprite)
		var tween := sprite.create_tween().set_loops()
		var base: float = sprite.modulate.a
		tween.tween_property(sprite, "modulate:a", base * 0.55, randf_range(0.6, 1.4))
		tween.tween_property(sprite, "modulate:a", base, randf_range(0.6, 1.4))


func _glow_texture() -> GradientTexture2D:
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
	return tex


# --- Street signs -------------------------------------------------------------


func _make_signs() -> void:
	for vi in main.VROADS.size():
		for hi in main.HROADS.size():
			var corner := Vector2(main.VROADS[vi], main.HROADS[hi])
			var pos := corner + SIGN_OFFSETS[0]
			var clear := false
			for off: Vector2 in SIGN_OFFSETS:
				if _sign_spot_ok(corner + off, corner):
					pos = corner + off
					clear = true
					break
			main.register_obstacle(pos, 12.0)
			var body := StaticBody2D.new()
			body.position = pos
			if clear:
				# Only a verified-clear sign blocks; a cramped one is walk-through.
				solids.append(pos)
				var collider := CollisionShape2D.new()
				var shape := CircleShape2D.new()
				shape.radius = 6.0
				collider.shape = shape
				body.add_child(collider)
			var stack := SpriteStack.new()
			stack.model = &"street_sign"
			body.add_child(stack)
			_root.add_child(body)

			var label := Label.new()
			label.text = "%s & %s" % [Game.VROAD_NAMES[vi], Game.HROAD_NAMES[hi]]
			label.add_theme_font_size_override("font_size", 11)
			label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.9))
			label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			label.add_theme_constant_override("outline_size", 4)
			label.size = Vector2(190, 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.position = pos + Vector2(-95, -86)
			label.z_index = 50
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_root.add_child(label)


## True when a sign pole at `pos` leaves a walkable gap (wider than any
## character) to the corner's streetlights, buildings, park trees and the
## other solid props.
func _sign_spot_ok(pos: Vector2, corner: Vector2) -> bool:
	if pos.x < 40.0 or pos.y < 40.0 or pos.x > main.COLS * main.CELL - 40.0 \
			or pos.y > main.ROWS * main.CELL - 40.0:
		return false
	for light_off: Vector2 in [Vector2(-70, -70), Vector2(70, -70), Vector2(-70, 70), Vector2(70, 70)]:
		if pos.distance_to(corner + light_off) < 55.0:
			return false
	for b in main.buildings:
		if (b.rect as Rect2).grow(44.0).has_point(pos):
			return false
	for t: Vector2 in main.TREES:
		if pos.distance_to(t) < 80.0:
			return false
	for s in solids:
		if pos.distance_to(s) < 70.0:
			return false
	return true
