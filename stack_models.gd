class_name StackModels
## Procedurally generated slice textures for sprite stacking.
## Every model faces +X at rotation 0 so SpriteStack.stack_rotation can be
## set straight from a movement vector's angle().
##
## get_frames() returns an Array of animation frames; each frame is an
## Array[ImageTexture] of slices (bottom first). Static models have 1 frame,
## characters have a 4-frame walk cycle (swing fwd, neutral, swing back, neutral).

static var _cache: Dictionary = {}
static var _shadow_cache: Dictionary = {}


static func get_frames(model_name: StringName) -> Array:
	var key := String(model_name)
	if not _cache.has(key):
		var frames := []
		match model_name:
			&"player":
				var neutral := _player_slices(0.0)
				frames = [_player_slices(1.0), neutral, _player_slices(-1.0), neutral]
			&"zombie":
				var neutral := _zombie_slices(0.0)
				frames = [_zombie_slices(1.0), neutral, _zombie_slices(-1.0), neutral]
			&"crate":
				frames = [_crate()]
			&"herb":
				frames = [_herb()]
			&"wall":
				frames = [_wall()]
			&"streetlight":
				frames = [_streetlight()]
			&"tree":
				frames = [_tree()]
			# --- Zombie variants / extra character frames ---
			&"runner":
				var neutral := _runner_slices(0.0)
				frames = [_runner_slices(1.0), neutral, _runner_slices(-1.0), neutral]
			&"brute":
				var neutral := _brute_slices(0.0)
				frames = [_brute_slices(1.0), neutral, _brute_slices(-1.0), neutral]
			&"screamer":
				var neutral := _screamer_slices(0.0, false)
				frames = [_screamer_slices(1.0, false), neutral, _screamer_slices(-1.0, false), neutral]
			&"screamer_scream":
				frames = [_screamer_slices(0.0, true)]
			&"player_shove":
				frames = [_player_shove_slices(0), _player_shove_slices(1), _player_shove_slices(2)]
			# --- World props ---
			&"payphone":
				frames = [_payphone(false), _payphone(true)]
			&"door_clean":
				frames = [_door(0)]
			&"door_dirty":
				frames = [_door(1)]
			&"door_ruin":
				frames = [_door(2)]
			&"bottle":
				frames = [_bottle()]
			&"tonic":
				frames = [_tonic()]
			&"charge":
				frames = [_charge()]
			&"crate_open":
				frames = [_crate_open()]
			&"street_sign":
				frames = [_street_sign()]
			&"hospital_cross":
				frames = [_hospital_cross()]
			&"safehouse_marker":
				frames = [_safehouse_marker()]
			# --- Furniture ---
			&"shelf":
				frames = [_shelf()]
			&"bed":
				frames = [_bed()]
			&"table":
				frames = [_table()]
			&"dumpster":
				frames = [_dumpster()]
			&"trash_can":
				frames = [_trash_can()]
			&"hospital_bed":
				frames = [_hospital_bed()]
			&"lab_bench":
				frames = [_lab_bench()]
		_cache[key] = frames
	return _cache[key]


static func building(w: int, d: int, h: int, color: int, design: int) -> Array:
	var key := "bld_%d_%d_%d_%d_%d" % [w, d, h, color, design]
	if not _cache.has(key):
		_cache[key] = [_building(w, d, h, color, design)]
	return _cache[key]


static func cure_herb(index: int) -> Array:
	var key := "cure_%d" % index
	if not _cache.has(key):
		_cache[key] = [_cure_herb(index)]
	return _cache[key]


## Flat top-down icon of a cure herb for the HUD: its slices composited
## top-most-last onto one small image.
static func cure_icon(index: int) -> ImageTexture:
	var key := "icon_%d" % index
	if not _cache.has(key):
		var slices: Array = cure_herb(index)[0]
		var img := _img(12)
		for tex: ImageTexture in slices:
			var layer := tex.get_image()
			for y in 12:
				for x in 12:
					var c := layer.get_pixel(x, y)
					if c.a > 0.5:
						img.set_pixel(x, y, c)
		_cache[key] = _tex(img)
	return _cache[key]


static func car(color_index: int) -> Array:
	var key := "car_%d" % color_index
	if not _cache.has(key):
		_cache[key] = [_car(color_index)]
	return _cache[key]


static func shadow_texture(w: int, h: int) -> ImageTexture:
	var key := "%d_%d" % [w, h]
	if not _shadow_cache.has(key):
		var img := _img2(w, h)
		var rx := maxf(w * 0.34, 1.5)
		var ry := maxf(h * 0.34, 1.5)
		var cx := w / 2.0 - 0.5
		var cy := h / 2.0 - 0.5
		for y in h:
			for x in w:
				var nx := (x - cx) / rx
				var ny := (y - cy) / ry
				if nx * nx + ny * ny <= 1.0:
					img.set_pixel(x, y, Color(0, 0, 0, 0.3))
		_shadow_cache[key] = _tex(img)
	return _shadow_cache[key]


# --- Ground / road textures ---------------------------------------------------


static func concrete_texture() -> ImageTexture:
	var img := _img(32)
	var base := Color(0.38, 0.30, 0.44)
	var seam := Color(0.31, 0.24, 0.37)
	var fleck := Color(0.44, 0.35, 0.50)
	for y in 32:
		for x in 32:
			if x % 8 == 0 or y % 8 == 0:
				img.set_pixel(x, y, seam)
			elif (x * 97 + y * 57) % 19 == 0:
				img.set_pixel(x, y, fleck)
			else:
				img.set_pixel(x, y, base)
	return _tex(img)


static func grass_texture() -> ImageTexture:
	var img := _img(32)
	var base := Color(0.16, 0.42, 0.38)
	var light := Color(0.23, 0.52, 0.47)
	var dark := Color(0.12, 0.33, 0.30)
	for y in 32:
		for x in 32:
			var h := (x * 97 + y * 57) % 23
			if h == 0:
				img.set_pixel(x, y, light)
			elif h == 1:
				img.set_pixel(x, y, dark)
			else:
				img.set_pixel(x, y, base)
	return _tex(img)


static func road_texture(vertical: bool) -> ImageTexture:
	var img := _img2(24, 16) if vertical else _img2(16, 24)
	var asphalt := Color(0.16, 0.10, 0.22)
	var dark := Color(0.13, 0.08, 0.19)
	var dash := Color(0.95, 0.40, 0.75)
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, dark if (x * 31 + y * 17) % 13 == 0 else asphalt)
	if vertical:
		_rect(img, 11, 0, 2, 8, dash)
	else:
		_rect(img, 0, 11, 8, 2, dash)
	return _tex(img)


# --- Characters ---------------------------------------------------------------


static func _player_slices(swing: float) -> Array[ImageTexture]:
	var skin := Color(0.87, 0.68, 0.55)
	var hair := Color(0.3, 0.2, 0.12)
	var shirt := Color(0.75, 0.2, 0.2)
	var pants := Color(0.22, 0.28, 0.5)
	var boots := Color(0.25, 0.18, 0.12)
	var eye := Color(0.12, 0.12, 0.15)
	var slices: Array[ImageTexture] = []
	var foot := roundi(swing * 2.0)

	# Boots (2 layers) - swing along the facing axis (+X)
	for i in 2:
		var img := _img(16)
		_rect(img, 7 + foot, 4, 4, 3, boots)
		_rect(img, 7 - foot, 9, 4, 3, boots)
		slices.append(_tex(img))
	# Legs (3 layers)
	for i in 3:
		var img := _img(16)
		_circle(img, 8 + swing * 1.5, 5.5, 1.6, pants)
		_circle(img, 8 - swing * 1.5, 10.5, 1.6, pants)
		slices.append(_tex(img))
	# Hips
	var hips := _img(16)
	_circle(hips, 8, 8, 3.2, pants)
	slices.append(_tex(hips))
	# Torso with swinging arms at the sides (3 layers)
	for i in 3:
		var img := _img(16)
		_circle(img, 8, 8, 3.6, shirt)
		_circle(img, 8 - swing * 2.0, 3.4, 1.2, shirt)
		_circle(img, 8 + swing * 2.0, 12.6, 1.2, shirt)
		slices.append(_tex(img))
	# Shoulders
	var shoulders := _img(16)
	_circle(shoulders, 8, 8, 3.4, shirt)
	slices.append(_tex(shoulders))
	# Neck
	var neck := _img(16)
	_circle(neck, 8, 8, 1.4, skin)
	slices.append(_tex(neck))
	# Head (3 layers; eyes on the middle one so facing is readable)
	for i in 3:
		var img := _img(16)
		_circle(img, 8, 8, 3.0, skin)
		if i == 1:
			img.set_pixel(10, 6, eye)
			img.set_pixel(10, 10, eye)
		slices.append(_tex(img))
	# Hair (2 layers)
	for i in 2:
		var img := _img(16)
		_circle(img, 8, 8, 2.9 - i * 0.4, hair)
		slices.append(_tex(img))
	return slices


static func _zombie_slices(swing: float) -> Array[ImageTexture]:
	var skin := Color(0.45, 0.62, 0.35)
	var shirt := Color(0.35, 0.37, 0.33)
	var pants := Color(0.18, 0.18, 0.2)
	var eye := Color(0.8, 0.1, 0.1)
	var slices: Array[ImageTexture] = []
	var foot := roundi(swing * 2.0)

	# Bare feet (2 layers)
	for i in 2:
		var img := _img(16)
		_rect(img, 7 + foot, 4, 4, 3, skin)
		_rect(img, 7 - foot, 9, 4, 3, skin)
		slices.append(_tex(img))
	# Legs (3 layers)
	for i in 3:
		var img := _img(16)
		_circle(img, 8 + swing * 1.5, 5.5, 1.6, pants)
		_circle(img, 8 - swing * 1.5, 10.5, 1.6, pants)
		slices.append(_tex(img))
	# Hips
	var hips := _img(16)
	_circle(hips, 8, 8, 3.2, pants)
	slices.append(_tex(hips))
	# Torso (3 layers)
	for i in 3:
		var img := _img(16)
		_circle(img, 8, 8, 3.6, shirt)
		slices.append(_tex(img))
	# Shoulders with arms stretched forward (+X), lurching with the walk
	for i in 2:
		var img := _img(16)
		_circle(img, 8, 8, 3.4, shirt)
		_rect(img, 10 + roundi(swing), 4, 5, 2, skin)
		_rect(img, 10 - roundi(swing), 10, 5, 2, skin)
		slices.append(_tex(img))
	# Neck
	var neck := _img(16)
	_circle(neck, 8, 8, 1.4, skin)
	slices.append(_tex(neck))
	# Head (3 layers, red eyes)
	for i in 3:
		var img := _img(16)
		_circle(img, 8, 8, 3.0, skin)
		if i == 1:
			img.set_pixel(10, 6, eye)
			img.set_pixel(10, 10, eye)
		slices.append(_tex(img))
	return slices


# --- Props --------------------------------------------------------------------


static func _crate() -> Array[ImageTexture]:
	var wood := Color(0.55, 0.38, 0.2)
	var dark := Color(0.38, 0.25, 0.12)
	var slices: Array[ImageTexture] = []
	for i in 8:
		var img := _img(12)
		_rect(img, 2, 2, 8, 8, wood)
		_rect(img, 2, 2, 8, 1, dark)
		_rect(img, 2, 9, 8, 1, dark)
		_rect(img, 2, 2, 1, 8, dark)
		_rect(img, 9, 2, 1, 8, dark)
		if i == 7:
			_rect(img, 2, 5, 8, 1, dark)
			_rect(img, 5, 2, 1, 8, dark)
		slices.append(_tex(img))
	return slices


static func _herb() -> Array[ImageTexture]:
	var stem := Color(0.15, 0.4, 0.18)
	var leaf := Color(0.3, 0.6, 0.28)
	var light := Color(0.45, 0.75, 0.4)
	var berry := Color(0.8, 0.2, 0.25)
	var slices: Array[ImageTexture] = []
	for i in 3:
		var img := _img(12)
		_circle(img, 6, 6, 1.0, stem)
		slices.append(_tex(img))
	var leaves := _img(12)
	_circle(leaves, 6, 4, 1.8, leaf)
	_circle(leaves, 8, 7, 1.8, leaf)
	_circle(leaves, 4, 7, 1.8, leaf)
	slices.append(_tex(leaves))
	var upper := _img(12)
	_circle(upper, 6, 5, 1.4, light)
	_circle(upper, 7, 7, 1.4, light)
	slices.append(_tex(upper))
	var top := _img(12)
	_circle(top, 6, 6, 1.4, light)
	top.set_pixel(7, 6, berry)
	slices.append(_tex(top))
	return slices


