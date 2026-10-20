class_name View3D
extends Node3D
## 3D presentation of a match: isometric orthographic camera, sun with shadows,
## filmic environment, 3D terrain, models for every entity, effects and a screen
## overlay for selection and health. The simulation itself stays in Game (2D logic).

const PITCH := -42.0
const YAW := 45.0
const BASE_SIZE := 15.0
const CAM_DIST := 60.0
const T := MapGrid.T

var game: Game
var controller = null
var camera: Camera3D
var sun: DirectionalLight3D
var terrain: Terrain3D
var overlay: Control
var overlay_layer: CanvasLayer
var focus := Vector2.ZERO          # world px under the screen centre
var zoom: float = 1.0
var visuals := {}                  # uid -> {node, e, kind, ...}
var proj_vis := {}                 # projectile instance id -> Node3D
var ghost: Node3D = null
var ghost_type: String = ""
var ghost_cells: Array = []
var fx_root: Node3D
var fx_count: int = 0
var _smoke_ramp: Gradient
var _steam_ramp: Gradient
var _fire_ramp: Gradient

func setup(g: Game) -> void:
	game = g
	g.view3d = self
	_build_environment()
	terrain = Terrain3D.new()
	add_child(terrain)
	terrain.setup(g)
	fx_root = Node3D.new()
	add_child(fx_root)
	_smoke_ramp = Fx3D.ramp([Color(0.15, 0.14, 0.13, 0.0), Color(0.18, 0.17, 0.16, 0.65), Color(0.3, 0.3, 0.3, 0.0)])
	_steam_ramp = Fx3D.ramp([Color(0.9, 0.9, 0.9, 0.0), Color(0.92, 0.92, 0.94, 0.28), Color(1, 1, 1, 0.0)])
	_fire_ramp = Fx3D.ramp([Color(1, 0.9, 0.5, 0.9), Color(1, 0.45, 0.1, 0.7), Color(0.3, 0.1, 0.05, 0.0)])
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 5
	add_child(overlay_layer)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	overlay_layer.add_child(overlay)
	focus = Vector2(map_w_px(), map_h_px()) * 0.5
	_update_camera()

func map_w_px() -> float:
	return game.map.w * T

func map_h_px() -> float:
	return game.map.h * T

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.05, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.62, 0.72)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 0.7
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.02
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 150, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = 160.0
	camera.rotation_degrees = Vector3(PITCH, YAW, 0)
	add_child(camera)
	camera.make_current()

# ---------------------------------------------------------------- camera API (used by the player controller)

func is_3d() -> bool:
	return true

func to3(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x / T, h, p.y / T)

func _update_camera() -> void:
	camera.size = BASE_SIZE / zoom
	var f3 := to3(focus)
	camera.position = f3 + camera.global_transform.basis.z * CAM_DIST

func set_focus(p: Vector2) -> void:
	focus = Vector2(clampf(p.x, 0.0, map_w_px()), clampf(p.y, 0.0, map_h_px()))
	_update_camera()

func get_focus() -> Vector2:
	return focus

func ground_from_screen(sp: Vector2) -> Vector2:
	var o := camera.project_ray_origin(sp)
	var d := camera.project_ray_normal(sp)
	if absf(d.y) < 0.0001:
		return focus
	var t := -o.y / d.y
	var p := o + d * t
	return Vector2(p.x * T, p.z * T)

func mouse_world() -> Vector2:
	return ground_from_screen(get_viewport().get_mouse_position())

func world_to_screen(p: Vector2, h: float = 0.0) -> Vector2:
	return camera.unproject_position(to3(p, h))

func pan_screen(rel: Vector2) -> void:
	var c := get_viewport().get_visible_rect().size * 0.5
	var a := ground_from_screen(c)
	var b := ground_from_screen(c + rel)
	set_focus(focus - (b - a))

func scroll(dir: Vector2, pixels: float) -> void:
	pan_screen(-dir.normalized() * pixels)

func zoom_by(factor: float, screen_pt: Vector2) -> void:
	var before := ground_from_screen(screen_pt)
	zoom = clampf(zoom * factor, 0.45, 2.2)
	_update_camera()
	var after := ground_from_screen(screen_pt)
	set_focus(focus + before - after)

func visible_ground_quad() -> PackedVector2Array:
	var s := get_viewport().get_visible_rect().size
	return PackedVector2Array([ground_from_screen(Vector2.ZERO), ground_from_screen(Vector2(s.x, 0)), ground_from_screen(s), ground_from_screen(Vector2(0, s.y))])

func view_radius_px() -> float:
	return camera.size * T * 1.2

