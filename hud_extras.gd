extends Control
## Extra HUD widgets: stamina, inventory, serum timer, brew progress, horde
## countdown, district name, rain indicator, the herb-clue arrow, the Escape
## pause menu (controls) and (as a zombie) the roar cooldown. All hidden until
## the run actually starts.

const ITEM_ORDER: Array[StringName] = [&"bottle", &"tonic", &"zmp"]
const ROAR_COOLDOWN := 10.0
const ARROW_TIME := 3.0  # herb-clue arrow: 3 pulses over 3 seconds

const CONTROLS_TEXT := """WASD  move      Shift  sprint
Space  enter door / open crate / shove
E  interact
Q  throw bottle ahead
R  feed herb to zombie
C  eat herb     F  detonate ZMP
F1  80's mode

AS A ZOMBIE
Space  roar     Shift  lunge"""

var _main = null
var _player = null
var _stamina_bar: ProgressBar
var _inv_row: HBoxContainer
var _inv_counts: Dictionary = {}  # item -> Label
var _inv_boxes: Dictionary = {}  # item -> HBoxContainer
var _serum_bar: ProgressBar
var _serum_max: float = 1.0
var _brew_box: VBoxContainer
var _brew_bar: ProgressBar
var _horde_label: Label
var _district_label: Label
var _rain_label: Label
var _roar_box: VBoxContainer
var _arrow: Control
var _arrow_target := Vector2.ZERO
var _arrow_time := 0.0
var _menu: Control
var _menu_open := false
var _roar_bar: ProgressBar
var _roar_max: float = ROAR_COOLDOWN
var _human_widgets: Array[Control] = []
var _horde_timer: float = 0.0


func setup(main: Node) -> void:
	_main = main
	_player = main.player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS  # the pause menu must work while paused
	_build()
	Game.brew_progress.connect(_on_brew)
	Game.district_changed.connect(_on_district)
	Game.herb_hint.connect(_on_herb_hint)
	if _player:
		_connect_player()
	_on_inventory({})
	_refresh_mode()
	visible = false


func _build() -> void:
	# Top-center stack, under the infection bar / herbs label (ends y 100).
	_stamina_bar = _make_bar(Vector2.ZERO, Vector2(220, 12), Color(0.35, 0.85, 0.4))
	_center_top(_stamina_bar, 112.0, 110.0, 12.0)
	var stam_label := _make_label("STAMINA", 10, Color(1, 1, 1, 0.85))
	stam_label.position = Vector2(226, -1)
	_stamina_bar.add_child(stam_label)
	_human_widgets.append(_stamina_bar)

	_inv_row = HBoxContainer.new()
	_inv_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_inv_row.add_theme_constant_override("separation", 14)
	add_child(_inv_row)
	_center_top(_inv_row, 130.0, 110.0, 24.0)
	for item: StringName in [&"herb"] + ITEM_ORDER:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		var icon := TextureRect.new()
		icon.texture = StackModels.item_icon(item)
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(icon)
		var lbl := _make_label("x0", 16, Color.WHITE)
		box.add_child(lbl)
		_inv_row.add_child(box)
		_inv_counts[item] = lbl
		_inv_boxes[item] = box
	_human_widgets.append(_inv_row)

	_serum_bar = _make_bar(Vector2.ZERO, Vector2(220, 10), Color(0.5, 0.8, 1.0))
	_center_top(_serum_bar, 162.0, 110.0, 10.0)
	var serum_label := _make_label("SERUM", 10, Color(0.7, 0.9, 1.0))
	_serum_bar.add_child(serum_label)
	serum_label.position = Vector2(226, -3)
	_serum_bar.visible = false

	# Top center: horde countdown and brew progress.
	_horde_label = _make_label("", 20, Color(1.0, 0.45, 0.35))
	_horde_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_horde_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_horde_label.visible = false
	add_child(_horde_label)
	_pin(_horde_label, Control.PRESET_CENTER_TOP, 6)

	_brew_box = VBoxContainer.new()
	_brew_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_brew_box.visible = false
	var brew_title := _make_label("Brewing the cure...", 16, Color(0.6, 1.0, 0.7))
	brew_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brew_box.add_child(brew_title)
	_brew_bar = ProgressBar.new()
	_style_bar(_brew_bar, Color(0.4, 0.95, 0.55))
	_brew_bar.custom_minimum_size = Vector2(300, 14)
	_brew_box.add_child(_brew_bar)
	add_child(_brew_box)
	_pin(_brew_box, Control.PRESET_CENTER_TOP, 180)

	# Bottom right, above the minimap: district + rain.
	_district_label = _make_label("", 16, Color.WHITE)
	_district_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_district_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_district_label)
	_pin(_district_label, Control.PRESET_BOTTOM_RIGHT, 12, -216)
	_rain_label = _make_label("Rain", 14, Color(0.6, 0.75, 1.0))
	_rain_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_rain_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_rain_label)
	_pin(_rain_label, Control.PRESET_BOTTOM_RIGHT, 12, -238)

	# Herb-clue arrow: points from screen center toward the hinted herb.
	_arrow = Control.new()
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.visible = false
	add_child(_arrow)
	_arrow.draw.connect(_draw_arrow)

	_build_menu()

	# Zombie mode: roar cooldown, bottom center.
	_roar_box = VBoxContainer.new()
	_roar_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_roar_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var roar_label := _make_label("Space: Roar    Shift: Lunge", 16, Color(1.0, 0.5, 0.45))
	roar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_roar_box.add_child(roar_label)
	_roar_bar = ProgressBar.new()
	_style_bar(_roar_bar, Color(0.9, 0.25, 0.2))
	_roar_bar.custom_minimum_size = Vector2(220, 10)
	_roar_bar.max_value = 1.0
	_roar_bar.value = 1.0
	_roar_box.add_child(_roar_bar)
	_roar_box.visible = false
	add_child(_roar_box)
	_pin(_roar_box, Control.PRESET_CENTER_BOTTOM, 16)


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _make_bar(pos: Vector2, size_px: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	_style_bar(b, color)
	b.position = pos
	b.custom_minimum_size = size_px
	b.size = size_px
	add_child(b)
	return b


func _style_bar(b: ProgressBar, color: Color) -> void:
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.07, 0.8)
	bg.set_border_width_all(1)
	bg.border_color = Color(1, 1, 1, 0.35)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)