## The four cure ingredients, each a recognizable real medicinal plant.
## 0 Chamomile, 1 Lavender, 2 Echinacea, 3 Garlic.
static func _cure_herb(index: int) -> Array[ImageTexture]:
	var stem := Color(0.18, 0.42, 0.2)
	var leaf := Color(0.28, 0.55, 0.26)
	var slices: Array[ImageTexture] = []
	match index:
		0:  # Chamomile: white petals, yellow center
			var petal := Color(0.95, 0.95, 0.88)
			var center := Color(0.95, 0.8, 0.2)
			for i in 3:
				var img := _img(12)
				_circle(img, 6, 6, 0.9, stem)
				slices.append(_tex(img))
			var leaves := _img(12)
			_circle(leaves, 4.5, 5, 1.3, leaf)
			_circle(leaves, 7.5, 7, 1.3, leaf)
			slices.append(_tex(leaves))
			for i in 2:
				var img := _img(12)
				_circle(img, 8.2, 6, 1.3, petal)
				_circle(img, 3.8, 6, 1.3, petal)
				_circle(img, 6, 8.2, 1.3, petal)
				_circle(img, 6, 3.8, 1.3, petal)
				slices.append(_tex(img))
			var top := _img(12)
			_circle(top, 6, 6, 2.2, petal)
			_circle(top, 6, 6, 1.2, center)
			slices.append(_tex(top))
		1:  # Lavender: tall purple flower spike
			var purple := Color(0.55, 0.4, 0.75)
			var light := Color(0.68, 0.52, 0.88)
			for i in 4:
				var img := _img(12)
				_circle(img, 6, 6, 0.9, stem)
				slices.append(_tex(img))
			var leaves := _img(12)
			_circle(leaves, 4.5, 6, 1.2, leaf)
			_circle(leaves, 7.5, 6, 1.2, leaf)
			slices.append(_tex(leaves))
			var spike_r := [1.7, 1.5, 1.1]
			for i in spike_r.size():
				var img := _img(12)
				_circle(img, 6, 6, spike_r[i], light if i > 0 else purple)
				slices.append(_tex(img))
		2:  # Echinacea: pink petals, orange cone center
			var pink := Color(0.85, 0.45, 0.62)
			var cone := Color(0.8, 0.45, 0.15)
			for i in 3:
				var img := _img(12)
				_circle(img, 6, 6, 0.9, stem)
				slices.append(_tex(img))
			var leaves := _img(12)
			_circle(leaves, 4.5, 5, 1.3, leaf)
			_circle(leaves, 7.5, 7, 1.3, leaf)
			slices.append(_tex(leaves))
			for i in 2:
				var img := _img(12)
				_circle(img, 8.1, 7.5, 1.3, pink)
				_circle(img, 3.9, 7.5, 1.3, pink)
				_circle(img, 8.1, 4.5, 1.3, pink)
				_circle(img, 3.9, 4.5, 1.3, pink)
				slices.append(_tex(img))
			var dome := _img(12)
			_circle(dome, 6, 6, 1.4, cone)
			slices.append(_tex(dome))
		3:  # Garlic: pale bulb with a green sprout
			var bulb := Color(0.92, 0.9, 0.82)
			var seam := Color(0.78, 0.75, 0.66)
			var bulb_r := [2.6, 3.0, 2.6, 1.8]
			for i in bulb_r.size():
				var img := _img(12)
				_circle(img, 6, 6, bulb_r[i], bulb)
				if i == 1:
					img.set_pixel(6, 3, seam)
					img.set_pixel(6, 9, seam)
					img.set_pixel(3, 6, seam)
					img.set_pixel(9, 6, seam)
				slices.append(_tex(img))
			var neck := _img(12)
			_circle(neck, 6, 6, 1.0, seam)
			slices.append(_tex(neck))
			for i in 2:
				var img := _img(12)
				_circle(img, 6, 6, 0.9 - i * 0.2, leaf)
				slices.append(_tex(img))
	return slices


static func _wall() -> Array[ImageTexture]:
	var stone := Color(0.46, 0.46, 0.5)
	var dark := Color(0.36, 0.36, 0.4)
	var top := Color(0.55, 0.55, 0.59)
	var slices: Array[ImageTexture] = []
	for i in 10:
		var img := _img(12)
		var fill := top if i == 9 else stone
		_rect(img, 1, 1, 10, 10, fill)
		_rect(img, 1, 1, 10, 1, dark)
		_rect(img, 1, 10, 10, 1, dark)
		_rect(img, 1, 1, 1, 10, dark)
		_rect(img, 10, 1, 1, 10, dark)
		for y in range(2, 10):
			for x in range(2, 10):
				if (x * 31 + y * 17 + i * 13) % 11 == 0:
					img.set_pixel(x, y, dark)
		slices.append(_tex(img))
	return slices


static func _streetlight() -> Array[ImageTexture]:
	var metal := Color(0.35, 0.37, 0.4)
	var lamp := Color(0.95, 0.85, 0.5)
	var slices: Array[ImageTexture] = []
	for i in 12:
		var img := _img(12)
		_circle(img, 6, 6, 0.9, metal)
		slices.append(_tex(img))
	var arm := _img(12)
	_rect(arm, 6, 5, 4, 2, metal)
	slices.append(_tex(arm))
	var light := _img(12)
	_circle(light, 9, 6, 1.6, lamp)
	slices.append(_tex(light))
	return slices


static func _tree() -> Array[ImageTexture]:
	var trunk := Color(0.4, 0.28, 0.16)
	var leaf_dark := Color(0.18, 0.4, 0.18)
	var leaf := Color(0.24, 0.5, 0.22)
	var leaf_light := Color(0.32, 0.6, 0.28)
	var slices: Array[ImageTexture] = []
	for i in 6:
		var img := _img(16)
		_circle(img, 8, 8, 1.3, trunk)
		slices.append(_tex(img))
	var radii := [5.0, 5.5, 4.8, 3.5, 2.2]
	var colors := [leaf_dark, leaf, leaf, leaf_light, leaf_light]
	for i in radii.size():
		var img := _img(16)
		_circle(img, 8, 8, radii[i], colors[i])
		slices.append(_tex(img))
	return slices


## 80's synthwave palette: purples, pinks and teals with sunset accents.
const WALL_COLORS: Array[Color] = [
	Color(0.30, 0.12, 0.36),  # deep purple
	Color(0.54, 0.21, 0.78),  # electric purple
	Color(0.66, 0.14, 0.40),  # magenta
	Color(0.57, 0.33, 0.61),  # mauve
	Color(0.95, 0.72, 0.85),  # pink
	Color(0.80, 0.58, 0.32),  # camel
	Color(0.94, 0.61, 0.22),  # sunset orange
	Color(0.27, 0.59, 0.54),  # teal
	Color(0.36, 0.84, 0.81),  # turquoise
	Color(0.43, 0.18, 0.55),  # violet
	Color(0.76, 0.42, 0.68),  # orchid
	Color(0.49, 0.26, 0.50),  # plum
	Color(0.22, 0.42, 0.45),  # deep teal
	Color(0.84, 0.46, 0.60),  # rose
	Color(0.38, 0.22, 0.48),  # grape
	Color(0.62, 0.49, 0.70),  # lilac
]


## Designs: 0 = plain block, 1 = stepped/tiered tower, 2 = round tower,
## 3 = cross (plus-shaped) footprint. Layer textures repeat (identical ground
## floors, window pattern on a 6-floor cycle), so tall buildings share a
## handful of textures instead of one per layer — far fewer GPU draw batches.
static func _building(w: int, d: int, h: int, color: int, design: int) -> Array[ImageTexture]:
	var wall: Color = WALL_COLORS[color % WALL_COLORS.size()]
	var pal := {
		wall = wall,
		edge = wall.darkened(0.25),
		roof = wall.darkened(0.45),
		win_dark = Color(0.12, 0.07, 0.20),
		win_lit = Color(0.98, 0.62, 0.86),
		door = Color(0.14, 0.08, 0.18),
	}
	design = design % 4
	var slices: Array[ImageTexture] = []
	var layer_cache: Dictionary = {}
	var mask_cache: Dictionary = {}

	# Tier boundaries for the stepped design; unused by the others.
	var t1 := maxi(int(h * 0.55), 4)
	var t2 := maxi(int(h * 0.85), 5)
	var max_inset := maxi((mini(w, d) - 10) / 2, 0)

	for i in h:
		var inset := 0
		if design == 1:
			inset = mini(6 if i >= t2 else (3 if i >= t1 else 0), max_inset)
		var top := i == h - 1 or (design == 1 and (i == t1 - 1 or i == t2 - 1))
		var k := i % 6
		var door := i < 3
		var windows := not top and not door and k % 3 != 0
		var key := "%d_%d_%d_%d_%d" % [k if windows else 0, inset, int(top), int(door), int(i == h - 1)]
		if not layer_cache.has(key):
			if not mask_cache.has(inset):
				mask_cache[inset] = _building_mask(w, d, design, inset)
			layer_cache[key] = _tex(_mask_layer(
				w, d, mask_cache[inset], top, i == h - 1, k, color, pal, door, windows))
		slices.append(layer_cache[key])
	return slices


## Footprint mask for one building layer: 1 = inside the building.
static func _building_mask(w: int, d: int, design: int, inset: int) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(w * d)
	match design:
		2:  # round tower (ellipse)
			var rx := w / 2.0 - 0.5
			var ry := d / 2.0 - 0.5
			for y in d:
				for x in w:
					var nx := (x - rx) / rx
					var ny := (y - ry) / ry
					if nx * nx + ny * ny <= 1.0:
						mask[y * w + x] = 1
		3:  # cross / plus footprint
			var ax := maxi(w / 4, 2)
			var ay := maxi(d / 4, 2)
			for y in d:
				for x in w:
					if (y >= ay and y < d - ay) or (x >= ax and x < w - ax):
						mask[y * w + x] = 1
		_:  # block, optionally inset (stepped tiers)
			for y in range(inset, d - inset):
				for x in range(inset, w - inset):
					mask[y * w + x] = 1
	return mask


## Renders one slice from a footprint mask: darker outline, wall or roof fill,
## optional windows along the perimeter, rooftop AC unit and east-face door.
static func _mask_layer(w: int, d: int, mask: PackedByteArray, top: bool, ac: bool,
		k: int, color: int, pal: Dictionary, door: bool, windows: bool) -> Image:
	var img := _img2(w, d)
	for y in d:
		for x in w:
			if mask[y * w + x] == 0:
				continue
			var on_edge: bool = x == 0 or y == 0 or x == w - 1 or y == d - 1 \
				or mask[y * w + x - 1] == 0 or mask[y * w + x + 1] == 0 \
				or mask[(y - 1) * w + x] == 0 or mask[(y + 1) * w + x] == 0
			if on_edge:
				if windows and (x + y) % 3 == 0:
					img.set_pixel(x, y, pal.win_lit
						if (x * 7 + y * 11 + k * 13 + color * 5) % 5 == 0 else pal.win_dark)
				else:
					img.set_pixel(x, y, pal.edge)
			else:
				img.set_pixel(x, y, pal.roof if top else pal.wall)
	if top and ac:
		_rect(img, roundi(w / 2.0) - 2, roundi(d / 2.0) - 2, 4, 3, Color(0.4, 0.4, 0.44))
	if door:
		for dy in range(-1, 2):
			var yy := clampi(roundi(d / 2.0) + dy, 0, d - 1)
			for x in range(w - 1, -1, -1):
				if mask[yy * w + x] == 1:
					img.set_pixel(x, yy, pal.door)
					break
	return img


static func _car(color_index: int) -> Array[ImageTexture]:
	var bodies: Array[Color] = [
		Color(0.7, 0.15, 0.12),
		Color(0.16, 0.32, 0.58),
		Color(0.82, 0.82, 0.8),
	]
	var body: Color = bodies[color_index % bodies.size()]
	var dark := body.darkened(0.35)
	var tire := Color(0.08, 0.08, 0.09)
	var glass := Color(0.45, 0.6, 0.7)
	var headlight := Color(0.95, 0.9, 0.6)
	var taillight := Color(0.8, 0.1, 0.1)
	var slices: Array[ImageTexture] = []

	var wheels := _img2(20, 12)
	_rect(wheels, 3, 1, 3, 2, tire)
	_rect(wheels, 3, 9, 3, 2, tire)
	_rect(wheels, 14, 1, 3, 2, tire)
	_rect(wheels, 14, 9, 3, 2, tire)
	slices.append(_tex(wheels))

	var lower := _img2(20, 12)
	_rect(lower, 1, 2, 18, 8, body)
	_rect(lower, 1, 2, 1, 8, dark)
	_rect(lower, 18, 2, 1, 8, dark)
	slices.append(_tex(lower))

	var lights := _img2(20, 12)
	_rect(lights, 1, 2, 18, 8, body)
	lights.set_pixel(18, 3, headlight)
	lights.set_pixel(18, 8, headlight)
	lights.set_pixel(1, 3, taillight)
	lights.set_pixel(1, 8, taillight)
	slices.append(_tex(lights))

	var mid := _img2(20, 12)
	_rect(mid, 2, 2, 16, 8, body)
	slices.append(_tex(mid))

	var window_band := _img2(20, 12)
	_rect(window_band, 3, 3, 13, 6, body)
	_rect(window_band, 5, 3, 9, 6, glass)
	slices.append(_tex(window_band))

	var cabin := _img2(20, 12)
	_rect(cabin, 6, 4, 7, 4, glass)
	slices.append(_tex(cabin))

	var roof_img := _img2(20, 12)
	_rect(roof_img, 7, 4, 5, 4, body)
	slices.append(_tex(roof_img))
	return slices


# --- New art API ----------------------------------------------------------------
# Every public function below has a FIXED signature other scripts depend on.


