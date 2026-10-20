class_name HUD
extends CanvasLayer
## In-game interface: top bar, sidebar (credits, power, minimap, build tabs, queue),
## selection panel with commands, message log, pause/game menu and game-over screen.

const CATS := [["building", "Build"], ["defense", "Defense"], ["infantry", "Infantry"], ["vehicle", "Vehicle"]]
const SIDEBAR_W := 316

var game: Game
var controller: PlayerController
var main = null
var root: Control
var credits_label: Label
var power_bar: Control
var power_label: Label
var minimap: Minimap
var tab_buttons := {}
var current_cat: String = "building"
var grid: GridContainer
var buttons: Array = []
var queue_box: HBoxContainer
var queue_label: Label
var sel_panel: PanelContainer
var sel_info: VBoxContainer
var sel_cmds: HFlowContainer
var msg_box: VBoxContainer
var speed_label: Label
var time_label: Label
var objective_label: Label
var pause_overlay: Label
var menu_panel: PanelContainer
var over_panel: PanelContainer
var cheat_panel = null
var dev_button: Button
var box_overlay: Control
var shown_credits: float = 0.0
var sel_status: Label = null
var sel_status_target = null
var refresh_t: float = 0.0

func setup(g: Game, pc: PlayerController, m) -> void:
	game = g
	controller = pc
	main = m
	controller.hud = self
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.make(g.players[g.human_pid].color)
	add_child(root)
	shown_credits = g.players[g.human_pid].credits()
	_build_box_overlay()
	_build_sidebar()
	_build_topbar()
	_build_selection_panel()
	_build_messages()
	_build_pause_overlay()
	controller.sidebar_width = SIDEBAR_W
	controller.selection_changed.connect(_refresh_selection)
	controller.mode_changed.connect(_refresh_selection)
	game.message.connect(_on_message)
	game.game_over.connect(_on_game_over)
	cheat_panel = CheatPanel.new()
	cheat_panel.setup(game, self)
	cheat_panel.visible = false
	root.add_child(cheat_panel)
	_select_tab("building")
	_refresh_selection()

# ---------------------------------------------------------------- layout builders

func _build_box_overlay() -> void:
	box_overlay = Control.new()
	box_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	box_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_overlay.draw.connect(func():
		if controller.dragging and controller.drag_start.distance_to(controller.drag_now) > 8.0:
			var r := Rect2(controller.drag_start, controller.drag_now - controller.drag_start).abs()
			box_overlay.draw_rect(r, Color(0.5, 1.0, 0.6, 0.08))
			box_overlay.draw_rect(r, Color(0.6, 1.0, 0.7, 0.9), false, 1.0))
	root.add_child(box_overlay)

