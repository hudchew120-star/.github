class_name PlayerController
extends Node2D
## Translates mouse/keyboard input into game commands: camera, selection,
## control groups, orders, structure placement, repair/sell modes.

signal selection_changed
signal mode_changed

var game: Game
var hud = null
var view = null      # View3D or View2D
var selection: Array = []
var groups := {}
var mode: String = ""            # "", place, attack_move, patrol, repair, sell
var place_type: String = ""
var place_cat: String = ""
var dragging: bool = false
var drag_start := Vector2.ZERO   # screen coordinates
var drag_now := Vector2.ZERO
var mmb_drag: bool = false
var last_click_t: int = 0
var last_group_t := {}
var hovered = null
var markers: Array = []          # [{pos, t, col}]
var sidebar_width: float = 316.0

func setup(g: Game, v) -> void:
	game = g
	view = v
	v.controller = self
	z_index = 30
	game.entity_removed.connect(_on_entity_removed)

func _on_entity_removed(e) -> void:
	if selection.has(e):
		selection.erase(e)
		game.selection = selection
		selection_changed.emit()
	for k in groups:
		groups[k].erase(e)
	if hovered == e:
		hovered = null

# ---------------------------------------------------------------- camera

func center_on(p: Vector2) -> void:
	view.set_focus(p)

func _process(delta: float) -> void:
	if game == null:
		return
	var move := Vector2.ZERO
	if not _typing():
		if Input.is_action_pressed("cam_left"): move.x -= 1
		if Input.is_action_pressed("cam_right"): move.x += 1
		if Input.is_action_pressed("cam_up"): move.y -= 1
		if Input.is_action_pressed("cam_down"): move.y += 1
	if Config.settings.edge_scroll and DisplayServer.window_is_focused() and not dragging:
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < 6: move.x -= 1
			if mp.x > vs.x - 6: move.x += 1
			if mp.y < 6: move.y -= 1
			if mp.y > vs.y - 6: move.y += 1
	if move != Vector2.ZERO:
		view.scroll(move, float(Config.settings.scroll_speed) * delta)
	_update_hover()
	var mc := MapGrid.to_cell(view.mouse_world())
	game.cursor_cell = mc
	for m in markers:
		m.t -= delta
	markers = markers.filter(func(m): return m.t > 0.0)
	queue_redraw()

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

# ---------------------------------------------------------------- picking

var _hover_mouse := Vector2(-1, -1)
var _hover_t: float = 0.0

func _update_hover() -> void:
	# Picking walks every unit and structure, so only redo it when the mouse moved or every 0.15 s.
	var mp := get_viewport().get_mouse_position()
	_hover_t -= get_process_delta_time()
	if mp.distance_squared_to(_hover_mouse) < 4.0 and _hover_t > 0.0:
		return
	_hover_mouse = mp
	_hover_t = 0.15
	var h = view.pick(mp)
	if h != hovered:
		if hovered != null and is_instance_valid(hovered):
			hovered.hovered = false
		hovered = h
		if hovered != null:
			hovered.hovered = true
	var shape := Input.CURSOR_ARROW
	if mode == "place":
		shape = Input.CURSOR_CROSS
	elif mode in ["attack_move", "patrol", "power"]:
		shape = Input.CURSOR_CROSS
	elif mode == "repair" or mode == "sell":
		shape = Input.CURSOR_POINTING_HAND
	elif hovered != null and hovered.is_building() and own_units().any(func(u): return u.engineer) and (game.are_enemies(game.human_pid, hovered.pid) or (hovered.pid == game.human_pid and hovered.hp < hovered.max_hp)):
		shape = Input.CURSOR_POINTING_HAND
	elif hovered != null and _has_own_units() and game.are_enemies(game.human_pid, hovered.pid):
		shape = Input.CURSOR_CROSS
	Input.set_default_cursor_shape(shape)

func _pick_screen(sp: Vector2):
	return view.pick(sp)

func _has_own_units() -> bool:
	for e in selection:
		if is_instance_valid(e) and e.is_unit() and e.pid == game.human_pid:
			return true
	return false

func own_units() -> Array:
	return selection.filter(func(e): return is_instance_valid(e) and not e.dead and e.is_unit() and e.pid == game.human_pid)

# ---------------------------------------------------------------- selection

func set_selection(list: Array, add: bool = false) -> void:
	if not add:
		for e in selection:
			if is_instance_valid(e):
				e.selected = false
				e.queue_redraw()
		selection = []
	for e in list:
		if is_instance_valid(e) and not e.dead and not selection.has(e):
			selection.append(e)
			e.selected = true
			e.queue_redraw()
	game.selection = selection
	if selection.size() > 0 and selection[0].pid == game.human_pid:
		game.play_sound("select", Vector2.INF)
	selection_changed.emit()

