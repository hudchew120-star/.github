extends Node
## Entry point: main menu (with a live AI battle in the background), skirmish/sandbox
## setup, settings, load/save, and the lifecycle of a match.

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 1

var audio: AudioFX
var game: Game = null
var controller: PlayerController = null
var hud: HUD = null
var view = null
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
	if "--2d" in args:
		Config.settings.graphics = "2d"
	elif "--3d" in args:
		Config.settings.graphics = "3d"
	elif "--iso" in args:
		Config.settings.graphics = "iso"
	_setup_screenshot(args)
	var stage := ""
	for a in args:
		if a.begins_with("--stage="):
			stage = a.substr(8)
	var bench := 0
	for a in args:
		if a.begins_with("--bench="):
			bench = int(a.substr(8))
	if bench > 0:
		stage = "army"
	if stage == "countries":
		start_match({"mode": "sandbox", "map_size": "medium", "water": "none", "seed": 5, "start_units": "base", "fog": false,
			"ai_count": 3, "cheats_allowed": true, "victory": "none", "start_credits": 50000,
			"player_country": "thailand", "enemy_countries": ["china", "germany", "cuba"]})
		_stage_countries()
	elif stage != "":
		var stage_country := "usa"
		for a in args:
			if a.begins_with("--country="):
				stage_country = a.substr(10)
		start_match({"mode": "sandbox", "map_size": "medium", "water": "coastal", "seed": 11, "start_units": "base", "fog": false,
			"ai_count": 1, "cheats_allowed": true, "victory": "none", "start_credits": 50000, "player_faction": "coalition", "enemy_factions": ["dominion"],
			"player_country": stage_country, "enemy_countries": ["russia"]})
		_stage_scene(stage)
		if bench > 0:
			_run_bench(bench)
	elif "--quickstart" in args:
		start_match({"map_size": "small", "start_units": "base", "cheats_allowed": true})
	elif "--sandbox" in args:
		start_match(_sandbox_defaults())
	elif "--setup" in args:
		show_setup("skirmish")
	else:
		show_main_menu()

## Developer helper: --shot=<file.png> --shot-at=<seconds> [--speed=N] [--cheats=cmd1;cmd2]
func _setup_screenshot(args: PackedStringArray) -> void:
	var path := ""
	var at := 3.0
	var spd := 1.0
	var cmds := ""
	var focus_cell := ""
	var zoom_v := 0.0
	for a in args:
		if a.begins_with("--shot="): path = a.substr(7)
		elif a.begins_with("--shot-at="): at = float(a.substr(10))
		elif a.begins_with("--speed="): spd = float(a.substr(8))
		elif a.begins_with("--cheats="): cmds = a.substr(9)
		elif a.begins_with("--focus="): focus_cell = a.substr(8)
		elif a.begins_with("--zoom="): zoom_v = float(a.substr(7))
	if path == "":
		return
	await get_tree().create_timer(0.5).timeout
	if game != null:
		game.set_speed(spd)
		for c in cmds.split(";", false):
			game.cheats.execute(c.replace("_", " "))
		if focus_cell != "" and controller != null:
			var fc := focus_cell.split(",")
			controller.center_on(MapGrid.cell_center(Vector2i(int(fc[0]), int(fc[1]))))
		if zoom_v > 0.0 and view != null:
			view.zoom_by(zoom_v, get_viewport().get_visible_rect().size * 0.5)
	await get_tree().create_timer(at).timeout
	for a in args:
		if a.begins_with("--tab=") and hud != null:
			hud._select_tab(a.substr(6))
			await get_tree().create_timer(0.3).timeout
	if hud != null and "--open-cheats" in args:
		hud.toggle_cheats()
		await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()