func _metal(name: String, margin: int) -> StyleBox:
	var tex: Texture2D = SpriteLib._load_tex("res://assets/ui/%s.png" % name)
	if tex == null:
		return UITheme.box(UITheme.PANEL, UITheme.BORDER, 1, 0, 8)
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _build_sidebar() -> void:
	var faction: String = game.players[game.human_pid].faction
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", _metal("panel_" + faction, 12))
	side.clip_contents = true
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -SIDEBAR_W
	side.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	side.add_child(v)
	# Faction insignia and credits readout.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var emb := TextureRect.new()
	emb.texture = SpriteLib._load_tex("res://assets/ui/emblem_%s.png" % faction)
	emb.custom_minimum_size = Vector2(52, 52)
	emb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(emb)
	var cr := PanelContainer.new()
	cr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_theme_stylebox_override("panel", UITheme.box(Color("#050607"), Color("#000000"), 2, 3, 8))
	credits_label = UITheme.label("$ 0", 26, UITheme.AMBER)
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credits_label.add_theme_color_override("font_shadow_color", Color(1, 0.6, 0.1, 0.35))
	credits_label.add_theme_constant_override("shadow_outline_size", 4)
	cr.add_child(credits_label)
	head.add_child(cr)
	v.add_child(head)
	# Power bar.
	var ph := HBoxContainer.new()
	power_label = UITheme.label("Power 0/0", 13, UITheme.DIM)
	power_label.custom_minimum_size.x = 118
	ph.add_child(power_label)
	power_bar = Control.new()
	power_bar.custom_minimum_size = Vector2(60, 14)
	power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	power_bar.draw.connect(_draw_power_bar)
	ph.add_child(power_bar)
	v.add_child(ph)
	# Minimap.
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(SIDEBAR_W - 18, SIDEBAR_W - 40)
	minimap.setup(game, controller)
	v.add_child(minimap)
	# Tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	for c in CATS:
		var b := Button.new()
		b.text = c[1]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_select_tab.bind(c[0]))
		tabs.add_child(b)
		tab_buttons[c[0]] = b
	v.add_child(tabs)
	# Build grid.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	v.add_child(scroll)
	# Queue strip.
	queue_label = UITheme.label("Queue", 12, UITheme.DIM)
	queue_label.clip_text = true
	queue_label.custom_minimum_size.x = 10
	v.add_child(queue_label)
	queue_box = HBoxContainer.new()
	queue_box.custom_minimum_size.y = 44
	queue_box.add_theme_constant_override("separation", 3)
	v.add_child(queue_box)
	# Repair / sell.
	var tools := HBoxContainer.new()
	tools.add_child(_tool_button("Repair (R)", func(): controller.set_mode("repair" if controller.mode != "repair" else "")))
	tools.add_child(_tool_button("Sell (T)", func(): controller.set_mode("sell" if controller.mode != "sell" else "")))
	tools.add_child(_tool_button("Base", func():
		controller.center_on(MapGrid.cell_center(game._base_center(game.human_pid)))))
	v.add_child(tools)

func _tool_button(text: String, cb: Callable) -> Button:
	var b = UITheme.button(text, cb)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 12)
	return b

func _build_topbar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _metal("plate_" + game.players[game.human_pid].faction, 10))
	bar.anchor_right = 1.0
	bar.offset_right = -SIDEBAR_W
	bar.offset_bottom = 38
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	bar.add_child(h)
	var mb = UITheme.button("Menu (Esc)", toggle_menu)
	mb.focus_mode = Control.FOCUS_NONE
	h.add_child(mb)
	var pb = UITheme.button("Pause", toggle_pause)
	pb.focus_mode = Control.FOCUS_NONE
	h.add_child(pb)
	var sd = UITheme.button("-", func(): game.set_speed(game.speed - 0.25))
	sd.focus_mode = Control.FOCUS_NONE
	h.add_child(sd)
	speed_label = UITheme.label("1.00x", 14)
	speed_label.custom_minimum_size.x = 56
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(speed_label)
	var su = UITheme.button("+", func(): game.set_speed(game.speed + 0.25))
	su.focus_mode = Control.FOCUS_NONE
	h.add_child(su)
	time_label = UITheme.label("00:00", 14, UITheme.DIM)
	h.add_child(time_label)
	objective_label = UITheme.label("", 14, UITheme.TEXT)
	objective_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective_label.clip_text = true
	h.add_child(objective_label)
	dev_button = UITheme.button("Developer tools (F10)", toggle_cheats)
	dev_button.focus_mode = Control.FOCUS_NONE
	dev_button.visible = game.cheats.enabled and bool(Config.settings.show_dev_tools)
	h.add_child(dev_button)

func _build_selection_panel() -> void:
	sel_panel = PanelContainer.new()
	sel_panel.add_theme_stylebox_override("panel", _metal("panel_" + game.players[game.human_pid].faction, 12))
	sel_panel.anchor_top = 1.0
	sel_panel.anchor_bottom = 1.0
	sel_panel.offset_top = -150
	sel_panel.offset_left = 8
	sel_panel.offset_bottom = -8
	sel_panel.offset_right = 700
	sel_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(sel_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	sel_panel.add_child(h)
	sel_info = VBoxContainer.new()
	sel_info.custom_minimum_size.x = 360
	h.add_child(sel_info)
	sel_cmds = HFlowContainer.new()
	sel_cmds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sel_cmds)

