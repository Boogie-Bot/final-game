extends Control
## Circular minimap that mirrors the fog of war. Shows district names,
## buildings (rubble when demolished), the player, the CPU survivor, the
## hospital / safe house once discovered, and pings for nearby cure herbs.
## Slides to the screen quadrant diagonally opposite the player so it never
## covers where they are heading. `capture_photo()` renders a zoomed-out
## picture for the end screen.

const MAP_SIZE := Vector2(2400.0, 1440.0)
const FOG_RECT := Rect2(-48.0, -48.0, 2496.0, 1536.0)
const RADIUS := 96.0
const MINI_SIZE := Vector2(RADIUS * 2.0, RADIUS * 2.0)
const MARGIN := 12.0
const HERB_RANGE := 350.0
## Player must be this far past screen center before the minimap swaps
## quadrants, so a centered player doesn't make it jitter between corners.
const SWAP_DEADZONE := 60.0

const C_CONCRETE := Color(0.33, 0.26, 0.40)
const C_PARK := Color(0.20, 0.50, 0.45)
const C_ROAD := Color(0.12, 0.08, 0.18)
const C_BUILDING := Color(0.74, 0.52, 0.80)
const C_RUBBLE := Color(0.40, 0.30, 0.38)

var _main = null
var _base_tex: ImageTexture
var _alive_sig: String = ""
var _poll: float = 0.0
var _pings: Array[Dictionary] = []
## Map drawn letterboxed inside the circle (largest 5:3 rect that fits).
var _map_rect: Rect2
## Which corner the minimap sits in: 0 = left/top, 1 = right/bottom.
var _quad := Vector2i(1, 1)
var _snap := true


func setup(main: Node) -> void:
	_main = main
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	size = MINI_SIZE
	var r := RADIUS - 6.0
	var w := 2.0 * r / sqrt(1.0 + pow(MAP_SIZE.y / MAP_SIZE.x, 2.0))
	var h := w * MAP_SIZE.y / MAP_SIZE.x
	_map_rect = Rect2(Vector2(RADIUS - w * 0.5, RADIUS - h * 0.5), Vector2(w, h))
	visible = false
	Game.minimap_ping.connect(_on_ping)
	_rebuild_base()


func _on_ping(pos: Vector2, color: Color, duration: float) -> void:
	_pings.append({pos = pos, color = color, left = duration, dur = maxf(duration, 0.01)})


func _process(delta: float) -> void:
	if Game.started != visible:
		visible = Game.started
		_snap = true
	if not visible:
		return
	_update_corner(delta)
	_poll -= delta
	if _poll <= 0.0:
		_poll = 1.0
		if _signature() != _alive_sig:
			_rebuild_base()
	for i in range(_pings.size() - 1, -1, -1):
		_pings[i].left -= delta
		if _pings[i].left <= 0.0:
			_pings.remove_at(i)
	queue_redraw()


## Keeps the minimap in the screen quadrant furthest from the player,
## with a center deadzone and smoothing so it doesn't flicker or teleport.
func _update_corner(delta: float) -> void:
	var vp := get_viewport_rect().size
	var player = _main.player
	if player != null and is_instance_valid(player):
		var p: Vector2 = player.get_global_transform_with_canvas().origin
		if p.x < vp.x * 0.5 - SWAP_DEADZONE:
			_quad.x = 1
		elif p.x > vp.x * 0.5 + SWAP_DEADZONE:
			_quad.x = 0
		if p.y < vp.y * 0.5 - SWAP_DEADZONE:
			_quad.y = 1
		elif p.y > vp.y * 0.5 + SWAP_DEADZONE:
			_quad.y = 0
	var target := Vector2(
		MARGIN if _quad.x == 0 else vp.x - MINI_SIZE.x - MARGIN,
		MARGIN if _quad.y == 0 else vp.y - MINI_SIZE.y - MARGIN)
	if _snap:
		_snap = false
		position = target
	else:
		position = position.lerp(target, minf(delta * 7.0, 1.0))


func _signature() -> String:
	var s := ""
	for b in _main.buildings:
		s += "1" if b.alive else "0"
	return s


func _rebuild_base() -> void:
	_alive_sig = _signature()
	_base_tex = ImageTexture.create_from_image(_render_base(_map_rect.size.x / MAP_SIZE.x))


