extends Node
## Autoload "Sfx": every sound cue in the game goes through here. No audio
## files exist yet — each cue maps to a res:// path that is empty for now.
## Drop a file in, fill in its path below, and the cue starts playing; until
## then every call is a silent no-op (but the player nodes still exist so the
## scene structure is ready).

const CUES := {
	# Player
	&"footstep": "", &"sprint_breath": "", &"shove": "", &"throw": "",
	&"bottle_break": "", &"pickup_herb": "", &"pickup_cure": "", &"drink_tonic": "",
	&"serum": "", &"turn_zombie": "", &"roar": "", &"lunge": "",
	&"glass_break": "", &"door_clatter": "",
	# Zombies
	&"zombie_shuffle_walker": "", &"zombie_shuffle_runner": "",
	&"zombie_shuffle_brute": "", &"zombie_shuffle_screamer": "",
	&"zombie_groan": "", &"zombie_lunge": "", &"zombie_knockdown": "",
	&"zombie_getup": "", &"brute_shove": "", &"scream": "", &"zombie_fed": "",
	# World
	&"crate_break": "", &"car_alarm": "", &"siren": "", &"phone_ring": "",
	&"phone_voice": "", &"phone_hangup": "", &"phone_garble": "",
	&"zmp_blast": "", &"explosion": "", &"building_collapse": "",
	&"puddle_splash": "", &"rain_loop": "", &"thunder": "",
	&"door_open": "", &"door_lock": "", &"window_smash": "", &"brew_bubble": "",
	# Music / herbs
	&"herb_hum_0": "", &"herb_hum_1": "", &"herb_hum_2": "", &"herb_hum_3": "",
	&"main_theme": "", &"synth_theme": "",
	# UI
	&"ui_click": "", &"win": "", &"lose": "",
}

var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The AudioStream for a cue, or null when no file is assigned yet.
func stream(cue: StringName) -> AudioStream:
	if _streams.has(cue):
		return _streams[cue]
	var path: String = CUES.get(cue, "")
	var s: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		s = load(path)
	_streams[cue] = s
	return s


## One-shot sound. Positional when `pos` is given (Vector2), global otherwise.
func play(cue: StringName, pos: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var s := stream(cue)
	if s == null:
		return
	var p: Node
	if pos is Vector2:
		var p2 := AudioStreamPlayer2D.new()
		p2.global_position = pos
		p2.max_distance = 1400.0
		p = p2
	else:
		p = AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	var parent: Node = Game.main if Game.main else self
	parent.add_child(p)
	p.play()


## Attaches a looping positional player to `owner_node` (created even when the
## cue has no stream yet). Returns it so the caller can stop/start/adjust it.
func attach_loop(cue: StringName, owner_node: Node2D, volume_db: float = 0.0,
		autoplay: bool = true) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.name = "Sfx_" + String(cue)
	p.stream = stream(cue)
	p.volume_db = volume_db
	p.max_distance = 1400.0
	owner_node.add_child(p)
	if autoplay and p.stream:
		p.play()
	return p


## Global (non-positional) loop, e.g. rain ambience or music.
func attach_global_loop(cue: StringName, owner_node: Node, volume_db: float = 0.0,
		autoplay: bool = true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = "Sfx_" + String(cue)
	p.stream = stream(cue)
	p.volume_db = volume_db
	owner_node.add_child(p)
	if autoplay and p.stream:
		p.play()
	return p
