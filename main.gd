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
const MAX_ZOMBIES := 35

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
]

@onready var player: CharacterBody2D = $Player

var _fog: FogOfWar
var _building_rects: Array[Rect2] = []
var _zombie_count: int = 0
var _spawn_timer: float = SPAWN_INTERVAL
var _popup_tween: Tween
var _cures_found: int = 0


func _ready() -> void:
	_make_ground()
	_make_walls()
	_make_buildings()
	_make_props()
	_spawn_entities()
	_spawn_cure_herbs()
	_make_fog()
	player.infection_changed.connect(func(v: float) -> void: $HUD/InfectionBar.value = v)
	player.herbs_changed.connect(_on_herb_collected)
	player.cure_collected.connect(_on_cure_collected)
	player.won.connect(_on_won)
	player.turned_zombie.connect(_on_player_turned)
	$HUD/EndScreen/Panel/Margin/VBox/NewGameButton.pressed.connect(_new_game)
	for i in 4:
		var row: HBoxContainer = $HUD/CureList.get_node("Row%d" % i)
		row.get_node("Icon").texture = StackModels.cure_icon(i)
		_set_cure_row(i, false)


func _process(delta: float) -> void:
	if player.dead:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = SPAWN_INTERVAL
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
	for b in BUILDINGS:
		var center: Vector2 = b[0]
		var w: int = b[1]
		var d: int = b[2]
		var size := Vector2(w * 4.0, d * 4.0)
		_building_rects.append(Rect2(center - size / 2.0, size))

		var body := StaticBody2D.new()
		body.position = center
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = size - Vector2(6, 6)
		collider.shape = shape
		body.add_child(collider)

		var stack := SpriteStack.new()
		stack.cast_shadow = false
		body.add_child(stack)
		stack.build(StackModels.building(w, d, b[3], b[4]))
		add_child(body)


func _make_props() -> void:
	for c in CARS:
		_add_car(c[0], c[1], c[2])
	for vx in VROADS:
		for hy in HROADS:
			for corner: Vector2 in [Vector2(-70, -70), Vector2(70, -70), Vector2(-70, 70), Vector2(70, 70)]:
				var pos := Vector2(vx, hy) + corner
				_add_prop(&"streetlight", pos, (Vector2(vx, hy) - pos).angle(), 5.0)
	for pos in TREES:
		_add_prop(&"tree", pos, 0.0, 7.0)


func _add_car(pos: Vector2, rot: float, color_index: int) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(72, 38)
	collider.shape = shape
	collider.rotation = rot
	body.add_child(collider)

	var stack := SpriteStack.new()
	body.add_child(stack)
	stack.build(StackModels.car(color_index))
	stack.stack_rotation = rot
	add_child(body)


func _add_prop(model: StringName, pos: Vector2, rot: float, collision_radius: float) -> void:
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


func _spawn_entities() -> void:
	for pos in ZOMBIES:
		_spawn_zombie(pos)
	for pos in HERBS:
		var herb := HERB_SCENE.instantiate()
		herb.position = pos
		add_child(herb)
	for pos in CRATES:
		var crate := CRATE_SCENE.instantiate()
		crate.position = pos
		add_child(crate)


## One cure ingredient per map quadrant, at a random open spot.
func _spawn_cure_herbs() -> void:
	var half_w := COLS * CELL / 2.0
	var half_h := ROWS * CELL / 2.0
	var margin := 70.0
	for i in 4:
		var quad := Rect2(
			(i % 2) * half_w + margin,
			(i / 2) * half_h + margin,
			half_w - 2.0 * margin,
			half_h - 2.0 * margin
		)
		var herb := HERB_SCENE.instantiate()
		herb.cure_index = i
		herb.position = _random_open_point(quad)
		add_child(herb)


func _random_open_point(rect: Rect2) -> Vector2:
	for attempt in 80:
		var p := Vector2(
			randf_range(rect.position.x, rect.end.x),
			randf_range(rect.position.y, rect.end.y)
		)
		if not _point_in_building(p):
			return p
	return rect.get_center()


func _spawn_zombie(pos: Vector2) -> void:
	var zombie := ZOMBIE_SCENE.instantiate()
	zombie.position = pos
	add_child(zombie)
	_zombie_count += 1
	zombie.tree_exited.connect(func() -> void: _zombie_count -= 1)


## Every SPAWN_INTERVAL seconds a zombie emerges, preferring the nearest
## fogged (unexplored) spot, never inside the player's facing cone; if all
## fog nearby is cleared it falls back to any off-screen point.
func _spawn_wave_zombie() -> void:
	if _zombie_count >= MAX_ZOMBIES:
		return
	var facing: float = player.stack.stack_rotation
	var best_pos := Vector2.ZERO
	var best_score := INF
	for attempt in 32:
		var angle := randf() * TAU
		if absf(angle_difference(angle, facing)) < 0.8:
			continue  # not right in front of the player
		var dist := randf_range(420.0, 950.0)
		var pos := player.global_position + Vector2.from_angle(angle) * dist
		if pos.x < 60.0 or pos.y < 60.0 or pos.x > COLS * CELL - 60.0 or pos.y > ROWS * CELL - 60.0:
			continue
		if _point_in_building(pos):
			continue
		var score: float
		if _fog.is_fogged(pos):
			score = dist  # closest fog wins
		elif dist > 700.0:
			score = dist + 5000.0  # explored but safely off-screen: fallback
		else:
			continue
		if score < best_score:
			best_score = score
			best_pos = pos
	if best_score < INF:
		_spawn_zombie(best_pos)


