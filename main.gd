extends Node2D
## Builds the city (ground, roads, buildings, props), spawns entities,
## manages fog of war and the periodic zombie spawner.

const CELL := 48.0
const COLS := 50
const ROWS := 30
const ROAD_HALF := 48.0
const VROADS: Array[float] = [600.0, 1200.0, 1800.0]
const HROADS: Array[float] = [480.0, 960.0]
const PARKS: Array[Rect2] = [Rect2(648, 528, 504, 384), Rect2(1848, 1008, 504, 384)]

const ZOMBIE_SCENE := preload("res://zombie.tscn")
const HERB_SCENE := preload("res://herb.tscn")
const CRATE_SCENE := preload("res://crate.tscn")
const SURVIVOR_SCENE := preload("res://survivor.tscn")

const SPAWN_INTERVAL := 10.0
const SPAWN_SCREEN_MARGIN := 96.0  # px beyond the screen edge that still counts as visible

# [healing herbs, zombie multiplier, npc-zombie drain vs CPU survivor,
#  player-zombie drain vs CPU survivor, zombie spawn interval]
# Higher difficulties make the survivor tougher to bring down and (on hard)
# slow reinforcements, so the zombie-player endgame gets harder too.
const DIFFICULTIES := [
	[4, 1.0, 9.0, 120.0, SPAWN_INTERVAL],
	[2, 5.0 / 3.0, 7.0, 105.0, SPAWN_INTERVAL],
	[1, 3.0, 5.0, 90.0, SPAWN_INTERVAL * 4.0 / 3.0],  # 3/4 the spawn rate
]

const XRAY_SHADER := preload("res://building_xray.gdshader")

# [center, canvas_width, canvas_depth, height_layers, style]
const BUILDINGS := [
	[Vector2(220, 200), 32, 24, 22, 0],
	[Vector2(430, 330), 24, 20, 30, 3],
	[Vector2(800, 180), 36, 24, 26, 1],
	[Vector2(1030, 320), 28, 22, 18, 2],
	[Vector2(1380, 200), 30, 24, 34, 3],
	[Vector2(1620, 330), 26, 20, 20, 0],
	[Vector2(2050, 220), 40, 26, 24, 1],
	[Vector2(200, 700), 30, 22, 28, 2],
	[Vector2(420, 820), 26, 20, 16, 0],
	[Vector2(1400, 680), 34, 26, 38, 3],
	[Vector2(1650, 840), 24, 18, 22, 1],
	[Vector2(2080, 720), 36, 24, 30, 2],
	[Vector2(240, 1180), 28, 22, 20, 1],
	[Vector2(450, 1300), 30, 22, 26, 3],
	[Vector2(820, 1150), 34, 24, 24, 0],
	[Vector2(1060, 1300), 26, 20, 32, 2],
	[Vector2(1420, 1180), 32, 24, 18, 1],
	[Vector2(1680, 1320), 28, 20, 28, 0],
	[Vector2(100, 340), 20, 18, 18, 2],
	[Vector2(700, 330), 22, 18, 24, 3],
	[Vector2(960, 110), 20, 14, 14, 0],
	[Vector2(1310, 330), 24, 18, 28, 1],
	[Vector2(1550, 120), 28, 16, 20, 2],
	[Vector2(1930, 350), 24, 18, 26, 0],
	[Vector2(2250, 370), 26, 18, 16, 3],
	[Vector2(150, 580), 22, 16, 22, 1],
	[Vector2(430, 620), 24, 18, 30, 2],
	[Vector2(1300, 850), 22, 18, 18, 0],
	[Vector2(1600, 580), 26, 16, 24, 3],
	[Vector2(1990, 570), 22, 14, 14, 1],
	[Vector2(2240, 850), 28, 20, 32, 2],
	[Vector2(130, 1320), 20, 16, 20, 3],
	[Vector2(380, 1070), 26, 16, 26, 0],
	[Vector2(700, 1320), 22, 16, 18, 1],
	[Vector2(1300, 1320), 22, 16, 22, 2],
	[Vector2(1560, 1060), 28, 16, 28, 0],
]

