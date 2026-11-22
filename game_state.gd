extends Node
## Autoload "Game": run-wide state, the noise bus, shared constants, stats and
## meta-unlocks. Systems talk through these signals instead of hard references.

## Any loud event (footsteps while sprinting, crates breaking, car alarms,
## thrown bottles, puddles, screams). Zombies within `radius` may react.
signal noise_emitted(pos: Vector2, radius: float, source: StringName)
## Flash a point on the minimap (crate clue notes, phone tips, ...).
signal minimap_ping(pos: Vector2, color: Color, duration: float)
## Center-screen popup text.
signal message(text: String, color: Color)
## Brewing progress at the hospital lab (0..max). active = someone is brewing.
signal brew_progress(value: float, max_value: float, active: bool)
signal district_changed(district_name: String)
## A clue revealed a cure herb: the HUD points a pulsing arrow at it.
signal herb_hint(pos: Vector2)

const DISTRICT_NAMES: Array[String] = ["Old Market", "Neon Heights", "Rustwater Docks", "Mercy Hill"]
const DISTRICT_COLORS: Array[Color] = [
	Color(0.94, 0.61, 0.22), Color(0.95, 0.45, 0.80), Color(0.36, 0.84, 0.81), Color(0.63, 0.40, 0.85),
]
## Street names, index-aligned with main.gd VROADS (x = 600, 1200, 1800)
## and HROADS (y = 480, 960).
const VROAD_NAMES: Array[String] = ["Arcade Ave", "Cassette St", "Vhs Blvd"]
const HROAD_NAMES: Array[String] = ["Synth Rd", "Walkman Way"]

## Player-made noise is muffled to this fraction when raining.
const RAIN_MUFFLE := 0.6
const META_PATH := "user://meta.cfg"

var main = null  # the Main node (untyped on purpose: systems access its members dynamically)
var difficulty: int = 0  # 0 easy, 1 medium, 2 hard
var started: bool = false  # false while the player is still in the starting alley
var raining: bool = false
var retro_mode: bool = false
var run_time: float = 0.0

var stats := {}
## Meta-unlocks persisted across runs: earned by winning on each difficulty.
var perks := {fast_walk = false, bonus_chest = false, long_vision = false}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_meta()
	reset_run()


func _process(delta: float) -> void:
	if started and not get_tree().paused:
		run_time += delta


func reset_run() -> void:
	main = null
	started = false
	raining = false
	run_time = 0.0
	stats = {
		herbs_used = 0,
		zombies_dodged = 0,
		zombies_shoved = 0,
		cures_found = 0,
		time_as_human = 0.0,
	}


## Broadcast a noise. Player-made noises (muffled = true) shrink in the rain.
func emit_noise(pos: Vector2, radius: float, source: StringName, muffled: bool = false) -> void:
	if muffled and raining:
		radius *= RAIN_MUFFLE
	noise_emitted.emit(pos, radius, source)


func ping(pos: Vector2, color: Color = Color(1, 0.9, 0.3), duration: float = 1.5) -> void:
	minimap_ping.emit(pos, color, duration)


func say(text: String, color: Color = Color.WHITE) -> void:
	message.emit(text, color)


## 0 NW, 1 NE, 2 SW, 3 SE, matching main.gd's quadrant order (i % 2, i / 2).
func district_index(pos: Vector2) -> int:
	if main == null:
		return 0
	var half_w: float = main.COLS * main.CELL / 2.0
	var half_h: float = main.ROWS * main.CELL / 2.0
	return int(pos.x >= half_w) + 2 * int(pos.y >= half_h)


func district_name(pos: Vector2) -> String:
	return DISTRICT_NAMES[district_index(pos)]


# --- Meta-unlocks -------------------------------------------------------------

## Winning a difficulty unlocks its perk: easy -> fast_walk,
## medium -> bonus_chest, hard -> long_vision. Returns the perk name if new.
func record_win(diff: int) -> String:
	var perk: String = ["fast_walk", "bonus_chest", "long_vision"][clampi(diff, 0, 2)]
	if perks[perk]:
		return ""
	perks[perk] = true
	save_meta()
	return perk


func load_meta() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(META_PATH) != OK:
		return
	for key in perks:
		perks[key] = bool(cfg.get_value("perks", key, false))


func save_meta() -> void:
	var cfg := ConfigFile.new()
	for key in perks:
		cfg.set_value("perks", key, perks[key])
	cfg.save(META_PATH)