## Developer helper: --stage=naval|army builds a showcase scene (used for documentation screenshots).
func _stage_scene(kind: String) -> void:
	await get_tree().process_frame
	game.cheats.set_flag("ai_disabled", true)
	var ai := AIController.new(game, game.players[0])
	var base: Vector2i = ai._base_center()
	var yard := ai._water_site("syrd")
	if yard.x >= 0:
		game.create_building(0, "syrd", yard, true)
	for t in ["afld", "fix", "dome", "weap", "sam"]:
		var c := ai._find_spot(t)
		if c.x >= 0:
			game.create_building(0, t, c, true)
	var bp := MapGrid.cell_center(base)
	var ships := [["dest_c", 0], ["boat_c", 0], ["boat_c", 0], ["sub_d", 1], ["cruiser_d", 1]]
	var wc: Vector2i = ai._nearest_water(yard + Vector2i(1, 1) if yard.x >= 0 else base, 14)
	for i in ships.size():
		var c: Vector2i = ai._nearest_water(wc + Vector2i(i * 3 - 4, (i % 2) * 3 - 1) * (2 if ships[i][1] == 1 else 1), 10)
		if c.x >= 0:
			var u = game.spawn_unit(ships[i][1], ships[i][0], MapGrid.cell_center(c))
			if u != null:
				u.facing = randf() * TAU
	var land := [] if kind == "specials" else [["mtank", 0, Vector2(4, 5)], ["mtank", 0, Vector2(5, 4)], ["ltank", 0, Vector2(6, 6)], ["aa_c", 0, Vector2(3, 6)], ["jeep", 0, Vector2(7, 4)],
		["e1", 0, Vector2(6, 2)], ["e1", 0, Vector2(6.4, 2.5)], ["e1", 0, Vector2(6.8, 2.1)], ["e3", 0, Vector2(7.2, 2.6)], ["eng", 0, Vector2(5.6, 2.8)],
		["htank", 1, Vector2(10, 9)], ["aa_d", 1, Vector2(11, 8)], ["e1", 1, Vector2(9, 10.5)], ["e4", 1, Vector2(9.5, 11)], ["flm", 1, Vector2(10, 11.2)], ["e1", 1, Vector2(10.5, 10.6)]]
	for e in land:
		var p: Vector2 = bp + (e[2] as Vector2) * MapGrid.T
		var u = game.spawn_unit(e[1], e[0], p)
		if u != null:
			u.facing = (bp + Vector2(8, 8) * MapGrid.T - u.pos).angle() if e[1] == 0 else (bp - u.pos).angle()
			u.turret_facing = u.facing
	for e in [["heli_c", 0, Vector2(2, 7)], ["heli_c", 0, Vector2(3.5, 8.5)], ["jet_c", 0, Vector2(0, 4)], ["heli_d", 1, Vector2(9, 6)], ["jet_d", 1, Vector2(12, 4)]]:
		var u = game.spawn_unit(e[1], e[0], bp + (e[2] as Vector2) * MapGrid.T)
		if u != null:
			u.air_state = "flying"
			u.altitude_now = u.altitude
			u.facing = 0.8 if e[1] == 0 else 3.9
			u.cmd_move(u.pos + Vector2(cos(u.facing), sin(u.facing)) * 160.0)
	if kind == "specials":
		var c0: Vector2 = bp + Vector2(6, 6) * MapGrid.T
		for i in 4:
			var gi = game.spawn_unit(0, "e1", c0 + Vector2(-90 + i * 34, -40))
			if gi != null:
				gi.facing = 0.8
				gi.cmd_deploy()
				gi.deploy_t = 0.0
		for i in 3:
			var rj = game.spawn_unit(0, "jjet", c0 + Vector2(40 + i * 40, -110))
			if rj != null:
				rj.facing = 0.8
		var cm = game.spawn_unit(0, "cmdo", c0 + Vector2(-30, 30))
		if cm != null:
			cm.facing = 0.8
		for i in 3:
			var dg = game.spawn_unit(1, "dog", c0 + Vector2(150 + i * 30, 120))
			if dg != null:
				dg.facing = 3.9
		var ml = game.spawn_unit(1, "mnly", c0 + Vector2(220, 40))
		if ml != null:
			ml.facing = 3.9
		var iv = game.spawn_unit(1, "ivan", c0 + Vector2(190, 170))
		if iv != null:
			iv.facing = 3.9
		game.specials.powers[0] = {"paradrop": game.sim_time}
		game.specials.use_power(0, "paradrop", c0 + Vector2(-140, 120))
		game.specials.powers[1] = {"bomber": game.sim_time}
		game.specials.use_power(1, "bomber", c0 + Vector2(-260, -200))
		for f in game.specials.flyovers:
			f.pos = f.target - f.dir * MapGrid.T * (5.0 if f.kind == "transport" else 9.0)
	if controller != null:
		if kind == "specials":
			controller.center_on(bp + Vector2(5, 6) * MapGrid.T)
		elif kind == "naval" and yard.x >= 0:
			controller.center_on(MapGrid.cell_center(yard) + Vector2(2.5, 3.5) * MapGrid.T)
		else:
			controller.center_on(bp + Vector2(7, 7) * MapGrid.T)