## Rubble pile for a demolished building footprint (canvas w x d pixels).
static func rubble(w: int, d: int) -> Array:
	var key := "rubble_%d_%d" % [w, d]
	if not _cache.has(key):
		_cache[key] = [_rubble(w, d)]
	return _cache[key]


## Flat (single texture) puddle; variant picks one of 4 shapes.
static func puddle_texture(variant: int) -> ImageTexture:
	var v := absi(variant) % 4
	var key := "puddle_%d" % v
	if not _cache.has(key):
		var water := Color(0.24, 0.33, 0.48, 0.62)
		var deep := Color(0.15, 0.22, 0.36, 0.7)
		var rim := Color(0.36, 0.45, 0.58, 0.45)
		var shine := Color(0.8, 0.88, 1.0, 0.8)
		# Each shape is a union of blobs: x, y, radius.
		var shapes := [
			[Vector3(6, 6, 4.2), Vector3(10.5, 5, 3.2), Vector3(4, 8, 2.2)],
			[Vector3(5, 4.5, 3.0), Vector3(9, 6.5, 4.0), Vector3(12.5, 8, 2.0), Vector3(3, 7, 1.6)],
			[Vector3(8, 6, 3.4), Vector3(4.5, 5, 2.6), Vector3(11.5, 6.5, 2.8), Vector3(8, 9, 1.8)],
			[Vector3(7, 7, 3.6), Vector3(10, 4, 2.6), Vector3(12.5, 6.5, 1.6), Vector3(3.5, 5.5, 1.7)],
		]
		var blobs: Array = shapes[v]
		var img := _img2(16, 12)
		# Depth field: how far inside the nearest blob each pixel sits.
		for y in 12:
			for x in 16:
				var depth := -9.0
				for b: Vector3 in blobs:
					depth = maxf(depth, b.z - Vector2(x - b.x, y - b.y).length())
				if depth >= 1.9:
					img.set_pixel(x, y, deep)
				elif depth >= 0.7:
					img.set_pixel(x, y, water)
				elif depth >= 0.0:
					img.set_pixel(x, y, rim)
		# Reflection streaks on the upper-left of the main blob.
		var b0: Vector3 = blobs[0]
		var hx := roundi(b0.x) - 2
		var hy := roundi(b0.y) - 2
		_px(img, hx, hy, shine)
		_px(img, hx + 1, hy, shine)
		_px(img, hx - 1, hy + 1, Color(shine, 0.5))
		var b1: Vector3 = blobs[1]
		_px(img, roundi(b1.x) + 1, roundi(b1.y) + 1, Color(shine, 0.55))
		_cache[key] = _tex(img)
	return _cache[key]


## Flat single shoe print of the infection trail, pointing +X.
## left=true for the left foot.
static func footprint_texture(left: bool) -> ImageTexture:
	var key := "foot_%d" % int(left)
	if not _cache.has(key):
		var rows := PackedStringArray([
			"....tT.",
			"hh.tTTt",
			"Hh.TTt.",
			".......",
		])
		if not left:
			rows.reverse()
		# Gray prints: light fill with a darker gray rim (green read as grass).
		_cache[key] = _tex(_pixmap(rows, {
			"T": Color(0.8, 0.82, 0.88, 0.95),
			"t": Color(0.26, 0.28, 0.32, 0.9),
			"H": Color(0.72, 0.74, 0.8, 0.9),
			"h": Color(0.22, 0.24, 0.28, 0.85),
		}))
	return _cache[key]


## Small flat raindrop streak for rain particles (faint tail, bright tip).
static func raindrop_texture() -> ImageTexture:
	if not _cache.has("raindrop"):
		var img := _img2(1, 6)
		var alphas := [0.12, 0.25, 0.4, 0.6, 0.8, 0.95]
		for y in 6:
			img.set_pixel(0, y, Color(0.72 + y * 0.04, 0.82 + y * 0.03, 1.0, alphas[y]))
		_cache["raindrop"] = _tex(img)
	return _cache["raindrop"]


## Tileable interior floor texture (32x32). style 0 = wood, 1 = tile, 2 = hospital.
static func interior_floor_texture(style: int) -> ImageTexture:
	var st := absi(style) % 3
	var key := "floor_%d" % st
	if not _cache.has(key):
		var img := _img(32)
		match st:
			0:  # Wood planks: 4px boards running along X, staggered end joints
				var woods: Array[Color] = [
					Color(0.5, 0.35, 0.21), Color(0.46, 0.32, 0.19),
					Color(0.54, 0.38, 0.23), Color(0.43, 0.3, 0.18),
				]
				var gap := Color(0.36, 0.25, 0.15)
				for y in 32:
					var row := y / 4
					var joint := (row * 11 + 5) % 16
					for x in 32:
						var board := row * 2 + (1 if (x + 32 - joint) % 32 >= 16 else 0)
						var c: Color = woods[_hash(board, 0, 3) % woods.size()]
						if y % 4 == 3 or x % 16 == joint:
							c = gap
						elif _hash(x / 3, y, 5) % 9 == 0:
							c = c.darkened(0.12)
						elif _hash(x / 4, y, 8) % 13 == 0:
							c = c.lightened(0.08)
						img.set_pixel(x, y, c)
			1:  # Checker tile: 8px cream / teal squares with grout
				var cream := Color(0.82, 0.78, 0.66)
				var teal := Color(0.2, 0.42, 0.44)
				var grout := Color(0.3, 0.3, 0.3)
				for y in 32:
					for x in 32:
						var c := cream if (x / 8 + y / 8) % 2 == 0 else teal
						if x % 8 == 0 or y % 8 == 0:
							c = grout
						elif x % 8 == 1 or y % 8 == 1:
							c = c.lightened(0.1)
						elif _hash(x, y, 4) % 23 == 0:
							c = c.darkened(0.12)
						img.set_pixel(x, y, c)
			_:  # Clean hospital tile: big pale tiles, thin grout, faint specks
				var tile := Color(0.82, 0.87, 0.86)
				var alt := Color(0.74, 0.84, 0.86)
				var grout := Color(0.62, 0.68, 0.69)
				for y in 32:
					for x in 32:
						var c := alt if (x / 16 + y / 16 * 2) % 4 == 3 else tile
						if x % 16 == 0 or y % 16 == 0:
							c = grout
						elif x % 16 == 1 or y % 16 == 1:
							c = c.lightened(0.25)
						elif _hash(x, y, 6) % 29 == 0:
							c = c.darkened(0.06)
						img.set_pixel(x, y, c)
		_cache[key] = _tex(img)
	return _cache[key]


## Small flat HUD icon (12x12) for an inventory item:
## &"bottle", &"tonic", &"charge", &"herb", &"serum".
static func item_icon(item: StringName) -> ImageTexture:
	var key := "item_" + String(item)
	if not _cache.has(key):
		var img: Image
		match item:
			&"bottle":
				img = _pixmap(PackedStringArray([
					"............",
					".....oo.....",
					".....gg.....",
					".....Gg.....",
					"....gGgg....",
					"...gGGgggd..",
					"...gGggggd..",
					"...wwwwwwW..",
					"...wwwwwwW..",
					"...gGggggd..",
					"...ggggggd..",
					"....dddddd..",
				]), {
					"g": Color(0.2, 0.62, 0.3), "G": Color(0.6, 0.92, 0.62),
					"d": Color(0.1, 0.38, 0.2), "w": Color(0.92, 0.9, 0.76),
					"W": Color(0.75, 0.72, 0.58), "o": Color(0.8, 0.7, 0.3),
				})
			&"tonic":
				img = _pixmap(PackedStringArray([
					"............",
					".....cc.....",
					".....cC.....",
					"....wwww....",
					".....gg.....",
					"....gggg....",
					"...bBbbbd...",
					"..bBBbbbbd..",
					"..bBbbbbbd..",
					"..bbbbbbbd..",
					"...bbbbbd...",
					"....dddd....",
				]), {
					"b": Color(0.25, 0.5, 0.95), "B": Color(0.7, 0.88, 1.0),
					"d": Color(0.12, 0.28, 0.65), "w": Color(0.9, 0.95, 1.0),
					"g": Color(0.65, 0.8, 0.95), "c": Color(0.72, 0.52, 0.3),
					"C": Color(0.55, 0.38, 0.2),
				})
			&"charge":
				img = _pixmap(PackedStringArray([
					".......yy...",
					"......y..y..",
					".rR.rR.rR.y.",
					".rR.rR.rR...",
					".rR.rR.rR...",
					"kkkkkkkkkkk.",
					"kkGGGGGkkLk.",
					"kkkkkkkkkkk.",
					".rR.rR.rR...",
					".rR.rR.rR...",
					".rd.rd.rd...",
					"............",
				]), {
					"r": Color(0.78, 0.16, 0.12), "R": Color(0.95, 0.4, 0.3),
					"d": Color(0.5, 0.1, 0.08), "k": Color(0.14, 0.14, 0.17),
					"G": Color(0.4, 1.0, 0.45), "L": Color(1.0, 0.25, 0.2),
					"y": Color(0.95, 0.8, 0.2),
				})
			&"herb":
				img = _pixmap(PackedStringArray([
					"............",
					"......lL....",
					".....lLLl...",
					"..lL..lLl...",
					".lLLl..s.lL.",
					".lLl..s.lLLl",
					"..l.s.s.lLl.",
					"....ss.s.l..",
					".....sss....",
					"......s.....",
					"......s.....",
					".....ss.....",
				]), {
					"l": Color(0.25, 0.55, 0.25), "L": Color(0.48, 0.8, 0.4),
					"s": Color(0.15, 0.4, 0.18),
				})
			&"serum":
				# Diagonal syringe (needle up-right) full of glowing liquid.
				img = _img(12)
				var glow := Color(0.3, 1.0, 0.9, 0.32)
				var liquid := Color(0.45, 1.0, 0.9)
				var glass := Color(0.92, 1.0, 1.0)
				var shade := Color(0.2, 0.7, 0.7)
				var steel := Color(0.72, 0.75, 0.8)
				for y in 12:
					for x in 12:
						var s := x + y
						var t := x - y
						if t >= -4 and t <= 6 and (s == 9 or s == 13):
							img.set_pixel(x, y, glow)
						elif t >= -3 and t <= 5:
							if s == 11:
								img.set_pixel(x, y, liquid)
							elif s == 10:
								img.set_pixel(x, y, glass)
							elif s == 12:
								img.set_pixel(x, y, shade)
						elif s == 11 and (t >= 7 or t <= -5):
							img.set_pixel(x, y, steel)
				_px(img, 0, 9, steel)
				_px(img, 1, 10, steel)
				_px(img, 2, 11, steel)
			_:
				img = _img(12)
				_circle(img, 5.5, 5.5, 4.0, Color(0.8, 0.8, 0.8))
		_cache[key] = _tex(img)
	return _cache[key]


# --- Zombie variants ------------------------------------------------------------


## Runner: lean sprinter in a torn orange tracksuit, hunched forward with
## pumping arms and a long stride.
static func _runner_slices(swing: float) -> Array[ImageTexture]:
	var skin := Color(0.56, 0.7, 0.36)
	var jacket := Color(0.95, 0.45, 0.1)
	var stripe := Color(0.96, 0.93, 0.85)
	var pants := Color(0.12, 0.4, 0.75)
	var shoe := Color(0.9, 0.9, 0.86)
	var band := Color(0.92, 0.2, 0.4)
	var hair := Color(0.2, 0.15, 0.1)
	var eye := Color(0.9, 0.1, 0.1)
	var mouth := Color(0.2, 0.05, 0.05)
	var slices: Array[ImageTexture] = []
	var foot := roundi(swing * 3.0)

	# Sneakers (2 layers), long stride
	var shoes := _img(16)
	_rect(shoes, 6 + foot, 5, 4, 2, shoe)
	_rect(shoes, 6 - foot, 9, 4, 2, shoe)
	_px(shoes, 9 + foot, 5, jacket)
	_px(shoes, 9 - foot, 10, jacket)
	var shoes_tex := _tex(shoes)
	slices.append(shoes_tex)
	slices.append(shoes_tex)
	# Thin legs (3 layers); one trouser leg torn off at the shin
	for i in 3:
		var img := _img(16)
		var f := swing * (2.4 - i * 0.7)
		_circle(img, 7.5 + f, 6.0, 1.2, pants)
		_circle(img, 7.5 - f, 10.0, 1.2, skin if i == 0 else pants)
		_px(img, roundi(7.5 + f), 5, stripe)
		slices.append(_tex(img))
	# Hips
	var hips := _img(16)
	_circle(hips, 8, 8, 2.5, pants)
	slices.append(_tex(hips))
	# Torso (3 layers) leaning further forward as it goes up
	for i in 3:
		var img := _img(16)
		var cx := 8.3 + i * 0.6
		_circle(img, cx, 8, 2.9, jacket)
		_px(img, roundi(cx), 5, stripe)
		_px(img, roundi(cx), 11, stripe)
		if i == 0:  # ragged hem
			_px(img, roundi(cx) - 2, 9, skin)
			_px(img, roundi(cx) + 2, 6, skin)
			_px(img, roundi(cx) - 1, 6, skin)
		slices.append(_tex(img))
	# Shoulders (2 layers) with arms pumping: one reaches ahead, one trails
	var a := roundi(swing * 3.0)
	for i in 2:
		var img := _img(16)
		_ellipse(img, 10.0, 8, 2.4, 3.5, jacket)
		_runner_arm(img, 3, a, jacket, skin)
		_runner_arm(img, 12, -a, jacket, skin)
		_px(img, 10, 4, stripe)
		_px(img, 10, 12, stripe)
		slices.append(_tex(img))
	# Neck, pushed forward
	var neck := _img(16)
	_circle(neck, 11, 8, 1.2, skin)
	slices.append(_tex(neck))
	# Head (3 layers) hunched out in front of the body
	for i in 3:
		var img := _img(16)
		_circle(img, 11.6, 8, 2.6, band if i == 2 else skin)
		if i == 0:
			_px(img, 14, 8, mouth)
		elif i == 1:
			_px(img, 13, 6, eye)
			_px(img, 13, 10, eye)
		else:
			_circle(img, 11.6, 8, 1.9, skin)
		slices.append(_tex(img))
	# Matted hair
	var top := _img(16)
	_circle(top, 11.2, 8, 1.9, hair)
	_px(top, 9, 7, hair)
	_px(top, 9, 9, hair)
	slices.append(_tex(top))
	return slices


