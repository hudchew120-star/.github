class_name PlayerController
extends Node2D
## Translates mouse/keyboard input into game commands: camera, selection,
## control groups, orders, structure placement, repair/sell modes.

signal selection_changed
signal mode_changed

var game: Game
var hud = null
var camera: Camera2D
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
var sidebar_width: float = 300.0

func setup(g: Game, cam: Camera2D) -> void:
	game = g
	camera = cam
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
	camera.position = p
	_clamp_camera()

func _clamp_camera() -> void:
	var view := get_viewport().get_visible_rect().size / camera.zoom
	var sw := sidebar_width / camera.zoom.x
	var mw := game.map.w * MapGrid.T
	var mh := game.map.h * MapGrid.T
	var minx := view.x * 0.5 - 64.0
	var maxx := mw - view.x * 0.5 + sw + 64.0
	var miny := view.y * 0.5 - 96.0
	var maxy := mh - view.y * 0.5 + 220.0 / camera.zoom.y
	camera.position.x = clampf(camera.position.x, minf(minx, maxx), maxf(minx, maxx))
	camera.position.y = clampf(camera.position.y, minf(miny, maxy), maxf(miny, maxy))

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
		camera.position += move.normalized() * float(Config.settings.scroll_speed) * delta / camera.zoom.x
		_clamp_camera()
	_update_hover()
	var mc := MapGrid.to_cell(get_global_mouse_position())
	game.cursor_cell = mc
	for m in markers:
		m.t -= delta
	markers = markers.filter(func(m): return m.t > 0.0)
	queue_redraw()

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

# ---------------------------------------------------------------- picking

func _update_hover() -> void:
	var p := get_global_mouse_position()
	var h = _pick(p)
	if h != hovered:
		if hovered != null and is_instance_valid(hovered):
			hovered.hovered = false
		hovered = h
		if hovered != null:
			hovered.hovered = true
	var shape := Input.CURSOR_ARROW
	if mode == "place":
		shape = Input.CURSOR_CROSS
	elif mode in ["attack_move", "patrol"]:
		shape = Input.CURSOR_CROSS
	elif mode == "repair" or mode == "sell":
		shape = Input.CURSOR_POINTING_HAND
	elif hovered != null and _has_own_units() and game.are_enemies(game.human_pid, hovered.pid):
		shape = Input.CURSOR_CROSS
	Input.set_default_cursor_shape(shape)

func _pick(p: Vector2):
	var best = null
	var best_d := INF
	for u in game.unit_hash.query(p, 24.0):
		if u.dead or not u.visible:
			continue
		var d: float = u.pos.distance_to(p)
		if d <= u.radius + 5.0 and d < best_d:
			best_d = d
			best = u
	if best != null:
		return best
	var c := MapGrid.to_cell(p)
	if game.map.in_bounds(c):
		var uid := game.map.occupied[game.map.idx(c)]
		if uid != 0:
			var b = game.entities.get(uid)
			if b != null and b.visible:
				return b
	for b in game.buildings:
		if b.visible and not b.dead and b.rect_px().has_point(p):
			return b
	return null

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
	var r := Rect2(a, b - a).abs()
	var found := []
	for u in game.units:
		if u.pid == game.human_pid and not u.dead and r.has_point(u.pos):
			found.append(u)
	# Prefer combat units over collectors when both are boxed.
	var fighters := found.filter(func(u): return not u.is_harvester)
	set_selection(fighters if fighters.size() > 0 else found, add)

func _select_same_type(e) -> void:
	var view := Rect2(camera.get_screen_center_position() - get_viewport().get_visible_rect().size / camera.zoom * 0.5, get_viewport().get_visible_rect().size / camera.zoom)
	var list := []
	for u in game.units:
		if u.pid == e.pid and u.type == e.type and not u.dead and view.has_point(u.pos):
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

func cancel_mode() -> void:
	set_mode("")

func placement_cell() -> Vector2i:
	var size: Vector2i = Data.def(place_type).size
	var p := get_global_mouse_position() - Vector2(size) * MapGrid.T * 0.5 + Vector2(MapGrid.T, MapGrid.T) * 0.5
	return MapGrid.to_cell(p)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.over and not event is InputEventKey:
		pass
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		if mmb_drag:
			camera.position -= event.relative / camera.zoom
			_clamp_camera()
		if dragging:
			drag_now = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)

func _mouse_button(ev: InputEventMouseButton) -> void:
	var wp := get_global_mouse_position()
	if ev.button_index == MOUSE_BUTTON_WHEEL_UP or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if ev.pressed:
			var before := get_global_mouse_position()
			var z := camera.zoom.x * (1.1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			camera.zoom = Vector2.ONE * clampf(z, 0.45, 2.0)
			camera.force_update_scroll()
			var after := get_global_mouse_position()
			camera.position += before - after
			_clamp_camera()
		return
	if ev.button_index == MOUSE_BUTTON_MIDDLE:
		mmb_drag = ev.pressed
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		if mode != "":
			cancel_mode()
			return
		_right_click(wp, ev.shift_pressed)
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
			"attack_move", "patrol":
				game.command_group(own_units(), mode, wp)
				_marker(wp, Color(1, 0.3, 0.2) if mode == "attack_move" else Color(0.4, 0.7, 1))
				game.play_sound("move", Vector2.INF)
				if not ev.shift_pressed:
					cancel_mode()
				return
			"repair", "sell":
				var e = _pick(wp)
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
			var inv := get_canvas_transform().affine_inverse()
			_box_select(inv * drag_start, inv * ev.position, ev.shift_pressed)
			return
		var e = _pick(wp)
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

func _right_click(wp: Vector2, shift: bool) -> void:
	var units := own_units()
	var target = _pick(wp)
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
	if target != null and game.are_enemies(game.human_pid, target.pid):
		game.command_group(units, "attack", wp, target)
		_marker(target.pos, Color(1, 0.2, 0.15))
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
		for u in own_units():
			if u.def.has("deploys_to"):
				u.cmd_deploy()
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
	if game == null:
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
