extends Node
## Every 30s a siren sounds and 50-80 zombies run down one whole road.

const INTERVAL := 30.0
const COUNT_MIN := 50
const COUNT_MAX := 80
const RUNNER_CHANCE := 0.25
const SPAWN_GAP := 0.05

var main
var _timer := INTERVAL
var _road := {}  # {vertical: bool, index: int, forward: bool}


func setup(m) -> void:
	main = m
	_pick_next()


func _pick_next() -> void:
	var vertical := randf() < 0.5
	var count: int = main.VROADS.size() if vertical else main.HROADS.size()
	_road = {vertical = vertical, index = randi() % count, forward = randf() < 0.5}


func _process(delta: float) -> void:
	if not Game.started or main == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		_launch()


func next_road_name() -> String:
	if _road.is_empty():
		return "the main road"
	var names: Array[String] = Game.VROAD_NAMES if _road.vertical else Game.HROAD_NAMES
	return names[_road.index]


func time_until_next() -> float:
	return _timer


func _ends(road: Dictionary) -> Array[Vector2]:
	var rect: Rect2 = main.map_rect() if main.has_method("map_rect") else Rect2(0, 0, 2400, 1440)
	var a: Vector2
	var b: Vector2
	if road.vertical:
		var x: float = main.VROADS[road.index]
		a = Vector2(x, rect.position.y + 20.0)
		b = Vector2(x, rect.end.y - 20.0)
	else:
		var y: float = main.HROADS[road.index]
		a = Vector2(rect.position.x + 20.0, y)
		b = Vector2(rect.end.x - 20.0, y)
	if not road.forward:
		return [b, a]
	return [a, b]


func next_road_start() -> Vector2:
	if _road.is_empty():
		return Vector2.ZERO
	return _ends(_road)[0]


func _launch() -> void:
	var road := _road
	_pick_next()
	var ends := _ends(road)
	var start := ends[0]
	var finish := ends[1]
	var dir := (finish - start).normalized()
	var side := dir.orthogonal()
	Sfx.play(&"siren")
	Game.say("SIREN! A horde is coming down %s!" % _name_of(road), Color(1.0, 0.25, 0.2))
	for i in randi_range(COUNT_MIN, COUNT_MAX):
		if not is_inside_tree():
			return
		var pos := start + side * randf_range(-34.0, 34.0) - dir * randf_range(0.0, 20.0)
		var variant: StringName = &"runner" if randf() < RUNNER_CHANCE else &"walker"
		var z = main.spawn_zombie(pos, variant, -1, true)  # the horde ignores the spawn rules
		if z != null and z.has_method("set_horde_path"):
			z.set_horde_path(PackedVector2Array([pos, finish + side * (pos - start).dot(side)]))
		await get_tree().create_timer(SPAWN_GAP).timeout


func _name_of(road: Dictionary) -> String:
	var names: Array[String] = Game.VROAD_NAMES if road.vertical else Game.HROAD_NAMES
	return names[road.index]
