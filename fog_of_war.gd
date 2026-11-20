class_name FogOfWar
extends Sprite2D
## Covers the map in near-black fog and permanently reveals a soft-edged
## circle around the player as they explore. One fog pixel = PX world pixels;
## the low-res texture is scaled up with linear filtering for smooth edges.

const PX := 8.0
const CLEAR_RADIUS := 150.0
const FADE_BAND := 110.0
const FOG_COLOR := Color(0.04, 0.04, 0.06, 1.0)

var _img: Image
var _player: Node2D
var _origin: Vector2
var _accum: float = 1.0  # large so the first _process stamps immediately


func setup(rect: Rect2, player: Node2D) -> void:
	_origin = rect.position
	_player = player
	var w := int(ceil(rect.size.x / PX))
	var h := int(ceil(rect.size.y / PX))
	_img = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	_img.fill(FOG_COLOR)
	texture = ImageTexture.create_from_image(_img)
	centered = false
	position = _origin
	scale = Vector2(PX, PX)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 100


## True when the world position is still (mostly) hidden by fog.
func is_fogged(world_pos: Vector2) -> bool:
	var p := (world_pos - _origin) / PX
	var x := clampi(int(p.x), 0, _img.get_width() - 1)
	var y := clampi(int(p.y), 0, _img.get_height() - 1)
	return _img.get_pixel(x, y).a > 0.6


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.08:
		return
	_accum = 0.0
	_stamp()


func _stamp() -> void:
	var center := (_player.global_position - _origin) / PX
	var reach := (CLEAR_RADIUS + FADE_BAND) / PX
	var x0 := maxi(int(center.x - reach), 0)
	var x1 := mini(int(center.x + reach) + 1, _img.get_width())
	var y0 := maxi(int(center.y - reach), 0)
	var y1 := mini(int(center.y + reach) + 1, _img.get_height())
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dist := (Vector2(x + 0.5, y + 0.5) - center).length() * PX
			var a := clampf((dist - CLEAR_RADIUS) / FADE_BAND, 0.0, 1.0)
			var p := _img.get_pixel(x, y)
			if a < p.a:
				p.a = a
				_img.set_pixel(x, y, p)
	(texture as ImageTexture).update(_img)