## One runner arm on rows y..y+1: reach > 0 claws forward, < 0 trails behind.
static func _runner_arm(img: Image, y: int, reach: int, sleeve: Color, skin: Color) -> void:
	if reach > 0:
		_rect(img, 11, y, 2, 2, sleeve)
		_rect(img, 13, y, 3, 2, skin)
	elif reach == 0:
		_rect(img, 10, y, 2, 2, sleeve)
		_rect(img, 12, y, 2, 2, skin)
	else:
		_rect(img, 7, y, 3, 2, sleeve)
		_rect(img, 5, y, 2, 2, skin)


## Brute: huge and slow on a 22px canvas. Broad shoulders, one thick arm
## reaching, the other hanging dead at its side, head lolling off-centre.
static func _brute_slices(swing: float) -> Array[ImageTexture]:
	var skin := Color(0.42, 0.53, 0.34)
	var skin_dark := Color(0.33, 0.43, 0.28)
	var overalls := Color(0.22, 0.3, 0.5)
	var shirt := Color(0.64, 0.56, 0.38)
	var shirt_dark := Color(0.5, 0.43, 0.3)
	var boots := Color(0.16, 0.13, 0.1)
	var blood := Color(0.42, 0.1, 0.08)
	var eye := Color(0.9, 0.12, 0.1)
	var socket := Color(0.12, 0.1, 0.1)
	var slices: Array[ImageTexture] = []
	var foot := roundi(swing * 2.0)
	var drag := roundi(swing * 1.0)  # the bad leg barely lifts

	# Heavy boots (2 layers)
	var boot_img := _img(22)
	_rect(boot_img, 9 + foot, 5, 6, 4, boots)
	_rect(boot_img, 8 - drag, 13, 6, 4, boots)
	var boot_tex := _tex(boot_img)
	slices.append(boot_tex)
	slices.append(boot_tex)
	# Thick legs (4 layers)
	for i in 4:
		var img := _img(22)
		var f := swing * (1.6 - i * 0.3)
		_circle(img, 11 + f, 7.0, 2.5, overalls)
		_circle(img, 10.5 - f * 0.5, 15.0, 2.5, overalls)
		if i == 1:  # torn knee
			_px(img, roundi(13 + f), 7, skin)
			_px(img, roundi(13 + f), 8, skin)
		slices.append(_tex(img))
	# Hips
	var hips := _img(22)
	_ellipse(hips, 11, 11, 4.6, 6.0, overalls)
	slices.append(_tex(hips))
	# Belly (2 layers): overalls bib; the dead arm's hand hangs down here
	for i in 2:
		var img := _img(22)
		_ellipse(img, 11.5, 11, 5.4, 6.4, overalls)
		_circle(img, 9.5 - swing * 0.6, 19.6, 1.5, skin_dark if i == 0 else skin)
		slices.append(_tex(img))
	# Chest (3 layers): filthy shirt, bib on the front, limp upper arm
	for i in 3:
		var img := _img(22)
		_ellipse(img, 11, 11, 5.2, 6.8, shirt)
		_rect(img, 13, 8, 4, 7, overalls)
		_circle(img, 10.0 - swing * 0.3, 19.4, 1.9, shirt_dark if i < 2 else shirt)
		if i == 1:
			_px(img, 15, 15, blood)
			_px(img, 14, 16, blood)
			_px(img, 9, 5, shirt_dark)
			_px(img, 7, 14, shirt_dark)
		slices.append(_tex(img))
	# Shoulders (2 layers): very wide, straps, one massive arm clawing forward
	var reach := roundi(swing * 1.5)
	for i in 2:
		var img := _img(22)
		_ellipse(img, 10.5, 11, 4.4, 8.8, shirt)
		_rect(img, 7, 8, 8, 1, overalls)
		_rect(img, 7, 14, 8, 1, overalls)
		_rect(img, 12, 2, 3, 3, shirt)
		_rect(img, 14 + reach, 2, 6, 3, skin)
		_rect(img, 19 + reach, 2, 2, 1, skin_dark)
		_rect(img, 19 + reach, 4, 2, 1, skin_dark)
		_circle(img, 10.5, 19.4, 1.9, shirt)
		if i == 1:
			_px(img, 8, 4, blood)
			_px(img, 9, 5, blood)
			_px(img, 8, 17, shirt_dark)
		slices.append(_tex(img))
	# Neck
	var neck := _img(22)
	_circle(neck, 11.5, 11.6, 2.2, skin)
	slices.append(_tex(neck))
	# Head (3 layers): small for the body, tilted toward the dead arm,
	# heavy jaw, one working eye
	for i in 3:
		var img := _img(22)
		if i == 0:
			_circle(img, 12.8, 12.2, 3.2, skin)
			_px(img, 15, 12, socket)
			_px(img, 15, 13, socket)
		else:
			_circle(img, 12.2, 12.2, 3.2, skin)
		if i == 1:
			_px(img, 14, 10, eye)
			_px(img, 14, 14, socket)
		if i == 2:  # bald, scarred scalp
			_px(img, 11, 11, skin_dark)
			_px(img, 12, 12, skin_dark)
			_px(img, 12, 13, skin_dark)
			_px(img, 10, 14, blood)
		slices.append(_tex(img))
	return slices


## Screamer: tall, gaunt and pale in a stained gown, long dangling arms,
## gaping mouth and wild hair. scream=true throws the arms up and the head back.
static func _screamer_slices(swing: float, scream: bool) -> Array[ImageTexture]:
	var skin := Color(0.8, 0.85, 0.72)
	var skin_dark := Color(0.62, 0.7, 0.58)
	var gown := Color(0.68, 0.66, 0.8)
	var gown_dark := Color(0.52, 0.5, 0.66)
	var stain := Color(0.45, 0.14, 0.14)
	var hair := Color(0.1, 0.08, 0.12)
	var mouth := Color(0.12, 0.02, 0.05)
	var eye := Color(0.75, 0.08, 0.1)
	var slices: Array[ImageTexture] = []
	var foot := roundi(swing * 1.4)
	var sw := roundi(swing)

	# Bare feet (2 layers), short shuffle
	var feet := _img(16)
	_rect(feet, 7 + foot, 5, 3, 2, skin_dark)
	_rect(feet, 7 - foot, 9, 3, 2, skin_dark)
	var feet_tex := _tex(feet)
	slices.append(feet_tex)
	slices.append(feet_tex)
	# Stick legs (5 layers); the long arm's hand dangles to the knee
	for i in 5:
		var img := _img(16)
		var f := swing * (1.0 - i * 0.2)
		if i < 3:
			_rect(img, roundi(7.5 + f), 6, 2, 1, skin)
			_rect(img, roundi(7.5 - f), 9, 2, 1, skin)
		else:
			_circle(img, 8.0 + f, 6.0, 1.3, gown_dark)
			_circle(img, 8.0 - f, 10.0, 1.3, gown_dark)
		if not scream and i >= 2:
			_px(img, 8 - sw, 3, skin_dark if i == 2 else skin)
			if i == 2:
				_px(img, 9 - sw, 3, skin_dark)
		slices.append(_tex(img))
	# Hips
	var hips := _img(16)
	_ellipse(hips, 8, 8, 2.0, 2.6, gown_dark)
	if not scream:
		_px(hips, 8, 3, skin)
	slices.append(_tex(hips))
	# Narrow torso (4 layers). One arm hangs straight, the other is crooked
	# with the forearm twitching out in front.
	for i in 4:
		var img := _img(16)
		_ellipse(img, 8.0 + i * 0.15, 8, 2.2, 2.8, gown)
		if i == 1:
			_px(img, 10, 7, stain)
			_px(img, 10, 8, stain)
			_px(img, 9, 9, stain)
		if not scream:
			_px(img, 8, 4 if i == 3 else 3, skin)
			if i == 0:
				_rect(img, 9 + sw, 12, 3, 1, skin)
				_px(img, 12 + sw, 11, skin_dark)
				_px(img, 12 + sw, 13, skin_dark)
			elif i == 1:
				_rect(img, 8, 12, 2, 1, skin)
			else:
				_px(img, 8, 12, skin)
		slices.append(_tex(img))
	# Bony shoulders (2 layers)
	for i in 2:
		var img := _img(16)
		_ellipse(img, 8, 8, 1.9, 3.7, gown)
		if scream:
			_rect(img, 8, 3 - i, 1, 2, skin)
			_rect(img, 8, 12 + i, 1, 2, skin)
		else:
			_px(img, 8, 4, skin)
			_px(img, 8, 12, skin)
		slices.append(_tex(img))
	# Long neck (2 layers)
	var hx := 7.0 if scream else 8.7
	var hy := 8.0 if scream else 8.6
	for i in 2:
		var img := _img(16)
		_circle(img, 8.0 if not scream else 7.6, 8, 1.0, skin)
		if scream:
			_rect(img, 8 + i, 1, 2, 1, skin)
			_rect(img, 8 + i, 14, 2, 1, skin)
		slices.append(_tex(img))
	# Head (3 layers): tilted; mouth hangs open. Screaming, the head tips
	# back so the face (and wide mouth) points up at the camera.
	for i in 3:
		var img := _img(16)
		_circle(img, hx, hy, 2.7, skin)
		var fx := roundi(hx) + 2
		var fy := roundi(hy)
		if scream:
			_px(img, 10, 0 if i > 0 else 1, skin)
			_px(img, 10, 15 if i > 0 else 14, skin)
			if i > 0:
				_px(img, 10, 1, skin)
				_px(img, 10, 14, skin)
			if i == 2:
				_rect(img, 10, 0, 2, 2, skin)
				_rect(img, 10, 14, 2, 2, skin)
				_rect(img, fx - 2, fy - 1, 2, 3, mouth)
				_px(img, fx - 4, fy - 2, eye)
				_px(img, fx - 4, fy + 2, eye)
			else:
				_px(img, fx, fy, mouth)
		else:
			if i < 2:
				_px(img, fx, fy, mouth)
				_px(img, fx, fy - 1, mouth)
			if i == 0:
				_px(img, fx - 1, fy, mouth)
			if i == 2:
				_px(img, fx, fy - 2, eye)
				_px(img, fx, fy + 1, eye)
		slices.append(_tex(img))
	# Wild hair (3 layers): ragged spikes, swept back off the face
	for i in 3:
		var img := _img(16)
		if scream:
			if i == 0:
				_px(img, 11, 0, skin_dark)
				_px(img, 12, 1, skin_dark)
				_px(img, 11, 15, skin_dark)
				_px(img, 12, 14, skin_dark)
			_wild_hair(img, hx - 2.2, hy, 2.0 - i * 0.5, 9 - i * 2, 31 + i, hair, true)
		else:
			_wild_hair(img, hx - 0.9, hy, 2.5 - i * 0.6, 11 - i * 3, 17 + i, hair, true)
		slices.append(_tex(img))
	return slices


## Blob of hair with hash-jittered spikes. back_only skips spikes that would
## point toward +X (over the face).
static func _wild_hair(img: Image, cx: float, cy: float, r: float, spikes: int,
		sd: int, c: Color, back_only: bool) -> void:
	_circle(img, cx, cy, r, c)
	for k in spikes:
		var ang := TAU * k / spikes + (_hash(k, 1, sd) % 10) * 0.05
		if back_only and cos(ang) > 0.35:
			continue
		var length := r + 0.8 + (_hash(k, 2, sd) % 3) * 0.7
		var t := 0.0
		while t <= length:
			_px(img, roundi(cx + cos(ang) * t), roundi(cy + sin(ang) * t), c)
			t += 0.5