func _point_in_building(pos: Vector2) -> bool:
	for rect in _building_rects:
		if rect.grow(20.0).has_point(pos):
			return true
	return false


# --- Fog / game over ----------------------------------------------------------


func _make_fog() -> void:
	_fog = FogOfWar.new()
	add_child(_fog)
	_fog.setup(Rect2(-CELL, -CELL, COLS * CELL + 2.0 * CELL, ROWS * CELL + 2.0 * CELL), player)


# --- HUD / endings ---------------------------------------------------------------


func _on_herb_collected(count: int) -> void:
	$HUD/HerbsLabel.text = "Herbs: %d" % count
	_show_popup("Healing Herb", Color(0.55, 0.9, 0.5))


func _on_cure_collected(index: int) -> void:
	_set_cure_row(index, true)
	_cures_found += 1
	$HUD/CureList/CureTitle.text = "Cure Ingredients: %d / 4" % _cures_found
	_show_popup(player.CURE_NAMES[index] + " acquired!", Color(1.0, 0.88, 0.45))


func _set_cure_row(index: int, collected: bool) -> void:
	var row: HBoxContainer = $HUD/CureList.get_node("Row%d" % index)
	row.get_node("Name").text = ("✔ " if collected else "") + player.CURE_NAMES[index]
	row.modulate = Color(1, 1, 1, 1) if collected else Color(0.75, 0.75, 0.75, 0.4)


func _on_won() -> void:
	_end_game("YOU WIN!\nYou completed the cure! The city is saved!", true)


## The player has turned: they now control a zombie and must stop the CPU
## survivor, who inherits the cure progress and hunts the remaining herbs.
func _on_player_turned() -> void:
	_show_popup("You have turned! Stop the survivor!", Color(0.9, 0.3, 0.3))
	$HUD/InfectionLabel.text = "Survivor Infection"
	$HUD/InfectionBar.value = 0.0

	_drop_player_items()

	var survivor := SURVIVOR_SCENE.instantiate()
	survivor.position = _survivor_spawn_point()
	add_child(survivor)
	survivor.infection_changed.connect(func(v: float) -> void: $HUD/InfectionBar.value = v)
	survivor.cure_collected.connect(_on_cure_collected)
	survivor.cured.connect(func() -> void:
		_end_game("YOU LOSE\nThe survivor completed the cure!", false))
	survivor.died.connect(func() -> void:
		_end_game("YOU WIN!\nThe survivor has fallen. The plague claims the city.", true))


## Everything the player was carrying scatters around the death spot. The
## survivor starts empty-handed, so the dropped pile makes a natural guard
## point for the player zombie.
func _drop_player_items() -> void:
	var drop_pos := player.global_position
	for i in 4:
		if player.cures[i]:
			var herb := HERB_SCENE.instantiate()
			herb.cure_index = i
			herb.position = drop_pos + Vector2.from_angle(randf() * TAU) * randf_range(36, 70)
			add_child(herb)
			player.cures[i] = false
			_set_cure_row(i, false)
			_cures_found -= 1
	for i in player.herbs:
		var heal := HERB_SCENE.instantiate()
		heal.position = drop_pos + Vector2.from_angle(randf() * TAU) * randf_range(40, 95)
		add_child(heal)
	player.herbs = 0
	$HUD/HerbsLabel.text = "Herbs: 0"
	$HUD/CureList/CureTitle.text = "Cure Ingredients: %d / 4" % _cures_found


## A random open point in the quadrant farthest from the player.
func _survivor_spawn_point() -> Vector2:
	var half_w := COLS * CELL / 2.0
	var half_h := ROWS * CELL / 2.0
	var margin := 70.0
	var best_quad := Rect2()
	var best_d := -1.0
	for i in 4:
		var quad := Rect2(
			(i % 2) * half_w + margin,
			(i / 2) * half_h + margin,
			half_w - 2.0 * margin,
			half_h - 2.0 * margin
		)
		var d := quad.get_center().distance_to(player.global_position)
		if d > best_d:
			best_d = d
			best_quad = quad
	return _random_open_point(best_quad)


func _end_game(message: String, win: bool) -> void:
	var label: Label = $HUD/EndScreen/Panel/Margin/VBox/ResultLabel
	label.text = message
	label.add_theme_color_override("font_color",
		Color(0.35, 0.9, 0.45) if win else Color(0.9, 0.3, 0.3))
	$HUD/EndScreen.visible = true
	get_tree().paused = true


func _new_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_popup(text: String, color: Color) -> void:
	var label: Label = $HUD/HerbPopup
	if _popup_tween:
		_popup_tween.kill()
	label.text = text
	label.visible = true
	label.modulate = Color(color, 0.0)
	_popup_tween = create_tween()
	_popup_tween.tween_property(label, "modulate:a", 1.0, 0.15)
	_popup_tween.tween_interval(1.3)
	_popup_tween.tween_property(label, "modulate:a", 0.0, 0.5)
	_popup_tween.tween_callback(func() -> void: label.visible = false)
