class_name IsoView
extends Node2D
## Classic isometric presentation built from pre-rendered sprites: painted terrain,
## Y-sorted units/structures/decorations, sprite-sheet effects and a fog overlay.
## Implements the same camera/picking API as View3D/View2D.

const T := MapGrid.T

var game: Game
var controller = null
var camera: Camera2D
var terrain: IsoTerrain
var ground_fx: Node2D
var entity_layer: Node2D
var air_layer: Node2D               # flying aircraft, drawn above everything on the ground
var air_fx: Node2D
var fog: Polygon2D
var ghost: Node2D
var ghost_sprite: Sprite2D
var ghost_type: String = ""
var overlay_layer: CanvasLayer
var overlay: Control
var visuals := {}
var proj_vis := {}
var fx_sheets := {}
var sidebar_width: float = 316.0
var ground_vp: SubViewport          # terrain rendered at reduced resolution (quality setting)
var ground_rect: TextureRect
var terrain_scale: float = 1.0

func setup(g: Game) -> void:
	game = g
	g.view3d = self
	camera = Camera2D.new()
	add_child(camera)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.zoom = Vector2(0.72, 0.72)
	camera.make_current()
	terrain = IsoTerrain.new()
	add_child(terrain)
	ground_fx = Node2D.new()
	add_child(ground_fx)
	entity_layer = Node2D.new()
	entity_layer.y_sort_enabled = true
	add_child(entity_layer)
	air_layer = Node2D.new()
	air_layer.y_sort_enabled = true
	add_child(air_layer)
	air_fx = Node2D.new()
	add_child(air_fx)
	terrain.setup(g, entity_layer)
	_setup_ground_scaling()
	_preload_sheets()
	_build_fog()
	ghost = Node2D.new()
	ghost.draw.connect(_draw_ghost_cells)
	add_child(ghost)
	ghost_sprite = Sprite2D.new()
	ghost_sprite.centered = false
	ghost_sprite.region_enabled = true
	ghost_sprite.modulate = Color(1, 1, 1, 0.55)
	ghost.add_child(ghost_sprite)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 5
	add_child(overlay_layer)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	overlay_layer.add_child(overlay)
	for k in ["explosion", "explosion_big", "explosion_small", "smoke_dark", "smoke_light", "fire", "muzzle", "crater", "shell", "rocket"]:
		fx_sheets[k] = SpriteLib.sheet(k, "fx")
	game.entity_removed.connect(_on_removed)
	set_focus(Vector2(g.map.w, g.map.h) * T * 0.5)

## Draws the terrain shader into a smaller off-screen image and stretches it over the screen.
## The painted ground is soft, so 50-70% resolution looks nearly identical but costs far less.
func _setup_ground_scaling() -> void:
	terrain_scale = Config.terrain_scale()
	if terrain_scale >= 0.99 or terrain.ground == null:
		return
	ground_vp = SubViewport.new()
	ground_vp.disable_3d = true
	ground_vp.transparent_bg = false
	ground_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	ground_vp.size = Vector2i(64, 64)
	add_child(ground_vp)
	terrain.ground.reparent(ground_vp, false)
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	ground_rect = TextureRect.new()
	ground_rect.texture = ground_vp.get_texture()
	ground_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground_rect.stretch_mode = TextureRect.STRETCH_SCALE
	ground_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ground_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ground_rect)
	_sync_ground()

func _sync_ground() -> void:
	if ground_vp == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var want := Vector2i(maxi(64, int(screen.x * terrain_scale)), maxi(64, int(screen.y * terrain_scale)))
	if ground_vp.size != want:
		ground_vp.size = want
	var k := float(want.x) / maxf(screen.x, 1.0)
	ground_vp.canvas_transform = Transform2D(0.0, Vector2(k, float(want.y) / maxf(screen.y, 1.0)), 0.0, Vector2.ZERO) * _ct()

## Loads every sprite sheet the factions in this match can use, so nothing is read from
## disk in the middle of a battle (that caused a freeze whenever a new unit type appeared).
func _preload_sheets() -> void:
	var factions := {}
	for p in game.players:
		factions[p.faction] = true
	for f in factions:
		for src in [Data.units, Data.buildings]:
			for t in src:
				var d: Dictionary = src[t]
				if not d.get("factions", []).has(f):
					continue
				var prefix := "b_" if src == Data.buildings else ("i_" if d.get("category", "") == "infantry" else "u_")
				var n := "%s%s_%s" % [prefix, d.get("sprite", ""), f]
				if not SpriteLib.has(n):
					continue
				for suffix in ["_turret", "_die", "_anim", "_dug"]:
					SpriteLib.sheet(n + suffix)
				var s := SpriteLib.sheet(n)
				for p in game.players:
					SpriteLib.team_material(p.color, s.mask)
				if d.get("category", "") == "aircraft":
					SpriteLib._load_tex("res://assets/sprites/%s_shadow.png" % n)

