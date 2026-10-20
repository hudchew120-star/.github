class_name Models
extends RefCounted
## Procedural 3D models for every unit and structure, assembled from primitive meshes.
## Units face +X; 1 world unit = 1 map cell. Buildings are built from their footprint's
## top-left corner. Animated parts are stored as metadata on the returned root node.

static var _mats := {}
static var _meshes := {}

# ---------------------------------------------------------------- materials

static func mat(key: String, col: Color, metal: float = 0.0, rough: float = 0.7, emit: Color = Color.BLACK, emit_e: float = 0.0) -> StandardMaterial3D:
	var k := "%s|%s" % [key, col.to_html()]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	_mats[k] = m
	return m

static func team_mat(team: Color) -> StandardMaterial3D:
	return mat("team", team.lerp(Color(0.5, 0.5, 0.5), 0.12), 0.35, 0.42)

static func hull_mat(team: Color, faction: String) -> StandardMaterial3D:
	var base := Color(0.40, 0.44, 0.34) if faction == "coalition" else Color(0.38, 0.34, 0.29)
	return mat("hull", base.lerp(team, 0.4), 0.3, 0.55)

static func conc(faction: String) -> StandardMaterial3D:
	return mat("conc", Color(0.66, 0.68, 0.70) if faction == "coalition" else Color(0.56, 0.51, 0.47), 0.0, 0.88)

static func conc_dark(faction: String) -> StandardMaterial3D:
	return mat("concd", Color(0.42, 0.44, 0.47) if faction == "coalition" else Color(0.36, 0.32, 0.30), 0.0, 0.9)

static func metal_dark() -> StandardMaterial3D:
	return mat("mdark", Color(0.17, 0.17, 0.18), 0.65, 0.45)

static func steel() -> StandardMaterial3D:
	return mat("steel", Color(0.55, 0.57, 0.6), 0.75, 0.35)

static func track_mat() -> StandardMaterial3D:
	return mat("track", Color(0.08, 0.08, 0.08), 0.2, 0.9)

static func glass() -> StandardMaterial3D:
	return mat("glass", Color(0.25, 0.45, 0.6), 0.8, 0.12, Color(0.3, 0.6, 0.8), 0.25)

static func hazard() -> StandardMaterial3D:
	return mat("haz", Color(0.92, 0.72, 0.12), 0.2, 0.5)

static func light_mat(col: Color, e: float = 3.0) -> StandardMaterial3D:
	return mat("light", col, 0.0, 0.4, col, e)

static func ore_mat(kind: int) -> StandardMaterial3D:
	if kind == 2:
		return mat("gem", Color(0.35, 0.75, 1.0), 0.4, 0.15, Color(0.2, 0.55, 1.0), 0.6)
	return mat("ore", Color(0.95, 0.74, 0.22), 0.75, 0.3, Color(0.9, 0.6, 0.1), 0.25)

# ---------------------------------------------------------------- primitives

static func box_mesh(s: Vector3) -> BoxMesh:
	var k := "box%s" % s
	if not _meshes.has(k):
		var m := BoxMesh.new()
		m.size = s
		_meshes[k] = m
	return _meshes[k]

static func cyl_mesh(rt: float, rb: float, h: float, seg: int = 16) -> CylinderMesh:
	var k := "cyl%.3f_%.3f_%.3f_%d" % [rt, rb, h, seg]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[k] = m
	return _meshes[k]

static func sphere_mesh(r: float, h: float = -1.0, seg: int = 16) -> SphereMesh:
	var hh := r * 2.0 if h < 0.0 else h
	var k := "sph%.3f_%.3f_%d" % [r, hh, seg]
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = hh
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		_meshes[k] = m
	return _meshes[k]

static func prism_mesh(s: Vector3) -> PrismMesh:
	var k := "prism%s" % s
	if not _meshes.has(k):
		var m := PrismMesh.new()
		m.size = s
		_meshes[k] = m
	return _meshes[k]

static func torus_mesh(ri: float, ro: float) -> TorusMesh:
	var k := "tor%.3f_%.3f" % [ri, ro]
	if not _meshes.has(k):
		var m := TorusMesh.new()
		m.inner_radius = ri
		m.outer_radius = ro
		m.rings = 16
		m.ring_segments = 8
		_meshes[k] = m
	return _meshes[k]

static func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = sc
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, s: Vector3, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return part(parent, box_mesh(s), m, pos, rot_deg)

static func cyl(parent: Node3D, rt: float, rb: float, h: float, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, seg: int = 16) -> MeshInstance3D:
	return part(parent, cyl_mesh(rt, rb, h, seg), m, pos, rot_deg)

