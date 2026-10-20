class_name CheatPanel
extends PanelContainer
## Graphical developer tools. Every control issues the same console command the text
## console would, so both paths change the real game state identically.

var game: Game
var hud = null
var log_view: RichTextLabel
var input: LineEdit
var hist_i: int = -1
var toggles := {}
var confirm_pending := {}
var money_field: LineEdit
var ore_field: LineEdit
var power_field: LineEdit
var spawn_type: OptionButton
var spawn_owner: OptionButton
var spawn_count: SpinBox
var spawn_loc: OptionButton
var spawn_x: SpinBox
var spawn_y: SpinBox
var health_field: LineEdit
var tele_x: SpinBox
var tele_y: SpinBox
var speed_slider: HSlider
var persist_opt: OptionButton

func setup(g: Game, h) -> void:
	game = g
	hud = h
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -HUD.SIDEBAR_W - 520
	offset_right = -HUD.SIDEBAR_W - 8
	offset_top = 46
	offset_bottom = -168
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	add_child(v)
	var head := HBoxContainer.new()
	var t = UITheme.title_label("Developer Tools", 20, UITheme.AMBER)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UITheme.button("Close (F10)", func(): visible = false))
	v.add_child(head)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(tabs)
	tabs.add_child(_tab_console())
	tabs.add_child(_tab_economy())
	tabs.add_child(_tab_toggles())
	tabs.add_child(_tab_spawn())
	tabs.add_child(_tab_selected())
	tabs.add_child(_tab_battlefield())

func on_open() -> void:
	_sync()
	input.grab_focus()

func _scroll_page(name: String) -> Array:
	var sc := ScrollContainer.new()
	sc.name = name
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	return [sc, v]

func run(cmd: String) -> Dictionary:
	var r: Dictionary = game.cheats.execute(cmd)
	_log("> " + cmd, UITheme.DIM)
	_log(r.msg, UITheme.GOOD if r.ok else UITheme.BAD)
	if r.msg != "" and hud != null:
		hud._on_message(r.msg.split("\n")[0], "info" if r.ok else "warn")
	_sync()
	return r

func _log(text: String, col: Color) -> void:
	if log_view == null or text == "":
		return
	log_view.push_color(col)
	log_view.add_text(text + "\n")
	log_view.pop()

## Destructive buttons need a second click within 3 seconds.
func _confirm_button(text: String, cmd: String) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		var now := Time.get_ticks_msec()
		if now - int(confirm_pending.get(cmd, 0)) < 3000 or not Config.settings.confirm_destructive:
			confirm_pending.erase(cmd)
			b.text = text
			run(cmd + " confirm")
		else:
			confirm_pending[cmd] = now
			b.text = "Click again to confirm"
			get_tree().create_timer(3.0).timeout.connect(func(): if is_instance_valid(b): b.text = text))
	return b