func toggle(e) -> void:
	if selection.has(e):
		selection.erase(e)
		e.selected = false
		game.selection = selection
		selection_changed.emit()
	else:
		set_selection([e], true)

func _box_select(a: Vector2, b: Vector2, add: bool) -> void:
	# a and b are screen positions; test each unit's projected position.
	var r := Rect2(a, b - a).abs().grow(4.0)
	var found := []
	for u in game.units:
		if u.pid == game.human_pid and not u.dead and r.has_point(view.world_to_screen(u.pos, 0.15)):
			found.append(u)
	# Prefer combat units over collectors when both are boxed.
	var fighters := found.filter(func(u): return not u.is_harvester)
	set_selection(fighters if fighters.size() > 0 else found, add)

func _select_same_type(e) -> void:
	var list := []
	for u in game.units:
		if u.pid == e.pid and u.type == e.type and not u.dead and view.screen_has(view.world_to_screen(u.pos), 0.0):
			list.append(u)
	set_selection(list)

# ---------------------------------------------------------------- modes

func begin_placement(t: String, cat: String) -> void:
	mode = "place"
	place_type = t
	place_cat = cat
	mode_changed.emit()

func set_mode(m: String) -> void:
	mode = m
	if m != "place":
		place_type = ""
	mode_changed.emit()

var power_id: String = ""

## E / Deploy button: construction vehicles unpack, Coalition riflemen dig in, minelayers lay a mine.
func deploy_selected() -> void:
	for u in own_units():
		if u.def.has("deploys_to") or u.can_dig_in() or u.def.has("minelayer"):
			u.cmd_deploy()

func begin_power(id: String) -> void:
	var st: Dictionary = game.specials.power_state(game.human_pid, id)
	if not st.ready:
		hud_message("%s: %s" % [Specials.POWERS[id].name, "recharging" if st.available else "requires an Airfield"], "warn")
		game.play_sound("error", Vector2.INF)
		return
	power_id = id
	set_mode("power")

func cancel_mode() -> void:
	set_mode("")

func placement_cell() -> Vector2i:
	var size: Vector2i = Data.def(place_type).size
	var p: Vector2 = view.mouse_world() - Vector2(size) * MapGrid.T * 0.5 + Vector2(MapGrid.T, MapGrid.T) * 0.5
	return MapGrid.to_cell(p)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.over and not event is InputEventKey:
		pass
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		if mmb_drag:
			view.pan_screen(event.relative)
		if dragging:
			drag_now = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)

func _mouse_button(ev: InputEventMouseButton) -> void:
	var wp: Vector2 = view.mouse_world()
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if ev.pressed:
			view.zoom_by(1.1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1, ev.position)
		return
	if ev.button_index == MOUSE_BUTTON_MIDDLE:
		mmb_drag = ev.pressed
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		if mode != "":
			cancel_mode()
			return
		_right_click(wp, ev.shift_pressed, ev.position)
		return
	if ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if ev.pressed:
		match mode:
			"place":
				var c := placement_cell()
				var r := game.place_structure(game.human_pid, place_cat, c)
				if r == "":
					if not ev.shift_pressed:
						cancel_mode()
				else:
					hud_message(r, "warn")
					game.play_sound("error", Vector2.INF)
				return
			"power":
				var r: String = game.specials.use_power(game.human_pid, power_id, wp)
				if r != "":
					hud_message(r, "warn")
					game.play_sound("error", Vector2.INF)
				else:
					_marker(wp, Color(1, 0.8, 0.2))
				cancel_mode()
				return
			"attack_move", "patrol":
				game.command_group(own_units(), mode, wp)
				_marker(wp, Color(1, 0.3, 0.2) if mode == "attack_move" else Color(0.4, 0.7, 1))
				game.play_sound("move", Vector2.INF)
				if not ev.shift_pressed:
					cancel_mode()
				return
			"repair", "sell":
				var e = _pick_screen(ev.position)
				if e != null and e.is_building() and e.pid == game.human_pid:
					if mode == "sell":
						game.sell_building(e)
					else:
						e.repairing = not e.repairing
				else:
					cancel_mode()
				return
		dragging = true
		drag_start = ev.position
		drag_now = ev.position
	else:
		if not dragging:
			return
		dragging = false
		if drag_start.distance_to(ev.position) > 8.0:
			_box_select(drag_start, ev.position, ev.shift_pressed)
			return
		var e = _pick_screen(ev.position)
		var now := Time.get_ticks_msec()
		var dbl := now - last_click_t < 350
		last_click_t = now
		if e == null:
			if not ev.shift_pressed:
				set_selection([])
			return
		if dbl and e.is_unit() and e.pid == game.human_pid:
			_select_same_type(e)
		elif ev.shift_pressed and e.pid == game.human_pid:
			toggle(e)
		else:
			set_selection([e])