func _connect_player() -> void:
	var p = _player
	if p.has_signal("stamina_changed"):
		p.stamina_changed.connect(_on_stamina)
		_on_stamina(p.stamina, p.max_stamina)
	if p.has_signal("inventory_changed"):
		p.inventory_changed.connect(_on_inventory)
		_on_inventory(p.inventory)
	if p.has_signal("serum_changed"):
		p.serum_changed.connect(_on_serum)
	if p.has_signal("cooldowns_changed"):
		p.cooldowns_changed.connect(_on_cooldowns)
	if p.has_signal("turned_zombie"):
		p.turned_zombie.connect(_refresh_mode)
	if p.has_signal("herbs_changed"):
		p.herbs_changed.connect(func(_n: int) -> void: _on_inventory(_player.inventory))


func _on_stamina(value: float, max_value: float) -> void:
	_stamina_bar.max_value = max_value
	_stamina_bar.value = value


func _on_inventory(inv: Dictionary) -> void:
	for item: StringName in ITEM_ORDER:
		var n: int = int(inv.get(item, 0))
		_inv_counts[item].text = "x%d" % n
		_inv_boxes[item].visible = n > 0
	var herbs: int = int(_player.herbs) if _player else 0
	_inv_counts[&"herb"].text = "x%d" % herbs
	_inv_boxes[&"herb"].visible = herbs > 0


func _on_serum(time_left: float) -> void:
	_serum_max = maxf(_serum_max, time_left)
	if time_left <= 0.0:
		_serum_max = 1.0
	_serum_bar.visible = time_left > 0.0 and not _is_zombie()
	_serum_bar.max_value = _serum_max
	_serum_bar.value = time_left


func _on_cooldowns(_shove_left: float, roar_left: float) -> void:
	_roar_max = maxf(_roar_max, roar_left)
	_roar_bar.max_value = _roar_max
	_roar_bar.value = _roar_max - roar_left


func _on_brew(value: float, max_value: float, active: bool) -> void:
	_brew_box.visible = Game.started and (active or value > 0.0)
	_brew_bar.max_value = maxf(max_value, 0.001)
	_brew_bar.value = value