func _build_fog() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform sampler2D fog_tex : filter_linear;
uniform vec2 map_size;
varying vec2 cp;
void vertex() { cp = vec2(VERTEX.x / 64.0 + VERTEX.y / 32.0, VERTEX.y / 32.0 - VERTEX.x / 64.0) * 0.5; }
void fragment() {
	if (cp.x < 0.0 || cp.y < 0.0 || cp.x > map_size.x || cp.y > map_size.y) {
		COLOR = vec4(0.015, 0.017, 0.02, 1.0);
	} else {
		float f = texture(fog_tex, cp / map_size).r;
		float a = f < 0.51 ? mix(0.0, 0.5, f / 0.51) : mix(0.5, 1.0, (f - 0.51) / 0.49);
		COLOR = vec4(0.01, 0.012, 0.018, a);
	}
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("fog_tex", game.fog_texture)
	m.set_shader_parameter("map_size", Vector2(game.map.w, game.map.h))
	fog = Polygon2D.new()
	var pad := 40.0
	var mw := float(game.map.w)
	var mh := float(game.map.h)
	fog.polygon = PackedVector2Array([SpriteLib.iso_cells(Vector2(-pad, -pad)), SpriteLib.iso_cells(Vector2(mw + pad, -pad)),
		SpriteLib.iso_cells(Vector2(mw + pad, mh + pad)), SpriteLib.iso_cells(Vector2(-pad, mh + pad))])
	fog.material = m
	add_child(fog)

# ---------------------------------------------------------------- camera API

func is_3d() -> bool:
	return true   # selection overlay is screen-space, like the 3D view

func _ct() -> Transform2D:
	return get_viewport().get_canvas_transform()

func world_to_screen(p: Vector2, h: float = 0.0) -> Vector2:
	return _ct() * SpriteLib.iso(p, h)

func ground_from_screen(sp: Vector2) -> Vector2:
	return SpriteLib.from_iso(_ct().affine_inverse() * sp)

func mouse_world() -> Vector2:
	return ground_from_screen(get_viewport().get_mouse_position())

func set_focus(p: Vector2) -> void:
	var c := Vector2(clampf(p.x, 0.0, game.map.w * T), clampf(p.y, 0.0, game.map.h * T))
	camera.position = SpriteLib.iso(c)
	camera.force_update_scroll()

func get_focus() -> Vector2:
	return SpriteLib.from_iso(camera.get_screen_center_position())

func _clamp() -> void:
	set_focus(SpriteLib.from_iso(camera.position))

func pan_screen(rel: Vector2) -> void:
	camera.position -= rel / camera.zoom.x
	_clamp()

func scroll(dir: Vector2, pixels: float) -> void:
	camera.position += dir.normalized() * pixels / camera.zoom.x
	_clamp()

func zoom_by(factor: float, screen_pt: Vector2) -> void:
	var before := ground_from_screen(screen_pt)
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.32, 1.3)
	camera.force_update_scroll()
	var after := ground_from_screen(screen_pt)
	camera.position += SpriteLib.iso(before) - SpriteLib.iso(after)
	_clamp()

func visible_ground_quad() -> PackedVector2Array:
	var s := get_viewport().get_visible_rect().size
	return PackedVector2Array([ground_from_screen(Vector2.ZERO), ground_from_screen(Vector2(s.x, 0)), ground_from_screen(s), ground_from_screen(Vector2(0, s.y))])

func view_radius_px() -> float:
	return get_viewport().get_visible_rect().size.length() / camera.zoom.x * 0.4

func screen_has(p: Vector2, margin: float = 40.0) -> bool:
	var s := get_viewport().get_visible_rect().size
	return p.x > -margin and p.y > -margin and p.x < s.x + margin and p.y < s.y + margin

func unit_screen_radius(e) -> float:
	return e.radius * 2.0 * camera.zoom.x * 1.25

func _height_of(b) -> float:
	var s := SpriteLib.sheet(SpriteLib.entity_sheet_name(b))
	return float(s.extra.get("height", 1.0)) if s != null else 1.0

func pick(sp: Vector2):
	var best = null
	var best_d := INF
	for u in game.units:
		if u.dead or not u.visible:
			continue
		var s := world_to_screen(u.pos, 0.25 + u.altitude_now)
		var d := s.distance_to(sp)
		if d < unit_screen_radius(u) + 8.0 and d < best_d:
			best_d = d
			best = u
	if best != null:
		return best
	var best_depth := -INF
	for b in game.buildings:
		if b.dead or not b.visible:
			continue
		var r: Rect2 = b.rect_px()
		var h := _height_of(b)
		var pts := PackedVector2Array()
		for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			pts.append(world_to_screen(corner, 0.0))
			pts.append(world_to_screen(corner, h * 0.8))
		if Geometry2D.is_point_in_polygon(sp, Geometry2D.convex_hull(pts)):
			var depth: float = r.get_center().x + r.get_center().y
			if depth > best_depth:
				best_depth = depth
				best = b
	return best

# ---------------------------------------------------------------- entity visuals

func _sprite(sheet: SpriteLib.Sheet, team: Color) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = sheet.tex
	sp.region_enabled = true
	sp.region_rect = sheet.region(0)
	sp.centered = false
	sp.offset = -Vector2(sheet.ax, sheet.ay)
	sp.material = SpriteLib.team_material(team, sheet.mask)
	return sp