# [position, rotation, color_index]
const CARS := [
	[Vector2(566, 300), PI / 2, 0],
	[Vector2(634, 800), -PI / 2, 1],
	[Vector2(1166, 1100), PI / 2, 2],
	[Vector2(1234, 350), -PI / 2, 0],
	[Vector2(1766, 900), PI / 2, 1],
	[Vector2(1834, 200), -PI / 2, 2],
	[Vector2(900, 446), PI, 0],
	[Vector2(1550, 514), 0.0, 2],
	[Vector2(2000, 926), PI, 1],
	[Vector2(450, 994), 0.0, 0],
]

# Trees sit well inside the parks, clear of edges, lights and herbs.
const TREES := [
	Vector2(800, 700), Vector2(1000, 780), Vector2(900, 620),
	Vector2(1980, 1100), Vector2(2200, 1300), Vector2(2080, 1200),
]

const ZOMBIES := [
	Vector2(900, 700), Vector2(1500, 250), Vector2(2100, 480),
	Vector2(600, 1200), Vector2(1800, 1100), Vector2(1200, 960),
	Vector2(400, 150), Vector2(1700, 150), Vector2(300, 950),
	Vector2(2200, 950), Vector2(900, 1250), Vector2(1350, 500),
]

const HERBS := [
	Vector2(850, 720), Vector2(950, 780), Vector2(780, 650),
	Vector2(2000, 1150), Vector2(2150, 1250), Vector2(350, 240),
	Vector2(1550, 900), Vector2(2250, 250),
]

const CRATES := [
	Vector2(470, 380), Vector2(760, 500), Vector2(1340, 1000),
	Vector2(1870, 640), Vector2(1060, 80), Vector2(2300, 1350),
	Vector2(250, 1150), Vector2(1500, 320), Vector2(950, 1300),
	Vector2(2100, 900), Vector2(620, 150),
]

const CAR_SCRIPT := preload("res://car.gd")
const FOOTPRINTS_SCRIPT := preload("res://footprints.gd")
const WEATHER_SCRIPT := preload("res://weather.gd")
const HORDE_SCRIPT := preload("res://horde.gd")
const PHONES_SCRIPT := preload("res://phones.gd")
const ZMP_SCRIPT := preload("res://zmp.gd")
const DISTRICTS_SCRIPT := preload("res://districts.gd")
const HOSPITAL_SCRIPT := preload("res://hospital.gd")
const INTERIORS_SCRIPT := preload("res://interiors.gd")
const ALLEY_SCRIPT := preload("res://start_alley.gd")
const MINIMAP_SCRIPT := preload("res://minimap.gd")
const HUD_EXTRAS_SCRIPT := preload("res://hud_extras.gd")
const END_SCREEN_SCRIPT := preload("res://end_screen.gd")
const RETRO_SCRIPT := preload("res://retro.gd")

const BUILDING_LAYER := 8  # collision layer 4: the zombie player (mask 1) walks through

const HERB_CLEARANCE := 20.0  # open px herbs keep from every static item
const HERB_RADIUS := 8.0  # half the herb sprite's drawn size

@onready var player: CharacterBody2D = $Player

var fog: FogOfWar
## [position, footprint radius] of every static street item (cars, streetlights,
## trees, crates, dumpsters, signs, payphones...). Herbs spawn with at least
## HERB_CLEARANCE px of open space from all of them so they are never covered.
var static_obstacles: Array = []
## One entry per building: {index, body, stack, rect, occluded, center, size, height_px,
## canvas_w, canvas_d, alive, kind, mat, xray}
var buildings: Array[Dictionary] = []
var footprints: Node
var weather: Node
var horde: Node
var phones: Node
var zmp: Node
var interiors: Node
var hospital: Node
var districts: Node
var start_alley: Node
var minimap: Control
var hud_extras: Control
var end_screen: Control
var retro: CanvasLayer

var _spawn_interval: float = SPAWN_INTERVAL
var _npc_survivor_drain: float = 9.0
var _spawn_timer: float = SPAWN_INTERVAL
var _popup_tween: Tween
var _cures_found: int = 0
var _photos: Array = []
var _ended: bool = false
var _survivor: Node = null