## Row of windows on a wall. `axis` is the wall direction (X or Z), `normal` points out of the wall.
static func windows(body: Node3D, start: Vector3, axis: Vector3, normal: Vector3, count: int, spacing: float, size: Vector2 = Vector2(0.1, 0.07), lit: bool = true) -> void:
	var m: Material = mat("win_lit", Color(0.95, 0.85, 0.55), 0.2, 0.3, Color(1.0, 0.8, 0.45), 1.6) if lit else glass()
	for i in count:
		var p := start + axis * (i * spacing) + normal * 0.006
		var s3 := Vector3(size.x, size.y, 0.012) if absf(axis.x) > 0.5 else Vector3(0.012, size.y, size.x)
		box(body, s3, m, p)

static func vent(body: Node3D, pos: Vector3, w: float = 0.18) -> void:
	box(body, Vector3(w, 0.08, w), steel(), pos + Vector3(0, 0.04, 0))
	for i in 3:
		box(body, Vector3(w * 0.9, 0.012, 0.02), metal_dark(), pos + Vector3(0, 0.085, -w * 0.3 + i * w * 0.3))

static func pipe(body: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var d := b - a
	var mi := MeshInstance3D.new()
	mi.mesh = cyl_mesh(r, r, 1.0, 8)
	mi.material_override = m
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * d.length(), z), a + d * 0.5)
	body.add_child(mi)

static func panel_lines(body: Node3D, pos: Vector3, size: Vector3, n: int, m: Material) -> void:
	# Vertical seams on the +Z face of a block.
	for i in range(1, n):
		var x := pos.x - size.x * 0.5 + size.x * i / n
		box(body, Vector3(0.015, size.y * 0.9, 0.01), m, Vector3(x, pos.y + size.y * 0.5, pos.z + size.z * 0.5 + 0.005))

static func pivot(parent: Node3D, pos: Vector3, name: String) -> Node3D:
	var p := Node3D.new()
	p.name = name
	p.position = pos
	parent.add_child(p)
	return p

# ---------------------------------------------------------------- units

static func build_unit(sprite: String, team: Color, faction: String) -> Node3D:
	var root := Node3D.new()
	var body := pivot(root, Vector3.ZERO, "body")
	root.set_meta("body", body)
	match sprite:
		"infantry", "rocket_inf", "heavy_inf", "flame_inf":
			_infantry(root, body, sprite, team, faction)
		"jeep":
			_jeep(root, body, team, faction)
		"tank_light":
			_tank(root, body, team, faction, 0.62, 0.46, 0.17, 0.42, 1)
		"tank_medium":
			_tank(root, body, team, faction, 0.72, 0.52, 0.2, 0.5, 1)
		"tank_heavy":
			_tank(root, body, team, faction, 0.84, 0.62, 0.23, 0.52, 2)
		"harvester":
			_harvester(root, body, team, faction)
		"mcv":
			_mcv(root, body, team, faction)
		_:
			box(body, Vector3(0.4, 0.3, 0.4), team_mat(team), Vector3(0, 0.15, 0))
	return root

static func _tracks(body: Node3D, l: float, w: float, tw: float) -> void:
	for s in [-1.0, 1.0]:
		var z: float = s * (w * 0.5 - tw * 0.5)
		box(body, Vector3(l, 0.13, tw), track_mat(), Vector3(0, 0.075, z))
		for i in 4:
			var x := -l * 0.38 + i * l * 0.253
			cyl(body, 0.055, 0.055, tw * 1.02, metal_dark(), Vector3(x, 0.07, z), Vector3(90, 0, 0), 10)

static func _tank(root: Node3D, body: Node3D, team: Color, faction: String, l: float, w: float, tur_r: float, barrel: float, barrels: int) -> void:
	var tw := w * 0.26
	_tracks(body, l, w, tw)
	var hm := hull_mat(team, faction)
	box(body, Vector3(l * 0.9, 0.13, w - tw * 0.9), hm, Vector3(-0.01, 0.19, 0))
	box(body, Vector3(l * 0.22, 0.09, w - tw * 1.1), hm, Vector3(l * 0.36, 0.2, 0), Vector3(0, 0, -18))
	box(body, Vector3(l * 0.15, 0.06, w * 0.5), metal_dark(), Vector3(-l * 0.4, 0.26, 0))
	var tur := pivot(root, Vector3(-l * 0.06, 0.25, 0), "turret")
	root.set_meta("turret", tur)
	cyl(tur, tur_r * 0.92, tur_r, 0.12, hm, Vector3(0, 0.06, 0), Vector3.ZERO, 12)
	box(tur, Vector3(tur_r * 1.1, 0.09, tur_r * 1.3), hm, Vector3(-tur_r * 0.6, 0.06, 0))
	cyl(tur, tur_r * 0.35, tur_r * 0.35, 0.03, team_mat(team), Vector3(-tur_r * 0.25, 0.135, -tur_r * 0.3), Vector3.ZERO, 10)
	var zs := [0.0] if barrels == 1 else [-0.06, 0.06]
	for z in zs:
		cyl(tur, 0.028, 0.032, barrel, metal_dark(), Vector3(tur_r * 0.7 + barrel * 0.5, 0.07, z), Vector3(0, 0, 90), 8)
		cyl(tur, 0.04, 0.04, 0.06, metal_dark(), Vector3(tur_r * 0.7 + barrel, 0.07, z), Vector3(0, 0, 90), 8)
	cyl(tur, 0.006, 0.006, 0.3, metal_dark(), Vector3(-tur_r * 0.9, 0.25, tur_r * 0.5))