func _make_visual(e) -> Dictionary:
	var v := {"e": e, "t": randf() * 5.0, "smoke_t": randf(), "fire_t": 0.0, "pid": e.pid, "wake_t": 0.0}
	var n := Node2D.new()
	var name := SpriteLib.entity_sheet_name(e)
	var sheet := SpriteLib.sheet(name)
	v["sheet"] = sheet
	v["node"] = n
	if sheet == null:
		entity_layer.add_child(n)
		return v
	var col: Color = e.team_color()
	var body := _sprite(sheet, col)
	n.add_child(body)
	v["body"] = body
	if e.is_unit():
		var ts := SpriteLib.sheet(name + "_turret")
		if ts != null:
			var tur := _sprite(ts, col)
			n.add_child(tur)
			v["turret"] = tur
			v["tsheet"] = ts
		n.position = SpriteLib.iso(e.pos)
		if e.is_infantry():
			v["dug"] = SpriteLib.sheet(name + "_dug")
			var extras := Node2D.new()
			extras.draw.connect(_draw_unit_extras.bind(extras, v))
			n.add_child(extras)
			n.move_child(extras, 0)
			v["extras"] = extras
		if e.is_air_unit:
			# Ground shadow (separate sheet) and, for helicopters, a spinning rotor disc.
			var stex := SpriteLib._load_tex("res://assets/sprites/%s_shadow.png" % name)
			if stex != null:
				var sh := Sprite2D.new()
				sh.texture = stex
				sh.region_enabled = true
				sh.centered = false
				sh.offset = -Vector2(sheet.ax, sheet.ay)
				ground_fx.add_child(sh)
				v["shadow"] = sh
			if sheet.extra.has("rotor"):
				var rot := Node2D.new()
				rot.set_meta("rotor", sheet.extra.rotor)
				rot.draw.connect(_draw_rotor.bind(rot, v))
				n.add_child(rot)
				v["rotor"] = rot
	else:
		var size: Vector2i = e.size
		var anchor_world := Vector2(e.cell0) * T
		var sort_world := Vector2(e.cell0 + size) * T
		n.position = SpriteLib.iso(sort_world) - Vector2(0, 24)
		body.position = SpriteLib.iso(anchor_world) - n.position
		var an := SpriteLib.sheet(name + "_anim")
		if an != null:
			v["anim"] = an
		var ts := SpriteLib.sheet(name + "_turret")
		if ts != null:
			var tur := _sprite(ts, col)
			var pv: Array = ts.extra.get("pivot", [0.5, 0.2, 0.5])
			tur.position = SpriteLib.iso_cells(Vector2(e.cell0) + Vector2(pv[0], pv[2]), pv[1]) - n.position
			n.add_child(tur)
			v["turret"] = tur
			v["tsheet"] = ts
		terrain.clear_decor(e.all_cells())
	if e.is_unit() and e.is_air_unit:
		air_layer.add_child(n)
	else:
		entity_layer.add_child(n)
	return v

## Sandbag ring for dug-in riflemen (drawn behind the soldier) and parachute canopies.
func _draw_unit_extras(node: Node2D, v: Dictionary) -> void:
	var e = v.e
	if e.deployed and v.get("dug") == null:
		var k: float = 1.0 if e.deploy_t <= 0.0 else 1.0 - e.deploy_t
		for i in 10:
			var a := TAU * i / 10.0
			var p: Vector2 = Vector2(cos(a) * 22.0, sin(a) * 11.0 + 2.0) * k
			var col := Color(0.62, 0.53, 0.36).darkened(0.18 if sin(a) < 0.0 else 0.0)
			node.draw_set_transform(p, a * 0.0, Vector2(1, 1))
			node.draw_circle(Vector2.ZERO, 6.5, col.darkened(0.35))
			node.draw_circle(Vector2(0, -1.5), 5.5, col)
		node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if e.para_t > 0.0:
		var top := Vector2(0, -78)
		var w := 30.0
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			pts.append(top + Vector2(cos(a) * w, sin(a) * 18.0))
		pts.append(top + Vector2(w, 0))
		node.draw_colored_polygon(pts, Color(0.92, 0.9, 0.82))
		for i in 6:
			var x := -w + i * (w * 2.0 / 5.0)
			node.draw_line(top + Vector2(x, -2), top + Vector2(x * 0.92, -14.0 * sin(PI * i / 5.0)), Color(0.75, 0.72, 0.62), 1.5)
		for x in [-w, -w * 0.4, w * 0.4, w]:
			node.draw_line(top + Vector2(x, 0), Vector2(0, -40), Color(0.2, 0.2, 0.2, 0.8), 1.0)

