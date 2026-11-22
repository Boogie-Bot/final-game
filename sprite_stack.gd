class_name SpriteStack
extends Node2D
## Renders a fake-3D "sprite stacked" object: a pile of horizontal slice
## textures, each drawn 1 (scaled) pixel above the previous one. Rotating
## stack_rotation spins every slice in place, which reads as a 3D rotation
## from the top-down camera while the world itself stays fixed.
## Supports multi-frame models (walk cycles) via set_frame/play_walk.

@export var model: StringName = &""
@export var pixel_scale: float = 4.0
@export var cast_shadow: bool = true

## Optional material applied to slices (not the shadow); set before build().
## Slices below material_from_layer keep the default material, so a building's
## collidable base stays visible even when the x-ray shader cuts the upper
## floors away.
var slice_material: Material
var material_from_layer: int = 0

var stack_rotation: float = 0.0:
	set(value):
		stack_rotation = value
		for s in _slices:
			s.rotation = value
		if _shadow:
			_shadow.rotation = value

## Vertical offset applied to the slices only, so the shadow stays grounded.
## Used for walk bobbing and floating items.
var bob_offset: float = 0.0:
	set(value):
		bob_offset = value
		if _topple_t <= 0.0:  # bobbing is ignored while toppled; rise() re-applies it
			for i in _slices.size():
				_slices[i].position.y = -i * pixel_scale + value

var _frames: Array = []
var _slices: Array[Sprite2D] = []
var _shadow: Sprite2D
var _frame: int = 0
var _walk_time: float = 0.0
var _topple_t: float = 0.0  # 0 = upright, 1 = lying flat toward _topple_dir
var _topple_dir := Vector2.DOWN
var _topple_tween: Tween


func _ready() -> void:
	if model != &"":
		build(StackModels.get_frames(model))


func build(frames: Array) -> void:
	for child in get_children():
		child.queue_free()
	_slices.clear()
	_shadow = null
	_frames = frames
	_frame = 0
	if frames.is_empty() or frames[0].is_empty():
		return
	var base: Array = frames[0]

	if cast_shadow:
		_shadow = Sprite2D.new()
		_shadow.texture = StackModels.shadow_texture(base[0].get_width(), base[0].get_height())
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_shadow.scale = Vector2.ONE * pixel_scale
		_shadow.position = Vector2(0, 2)
		_shadow.rotation = stack_rotation
		add_child(_shadow)

	for i in base.size():
		var s := Sprite2D.new()
		s.texture = base[i]
		if i >= material_from_layer:
			s.material = slice_material
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * pixel_scale
		s.position = Vector2(0, -i * pixel_scale + bob_offset)
		s.rotation = stack_rotation
		add_child(s)
		_slices.append(s)
	if _topple_t > 0.0:
		_apply_topple()


func set_frame(index: int) -> void:
	if _frames.size() < 2:
		return
	index = index % _frames.size()
	if index == _frame:
		return
	_frame = index
	var textures: Array = _frames[index]
	for i in _slices.size():
		_slices[i].texture = textures[i]


## Advances the walk cycle; call every frame while moving.
func play_walk(delta: float, fps: float = 9.0) -> void:
	_walk_time += delta * fps
	set_frame(int(_walk_time))


## Returns to the neutral standing frame.
func stand() -> void:
	_walk_time = 0.0
	set_frame(1)


## Flattens the stack to the ground (used for the player's death).
func collapse() -> void:
	var tween := create_tween().set_parallel(true)
	for s in _slices:
		tween.tween_property(s, "position:y", 0.0, 0.4).set_ease(Tween.EASE_IN)


# --- Animation API (stubs; the zombie-AI agent implements these) ----------------

## Read-only access to the slice sprites (bottom first).
func get_slices() -> Array[Sprite2D]:
	return _slices


## Tips the stack over toward world-space `direction` over `duration` seconds
## (knockdowns, collapsing buildings). Returns the Tween so callers can await it.
## Slice i slides along direction * i * pixel_scale * t while its vertical lift
## shrinks by t, so the whole pile lays down toward `direction`.
func topple(direction: Vector2, duration: float) -> Tween:
	if _topple_tween:
		_topple_tween.kill()
	if direction.length_squared() > 0.0001:
		_topple_dir = direction.normalized()
	_topple_tween = create_tween()
	_topple_tween.tween_method(_set_topple, _topple_t, 1.0, maxf(duration, 0.01))
	return _topple_tween


## Stands a toppled/collapsed stack back up over `duration` seconds.
func rise(duration: float) -> Tween:
	if _topple_tween:
		_topple_tween.kill()
	_topple_tween = create_tween()
	_topple_tween.tween_method(_set_topple, _topple_t, 0.0, maxf(duration, 0.01))
	return _topple_tween


func _set_topple(t: float) -> void:
	_topple_t = t
	_apply_topple()


## Repositions every slice for the current topple progress (also the upright
## pose, including bob_offset, when progress is 0).
func _apply_topple() -> void:
	var t := _topple_t
	var lift := 1.0 - t
	var slide := _topple_dir * pixel_scale * t
	for i in _slices.size():
		_slices[i].position = Vector2(slide.x * i, slide.y * i - i * pixel_scale * lift + bob_offset * lift)