func _right_click(wp: Vector2, shift: bool, sp: Vector2) -> void:
	var units := own_units()
	var target = _pick_screen(sp)
	if units.is_empty():
		# Production building selected: set its rally point.
		var set_any := false
		for e in selection:
			if is_instance_valid(e) and e.is_building() and e.pid == game.human_pid and not e.queues.is_empty():
				e.rally = wp
				set_any = true
		if set_any:
			_marker(wp, Color(1, 1, 1))
			game.play_sound("click", Vector2.INF)
		else:
			set_selection([])
		return
	var planters := units.filter(func(u): return u.def.has("planter") and u.plant_cd <= 0.0)
	if target != null and game.are_enemies(game.human_pid, target.pid) and planters.size() > 0:
		var usable := planters.filter(func(u): return target.is_building() or not u.def.planter.get("buildings_only", false))
		if usable.size() > 0:
			# Commando C4 / demolition charge; the rest of the selection attacks normally.
			usable[0].cmd_plant(target)
			var rest := units.filter(func(u): return u != usable[0])
			if rest.size() > 0:
				game.command_group(rest, "attack", wp, target)
			_marker(target.pos, Color(1, 0.55, 0.1))
			game.play_sound("move", Vector2.INF)
			return
	var engineers := units.filter(func(u): return u.engineer)
	if target != null and target.is_building() and engineers.size() > 0 and (game.are_enemies(game.human_pid, target.pid) or (target.pid == game.human_pid and target.hp < target.max_hp)):
		# Engineers capture enemy structures or fully repair our own; one engineer is enough.
		engineers[0].cmd_capture(target)
		var rest := units.filter(func(u): return u != engineers[0])
		if rest.size() > 0 and game.are_enemies(game.human_pid, target.pid):
			game.command_group(rest.filter(func(u): return not u.engineer), "attack", wp, target)
		_marker(target.pos, Color(1, 0.85, 0.2))
	elif target != null and game.are_enemies(game.human_pid, target.pid):
		game.command_group(units, "attack", wp, target)
		_marker(target.pos, Color(1, 0.2, 0.15))
	elif target != null and target.is_building() and target.pid == game.human_pid and target.def.has("repair_rate"):
		# Send vehicles to the repair facility.
		var r: Rect2 = target.rect_px()
		var i := 0
		for u in units:
			if u.is_air_unit or u.is_naval:
				u.cmd_move(wp)
				continue
			var off := Vector2(((i % 3) - 1) * 14.0, ((i / 3) % 3 - 1) * 14.0)
			u.cmd_move(r.get_center() + off)
			i += 1
		_marker(r.get_center(), Color(0.4, 0.8, 1))
	elif target != null and target.is_building() and target.pid == game.human_pid and target.def.has("pads") and units.any(func(u): return u.is_air_unit):
		for u in units:
			if u.is_air_unit:
				u._return_to_base(target)
			else:
				u.cmd_move(wp)
		_marker(target.pos, Color(0.4, 0.8, 1))
	elif target != null and target.is_building() and target.pid == game.human_pid and target.def.has("dock"):
		for u in units:
			if u.is_harvester:
				u.order = "harvest"
				u.harv_state = "to_refinery"
				u.dock_uid = target.uid
				u.goal = MapGrid.cell_center(target.dock_cell())
				u._request_path()
			else:
				u.cmd_move(wp)
		_marker(wp, Color(0.4, 1, 0.4))
	elif target != null and target.is_unit() and target.pid == game.human_pid and target.def.has("deploys_to") == false and units.size() == 1 and units[0] == target and units[0].def.has("deploys_to"):
		units[0].cmd_deploy()
	else:
		game.command_group(units, "move", wp)
		_marker(wp, Color(0.4, 1, 0.4))
	game.play_sound("move", Vector2.INF)

func _marker(p: Vector2, col: Color) -> void:
	markers.append({"pos": p, "t": 0.6, "col": col})

func hud_message(t: String, kind: String) -> void:
	game.message.emit(t, kind)

