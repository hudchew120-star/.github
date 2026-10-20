extends Node
## Entry point: main menu (with a live AI battle in the background), skirmish/sandbox
## setup, settings, load/save, and the lifecycle of a match.

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1

var audio: AudioFX
var game: Game = null
var controller: PlayerController = null
var hud: HUD = null
var camera: Camera2D = null
var menu_layer: CanvasLayer
var menu_root: Control
var last_settings: Dictionary = {}
var autosave_t: float = 0.0
var attract_bot: AIController = null
var attract_bot_t: float = 0.0
var capture_action: String = ""
var capture_label: Label = null

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Config.apply_display()
	audio = AudioFX.new()
	add_child(audio)
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	var args := OS.get_cmdline_user_args()
	_setup_screenshot(args)
	if "--quickstart" in args:
		start_match({"map_size": "small", "start_units": "base", "cheats_allowed": true})
	elif "--sandbox" in args:
		start_match(_sandbox_defaults())
	else:
		show_main_menu()

## Developer helper: --shot=<file.png> --shot-at=<seconds> [--speed=N] [--cheats=cmd1;cmd2]
func _setup_screenshot(args: PackedStringArray) -> void:
	var path := ""
	var at := 3.0
	var spd := 1.0
	var cmds := ""
	for a in args:
		if a.begins_with("--shot="): path = a.substr(7)
		elif a.begins_with("--shot-at="): at = float(a.substr(10))
		elif a.begins_with("--speed="): spd = float(a.substr(8))
		elif a.begins_with("--cheats="): cmds = a.substr(9)
	if path == "":
		return
	await get_tree().create_timer(0.5).timeout
	if game != null:
		game.set_speed(spd)
		for c in cmds.split(";", false):
			game.cheats.execute(c.replace("_", " "))
	await get_tree().create_timer(at).timeout
	if hud != null and "--open-cheats" in args:
		hud.toggle_cheats()
		await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()

# ---------------------------------------------------------------- menus

func _clear_menu() -> VBoxContainer:
	if menu_root != null:
		menu_root.queue_free()
	menu_root = Control.new()
	menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_root.theme = UITheme.make(Color("#c8352c"))
	menu_layer.add_child(menu_root)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.04, 0.05, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(shade)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.box(Color(0.06, 0.07, 0.085, 0.94), UITheme.BORDER, 1, 0, 28))
	panel.anchor_bottom = 1.0
	panel.offset_right = 560
	menu_root.add_child(panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	sc.add_child(v)
	return v

func _header(v: VBoxContainer, sub: String) -> void:
	var t = UITheme.title_label("IRON MERIDIAN", 46, UITheme.TEXT)
	t.add_theme_constant_override("outline_size", 0)
	v.add_child(t)
	var line := ColorRect.new()
	line.color = Color("#c8352c")
	line.custom_minimum_size = Vector2(120, 4)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(line)
	v.add_child(UITheme.label(sub, 16, UITheme.DIM))
	var sp := Control.new()
	sp.custom_minimum_size.y = 14
	v.add_child(sp)

func _menu_button(v: VBoxContainer, text: String, cb: Callable, desc: String = "", enabled: bool = true) -> Button:
	var b = UITheme.button(text, cb)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 18)
	b.disabled = not enabled
	b.tooltip_text = desc
	b.mouse_entered.connect(func(): audio.ui("click"))
	v.add_child(b)
	return b

func show_main_menu() -> void:
	_start_attract()
	var v := _clear_menu()
	_header(v, "Offline real-time strategy  -  Coalition vs Dominion")
	var first := _menu_button(v, "New Game", func(): start_match({}), "Quick skirmish: medium map, one Normal AI.")
	_menu_button(v, "Skirmish", func(): show_setup("skirmish"), "Choose map, factions, opponents and rules.")
	_menu_button(v, "Sandbox", func(): show_setup("sandbox"), "Free experimentation with all developer tools enabled.")
	_menu_button(v, "Missions", func(): pass, "Scripted single-player missions arrive in development phase 4.", false)
	_menu_button(v, "Map Editor", func(): pass, "The map editor arrives in development phase 4. Maps can already be authored as JSON (see docs).", false)
	_menu_button(v, "Load Game", show_load, "Continue a saved match.")
	_menu_button(v, "Settings", show_settings, "Display, controls, audio and gameplay options.")
	_menu_button(v, "Credits", show_credits)
	_menu_button(v, "Exit", func(): get_tree().quit())
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sp)
	v.add_child(UITheme.label("Development build - phase 1-2. All content is original.", 12, UITheme.DIM))
	first.grab_focus()
	audio.start_music()