## Player shove animation. phase 0 = wind-up (fists pulled back to the chest),
## 1 = push (both arms locked out toward +X), 2 = recover. Same canvas and
## slice count as _player_slices.
static func _player_shove_slices(phase: int) -> Array[ImageTexture]:
	var skin := Color(0.87, 0.68, 0.55)
	var hair := Color(0.3, 0.2, 0.12)
	var shirt := Color(0.75, 0.2, 0.2)
	var pants := Color(0.22, 0.28, 0.5)
	var boots := Color(0.25, 0.18, 0.12)
	var eye := Color(0.12, 0.12, 0.15)
	var slices: Array[ImageTexture] = []
	var lean: float = [-0.7, 1.2, 0.4][phase]
	var foot: int = [0, 2, 1][phase]

	# Boots (2 layers): front foot plants forward on the push
	var boot_img := _img(16)
	_rect(boot_img, 7 + foot, 4, 4, 3, boots)
	_rect(boot_img, 7 - foot / 2, 9, 4, 3, boots)
	var boot_tex := _tex(boot_img)
	slices.append(boot_tex)
	slices.append(boot_tex)
	# Legs (3 layers)
	for i in 3:
		var img := _img(16)
		_circle(img, 8 + foot * (0.75 - i * 0.2), 5.5, 1.6, pants)
		_circle(img, 8 - foot * 0.25, 10.5, 1.6, pants)
		slices.append(_tex(img))
	# Hips
	var hips := _img(16)
	_circle(hips, 8, 8, 3.2, pants)
	slices.append(_tex(hips))
	# Torso (3 layers) with the arms
	for i in 3:
		var img := _img(16)
		_circle(img, 8 + lean * (0.3 + i * 0.25), 8, 3.6, shirt)
		_shove_arms(img, phase, i >= 1, shirt, skin)
		slices.append(_tex(img))
	# Shoulders
	var shoulders := _img(16)
	_circle(shoulders, 8 + lean, 8, 3.4, shirt)
	_shove_arms(shoulders, phase, phase != 0, shirt, skin)
	slices.append(_tex(shoulders))
	# Neck
	var neck := _img(16)
	_circle(neck, 8 + lean, 8, 1.4, skin)
	slices.append(_tex(neck))
	# Head (3 layers)
	var hx := roundi(8 + lean)
	for i in 3:
		var img := _img(16)
		_circle(img, hx, 8, 3.0, skin)
		if i == 1:
			_px(img, hx + 2, 6, eye)
			_px(img, hx + 2, 10, eye)
		slices.append(_tex(img))
	# Hair (2 layers)
	for i in 2:
		var img := _img(16)
		_circle(img, hx, 8, 2.9 - i * 0.4, hair)
		slices.append(_tex(img))
	return slices


static func _shove_arms(img: Image, phase: int, raised: bool, shirt: Color, skin: Color) -> void:
	for y: int in [3, 12]:
		match phase:
			0:  # elbows back, fists by the chest
				_rect(img, 4, y, 4, 2, shirt)
				if raised:
					_rect(img, 8, y, 1, 2, skin)
			1:  # locked out
				if raised:
					_rect(img, 9, y, 4, 2, shirt)
					_rect(img, 13, y, 3, 2, skin)
			_:  # half-way back
				if raised:
					_rect(img, 8, y, 3, 2, shirt)
					_rect(img, 11, y, 2, 2, skin)
				else:
					_rect(img, 7, y, 2, 2, shirt)


# --- New props ------------------------------------------------------------------


## Payphone on a post. The handset hangs on the +Y side so it shows from the
## camera; ringing knocks it off the hook and lights the lamp + sign.
static func _payphone(ringing: bool) -> Array[ImageTexture]:
	var metal := Color(0.42, 0.44, 0.48)
	var dark := Color(0.2, 0.2, 0.24)
	var blue := Color(0.15, 0.35, 0.72)
	var blue_dark := Color(0.1, 0.24, 0.52)
	var blue_light := Color(0.32, 0.52, 0.88)
	var silver := Color(0.76, 0.78, 0.82)
	var keys := Color(0.2, 0.2, 0.22)
	var handset := Color(0.06, 0.06, 0.08)
	var cord := Color(0.3, 0.3, 0.33)
	var lamp := Color(1.0, 0.85, 0.2) if ringing else Color(0.4, 0.12, 0.1)
	var sign_c := Color(1.0, 0.95, 0.55) if ringing else Color(0.9, 0.92, 0.95)
	var slices: Array[ImageTexture] = []

	var base := _img(10)
	_rect(base, 3, 3, 4, 4, dark)
	slices.append(_tex(base))
	var post := _img(10)
	_rect(post, 4, 4, 2, 2, metal)
	var post_tex := _tex(post)
	for i in 7:
		if ringing and i >= 5:  # handset swinging on its cord below the box
			var img := _img(10)
			_rect(img, 4, 4, 2, 2, metal)
			_px(img, 6, 8, cord if i == 6 else handset)
			_px(img, 7, 8, handset)
			slices.append(_tex(img))
		else:
			slices.append(post_tex)
	# Phone box (5 layers): steel face on +X, handset cradle on +Y
	for i in 5:
		var img := _img(10)
		_rect(img, 2, 2, 6, 6, blue)
		_rect(img, 2, 2, 6, 1, blue_dark)
		_rect(img, 2, 2, 1, 6, blue_dark)
		_rect(img, 7, 3, 1, 4, silver)
		if i == 1 or i == 2:
			_px(img, 7, 4, keys)
			_px(img, 7, 5, keys)
		if i == 3:
			_px(img, 7, 3, keys)  # coin slot
		# +Y side face
		_px(img, 2, 7, blue_dark)
		_px(img, 7, 7, silver)
		if ringing:
			if i == 0:
				_px(img, 6, 8, cord)
			if i == 3:
				_px(img, 4, 7, dark)  # empty hook
				_px(img, 3, 7, lamp)
		else:
			if i >= 1 and i <= 3:
				_rect(img, 4, 7, 2, 1, handset)
				_px(img, 4 if i != 2 else 5, 8, handset)
		slices.append(_tex(img))
	# Hood
	var hood := _img(10)
	_rect(hood, 1, 1, 8, 8, blue_dark)
	_rect(hood, 2, 8, 6, 1, sign_c)
	slices.append(_tex(hood))
	var top := _img(10)
	_rect(top, 1, 1, 8, 8, blue_light)
	_rect(top, 1, 1, 8, 1, blue)
	_rect(top, 1, 8, 8, 1, blue)
	_rect(top, 1, 1, 1, 8, blue)
	_rect(top, 8, 1, 1, 8, blue)
	_rect(top, 3, 4, 4, 2, sign_c)
	_px(top, 7, 2, lamp)
	if ringing:
		_px(top, 7, 3, Color(1.0, 0.6, 0.15))
		_px(top, 6, 2, Color(1.0, 0.6, 0.15))
	slices.append(_tex(top))
	if ringing:  # lamp glow standing proud of the hood
		var glow := _img(10)
		_px(glow, 7, 2, Color(1.0, 0.95, 0.6))
		slices.append(_tex(glow))
	else:
		var cap := _img(10)
		_px(cap, 7, 2, lamp)
		slices.append(_tex(cap))
	return slices


## Short wall segment with a door, 20x6 canvas, 20 slices tall. Placed
## unrotated, so the south (+Y) row of every slice is the visible face: the
## slices together paint a 20x20 front elevation. kind 0 = clean painted door,
## 1 = dilapidated boarded door, 2 = mossy stone ruin arch.
static func _door(kind: int) -> Array[ImageTexture]:
	var slices: Array[ImageTexture] = []
	var top_colors: Array[Color] = [
		Color(0.72, 0.68, 0.62), Color(0.26, 0.22, 0.2), Color(0.56, 0.56, 0.52)]
	var top_c: Color = top_colors[kind]
	for i in 20:
		var img := _img2(20, 6)
		for x in 20:
			if kind == 2 and _ruin_gone(x, i):
				continue
			var opening := x >= 6 and x <= 13 and i < _door_opening_height(kind, x)
			var face := _door_face(kind, x, i)
			if opening and i > 0:
				# Recessed leaf: one pixel back from the wall face.
				var back := face.darkened(0.55)
				for y in 4:
					img.set_pixel(x, y, back)
				img.set_pixel(x, 4, face)
			else:
				var cap := top_c
				if kind == 2 and _hash(x, i, 21) % 3 == 0:
					cap = Color(0.3, 0.48, 0.22)
				elif _hash(x, i, 22) % 5 == 0:
					cap = cap.darkened(0.1)
				for y in 5:
					img.set_pixel(x, y, cap)
				img.set_pixel(x, 0, cap.darkened(0.25))
				img.set_pixel(x, 5, face)
		slices.append(_tex(img))
	return slices


static func _door_opening_height(kind: int, x: int) -> int:
	if kind != 2:
		return 16
	if x == 6 or x == 13:
		return 12
	if x == 7 or x == 12:
		return 14
	return 15


## Crumbled-away parts of the ruin's top courses.
static func _ruin_gone(x: int, h: int) -> bool:
	if h < 17:
		return false
	var notch := _hash(x / 2, 0, 77) % 5
	if x >= 8 and x <= 11:
		notch = 4  # keep the keystone standing
	return (h == 19 and notch < 3) or (h == 18 and notch < 2) or (h == 17 and notch < 1)


## Front-elevation colour of a door segment at column x, height h (0 = ground).
static func _door_face(kind: int, x: int, h: int) -> Color:
	var in_door := x >= 6 and x <= 13 and h < _door_opening_height(kind, x)
	match kind:
		0:
			var brick := Color(0.66, 0.33, 0.24)
			var mortar := Color(0.8, 0.74, 0.66)
			var trim := Color(0.94, 0.94, 0.9)
			var paint := Color(0.1, 0.5, 0.62)
			if in_door:
				if h == 0:
					return Color(0.6, 0.6, 0.58)  # stone step
				if x == 12 and h == 7:
					return Color(0.98, 0.82, 0.25)  # brass knob
				if x == 12 and h == 8:
					return Color(1.0, 1.0, 0.85)  # ...catching the light
				if h >= 12 and h <= 14 and x >= 8 and x <= 11:
					return Color(0.95, 0.98, 1.0) if (x == 8 and h == 14) or (x == 9 and h == 13) \
						else Color(0.55, 0.78, 0.92)
				if h == 1:
					return Color(0.8, 0.68, 0.3)  # kick plate
				var panel := (x >= 7 and x <= 9) or (x >= 10 and x <= 12)
				if panel and ((h >= 3 and h <= 5) or (h >= 9 and h <= 10)) and x != 12:
					return paint.darkened(0.22)
				if x == 6:
					return paint.lightened(0.18)
				return paint
			if (x == 5 or x == 14) and h <= 16:
				return trim
			if h == 16 and x >= 5 and x <= 14:
				return trim
			if h == 18 and (x == 9 or x == 10):
				return Color(1.0, 0.92, 0.55)  # porch lamp
			if h == 19 and (x == 9 or x == 10):
				return Color(0.2, 0.2, 0.22)
			if h == 19:
				return mortar.darkened(0.1)
			if h % 3 == 2 or (x + (h / 3) % 2 * 2) % 4 == 0:
				return mortar
			return brick.darkened(0.08) if _hash(x / 4, h / 3, 2) % 4 == 0 else brick
		1:
			var brick := Color(0.36, 0.24, 0.2)
			var mortar := Color(0.27, 0.24, 0.22)
			var paint := Color(0.36, 0.44, 0.32)
			var wood := Color(0.42, 0.3, 0.19)
			var plank := Color(0.62, 0.48, 0.3)
			var nail := Color(0.15, 0.13, 0.12)
			if in_door:
				if h == 0:
					return Color(0.3, 0.29, 0.27)
				# Two boards nailed across at careless angles
				var b1 := 10 + (x - 6) / 3
				var b2 := 5 - (x - 6) / 4
				if h == b1 or h == b1 + 1 or h == b2 or h == b2 + 1:
					if (x == 6 or x == 13) and (h == b1 or h == b2):
						return nail
					return plank.darkened(0.15) if (h == b1 or h == b2) else plank
				if h <= 2 and x <= 7:
					return Color(0.05, 0.04, 0.04)  # kicked-in corner
				if x == 12 and h == 7:
					return Color(0.5, 0.27, 0.12)  # rusted knob
				if h >= 13 and x >= 8 and x <= 11:
					return Color(0.08, 0.08, 0.1) if (x + h) % 3 != 0 else Color(0.3, 0.34, 0.36)
				var r := _hash(x, h, 11) % 7
				if r == 0 or _hash(x / 2, h / 3, 12) % 4 == 0:
					return wood if r % 2 == 0 else wood.darkened(0.2)
				return paint.darkened(0.15) if r == 1 else paint
			if (x == 5 or x == 14) and h <= 16:
				return wood.darkened(0.3)
			if h == 16 and x >= 5 and x <= 14:
				return wood.darkened(0.2)
			# Graffiti scrawl
			if (x == 16 and h >= 8 and h <= 11) or (x == 17 and (h == 11 or h == 9)) \
					or (x == 18 and h >= 8 and h <= 10):
				return Color(0.9, 0.3, 0.6)
			if x >= 1 and x <= 3 and h == 13 - x:
				return Color(0.3, 0.8, 0.8)
			var c := brick
			if h % 3 == 2 or (x + (h / 3) % 2 * 2) % 4 == 0:
				c = mortar
			if h < 3:
				c = c.darkened(0.35 - h * 0.1)  # grime at street level
			if _hash(x / 3, 0, 13) % 3 == 0 and h > 19 - 2 - _hash(x / 3, 1, 13) % 7:
				c = c.darkened(0.3)  # water streaks from the roofline
			elif _hash(x, h, 14) % 6 == 0:
				c = c.darkened(0.15)
			return c
		_:
			var stone := Color(0.52, 0.52, 0.48)
			var joint := Color(0.32, 0.32, 0.3)
			var moss := Color(0.3, 0.5, 0.22)
			var moss_light := Color(0.42, 0.62, 0.28)
			if in_door:
				# Sealed double stone door in the archway
				var slab := Color(0.24, 0.25, 0.27)
				if h == 0:
					return stone.darkened(0.2)
				if x == 9 and h < 14:
					return Color(0.06, 0.06, 0.08)  # seam
				if (x == 8 or x == 11) and (h == 7 or h == 8):
					return Color(0.55, 0.45, 0.25)  # bronze rings
				if (x == 10 and h == 11) or (x == 11 and h == 10) or (x == 11 and h == 9) \
						or (x == 12 and h == 8):
					return Color(0.08, 0.08, 0.1)  # crack
				if h <= 2 and _hash(x, h, 31) % 2 == 0:
					return moss
				if h == 5 or h == 11:
					return slab.lightened(0.12)
				return slab.darkened(0.12) if _hash(x, h, 32) % 5 == 0 else slab
			# Arch ring of paler stones just outside the opening
			var ring := x >= 5 and x <= 14 and h <= 16 \
				and h < _door_opening_height(2, clampi(x, 6, 13)) + 2 \
				and (x < 6 or x > 13 or h >= _door_opening_height(2, x))
			if x >= 9 and x <= 10 and (h == 16 or h == 17):
				return Color(0.45, 0.92, 0.82) if (x == 9 and h == 16) else Color(0.7, 0.69, 0.62)
			# Cracks running down the wall
			if (x == 2 and h >= 15) or (x == 3 and h >= 11 and h <= 15) or (x == 4 and h == 11) \
					or (x == 17 and h >= 4 and h <= 9) or (x == 16 and h >= 9 and h <= 12) \
					or (x == 18 and h <= 4 and h >= 2):
				return Color(0.12, 0.12, 0.12)
			var m := _hash(x / 2, h / 2, 33) % 6
			if (h < 4 or h > 15) and m <= 1:
				return moss if _hash(x, h, 34) % 2 == 0 else moss_light
			if m == 0:
				return moss
			if ring:
				return Color(0.66, 0.65, 0.58) if (x + h) % 3 != 0 else Color(0.5, 0.5, 0.45)
			if h % 4 == 3 or (x + (h / 4) % 2 * 3) % 6 == 0:
				return joint
			return stone.darkened(0.1) if _hash(x / 6, h / 4, 35) % 3 == 0 else stone
	return Color.MAGENTA


