class_name FogOfWar
extends Sprite2D
## Covers the map in near-black fog and permanently reveals a soft-edged
## circle around the player as they explore. One fog pixel = PX world pixels;
## the low-res texture is scaled up with linear filtering for smooth edges.

const PX := 8.0
const CLEAR_RADIUS := 150.0
const FADE_BAND := 110.0
const FOG_COLOR := Color(0.04, 0.04, 0.06, 1.0)

## Hard mode keeps reveals this long (seconds) before fogging them again.
const HARD_REVEAL_TIME := 6.0

var clear_radius: float = CLEAR_RADIUS
var persistent: bool = true  # false on hard: only the live vision circle stays clear

var _img: Image
var _explored: Image  # never re-fogs: everywhere you've ever seen (end-screen photos)
var _player: Node2D
var _origin: Vector2
var _rect: Rect2
var _accum: float = 1.0  # large so the first _process stamps immediately
var _reveals: Array[Dictionary] = []  # temporary reveals (hard mode): {pos, radius, left}


func setup(rect: Rect2, player: Node2D) -> void:
	_origin = rect.position
	_rect = rect
	_player = player
	clear_radius = CLEAR_RADIUS * (1.3 if Game.perks.get("long_vision", false) else 1.0)
	persistent = Game.difficulty != 2
	var w := int(ceil(rect.size.x / PX))
	var h := int(ceil(rect.size.y / PX))
	_img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	_img.fill(FOG_COLOR)
	_explored = _img.duplicate()
	texture = ImageTexture.create_from_image(_img)
	centered = false
	position = _origin
	scale = Vector2(PX, PX)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 100


## Hard mode (false): the fog returns as soon as you leave a spot.
func set_persistent(on: bool) -> void:
	persistent = on


## Clears a circle of fog (clue pings, etc.). On hard it fades back after a few seconds.
func reveal(pos: Vector2, radius: float) -> void:
	if _img == null:
		return
	if persistent:
		_stamp_circle(pos, radius)
		(texture as ImageTexture).update(_img)
	else:
		_reveals.append({pos = pos, radius = radius, left = HARD_REVEAL_TIME})


## Copy of the explored-area fog (alpha = fogged amount) for end-screen
## photos. On hard the live fog re-covers everything, so this keeps the route.
func snapshot() -> Image:
	return _explored.duplicate()


## True when the player has ever seen this spot (independent of hard-mode re-fog).
func was_explored(world_pos: Vector2) -> bool:
	var p := (world_pos - _origin) / PX
	var x := clampi(int(p.x), 0, _explored.get_width() - 1)
	var y := clampi(int(p.y), 0, _explored.get_height() - 1)
	return _explored.get_pixel(x, y).a <= 0.6


## True when the world position is still (mostly) hidden by fog.
func is_fogged(world_pos: Vector2) -> bool:
	var p := (world_pos - _origin) / PX
	var x := clampi(int(p.x), 0, _img.get_width() - 1)
	var y := clampi(int(p.y), 0, _img.get_height() - 1)
	return _img.get_pixel(x, y).a > 0.6


func _process(delta: float) -> void:
	for i in range(_reveals.size() - 1, -1, -1):
		_reveals[i].left -= delta
		if _reveals[i].left <= 0.0:
			_reveals.remove_at(i)
	_accum += delta
	if _accum < 0.08:
		return
	_accum = 0.0
	_stamp()


func _stamp() -> void:
	var on_map := _rect.has_point(_player.global_position)
	if persistent:
		if not on_map:
			return
		_stamp_circle(_player.global_position, clear_radius)
	else:
		_img.fill(FOG_COLOR)
		if on_map:
			_stamp_circle(_player.global_position, clear_radius)
			_stamp_circle(_player.global_position, clear_radius, _explored)
		for r in _reveals:
			_stamp_circle(r.pos, r.radius)
	(texture as ImageTexture).update(_img)


func _stamp_circle(world_pos: Vector2, radius: float, target: Image = null) -> void:
	if target == null:
		target = _img
		if persistent:
			_stamp_circle(world_pos, radius, _explored)
	var center := (world_pos - _origin) / PX
	var reach := (radius + FADE_BAND) / PX
	var x0 := maxi(int(center.x - reach), 0)
	var x1 := mini(int(center.x + reach) + 1, _img.get_width())
	var y0 := maxi(int(center.y - reach), 0)
	var y1 := mini(int(center.y + reach) + 1, _img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dist := (Vector2(x + 0.5, y + 0.5) - center).length() * PX
			var a := clampf((dist - radius) / FADE_BAND, 0.0, 1.0)
			var p := target.get_pixel(x, y)
			if a < p.a:
				p.a = a
				target.set_pixel(x, y, p)