func _ready() -> void:
	Game.reset_run()
	Game.main = self
	_make_ground()
	_make_walls()
	_make_buildings()
	_make_props()
	_make_fog()

	districts = _add_system(DISTRICTS_SCRIPT)
	hospital = _add_system(HOSPITAL_SCRIPT)
	interiors = _add_system(INTERIORS_SCRIPT)
	phones = _add_system(PHONES_SCRIPT)
	zmp = _add_system(ZMP_SCRIPT)
	footprints = FOOTPRINTS_SCRIPT.new()
	add_child(footprints)
	footprints.setup(self)
	horde = _add_system(HORDE_SCRIPT)
	weather = _add_system(WEATHER_SCRIPT)
	start_alley = _add_system(ALLEY_SCRIPT)
	player.global_position = start_alley.spawn_point()
	player.outside_position = Vector2(300, 480)

	$HUD.layer = 10
	player.infection_changed.connect(func(v: float) -> void: $HUD/InfectionBar.value = v)
	player.herbs_changed.connect(_on_herbs_changed)
	player.cure_collected.connect(_on_cure_collected)
	player.cures_spent.connect(_on_cures_spent)
	player.all_cures_collected.connect(func() -> void: _show_popup(
		"All 4 ingredients! Brew at the hospital", Color(1.0, 0.88, 0.45)))
	player.won.connect(_on_won)
	player.turned_zombie.connect(_on_player_turned)
	Game.message.connect(show_popup)
	for i in 4:
		var row: HBoxContainer = $HUD/CureList.get_node("Row%d" % i)
		row.get_node("Icon").texture = StackModels.cure_icon(i)
		_set_cure_row(i, false)
	$HUD/HerbsLabel.text = "Herbs: 0  (C eat, R feed)"

	minimap = _add_hud_control(MINIMAP_SCRIPT)
	hud_extras = _add_hud_control(HUD_EXTRAS_SCRIPT)
	end_screen = _add_hud_control(END_SCREEN_SCRIPT)
	end_screen.visible = false
	end_screen.new_game_requested.connect(_new_game)

	retro = RETRO_SCRIPT.new()
	add_child(retro)
	retro.setup(self)


func _add_system(script: Script) -> Node:
	var n := Node.new()
	n.set_script(script)
	add_child(n)
	n.setup(self)
	return n


func _add_hud_control(script: Script) -> Control:
	var c := Control.new()
	c.set_script(script)
	$HUD.add_child(c)
	c.setup(self)
	return c


## Called by the alley exit: spawns the city for the chosen difficulty and drops the player in.
func start_game(difficulty: int) -> void:
	Game.difficulty = difficulty
	Game.started = true
	Game.raining = randf() < 0.3
	if Game.raining:
		Game.say("It's raining. Sounds carry less, but puddles splash.", Color(0.6, 0.75, 1.0))
	fog.set_persistent(difficulty != 2)
	var herb_count: int = DIFFICULTIES[difficulty][0]
	var zombie_mult: float = DIFFICULTIES[difficulty][1]
	_npc_survivor_drain = DIFFICULTIES[difficulty][2]
	player.attack_rate = DIFFICULTIES[difficulty][3]
	_spawn_interval = DIFFICULTIES[difficulty][4]
	_spawn_timer = _spawn_interval
	if Game.perks.get("bonus_chest", false):  # before herbs, so they keep clear of it
		spawn_crate(_visible_spot(Vector2(380, 420)), true)
	_spawn_entities(herb_count, zombie_mult, Vector2(300, 480))  # where the player lands
	_spawn_cure_herbs()
	player.teleport(Vector2(300, 480))
	player.outside_position = Vector2(300, 480)
	player.set_camera_limits(Rect2(-48, -48, 2496, 1536))


func map_rect() -> Rect2:
	return Rect2(0, 0, COLS * CELL, ROWS * CELL)


func _process(delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"player_pos", player.global_position)
	_update_building_xray(delta)
	if not Game.started or player.dead:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval
		_spawn_wave_zombie()


# --- Ground -------------------------------------------------------------------


func _make_ground() -> void:
	_ground_sprite(StackModels.concrete_texture(), Rect2(0, 0, COLS * CELL, ROWS * CELL), -10)
	for park in PARKS:
		_ground_sprite(StackModels.grass_texture(), park, -9)
	for vx in VROADS:
		_ground_sprite(StackModels.road_texture(true), Rect2(vx - ROAD_HALF, 0, 96, ROWS * CELL), -8)
	for hy in HROADS:
		_ground_sprite(StackModels.road_texture(false), Rect2(0, hy - ROAD_HALF, COLS * CELL, 96), -8)