func _on_district(district_name: String) -> void:
	var idx: int = Game.DISTRICT_NAMES.find(district_name)
	_district_label.text = district_name
	_district_label.add_theme_color_override("font_color",
		Game.DISTRICT_COLORS[idx] if idx >= 0 else Color.WHITE)


func _is_zombie() -> bool:
	return _player != null and _player.is_zombie


func _refresh_mode() -> void:
	var z := _is_zombie()
	for w in _human_widgets:
		w.visible = not z
	_roar_box.visible = z
	if z:
		_serum_bar.visible = false


func _process(delta: float) -> void:
	var show_all: bool = Game.started
	if visible != show_all:
		visible = show_all
	if not show_all:
		return
	if _arrow_time > 0.0 and not _menu_open:
		_arrow_time -= delta
		_update_arrow()
	_rain_label.visible = Game.raining
	_horde_timer -= delta
	if _horde_timer <= 0.0:
		_horde_timer = 0.25
		var horde = _main.get("horde")
		if horde != null and horde.has_method("time_until_next"):
			var t: float = horde.time_until_next()
			_horde_label.visible = t >= 0.0
			_horde_label.text = "Horde in %ds" % int(ceil(t))
			_horde_label.add_theme_color_override("font_color",
				Color(1.0, 0.25, 0.2) if t < 6.0 else Color(1.0, 0.6, 0.4))
		else:
			_horde_label.visible = false
		if _is_zombie() != _roar_box.visible:
			_refresh_mode()


## Anchors a control to a screen edge/corner with a margin (plain `position`
## ignores anchors, which flung these widgets to the top-left). extra_y shifts
## it vertically, e.g. to stack above the minimap.
func _pin(c: Control, preset: Control.LayoutPreset, margin: int, extra_y: float = 0.0) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.offset_top += extra_y
	c.offset_bottom += extra_y


## Centers a control horizontally (half_w each side) at `y` from the top.
func _center_top(c: Control, y: float, half_w: float, h: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.offset_left = -half_w
	c.offset_right = half_w
	c.offset_top = y
	c.offset_bottom = y + h


# --- Herb-clue arrow -------------------------------------------------------------

func _on_herb_hint(pos: Vector2) -> void:
	_arrow_target = pos
	_arrow_time = ARROW_TIME
	_update_arrow()


func _update_arrow() -> void:
	var player = _main.player
	if _arrow_time <= 0.0 or player == null or not is_instance_valid(player) or _is_zombie():
		_arrow_time = 0.0
		_arrow.visible = false
		return
	var vp := get_viewport_rect().size
	var dir: Vector2 = _arrow_target - player.global_position
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	_arrow.position = vp * 0.5 + dir * (minf(vp.x, vp.y) * 0.5 - 70.0)
	_arrow.rotation = dir.angle()
	# Three pulses over the three seconds, fading out at the end.
	var t := ARROW_TIME - _arrow_time
	var pulse := 0.5 - 0.5 * cos(TAU * t)
	_arrow.scale = Vector2.ONE * (1.0 + 0.5 * pulse)
	_arrow.modulate.a = clampf(_arrow_time / 0.35, 0.0, 1.0)
	_arrow.visible = true
	_arrow.queue_redraw()


func _draw_arrow() -> void:
	var body := PackedVector2Array([
		Vector2(26, 0), Vector2(2, -17), Vector2(2, -7), Vector2(-22, -7),
		Vector2(-22, 7), Vector2(2, 7), Vector2(2, 17),
	])
	_arrow.draw_colored_polygon(body, Color(0.25, 0.95, 0.35))
	var outline := body.duplicate()
	outline.append(body[0])
	_arrow.draw_polyline(outline, Color(0, 0, 0, 0.9), 2.0)


# --- Escape pause menu -----------------------------------------------------------

func _build_menu() -> void:
	_menu = Control.new()
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	add_child(_menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.85, 0.85, 0.9)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := _make_label("PAUSED - CONTROLS", 22, Color(1.0, 0.9, 0.5))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_make_label(CONTROLS_TEXT, 15, Color(0.85, 0.95, 1.0)))
	var hint := _make_label("Esc  resume", 13, Color(1, 1, 1, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or not Game.started:
		return
	# Don't fight other pause sources (the end screen pauses the tree too).
	if get_tree().paused and not _menu_open:
		return
	_menu_open = not _menu_open
	_menu.visible = _menu_open
	get_tree().paused = _menu_open
	get_viewport().set_input_as_handled()
