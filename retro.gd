extends CanvasLayer
## 80's mode (F1 / RetroToggle): a synthwave palette-swap post-process over
## the world (layer 5, below the HUD at layer 10), a neon theme on the HUD and
## the synth music cue. The state lives in Game.retro_mode.

const SHADER := preload("res://retro.gdshader")

var _rect: ColorRect
var _hud: CanvasLayer
var _theme: Theme
var _saved_themes: Dictionary = {}  # Control instance id -> {node, theme}
var _saved_labels: Dictionary = {}  # Label instance id -> {node, color, outline_color, outline_size}
var _music_synth: AudioStreamPlayer


func setup(main: Node) -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud = main.get_node_or_null("HUD")
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_rect.material = mat
	add_child(_rect)
	_theme = _make_theme()
	_music_synth = Sfx.attach_global_loop(&"synth_theme", self, 0.0, false)
	_apply(Game.retro_mode)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"RetroToggle"):
		_apply(not Game.retro_mode)
		get_viewport().set_input_as_handled()


func _apply(on: bool) -> void:
	Game.retro_mode = on
	_rect.visible = on
	if on:
		_set_main_theme_paused(true)
		if _music_synth.stream and not _music_synth.playing:
			_music_synth.play()
		_neon_on()
	else:
		_music_synth.stop()
		_set_main_theme_paused(false)
		_neon_off()


## The player owns main_theme (it starts when all 4 cures are found); just
## pause/resume it around the synth theme.
func _set_main_theme_paused(paused: bool) -> void:
	var p = Game.main.get("player") if Game.main else null
	var loop = p.get("_theme_loop") if p else null
	if loop != null and is_instance_valid(loop):
		loop.stream_paused = paused


func _neon_on() -> void:
	if _hud == null:
		return
	for c in _hud.get_children():
		if c is Control and not _saved_themes.has(c.get_instance_id()):
			_saved_themes[c.get_instance_id()] = {node = c, theme = c.theme}
			c.theme = _theme
			_tint_labels(c)


func _neon_off() -> void:
	for id in _saved_themes:
		var e: Dictionary = _saved_themes[id]
		if is_instance_valid(e.node):
			e.node.theme = e.theme
	_saved_themes.clear()
	for id in _saved_labels:
		var e: Dictionary = _saved_labels[id]
		var l: Label = e.node
		if not is_instance_valid(l):
			continue
		_restore_override(l, "font_color", e.color, true)
		_restore_override(l, "font_outline_color", e.outline_color, true)
		_restore_override(l, "outline_size", e.outline_size, false)
	_saved_labels.clear()


func _restore_override(l: Label, key: String, value: Variant, is_color: bool) -> void:
	if value == null:
		if is_color:
			l.remove_theme_color_override(key)
		else:
			l.remove_theme_constant_override(key)
	elif is_color:
		l.add_theme_color_override(key, value)
	else:
		l.add_theme_constant_override(key, value)


## Labels with explicit overrides ignore the theme, so shift them toward neon.
func _tint_labels(node: Node) -> void:
	for ch in node.get_children():
		if ch is Label and not _saved_labels.has(ch.get_instance_id()):
			var l: Label = ch
			_saved_labels[l.get_instance_id()] = {
				node = l,
				color = l.get_theme_color("font_color") if l.has_theme_color_override("font_color") else null,
				outline_color = l.get_theme_color("font_outline_color") if l.has_theme_color_override("font_outline_color") else null,
				outline_size = l.get_theme_constant("outline_size") if l.has_theme_constant_override("outline_size") else null,
			}
			if l.has_theme_color_override("font_color"):
				var base: Color = l.get_theme_color("font_color")
				l.add_theme_color_override("font_color", base.lerp(Color(1.0, 0.35, 0.85), 0.5))
			l.add_theme_color_override("font_outline_color", Color(0.0, 0.85, 1.0, 0.7))
			l.add_theme_constant_override("outline_size", 4)
		_tint_labels(ch)


func _make_theme() -> Theme:
	var t := Theme.new()
	var pink := Color(1.0, 0.35, 0.85)
	var cyan := Color(0.0, 0.9, 1.0, 0.7)
	for type in ["Label", "Button", "CheckBox"]:
		t.set_color("font_color", type, pink)
		t.set_color("font_outline_color", type, cyan)
		t.set_constant("outline_size", type, 4)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.7, 0.95))
	t.set_color("font_pressed_color", "Button", Color(0.4, 1.0, 1.0))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.02, 0.2, 0.9)
	panel.set_border_width_all(2)
	panel.border_color = Color(1.0, 0.2, 0.8)
	panel.set_corner_radius_all(6)
	panel.shadow_color = Color(1.0, 0.2, 0.8, 0.35)
	panel.shadow_size = 6
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var btn := panel.duplicate() as StyleBoxFlat
	t.set_stylebox("normal", "Button", btn)
	var hover := panel.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.05, 0.4, 0.95)
	hover.border_color = Color(0.0, 0.95, 1.0)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.02, 0.16, 0.9)
	bar_bg.set_border_width_all(1)
	bar_bg.border_color = Color(0.0, 0.9, 1.0, 0.8)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.2, 0.8)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	return t