## Developer helper: --stage=countries lines up country uniforms and unique units for a screenshot.
func _stage_countries() -> void:
	await get_tree().process_frame
	game.cheats.set_flag("ai_disabled", true)
	for p in game.players:
		p.team = 0               # a parade, not a battle
		p.power_bonus = 1000
		p.recompute(game.buildings)
	var ai := AIController.new(game, game.players[0])
	var bp := MapGrid.cell_center(ai._base_center()) + Vector2(5, 5) * MapGrid.T
	# [pid, type, offset in cells, facing]
	var rows := [
		[0, "e1", Vector2(0, 0)], [0, "e1", Vector2(0.5, 0.4)], [0, "e3", Vector2(1.0, 0.0)], [0, "rngr", Vector2(1.5, 0.5)], [0, "rngr", Vector2(2.0, 0.1)],
		[0, "mech", Vector2(3.2, 0.6)], [0, "bjet", Vector2(2.0, -2.5)],
		[2, "e1", Vector2(-1.0, 2.6)], [2, "e1", Vector2(-0.5, 3.0)], [2, "e3", Vector2(0.0, 2.6)], [2, "tdst", Vector2(1.3, 3.2)],
		[1, "e1", Vector2(4.5, 2.6)], [1, "e4", Vector2(5.0, 3.0)], [1, "flm", Vector2(5.5, 2.6)], [1, "gatl", Vector2(6.8, 3.4)], [1, "tsar", Vector2(5.2, 4.9)],
		[3, "e1", Vector2(1.5, 5.4)], [3, "guer", Vector2(2.0, 5.8)], [3, "guer", Vector2(2.5, 5.4)], [3, "e4", Vector2(3.0, 5.8)],
	]
	for r in rows:
		var u = game.spawn_unit(r[0], r[1], bp + (r[2] as Vector2) * MapGrid.T)
		if u == null:
			continue
		u.facing = 0.9
		u.turret_facing = 0.9
		if u.is_air_unit:
			u.air_state = "flying"
			u.altitude_now = u.altitude
			u.cmd_move(u.pos + Vector2(cos(u.facing), sin(u.facing)) * 160.0)
		else:
			u.cmd_hold()
	var gc := MapGrid.to_cell(bp + Vector2(-3.5, 4.5) * MapGrid.T)
	game.create_building(2, "gcan", gc, true)
	if controller != null:
		controller.center_on(bp + Vector2(2.2, 2.6) * MapGrid.T)