func _build_messages() -> void:
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(12, 48)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.add_theme_constant_override("separation", 2)
	root.add_child(msg_box)

func _build_pause_overlay() -> void:
	pause_overlay = UITheme.label("PAUSED  -  press F9 or Pause to resume", 30, UITheme.AMBER)
	pause_overlay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_overlay.position = Vector2(0, 120)
	pause_overlay.anchor_left = 0.0
	pause_overlay.anchor_right = 1.0
	pause_overlay.offset_right = -SIDEBAR_W
	pause_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pause_overlay)

# ---------------------------------------------------------------- sidebar behaviour

func _select_tab(cat: String) -> void:
	current_cat = cat
	for k in tab_buttons:
		tab_buttons[k].button_pressed = k == cat
	for b in buttons:
		b.queue_free()
	buttons.clear()
	var p = game.players[game.human_pid]
	for t in Data.types_in_category(cat, p.faction):
		var bb = BuildButton.new()
		bb.setup(self, t, cat)
		grid.add_child(bb)
		buttons.append(bb)
	_refresh_sidebar()

func on_build_click(bb: BuildButton, shift: bool) -> void:
	var pid := game.human_pid
	var prod = game.producer_for(pid, bb.cat)
	if prod != null:
		var it = prod.ready_item(bb.cat)
		if it != null and it.type == bb.type and (bb.cat == "building" or bb.cat == "defense"):
			controller.begin_placement(bb.type, bb.cat)
			return
	var n := 5 if shift else 1
	for i in n:
		var r := game.queue_item(pid, bb.type)
		if r != "":
			_on_message(r, "warn")
			game.play_sound("error", Vector2.INF)
			break
	_refresh_sidebar()

func on_build_cancel(bb: BuildButton) -> void:
	var prod = game.producer_for(game.human_pid, bb.cat)
	if prod == null:
		return
	var q: Array = prod.queues.get(bb.cat, [])
	for i in range(q.size() - 1, -1, -1):
		if q[i].type == bb.type:
			prod.cancel_item(bb.cat, i)
			if controller.mode == "place" and controller.place_type == bb.type:
				controller.cancel_mode()
			_on_message("Cancelled %s (refunded)." % Data.def(bb.type).name, "info")
			break
	_refresh_sidebar()

func _refresh_sidebar() -> void:
	for b in buttons:
		b.refresh(game)
	# Tab badges: show which tabs have ready items or are locked.
	var p = game.players[game.human_pid]
	for c in CATS:
		var prod = game.producer_for(game.human_pid, c[0])
		var label: String = c[1]
		if prod != null and prod.ready_item(c[0]) != null and (c[0] == "building" or c[0] == "defense"):
			label += " !"
		tab_buttons[c[0]].text = label
		tab_buttons[c[0]].disabled = prod == null
		tab_buttons[c[0]].tooltip_text = "" if prod != null else "Build the matching production structure first."
	_refresh_queue()

