extends Node2D
## Infection trail: survivors leave glowing footprints that zombies can follow.

const STEP := 26.0
const LIFE := 18.0  # visual lifetime: long tail at constant alpha, then a fade
const TRACK_LIFE := 10.0  # zombies only follow prints younger than this
const FADE_START := 0.65  # fraction of LIFE where the fade-out begins
const BASE_ALPHA := 0.5
const MAX_PRINTS := 400

var _prints: Array[Dictionary] = []  # {node: Sprite2D, born: float}
var _last: Dictionary = {}  # instance_id -> last print position
var _side: Dictionary = {}  # instance_id -> bool


func _ready() -> void:
	z_index = -5


func setup(_main) -> void:
	pass


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if not Game.started:
		return
	var now := _now()
	for body in get_tree().get_nodes_in_group(&"survivor"):
		if not (body is Node2D) or body.get("is_zombie") == true:
			continue
		var id: int = body.get_instance_id()
		var pos: Vector2 = body.global_position
		if not _last.has(id):
			_last[id] = pos
			_side[id] = false
			continue
		var from: Vector2 = _last[id]
		var dist := from.distance_to(pos)
		if dist > 400.0:  # teleported (interior, start)
			_last[id] = pos
			continue
		if dist >= STEP:
			var dir := (pos - from) / dist
			_side[id] = not _side[id]
			var left: bool = _side[id]
			var perp := dir.orthogonal() * (5.0 if left else -5.0)
			_drop(pos + perp, dir.angle(), left, now)
			_last[id] = pos
	var i := 0
	while i < _prints.size():
		var p: Dictionary = _prints[i]
		var age := now - float(p.born)
		var node: Sprite2D = p.node
		if age >= LIFE or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_prints.remove_at(i)
			continue
		node.modulate.a = BASE_ALPHA * clampf((1.0 - age / LIFE) / (1.0 - FADE_START), 0.0, 1.0)
		i += 1


func _drop(pos: Vector2, ang: float, left: bool, now: float) -> void:
	var s := Sprite2D.new()
	s.texture = StackModels.footprint_texture(left)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2.ONE * 4.0
	s.global_position = pos
	s.rotation = ang
	add_child(s)
	_prints.append({node = s, born = now})
	if _prints.size() > MAX_PRINTS:
		var old: Dictionary = _prints.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()


## Newest print younger than TRACK_LIFE within radius, or {}.
func freshest_near(pos: Vector2, radius: float) -> Dictionary:
	var now := _now()
	var best := {}
	var best_born := -1.0
	for p in _prints:
		var node: Sprite2D = p.node
		if not is_instance_valid(node) or now - float(p.born) >= TRACK_LIFE:
			continue
		if node.global_position.distance_to(pos) <= radius and float(p.born) > best_born:
			best_born = p.born
			best = {pos = node.global_position, born = p.born}
	return best