## Developer helper: --bench=<seconds> stages a large battle (AI on) and prints frame timings.
func _run_bench(seconds: int) -> void:
	await get_tree().create_timer(0.6).timeout
	game.cheats.set_flag("ai_disabled", false)
	var bp := MapGrid.cell_center(game.map.starts[0])
	var ep := MapGrid.cell_center(game.map.starts[1])
	var types := ["mtank", "ltank", "e1", "e1", "e3", "jeep", "aa_c"]
	var etypes := ["htank", "e1", "e1", "e4", "flm", "aa_d"]
	for i in 70:
		var u = game.spawn_unit(0, types[i % types.size()], bp + Vector2(randf_range(80, 400), randf_range(80, 400)))
		if u != null: u.cmd_attack_move(ep)
		var v = game.spawn_unit(1, etypes[i % etypes.size()], ep - Vector2(randf_range(80, 400), randf_range(80, 400)))
		if v != null: v.cmd_attack_move(bp)
	var spd := OS.get_environment("BENCH_SPEED")
	if spd != "":
		game.set_speed(float(spd))
	await get_tree().create_timer(4.0).timeout   # warm-up
	for n in OS.get_environment("BENCH_HIDE").split(",", false):
		var node = view.get(n)
		if node != null:
			node.visible = false
	if OS.get_environment("BENCH_NOHUD") != "" and hud != null:
		hud.visible = false
	game.profile.clear()
	var tick0 := game.tick_count
	game.profiling = true
	var frames := 0
	var worst := 0.0
	var proc_sum := 0.0
	var phys_sum := 0.0
	var t_end := Time.get_ticks_msec() + seconds * 1000
	var last := Time.get_ticks_usec()
	while Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		frames += 1
		proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys_sum += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		if controller != null and frames % 60 == 0:
			controller.center_on(game.units[randi() % game.units.size()].pos)
	print("BENCH frames %d in %ds = %.1f fps, worst frame %.1f ms, process %.2f ms, physics %.2f ms, units %d, draw calls %d, nodes %d" % [
		frames, seconds, frames / float(seconds), worst, proc_sum / frames, phys_sum / frames, game.units.size(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	var ticks := maxf(1.0, game.tick_count - tick0)
	for k in game.profile:
		print("BENCH step.%s %.3f ms/tick" % [k, game.profile[k] / 1000.0 / ticks])
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
	v.add_child(UITheme.label("Development build - phases 1-2 + 3D graphics. All content is original.", 12, UITheme.DIM))
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

## A row of flag buttons for each side plus a "random" flag. Writes the chosen country id
## (or "random") into pick[key].
func _flag_picker(v: VBoxContainer, label: String, pick: Dictionary, key: String) -> void:
	var h := HBoxContainer.new()
	var l = UITheme.label(label, 15)
	l.custom_minimum_size.x = 190
	h.add_child(l)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	h.add_child(rows)
	v.add_child(h)
	var frames := {}
	var refresh := func():
		for id in frames:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(3)
			sb.border_color = UITheme.AMBER if id == pick[key] else Color(0, 0, 0, 0)
			sb.set_corner_radius_all(3)
			frames[id].add_theme_stylebox_override("panel", sb)
	var groups := [Data.countries_of("coalition"), Data.countries_of("dominion") + ["random"]]
	for g in groups:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		rows.add_child(row)
		for id in g:
			var frame := PanelContainer.new()
			var b := TextureButton.new()
			b.texture_normal = SpriteLib._load_tex("res://assets/ui/flags/%s.png" % id)
			b.ignore_texture_size = true
			b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			b.custom_minimum_size = Vector2(57, 38)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			if id == "random":
				b.tooltip_text = "Random country"
			else:
				var c: Dictionary = Data.countries[id]
				b.tooltip_text = "%s (%s)\n%s" % [c.name, Data.factions[c.side].short, c.special]
			var cid: String = id
			b.pressed.connect(func():
				pick[key] = cid
				refresh.call())
			frame.add_child(b)
			row.add_child(frame)
			frames[id] = frame
	refresh.call()

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
	var map_presets := [""]
	for id in MapGen.PRESETS:
		var pr: Dictionary = MapGen.PRESETS[id]
		maps.append("%s  (%s, up to %d players)" % [pr.name, str(pr.size).capitalize(), int(pr.max_players)])
		map_files.append("")
		map_presets.append(id)
	for f in DirAccess.get_files_at("res://maps"):
		if f.ends_with(".json"):
			maps.append(f.get_basename().capitalize())
			map_files.append("res://maps/" + f)
			map_presets.append("")
	var o_map := _opt(v, "Map", maps, 0)
	var o_size := _opt(v, "Map size (random maps)", ["Small 64x64", "Medium 96x96", "Large 128x128", "Extra large 176x176"], 1)
	var waters := ["lakes", "coastal", "none"]
	var o_water := _opt(v, "Water (random maps)", ["Lakes and rivers", "Coastal (naval warfare)", "Dry land"], 0)
	var seed_h := HBoxContainer.new()
	var sl = UITheme.label("Map seed", 15)
	sl.custom_minimum_size.x = 190
	seed_h.add_child(sl)
	var seed_box := SpinBox.new()
	seed_box.max_value = 999999
	seed_box.value = randi() % 100000
	seed_h.add_child(seed_box)
	v.add_child(seed_h)
	# Countries are picked by flag (no reading needed); hovering a flag shows what it brings.
	var pick := {"you": "usa", "enemy": "random"}
	_flag_picker(v, "Your country", pick, "you")
	_flag_picker(v, "Enemy country", pick, "enemy")
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
			"mode": mode, "map_file": map_files[o_map.selected], "map_preset": map_presets[o_map.selected], "map_size": sizes[o_size.selected], "water": waters[o_water.selected], "seed": int(seed_box.value),
			"player_country": pick.you, "enemy_countries": [pick.enemy], "player_faction": "random", "enemy_factions": ["random"],
			"ai_count": o_ai.selected, "difficulty": diffs[o_diff.selected], "start_credits": credits[o_cred.selected],
			"start_units": starts[o_start.selected], "start_power_bonus": [0, 100, 500, 99999][o_power.selected],
			"resources": res[o_res.selected], "speed": speeds[o_speed.selected], "victory": vict[o_vic.selected],
			"fog": c_fog.button_pressed, "power_enabled": c_power.button_pressed, "cheats_allowed": c_cheat.button_pressed or sb,
		}
		if s.player_country == "random":
			var all := Data.countries.keys()
			s.player_country = all[randi() % all.size()]
		s.player_faction = Data.countries[s.player_country].side
		start_match(s), 160))
	h.add_child(UITheme.button("Back", show_main_menu, 120))
	v.add_child(h)

# ---------------------------------------------------------------- settings