## Helicopter main rotor: translucent blurred disc plus fast-turning blade highlights.
func _draw_rotor(rot: Node2D, v: Dictionary) -> void:
	var info: Dictionary = rot.get_meta("rotor")
	var r: float = float(info.r) * SpriteLib.PXU
	var blades: int = int(info.get("blades", 4))
	var pts := PackedVector2Array()
	for k in 33:
		var a := TAU * k / 32.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	rot.draw_colored_polygon(pts, Color(0.08, 0.08, 0.08, 0.16))
	rot.draw_polyline(pts, Color(0.1, 0.1, 0.1, 0.25), 1.2)
	var spin: float = v.t * 26.0
	for b in blades:
		var a := spin + TAU * b / blades
		for k in 3:
			var aa := a - k * 0.09
			rot.draw_line(Vector2.ZERO, Vector2(cos(aa) * r, sin(aa) * r * 0.5), Color(0.06, 0.06, 0.06, 0.5 - k * 0.15), 3.0 - k)

func _process(delta: float) -> void:
	if game == null:
		return
	_sync_ground()
	for uid in game.entities:
		if not visuals.has(uid):
			visuals[uid] = _make_visual(game.entities[uid])
	for uid in visuals.keys():
		var v: Dictionary = visuals[uid]
		if not game.entities.has(uid) or not is_instance_valid(v.e) or v.e.dead:
			_free_visual(v)
			visuals.erase(uid)
			continue
		if v.pid != v.e.pid:
			# Captured: rebuild with the new owner's colours.
			_free_visual(v)
			visuals[uid] = _make_visual(v.e)
			v = visuals[uid]
		if v.sheet == null:
			continue
		if v.e.is_unit():
			_update_unit(v, delta)
		else:
			_update_building(v, delta)
	_update_projectiles(delta)
	_update_flyovers()
	_update_mines(delta)
	_update_ghost()
	overlay.queue_redraw()

func _free_visual(v: Dictionary) -> void:
	v.node.queue_free()
	if v.has("shadow"):
		v.shadow.queue_free()

func _update_unit(v: Dictionary, delta: float) -> void:
	var e = v.e
	var n: Node2D = v.node
	n.visible = e.visible
	if v.has("shadow"):
		v.shadow.visible = e.visible
	if not n.visible:
		return
	v.t += delta
	var h: float = e.altitude_now
	if e.is_naval:
		h = sin(v.t * 1.7 + float(e.uid)) * 0.012
	var target := SpriteLib.iso(e.pos, h)
	n.position = target if n.position.distance_to(target) > 120.0 else n.position.lerp(target, minf(1.0, delta * 18.0))
	if e.is_air_unit:
		var gp := SpriteLib.iso(e.pos)
		if v.has("shadow"):
			v.shadow.position = gp
			v.shadow.modulate.a = clampf(1.0 - h * 0.25, 0.45, 1.0)
		if h > 0.05:
			n.position.y += sin(v.t * 2.3 + float(e.uid)) * 1.5
		if v.has("rotor"):
			var info: Dictionary = v.rotor.get_meta("rotor")
			var rp: Array = info.pos
			var c := cos(e.facing)
			var sn := sin(e.facing)
			v.rotor.position = SpriteLib.iso_cells(Vector2(rp[0] * c - rp[2] * sn, rp[0] * sn + rp[2] * c), rp[1])
			v.rotor.queue_redraw()
	if v.has("extras") and (e.deployed or e.para_t > 0.0 or v.get("had_extras", false)):
		v.extras.queue_redraw()
		v["had_extras"] = e.deployed or e.para_t > 0.0
	# Submarines: own submerged boats show as a dark translucent shape.
	if e.submarine:
		n.modulate = Color(0.55, 0.65, 0.75, 0.45) if e.submerged() else Color.WHITE
	elif e.is_naval and e.moving and not game.headless:
		v.wake_t -= delta
		if v.wake_t <= 0.0:
			v.wake_t = 0.09
			var back: Vector2 = e.pos - Vector2(cos(e.facing), sin(e.facing)) * e.radius * 1.1
			_wake(SpriteLib.iso(back))
	var s: SpriteLib.Sheet = v.sheet
	var body: Sprite2D = v.body
	var dirs: int = int(s.extra.get("dirs", 32))
	if e.is_infantry() and e.deployed and v.get("dug") != null:
		# Dug-in emplacement sheet: aim pose, two firing frames.
		var dg: SpriteLib.Sheet = v.dug
		body.texture = dg.tex
		body.material = SpriteLib.team_material(e.team_color(), dg.mask)
		var dfr := 0
		if game.sim_time - e.last_fire_time < 0.18:
			dfr = 1 if game.sim_time - e.last_fire_time < 0.09 else 2
		body.region_rect = dg.region(dfr * 8 + SpriteLib.dir_index(e.facing, 8))
		v["showing_dug"] = true
	elif e.is_infantry():
		if v.get("showing_dug", false):
			body.texture = s.tex
			body.material = SpriteLib.team_material(e.team_color(), s.mask)
			v["showing_dug"] = false
		var d := SpriteLib.dir_index(e.facing, 8)
		var fr := 0
		if game.sim_time - e.last_fire_time < 0.18:
			fr = 7 + (1 if game.sim_time - e.last_fire_time < 0.09 else 0)
		elif e.moving and e.order != "idle":
			fr = 1 + int(v.t * 11.0) % 6
		body.region_rect = s.region(fr * 8 + d)
	else:
		var d := SpriteLib.dir_index(e.facing, dirs)
		var state := 0
		if int(s.extra.get("states", 1)) > 1 and e.is_harvester and e.cargo > e.capacity * 0.35:
			state = 1
		body.region_rect = s.region(state * dirs + d)
		if v.has("turret"):
			var ts: SpriteLib.Sheet = v.tsheet
			v.turret.region_rect = ts.region(SpriteLib.dir_index(e.turret_facing, int(ts.extra.get("dirs", 32))))
			var pv: Array = s.extra.get("pivot", [0, 0.25, 0])
			var c := cos(e.facing)
			var sn := sin(e.facing)
			var off := Vector2(pv[0] * c - pv[2] * sn, pv[0] * sn + pv[2] * c)
			v.turret.position = SpriteLib.iso_cells(off, pv[1])
	if e.hit_flash > 0.0:
		body.modulate = Color(1.6, 1.6, 1.6)
	else:
		body.modulate = Color.WHITE

