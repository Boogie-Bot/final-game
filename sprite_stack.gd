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
		for i in _slices.size():
			_slices[i].position.y = -i * pixel_scale + value

var _frames: Array = []
var _slices: Array[Sprite2D] = []
var _shadow: Sprite2D
var _frame: int = 0
var _walk_time: float = 0.0


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
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * pixel_scale
		s.position = Vector2(0, -i * pixel_scale + bob_offset)
		s.rotation = stack_rotation
		add_child(s)
		_slices.append(s)


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