static func _jeep(root: Node3D, body: Node3D, team: Color, faction: String) -> void:
	var hm := hull_mat(team, faction)
	for p in [Vector2(-0.16, -0.15), Vector2(0.16, -0.15), Vector2(-0.16, 0.15), Vector2(0.16, 0.15)]:
		cyl(body, 0.075, 0.075, 0.07, track_mat(), Vector3(p.x, 0.075, p.y), Vector3(90, 0, 0), 12)
	box(body, Vector3(0.52, 0.1, 0.28), hm, Vector3(0, 0.15, 0))
	box(body, Vector3(0.16, 0.08, 0.26), hm, Vector3(0.17, 0.22, 0))
	box(body, Vector3(0.02, 0.09, 0.24), glass(), Vector3(0.09, 0.25, 0), Vector3(0, 0, -25))
	var tur := pivot(root, Vector3(-0.08, 0.24, 0), "turret")
	root.set_meta("turret", tur)
	cyl(tur, 0.05, 0.06, 0.06, metal_dark(), Vector3(0, 0.03, 0))
	cyl(tur, 0.014, 0.014, 0.24, metal_dark(), Vector3(0.13, 0.05, 0), Vector3(0, 0, 90), 6)
	box(tur, Vector3(0.03, 0.06, 0.1), steel(), Vector3(0.04, 0.06, 0))

static func _harvester(root: Node3D, body: Node3D, team: Color, faction: String) -> void:
	var l := 0.86
	var w := 0.64
	_tracks(body, l, w, w * 0.25)
	var hm := hull_mat(team, faction)
	box(body, Vector3(l * 0.62, 0.08, w * 0.62), hm, Vector3(-0.1, 0.18, 0))
	for s in [-1.0, 1.0]:
		box(body, Vector3(l * 0.6, 0.16, 0.03), hm, Vector3(-0.1, 0.29, s * w * 0.3))
	box(body, Vector3(0.03, 0.16, w * 0.62), hm, Vector3(-0.4, 0.29, 0))
	box(body, Vector3(0.03, 0.16, w * 0.62), hm, Vector3(0.2, 0.29, 0))
	var fill := box(body, Vector3(l * 0.56, 0.14, w * 0.56), ore_mat(1), Vector3(-0.1, 0.22, 0))
	root.set_meta("fill", fill)
	box(body, Vector3(0.18, 0.2, w * 0.6), hm, Vector3(0.3, 0.27, 0))
	box(body, Vector3(0.02, 0.1, w * 0.45), glass(), Vector3(0.395, 0.31, 0))
	box(body, Vector3(0.14, 0.03, w * 0.6), team_mat(team), Vector3(0.3, 0.385, 0))
	var drum := cyl(body, 0.09, 0.09, w * 0.78, steel(), Vector3(0.47, 0.11, 0), Vector3(90, 0, 0), 10)
	root.set_meta("drum", drum)
	for i in 3:
		box(drum, Vector3(0.2, 0.02, 0.03), hazard(), Vector3(0, -w * 0.3 + i * w * 0.3, 0), Vector3(0, 0, i * 60))
	light_part(body, Vector3(0.4, 0.4, 0.2))
	light_part(body, Vector3(0.4, 0.4, -0.2))

static func light_part(parent: Node3D, pos: Vector3, col: Color = Color(1.0, 0.8, 0.45)) -> MeshInstance3D:
	return part(parent, sphere_mesh(0.025, -1, 8), light_mat(col, 4.0), pos)

static func _mcv(root: Node3D, body: Node3D, team: Color, faction: String) -> void:
	var l := 0.94
	var w := 0.62
	_tracks(body, l, w, w * 0.25)
	var hm := hull_mat(team, faction)
	box(body, Vector3(l * 0.9, 0.12, w * 0.7), hm, Vector3(0, 0.19, 0))
	box(body, Vector3(0.2, 0.18, w * 0.62), hm, Vector3(l * 0.36, 0.33, 0))
	box(body, Vector3(0.02, 0.1, w * 0.45), glass(), Vector3(l * 0.46 + 0.005, 0.36, 0))
	box(body, Vector3(0.5, 0.16, w * 0.6), conc(faction), Vector3(-0.12, 0.33, 0))
	box(body, Vector3(0.5, 0.03, 0.08), team_mat(team), Vector3(-0.12, 0.42, 0))
	var arm := pivot(body, Vector3(-0.32, 0.42, 0.14), "crane")
	box(arm, Vector3(0.62, 0.05, 0.05), hazard(), Vector3(0.28, 0.02, 0), Vector3(0, 0, 4))
	cyl(arm, 0.05, 0.06, 0.06, hazard(), Vector3(0, 0, 0))
	light_part(body, Vector3(l * 0.47, 0.3, 0.2))
	light_part(body, Vector3(l * 0.47, 0.3, -0.2))
	part(body, sphere_mesh(0.03, -1, 8), light_mat(Color(1, 0.55, 0.1), 5.0), Vector3(l * 0.36, 0.44, 0))