func _update_building(v: Dictionary, delta: float) -> void:
	var e = v.e
	var n: Node2D = v.node
	n.visible = e.visible
	if not n.visible:
		return
	v.t += delta
	var s: SpriteLib.Sheet = v.sheet
	var body: Sprite2D = v.body
	var hr: float = e.hp_ratio()
	if not e.completed:
		body.texture = s.tex
		body.region_rect = s.region(2 + clampi(int(e.make_progress * 5.0), 0, 4))
	elif hr < 0.5:
		body.texture = s.tex
		body.region_rect = s.region(1)
	elif v.has("anim"):
		var an: SpriteLib.Sheet = v.anim
		var fi := 0
		if e.def.get("sprite", "") == "arc_coil":
			fi = clampi(int(e.charge * an.count), 0, an.count - 1) if e.powered() else 0
		elif e.powered():
			fi = int(v.t * 6.0) % an.count
		body.texture = an.tex
		body.region_rect = an.region(fi)
	else:
		body.texture = s.tex
		body.region_rect = s.region(0)
	if v.has("turret"):
		var ts: SpriteLib.Sheet = v.tsheet
		v.turret.region_rect = ts.region(SpriteLib.dir_index(e.turret_facing, int(ts.extra.get("dirs", 32))))
		v.turret.visible = e.completed
	body.modulate = Color(1.4, 1.4, 1.4) if e.hit_flash > 0.0 else Color.WHITE
	if not e.completed or game.headless:
		return
	# Chimney smoke and damage smoke/fire.
	v.smoke_t -= delta
	if v.smoke_t <= 0.0:
		v.smoke_t = 0.35 + randf() * 0.3
		if e.powered():
			for sp in s.extra.get("smoke", []):
				var steam: bool = e.def.get("sprite", "") in ["power", "adv_power"]
				_puff("smoke_light" if steam else "smoke_dark", SpriteLib.iso_cells(Vector2(e.cell0) + Vector2(sp[0], sp[2]), sp[1]), 0.55 if steam else 0.4, Vector2(10, -26))
		if hr < 0.5:
			var h := float(s.extra.get("height", 1.0))
			var rp := Vector2(e.cell0) + Vector2(randf_range(0.2, 0.8) * e.size.x, randf_range(0.2, 0.8) * e.size.y)
			_puff("smoke_dark", SpriteLib.iso_cells(rp, h * randf_range(0.3, 0.7)), 0.7, Vector2(8, -30))
			if hr < 0.25:
				var fx := IsoFx.new()
				fx.play(fx_sheets.fire, SpriteLib.iso_cells(rp, h * 0.3), 16.0, 0.8)
				fx.loop = true
				fx.life = 1.2
				air_fx.add_child(fx)

func _wake(p: Vector2) -> void:
	if fx_sheets.get("smoke_light") == null or ground_fx.get_child_count() > 400:
		return
	var fx := IsoFx.new()
	fx.play(fx_sheets.smoke_light, p + Vector2(randf_range(-4, 4), randf_range(-2, 2)), 7.0, 0.32)
	fx.modulate = Color(1.3, 1.4, 1.5, 0.7)
	ground_fx.add_child(fx)

func _puff(kind: String, p: Vector2, sc: float, drift: Vector2) -> void:
	if fx_sheets.get(kind) == null or air_fx.get_child_count() > 500 or randf() > Config.effects_density():
		return
	var fx := IsoFx.new()
	fx.play(fx_sheets[kind], p, 9.0, sc)
	fx.drift = drift
	air_fx.add_child(fx)

func _on_removed(e) -> void:
	if not e.is_unit() or not e.is_infantry() or not e.visible:
		return
	var name := SpriteLib.entity_sheet_name(e)
	var ds := SpriteLib.sheet(name + "_die")
	if ds == null:
		return
	var fx := IsoFx.new()
	fx.play(ds, SpriteLib.iso(e.pos), 10.0)
	fx.hold_last = 3.0
	fx.fade = 1.0
	fx.material = SpriteLib.team_material(e.team_color(), ds.mask)
	ground_fx.add_child(fx)