## Green glass bottle standing upright.
static func _bottle() -> Array[ImageTexture]:
	var glass := Color(0.2, 0.62, 0.3)
	var dark := Color(0.12, 0.42, 0.22)
	var shine := Color(0.62, 0.92, 0.62)
	var label := Color(0.92, 0.9, 0.76)
	var cap := Color(0.8, 0.7, 0.3)
	var slices: Array[ImageTexture] = []
	for i in 5:
		var img := _img(8)
		_circle(img, 3.5, 3.5, 1.6, dark if i == 0 else glass)
		if i == 2 or i == 3:
			_rect(img, 2, 5, 3, 1, label)
			_px(img, 5, 4, label)
		_px(img, 2, 3, shine)
		slices.append(_tex(img))
	var shoulder := _img(8)
	_rect(shoulder, 3, 3, 2, 2, glass)
	_px(shoulder, 3, 3, shine)
	_px(shoulder, 2, 3, glass)
	_px(shoulder, 3, 2, glass)
	slices.append(_tex(shoulder))
	var neck := _img(8)
	_rect(neck, 3, 3, 2, 2, glass)
	_px(neck, 3, 3, shine)
	var neck_tex := _tex(neck)
	slices.append(neck_tex)
	slices.append(neck_tex)
	var top := _img(8)
	_rect(top, 3, 3, 2, 2, cap)
	slices.append(_tex(top))
	return slices


## Blue stamina tonic: a stubby vial with a cork.
static func _tonic() -> Array[ImageTexture]:
	var liquid := Color(0.25, 0.5, 0.95)
	var dark := Color(0.14, 0.3, 0.7)
	var shine := Color(0.75, 0.9, 1.0)
	var glass := Color(0.7, 0.84, 0.96)
	var cork := Color(0.72, 0.52, 0.3)
	var cork_dark := Color(0.55, 0.38, 0.2)
	var slices: Array[ImageTexture] = []
	var radii := [1.6, 2.2, 2.2, 1.6]
	for i in radii.size():
		var img := _img(8)
		_circle(img, 3.5, 3.5, radii[i], dark if i == 0 else liquid)
		_px(img, 2, 3, shine)
		if i == 2:
			_px(img, 2, 2, shine)
		slices.append(_tex(img))
	var rim := _img(8)
	_circle(rim, 3.5, 3.5, 1.6, glass)
	_rect(rim, 3, 3, 2, 2, liquid)
	slices.append(_tex(rim))
	var neck := _img(8)
	_rect(neck, 3, 3, 2, 2, glass)
	slices.append(_tex(neck))
	var lip := _img(8)
	_circle(lip, 3.5, 3.5, 1.6, glass)
	_rect(lip, 3, 3, 2, 2, cork_dark)
	slices.append(_tex(lip))
	var stopper := _img(8)
	_rect(stopper, 3, 3, 2, 2, cork)
	slices.append(_tex(stopper))
	return slices


## Demolition charge: three taped dynamite sticks with a timer on top.
static func _charge() -> Array[ImageTexture]:
	var red := Color(0.8, 0.17, 0.13)
	var red_dark := Color(0.55, 0.1, 0.08)
	var red_light := Color(0.95, 0.4, 0.3)
	var tape := Color(0.12, 0.12, 0.14)
	var box := Color(0.2, 0.2, 0.24)
	var wire := Color(0.95, 0.8, 0.2)
	var slices: Array[ImageTexture] = []
	var lower := _img(10)
	_rect(lower, 1, 2, 8, 6, red_dark)
	_rect(lower, 3, 2, 1, 6, tape)
	_rect(lower, 6, 2, 1, 6, tape)
	slices.append(_tex(lower))
	var mid := _img(10)
	_rect(mid, 1, 2, 8, 6, red)
	_rect(mid, 3, 2, 1, 6, tape)
	_rect(mid, 6, 2, 1, 6, tape)
	_rect(mid, 8, 2, 1, 6, Color(0.75, 0.65, 0.45))  # stick ends
	slices.append(_tex(mid))
	var upper := _img(10)
	for s in 3:
		_rect(upper, 1, 2 + s * 2, 8, 2, red)
		_rect(upper, 1, 2 + s * 2, 8, 1, red_light)
	_rect(upper, 3, 2, 1, 6, tape)
	_rect(upper, 6, 2, 1, 6, tape)
	slices.append(_tex(upper))
	var timer := _img(10)
	_rect(timer, 3, 3, 4, 4, box)
	_px(timer, 7, 5, wire)
	_px(timer, 8, 6, wire)
	_px(timer, 2, 3, wire)
	slices.append(_tex(timer))
	var face := _img(10)
	_rect(face, 3, 3, 4, 4, box.lightened(0.12))
	_rect(face, 4, 4, 2, 1, Color(0.4, 1.0, 0.45))
	_px(face, 5, 5, Color(1.0, 0.25, 0.2))
	_rect(face, 3, 6, 4, 1, tape)
	slices.append(_tex(face))
	return slices


## The crate after it has been smashed open: hollow, splintered rim, one
## plank fallen across the top. Same footprint as _crate.
static func _crate_open() -> Array[ImageTexture]:
	var wood := Color(0.55, 0.38, 0.2)
	var dark := Color(0.38, 0.25, 0.12)
	var inside := Color(0.2, 0.13, 0.07)
	var pale := Color(0.72, 0.56, 0.35)  # fresh splintered wood
	var slices: Array[ImageTexture] = []
	for i in 8:
		var img := _img(12)
		if i == 0:
			_rect(img, 2, 2, 8, 8, inside)
			_px(img, 4, 6, dark)
			_px(img, 7, 4, dark)
			_px(img, 6, 7, pale)
		for p in 28:  # walk the 8x8 perimeter
			var x := 2
			var y := 2
			if p < 8:
				x = 2 + p
			elif p < 15:
				x = 9
				y = 3 + (p - 8)
			elif p < 22:
				x = 8 - (p - 15)
				y = 9
			else:
				y = 8 - (p - 22)
			var corner := (x == 2 or x == 9) and (y == 2 or y == 9)
			var wall_h := 5 + _hash(p / 2, 0, 41) % 3
			if corner:
				wall_h = 8 if y == 2 else 5 + (x % 2)
			elif y == 9:
				wall_h = 2 + _hash(p / 2, 0, 42) % 2  # front boards smashed in
			elif y > 5:
				wall_h = mini(wall_h, 5)
			if i < wall_h:
				var c := dark if corner or y == 2 or y == 9 else wood
				if i == wall_h - 1 and not corner:
					c = pale
				img.set_pixel(x, y, c)
		if i == 1:  # broken lid plank lying inside, tipped against the wall
			_rect(img, 3, 6, 4, 2, wood)
			_px(img, 3, 6, pale)
		if i == 2:
			_rect(img, 5, 5, 4, 2, wood)
			_px(img, 5, 5, dark)
		slices.append(_tex(img))
	return slices


## Street-corner sign: pole with two crossed green name plates.
static func _street_sign() -> Array[ImageTexture]:
	var metal := Color(0.4, 0.42, 0.45)
	var green := Color(0.1, 0.5, 0.25)
	var green_dark := Color(0.06, 0.36, 0.18)
	var white := Color(0.95, 0.96, 0.92)
	var slices: Array[ImageTexture] = []
	var pole := _img(12)
	_rect(pole, 5, 5, 2, 2, metal)
	_px(pole, 5, 5, metal.lightened(0.2))
	var pole_tex := _tex(pole)
	var base := _img(12)
	_rect(base, 4, 4, 4, 4, metal.darkened(0.3))
	slices.append(_tex(base))
	for i in 13:
		slices.append(pole_tex)
	# Plate along X; lettering shows on its south edge and top
	for i in 3:
		var img := _img(12)
		_rect(img, 0, 5, 12, 2, green)
		_rect(img, 0, 5, 12, 1, green_dark)
		if i == 1:
			for x: int in [2, 3, 5, 6, 7, 9]:
				_px(img, x, 6, white)
		else:
			_px(img, 0, 6, white)
			_px(img, 11, 6, white)
		slices.append(_tex(img))
	# Plate along Y on top
	for i in 3:
		var img := _img(12)
		_rect(img, 5, 0, 2, 12, green if i < 2 else Color(0.16, 0.6, 0.32))
		if i == 2:
			_rect(img, 5, 0, 2, 1, white)
			_rect(img, 5, 11, 2, 1, white)
			for y: int in [2, 3, 5, 8, 9]:
				_px(img, 5, y, white)
		else:
			_px(img, 5, 11, white)
			_px(img, 6, 11, green_dark if i == 0 else white)
		slices.append(_tex(img))
	var cap := _img(12)
	_rect(cap, 5, 5, 2, 2, metal.lightened(0.25))
	slices.append(_tex(cap))
	return slices


## Rooftop hospital marker: white pad with a raised red cross.
static func _hospital_cross() -> Array[ImageTexture]:
	var white := Color(0.95, 0.95, 0.93)
	var grey := Color(0.7, 0.71, 0.72)
	var red := Color(0.88, 0.12, 0.14)
	var red_dark := Color(0.6, 0.08, 0.1)
	var red_light := Color(1.0, 0.4, 0.38)
	var slices: Array[ImageTexture] = []
	var pad := _img(16)
	_circle(pad, 7.5, 7.5, 7.6, grey)
	_circle(pad, 7.5, 7.5, 6.6, white)
	slices.append(_tex(pad))
	var body := _img(16)
	_rect(body, 6, 2, 4, 12, red_dark)
	_rect(body, 2, 6, 12, 4, red_dark)
	var body_tex := _tex(body)
	slices.append(body_tex)
	slices.append(body_tex)
	var top := _img(16)
	_rect(top, 6, 2, 4, 12, red)
	_rect(top, 2, 6, 12, 4, red)
	_rect(top, 6, 2, 4, 1, red_light)
	_rect(top, 2, 6, 4, 1, red_light)
	_rect(top, 10, 6, 4, 1, red_light)
	_rect(top, 6, 2, 1, 4, red_light)
	slices.append(_tex(top))
	return slices