func _row(parent: Control, items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for it in items:
		h.add_child(it)
	parent.add_child(h)
	return h

func _num_field(placeholder: String, w: int = 160) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size.x = w
	return le

# ---------------------------------------------------------------- tabs

func _tab_console() -> Control:
	var v := VBoxContainer.new()
	v.name = "Console"
	log_view = RichTextLabel.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.scroll_following = true
	log_view.selection_enabled = true
	v.add_child(log_view)
	input = LineEdit.new()
	input.placeholder_text = "Type a command (help, money set 1000000, spawn mtank 5...). Up/Down: history, Tab: complete"
	input.text_submitted.connect(func(t):
		if t.strip_edges() != "":
			run(t)
		input.text = ""
		hist_i = -1)
	input.gui_input.connect(_console_keys)
	v.add_child(input)
	_log("Developer console ready. Type 'help' for every command.", UITheme.DIM)
	return v

func _console_keys(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed):
		return
	var h: Array = game.cheats.history
	if ev.keycode == KEY_UP and h.size() > 0:
		hist_i = h.size() - 1 if hist_i < 0 else maxi(0, hist_i - 1)
		input.text = h[hist_i]
		input.caret_column = input.text.length()
		input.accept_event()
	elif ev.keycode == KEY_DOWN and hist_i >= 0:
		hist_i += 1
		input.text = h[hist_i] if hist_i < h.size() else ""
		if hist_i >= h.size():
			hist_i = -1
		input.caret_column = input.text.length()
		input.accept_event()
	elif ev.keycode == KEY_TAB:
		var opts: Array = game.cheats.autocomplete(input.text.to_lower())
		if opts.size() == 1:
			input.text = String(opts[0]).split(" <")[0].split(" [")[0].split("|")[0]
			input.caret_column = input.text.length()
		elif opts.size() > 1:
			_log("  " + "\n  ".join(opts.slice(0, 20)), UITheme.DIM)
		input.accept_event()
	elif ev.keycode == KEY_F10 or ev.keycode == KEY_ESCAPE:
		visible = false
		input.release_focus()
		input.accept_event()

func _tab_economy() -> Control:
	var pv := _scroll_page("Economy")
	var v: VBoxContainer = pv[1]
	v.add_child(UITheme.label("Money (credits)", 15, UITheme.AMBER))
	money_field = _num_field("amount, e.g. 1000000")
	_row(v, [money_field,
		UITheme.button("Set", func(): run("money set " + money_field.text)),
		UITheme.button("Add", func(): run("money add " + money_field.text)),
		UITheme.button("Subtract", func(): run("money subtract " + money_field.text))])
	_row(v, [UITheme.button("+10,000", func(): run("money add 10000")), UITheme.button("+100,000", func(): run("money add 100000")),
		UITheme.button("Set 1,000,000", func(): run("money set 1000000")), UITheme.button("Set 999,999,999", func(): run("money set 999999999"))])
	v.add_child(UITheme.label("Stored resources", 15, UITheme.AMBER))
	ore_field = _num_field("amount")
	var kind := OptionButton.new()
	for k in ["ore", "gems", "all"]:
		kind.add_item(k)
	_row(v, [kind, ore_field])
	_row(v, [UITheme.button("Set", func(): run("resources set %s %s" % [kind.get_item_text(kind.selected), ore_field.text])),
		UITheme.button("Add", func(): run("resources add %s %s" % [kind.get_item_text(kind.selected), ore_field.text])),
		UITheme.button("Subtract", func(): run("resources subtract %s %s" % [kind.get_item_text(kind.selected), ore_field.text]))])
	v.add_child(UITheme.label("Power output", 15, UITheme.AMBER))
	power_field = _num_field("total power, e.g. 999999")
	_row(v, [power_field, UITheme.button("Set power", func(): run("power set " + power_field.text))])
	v.add_child(_toggle("unlimited_storage"))
	v.add_child(_toggle("no_depletion"))
	return pv[0]

func _toggle(flag: String) -> CheckBox:
	var cb := CheckBox.new()
	cb.text = Cheats.FLAG_LABELS.get(flag, flag)
	cb.toggled.connect(func(on):
		if game.cheats.flags.get(flag, false) != on:
			game.cheats.set_flag(flag, on)
			_log("%s: %s" % [cb.text, "ON" if on else "OFF"], UITheme.GOOD))
	toggles[flag] = toggles.get(flag, []) + [cb]
	return cb

func _tab_toggles() -> Control:
	var pv := _scroll_page("Production")
	var v: VBoxContainer = pv[1]
	v.add_child(UITheme.label("Construction and production", 15, UITheme.AMBER))
	for f in ["instant_build", "instant_units", "free_build", "free_units", "unlimited_queue", "no_prereq", "instant_deploy", "instant_repair", "build_anywhere", "auto_repair_units", "auto_repair_buildings"]:
		v.add_child(_toggle(f))
	_row(v, [UITheme.button("Unlock all technology", func(): run("research instant"))])
	v.add_child(UITheme.label("Cheat persistence", 15, UITheme.AMBER))
	persist_opt = OptionButton.new()
	persist_opt.add_item("This match only")
	persist_opt.add_item("This session (until the game is closed)")
	persist_opt.add_item("Saved for future matches")
	persist_opt.item_selected.connect(func(i): run("persist " + ["match", "session", "saved"][i]))
	v.add_child(persist_opt)
	_row(v, [UITheme.button("Reset all cheats to default", func(): run("reset"))])
	return pv[0]

func _tab_spawn() -> Control:
	var pv := _scroll_page("Spawn")
	var v: VBoxContainer = pv[1]
	v.add_child(UITheme.label("Spawn units or structures", 15, UITheme.AMBER))
	spawn_type = OptionButton.new()
	for t in Data.units:
		spawn_type.add_item("%s  [%s]" % [Data.units[t].name, t])
		spawn_type.set_item_metadata(spawn_type.item_count - 1, t)
	for t in Data.buildings:
		spawn_type.add_item("%s  [%s] (structure)" % [Data.buildings[t].name, t])
		spawn_type.set_item_metadata(spawn_type.item_count - 1, t)
	v.add_child(spawn_type)
	spawn_owner = OptionButton.new()
	for p in game.players:
		spawn_owner.add_item("%s (%s)" % [p.name, Data.factions[p.faction].short])
	spawn_count = SpinBox.new()
	spawn_count.min_value = 1
	spawn_count.max_value = Cheats.MAX_SPAWN
	spawn_count.value = 1
	_row(v, [UITheme.label("Owner"), spawn_owner, UITheme.label("Quantity"), spawn_count])
	spawn_loc = OptionButton.new()
	spawn_loc.add_item("At mouse cursor")
	spawn_loc.add_item("At owner's base")
	spawn_loc.add_item("At map cell X/Y")
	spawn_x = SpinBox.new()
	spawn_x.max_value = game.map.w - 1
	spawn_y = SpinBox.new()
	spawn_y.max_value = game.map.h - 1
	_row(v, [spawn_loc, spawn_x, spawn_y])
	v.add_child(UITheme.label("Tip: with 'At mouse cursor', hover the battlefield, then press Enter in the console with the last spawn command.", 12, UITheme.DIM))
	_row(v, [UITheme.button("Spawn", _do_spawn), UITheme.button("Spawn ore collector", func(): run("spawn harv"))])
	return pv[0]

func _do_spawn() -> void:
	var t: String = spawn_type.get_item_metadata(spawn_type.selected)
	var owner := "p%d" % (spawn_owner.selected + 1)
	var cmd := "spawn %s %d %s" % [t, int(spawn_count.value), owner]
	match spawn_loc.selected:
		1:
			var c: Vector2i = game._base_center(spawn_owner.selected)
			cmd += " at %d %d" % [c.x, c.y]
		2:
			cmd += " at %d %d" % [int(spawn_x.value), int(spawn_y.value)]
		_:
			var c: Vector2i = game.cursor_cell
			if not game.map.in_bounds(c):
				c = game._base_center(spawn_owner.selected)
			cmd += " at %d %d" % [c.x, c.y]
	run(cmd)

func _tab_selected() -> Control:
	var pv := _scroll_page("Selected")
	var v: VBoxContainer = pv[1]
	v.add_child(UITheme.label("Applies to the current selection", 15, UITheme.AMBER))
	health_field = _num_field("health value")
	_row(v, [health_field, UITheme.button("Set health", func(): run("health set " + health_field.text)), UITheme.button("Full health", func(): run("health full"))])
	_row(v, [UITheme.button("Invulnerable ON", func(): run("invulnerable on")), UITheme.button("Invulnerable OFF", func(): run("invulnerable off"))])
	_row(v, [UITheme.button("Repair selected", func(): run("repair selected")), _confirm_button("Destroy selected", "destroy selected")])
	tele_x = SpinBox.new()
	tele_x.max_value = game.map.w - 1
	tele_y = SpinBox.new()
	tele_y.max_value = game.map.h - 1
	_row(v, [UITheme.label("Teleport to cell"), tele_x, tele_y, UITheme.button("Teleport", func(): run("teleport %d %d" % [int(tele_x.value), int(tele_y.value)]))])
	return pv[0]

func _tab_battlefield() -> Control:
	var pv := _scroll_page("Battlefield")
	var v: VBoxContainer = pv[1]
	for f in ["reveal_map", "no_fog", "reveal_enemies", "freeze_enemies", "ai_disabled", "no_power"]:
		v.add_child(_toggle(f))
	_row(v, [_confirm_button("Remove all enemies", "remove enemies"), _confirm_button("Remove friendly forces", "remove friendly")])
	_row(v, [_confirm_button("Force victory", "victory"), _confirm_button("Force defeat", "defeat")])
	v.add_child(UITheme.label("Simulation speed", 15, UITheme.AMBER))
	speed_slider = HSlider.new()
	speed_slider.min_value = 0.25
	speed_slider.max_value = 8.0
	speed_slider.step = 0.25
	speed_slider.value = game.speed
	speed_slider.value_changed.connect(func(val):
		if absf(val - game.speed) > 0.01:
			run("speed %.2f" % val))
	v.add_child(speed_slider)
	_row(v, [UITheme.button("Normal speed", func(): run("speed reset"))])
	return pv[0]

func _sync() -> void:
	for f in toggles:
		for cb in toggles[f]:
			cb.set_pressed_no_signal(bool(game.cheats.flags.get(f, false)))
	if persist_opt != null:
		persist_opt.select(["match", "session", "saved"].find(game.cheats.persistence))
	if speed_slider != null:
		speed_slider.set_value_no_signal(game.speed)