var flyover_sprites: Array = []
var mines_node: Node2D
var mines_t: float = 0.0

## Support-power aircraft (transport for paratroopers, bombers).
func _update_flyovers() -> void:
	var fl: Array = game.specials.flyovers
	while flyover_sprites.size() < fl.size():
		var body := Sprite2D.new()
		body.region_enabled = true
		body.centered = false
		air_layer.add_child(body)
		var sh := Sprite2D.new()
		sh.region_enabled = true
		sh.centered = false
		ground_fx.add_child(sh)
		flyover_sprites.append([body, sh, ""])
	for i in flyover_sprites.size():
		var pair: Array = flyover_sprites[i]
		var body: Sprite2D = pair[0]
		var sh: Sprite2D = pair[1]
		if i >= fl.size():
			body.visible = false
			sh.visible = false
			continue
		var f: Dictionary = fl[i]
		var name: String = ("u_transport_%s" if f.kind == "transport" else "u_bomber_%s") % f.faction
		if not SpriteLib.has(name):
			name = "u_jet_%s" % f.faction
		var s := SpriteLib.sheet(name)
		if s == null:
			continue
		if pair[2] != name:
			pair[2] = name
			body.texture = s.tex
			body.offset = -Vector2(s.ax, s.ay)
			body.material = SpriteLib.team_material(game.players[f.pid].color, s.mask)
			var stex := SpriteLib._load_tex("res://assets/sprites/%s_shadow.png" % name)
			sh.texture = stex
			sh.offset = -Vector2(s.ax, s.ay)
		var d := SpriteLib.dir_index(f.dir.angle(), int(s.extra.get("dirs", 32)))
		body.region_rect = s.region(d)
		sh.region_rect = s.region(d)
		body.visible = true
		sh.visible = sh.texture != null
		body.position = SpriteLib.iso(f.pos, 2.2)
		sh.position = SpriteLib.iso(f.pos)

## The player's own (and allies') mines; enemy mines are invisible.
func _update_mines(delta: float) -> void:
	mines_t -= delta
	if mines_t > 0.0:
		return
	mines_t = 0.4
	if mines_node == null:
		mines_node = Node2D.new()
		mines_node.draw.connect(_draw_mines)
		ground_fx.add_child(mines_node)
	mines_node.queue_redraw()

func _draw_mines() -> void:
	for c in game.specials.visible_mines(game.human_pid):
		var p := SpriteLib.iso_cells(Vector2(c) + Vector2(0.5, 0.5))
		mines_node.draw_circle(p + Vector2(0, 2), 7.0, Color(0, 0, 0, 0.35))
		mines_node.draw_circle(p, 6.0, Color(0.28, 0.3, 0.24))
		mines_node.draw_circle(p + Vector2(0, -1), 2.5, Color(0.85, 0.15, 0.1))

func _update_projectiles(_delta: float) -> void:
	var seen := {}
	for pr in game.projectiles:
		var id = pr.get_instance_id()
		seen[id] = true
		var n: Node2D = proj_vis.get(id)
		if n == null:
			n = Node2D.new()
			var key := "rocket" if pr.kind == "rocket" else ("fire" if pr.kind == "flame" else "shell")
			var s: SpriteLib.Sheet = fx_sheets.get(key)
			if s != null:
				var sp := Sprite2D.new()
				sp.texture = s.tex
				sp.region_enabled = true
				sp.region_rect = s.region(0)
				sp.scale = Vector2(0.7, 0.7) if key != "fire" else Vector2(0.5, 0.5)
				n.add_child(sp)
			air_fx.add_child(n)
			proj_vis[id] = n
			n.set_meta("trail_t", 0.0)
		var tot: float = maxf(pr.from.distance_to(pr.to), 1.0)
		var k: float = clampf(pr.from.distance_to(pr.cur) / tot, 0.0, 1.0)
		n.position = SpriteLib.iso(pr.cur, 0.35 + lerpf(pr.h_from, pr.h_to, k))
		var d := Vector2(cos(pr.rotation), sin(pr.rotation))
		n.rotation = Vector2((d.x - d.y) * 64.0, (d.x + d.y) * 32.0).angle()
		if pr.kind == "flame":
			n.scale = Vector2.ONE * (1.0 + pr.t * 4.0)
		elif pr.kind == "rocket":
			var tt: float = n.get_meta("trail_t") - _delta
			if tt <= 0.0:
				tt = 0.035
				_puff("smoke_light", n.position, 0.22, Vector2(0, -8))
			n.set_meta("trail_t", tt)
	for id in proj_vis.keys():
		if not seen.has(id):
			proj_vis[id].queue_free()
			proj_vis.erase(id)

# ---------------------------------------------------------------- effects (called by the simulation)