## Pre-rendered ground + buildings at `s` pixels per world pixel.
func _render_base(s: float) -> Image:
	var img := Image.create_empty(int(MAP_SIZE.x * s), int(MAP_SIZE.y * s), false, Image.FORMAT_RGBA8)
	img.fill(C_CONCRETE)
	for park: Rect2 in _main.PARKS:
		_fill(img, park, s, C_PARK)
	var half: float = _main.ROAD_HALF
	for vx: float in _main.VROADS:
		_fill(img, Rect2(vx - half, 0, half * 2.0, MAP_SIZE.y), s, C_ROAD)
	for hy: float in _main.HROADS:
		_fill(img, Rect2(0, hy - half, MAP_SIZE.x, half * 2.0), s, C_ROAD)
	for b in _main.buildings:
		var col := C_BUILDING if b.alive else C_RUBBLE
		if b.alive and b.kind == &"hospital":
			col = Color(0.85, 0.7, 0.7)
		elif b.alive and b.kind == &"safehouse":
			col = Color(0.6, 0.8, 0.65)
		_fill(img, b.rect, s, col)
	return img


func _fill(img: Image, r: Rect2, s: float, c: Color) -> void:
	var x0 := maxi(int(r.position.x * s), 0)
	var y0 := maxi(int(r.position.y * s), 0)
	var x1 := mini(int(ceil(r.end.x * s)), img.get_width())
	var y1 := mini(int(ceil(r.end.y * s)), img.get_height())
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)


func _to_mini(world: Vector2) -> Vector2:
	return _map_rect.position + world * (_map_rect.size.x / MAP_SIZE.x)


func _on_map(world: Vector2) -> bool:
	return Rect2(Vector2.ZERO, MAP_SIZE).has_point(world)


func _draw() -> void:
	if _main == null or _base_tex == null:
		return
	var font := ThemeDB.fallback_font
	var center := Vector2(RADIUS, RADIUS)
	draw_circle(center, RADIUS, Color(0, 0, 0, 0.8))
	draw_texture_rect(_base_tex, _map_rect, false)
	var scale_m := _map_rect.size.x / MAP_SIZE.x
	var fog = _main.fog
	if fog != null and fog.texture != null:
		var fr := Rect2(_to_mini(FOG_RECT.position), FOG_RECT.size * scale_m)
		draw_texture_rect(fog.texture, fr, false)
	# District names, one per quadrant.
	for i in 4:
		var qpos := _map_rect.position + Vector2(
			(i % 2) * _map_rect.size.x * 0.5, (i / 2) * _map_rect.size.y * 0.5)
		var col: Color = Game.DISTRICT_COLORS[i]
		col.a = 0.9
		var txt: String = Game.DISTRICT_NAMES[i]
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		draw_string_outline(font, qpos + Vector2(_map_rect.size.x * 0.25 - w * 0.5, _map_rect.size.y * 0.25 + 4.0),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.85))
		draw_string(font, qpos + Vector2(_map_rect.size.x * 0.25 - w * 0.5, _map_rect.size.y * 0.25 + 4.0),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)
	# Hospital / safe house icons once discovered.
	for b in _main.buildings:
		if not b.alive or (b.kind != &"hospital" and b.kind != &"safehouse"):
			continue
		if fog != null and fog.is_fogged(b.center):
			continue
		var p := _to_mini(b.center)
		if b.kind == &"hospital":
			draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color.WHITE)
			draw_rect(Rect2(p - Vector2(1.5, 4), Vector2(3, 8)), Color(0.85, 0.1, 0.1))
			draw_rect(Rect2(p - Vector2(4, 1.5), Vector2(8, 3)), Color(0.85, 0.1, 0.1))
		else:
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 1), p + Vector2(0, -5), p + Vector2(5, 1)]),
				Color(0.3, 0.95, 0.4))
			draw_rect(Rect2(p + Vector2(-3.5, 1), Vector2(7, 4)), Color(0.3, 0.95, 0.4))
	var player = _main.player
	var inside: bool = player != null and player.interior_id != -1
	# Cure herbs ping when the player is close.
	if player != null and not inside:
		var t := Time.get_ticks_msec() / 1000.0
		for h in get_tree().get_nodes_in_group(&"cure_herb"):
			if h is Node2D and h.global_position.distance_to(player.global_position) < HERB_RANGE:
				var ph := fmod(t, 1.0)
				_ring(_to_mini(h.global_position), 2.0 + ph * 9.0, Color(0.4, 1.0, 0.5, 1.0 - ph))
	for pg in _pings:
		var ph: float = 1.0 - pg.left / pg.dur
		var a: float = 1.0 - ph
		var pulse := fmod(ph * float(pg.dur) * 1.5, 1.0)
		var c: Color = pg.color
		draw_circle(_to_mini(pg.pos), 2.5, Color(c.r, c.g, c.b, a))
		_ring(_to_mini(pg.pos), 3.0 + pulse * 10.0, Color(c.r, c.g, c.b, a * (1.0 - pulse)))
	# Survivor and player.
	if not inside:
		for s in get_tree().get_nodes_in_group(&"survivor"):
			if s is Node2D and s != player and _on_map(s.global_position):
				if fog == null or not fog.is_fogged(s.global_position):
					draw_circle(_to_mini(s.global_position), 3.0, Color(0.3, 0.9, 1.0))
		if player != null and _on_map(player.global_position):
			var pc := Color(1.0, 0.15, 0.15) if player.is_zombie else Color(1.0, 1.0, 0.3)
			draw_circle(_to_mini(player.global_position), 3.5, Color.BLACK)
			draw_circle(_to_mini(player.global_position), 2.5, pc)
	else:
		draw_string_outline(font, Vector2(0, RADIUS + 8), "INSIDE", HORIZONTAL_ALIGNMENT_CENTER,
			MINI_SIZE.x, 22, 4, Color.BLACK)
		draw_string(font, Vector2(0, RADIUS + 8), "INSIDE", HORIZONTAL_ALIGNMENT_CENTER,
			MINI_SIZE.x, 22, Color(1.0, 0.9, 0.4))
	draw_arc(center, RADIUS - 1.0, 0.0, TAU, 64, Color(0.85, 0.85, 0.9), 2.0, true)