static func _infantry(root: Node3D, body: Node3D, sprite: String, team: Color, faction: String) -> void:
	var s := 1.15 if sprite == "heavy_inf" else 1.0
	var uniform := mat("uni", Color(0.33, 0.37, 0.28) if faction == "coalition" else Color(0.36, 0.3, 0.26), 0.0, 0.85)
	var legs := []
	for z in [-0.035, 0.035]:
		var leg := pivot(body, Vector3(0, 0.15 * s, z * s), "leg")
		box(leg, Vector3(0.05 * s, 0.15 * s, 0.045 * s), uniform, Vector3(0, -0.075 * s, 0))
		legs.append(leg)
	root.set_meta("legs", legs)
	box(body, Vector3(0.08 * s, 0.14 * s, 0.13 * s), team_mat(team), Vector3(0, 0.22 * s, 0))
	part(body, sphere_mesh(0.045 * s, -1, 10), mat("skin", Color(0.82, 0.66, 0.52), 0.0, 0.8), Vector3(0.005, 0.33 * s, 0))
	part(body, sphere_mesh(0.052 * s, 0.06 * s, 10), uniform, Vector3(0, 0.35 * s, 0))
	match sprite:
		"infantry":
			box(body, Vector3(0.2, 0.025, 0.025), metal_dark(), Vector3(0.09, 0.23, 0.06))
		"rocket_inf":
			cyl(body, 0.03, 0.03, 0.3, mat("tube", Color(0.32, 0.36, 0.28), 0.2, 0.6), Vector3(0.03, 0.3, 0.07), Vector3(0, 0, 90), 8)
			part(body, sphere_mesh(0.03, -1, 8), hazard(), Vector3(0.18, 0.3, 0.07))
		"heavy_inf":
			cyl(body, 0.04, 0.04, 0.34, metal_dark(), Vector3(0.04, 0.33, 0.08), Vector3(0, 0, 90), 8)
			part(body, sphere_mesh(0.05, -1, 8), mat("warhead", Color(0.45, 0.4, 0.3), 0.3, 0.6), Vector3(0.22, 0.33, 0.08))
		"flame_inf":
			cyl(body, 0.045, 0.045, 0.14, mat("ftank", Color(0.6, 0.2, 0.12), 0.4, 0.5), Vector3(-0.08, 0.24, 0))
			box(body, Vector3(0.2, 0.025, 0.025), metal_dark(), Vector3(0.09, 0.22, 0.06))
			part(body, sphere_mesh(0.02, -1, 6), light_mat(Color(1, 0.5, 0.1), 5.0), Vector3(0.2, 0.22, 0.06))

# ---------------------------------------------------------------- buildings

static func build_building(sprite: String, size: Vector2i, team: Color, faction: String) -> Node3D:
	var root := Node3D.new()
	var sx := float(size.x)
	var sz := float(size.y)
	var body := pivot(root, Vector3.ZERO, "body")
	root.set_meta("body", body)
	root.set_meta("smoke", [])
	if sprite != "pillbox" and sprite != "gun_turret" and sprite != "flame_tower":
		box(body, Vector3(sx - 0.06, 0.06, sz - 0.06), conc_dark(faction), Vector3(sx * 0.5, 0.03, sz * 0.5))
	var c := conc(faction)
	var tm := team_mat(team)
	match sprite:
		"conyard": _b_conyard(root, body, sx, sz, c, tm, faction)
		"power": _b_power(root, body, sx, sz, c, tm, faction, 2)
		"adv_power": _b_power(root, body, sx, sz, c, tm, faction, 3)
		"refinery": _b_refinery(root, body, sx, sz, c, tm, faction)
		"silo": _b_silo(root, body, sx, sz, c, tm)
		"barracks": _b_barracks(root, body, sx, sz, c, tm)
		"barracks_dom": _b_barracks_dom(root, body, sx, sz, c, tm, faction)
		"factory": _b_factory(root, body, sx, sz, c, tm, faction)
		"radar": _b_radar(root, body, sx, sz, c, tm, faction)
		"pillbox": _b_pillbox(root, body, sx, sz, c, tm, faction)
		"gun_turret": _b_gun_turret(root, body, sx, sz, c, tm, faction)
		"flame_tower": _b_flame_tower(root, body, sx, sz, c, tm, faction)
		"arc_coil": _b_arc_coil(root, body, sx, sz, c, tm, faction)
		_:
			box(body, Vector3(sx * 0.8, 0.5, sz * 0.8), c, Vector3(sx * 0.5, 0.25, sz * 0.5))
	return root