func spawn_fx(kind: String, p: Vector2, opts: Dictionary) -> void:
	if air_fx.get_child_count() > 500 and kind != "crater":
		return
	match kind:
		"explosion", "explosion_big", "explosion_small":
			var fx := IsoFx.new()
			fx.play(fx_sheets.get(kind), SpriteLib.iso(p, float(opts.get("h", 0.0))), 22.0)
			fx.fade = 0.2
			air_fx.add_child(fx)
		"crater":
			var s: SpriteLib.Sheet = fx_sheets.crater
			if s == null:
				return
			var fx := IsoFx.new()
			fx.play(s, SpriteLib.iso(p) + Vector2(0, 14), 1.0, clampf(float(opts.get("r", 12.0)) / 14.0, 0.5, 2.5))
			fx.frame_override = randi() % s.count
			fx.life = 25.0
			fx.fade = 5.0
			ground_fx.add_child(fx)
		"muzzle":
			var s: SpriteLib.Sheet = fx_sheets.muzzle
			if s == null:
				return
			var fx := IsoFx.new()
			fx.play(s, SpriteLib.iso(p, 0.32 + float(opts.get("h", 0.0))), 50.0, 1.3 if opts.get("big", false) else 0.8)
			var a: float = opts.get("angle", 0.0)
			var d := Vector2(cos(a), sin(a))
			fx.rotation = Vector2((d.x - d.y) * 64.0, (d.x + d.y) * 32.0).angle()
			fx.fade = 0.02
			air_fx.add_child(fx)
		"tracer", "zap":
			var fx := IsoFx.new()
			fx.position = SpriteLib.iso(p, 0.32 + float(opts.get("h", 0.0)))
			fx.line_to = SpriteLib.iso(opts.get("to", p), 0.25 + float(opts.get("th", 0.0)))
			fx.life = 0.07 if kind == "tracer" else 0.25
			fx.zap = kind == "zap"
			fx.line_w = 1.5 if kind == "tracer" else 2.0
			air_fx.add_child(fx)
		"spark":
			var s: SpriteLib.Sheet = fx_sheets.muzzle
			if s != null:
				var fx := IsoFx.new()
				fx.play(s, SpriteLib.iso(p, 0.25), 25.0, 1.2)
				fx.modulate = Color(0.6, 0.85, 1.4)
				air_fx.add_child(fx)
		"flame_burst":
			var s: SpriteLib.Sheet = fx_sheets.fire
			if s != null:
				var fx := IsoFx.new()
				fx.play(s, SpriteLib.iso(p), 18.0, 0.9)
				air_fx.add_child(fx)

# ---------------------------------------------------------------- placement ghost

func _update_ghost() -> void:
	var active: bool = controller != null and controller.mode == "place" and controller.place_type != ""
	ghost.visible = active
	if not active:
		ghost_type = ""
		return
	var t: String = controller.place_type
	var d := Data.def(t)
	var p = game.players[game.human_pid]
	if ghost_type != t:
		ghost_type = t
		var name := ""
		for f in [p.faction, "coalition", "dominion"]:
			if SpriteLib.has("b_%s_%s" % [d.get("sprite", ""), f]):
				name = "b_%s_%s" % [d.get("sprite", ""), f]
				break
		var s := SpriteLib.sheet(name)
		ghost_sprite.visible = s != null
		if s != null:
			ghost_sprite.texture = s.tex
			ghost_sprite.region_rect = s.region(0)
			ghost_sprite.offset = -Vector2(s.ax, s.ay)
			ghost_sprite.material = SpriteLib.team_material(p.color, s.mask)
	var c: Vector2i = controller.placement_cell()
	ghost.position = Vector2.ZERO
	ghost_sprite.position = SpriteLib.iso_cells(Vector2(c))
	ghost.set_meta("cell", c)
	ghost.queue_redraw()

func _draw_ghost_cells() -> void:
	if not ghost.has_meta("cell") or ghost_type == "":
		return
	var c: Vector2i = ghost.get_meta("cell")
	var d := Data.def(ghost_type)
	var ok: bool = game.can_place(game.human_pid, ghost_type, c) == ""
	var fp: Array = d.get("footprint", ["x"])
	for y in fp.size():
		for x in String(fp[y]).length():
			var cc := c + Vector2i(x, y)
			var good := ok
			if not ok:
				if d.get("placement", "") == "water":
					good = game.map.in_bounds(cc) and game.map.terrain_id(cc) == "water" and game.map.occupied[game.map.idx(cc)] == 0
				else:
					good = game.map.buildable(cc) if String(fp[y])[x] == "x" else game.map.passable(cc, "track")
			var col := Color(0.2, 1.0, 0.35, 0.32) if ok else (Color(1.0, 0.8, 0.2, 0.3) if good else Color(1.0, 0.2, 0.15, 0.4))
			var pts := PackedVector2Array([SpriteLib.iso_cells(Vector2(cc) + Vector2(0.04, 0.04)), SpriteLib.iso_cells(Vector2(cc) + Vector2(0.96, 0.04)),
				SpriteLib.iso_cells(Vector2(cc) + Vector2(0.96, 0.96)), SpriteLib.iso_cells(Vector2(cc) + Vector2(0.04, 0.96))])
			ghost.draw_colored_polygon(pts, col)

# ---------------------------------------------------------------- overlay (selection, health, markers)