func screen_has(p: Vector2, margin: float = 40.0) -> bool:
	var s := get_viewport().get_visible_rect().size
	return p.x > -margin and p.y > -margin and p.x < s.x + margin and p.y < s.y + margin

func unit_screen_radius(e) -> float:
	var px_per_unit := get_viewport().get_visible_rect().size.y / camera.size
	return e.radius / T * px_per_unit

## Screen-space picking that respects the height of structures.
func pick(sp: Vector2):
	var best = null
	var best_d := INF
	for u in game.units:
		if u.dead or not u.visible:
			continue
		var s := world_to_screen(u.pos, 0.2)
		var r := unit_screen_radius(u) + 6.0
		var d := s.distance_to(sp)
		if d < r and d < best_d:
			best_d = d
			best = u
	if best != null:
		return best
	var best_depth := -INF
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		var r: Rect2 = b.rect_px()
		var h := Models.height_of(b.def.get("sprite", ""))
		var pts := PackedVector2Array()
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			pts.append(world_to_screen(corner, 0.0))
			pts.append(world_to_screen(corner, h * 0.85))
		var hull := Geometry2D.convex_hull(pts)
		if Geometry2D.is_point_in_polygon(sp, hull):
			var depth: float = r.get_center().x + r.get_center().y
			if depth > best_depth:
				best_depth = depth
				best = b
	return best

# ---------------------------------------------------------------- effects

func spawn_fx(kind: String, p: Vector2, opts: Dictionary) -> void:
	if kind == "smoke" or kind == "fire":
		return   # structures emit their own particles in 3D
	if fx_root.get_child_count() > 260 and kind != "crater":
		return
	var h := terrain.ground_height(p)
	var o := opts.duplicate()
	var y := h + 0.3
	if kind == "crater":
		y = h
		o["r"] = float(opts.get("r", 12.0)) / T
	elif kind == "explosion_small" or kind == "flame_burst":
		y = h + 0.15
	if o.has("to"):
		var tp: Vector2 = o.to
		o["to"] = to3(tp, terrain.ground_height(tp) + 0.25)
	var fx := Fx3D.new()
	fx_root.add_child(fx)
	fx.setup(kind, to3(p, y), o)

# ---------------------------------------------------------------- entity visuals

func _make_visual(e) -> Dictionary:
	var faction: String = e.player().faction
	var col: Color = e.team_color()
	var v := {"e": e, "kind": "unit" if e.is_unit() else "building", "t": randf() * 10.0}
	var node: Node3D
	if e.is_unit():
		node = Models.build_unit(e.def.get("sprite", ""), col, faction)
		node.position = to3(e.pos, terrain.ground_height(e.pos))
		node.rotation.y = -e.facing
	else:
		node = Models.build_building(e.def.get("sprite", ""), e.size, col, faction)
		node.position = Vector3(e.cell0.x, 0.0, e.cell0.y)
		var emitters := []
		for sp in node.get_meta("smoke", []):
			var steam: bool = node.get_meta("steam", false)
			var pe := Fx3D.make_particles(node, 10, 2.6 if steam else 2.2, false, _steam_ramp if steam else _smoke_ramp, 0.55 if steam else 0.4, false)
			pe.position = sp
			pe.direction = Vector3.UP
			pe.spread = 12.0
			pe.initial_velocity_min = 0.25
			pe.initial_velocity_max = 0.45
			pe.gravity = Vector3(0.12, 0.05, 0.05)
			pe.emitting = true
			emitters.append(pe)
		v["emitters"] = emitters
		var c := Vector3(e.size.x * 0.5, Models.height_of(e.def.get("sprite", "")) * 0.6, e.size.y * 0.5)
		var dmg := Fx3D.make_particles(node, 16, 2.0, false, _smoke_ramp, 0.6, false)
		dmg.position = c
		dmg.direction = Vector3.UP
		dmg.spread = 25.0
		dmg.initial_velocity_min = 0.3
		dmg.initial_velocity_max = 0.6
		dmg.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dmg.emission_box_extents = Vector3(e.size.x * 0.3, 0.1, e.size.y * 0.3)
		dmg.emitting = false
		v["dmg"] = dmg
		var fire := Fx3D.make_particles(node, 14, 0.7, true, _fire_ramp, 0.35, false)
		fire.position = c - Vector3(0, 0.2, 0)
		fire.direction = Vector3.UP
		fire.spread = 15.0
		fire.initial_velocity_min = 0.3
		fire.initial_velocity_max = 0.7
		fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fire.emission_box_extents = Vector3(e.size.x * 0.3, 0.05, e.size.y * 0.3)
		fire.emitting = false
		v["fire"] = fire
		if node.has_meta("glow"):
			var gmi: MeshInstance3D = node.get_meta("glow")
			gmi.material_override = gmi.material_override.duplicate()
	add_child(node)
	v["node"] = node
	return v