func _ground_sprite(tex: ImageTexture, rect: Rect2, z: int) -> void:
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
	add_child(sprite)


# --- Static city --------------------------------------------------------------


func _make_walls() -> void:
	var width := COLS * CELL
	var height := ROWS * CELL

	var body := StaticBody2D.new()
	add_child(body)
	var bounds: Array[Rect2] = [
		Rect2(-CELL, -CELL, width + 2.0 * CELL, CELL),
		Rect2(-CELL, height, width + 2.0 * CELL, CELL),
		Rect2(-CELL, 0, CELL, height),
		Rect2(width, 0, CELL, height),
	]
	for rect in bounds:
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		collider.position = rect.get_center()
		body.add_child(collider)

	for i in range(-1, COLS + 1):
		_wall_stack(Vector2((i + 0.5) * CELL, -0.5 * CELL))
		_wall_stack(Vector2((i + 0.5) * CELL, (ROWS + 0.5) * CELL))
	for j in ROWS:
		_wall_stack(Vector2(-0.5 * CELL, (j + 0.5) * CELL))
		_wall_stack(Vector2((COLS + 0.5) * CELL, (j + 0.5) * CELL))


func _wall_stack(pos: Vector2) -> void:
	var stack := SpriteStack.new()
	stack.model = &"wall"
	stack.cast_shadow = false
	stack.position = pos
	add_child(stack)


func _make_buildings() -> void:
	# Round towers (design 2) grow 2-4x, shrinking back only as far as roads,
	# map bounds and neighbouring buildings force them to.
	var dims: Array[Vector2i] = []
	var rects: Array[Rect2] = []
	for b in BUILDINGS:
		var dim := Vector2i(b[1], b[2])
		dims.append(dim)
		rects.append(Rect2((b[0] as Vector2) - Vector2(dim) * 2.0, Vector2(dim) * 4.0))
	for i in BUILDINGS.size():
		if int(BUILDINGS[i][4]) != 2:
			continue
		var f := randf_range(2.0, 4.0)
		while f > 1.0 and not _building_fits(BUILDINGS[i][0], Vector2(dims[i]) * f, i, rects):
			f -= 0.25
		if f > 1.0:
			dims[i] = Vector2i((Vector2(dims[i]) * f).floor())
			rects[i] = Rect2((BUILDINGS[i][0] as Vector2) - Vector2(dims[i]) * 2.0, Vector2(dims[i]) * 4.0)

	for i in BUILDINGS.size():
		var b: Array = BUILDINGS[i]
		var center: Vector2 = b[0]
		var w: int = dims[i].x
		var d: int = dims[i].y
		# Buildings are variably 2-4x their base height for a proper skyline.
		var height_layers: int = b[3] * (2 + i % 3)
		var size := Vector2(w * 4.0, d * 4.0)
		var height_px := height_layers * 4.0

		var body := StaticBody2D.new()
		body.position = center
		body.collision_layer = BUILDING_LAYER
		var collider := CollisionShape2D.new()
		if int(b[4]) == 2:
			# Round towers are drawn as ellipses; collide as one too, or their
			# invisible rect corners block the alleys next to them.
			var poly := ConvexPolygonShape2D.new()
			var pts := PackedVector2Array()
			for k in 24:
				var a := TAU * k / 24.0
				pts.append(Vector2(cos(a) * (size.x * 0.5 - 3.0), sin(a) * (size.y * 0.5 - 3.0)))
			poly.points = pts
			collider.shape = poly
		else:
			var shape := RectangleShape2D.new()
			shape.size = size - Vector2(6, 6)
			collider.shape = shape
		body.add_child(collider)

		var mat := ShaderMaterial.new()
		mat.shader = XRAY_SHADER

		var stack := SpriteStack.new()
		stack.cast_shadow = false
		stack.slice_material = mat
		stack.material_from_layer = 8  # ground floors never x-ray: we collide with them
		body.add_child(stack)
		# b[4] picks the design (0-3); color cycles through all 16 wall colors.
		stack.build(StackModels.building(w, d, height_layers, (i * 7 + int(b[4])) % 16, b[4]))
		add_child(body)

		buildings.append({
			index = i,
			body = body,
			stack = stack,
			rect = Rect2(center - size / 2.0, size),
			occluded = Rect2(center.x - size.x / 2.0, center.y - size.y / 2.0 - height_px,
				size.x, size.y + height_px),
			center = center,
			size = size,
			height_px = height_px,
			canvas_w = w,
			canvas_d = d,
			alive = true,
			kind = &"normal",
			mat = mat,
			xray = 0.0,
		})