func _key(ev: InputEventKey) -> void:
	if _typing():
		return
	var kc := ev.physical_keycode
	if kc >= KEY_1 and kc <= KEY_9:
		var n := kc - KEY_0
		if ev.ctrl_pressed:
			groups[n] = selection.filter(func(e): return is_instance_valid(e) and e.pid == game.human_pid)
			hud_message("Group %d assigned (%d)." % [n, groups[n].size()], "info")
		else:
			var g: Array = groups.get(n, []).filter(func(e): return is_instance_valid(e) and not e.dead)
			if g.size() > 0:
				var now := Time.get_ticks_msec()
				if now - int(last_group_t.get(n, 0)) < 400:
					center_on(g[0].pos)
				last_group_t[n] = now
				set_selection(g, ev.shift_pressed)
		get_viewport().set_input_as_handled()
		return
	if ev.is_action("cmd_attack_move") and _has_own_units():
		set_mode("attack_move")
	elif ev.is_action("cmd_patrol") and _has_own_units():
		set_mode("patrol")
	elif ev.is_action("cmd_stop"):
		for u in own_units():
			u.cmd_stop()
	elif ev.is_action("cmd_guard"):
		for u in own_units():
			u.cmd_guard()
	elif ev.is_action("cmd_hold"):
		for u in own_units():
			u.cmd_hold()
	elif ev.is_action("cmd_scatter"):
		for u in own_units():
			u.cmd_scatter()
	elif ev.is_action("cmd_deploy"):
		deploy_selected()
	elif ev.is_action("select_all_army"):
		set_selection(game.units.filter(func(u): return u.pid == game.human_pid and u.can_attack() and not u.is_harvester))
	elif ev.is_action("repair_mode"):
		set_mode("repair" if mode != "repair" else "")
	elif ev.is_action("sell_mode"):
		set_mode("sell" if mode != "sell" else "")
	elif ev.is_action("center_base"):
		var p := game._base_center(game.human_pid)
		center_on(MapGrid.cell_center(p))
	elif ev.is_action("game_menu"):
		if mode != "":
			cancel_mode()
		elif hud != null:
			hud.toggle_menu()
	elif ev.is_action("pause") and hud != null:
		hud.toggle_pause()
	elif ev.is_action("cheat_panel") and hud != null:
		hud.toggle_cheats()
	elif ev.is_action("speed_up"):
		game.set_speed(game.speed * 2.0 if game.speed < 1.0 else game.speed + 0.5)
	elif ev.is_action("speed_down"):
		game.set_speed(game.speed - 0.5 if game.speed > 1.0 else game.speed * 0.5)

# ---------------------------------------------------------------- overlay drawing

func _draw() -> void:
	if game == null or view == null or view.is_3d():
		return
	for m in markers:
		var a: float = m.t / 0.6
		var r: float = 4.0 + (1.0 - a) * 10.0
		draw_arc(m.pos, r, 0, TAU, 16, Color(m.col.r, m.col.g, m.col.b, a), 2.0)
	if mode == "place" and place_type != "":
		var c := placement_cell()
		var d := Data.def(place_type)
		var fp: Array = d.get("footprint", ["x"])
		var ok := game.can_place(game.human_pid, place_type, c) == ""
		for y in fp.size():
			var row := String(fp[y])
			for x in row.length():
				var cc := c + Vector2i(x, y)
				var good := ok
				if not ok:
					good = row[x] == "x" and game.map.buildable(cc) or row[x] == "." and game.map.passable(cc, "track")
				var col := Color(0.2, 0.9, 0.3, 0.35) if good and ok else (Color(0.95, 0.75, 0.2, 0.35) if good else Color(0.95, 0.2, 0.15, 0.45))
				draw_rect(Rect2(Vector2(cc) * MapGrid.T, Vector2(MapGrid.T, MapGrid.T)).grow(-1), col)
		var col = game.players[game.human_pid].color
		col.a = 0.6
		Sprites.base = Transform2D(0.0, Vector2(c) * MapGrid.T)
		draw_set_transform_matrix(Sprites.base)
		Sprites.draw_building(self, d.get("sprite", ""), d.size, col, game.players[game.human_pid].faction, 1.0, 0.0)
		Sprites.base = Transform2D.IDENTITY
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if selection.size() > 0:
		for u in own_units():
			if u.moving and u.order in ["move", "attack_move", "patrol"] and selection.size() <= 12:
				var col := Color(0.4, 1, 0.4, 0.25) if u.order == "move" else Color(1, 0.4, 0.3, 0.25)
				draw_line(u.pos, u.goal, col, 1.0)
