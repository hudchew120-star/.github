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

var _terrain_rgb := PackedByteArray()
var _pixels := PackedByteArray()

## Builds the radar image from byte arrays (much faster than setting pixels one by one).
func _rebuild() -> void:
	var m := game.map
	var n := m.w * m.h
	if _terrain_rgb.size() != n * 3:
		_terrain_rgb.resize(n * 3)
		for i in n:
			var col := Color(m.terrain_def(Vector2i(i % m.w, i / m.w)).get("color", "#777"))
			_terrain_rgb[i * 3] = int(col.r * 255.0)
			_terrain_rgb[i * 3 + 1] = int(col.g * 255.0)
			_terrain_rgb[i * 3 + 2] = int(col.b * 255.0)
		_pixels.resize(n * 4)
	var hv: PackedByteArray = game.players[game.human_pid].vis
	var reveal := not game.fog_enabled() or game.cheats.flag(-1, "reveal_map")
	var ore: PackedInt32Array = m.ore
	var kinds: PackedByteArray = m.ore_kind
	for i in n:
		var r := _terrain_rgb[i * 3]
		var g := _terrain_rgb[i * 3 + 1]
		var b := _terrain_rgb[i * 3 + 2]
		if ore[i] > 0:
			if kinds[i] == 1:
				r = 217; g = 173; b = 64
			else:
				r = 102; g = 191; b = 242
		if not reveal:
			var v := hv[i]
			if v == 0:
				r = 5; g = 5; b = 8
			elif v == 1:
				r = r * 55 / 100; g = g * 55 / 100; b = b * 55 / 100
		_pixels[i * 4] = r
		_pixels[i * 4 + 1] = g
		_pixels[i * 4 + 2] = b
		_pixels[i * 4 + 3] = 255
	base_img.set_data(m.w, m.h, false, Image.FORMAT_RGBA8, _pixels)
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
		refresh_t = 1.0
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
	# Camera frame (a diamond in 3D, a rectangle in 2D).
	var quad: PackedVector2Array = controller.view.visible_ground_quad()
	var pts := PackedVector2Array()
	for q in quad:
		var mp := r.position + q * sx
		pts.append(Vector2(clampf(mp.x, r.position.x, r.end.x), clampf(mp.y, r.position.y, r.end.y)))
	pts.append(pts[0])
	draw_polyline(pts, Color(1, 1, 1, 0.85), 1.0)
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