## True when a building of canvas size `dim` (world size = dim * 4) centered at
## `center` stays on the map, off the roads and keeps a walkable corridor
## (wider than a brute) clear of every other building.
func _building_fits(center: Vector2, dim: Vector2, index: int, rects: Array[Rect2]) -> bool:
	var half := dim * 2.0
	var rect := Rect2(center - half, half * 2.0).grow(60.0)
	if not Rect2(20, 20, COLS * CELL - 40, ROWS * CELL - 40).encloses(rect):
		return false
	for vx in VROADS:
		if rect.position.x < vx + ROAD_HALF + 8.0 and rect.end.x > vx - ROAD_HALF - 8.0:
			return false
	for hy in HROADS:
		if rect.position.y < hy + ROAD_HALF + 8.0 and rect.end.y > hy - ROAD_HALF - 8.0:
			return false
	for j in rects.size():
		if j != index and rect.intersects(rects[j]):
			return false
	return true


## Fades in the see-through circle on any building whose sprite stack is
## currently drawn over the player (player behind it, within its footprint).
func _update_building_xray(delta: float) -> void:
	var p := player.global_position
	for info in buildings:
		if not info.alive:
			continue
		var c: Vector2 = info.center
		var half: Vector2 = info.size / 2.0
		var behind: bool = absf(p.x - c.x) < half.x + 110.0 \
			and p.y < c.y + half.y \
			and p.y > c.y - half.y - info.height_px
		var target := 1.0 if behind else 0.0
		if not is_equal_approx(info.xray, target):
			info.xray = move_toward(info.xray, target, 6.0 * delta)
			info.mat.set_shader_parameter(&"active", info.xray)


func _make_props() -> void:
	for c in CARS:
		var car := CAR_SCRIPT.new()
		car.setup(c[0], c[1], c[2])
		add_child(car)
		register_obstacle(c[0], 46.0)  # the tipped car sprite spans ~84x50
	for vx in VROADS:
		for hy in HROADS:
			for corner: Vector2 in [Vector2(-70, -70), Vector2(70, -70), Vector2(-70, 70), Vector2(70, 70)]:
				var pos := Vector2(vx, hy) + corner
				_add_prop(&"streetlight", pos, (Vector2(vx, hy) - pos).angle(), 5.0, 16.0)
	for pos in TREES:
		if not point_in_building(pos):  # grown round towers can swallow tree spots
			_add_prop(&"tree", pos, 0.0, 7.0, 28.0)


## Records a static item's position and visual footprint radius, so herb
## spawns can keep clear of it.
func register_obstacle(pos: Vector2, radius: float) -> void:
	static_obstacles.append([pos, radius])


func _add_prop(model: StringName, pos: Vector2, rot: float, collision_radius: float,
		footprint_radius: float = -1.0) -> void:
	register_obstacle(pos, maxf(footprint_radius, collision_radius))
	var body := StaticBody2D.new()
	body.position = pos
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = collision_radius
	collider.shape = shape
	body.add_child(collider)

	var stack := SpriteStack.new()
	stack.model = model
	body.add_child(stack)
	stack.stack_rotation = rot
	add_child(body)


# --- Entities -----------------------------------------------------------------