func _ring(p: Vector2, r: float, c: Color) -> void:
	draw_arc(p, r, 0.0, TAU, 20, c, 1.5)


## Zoomed-out picture of the map with fog applied (fogged = dark) and markers.
func capture_photo(size: Vector2i = Vector2i(720, 432)) -> ImageTexture:
	var s := size.x / MAP_SIZE.x
	var img := _render_base(s)
	var fog = _main.fog
	if fog != null:
		var f: Image = fog.snapshot()
		f.resize(int(FOG_RECT.size.x * s), int(FOG_RECT.size.y * s), Image.INTERPOLATE_BILINEAR)
		img.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((FOG_RECT.position * s).round()))
	for z in get_tree().get_nodes_in_group(&"zombies"):
		_photo_mark(img, fog, z, s, Color(0.95, 0.15, 0.15), 3)
	for z in get_tree().get_nodes_in_group(&"fed_zombie"):
		_photo_mark(img, fog, z, s, Color(0.3, 0.5, 1.0), 3)
	for h in get_tree().get_nodes_in_group(&"cure_herb"):
		_photo_mark(img, fog, h, s, Color(0.4, 1.0, 0.5), 3)
	for b in _main.buildings:
		if b.alive and (b.kind == &"hospital" or b.kind == &"safehouse"):
			var col := Color(1, 1, 1) if b.kind == &"hospital" else Color(0.3, 0.95, 0.4)
			_photo_dot(img, fog, b.center, s, col, 5, true)
	for sv in get_tree().get_nodes_in_group(&"survivor"):
		if sv != _main.player:
			_photo_mark(img, fog, sv, s, Color(0.3, 0.9, 1.0), 4)
	var p = _main.player
	if p != null:
		_photo_dot(img, null, p.global_position, s,
			Color(1.0, 0.15, 0.15) if p.is_zombie else Color(1.0, 1.0, 0.3), 5, true)
	return ImageTexture.create_from_image(img)


func _photo_mark(img: Image, fog, node: Node, s: float, c: Color, r: int) -> void:
	if node is Node2D and node != _main.player:
		_photo_dot(img, fog, node.global_position, s, c, r)


func _photo_dot(img: Image, fog, world: Vector2, s: float, c: Color, r: int, outline: bool = false) -> void:
	if not _on_map(world) or (fog != null and not fog.was_explored(world)):
		return
	var cx := int(world.x * s)
	var cy := int(world.y * s)
	var ro := r + (1 if outline else 0)
	for y in range(maxi(cy - ro, 0), mini(cy + ro + 1, img.get_height())):
		for x in range(maxi(cx - ro, 0), mini(cx + ro + 1, img.get_width())):
			var d := Vector2(x - cx, y - cy).length()
			if d <= r:
				img.set_pixel(x, y, c)
			elif outline and d <= ro:
				img.set_pixel(x, y, Color.BLACK)