func _bar(pos: Vector2, w: float, ratio: float, inv: bool) -> void:
	var col := Color(0.2, 0.85, 0.3) if ratio > 0.6 else (Color(0.95, 0.8, 0.2) if ratio > 0.3 else Color(0.9, 0.2, 0.15))
	var r := Rect2(pos.x - w * 0.5, pos.y, w, 5)
	overlay.draw_rect(r.grow(1), Color(0, 0, 0, 0.8))
	overlay.draw_rect(Rect2(r.position, Vector2(w * ratio, 5)), col)
	var segs := int(w / 6.0)
	for i in range(1, segs):
		var x := r.position.x + i * w / segs
		overlay.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.4), 1.0)
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
		var h := _height_of(b)
		var top := world_to_screen(r.get_center(), h + 0.15)
		if not screen_has(top, 300):
			continue
		if b.selected:
			var pts := PackedVector2Array()
			for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				pts.append(world_to_screen(corner))
			for i in 4:
				var a := pts[i]
				overlay.draw_line(a, a.lerp(pts[(i + 1) % 4], 0.2), white, 2.0)
				overlay.draw_line(a, a.lerp(pts[(i + 3) % 4], 0.2), white, 2.0)
			if b.rally != Vector2.INF and b.pid == game.human_pid:
				var rp := world_to_screen(b.rally)
				overlay.draw_dashed_line(world_to_screen(r.get_center()), rp, Color(1, 1, 1, 0.6), 1.5, 6.0)
				overlay.draw_circle(rp, 4, Color(1, 1, 1, 0.8))
		if b.selected or b.hovered or b.hp_ratio() < 0.999:
			_bar(top, clampf((b.size.x + b.size.y) * 22.0 * camera.zoom.x, 30, 140), b.hp_ratio(), b.invulnerable)
		if b.completed and b.requires_power() and not b.powered():
			overlay.draw_string(font, top + Vector2(-26, -6), "OFFLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.35, 0.2))
		if b.repairing:
			var c := top + Vector2(0, -16)
			overlay.draw_circle(c, 9, Color(0.1, 0.45, 0.15, 0.85))
			overlay.draw_line(c - Vector2(5, 0), c + Vector2(5, 0), Color.WHITE, 2.0)
			overlay.draw_line(c - Vector2(0, 5), c + Vector2(0, 5), Color.WHITE, 2.0)
	for bomb in game.specials.bombs:
		var bp := world_to_screen(bomb.pos, 0.7)
		if not screen_has(bp):
			continue
		var blink: bool = fmod(bomb.t, 0.5 if bomb.t < 3.0 else 1.0) < 0.25
		overlay.draw_circle(bp, 8.0, Color(0.08, 0.08, 0.08, 0.85))
		overlay.draw_circle(bp, 5.0, Color(1, 0.15, 0.1) if blink else Color(0.45, 0.05, 0.05))
		overlay.draw_string(font, bp + Vector2(10, 5), "%d" % int(ceil(bomb.t)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.85, 0.3))
	for u in game.units:
		if u.dead or not u.visible:
			continue
		var base := world_to_screen(u.pos, u.altitude_now)
		if not screen_has(base):
			continue
		var rs := unit_screen_radius(u)
		if u.selected:
			var c := base + Vector2(0, -rs * 0.3)
			var rr := Vector2(rs + 6.0, (rs + 6.0) * 0.55)
			for i in 4:
				var a := i * PI * 0.5 + PI * 0.25
				var pts := PackedVector2Array()
				for k in 7:
					var aa := a - 0.35 + 0.7 * k / 6.0
					pts.append(c + Vector2(cos(aa) * rr.x, sin(aa) * rr.y))
				overlay.draw_polyline(pts, white, 1.6)
		if u.selected or u.hovered or u.hp_ratio() < 0.5:
			_bar(base + Vector2(0, -rs * 1.9 - 12), maxf(rs * 2.0, 20.0), u.hp_ratio(), u.invulnerable)
		if u.selected and u.is_harvester:
			var ratio := float(u.cargo) / float(maxi(u.capacity, 1))
			var p := base + Vector2(-rs, -rs * 1.9 - 5)
			overlay.draw_rect(Rect2(p, Vector2(rs * 2.0, 3)), Color(0, 0, 0, 0.7))
			overlay.draw_rect(Rect2(p, Vector2(rs * 2.0 * ratio, 3)), Color(0.95, 0.75, 0.25))
		if u.selected and u.pid == game.human_pid and u.moving and u.order in ["move", "attack_move", "patrol"] and game.selection.size() <= 12:
			var col := Color(0.4, 1, 0.4, 0.35) if u.order == "move" else Color(1, 0.4, 0.3, 0.35)
			overlay.draw_line(base, world_to_screen(u.goal), col, 1.0)
	if controller != null:
		for m in controller.markers:
			var a: float = m.t / 0.6
			var sp := world_to_screen(m.pos)
			var r: float = 6.0 + (1.0 - a) * 16.0
			var pts := PackedVector2Array()
			for k in 21:
				var aa := TAU * k / 20.0
				pts.append(sp + Vector2(cos(aa) * r, sin(aa) * r * 0.5))
			overlay.draw_polyline(pts, Color(m.col.r, m.col.g, m.col.b, a), 2.0)