## Spawns the starting entities for the chosen difficulty: zombie count is
## scaled by zombie_mult (extras fan out around the listed spots), and
## herb_count healing herbs are picked evenly from the HERBS list.
func _spawn_entities(herb_count: int, zombie_mult: float, view_center: Vector2) -> void:
	var zombie_total := int(round(ZOMBIES.size() * zombie_mult))
	for n in zombie_total:
		var pos: Vector2
		if zombie_total <= ZOMBIES.size():
			pos = ZOMBIES[n * ZOMBIES.size() / zombie_total]
		else:
			var base: Vector2 = ZOMBIES[n % ZOMBIES.size()]
			pos = base if n < ZOMBIES.size() else _scatter_point(base)
		# Nudge spots that would be on-screen or unfogged; skip if none work.
		var tries := 0
		while not can_spawn_enemy_at(pos, view_center) and tries < 12:
			pos = _scatter_point(pos)
			tries += 1
		if can_spawn_enemy_at(pos, view_center):
			spawn_zombie(pos, _random_variant(), -1, true)
	# Crates go down before herbs, so herb spawns can keep clear of them.
	# One street crate per run is guaranteed to hold a ZMP.
	var zmp_crate := randi() % CRATES.size()
	for i in CRATES.size():
		spawn_crate(_visible_spot(CRATES[i]), false, false, i == zmp_crate)
	for n in herb_count:
		spawn_herb(_visible_spot(HERBS[n * HERBS.size() / herb_count]))


## Mostly walkers; a few runners, brutes and screamers.
func _random_variant() -> StringName:
	var r := randf()
	if r < 0.12:
		return &"runner"
	if r < 0.20:
		return &"brute"
	if r < 0.26:
		return &"screamer"
	return &"walker"


## Enemies may only appear off-screen AND under fog (the horde bypasses this
## with force). Interior zombies live in sealed rooms and are exempt.
## Returns null when the spot breaks the rule.
func spawn_zombie(pos: Vector2, variant: StringName = &"walker", interior_id: int = -1, force: bool = false) -> Node:
	if not force and interior_id == -1 and not can_spawn_enemy_at(pos):
		return null
	var zombie := ZOMBIE_SCENE.instantiate()
	zombie.position = pos
	zombie.variant = variant
	zombie.interior_id = interior_id
	zombie.survivor_infection_rate = _npc_survivor_drain
	add_child(zombie)
	return zombie


## True when pos is outside the camera view (with a margin) and still fogged.
## view_center overrides the camera centre (used before the camera has moved).
func can_spawn_enemy_at(pos: Vector2, view_center: Variant = null) -> bool:
	if fog == null or not fog.is_fogged(pos):
		return false
	var cam: Camera2D = player.camera
	var size: Vector2 = get_viewport_rect().size / cam.zoom
	var center: Vector2 = view_center if view_center != null else cam.get_screen_center_position()
	return not Rect2(center - size * 0.5, size).grow(SPAWN_SCREEN_MARGIN).has_point(pos)


func spawn_herb(pos: Vector2, cure_index: int = -1) -> Node:
	var herb := HERB_SCENE.instantiate()
	herb.cure_index = cure_index
	herb.position = clear_herb_spot(pos)
	add_child(herb)
	return herb


## True when an herb at p sits HERB_CLEARANCE px clear of every static item
## and is not covered by a building.
func herb_spot_clear(p: Vector2) -> bool:
	for o in static_obstacles:
		if p.distance_to(o[0]) < o[1] + HERB_CLEARANCE + HERB_RADIUS:
			return false
	return not point_hidden(p) and not point_in_building(p)


## The nearest spot to pos where an herb is fully visible: rings of candidate
## points spiral outward until one has clearance. Falls back to pos itself.
func clear_herb_spot(pos: Vector2) -> Vector2:
	var p := visible_spot(pos)
	if herb_spot_clear(p):
		return p
	for ring in range(1, 14):
		var r := ring * 16.0
		for k in 12:
			var q := p + Vector2.from_angle(k * TAU / 12.0 + ring * 0.5) * r
			if q.x > 40.0 and q.y > 40.0 and q.x < COLS * CELL - 40.0 \
					and q.y < ROWS * CELL - 40.0 and herb_spot_clear(q):
				return q
	return p


func spawn_crate(pos: Vector2, guaranteed_loot: bool = false, no_clues: bool = false,
		guaranteed_zmp: bool = false) -> Node:
	var crate := CRATE_SCENE.instantiate()
	crate.guaranteed_loot = guaranteed_loot
	crate.no_clues = no_clues
	crate.guaranteed_zmp = guaranteed_zmp
	crate.position = pos
	add_child(crate)
	register_obstacle(crate.position, 26.0)  # 36x36 collider, ~25.5 half-diagonal
	return crate


