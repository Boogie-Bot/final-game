extends Control
## Win / lose screen: result, score lines and the "photo of the fallen" (the
## explored map when you died as the player, cross-fading to the map from when
## the run ended as a zombie). Works while the tree is paused.

signal new_game_requested

const PHOTO_SIZE := Vector2(440, 264)
const FADE_DELAY := 5.0
const FADE_TIME := 1.2

var _result: Label
var _subtitle: Label
var _photo_a: TextureRect
var _photo_b: TextureRect
var _caption: Label
var _stats: Label
var _perk: Label
var _button: Button
var _tween: Tween


func setup(_main: Node = null) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.96)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.7, 0.7, 0.8, 0.8)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 36)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_result)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.custom_minimum_size.x = 760
	vbox.add_child(_subtitle)

	# Photo (left) beside the score column (right) keeps the panel short
	# enough for a 648px-tall window.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	vbox.add_child(row)
	var photo_col := VBoxContainer.new()
	row.add_child(photo_col)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 14)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.custom_minimum_size.x = 290
	row.add_child(info)

	var photo_holder := Control.new()
	photo_holder.custom_minimum_size = PHOTO_SIZE
	photo_col.add_child(photo_holder)
	var frame := ColorRect.new()
	frame.color = Color(0.7, 0.7, 0.8)
	frame.position = Vector2(-3, -3)
	frame.size = PHOTO_SIZE + Vector2(6, 6)
	photo_holder.add_child(frame)
	_photo_a = _make_photo()
	_photo_b = _make_photo()
	photo_holder.add_child(_photo_a)
	photo_holder.add_child(_photo_b)

	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 16)
	_caption.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	photo_col.add_child(_caption)

	_stats = Label.new()
	_stats.add_theme_font_size_override("font_size", 18)
	info.add_child(_stats)

	_perk = Label.new()
	_perk.add_theme_font_size_override("font_size", 20)
	_perk.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_perk)

	_button = Button.new()
	_button.text = "New Game"
	_button.add_theme_font_size_override("font_size", 24)
	_button.custom_minimum_size = Vector2(200, 44)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_button.pressed.connect(func() -> void:
		Sfx.play(&"ui_click")
		new_game_requested.emit())
	info.add_child(_button)
	visible = false


func _make_photo() -> TextureRect:
	var t := TextureRect.new()
	t.size = PHOTO_SIZE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func show_result(message: String, win: bool, photos: Array = [], new_perk: String = "") -> void:
	if _tween:
		_tween.kill()
	# First line is the headline; the rest is the smaller subtitle.
	var parts := message.split("\n", true, 1)
	_result.text = parts[0]
	_subtitle.text = parts[1] if parts.size() > 1 else ""
	_subtitle.visible = _subtitle.text != ""
	_subtitle.add_theme_color_override("font_color",
		Color(0.75, 0.95, 0.8) if win else Color(1.0, 0.7, 0.7))
	_result.add_theme_color_override("font_color",
		Color(0.4, 1.0, 0.5) if win else Color(1.0, 0.3, 0.3))
	var secs := int(Game.run_time)
	var cures: int = mini(int(Game.stats.get("cures_found", 0)), 4)
	var turned: bool = Game.main != null and Game.main.player.is_zombie
	var cure_line := "Cure ingredients found: %d / 4" % cures
	if win and not turned:
		cure_line = "Cure brewed!"
	elif win and turned:
		cure_line += "\nThe survivor was stopped."
	var lines: Array[String] = [
		"Time survived: %02d:%02d" % [secs / 60, secs % 60],
		"Herbs used: %d" % int(Game.stats.get("herbs_used", 0)),
		"Zombies dodged: %d" % int(Game.stats.get("zombies_dodged", 0)),
		"Zombies shoved: %d" % int(Game.stats.get("zombies_shoved", 0)),
		cure_line,
	]
	_stats.text = "\n".join(lines)
	_perk.text = "New perk unlocked: %s" % new_perk.capitalize().replace("_", " ") if new_perk != "" else ""
	_perk.visible = new_perk != ""
	_photo_a.visible = photos.size() > 0
	_photo_b.visible = false
	_caption.text = ""
	if photos.size() > 0:
		_photo_a.texture = photos[0]
		_caption.text = "When you fell" if photos.size() > 1 else "Your map"
	if photos.size() > 1:
		_photo_b.texture = photos[1]
		_photo_b.modulate.a = 0.0
		_photo_b.visible = true
	visible = true
	if photos.size() > 1:
		# Alternate between the two maps forever: hold each for FADE_DELAY,
		# then cross-fade.
		_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
		_tween.tween_interval(FADE_DELAY)
		_tween.tween_callback(func() -> void: _caption.text = "When it ended")
		_tween.tween_property(_photo_b, "modulate:a", 1.0, FADE_TIME)
		_tween.tween_interval(FADE_DELAY)
		_tween.tween_callback(func() -> void: _caption.text = "When you fell")
		_tween.tween_property(_photo_b, "modulate:a", 0.0, FADE_TIME)