func _refresh_queue() -> void:
	for c in queue_box.get_children():
		c.queue_free()
	var prod = game.producer_for(game.human_pid, current_cat)
	if prod == null:
		queue_label.text = "No production facility for this tab."
		return
	var q: Array = prod.queues.get(current_cat, [])
	queue_label.text = "%s queue %d/%s" % [prod.def.name, q.size(), str(prod.queue_limit()) if prod.queue_limit() < 999 else "unlimited"]
	queue_label.tooltip_text = "Click an item to move it earlier. Right-click to cancel (refunds what was paid)."
	for i in mini(q.size(), 7):
		var it: Dictionary = q[i]
		var qi := Control.new()
		qi.custom_minimum_size = Vector2(38, 40)
		qi.tooltip_text = "%s - %d%%%s" % [Data.def(it.type).name, int(float(it.progress) * 100), " (on hold: need credits)" if it.state == "hold" else ""]
		var idx := i
		qi.draw.connect(func():
			var pl = game.players[game.human_pid]
			IconView.draw(qi, it.type, Rect2(Vector2.ZERO, qi.size), pl.color, pl.faction)
			qi.draw_rect(Rect2(0, qi.size.y - 4, qi.size.x * float(it.progress), 4), UITheme.GOOD if it.state != "hold" else UITheme.BAD)
			qi.draw_rect(Rect2(Vector2.ZERO, qi.size), UITheme.BORDER, false, 1.0))
		qi.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT:
					prod.move_item(current_cat, idx, -1)
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					prod.cancel_item(current_cat, idx)
				_refresh_sidebar())
		queue_box.add_child(qi)

func _draw_power_bar() -> void:
	var p = game.players[game.human_pid]
	var s := power_bar.size
	power_bar.draw_rect(Rect2(Vector2.ZERO, s), Color("#07090b"))
	var total: int = p.power_total()
	var use: int = p.power_use
	var mx := float(maxi(maxi(total, use), 1))
	var col = UITheme.GOOD if not p.low_power() else UITheme.BAD
	power_bar.draw_rect(Rect2(1, 1, (s.x - 2) * clampf(total / mx, 0, 1), s.y - 2), col.darkened(0.3))
	var ux := (s.x - 2) * clampf(use / mx, 0, 1)
	power_bar.draw_rect(Rect2(ux, 0, 2, s.y), Color.WHITE)
	power_bar.draw_rect(Rect2(Vector2.ZERO, s), UITheme.BORDER, false, 1.0)

# ---------------------------------------------------------------- selection panel