## A spot near base where an extra zombie can stand (open ground, in bounds).
func _scatter_point(base: Vector2) -> Vector2:
	for attempt in 10:
		var p := base + Vector2.from_angle(randf() * TAU) * randf_range(50.0, 150.0)
		if p.x > 60.0 and p.y > 60.0 and p.x < COLS * CELL - 60.0 and p.y < ROWS * CELL - 60.0 \
				and not point_in_building(p):
			return p
	return base


func _quadrant(i: int) -> Rect2:
	var half_w := COLS * CELL / 2.0
	var half_h := ROWS * CELL / 2.0
	var margin := 70.0
	return Rect2(
		(i % 2) * half_w + margin,
		(i / 2) * half_h + margin,
		half_w - 2.0 * margin,
		half_h - 2.0 * margin
	)


## One cure ingredient per map quadrant, at a random open spot.
func _spawn_cure_herbs() -> void:
	for i in 4:
		spawn_herb(random_open_point(_quadrant(i)), i)


## Re-places a spent cure ingredient in its quadrant.
func respawn_cure(index: int) -> void:
	if index < 0 or index > 3:
		return
	spawn_herb(random_open_point(_quadrant(index)), index)


func random_open_point(rect: Rect2) -> Vector2:
	for attempt in 80:
		var p := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		if herb_spot_clear(p):
			return p
	return visible_spot(rect.get_center())


## True when a building footprint, or the tall stack drawn above it, covers
## this point (standing buildings only) — items here would be invisible.
func point_hidden(pos: Vector2) -> bool:
	for b in buildings:
		if b.alive and (b.occluded as Rect2).grow(24.0).has_point(pos):
			return true
	return false


## Nudges a point south (toward the camera) until no building occludes it;
## occlusion bands only extend north of a building, so south always clears.
func visible_spot(pos: Vector2) -> Vector2:
	var p := pos
	while point_hidden(p) and p.y < ROWS * CELL - 60.0:
		p.y += 24.0
	return p


func _visible_spot(pos: Vector2) -> Vector2:
	return visible_spot(pos)


func point_in_building(pos: Vector2) -> bool:
	for b in buildings:
		if b.alive and (b.rect as Rect2).grow(20.0).has_point(pos):
			return true
	return false


## Every spawn interval a zombie emerges, preferring the nearest fogged
## (unexplored) spot, never inside the player's facing cone; if all fog nearby
## is cleared it falls back to any off-screen point. While the player is
## indoors the origin is where they last stood outside.
func _spawn_wave_zombie() -> void:
	var origin: Vector2 = player.outside_position if player.interior_id != -1 else player.global_position
	var facing: float = player.stack.stack_rotation
	var best_pos := Vector2.ZERO
	var best_score := INF
	for attempt in 32:
		var angle := randf() * TAU
		if player.interior_id == -1 and absf(angle_difference(angle, facing)) < 0.8:
			continue  # not right in front of the player
		var dist := randf_range(420.0, 950.0)
		var pos := origin + Vector2.from_angle(angle) * dist
		if pos.x < 60.0 or pos.y < 60.0 or pos.x > COLS * CELL - 60.0 or pos.y > ROWS * CELL - 60.0:
			continue
		if point_in_building(pos) or not can_spawn_enemy_at(pos):
			continue
		var score: float
		# Hard mode fog never stays cleared, so "fogged" says nothing there:
		# fall back to the off-screen rule instead of always picking the nearest.
		if fog.persistent and fog.is_fogged(pos):
			score = dist  # closest fog wins
		elif dist > 700.0:
			score = dist + 5000.0  # explored but safely off-screen: fallback
		else:
			continue
		if score < best_score:
			best_score = score
			best_pos = pos
	if best_score < INF:
		spawn_zombie(best_pos, _random_variant())


# --- Fog / HUD / endings ------------------------------------------------------


func _make_fog() -> void:
	fog = FogOfWar.new()
	add_child(fog)
	fog.setup(Rect2(-CELL, -CELL, COLS * CELL + 2.0 * CELL, ROWS * CELL + 2.0 * CELL), player)


func _on_herbs_changed(count: int) -> void:
	$HUD/HerbsLabel.text = "Herbs: %d  (C eat, R feed)" % count