static func _block(body: Node3D, s: Vector3, m: Material, pos: Vector3, trim: Material = null) -> void:
	box(body, s, m, pos + Vector3(0, s.y * 0.5, 0))
	if trim != null:
		box(body, Vector3(s.x + 0.02, 0.035, s.z + 0.02), trim, pos + Vector3(0, s.y, 0))

static func _b_conyard(root, body, sx, sz, c, tm, faction) -> void:
	_block(body, Vector3(2.3, 0.5, 1.5), c, Vector3(1.35, 0.06, 1.05), conc_dark(faction))
	_block(body, Vector3(1.6, 0.16, 1.0), tm, Vector3(1.35, 0.56, 1.05))
	_block(body, Vector3(0.5, 0.95, 0.5), c, Vector3(0.45, 0.06, 0.55), conc_dark(faction))
	windows(body, Vector3(0.45, 0.36, 1.8), Vector3.RIGHT, Vector3.BACK, 9, 0.21)
	windows(body, Vector3(2.5, 0.36, 0.5), Vector3.BACK, Vector3.RIGHT, 6, 0.21)
	panel_lines(body, Vector3(1.35, 0.06, 1.05), Vector3(2.3, 0.5, 1.5), 6, conc_dark(faction))
	vent(body, Vector3(0.75, 0.72, 0.75))
	vent(body, Vector3(1.95, 0.72, 0.75))
	vent(body, Vector3(1.95, 0.72, 1.35), 0.14)
	pipe(body, Vector3(0.7, 0.6, 0.55), Vector3(1.1, 0.6, 0.55), 0.035, steel())
	box(body, Vector3(0.52, 0.04, 0.52), tm, Vector3(0.45, 1.03, 0.55))
	part(body, sphere_mesh(0.035, -1, 8), light_mat(Color(0.3, 1.0, 0.4), 5.0), Vector3(0.24, 1.06, 0.34))
	for i in 5:
		box(body, Vector3(0.1, 0.03, 0.4), hazard(), Vector3(2.0 + i * 0.16, 0.08, 2.55))
	var mast := pivot(body, Vector3(2.45, 0.06, 0.45), "mast")
	cyl(mast, 0.07, 0.09, 1.3, hazard(), Vector3(0, 0.65, 0), Vector3.ZERO, 8)
	var crane := pivot(mast, Vector3(0, 1.3, 0), "crane")
	root.set_meta("crane", crane)
	box(crane, Vector3(1.6, 0.08, 0.1), hazard(), Vector3(-0.55, 0, 0))
	box(crane, Vector3(0.3, 0.16, 0.2), metal_dark(), Vector3(0.35, 0, 0))
	cyl(crane, 0.008, 0.008, 0.6, metal_dark(), Vector3(-1.25, -0.3, 0))
	box(crane, Vector3(0.12, 0.08, 0.12), metal_dark(), Vector3(-1.25, -0.62, 0))
	part(body, sphere_mesh(0.04, -1, 8), light_mat(Color(1, 0.2, 0.1), 5.0), Vector3(2.45, 1.4, 0.45))
	root.get_meta("smoke").append(Vector3(0.45, 1.05, 0.55))

static func _b_power(root, body, sx, sz, c, tm, faction, towers) -> void:
	_block(body, Vector3(sx - 0.25, 0.32, sz * 0.38), c, Vector3(sx * 0.5, 0.06, sz * 0.74), conc_dark(faction))
	box(body, Vector3(sx - 0.3, 0.06, 0.04), tm, Vector3(sx * 0.5, 0.3, sz * 0.74 + sz * 0.19 + 0.01))
	var pts := []
	for i in towers:
		var x = sx * (i + 0.5) / towers
		var z = sz * 0.36 if towers == 2 else (sz * 0.32 if i != 1 else sz * 0.42)
		var r: float = minf(0.42, sx / towers * 0.42)
		cyl(body, r * 0.72, r, 0.95, c, Vector3(x, 0.06 + 0.475, z), Vector3.ZERO, 20)
		cyl(body, r * 0.62, r * 0.62, 0.02, mat("hole", Color(0.08, 0.08, 0.08), 0.0, 1.0), Vector3(x, 1.02, z), Vector3.ZERO, 16)
		box(body, Vector3(r * 1.5, 0.05, 0.04), tm, Vector3(x, 0.55, z + r * 0.88))
		pts.append(Vector3(x, 1.05, z))
	windows(body, Vector3(0.25, 0.22, sz * 0.74 + sz * 0.19), Vector3.RIGHT, Vector3.BACK, int(sx * 4) - 1, 0.24, Vector2(0.1, 0.06))
	for i in towers:
		var x2: float = sx * (i + 0.5) / towers
		pipe(body, Vector3(x2, 0.3, sz * 0.6), Vector3(x2, 0.3, sz * 0.36 + 0.3), 0.05, steel())
	vent(body, Vector3(0.3, 0.38, sz * 0.74))
	vent(body, Vector3(sx - 0.3, 0.38, sz * 0.74))
	if towers == 3:
		part(body, sphere_mesh(0.35, 0.4, 16), steel(), Vector3(sx * 0.5, 0.25, sz * 0.82))
	root.set_meta("smoke", pts)
	root.set_meta("steam", true)