## Rooftop safe-house marker: green shield pad with a raised house symbol.
static func _safehouse_marker() -> Array[ImageTexture]:
	var dark := Color(0.06, 0.3, 0.14)
	var green := Color(0.15, 0.75, 0.32)
	var bright := Color(0.6, 1.0, 0.65)
	var slices: Array[ImageTexture] = []
	var shield := PackedStringArray([
		"................",
		".gggggggggggggg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		".gddddddddddddg.",
		"..gddddddddddg..",
		"..gddddddddddg..",
		"...gddddddddg...",
		"....ggddddgg....",
		"......gddg......",
		".......gg.......",
	])
	slices.append(_tex(_pixmap(shield, {"g": green, "d": dark})))
	var house := PackedStringArray([
		"................",
		"................",
		"................",
		".......hh.......",
		"......hhhh......",
		".....hhhhhh.....",
		"....hhhhhhhh....",
		"...hhhhhhhhhh...",
		".....hhhhhh.....",
		".....hh..hh.....",
		".....hh..hh.....",
		".....hh..hh.....",
		"................",
		"................",
		"................",
		"................",
	])
	var house_tex := _tex(_pixmap(house, {"h": green}))
	slices.append(house_tex)
	slices.append(_tex(_pixmap(house, {"h": bright})))
	return slices


# --- Furniture ------------------------------------------------------------------
# Furniture is long along X with its front on the +Y (camera) side, so it reads
# correctly when placed unrotated against a north wall.


## Half-looted store shelf, 16x6 canvas.
static func _shelf() -> Array[ImageTexture]:
	var wood := Color(0.5, 0.36, 0.22)
	var dark := Color(0.34, 0.23, 0.13)
	var back := Color(0.26, 0.18, 0.11)
	var goods: Array[Color] = [
		Color(0.85, 0.2, 0.2), Color(0.95, 0.8, 0.2), Color(0.2, 0.65, 0.7),
		Color(0.92, 0.92, 0.88), Color(0.25, 0.4, 0.85), Color(0.95, 0.5, 0.15),
		Color(0.4, 0.75, 0.3),
	]
	var slices: Array[ImageTexture] = []
	for i in 13:
		var img := _img2(16, 6)
		if i % 4 == 0:  # shelf board
			_rect(img, 0, 0, 16, 6, wood if i == 12 else dark)
			_rect(img, 0, 5, 16, 1, wood.lightened(0.12))
			if i == 12:
				_rect(img, 0, 0, 16, 1, dark)
				_px(img, 4, 2, goods[3])  # a lone can left on top
				_px(img, 5, 2, goods[3])
		else:
			_rect(img, 0, 0, 16, 2, back)
			_rect(img, 0, 0, 1, 6, dark)
			_rect(img, 15, 0, 1, 6, dark)
			var tier := i / 4
			var level := i % 4  # 1..3 above the board
			for g in 7:
				var r := _hash(g, tier, 51)
				if r % 3 == 0:
					continue  # looted gap
				var item_h := 1 + (r / 3) % 3
				if level <= item_h:
					var c: Color = goods[(r / 9) % goods.size()]
					_rect(img, 1 + g * 2, 3, 2, 3, c)
					_px(img, 1 + g * 2, 5, c.lightened(0.25) if level == item_h else c.darkened(0.15))
		slices.append(_tex(img))
	return slices


## Rumpled single bed, 18x12 canvas, headboard on the -X end.
static func _bed() -> Array[ImageTexture]:
	var wood := Color(0.45, 0.3, 0.18)
	var dark := Color(0.3, 0.2, 0.12)
	var sheet := Color(0.88, 0.86, 0.8)
	var blanket := Color(0.25, 0.4, 0.66)
	var blanket_light := Color(0.36, 0.52, 0.78)
	var blanket_dark := Color(0.17, 0.28, 0.5)
	var pillow := Color(0.97, 0.97, 0.95)
	var slices: Array[ImageTexture] = []
	var legs := _img2(18, 12)
	for p: Vector2i in [Vector2i(0, 0), Vector2i(16, 0), Vector2i(0, 10), Vector2i(16, 10)]:
		_rect(legs, p.x, p.y, 2, 2, dark)
	slices.append(_tex(legs))
	var frame := _img2(18, 12)
	_rect(frame, 0, 0, 18, 12, wood)
	_rect(frame, 0, 11, 18, 1, dark)
	_rect(frame, 0, 0, 18, 1, dark)
	var frame_tex := _tex(frame)
	slices.append(frame_tex)
	slices.append(frame_tex)
	var mattress := _img2(18, 12)
	_rect(mattress, 0, 0, 2, 12, wood)
	_rect(mattress, 2, 1, 15, 10, sheet)
	_rect(mattress, 2, 10, 15, 1, sheet.darkened(0.15))
	slices.append(_tex(mattress))
	var cover := _img2(18, 12)
	_rect(cover, 0, 0, 2, 12, wood)
	_rect(cover, 2, 1, 15, 10, sheet)
	_rect(cover, 8, 1, 9, 10, blanket)
	_rect(cover, 8, 1, 1, 10, blanket_light)
	_rect(cover, 8, 10, 9, 1, blanket_dark)
	_rect(cover, 3, 3, 4, 6, pillow)
	_rect(cover, 3, 8, 4, 1, pillow.darkened(0.15))
	slices.append(_tex(cover))
	var lumps := _img2(18, 12)
	_rect(lumps, 0, 0, 2, 12, wood)
	_ellipse(lumps, 12.5, 5.0, 3.6, 2.6, blanket)
	_ellipse(lumps, 12.0, 4.5, 2.4, 1.6, blanket_light)
	_rect(lumps, 4, 4, 2, 4, pillow)
	slices.append(_tex(lumps))
	var head := _img2(18, 12)
	_rect(head, 0, 0, 2, 12, wood.lightened(0.1))
	_rect(head, 0, 11, 2, 1, dark)
	slices.append(_tex(head))
	return slices


## Wooden table with a few abandoned things on it, 14x10 canvas.
static func _table() -> Array[ImageTexture]:
	var wood := Color(0.56, 0.4, 0.24)
	var light := Color(0.66, 0.5, 0.31)
	var dark := Color(0.36, 0.24, 0.13)
	var slices: Array[ImageTexture] = []
	var legs := _img2(14, 10)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(11, 1), Vector2i(1, 7), Vector2i(11, 7)]:
		_rect(legs, p.x, p.y, 2, 2, dark)
	var legs_tex := _tex(legs)
	for i in 5:
		slices.append(legs_tex)
	var apron := _img2(14, 10)
	_rect(apron, 0, 0, 14, 10, dark)
	_rect(apron, 0, 9, 14, 1, wood.darkened(0.15))
	slices.append(_tex(apron))
	var top := _img2(14, 10)
	_rect(top, 0, 0, 14, 10, wood)
	for y in 10:
		for x in 14:
			if y % 3 == 0:
				top.set_pixel(x, y, light)
			elif _hash(x / 3, y, 61) % 7 == 0:
				top.set_pixel(x, y, wood.darkened(0.1))
	_rect(top, 0, 9, 14, 1, light)
	_circle(top, 4, 5, 1.6, Color(0.9, 0.9, 0.87))  # plate
	_px(top, 4, 5, Color(0.75, 0.75, 0.72))
	_rect(top, 9, 2, 3, 2, Color(0.85, 0.83, 0.7))  # note
	slices.append(_tex(top))
	var things := _img2(14, 10)
	_rect(things, 9, 6, 2, 2, Color(0.8, 0.3, 0.2))  # mug
	slices.append(_tex(things))
	var mug_top := _img2(14, 10)
	_rect(mug_top, 9, 6, 2, 2, Color(0.9, 0.4, 0.28))
	_px(mug_top, 10, 7, Color(0.25, 0.15, 0.1))
	slices.append(_tex(mug_top))
	return slices


## Alley dumpster, 18x10 canvas: one lid shut, the other thrown open on trash.
static func _dumpster() -> Array[ImageTexture]:
	var green := Color(0.14, 0.4, 0.26)
	var rib := Color(0.09, 0.28, 0.18)
	var light := Color(0.24, 0.54, 0.36)
	var rust := Color(0.5, 0.3, 0.15)
	var lid := Color(0.14, 0.15, 0.17)
	var lid_light := Color(0.26, 0.27, 0.3)
	var bag := Color(0.08, 0.08, 0.1)
	var slices: Array[ImageTexture] = []
	var wheels := _img2(18, 10)
	for p: Vector2i in [Vector2i(1, 1), Vector2i(15, 1), Vector2i(1, 7), Vector2i(15, 7)]:
		_rect(wheels, p.x, p.y, 2, 2, bag)
	slices.append(_tex(wheels))
	var body_cache: Dictionary = {}
	for i in 7:
		var band := i == 3
		var low := i == 0
		var bkey := int(band) + int(low) * 2 + (i % 2) * 4
		if not body_cache.has(bkey):
			var img := _img2(18, 10)
			_rect(img, 0, 1, 18, 8, green)
			_rect(img, 0, 1, 18, 1, rib)
			for x in 18:
				var c := rib if x % 4 == 0 else green
				if band:
					c = light
				if low and _hash(x, 0, 71) % 3 == 0:
					c = rust
				elif _hash(x, i % 2, 72) % 11 == 0:
					c = rust
				img.set_pixel(x, 8, c)
			_px(img, 0, 8, rib)
			_px(img, 17, 8, rib)
			body_cache[bkey] = _tex(img)
		slices.append(body_cache[bkey])
	var rim := _img2(18, 10)
	_rect(rim, 0, 1, 18, 8, light)
	_rect(rim, 1, 2, 16, 6, bag)
	_rect(rim, 10, 2, 7, 6, Color(0.16, 0.14, 0.12))
	_px(rim, 12, 6, Color(0.8, 0.75, 0.55))
	_px(rim, 15, 3, Color(0.7, 0.2, 0.2))
	_px(rim, 11, 3, Color(0.85, 0.85, 0.8))
	slices.append(_tex(rim))
	var top := _img2(18, 10)
	_rect(top, 0, 1, 9, 8, lid)
	_rect(top, 0, 1, 9, 1, lid_light)
	_rect(top, 1, 4, 7, 1, lid_light)
	_rect(top, 1, 7, 7, 1, lid_light)
	_rect(top, 9, 0, 9, 2, lid)  # the other lid flipped up against the back
	_rect(top, 9, 1, 9, 1, lid_light)
	_circle(top, 13.5, 5.2, 2.2, bag)
	_px(top, 13, 4, Color(0.3, 0.3, 0.34))
	_px(top, 16, 6, Color(0.75, 0.65, 0.4))
	_px(top, 11, 7, Color(0.85, 0.85, 0.8))
	slices.append(_tex(top))
	var open_lid := _img2(18, 10)
	_rect(open_lid, 9, 0, 9, 1, lid)
	_circle(open_lid, 13.5, 5.0, 1.2, bag)
	_px(open_lid, 13, 5, Color(0.3, 0.3, 0.34))
	var open_tex := _tex(open_lid)
	slices.append(open_tex)
	var lid_edge := _img2(18, 10)
	_rect(lid_edge, 9, 0, 9, 1, lid_light)
	slices.append(_tex(lid_edge))
	return slices


## Dented metal trash can with a lid.
static func _trash_can() -> Array[ImageTexture]:
	var metal := Color(0.56, 0.58, 0.6)
	var groove := Color(0.4, 0.42, 0.45)
	var light := Color(0.76, 0.78, 0.8)
	var slices: Array[ImageTexture] = []
	var ridge := _img(8)
	_circle(ridge, 3.5, 3.5, 2.7, metal)
	_px(ridge, 2, 5, light)
	var ridge_tex := _tex(ridge)
	var dip := _img(8)
	_circle(dip, 3.5, 3.5, 2.7, groove)
	_px(dip, 2, 5, metal)
	var dip_tex := _tex(dip)
	var base := _img(8)
	_circle(base, 3.5, 3.5, 2.3, groove.darkened(0.3))
	slices.append(_tex(base))
	for i in 6:
		slices.append(ridge_tex if i % 2 == 0 else dip_tex)
	var lid := _img(8)
	_circle(lid, 3.5, 3.5, 3.4, metal)
	_circle(lid, 3.5, 3.5, 2.4, light)
	slices.append(_tex(lid))
	var knob := _img(8)
	_circle(knob, 3.5, 3.5, 1.6, light)
	_rect(knob, 3, 3, 2, 2, groove)
	slices.append(_tex(knob))
	return slices