func show_credits() -> void:
	var v := _clear_menu()
	_header(v, "Credits")
	var t = UITheme.label("Design, code, artwork, sound effects and music generated procedurally for this project.\n\nInspired by the classic 1990s base-building RTS genre. No original game assets, names, voices or music are used.\n\nBuilt with the Godot Engine (MIT licence).", 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size.x = 480
	v.add_child(t)
	_menu_button(v, "Back", show_main_menu)

# ---------------------------------------------------------------- skirmish / sandbox setup

func _sandbox_defaults() -> Dictionary:
	return {"mode": "sandbox", "cheats_allowed": true, "victory": "none", "start_credits": 50000, "start_units": "base", "ai_count": 1, "map_size": "medium"}

func _opt(v: VBoxContainer, label: String, items: Array, sel: int) -> OptionButton:
	var h := HBoxContainer.new()
	var l = UITheme.label(label, 15)
	l.custom_minimum_size.x = 190
	h.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(sel)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(o)
	v.add_child(h)
	return o

func _check(v: VBoxContainer, label: String, on: bool) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = on
	v.add_child(c)
	return c

func show_setup(mode: String) -> void:
	var v := _clear_menu()
	_header(v, "Sandbox setup" if mode == "sandbox" else "Skirmish setup")
	var sb := mode == "sandbox"
	var sizes := ["small", "medium", "large", "xlarge"]
	var maps := ["Random (generated)"]
	var map_files := [""]
	for f in DirAccess.get_files_at("res://maps"):
		if f.ends_with(".json"):
			maps.append(f.get_basename().capitalize())
			map_files.append("res://maps/" + f)
	var o_map := _opt(v, "Map", maps, 0)
	var o_size := _opt(v, "Map size (random maps)", ["Small 64x64", "Medium 96x96", "Large 128x128", "Extra large 176x176"], 1)
	var seed_h := HBoxContainer.new()
	var sl = UITheme.label("Map seed", 15)
	sl.custom_minimum_size.x = 190
	seed_h.add_child(sl)
	var seed_box := SpinBox.new()
	seed_box.max_value = 999999
	seed_box.value = randi() % 100000
	seed_h.add_child(seed_box)
	v.add_child(seed_h)
	var factions := ["coalition", "dominion", "random"]
	var o_pf := _opt(v, "Your faction", ["Advanced Coalition", "Iron Dominion", "Random"], 0)
	var o_ef := _opt(v, "Enemy faction", ["Advanced Coalition", "Iron Dominion", "Random"], 1)
	var o_ai := _opt(v, "AI opponents", ["0", "1", "2", "3"], 1)
	var diffs := ["easy", "normal", "hard"]
	var o_diff := _opt(v, "AI difficulty", ["Easy", "Normal", "Hard"], 1)
	var credits := [2500, 5000, 10000, 20000, 50000, 100000]
	var o_cred := _opt(v, "Starting credits", credits.map(func(c): return UITheme.fmt(c)), 4 if sb else 2)
	var starts := ["mcv", "mcv_army", "base"]
	var o_start := _opt(v, "Starting forces", ["Construction vehicle only", "Construction vehicle + squad", "Small base + squad"], 2 if sb else 0)
	var o_power := _opt(v, "Starting bonus power", ["0", "100", "500", "Unlimited (99999)"], 0)
	var res := ["low", "normal", "high"]
	var o_res := _opt(v, "Resource abundance", ["Low", "Normal", "High"], 1)
	var speeds := [0.5, 0.75, 1.0, 1.5, 2.0]
	var o_speed := _opt(v, "Game speed", ["0.5x", "0.75x", "1x", "1.5x", "2x"], 2)
	var vict := ["structures", "annihilation", "none"]
	var o_vic := _opt(v, "Victory condition", ["Destroy all structures", "Annihilation (everything)", "None (free play)"], 2 if sb else 0)
	var c_fog := _check(v, "Fog of war", not sb)
	var c_power := _check(v, "Power constraints", true)
	var c_cheat := _check(v, "Allow developer cheats (F10)", true if sb else false)
	c_cheat.disabled = sb
	var h := HBoxContainer.new()
	h.add_child(UITheme.button("Start", func():
		var s := {
			"mode": mode, "map_file": map_files[o_map.selected], "map_size": sizes[o_size.selected], "seed": int(seed_box.value),
			"player_faction": factions[o_pf.selected], "enemy_factions": [factions[o_ef.selected]],
			"ai_count": o_ai.selected, "difficulty": diffs[o_diff.selected], "start_credits": credits[o_cred.selected],
			"start_units": starts[o_start.selected], "start_power_bonus": [0, 100, 500, 99999][o_power.selected],
			"resources": res[o_res.selected], "speed": speeds[o_speed.selected], "victory": vict[o_vic.selected],
			"fog": c_fog.button_pressed, "power_enabled": c_power.button_pressed, "cheats_allowed": c_cheat.button_pressed or sb,
		}
		if s.player_faction == "random":
			s.player_faction = ["coalition", "dominion"][randi() % 2]
		start_match(s), 160))
	h.add_child(UITheme.button("Back", show_main_menu, 120))
	v.add_child(h)

# ---------------------------------------------------------------- settings

func show_settings() -> void:
	var v := _clear_menu()
	_header(v, "Settings")
	var S: Dictionary = Config.settings
	v.add_child(UITheme.label("Display", 17, UITheme.AMBER))
	_slider(v, "UI scale", 0.75, 1.75, 0.05, float(S.ui_scale), func(x):
		S.ui_scale = x
		Config.apply_display())
	var fs := _check(v, "Fullscreen", bool(S.fullscreen))
	fs.toggled.connect(func(on):
		S.fullscreen = on
		Config.apply_display())
	v.add_child(UITheme.label("Controls", 17, UITheme.AMBER))
	var es := _check(v, "Edge scrolling", bool(S.edge_scroll))
	es.toggled.connect(func(on): S.edge_scroll = on)
	_slider(v, "Scroll speed", 300, 2000, 50, float(S.scroll_speed), func(x): S.scroll_speed = x)
	v.add_child(UITheme.label("Audio", 17, UITheme.AMBER))
	for k in [["music_volume", "Music volume"], ["sfx_volume", "Effects volume"], ["ui_volume", "Interface volume"]]:
		var key: String = k[0]
		_slider(v, k[1], 0, 1, 0.05, float(S[key]), func(x):
			S[key] = x
			audio.apply_volumes())
	v.add_child(UITheme.label("Gameplay", 17, UITheme.AMBER))
	var cd := _check(v, "Confirm destructive developer commands", bool(S.confirm_destructive))
	cd.toggled.connect(func(on): S.confirm_destructive = on)
	var dt := _check(v, "Show developer tools button during play", bool(S.show_dev_tools))
	dt.toggled.connect(func(on): S.show_dev_tools = on)
	_slider(v, "Autosave every (minutes, 0 = off)", 0, 30, 1, float(S.autosave_minutes), func(x): S.autosave_minutes = int(x))
	_slider(v, "Refund when cancelling (%)", 0, 100, 5, float(S.refund_ratio) * 100.0, func(x): S.refund_ratio = x / 100.0)
	_slider(v, "Maximum units per match", 100, 2000, 50, float(S.max_units), func(x): S.max_units = int(x))
	v.add_child(UITheme.label("Key bindings (click, then press a key)", 17, UITheme.AMBER))
	var names := {"cam_up": "Scroll up", "cam_down": "Scroll down", "cam_left": "Scroll left", "cam_right": "Scroll right",
		"cmd_attack_move": "Attack-move", "cmd_stop": "Stop", "cmd_guard": "Guard", "cmd_hold": "Hold position", "cmd_patrol": "Patrol",
		"cmd_scatter": "Scatter", "cmd_deploy": "Deploy", "pause": "Tactical pause", "cheat_panel": "Developer tools",
		"game_menu": "Game menu", "select_all_army": "Select all combat units", "repair_mode": "Repair mode", "sell_mode": "Sell mode",
		"speed_up": "Speed up", "speed_down": "Slow down", "center_base": "Center on base"}
	for action in Config.keymap:
		var h := HBoxContainer.new()
		var l = UITheme.label(names.get(action, action), 14)
		l.custom_minimum_size.x = 230
		h.add_child(l)
		var kl = UITheme.label(", ".join(Config.keymap[action]), 14, UITheme.AMBER)
		kl.custom_minimum_size.x = 120
		h.add_child(kl)
		var act: String = action
		h.add_child(UITheme.button("Rebind", func():
			capture_action = act
			capture_label = kl
			kl.text = "press a key..."))
		v.add_child(h)
	var hb := HBoxContainer.new()
	hb.add_child(UITheme.button("Save and back", func():
		Config.save_settings()
		show_main_menu(), 160))
	v.add_child(hb)

func _slider(v: VBoxContainer, label: String, mn: float, mx: float, step: float, val: float, cb: Callable) -> void:
	var h := HBoxContainer.new()
	var l = UITheme.label(label, 14)
	l.custom_minimum_size.x = 250
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = val
	s.custom_minimum_size.x = 160
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vl = UITheme.label(str(snappedf(val, step)), 14, UITheme.DIM)
	vl.custom_minimum_size.x = 48
	s.value_changed.connect(func(x):
		vl.text = str(snappedf(x, step))
		cb.call(x))
	h.add_child(s)
	h.add_child(vl)
	v.add_child(h)

func _input(event: InputEvent) -> void:
	if capture_action != "" and event is InputEventKey and event.pressed:
		var name := OS.get_keycode_string(event.physical_keycode)
		Config.rebind(capture_action, name)
		if capture_label != null and is_instance_valid(capture_label):
			capture_label.text = name
		capture_action = ""
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- load / save

func list_saves() -> Array:
	var out := []
	for f in DirAccess.get_files_at(SAVE_DIR):
		if f.ends_with(".json"):
			var path := SAVE_DIR + "/" + f
			var t := FileAccess.get_modified_time(path)
			out.append({"name": f.get_basename(), "date": Time.get_datetime_string_from_unix_time(t, true), "t": t})
	out.sort_custom(func(a, b): return a.t > b.t)
	return out

func save_game(name: String) -> String:
	if game == null:
		return "No match in progress."
	var clean := name.strip_edges().validate_filename()
	if clean == "":
		return "Please enter a name."
	var d := game.to_save()
	d["save_version"] = SAVE_VERSION
	d["last_settings"] = last_settings
	var f := FileAccess.open(SAVE_DIR + "/" + clean + ".json", FileAccess.WRITE)
	if f == null:
		return "Could not write the save file (%s)." % error_string(FileAccess.get_open_error())
	f.store_string(JSON.stringify(d))
	return "Saved as '%s'." % clean

func load_game(name: String) -> void:
	var path := SAVE_DIR + "/" + name + ".json"
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		_error_screen("Save '%s' could not be opened. It may have been deleted." % name)
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or not d.has("map") or int(d.get("save_version", 0)) != SAVE_VERSION:
		_error_screen("Save '%s' is damaged or from an incompatible version." % name)
		return
	_end_match()
	_stop_attract()
	last_settings = d.get("last_settings", {})
	_create_match_nodes()
	game.load_save(d)
	_finish_match_setup()

func show_load() -> void:
	var v := _clear_menu()
	_header(v, "Load game")
	var saves := list_saves()
	if saves.is_empty():
		v.add_child(UITheme.label("No saved games yet. Save from the in-game menu (Esc).", 15, UITheme.DIM))
	for s in saves:
		var h := HBoxContainer.new()
		var b = UITheme.button("%s" % s.name, func(): load_game(s.name))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		h.add_child(b)
		h.add_child(UITheme.label(s.date, 13, UITheme.DIM))
		v.add_child(h)
	_menu_button(v, "Back", show_main_menu)

func _error_screen(msg: String) -> void:
	var v := _clear_menu()
	_header(v, "Something went wrong")
	var l = UITheme.label(msg, 15, UITheme.BAD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size.x = 480
	v.add_child(l)
	_menu_button(v, "Back to menu", show_main_menu)

# ---------------------------------------------------------------- match lifecycle

func _create_match_nodes() -> void:
	game = Game.new()
	add_child(game)
	game.audio = audio
	camera = Camera2D.new()
	game.add_child(camera)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.make_current()
	audio.camera = camera

func _finish_match_setup() -> void:
	controller = PlayerController.new()
	game.add_child(controller)
	controller.setup(game, camera)
	hud = HUD.new()
	add_child(hud)
	hud.setup(game, controller, self)
	var start: Vector2i = game._base_center(game.human_pid)
	controller.center_on(MapGrid.cell_center(start))
	if menu_root != null:
		menu_root.queue_free()
		menu_root = null
	autosave_t = float(Config.settings.autosave_minutes) * 60.0
	game.notify(game.human_pid, "Commander, establish your base. Deploy the construction vehicle (select it, press E)." if game.settings.start_units != "base" else "Commander, your base is ready.", "info")

func start_match(s: Dictionary) -> void:
	_end_match()
	_stop_attract()
	last_settings = s.duplicate(true)
	var full := s.duplicate(true)
	full["refund_ratio"] = float(Config.settings.refund_ratio)
	full["max_units"] = int(Config.settings.max_units)
	if not full.has("seed"):
		full["seed"] = randi() % 100000
	_create_match_nodes()
	game.setup(full)
	_finish_match_setup()

func restart_match() -> void:
	start_match(last_settings)

func quit_to_menu() -> void:
	_end_match()
	show_main_menu()

func _end_match() -> void:
	if hud != null:
		hud.queue_free()
		hud = null
	if game != null:
		game.queue_free()
		game = null
	controller = null
	camera = null

func _process(delta: float) -> void:
	if game != null and attract_bot == null and not game.over and not game.paused:
		var mins := int(Config.settings.autosave_minutes)
		if mins > 0:
			autosave_t -= delta
			if autosave_t <= 0.0:
				autosave_t = mins * 60.0
				var r := save_game("autosave")
				game.notify(game.human_pid, "Autosaved.", "info")
	if attract_bot != null and game != null:
		attract_bot_t -= delta * game.speed
		if attract_bot_t <= 0.0:
			attract_bot_t = 0.5
			attract_bot.tick(0.5)
		camera.position = camera.position.lerp(_attract_focus(), delta * 0.25)
		if game.over:
			_stop_attract()
			_start_attract()

# ---------------------------------------------------------------- attract mode (live AI battle behind the menu)

func _start_attract() -> void:
	if game != null:
		return
	_create_match_nodes()
	game.setup({"map_size": "small", "seed": randi() % 9999, "ai_count": 1, "difficulty": "hard", "start_units": "base",
		"start_credits": 15000, "cheats_allowed": true, "fog": false, "player_faction": "coalition", "enemy_factions": ["dominion"]})
	game.speed = 1.5
	game.audio = null
	attract_bot = AIController.new(game, game.players[0])
	attract_bot.cfg = Data.ai.difficulty.hard
	camera.zoom = Vector2(1.1, 1.1)
	camera.position = Vector2(game.map.w, game.map.h) * MapGrid.T * 0.5
	audio.camera = null

func _attract_focus() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for u in game.units:
		if u.can_attack() and (u.order == "attack" or u.target != null):
			sum += u.pos
			n += 1
	if n > 0:
		return sum / n + Vector2(-200, 0)
	return Vector2(game.map.w, game.map.h) * MapGrid.T * 0.5 + Vector2(sin(Time.get_ticks_msec() * 0.0001), cos(Time.get_ticks_msec() * 0.00013)) * 600.0

func _stop_attract() -> void:
	if attract_bot != null:
		attract_bot = null
		_end_match()
