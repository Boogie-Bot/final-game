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
		_cache[key] = frames
	return _cache[key]


static func building(w: int, d: int, h: int, style: int) -> Array:
	var key := "bld_%d_%d_%d_%d" % [w, d, h, style]
	if not _cache.has(key):
		_cache[key] = [_building(w, d, h, style)]
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
	var base := Color(0.56, 0.56, 0.54)
	var seam := Color(0.47, 0.47, 0.45)
	var fleck := Color(0.52, 0.52, 0.5)
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
	var base := Color(0.23, 0.27, 0.18)
	var light := Color(0.27, 0.32, 0.21)
	var dark := Color(0.19, 0.22, 0.15)
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
	var asphalt := Color(0.2, 0.2, 0.22)
	var dark := Color(0.17, 0.17, 0.19)
	var dash := Color(0.72, 0.62, 0.2)
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


static func _building(w: int, d: int, h: int, style: int) -> Array[ImageTexture]:
	var wall_colors: Array[Color] = [
		Color(0.52, 0.3, 0.24),   # brick
		Color(0.55, 0.55, 0.58),  # concrete
		Color(0.62, 0.55, 0.42),  # tan
		Color(0.3, 0.35, 0.42),   # dark glass office
	]
	var wall: Color = wall_colors[style % wall_colors.size()]
	var edge := wall.darkened(0.25)
	var roof := wall.darkened(0.45)
	var win_dark := Color(0.16, 0.2, 0.26)
	var win_lit := Color(0.9, 0.82, 0.5)
	var door := Color(0.25, 0.18, 0.12)
	var slices: Array[ImageTexture] = []

	for i in h:
		var img := _img2(w, d)
		if i == h - 1:
			_rect(img, 0, 0, w, d, roof)
			_rect(img, 0, 0, w, 1, edge)
			_rect(img, 0, d - 1, w, 1, edge)
			_rect(img, 0, 0, 1, d, edge)
			_rect(img, w - 1, 0, 1, d, edge)
			_rect(img, roundi(w / 2.0) - 2, roundi(d / 2.0) - 2, 4, 3, Color(0.4, 0.4, 0.44))
		else:
			_rect(img, 0, 0, w, d, wall)
			_rect(img, 0, 0, w, 1, edge)
			_rect(img, 0, d - 1, w, 1, edge)
			_rect(img, 0, 0, 1, d, edge)
			_rect(img, w - 1, 0, 1, d, edge)
			# Window bands: two lit layers out of every three read as floors
			if i % 3 != 0 and i > 2:
				for x in range(2, w - 2, 3):
					img.set_pixel(x, 0, win_lit if (x * 7 + i * 13 + style * 5) % 5 == 0 else win_dark)
					img.set_pixel(x, d - 1, win_lit if (x * 11 + i * 13 + style * 3) % 5 == 0 else win_dark)
				for y in range(2, d - 2, 3):
					img.set_pixel(0, y, win_lit if (y * 7 + i * 17 + style * 5) % 5 == 0 else win_dark)
					img.set_pixel(w - 1, y, win_lit if (y * 11 + i * 17 + style * 3) % 5 == 0 else win_dark)
			if i < 3:
				_rect(img, w - 1, roundi(d / 2.0) - 1, 1, 3, door)
		slices.append(_tex(img))
	return slices


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