static func _b_refinery(root, body, sx, sz, c, tm, faction) -> void:
	_block(body, Vector3(1.85, 0.62, 1.55), c, Vector3(1.0, 0.06, 0.85), conc_dark(faction))
	_block(body, Vector3(1.4, 0.12, 0.9), tm, Vector3(0.95, 0.68, 0.85))
	cyl(body, 0.42, 0.42, 1.0, mat("tank", Color(0.72, 0.62, 0.36), 0.6, 0.35), Vector3(2.45, 0.56, 0.62), Vector3.ZERO, 20)
	part(body, sphere_mesh(0.42, 0.4, 20), mat("tank", Color(0.72, 0.62, 0.36), 0.6, 0.35), Vector3(2.45, 1.06, 0.62))
	box(body, Vector3(0.86, 0.04, 0.05), tm, Vector3(2.45, 0.8, 1.04))
	# Dock pad in the open cell at (1, 2).
	box(body, Vector3(0.94, 0.03, 0.94), mat("dock", Color(0.25, 0.25, 0.24), 0.3, 0.8), Vector3(1.5, 0.075, 2.5))
	for i in 4:
		box(body, Vector3(0.9, 0.012, 0.05), hazard(), Vector3(1.5, 0.095, 2.1 + i * 0.26))
	box(body, Vector3(0.18, 0.12, 0.9), steel(), Vector3(1.5, 0.75, 1.9), Vector3(-28, 0, 0))
	cyl(body, 0.08, 0.1, 0.9, conc_dark(faction), Vector3(0.35, 0.95, 0.35), Vector3.ZERO, 10)
	windows(body, Vector3(0.2, 0.42, 1.63), Vector3.RIGHT, Vector3.BACK, 8, 0.22)
	panel_lines(body, Vector3(1.0, 0.06, 0.85), Vector3(1.85, 0.62, 1.55), 5, conc_dark(faction))
	vent(body, Vector3(0.55, 0.8, 0.5))
	vent(body, Vector3(1.45, 0.8, 0.5))
	pipe(body, Vector3(1.9, 0.5, 0.62), Vector3(2.1, 0.5, 0.62), 0.06, steel())
	pipe(body, Vector3(1.9, 0.3, 0.9), Vector3(2.15, 0.3, 0.9), 0.045, metal_dark())
	for a in [0.0, 90.0, 180.0, 270.0]:
		var dd := Vector3(cos(deg_to_rad(a)), 0, sin(deg_to_rad(a))) * 0.4
		box(body, Vector3(0.05, 0.5, 0.05), metal_dark(), Vector3(2.45, 0.3, 0.62) + dd)
	root.set_meta("smoke", [Vector3(0.35, 1.42, 0.35)])
	var glow := part(body, sphere_mesh(0.12, -1, 10), light_mat(Color(1, 0.7, 0.2), 0.0), Vector3(1.5, 0.45, 1.75))
	root.set_meta("glow", glow)

static func _b_silo(root, body, sx, sz, c, tm) -> void:
	cyl(body, 0.36, 0.38, 0.55, c, Vector3(0.5, 0.33, 0.5), Vector3.ZERO, 18)
	part(body, sphere_mesh(0.36, 0.3, 18), steel(), Vector3(0.5, 0.6, 0.5))
	var ring := cyl(body, 0.385, 0.385, 0.05, ore_mat(1), Vector3(0.5, 0.12, 0.5), Vector3.ZERO, 18)
	root.set_meta("fill", ring)
	cyl(body, 0.39, 0.39, 0.04, tm, Vector3(0.5, 0.5, 0.5), Vector3.ZERO, 18)

static func _b_barracks(root, body, sx, sz, c, tm) -> void:
	var canvas := mat("canvas", Color(0.43, 0.48, 0.34), 0.0, 0.95)
	for i in 2:
		var z := 0.55 + i * 0.85
		part(body, prism_mesh(Vector3(0.7, 0.5, 1.6)), canvas, Vector3(1.0, 0.31, z), Vector3(0, 90, 0))
		box(body, Vector3(0.04, 0.3, 0.2), mat("door", Color(0.12, 0.12, 0.12), 0.4, 0.6), Vector3(1.81, 0.2, z))
	for i in 6:
		part(body, sphere_mesh(0.07, 0.09, 8), mat("sand", Color(0.66, 0.58, 0.42), 0.0, 1.0), Vector3(0.2 + i * 0.12, 0.1, 1.9))
	cyl(body, 0.015, 0.015, 1.1, steel(), Vector3(1.85, 0.6, 1.8))
	box(body, Vector3(0.3, 0.18, 0.01), tm, Vector3(1.7, 1.05, 1.8))