func _process(delta: float) -> void:
	if game == null:
		return
	# Create / remove visuals.
	for uid in game.entities:
		if not visuals.has(uid):
			visuals[uid] = _make_visual(game.entities[uid])
	for uid in visuals.keys():
		var v: Dictionary = visuals[uid]
		if not game.entities.has(uid) or not is_instance_valid(v.e) or v.e.dead:
			v.node.queue_free()
			visuals.erase(uid)
			continue
		if v.kind == "unit":
			_update_unit(v, delta)
		else:
			_update_building(v, delta)
	_update_projectiles()
	terrain.process_dirty()
	_update_ghost()
	overlay.queue_redraw()

func _update_unit(v: Dictionary, delta: float) -> void:
	var e = v.e
	var n: Node3D = v.node
	n.visible = e.visible
	if not n.visible:
		return
	var target := to3(e.pos, terrain.ground_height(e.pos))
	var moved := n.position.distance_to(target)
	if moved > 2.0:
		n.position = target
	else:
		n.position = n.position.lerp(target, minf(1.0, delta * 18.0))
	n.rotation.y = lerp_angle(n.rotation.y, -e.facing, minf(1.0, delta * 14.0))
	v.t += delta
	if n.has_meta("turret"):
		var tur: Node3D = n.get_meta("turret")
		tur.rotation.y = lerp_angle(tur.rotation.y, -(e.turret_facing - e.facing), minf(1.0, delta * 16.0))
	var walking: bool = e.moving and moved > 0.002
	if n.has_meta("legs"):
		var legs: Array = n.get_meta("legs")
		var sw := sin(v.t * 13.0) * 0.6 if walking else 0.0
		legs[0].rotation.z = sw
		legs[1].rotation.z = -sw
		var body: Node3D = n.get_meta("body")
		body.position.y = absf(sin(v.t * 13.0)) * 0.015 if walking else 0.0
	elif walking:
		var body: Node3D = n.get_meta("body")
		body.position.y = sin(v.t * 30.0) * 0.004
	if n.has_meta("fill"):
		var fill: MeshInstance3D = n.get_meta("fill")
		var r := float(e.cargo) / float(maxi(e.capacity, 1))
		fill.visible = r > 0.01
		fill.scale = Vector3(1, maxf(r, 0.05), 1)
		fill.position.y = 0.15 + 0.07 * r
	if n.has_meta("drum") and e.harv_state == "mining":
		var drum: MeshInstance3D = n.get_meta("drum")
		drum.rotate_object_local(Vector3.UP, delta * 8.0)

func _update_building(v: Dictionary, delta: float) -> void:
	var e = v.e
	var n: Node3D = v.node
	n.visible = e.visible
	if not n.visible:
		return
	v.t += delta
	var body: Node3D = n.get_meta("body")
	body.scale.y = maxf(0.03, e.make_progress)
	if n.has_meta("turret"):
		var tur: Node3D = n.get_meta("turret")
		tur.rotation.y = lerp_angle(tur.rotation.y, -e.turret_facing, minf(1.0, delta * 12.0))
	if n.has_meta("crane"):
		var cr: Node3D = n.get_meta("crane")
		cr.rotation.y = sin(v.t * 0.35) * 1.3
	if n.has_meta("dish"):
		var dish: Node3D = n.get_meta("dish")
		if e.powered():
			dish.rotation.y += delta * 1.1
	if n.has_meta("blink"):
		var bl: MeshInstance3D = n.get_meta("blink")
		bl.visible = fmod(v.t, 1.2) < 0.6
	if n.has_meta("glow"):
		var gmi: MeshInstance3D = n.get_meta("glow")
		var m: StandardMaterial3D = gmi.material_override
		if e.def.get("sprite", "") == "arc_coil":
			m.emission_energy_multiplier = 0.4 + 7.0 * e.charge * e.charge if e.powered() else 0.1
		else:
			m.emission_energy_multiplier = 4.0 if e.unload_anim > 0.0 else 0.0
	var on: bool = e.completed and e.powered()
	for pe in v.get("emitters", []):
		pe.emitting = on
	var hr: float = e.hp_ratio()
	v.dmg.emitting = e.completed and hr < 0.5
	v.fire.emitting = e.completed and hr < 0.25

