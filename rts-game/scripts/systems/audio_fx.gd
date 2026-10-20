class_name AudioFX
extends Node
## Original procedurally synthesised sound effects and music. Separate buses for
## Music, SFX and UI so each has its own volume control.

const RATE := 22050
var sounds := {}
var players: Array = []
var music_player: AudioStreamPlayer
var last_play := {}
var view = null       # View3D or View2D; positional volume uses its focus

func _ready() -> void:
	_ensure_buses()
	apply_volumes()
	_build_sounds()
	for i in 20:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

func _ensure_buses() -> void:
	for b in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")

func apply_volumes() -> void:
	var map := {"Music": "music_volume", "SFX": "sfx_volume", "UI": "ui_volume"}
	for b in map:
		var i := AudioServer.get_bus_index(b)
		var v := float(Config.settings.get(map[b], 0.7))
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)

func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w

## Generic synth: noise + tone with exponential decay and optional pitch sweep.
func _synth(dur: float, noise: float, tone_hz: float, sweep: float, decay: float, lowpass: float = 0.5) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay) * minf(1.0, t * 400.0)
		var nz := randf_range(-1.0, 1.0)
		lp += (nz - lp) * lowpass
		var hz := tone_hz * (1.0 + sweep * t)
		phase += hz / RATE
		var s := lp * noise + sin(phase * TAU) * (1.0 - noise)
		out[i] = s * env * 0.8
	return out

func _tones(notes: Array, note_dur: float, wave: String = "sine") -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for hz in notes:
		var n := int(note_dur * RATE)
		for i in n:
			var t := float(i) / RATE
			var env := minf(1.0, t * 200.0) * exp(-t * 6.0)
			var ph := fmod(t * float(hz), 1.0)
			var s := sin(ph * TAU) if wave == "sine" else (1.0 if ph < 0.5 else -1.0) * 0.4
			out.append(s * env * 0.5)
	return out

func _build_sounds() -> void:
	seed(1234)
	sounds["rifle"] = _wav(_synth(0.12, 0.95, 300, 0, 38, 0.6))
	sounds["mg"] = _wav(_synth(0.08, 0.9, 240, 0, 50, 0.7))
	sounds["cannon"] = _wav(_synth(0.45, 0.85, 90, -0.5, 9, 0.25))
	sounds["cannon_heavy"] = _wav(_synth(0.6, 0.85, 70, -0.5, 7, 0.2))
	sounds["rocket"] = _wav(_synth(0.5, 0.9, 400, 1.5, 5, 0.35))
	sounds["flame"] = _wav(_synth(0.5, 1.0, 0, 0, 4, 0.15))
	sounds["zap"] = _wav(_synth(0.35, 0.4, 900, -1.8, 8, 0.8))
	sounds["explode"] = _wav(_synth(0.9, 1.0, 50, 0, 4.5, 0.12))
	sounds["explode_big"] = _wav(_synth(1.6, 1.0, 40, 0, 2.6, 0.08))
	sounds["die_inf"] = _wav(_synth(0.25, 0.6, 220, -1.0, 12, 0.4))
	sounds["build"] = _wav(_tones([180, 120], 0.08, "square"))
	sounds["complete"] = _wav(_tones([523, 659, 784], 0.12))
	sounds["unit_ready"] = _wav(_tones([659, 880], 0.1))
	sounds["click"] = _wav(_tones([1200], 0.03, "square"))
	sounds["select"] = _wav(_tones([880, 1100], 0.04))
	sounds["move"] = _wav(_tones([660, 520], 0.05))
	sounds["alert"] = _wav(_tones([440, 330, 440, 330], 0.16, "square"))
	sounds["error"] = _wav(_tones([200, 150], 0.1, "square"))

func play(name: String, world_pos: Vector2 = Vector2.INF, bus: String = "SFX") -> void:
	if not sounds.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(name, 0)) < 45:
		return
	var vol := 0.0
	if world_pos != Vector2.INF and view != null and is_instance_valid(view):
		var d: float = world_pos.distance_to(view.get_focus())
		var reach: float = view.view_radius_px()
		if d > reach:
			return
		vol = linear_to_db(clampf(1.0 - d / reach, 0.08, 1.0))
	last_play[name] = now
	for p in players:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = vol
			p.bus = bus
			p.play()
			return

func ui(name: String) -> void:
	play(name, Vector2.INF, "UI")

## A short original martial loop: bass ostinato, kick/snare pattern and a minor-key lead.
func start_music() -> void:
	if music_player.playing:
		return
	if not sounds.has("music"):
		sounds["music"] = _wav(_make_music(), true)
	music_player.stream = sounds["music"]
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func _make_music() -> PackedFloat32Array:
	var bpm := 112.0
	var beat := 60.0 / bpm
	var bars := 4
	var n := int(beat * 4 * bars * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bass := [55.0, 55.0, 65.41, 49.0]              # A1 A1 C2 G1 per bar
	var lead := [440.0, 523.25, 493.88, 392.0, 440.0, 349.23, 392.0, 329.63]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var t := float(i) / RATE
		var b := t / beat
		var bar := int(b / 4.0) % bars
		var in_beat := fmod(b, 1.0)
		var eighth := fmod(b * 2.0, 1.0)
		var s := 0.0
		# Bass: driving eighth notes.
		var bh: float = bass[bar]
		s += (1.0 if fmod(t * bh, 1.0) < 0.5 else -1.0) * 0.12 * exp(-eighth * 3.0)
		# Kick on every beat, snare on 2 and 4.
		var kt := in_beat * beat
		s += sin(TAU * (50.0 + 90.0 * exp(-kt * 30.0)) * kt) * exp(-kt * 14.0) * 0.5
		if int(b) % 2 == 1:
			s += rng.randf_range(-1, 1) * exp(-kt * 22.0) * 0.22
		# Lead: one note per half bar.
		var li := int(b / 2.0) % lead.size()
		var lt := fmod(b, 2.0) * beat
		var lh: float = lead[li]
		s += sin(TAU * lh * t + sin(TAU * 5.0 * t) * 0.3) * 0.08 * exp(-lt * 1.5)
		out[i] = s * 0.7
	return out
