extends Node
## Places payphones near intersections and rings one every 7-9s.

var _phone_count := 2  # 2 or 3 per run, rolled in setup()
const PAYPHONE := preload("res://payphone.gd")

var main
var phones: Array = []
var _timer := 5.0


func setup(m) -> void:
	main = m
	_phone_count = randi_range(2, 3)
	_place()


func _place() -> void:
	var cands: Array[Vector2] = []
	for vx: float in main.VROADS:
		for hy: float in main.HROADS:
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					# beside the vertical road, away from the crossing
					cands.append(Vector2(vx + sx * 82.0, hy + sy * 150.0))
					# beside the horizontal road
					cands.append(Vector2(vx + sx * 150.0, hy + sy * 82.0))
	cands.shuffle()
	var rect: Rect2 = main.map_rect() if main.has_method("map_rect") else Rect2(0, 0, 2400, 1440)
	for c in cands:
		if phones.size() >= _phone_count:
			break
		if not rect.grow(-40.0).has_point(c) or _blocked(c):
			continue
		var too_close := false
		for p in phones:
			if p.position.distance_to(c) < 300.0:
				too_close = true
		if too_close:
			continue
		var ph := PAYPHONE.new()
		ph.position = c
		main.add_child(ph)
		phones.append(ph)


func _blocked(c: Vector2) -> bool:
	for off in [Vector2.ZERO, Vector2(18, 0), Vector2(-18, 0), Vector2(0, 18), Vector2(0, -18)]:
		var p: Vector2 = c + off
		if main.point_in_building(p) or main.point_hidden(p):
			return true
	# keep off roads (centers +-48) and streetlights (intersection +-70)
	for vx: float in main.VROADS:
		if absf(c.x - vx) < 62.0:
			return true
	for hy: float in main.HROADS:
		if absf(c.y - hy) < 62.0:
			return true
	# keep a walkable gap to signs, trash cans and dumpsters
	var d = main.get("districts")
	if d != null and d.get("solids") != null:
		for s: Vector2 in d.solids:
			if c.distance_to(s) < 75.0:
				return true
	return false


func _process(delta: float) -> void:
	if not Game.started or main == null or phones.is_empty():
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = randf_range(7.0, 9.0)
	for p in phones:
		if is_instance_valid(p) and (p.ringing or p.in_call):
			return
	var pool: Array = []
	var near: Array = []
	var player: Node2D = main.player
	for p in phones:
		if not is_instance_valid(p):
			continue
		pool.append(p)
		if player and p.global_position.distance_to(player.global_position) < 900.0:
			near.append(p)
	var pick: Array = near if not near.is_empty() else pool
	if not pick.is_empty():
		pick.pick_random().ring()