## Hospital gurney bed with side rails and an IV stand, 18x10 canvas.
static func _hospital_bed() -> Array[ImageTexture]:
	var metal := Color(0.74, 0.77, 0.82)
	var metal_dark := Color(0.5, 0.53, 0.58)
	var wheel := Color(0.12, 0.12, 0.14)
	var white := Color(0.95, 0.96, 0.97)
	var shade := Color(0.78, 0.81, 0.86)
	var mint := Color(0.5, 0.8, 0.74)
	var mint_dark := Color(0.36, 0.64, 0.6)
	var slices: Array[ImageTexture] = []
	var corners: Array[Vector2i] = [Vector2i(1, 1), Vector2i(16, 1), Vector2i(1, 8), Vector2i(16, 8)]
	var wheels := _img2(18, 10)
	for p in corners:
		_px(wheels, p.x, p.y, wheel)
	_px(wheels, 0, 9, metal_dark)
	slices.append(_tex(wheels))
	var legs := _img2(18, 10)
	for p in corners:
		_px(legs, p.x, p.y, metal_dark)
	_px(legs, 0, 9, metal_dark)
	var legs_tex := _tex(legs)
	slices.append(legs_tex)
	slices.append(legs_tex)
	var frame := _img2(18, 10)
	_rect(frame, 0, 0, 18, 10, metal)
	_rect(frame, 0, 9, 18, 1, metal_dark)
	slices.append(_tex(frame))
	var mattress := _img2(18, 10)
	_rect(mattress, 1, 1, 16, 8, white)
	_rect(mattress, 1, 8, 16, 1, shade)
	_rect(mattress, 0, 0, 1, 10, metal)
	_rect(mattress, 17, 0, 1, 10, metal)
	slices.append(_tex(mattress))
	var cover := _img2(18, 10)
	_rect(cover, 1, 1, 16, 8, white)
	_rect(cover, 7, 1, 10, 8, mint)
	_rect(cover, 7, 1, 1, 8, white)
	_rect(cover, 8, 8, 9, 1, mint_dark)
	_rect(cover, 11, 4, 3, 1, Color(0.9, 0.3, 0.3))  # small red cross on the blanket
	_rect(cover, 12, 3, 1, 3, Color(0.9, 0.3, 0.3))
	_rect(cover, 2, 2, 4, 6, white)
	_rect(cover, 2, 7, 4, 1, shade)
	_rect(cover, 0, 0, 1, 10, metal)
	_rect(cover, 17, 0, 1, 10, metal)
	slices.append(_tex(cover))
	# Rails: posts, then the top bar
	for i in 2:
		var img := _img2(18, 10)
		_rect(img, 0, 0, 1, 10, metal)
		_rect(img, 17, 0, 1, 10, metal_dark if i == 0 else metal)
		if i == 0:
			for x: int in [6, 10, 14]:
				_px(img, x, 0, metal_dark)
				_px(img, x, 9, metal_dark)
			_rect(img, 3, 3, 2, 4, white)  # pillow crown
		else:
			_rect(img, 6, 0, 9, 1, metal)
			_rect(img, 6, 9, 9, 1, metal)
		_px(img, 0, 9, metal_dark)
		slices.append(_tex(img))
	# IV stand rising from the head corner, bag hanging off the hook
	var pole := _img2(18, 10)
	_px(pole, 0, 9, metal_dark)
	var pole_tex := _tex(pole)
	slices.append(pole_tex)
	slices.append(pole_tex)
	var bag_low := _img2(18, 10)
	_px(bag_low, 0, 9, metal_dark)
	_rect(bag_low, 1, 8, 2, 2, Color(0.8, 0.22, 0.25))
	slices.append(_tex(bag_low))
	var bag_high := _img2(18, 10)
	_px(bag_high, 0, 9, metal_dark)
	_rect(bag_high, 1, 8, 2, 2, Color(0.92, 0.8, 0.82))
	_px(bag_high, 1, 9, Color(0.85, 0.4, 0.42))
	slices.append(_tex(bag_high))
	var hook := _img2(18, 10)
	_rect(hook, 0, 9, 3, 1, metal)
	_px(hook, 0, 8, metal)
	slices.append(_tex(hook))
	return slices


## Lab bench for brewing the cure, 20x8 canvas: steel cabinet, dark worktop,
## glowing flasks, burner and a microscope.
static func _lab_bench() -> Array[ImageTexture]:
	var steel := Color(0.8, 0.82, 0.86)
	var seam := Color(0.52, 0.55, 0.6)
	var handle := Color(0.25, 0.27, 0.3)
	var counter := Color(0.2, 0.23, 0.28)
	var counter_edge := Color(0.34, 0.38, 0.44)
	var glass := Color(0.8, 0.92, 0.95)
	var cure := Color(0.4, 1.0, 0.5)
	var purple := Color(0.75, 0.4, 0.95)
	var slices: Array[ImageTexture] = []
	var kick := _img2(20, 8)
	_rect(kick, 1, 0, 18, 7, handle)
	slices.append(_tex(kick))
	var plain: ImageTexture
	for i in 4:
		if i != 2 and plain != null:
			slices.append(plain)
			continue
		var img := _img2(20, 8)
		_rect(img, 0, 0, 20, 8, steel)
		_rect(img, 0, 0, 20, 1, seam)
		for x in 20:
			if x % 5 == 0 or x == 19:
				img.set_pixel(x, 7, seam)
			elif i == 2 and x % 5 == 2:
				img.set_pixel(x, 7, handle)
				img.set_pixel(x + 1, 7, handle)
		var t := _tex(img)
		if i != 2:
			plain = t
		slices.append(t)
	var worktop := _img2(20, 8)
	_rect(worktop, 0, 0, 20, 8, counter)
	_rect(worktop, 0, 7, 20, 1, counter_edge)
	_rect(worktop, 0, 0, 20, 1, counter_edge)
	_rect(worktop, 15, 4, 4, 2, Color(0.9, 0.9, 0.84))  # notes
	_px(worktop, 16, 5, seam)
	_px(worktop, 17, 4, seam)
	slices.append(_tex(worktop))
	var low := _img2(20, 8)
	_circle(low, 4, 4, 1.7, glass)
	_circle(low, 4, 4, 1.0, cure)
	_rect(low, 7, 1, 5, 1, Color(0.5, 0.36, 0.22))  # test-tube rack
	_rect(low, 9, 4, 2, 2, handle)  # burner
	_rect(low, 13, 2, 2, 3, handle)  # microscope base
	_circle(low, 12.5, 5.6, 1.1, glass)
	_px(low, 12, 5, purple)
	_px(low, 13, 6, purple)
	slices.append(_tex(low))
	var mid := _img2(20, 8)
	_circle(mid, 4, 4, 1.0, cure)
	_px(mid, 3, 3, glass)
	_px(mid, 7, 1, Color(0.9, 0.3, 0.3))
	_px(mid, 9, 1, Color(0.3, 0.6, 0.95))
	_px(mid, 11, 1, cure)
	_rect(mid, 9, 4, 2, 2, Color(0.2, 0.5, 1.0))  # flame
	_px(mid, 13, 2, seam)
	_px(mid, 13, 3, seam)
	_px(mid, 12, 5, purple.lightened(0.3))
	slices.append(_tex(mid))
	var high := _img2(20, 8)
	_px(high, 4, 4, glass)
	_px(high, 10, 4, Color(1.0, 0.85, 0.3))
	_rect(high, 13, 2, 3, 2, handle)
	_px(high, 15, 3, steel)
	slices.append(_tex(high))
	return slices


# --- Rubble ---------------------------------------------------------------------


## Collapsed-building debris: chunky hash-placed mounds of concrete and brick
## with fallen beams and bent rebar. Deterministic for a given w x d.
static func _rubble(w: int, d: int) -> Array[ImageTexture]:
	var sd := w * 31 + d * 17
	var palette: Array[Color] = [
		Color(0.6, 0.6, 0.58), Color(0.5, 0.5, 0.49), Color(0.56, 0.31, 0.23),
		Color(0.66, 0.65, 0.62), Color(0.44, 0.26, 0.2), Color(0.6, 0.54, 0.45),
		Color(0.38, 0.39, 0.42), Color(0.54, 0.54, 0.52),
	]
	# Mounds: x, y, radius, peak height.
	var mounds: Array[Vector4] = []
	var count := maxi(w * d / 70, 5)
	for m in count:
		var peak := 3.0 + _hash(m, 4, sd) % 5
		if m == 0:
			peak = 7.0
		mounds.append(Vector4(
			3 + _hash(m, 1, sd) % maxi(w - 6, 1),
			3 + _hash(m, 2, sd) % maxi(d - 6, 1),
			5.0 + _hash(m, 3, sd) % 6,
			peak))
	# Height + colour are decided per chunk (3x2 px, brick-staggered) so the
	# pile reads as broken slabs rather than noise.
	var cols := w / 4 + 2
	var rows := d / 3 + 2
	var chunk_h := PackedByteArray()
	chunk_h.resize(cols * rows)
	for qy in rows:
		for qx in cols:
			var sx := qx * 4 + 1.5 - (qy % 2) * 2.0
			var sy := qy * 3 + 1.0
			var h := 0.0
			for mnd in mounds:
				h = maxf(h, mnd.w * (1.0 - Vector2(sx - mnd.x, sy - mnd.y).length() / mnd.z))
			var r := _hash(qx, qy, sd)
			h += (r % 3) * 0.6 - 0.4
			var edge := minf(minf(sx, w - 1 - sx), minf(sy, d - 1 - sy))
			if edge < 2.0 and (r / 3) % 3 != 0:
				h = 0.0  # ragged outline
			elif h < 1.0 and (r / 9) % 6 != 0:
				h = 1.0  # ground scatter between the piles
			chunk_h[qy * cols + qx] = clampi(roundi(h), 0, 8)
	var top_h := 4
	for v in chunk_h:
		top_h = maxi(top_h, v)
	var imgs: Array[Image] = []
	for i in top_h:
		imgs.append(_img2(w, d))
	var heights := PackedByteArray()
	heights.resize(w * d)
	for y in d:
		var qy := y / 3
		for x in w:
			var qx := (x + (qy % 2) * 2) / 4
			var h := chunk_h[qy * cols + qx]
			heights[y * w + x] = h
			if h == 0:
				continue
			var r := _hash(qx, qy, sd + 3)
			# Brick shows up in patches; everything else is concrete.
			var bricky := _hash(qx / 2, qy / 2, sd + 6) % 4 == 0
			var c: Color = palette[(r % 2) * 2 + 2] if bricky and r % 3 != 0 \
				else palette[[0, 1, 3, 5, 6, 7, 0, 3][r % 8]]
			var speck := _hash(x, y, sd + 4) % 9
			for i in h:
				var shade := c
				if i < h - 1:
					shade = c.darkened(0.35)
				elif h == 1:  # dusty ground layer
					shade = c.lerp(Color(0.36, 0.35, 0.34), 0.6)
					if speck < 2:
						shade = shade.darkened(0.15)
				else:
					shade = c.lightened(0.04 * h)
					if speck == 0:
						shade = shade.darkened(0.12)
				imgs[i].set_pixel(x, y, shade)
	# Fallen beams: straight runs climbing out of the pile.
	var wood := Color(0.32, 0.22, 0.13)
	var girder := Color(0.24, 0.26, 0.3)
	for b in maxi(count / 3, 2):
		var ang := (_hash(b, 5, sd) % 16) * TAU / 16.0
		var length := 7 + _hash(b, 6, sd) % 8
		var start := Vector2(4 + _hash(b, 7, sd) % maxi(w - 8, 1), 3 + _hash(b, 8, sd) % maxi(d - 6, 1))
		var c := wood if b % 2 == 0 else girder
		var rise := 1 + _hash(b, 9, sd) % 3
		for t in length:
			var p := start + Vector2.from_angle(ang) * t
			var px := roundi(p.x)
			var py := roundi(p.y)
			if px < 1 or py < 1 or px >= w - 1 or py >= d - 1:
				continue
			var layer := mini(int(heights[py * w + px]) + (rise * t) / length, top_h - 1)
			imgs[layer].set_pixel(px, py, c if t % 4 != 3 else c.lightened(0.15))
			imgs[layer].set_pixel(px, py - 1, c.lightened(0.1))
			if layer > 0:
				imgs[layer - 1].set_pixel(px, py, c.darkened(0.25))
	# Rebar: rusty rods sticking up out of the concrete, bent at the tip.
	var rust := Color(0.62, 0.32, 0.15)
	for b in maxi(count / 2, 2):
		var px := 3 + _hash(b, 10, sd) % maxi(w - 6, 1)
		var py := 3 + _hash(b, 11, sd) % maxi(d - 6, 1)
		var from := int(heights[py * w + px])
		if from == 0:
			continue
		var tall := 2 + _hash(b, 12, sd) % 3
		for i in range(from, mini(from + tall, top_h)):
			var bend := 1 if i == from + tall - 1 else 0
			imgs[i].set_pixel(px + bend, py, rust if i % 2 == 0 else rust.darkened(0.2))
	var slices: Array[ImageTexture] = []
	for img in imgs:
		slices.append(_tex(img))
	return slices


# --- Drawing helpers ----------------------------------------------------------


static func _img(size: int) -> Image:
	return Image.create_empty(size, size, false, Image.FORMAT_RGBA8)


static func _img2(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


static func _circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if Vector2(x - cx, y - cy).length() <= r:
				img.set_pixel(x, y, c)


static func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y0 + h, img.get_height())):
		for x in range(maxi(x0, 0), mini(x0 + w, img.get_width())):
			img.set_pixel(x, y, c)


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## Bounds-checked set_pixel.
static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(maxi(floori(cy - ry), 0), mini(ceili(cy + ry) + 1, img.get_height())):
		for x in range(maxi(floori(cx - rx), 0), mini(ceili(cx + rx) + 1, img.get_width())):
			var nx := (x - cx) / rx
			var ny := (y - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, c)


## Builds an image from rows of characters; each character found in `pal`
## paints that colour, anything else stays transparent.
static func _pixmap(rows: PackedStringArray, pal: Dictionary) -> Image:
	var img := _img2(rows[0].length(), rows.size())
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var ch := row[x]
			if pal.has(ch):
				img.set_pixel(x, y, pal[ch])
	return img


## Deterministic non-negative integer hash for procedural detail.
static func _hash(x: int, y: int, s: int) -> int:
	var n := (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
	n = ((n ^ (n >> 13)) * 1274126177) & 0x7fffffff
	return (n ^ (n >> 16)) & 0x7fffffff