func _on_cure_collected(index: int) -> void:
	_set_cure_row(index, true)
	_cures_found += 1
	_show_popup(player.CURE_NAMES[index] + " acquired!", Color(1.0, 0.88, 0.45))


func _on_cures_spent(indices: Array) -> void:
	for i: int in indices:
		_set_cure_row(i, false)
		_cures_found -= 1
	_cures_found = maxi(_cures_found, 0)


## Collected ingredients show full color; missing ones sit dim and ghostly.
func _set_cure_row(index: int, collected: bool) -> void:
	var row: HBoxContainer = $HUD/CureList.get_node("Row%d" % index)
	row.modulate = Color(1, 1, 1, 1) if collected else Color(0.75, 0.75, 0.75, 0.4)


## The human brewed the cure at the hospital.
func _on_won() -> void:
	_end_game("YOU WIN!\nYou brewed the cure! The city is saved!", true, true)


## The player has turned: they now control a zombie and must stop the CPU
## survivor, who inherits the cure progress and hunts the remaining herbs.
func _on_player_turned() -> void:
	_photos.append(minimap.capture_photo())
	_show_popup("You have turned! Stop the survivor!", Color(0.9, 0.3, 0.3))
	$HUD/InfectionLabel.text = "Survivor Infection"
	$HUD/InfectionBar.value = 0.0
	$HUD/HerbsLabel.text = "Herbs: 0"

	_drop_player_items()

	var origin: Vector2 = player.outside_position if player.interior_id != -1 else player.global_position
	var survivor := SURVIVOR_SCENE.instantiate()
	survivor.position = _survivor_spawn_point(origin)
	add_child(survivor)
	_survivor = survivor
	survivor.infection_changed.connect(func(v: float) -> void: $HUD/InfectionBar.value = v)
	survivor.cure_collected.connect(_on_cure_collected)
	survivor.cured.connect(func() -> void:
		_end_game("YOU LOSE\nThe survivor brewed the cure!", false, false))
	# The zombie player finishing the survivor counts as a win and earns the perk.
	survivor.died.connect(func() -> void:
		_end_game("YOU WIN!\nThe survivor has fallen. The plague claims the city.", true, true))


## Everything the player was carrying scatters around the death spot. The
## survivor starts empty-handed, so the dropped pile makes a natural guard
## point for the player zombie.
func _drop_player_items() -> void:
	var drop_pos: Vector2 = player.outside_position if player.interior_id != -1 else player.global_position
	for i in 4:
		if player.cures[i]:
			spawn_herb(visible_spot(drop_pos + Vector2.from_angle(randf() * TAU) * randf_range(36, 70)), i)
			player.cures[i] = false
			_set_cure_row(i, false)
			_cures_found -= 1
	for i in player.herbs:
		spawn_herb(visible_spot(drop_pos + Vector2.from_angle(randf() * TAU) * randf_range(40, 95)))
	player.herbs = 0
	_cures_found = maxi(_cures_found, 0)


## A random open point in the quadrant farthest from `origin`.
func _survivor_spawn_point(origin: Vector2) -> Vector2:
	var best_quad := Rect2()
	var best_d := -1.0
	for i in 4:
		var quad := _quadrant(i)
		var d := quad.get_center().distance_to(origin)
		if d > best_d:
			best_d = d
			best_quad = quad
	return random_open_point(best_quad)


func _end_game(message: String, win: bool, earned: bool) -> void:
	if _ended:
		return
	_ended = true
	_photos.append(minimap.capture_photo())
	var new_perk := ""
	if earned:
		new_perk = Game.record_win(Game.difficulty)
	end_screen.show_result(message, win, _photos, new_perk)
	end_screen.visible = true
	get_tree().paused = true


func _new_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func show_popup(text: String, color: Color) -> void:
	_show_popup(text, color)


func _show_popup(text: String, color: Color) -> void:
	var label: Label = $HUD/HerbPopup
	if _popup_tween:
		_popup_tween.kill()
	label.text = text
	label.visible = true
	label.modulate = Color(color, 0.0)
	_popup_tween = create_tween()
	_popup_tween.tween_property(label, "modulate:a", 1.0, 0.15)
	_popup_tween.tween_interval(1.8)
	_popup_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	_popup_tween.tween_callback(func() -> void: label.visible = false)