static func _b_barracks_dom(root, body, sx, sz, c, tm, faction) -> void:
	_block(body, Vector3(1.7, 0.42, 1.4), c, Vector3(1.0, 0.06, 0.85), conc_dark(faction))
	part(body, prism_mesh(Vector3(1.7, 0.3, 1.4)), conc_dark(faction), Vector3(1.0, 0.63, 0.85))
	box(body, Vector3(0.4, 0.4, 0.02), tm, Vector3(1.0, 0.45, 1.56))
	box(body, Vector3(0.3, 0.26, 0.04), mat("door", Color(0.12, 0.12, 0.12), 0.4, 0.6), Vector3(1.0, 0.19, 1.56))
	cyl(body, 0.06, 0.08, 0.5, conc_dark(faction), Vector3(0.3, 0.6, 0.4), Vector3.ZERO, 8)
	windows(body, Vector3(0.3, 0.32, 1.55), Vector3.RIGHT, Vector3.BACK, 2, 0.2, Vector2(0.12, 0.05))
	windows(body, Vector3(1.5, 0.32, 1.55), Vector3.RIGHT, Vector3.BACK, 2, 0.2, Vector2(0.12, 0.05))

static func _b_factory(root, body, sx, sz, c, tm, faction) -> void:
	_block(body, Vector3(2.7, 0.7, 2.3), c, Vector3(1.5, 0.06, 1.25), conc_dark(faction))
	for i in 5:
		box(body, Vector3(0.06, 0.08, 2.32), conc_dark(faction), Vector3(0.45 + i * 0.52, 0.8, 1.25))
	box(body, Vector3(2.72, 0.1, 0.25), tm, Vector3(1.5, 0.72, 0.18))
	box(body, Vector3(1.2, 0.55, 0.06), mat("door", Color(0.16, 0.16, 0.16), 0.5, 0.5), Vector3(1.5, 0.34, 2.41))
	for i in 4:
		box(body, Vector3(1.22, 0.02, 0.07), steel(), Vector3(1.5, 0.12 + i * 0.13, 2.43))
	box(body, Vector3(1.4, 0.05, 0.4), hazard(), Vector3(1.5, 0.08, 2.75))
	for x in [0.35, 2.65]:
		cyl(body, 0.09, 0.11, 0.7, conc_dark(faction), Vector3(x, 1.05, 0.5), Vector3.ZERO, 10)
	root.set_meta("smoke", [Vector3(0.35, 1.42, 0.5), Vector3(2.65, 1.42, 0.5)])
	windows(body, Vector3(0.35, 0.55, 2.41), Vector3.RIGHT, Vector3.BACK, 3, 0.22)
	windows(body, Vector3(2.21, 0.55, 2.41), Vector3.RIGHT, Vector3.BACK, 3, 0.22)
	windows(body, Vector3(2.86, 0.5, 0.4), Vector3.BACK, Vector3.RIGHT, 8, 0.25)
	for x in [0.9, 1.5, 2.1]:
		vent(body, Vector3(x, 0.76, 1.0), 0.22)
	pipe(body, Vector3(0.35, 0.76, 0.5), Vector3(0.35, 0.76, 1.2), 0.04, steel())
	var blink := part(body, sphere_mesh(0.05, -1, 8), light_mat(Color(1, 0.6, 0.1), 5.0), Vector3(0.75, 0.68, 2.42))
	root.set_meta("blink", blink)

static func _b_radar(root, body, sx, sz, c, tm, faction) -> void:
	_block(body, Vector3(1.6, 0.4, 0.9), c, Vector3(1.0, 0.06, 1.35), conc_dark(faction))
	box(body, Vector3(1.6, 0.05, 0.05), tm, Vector3(1.0, 0.38, 1.81))
	cyl(body, 0.08, 0.12, 0.9, steel(), Vector3(1.0, 0.5, 0.75), Vector3.ZERO, 8)
	windows(body, Vector3(0.35, 0.3, 1.8), Vector3.RIGHT, Vector3.BACK, 6, 0.26)
	vent(body, Vector3(0.45, 0.46, 1.35))
	vent(body, Vector3(1.55, 0.46, 1.35))
	var dish := pivot(body, Vector3(1.0, 1.0, 0.75), "dish")
	root.set_meta("dish", dish)
	part(dish, cyl_mesh(0.55, 0.12, 0.12, 20), mat("dish", Color(0.86, 0.88, 0.9), 0.5, 0.35), Vector3(0.05, 0.1, 0), Vector3(0, 0, -60))
	cyl(dish, 0.012, 0.012, 0.4, metal_dark(), Vector3(0.25, 0.22, 0), Vector3(0, 0, -60))
	part(dish, sphere_mesh(0.03, -1, 8), light_mat(Color(1, 0.2, 0.15), 6.0), Vector3(0.42, 0.32, 0))

