class_name View2D
extends Node2D
## Classic top-down camera. Implements the same camera/picking API as View3D so the
## player controller, minimap and audio work with either presentation.

var game: Game
var controller = null
var camera: Camera2D
var sidebar_width: float = 316.0

func setup(g: Game) -> void:
	game = g
	camera = Camera2D.new()
	g.add_child(camera)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.make_current()

func is_3d() -> bool:
	return false

func _clamp() -> void:
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

func set_focus(p: Vector2) -> void:
	camera.position = p
	_clamp()

func get_focus() -> Vector2:
	return camera.get_screen_center_position()

func mouse_world() -> Vector2:
	return game.get_global_mouse_position()

func ground_from_screen(sp: Vector2) -> Vector2:
	return game.get_canvas_transform().affine_inverse() * sp

func world_to_screen(p: Vector2, _h: float = 0.0) -> Vector2:
	return game.get_canvas_transform() * p

func pan_screen(rel: Vector2) -> void:
	camera.position -= rel / camera.zoom
	_clamp()

func scroll(dir: Vector2, pixels: float) -> void:
	camera.position += dir.normalized() * pixels / camera.zoom.x
	_clamp()

func zoom_by(factor: float, screen_pt: Vector2) -> void:
	var before := ground_from_screen(screen_pt)
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.45, 2.0)
	camera.force_update_scroll()
	var after := ground_from_screen(screen_pt)
	camera.position += before - after
	_clamp()

func visible_ground_quad() -> PackedVector2Array:
	var s := get_viewport().get_visible_rect().size
	return PackedVector2Array([ground_from_screen(Vector2.ZERO), ground_from_screen(Vector2(s.x, 0)), ground_from_screen(s), ground_from_screen(Vector2(0, s.y))])

func view_radius_px() -> float:
	return (get_viewport().get_visible_rect().size / camera.zoom).length() * 0.6

func screen_has(p: Vector2, margin: float = 40.0) -> bool:
	var s := get_viewport().get_visible_rect().size
	return p.x > -margin and p.y > -margin and p.x < s.x + margin and p.y < s.y + margin

func pick(sp: Vector2):
	var p := ground_from_screen(sp)
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
	for b in game.buildings:
		if b.visible and not b.dead and b.rect_px().has_point(p):
			return b
	return null

func spawn_fx(_k: String, _p: Vector2, _o: Dictionary) -> void:
	pass
