class_name Minimap
extends Control
## Radar view: terrain, ore and fog; unit/structure blips (enemies need a powered radar);
## camera frame. Left-click/drag moves the camera, right-click orders selected units.

var game: Game
var controller: PlayerController
var base_img: Image
var tex: ImageTexture
var refresh_t: float = 0.0
var dragging: bool = false

func setup(g: Game, pc: PlayerController) -> void:
	game = g
	controller = pc
	mouse_filter = Control.MOUSE_FILTER_STOP
	base_img = Image.create(g.map.w, g.map.h, false, Image.FORMAT_RGBA8)
	_rebuild()

func _rebuild() -> void:
	var m := game.map
	var hv: PackedByteArray = game.players[game.human_pid].vis
	var reveal := not game.fog_enabled() or game.cheats.flag(-1, "reveal_map")
	for y in m.h:
		for x in m.w:
			var c := Vector2i(x, y)
			var i := m.idx(c)
			var col := Color(m.terrain_def(c).get("color", "#777"))
			if m.ore[i] > 0:
				col = Color(0.85, 0.68, 0.25) if m.ore_kind[i] == 1 else Color(0.4, 0.75, 0.95)
			if not reveal:
				if hv[i] == 0:
					col = Color(0.02, 0.02, 0.03)
				elif hv[i] == 1:
					col = col.darkened(0.45)
			base_img.set_pixel(x, y, col)
	if tex == null:
		tex = ImageTexture.create_from_image(base_img)
	else:
		tex.update(base_img)

func has_radar() -> bool:
	if game.cheats.flag(-1, "reveal_map") or game.cheats.flag(-1, "reveal_enemies"):
		return true
	for b in game.buildings:
		if b.pid == game.human_pid and b.completed and b.def.get("provides", []).has("radar") and b.powered():
			return true
	return false

func _process(delta: float) -> void:
	if game == null:
		return
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.5
		_rebuild()
	queue_redraw()

func _map_rect() -> Rect2:
	var s := size
	var aspect := float(game.map.w) / float(game.map.h)
	var w := s.x
	var h := s.x / aspect
	if h > s.y:
		h = s.y
		w = s.y * aspect
	return Rect2((s - Vector2(w, h)) * 0.5, Vector2(w, h))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.03))
	if game == null or tex == null:
		return
	var r := _map_rect()
	draw_texture_rect(tex, r, false)
	var sx := r.size.x / float(game.map.w * MapGrid.T)
	var radar := has_radar()
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		if b.pid != game.human_pid and not radar and not b.seen_by_human:
			continue
		var br: Rect2 = b.rect_px()
		draw_rect(Rect2(r.position + br.position * sx, (br.size * sx).max(Vector2(2, 2))), b.team_color().lightened(0.2))
	for u in game.units:
		if u.dead:
			continue
		if u.pid != game.human_pid and (not u.visible or not radar and not game.cell_visible_to_human(u.cell())):
			continue
		var p: Vector2 = r.position + u.pos * sx
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2.5, 2.5)), u.team_color().lightened(0.35))
	# Camera frame.
	var cam = controller.camera
	var vs = get_viewport().get_visible_rect().size / cam.zoom
	var tl = cam.get_screen_center_position() - vs * 0.5
	draw_rect(Rect2(r.position + tl * sx, vs * sx).intersection(r.grow(1)), Color(1, 1, 1, 0.85), false, 1.0)
	if not radar:
		draw_string(ThemeDB.fallback_font, Vector2(6, size.y - 8), "NO RADAR: enemy contacts hidden", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.6, 0.3, 0.9))
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.BORDER, false, 1.0)

func _to_world(p: Vector2) -> Vector2:
	var r := _map_rect()
	var rel := (p - r.position) / r.size
	return Vector2(rel.x * game.map.w, rel.y * game.map.h) * MapGrid.T

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				controller.center_on(_to_world(event.position))
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var units = controller.own_units()
			if units.size() > 0:
				game.command_group(units, "move", _to_world(event.position))
				game.play_sound("move", Vector2.INF)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		controller.center_on(_to_world(event.position))
		accept_event()