static func _b_pillbox(root, body, sx, sz, c, tm, faction) -> void:
	cyl(body, 0.4, 0.45, 0.3, c, Vector3(0.5, 0.15, 0.5), Vector3.ZERO, 6)
	cyl(body, 0.3, 0.38, 0.1, conc_dark(faction), Vector3(0.5, 0.35, 0.5), Vector3.ZERO, 6)
	var tur := pivot(body, Vector3(0.5, 0.22, 0.5), "turret")
	root.set_meta("turret", tur)
	box(tur, Vector3(0.12, 0.05, 0.25), mat("slit", Color(0.05, 0.05, 0.05), 0.0, 1.0), Vector3(0.36, 0.0, 0))
	cyl(tur, 0.015, 0.015, 0.2, metal_dark(), Vector3(0.45, 0.0, 0), Vector3(0, 0, 90), 6)
	cyl(body, 0.12, 0.12, 0.03, tm, Vector3(0.5, 0.41, 0.5), Vector3.ZERO, 6)

static func _b_gun_turret(root, body, sx, sz, c, tm, faction) -> void:
	cyl(body, 0.42, 0.46, 0.18, conc_dark(faction), Vector3(0.5, 0.09, 0.5), Vector3.ZERO, 8)
	var tur := pivot(body, Vector3(0.5, 0.2, 0.5), "turret")
	root.set_meta("turret", tur)
	box(tur, Vector3(0.42, 0.2, 0.36), steel(), Vector3(-0.02, 0.1, 0))
	box(tur, Vector3(0.3, 0.04, 0.3), tm, Vector3(-0.05, 0.215, 0))
	cyl(tur, 0.035, 0.04, 0.5, metal_dark(), Vector3(0.42, 0.12, 0), Vector3(0, 0, 90), 8)

static func _b_flame_tower(root, body, sx, sz, c, tm, faction) -> void:
	cyl(body, 0.3, 0.38, 0.55, c, Vector3(0.5, 0.275, 0.5), Vector3.ZERO, 10)
	cyl(body, 0.2, 0.2, 0.25, mat("ftank", Color(0.6, 0.2, 0.12), 0.4, 0.5), Vector3(0.5, 0.67, 0.5), Vector3.ZERO, 12)
	var tur := pivot(body, Vector3(0.5, 0.7, 0.5), "turret")
	root.set_meta("turret", tur)
	cyl(tur, 0.04, 0.05, 0.36, metal_dark(), Vector3(0.28, 0.0, 0), Vector3(0, 0, 90), 8)
	part(tur, sphere_mesh(0.03, -1, 6), light_mat(Color(1, 0.5, 0.1), 6.0), Vector3(0.47, 0.0, 0))
	cyl(body, 0.31, 0.31, 0.04, tm, Vector3(0.5, 0.5, 0.5), Vector3.ZERO, 10)

static func _b_arc_coil(root, body, sx, sz, c, tm, faction) -> void:
	cyl(body, 0.42, 0.46, 0.25, conc_dark(faction), Vector3(0.5, 0.125, 1.2), Vector3.ZERO, 10)
	cyl(body, 0.12, 0.2, 1.5, metal_dark(), Vector3(0.5, 1.0, 1.2), Vector3.ZERO, 10)
	var copper := mat("copper", Color(0.78, 0.48, 0.25), 0.9, 0.3)
	for i in 6:
		part(body, torus_mesh(0.14, 0.24 - i * 0.015), copper, Vector3(0.5, 0.45 + i * 0.2, 1.2))
	part(body, sphere_mesh(0.2, -1, 14), steel(), Vector3(0.5, 1.85, 1.2))
	var glow := part(body, sphere_mesh(0.14, -1, 12), light_mat(Color(0.5, 0.8, 1.0), 2.0), Vector3(0.5, 1.85, 1.2))
	root.set_meta("glow", glow)
	box(body, Vector3(0.5, 0.25, 0.5), c, Vector3(0.5, 0.18, 0.4))
	box(body, Vector3(0.52, 0.04, 0.52), tm, Vector3(0.5, 0.32, 0.4))

## Approximate height of each structure, used for screen picking.
static func height_of(sprite: String) -> float:
	return {"conyard": 1.4, "power": 1.05, "adv_power": 1.05, "refinery": 1.4, "silo": 0.75, "barracks": 0.6,
		"barracks_dom": 0.8, "factory": 1.4, "radar": 1.4, "pillbox": 0.45, "gun_turret": 0.45, "flame_tower": 0.9, "arc_coil": 2.0}.get(sprite, 0.8)