func _refresh_selection() -> void:
	sel_status = null
	sel_status_target = null
	for c in sel_info.get_children():
		c.queue_free()
	for c in sel_cmds.get_children():
		c.queue_free()
	var sel: Array = controller.selection.filter(func(e): return is_instance_valid(e) and not e.dead)
	if controller.mode != "":
		var hint := {"place": "Placing %s - left-click to build, right-click to cancel, Shift to keep placing." % Data.def(controller.place_type).get("name", ""),
			"attack_move": "Attack-move: click a destination. Units engage enemies on the way.",
			"patrol": "Patrol: click the second patrol point.",
			"repair": "Repair mode: click your damaged structures (costs credits). Right-click to exit.",
			"sell": "Sell mode: click a structure to sell it for 50% (by health). Right-click to exit."}
		var l = UITheme.label(hint.get(controller.mode, ""), 14, UITheme.AMBER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		sel_info.add_child(l)
	if sel.is_empty():
		if controller.mode == "":
			sel_info.add_child(UITheme.label("No selection", 18, UITheme.DIM))
			var help = UITheme.label("Drag to select units. Right-click to move or attack.\nCtrl+1-9 assigns groups, 1-9 recalls. Q attack-move, X stop, G guard, H hold, P patrol, V scatter, E deploy.", 12, UITheme.DIM)
			help.autowrap_mode = TextServer.AUTOWRAP_WORD
			sel_info.add_child(help)
		return
	var first = sel[0]
	var types := {}
	for e in sel:
		types[e.type] = int(types.get(e.type, 0)) + 1
	var head := HBoxContainer.new()
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(64, 56)
	var ft: String = first.type
	var fcol: Color = first.team_color()
	var ffac: String = first.player().faction
	var cam_tex: Texture2D = BuildButton.cameo_for(ft, ffac)
	icon.custom_minimum_size = Vector2(84, 66)
	icon.draw.connect(func():
		if cam_tex != null:
			icon.draw_texture_rect(cam_tex, Rect2(Vector2.ZERO, icon.size), false)
		else:
			IconView.draw(icon, ft, Rect2(Vector2.ZERO, icon.size), fcol, ffac))
	head.add_child(icon)
	var tv := VBoxContainer.new()
	var title: String = first.def.name if types.size() == 1 else "%d units selected" % sel.size()
	if types.size() == 1 and sel.size() > 1:
		title = "%d x %s" % [sel.size(), first.def.name]
	tv.add_child(UITheme.label(title, 17))
	var owner_txt := "" if first.pid == game.human_pid else "  (%s)" % first.player().name
	if sel.size() == 1:
		var st := "HP %d / %d%s" % [int(first.hp), int(first.max_hp), owner_txt]
		if first.is_unit():
			st += "   |   " + _order_text(first)
		elif first.is_building():
			if not first.completed:
				st += "   |   deploying"
			elif first.requires_power() and not first.powered():
				st += "   |   OFFLINE (low power)"
		sel_status = UITheme.label(st, 13, UITheme.DIM)
		sel_status_target = first
		tv.add_child(sel_status)
		if first.def.has("role"):
			var rl = UITheme.label(first.def.role, 12, UITheme.DIM)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD
			rl.custom_minimum_size.x = 280
			tv.add_child(rl)
	else:
		var parts := []
		for t in types:
			parts.append("%d %s" % [types[t], Data.def(t).name])
		var l = UITheme.label(", ".join(parts), 12, UITheme.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size.x = 280
		tv.add_child(l)
	head.add_child(tv)
	sel_info.add_child(head)
	if first.pid != game.human_pid:
		return
	if controller.own_units().size() > 0:
		_cmd("Attack-move (Q)", controller.set_mode.bind("attack_move"))
		_cmd("Stop (X)", _each.bind("cmd_stop"))
		_cmd("Guard (G)", _each.bind("cmd_guard"))
		_cmd("Hold (H)", _each.bind("cmd_hold"))
		_cmd("Patrol (P)", controller.set_mode.bind("patrol"))
		_cmd("Scatter (V)", _each.bind("cmd_scatter"))
		var has_mcv := false
		var has_harv := false
		for u in controller.own_units():
			has_mcv = has_mcv or u.def.has("deploys_to")
			has_harv = has_harv or u.is_harvester
		if has_mcv:
			_cmd("Deploy (E)", _each.bind("cmd_deploy"))
		if has_harv:
			_cmd("Harvest", _each.bind("cmd_harvest"))
	elif first.is_building() and sel.size() == 1:
		var b = first
		_cmd("Repair" if not b.repairing else "Stop repair", func():
			b.repairing = not b.repairing
			_refresh_selection())
		_cmd("Sell", func(): game.sell_building(b))
		if not b.queues.is_empty():
			_cmd("Set primary", func():
				for cat in b.queues:
					game.players[game.human_pid].primary[cat] = b.uid
				_on_message("%s is now the primary facility." % b.def.name, "info")
				_refresh_sidebar())
			var l = UITheme.label("Right-click the ground to set a rally point.", 12, UITheme.DIM)
			sel_cmds.add_child(l)

func _each(method: String) -> void:
	for u in controller.own_units():
		if method == "cmd_deploy" and not u.def.has("deploys_to"):
			continue
		if method == "cmd_harvest" and not u.is_harvester:
			continue
		u.call(method)

func _update_status() -> void:
	if sel_status == null or not is_instance_valid(sel_status) or sel_status_target == null or not is_instance_valid(sel_status_target) or sel_status_target.dead:
		return
	var e = sel_status_target
	var st := "HP %d / %d" % [int(e.hp), int(e.max_hp)]
	if e.pid != game.human_pid:
		st += "  (%s)" % e.player().name
	if e.is_unit():
		st += "   |   " + _order_text(e)
	elif not e.completed:
		st += "   |   deploying"
	elif e.requires_power() and not e.powered():
		st += "   |   OFFLINE (low power)"
	elif e.repairing:
		st += "   |   repairing"
	sel_status.text = st

func _cmd(text: String, cb: Callable) -> void:
	var b = UITheme.button(text, cb)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	sel_cmds.add_child(b)

func _order_text(u) -> String:
	if u.is_harvester:
		var states := {"seek": "looking for ore", "to_field": "heading to ore field", "mining": "harvesting", "to_refinery": "returning to refinery",
			"wait_dock": "waiting for refinery", "unloading": "unloading"}
		return "Ore %d/%d - %s" % [u.cargo, u.capacity, states.get(u.harv_state, "idle")]
	return {"idle": "Idle", "move": "Moving", "attack": "Attacking", "attack_move": "Attack-moving", "guard": "Guarding",
		"patrol": "Patrolling", "hold": "Holding position", "harvest": "Harvesting"}.get(u.order, u.order)

# ---------------------------------------------------------------- messages, menus

func _on_message(text: String, kind: String) -> void:
	var col = {"alert": UITheme.BAD, "warn": UITheme.AMBER, "build": UITheme.GOOD, "unit": Color("#9fd0ff")}.get(kind, UITheme.TEXT)
	var l = UITheme.label(text, 15, col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	msg_box.add_child(l)
	while msg_box.get_child_count() > 7:
		msg_box.get_child(0).free()
	var tw = l.create_tween()
	tw.tween_interval(5.5)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)
	if kind == "alert" and main != null and main.audio != null:
		main.audio.ui("alert")

func toggle_pause() -> void:
	game.paused = not game.paused
	pause_overlay.visible = game.paused and (menu_panel == null or not menu_panel.visible)

func toggle_cheats() -> void:
	if not game.cheats.enabled:
		_on_message("Developer tools are disabled for this match (enable cheats in the skirmish setup or play Sandbox).", "warn")
		return
	cheat_panel.visible = not cheat_panel.visible
	if cheat_panel.visible:
		cheat_panel.on_open()

func toggle_menu() -> void:
	if menu_panel != null and is_instance_valid(menu_panel) and menu_panel.visible:
		menu_panel.queue_free()
		menu_panel = null
		game.paused = false
		pause_overlay.visible = false
		return
	game.paused = true
	pause_overlay.visible = false
	menu_panel = PanelContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.custom_minimum_size = Vector2(420, 0)
	root.add_child(menu_panel)
	_fill_menu_main()

func _menu_reset() -> VBoxContainer:
	for c in menu_panel.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	menu_panel.add_child(v)
	menu_panel.position = (root.size - Vector2(420, 420)) * 0.5
	return v

func _fill_menu_main() -> void:
	var v := _menu_reset()
	v.add_child(UITheme.title_label("Game Menu", 24))
	v.add_child(UITheme.button("Resume", toggle_menu))
	v.add_child(UITheme.button("Save game", _fill_menu_save))
	v.add_child(UITheme.button("Load game", _fill_menu_load))
	v.add_child(UITheme.button("Audio settings", _fill_menu_audio))
	v.add_child(UITheme.button("Restart match (same settings)", func(): main.restart_match()))
	v.add_child(UITheme.button("Quit to main menu", func(): main.quit_to_menu()))
	v.add_child(UITheme.button("Exit game", func(): get_tree().quit()))

func _fill_menu_save() -> void:
	var v := _menu_reset()
	v.add_child(UITheme.title_label("Save game", 22))
	var le := LineEdit.new()
	le.text = "save_%s" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	v.add_child(le)
	var status = UITheme.label("", 13, UITheme.DIM)
	v.add_child(UITheme.button("Save", func():
		var r: String = main.save_game(le.text)
		status.text = r))
	v.add_child(status)
	v.add_child(UITheme.button("Back", _fill_menu_main))

func _fill_menu_load() -> void:
	var v := _menu_reset()
	v.add_child(UITheme.title_label("Load game", 22))
	var saves: Array = main.list_saves()
	if saves.is_empty():
		v.add_child(UITheme.label("No saved games yet.", 14, UITheme.DIM))
	for s in saves.slice(0, 10):
		v.add_child(UITheme.button("%s   (%s)" % [s.name, s.date], func(): main.load_game(s.name)))
	v.add_child(UITheme.button("Back", _fill_menu_main))

func _fill_menu_audio() -> void:
	var v := _menu_reset()
	v.add_child(UITheme.title_label("Audio", 22))
	for k in [["music_volume", "Music"], ["sfx_volume", "Effects"], ["ui_volume", "Interface"]]:
		v.add_child(UITheme.label(k[1], 14))
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 1
		s.step = 0.05
		s.value = float(Config.settings[k[0]])
		var key: String = k[0]
		s.value_changed.connect(func(val):
			Config.settings[key] = val
			Config.save_settings()
			if main.audio != null:
				main.audio.apply_volumes())
		v.add_child(s)
	v.add_child(UITheme.button("Back", _fill_menu_main))

func _on_game_over(won: bool) -> void:
	over_panel = PanelContainer.new()
	over_panel.set_anchors_preset(Control.PRESET_CENTER)
	root.add_child(over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	over_panel.add_child(v)
	v.add_child(UITheme.title_label("MISSION ACCOMPLISHED" if won else "MISSION FAILED", 36, UITheme.GOOD if won else UITheme.BAD))
	var p = game.players[game.human_pid]
	var s: Dictionary = p.stats
	v.add_child(UITheme.label("Time %s   |   Enemy losses %d   |   Your losses %d units, %d structures" % [_clock(), s.units_killed, s.units_lost, s.buildings_lost], 15))
	v.add_child(UITheme.label("Harvested $%s   |   Spent on structures $%s, on units $%s" % [UITheme.fmt(s.harvested), UITheme.fmt(s.spent_build), UITheme.fmt(s.spent_units)], 15, UITheme.DIM))
	var h := HBoxContainer.new()
	h.add_child(UITheme.button("Restart", func(): main.restart_match()))
	h.add_child(UITheme.button("Main menu", func(): main.quit_to_menu()))
	h.add_child(UITheme.button("Keep watching", func(): over_panel.queue_free()))
	v.add_child(h)
	over_panel.position = (root.size - Vector2(720, 200)) * 0.5

func _clock() -> String:
	var t := int(game.sim_time)
	return "%02d:%02d" % [t / 60, t % 60]

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	if game == null:
		return
	var p = game.players[game.human_pid]
	var target := float(p.credits())
	shown_credits = target if absf(target - shown_credits) > 50000 else move_toward(shown_credits, target, maxf(400.0, absf(target - shown_credits) * 4.0) * delta)
	credits_label.text = "$ " + UITheme.fmt(int(round(shown_credits)))
	var stored := ""
	if p.storage_cap > 0 or p.unlimited_storage():
		stored = "  |  Silos %s/%s" % [UITheme.fmt(p.stored_resources()), "inf" if p.unlimited_storage() else UITheme.fmt(p.storage_cap)]
	credits_label.tooltip_text = "Cash %s, stored ore %s, gems %s%s" % [UITheme.fmt(p.cash), UITheme.fmt(p.resources.ore), UITheme.fmt(p.resources.gems), stored]
	power_label.text = "Power %d / %d" % [p.power_total(), p.power_use]
	power_label.add_theme_color_override("font_color", UITheme.BAD if p.low_power() else UITheme.DIM)
	power_bar.queue_redraw()
	speed_label.text = "%.2fx" % game.speed
	time_label.text = _clock()
	var harv := game.units.filter(func(u): return u.pid == game.human_pid and u.is_harvester).size()
	objective_label.text = "Objective: %s   |   Collectors %d%s" % [game.objectives[0].text, harv, stored]
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.2
		_refresh_sidebar()
		_update_status()
	box_overlay.queue_redraw()