func _update_projectiles() -> void:
	var seen := {}
	for pr in game.projectiles:
		var id = pr.get_instance_id()
		seen[id] = true
		var n: Node3D = proj_vis.get(id)
		if n == null:
			n = Node3D.new()
			var mi := MeshInstance3D.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			match pr.kind:
				"rocket":
					mi.mesh = Models.cyl_mesh(0.022, 0.022, 0.2, 6)
					mi.rotation_degrees = Vector3(0, 0, 90)
					mi.material_override = Models.mat("rocket", Color(0.8, 0.8, 0.76), 0.5, 0.4)
					var tail := MeshInstance3D.new()
					tail.mesh = Models.cyl_mesh(0.0, 0.035, 0.14, 6)
					tail.rotation_degrees = Vector3(0, 0, 90)
					tail.material_override = Models.light_mat(Color(1, 0.6, 0.2), 9.0)
					tail.position = Vector3(-0.16, 0, 0)
					n.add_child(tail)
					var trail := Fx3D.make_particles(fx_root, 16, 0.6, false, _steam_ramp, 0.16, false)
					trail.emitting = true
					n.set_meta("trail", trail)
				"flame":
					mi.mesh = Models.sphere_mesh(0.12, -1, 8)
					mi.material_override = Models.light_mat(Color(1, 0.5, 0.1), 5.0)
				_:
					mi.mesh = Models.box_mesh(Vector3(0.16, 0.025, 0.025))
					mi.material_override = Models.light_mat(Color(1, 0.85, 0.5), 7.0)
			n.add_child(mi)
			fx_root.add_child(n)
			proj_vis[id] = n
		var h := terrain.ground_height(pr.cur) + 0.3
		n.position = to3(pr.cur, h)
		n.rotation.y = -pr.rotation
		if pr.kind == "flame":
			n.scale = Vector3.ONE * (1.0 + pr.t * 5.0)
		if n.has_meta("trail"):
			n.get_meta("trail").position = n.position
	for id in proj_vis.keys():
		if not seen.has(id):
			var n: Node3D = proj_vis[id]
			if n.has_meta("trail"):
				var tr: CPUParticles3D = n.get_meta("trail")
				tr.emitting = false
				get_tree().create_timer(0.8).timeout.connect(tr.queue_free)
			n.queue_free()
			proj_vis.erase(id)

# ---------------------------------------------------------------- placement ghost

func _update_ghost() -> void:
	if controller == null or controller.mode != "place" or controller.place_type == "":
		if ghost != null:
			ghost.queue_free()
			ghost = null
			ghost_type = ""
			for q in ghost_cells:
				q.queue_free()
			ghost_cells.clear()
		return
	var t: String = controller.place_type
	var d := Data.def(t)
	if ghost_type != t:
		if ghost != null:
			ghost.queue_free()
		for q in ghost_cells:
			q.queue_free()
		ghost_cells.clear()
		var p = game.players[game.human_pid]
		ghost = Models.build_building(d.get("sprite", ""), d.size, p.color, p.faction)
		for mi in ghost.find_children("*", "MeshInstance3D", true, false):
			mi.transparency = 0.45
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		ghost_type = t
		var fp: Array = d.get("footprint", ["x"])
		for y in fp.size():
			for x in String(fp[y]).length():
				var q := MeshInstance3D.new()
				var pm := PlaneMesh.new()
				pm.size = Vector2(0.94, 0.94)
				q.mesh = pm
				q.set_meta("off", Vector2i(x, y))
				q.set_meta("solid", String(fp[y])[x] == "x")
				q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(q)
				ghost_cells.append(q)
	var c: Vector2i = controller.placement_cell()
	var ok: bool = game.can_place(game.human_pid, t, c) == ""
	ghost.position = Vector3(c.x, 0.0, c.y)
	for q in ghost_cells:
		var cc: Vector2i = c + q.get_meta("off")
		q.position = Vector3(cc.x + 0.5, terrain.ground_height(MapGrid.cell_center(cc)) + 0.03, cc.y + 0.5)
		var good := ok
		if not ok:
			good = (game.map.buildable(cc) if q.get_meta("solid") else game.map.passable(cc, "track"))
		var col := Color(0.2, 1.0, 0.35, 0.45) if ok else (Color(1.0, 0.8, 0.2, 0.4) if good else Color(1.0, 0.2, 0.15, 0.5))
		q.material_override = _cell_mat(col)

var _cell_mats := {}
func _cell_mat(col: Color) -> StandardMaterial3D:
	var k := col.to_html()
	if not _cell_mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = col
		_cell_mats[k] = m
	return _cell_mats[k]

# ---------------------------------------------------------------- overlay (selection, health, markers)