func show_settings() -> void:
	var v := _clear_menu()
	_header(v, "Settings")
	var S: Dictionary = Config.settings
	v.add_child(UITheme.label("Display", 17, UITheme.AMBER))
	var modes := ["iso", "2d"]
	var gfx := _opt(v, "Graphics", ["Classic isometric (recommended)", "Top-down 2D (very old PCs)"], maxi(modes.find(graphics_mode()), 0))
	gfx.item_selected.connect(func(i): S.graphics = modes[i])
	_slider(v, "UI scale", 0.75, 1.75, 0.05, float(S.ui_scale), func(x):
		S.ui_scale = x
		Config.apply_display())
	var fs := _check(v, "Fullscreen", bool(S.fullscreen))
	fs.toggled.connect(func(on):
		S.fullscreen = on
		Config.apply_display())
	var qualities := ["performance", "balanced", "quality"]
	var q := _opt(v, "Graphics quality (applies to the next match)", ["Performance (fastest, for older PCs)", "Balanced (recommended)", "Quality (sharpest terrain)"], maxi(qualities.find(str(S.get("quality", "balanced"))), 0))
	q.item_selected.connect(func(i): S.quality = qualities[i])
	var limits := [0, 30, 60, 120, 144, 240]
	var fl := _opt(v, "Frame rate limit", ["Unlimited", "30", "60", "120", "144", "240"], maxi(limits.find(int(S.get("fps_limit", 0))), 0))
	fl.item_selected.connect(func(i):
		S.fps_limit = limits[i]
		Config.apply_display())
	var vs := _check(v, "VSync (smooth, no tearing)", bool(S.get("vsync", true)))
	vs.toggled.connect(func(on):
		S.vsync = on
		Config.apply_display())
	var sf := _check(v, "Show FPS counter", bool(S.get("show_fps", true)))
	sf.toggled.connect(func(on): S.show_fps = on)
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
	d.settings["use_3d"] = use_3d()
	game.load_save(d)
	_attach_view()
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

func graphics_mode() -> String:
	return String(Config.settings.get("graphics", "iso"))

## True when an external presentation (isometric or 3D) draws the battlefield.
func use_3d() -> bool:
	return graphics_mode() != "2d"

## Creates the 3D (or classic 2D) presentation once the game's map exists.
func _attach_view() -> void:
	if graphics_mode() == "iso":
		view = IsoView.new()
		add_child(view)
		view.setup(game)
	elif graphics_mode() == "3d":
		view = View3D.new()
		add_child(view)
		view.setup(game)
	else:
		view = View2D.new()
		game.add_child(view)
		view.setup(game)
	audio.view = view

func _finish_match_setup() -> void:
	controller = PlayerController.new()
	game.add_child(controller)
	controller.setup(game, view)
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
	full["use_3d"] = use_3d()
	_create_match_nodes()
	game.setup(full)
	_attach_view()
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
	if view != null and is_instance_valid(view) and view.get_parent() == self:
		view.queue_free()
	view = null
	if game != null:
		game.queue_free()
		game = null
	controller = null
	if audio != null:
		audio.view = null

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
		view.set_focus(view.get_focus().lerp(_attract_focus(), delta * 0.25))
		if game.over:
			_stop_attract()
			_start_attract()

# ---------------------------------------------------------------- attract mode (live AI battle behind the menu)

func _start_attract() -> void:
	if game != null:
		return
	_create_match_nodes()
	game.setup({"map_size": "small", "seed": randi() % 9999, "ai_count": 1, "difficulty": "hard", "start_units": "base",
		"start_credits": 15000, "cheats_allowed": true, "fog": false, "player_faction": "coalition", "enemy_factions": ["dominion"], "use_3d": use_3d()})
	_attach_view()
	game.speed = 1.5
	game.audio = null
	attract_bot = AIController.new(game, game.players[0])
	attract_bot.cfg = Data.ai.difficulty.hard
	view.set_focus(MapGrid.cell_center(game._base_center(0)) + Vector2(-60, 40))
	audio.view = null

func _attract_focus() -> Vector2:
	var sum := Vector2.ZERO
	var n := 0
	for u in game.units:
		if u.can_attack() and (u.order == "attack" or u.target != null):
			sum += u.pos
			n += 1
	if n > 0:
		return sum / n
	# No fighting: drift slowly around the first base.
	return MapGrid.cell_center(game._base_center(0)) + Vector2(sin(Time.get_ticks_msec() * 0.00012), cos(Time.get_ticks_msec() * 0.0001)) * 160.0

func _stop_attract() -> void:
	if attract_bot != null:
		attract_bot = null
		_end_match()