func _bar(pos: Vector2, w: float, ratio: float, inv: bool) -> void:
	var col := Color(0.2, 0.85, 0.3) if ratio > 0.6 else (Color(0.95, 0.8, 0.2) if ratio > 0.3 else Color(0.9, 0.2, 0.15))
	var r := Rect2(pos.x - w * 0.5, pos.y, w, 5)
	overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
	overlay.draw_rect(Rect2(r.position, Vector2(w * ratio, 5)), col)
	var segs := int(w / 6.0)
	for i in range(1, segs):
		var x := r.position.x + i * w / segs
		overlay.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.35), 1.0)
	if inv:
		overlay.draw_rect(r.grow(1), Color(0.6, 0.9, 1.0), false, 1.0)

func _draw_overlay() -> void:
	if game == null:
		return
	var font := ThemeDB.fallback_font
	var white := Color(1, 1, 1, 0.92)
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		var r: Rect2 = b.rect_px()
		var top := world_to_screen(r.get_center(), Models.height_of(b.def.get("sprite", "")) + 0.25)
		if not screen_has(top, 200):
			continue
		if b.selected:
			var pts := PackedVector2Array()
			for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				pts.append(world_to_screen(corner, 0.05))
			for i in 4:
				var a := pts[i]
				var n1 := pts[(i + 1) % 4]
				var n0 := pts[(i + 3) % 4]
				overlay.draw_line(a, a.lerp(n1, 0.22), white, 2.0)
				overlay.draw_line(a, a.lerp(n0, 0.22), white, 2.0)
			if b.rally != Vector2.INF and b.pid == game.human_pid:
				var rp := world_to_screen(b.rally, 0.05)
				overlay.draw_dashed_line(world_to_screen(r.get_center(), 0.05), rp, Color(1, 1, 1, 0.6), 1.5, 6.0)
				overlay.draw_circle(rp, 4, Color(1, 1, 1, 0.8))
		if b.selected or b.hovered or b.hp_ratio() < 0.999:
			_bar(top, clampf(r.size.x / T * 34.0, 30, 110), b.hp_ratio(), b.invulnerable)
		if b.completed and b.requires_power() and not b.powered():
			overlay.draw_string(font, top + Vector2(-26, -6), "OFFLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.35, 0.2))
		if b.repairing:
			var c := top + Vector2(0, -16)
			overlay.draw_circle(c, 9, Color(0.1, 0.45, 0.15, 0.85))
			overlay.draw_line(c - Vector2(5, 0), c + Vector2(5, 0), Color.WHITE, 2.0)
			overlay.draw_line(c - Vector2(0, 5), c + Vector2(0, 5), Color.WHITE, 2.0)
	for u in game.units:
		if u.dead or not u.visible:
			continue
		var base := world_to_screen(u.pos, terrain.ground_height(u.pos))
		if not screen_has(base):
			continue
		var rs := unit_screen_radius(u)
		if u.selected:
			var rr := rs + 4.0
			var c := base + Vector2(0, -rs * 0.35)
			for i in 4:
				var a := i * PI * 0.5 + PI * 0.25
				overlay.draw_arc(c, rr, a - 0.35, a + 0.35, 6, white, 1.6)
		if u.selected or u.hovered or u.hp_ratio() < 0.5:
			_bar(base + Vector2(0, -rs * 1.6 - 14), maxf(rs * 2.0, 18.0), u.hp_ratio(), u.invulnerable)
		if u.selected and u.is_harvester:
			var ratio := float(u.cargo) / float(maxi(u.capacity, 1))
			var p := base + Vector2(-rs, -rs * 1.6 - 7)
			overlay.draw_rect(Rect2(p, Vector2(rs * 2.0, 3)), Color(0, 0, 0, 0.7))
			overlay.draw_rect(Rect2(p, Vector2(rs * 2.0 * ratio, 3)), Color(0.95, 0.75, 0.25))
		if u.selected and u.pid == game.human_pid and u.moving and u.order in ["move", "attack_move", "patrol"] and game.selection.size() <= 12:
			var col := Color(0.4, 1, 0.4, 0.35) if u.order == "move" else Color(1, 0.4, 0.3, 0.35)
			overlay.draw_line(base, world_to_screen(u.goal, 0.05), col, 1.0)
	if controller != null:
		for m in controller.markers:
			var a: float = m.t / 0.6
			var sp := world_to_screen(m.pos, 0.05)
			var r: float = 5.0 + (1.0 - a) * 14.0
			overlay.draw_arc(sp, r, 0, TAU, 20, Color(m.col.r, m.col.g, m.col.b, a), 2.0)
