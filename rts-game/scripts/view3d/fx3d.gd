class_name Fx3D
extends Node3D
## 3D combat effects: fireball explosions with debris and light, muzzle flashes,
## tracers, electric arcs, flame bursts and scorch marks.

static var _soft_tex: GradientTexture2D
static var _mat_cache := {}

var kind: String = ""
var t: float = 0.0
var dur: float = 1.0
var light: OmniLight3D
var light_e: float = 0.0
var mesh_i: MeshInstance3D
var opts: Dictionary = {}
var arc: ImmediateMesh

static func soft_tex() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.65))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(1.0, 0.5)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex

static func particle_mat(additive: bool) -> StandardMaterial3D:
	var k := "add" if additive else "mix"
	if _mat_cache.has(k):
		return _mat_cache[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex()
	m.disable_receive_shadows = true
	_mat_cache[k] = m
	return m

static func make_particles(parent: Node3D, amount: int, life: float, additive: bool, ramp: Gradient, size: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = particle_mat(additive)
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curve
	parent.add_child(p)
	return p

static func ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, cols[0])
	g.set_color(1, cols[cols.size() - 1])
	for i in range(1, cols.size() - 1):
		g.add_point(float(i) / (cols.size() - 1), cols[i])
	return g

func setup(k: String, p: Vector3, o: Dictionary) -> void:
	kind = k
	position = p
	opts = o
	match k:
		"explosion", "explosion_big", "explosion_small":
			var big: float = {"explosion": 1.0, "explosion_big": 1.9, "explosion_small": 0.5}[k]
			dur = 2.4
			var fire := make_particles(self, int(18 * big) + 6, 0.55, true, ramp([Color(1, 0.78, 0.4, 0.85), Color(0.95, 0.45, 0.12, 0.75), Color(0.5, 0.12, 0.04, 0.0)]), 0.38 * big, true)
			fire.direction = Vector3.UP
			fire.spread = 80.0
			fire.initial_velocity_min = 0.6 * big
			fire.initial_velocity_max = 1.8 * big
			fire.gravity = Vector3(0, 0.6, 0)
			fire.damping_min = 2.0
			fire.damping_max = 3.0
			fire.emitting = true
			var smoke := make_particles(self, int(10 * big) + 4, 1.9, false, ramp([Color(0.2, 0.18, 0.16, 0.0), Color(0.22, 0.2, 0.18, 0.7), Color(0.3, 0.3, 0.3, 0.0)]), 0.7 * big, true)
			smoke.direction = Vector3.UP
			smoke.spread = 40.0
			smoke.initial_velocity_min = 0.3
			smoke.initial_velocity_max = 0.8 * big
			smoke.gravity = Vector3(0.1, 0.35, 0)
			smoke.emitting = true
			if big >= 1.0:
				var deb := CPUParticles3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.05, 0.05, 0.05)
				bm.material = Models.metal_dark()
				deb.mesh = bm
				deb.amount = int(8 * big)
				deb.lifetime = 1.2
				deb.one_shot = true
				deb.explosiveness = 1.0
				deb.direction = Vector3.UP
				deb.spread = 60.0
				deb.initial_velocity_min = 1.5
				deb.initial_velocity_max = 3.0 * big
				deb.gravity = Vector3(0, -6, 0)
				deb.angular_velocity_min = -400
				deb.angular_velocity_max = 400
				add_child(deb)
				deb.emitting = true
			light = OmniLight3D.new()
			light.light_color = Color(1, 0.6, 0.25)
			light_e = 2.6 * big
			light.light_energy = light_e
			light.omni_range = 2.5 * big + 0.5
			light.position = Vector3(0, 0.4, 0)
			add_child(light)
		"muzzle":
			dur = 0.08
			mesh_i = MeshInstance3D.new()
			mesh_i.mesh = Models.sphere_mesh(0.06 if opts.get("big", false) else 0.035, -1, 6)
			mesh_i.material_override = Models.light_mat(Color(1, 0.8, 0.35), 8.0)
			mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh_i)
			if opts.get("big", false):
				light = OmniLight3D.new()
				light.light_color = Color(1, 0.75, 0.4)
				light_e = 2.0
				light.light_energy = light_e
				light.omni_range = 1.6
				add_child(light)
		"tracer":
			dur = 0.07
			var to: Vector3 = opts.get("to", p)
			var d := to - p
			mesh_i = MeshInstance3D.new()
			mesh_i.mesh = Models.box_mesh(Vector3(1, 0.012, 0.012))
			mesh_i.material_override = Models.light_mat(Color(1, 0.9, 0.5), 6.0)
			mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh_i)
			if d.length() > 0.01:
				var x := d.normalized()
				var up := Vector3.UP if absf(x.y) < 0.99 else Vector3.FORWARD
				var z := x.cross(up).normalized()
				var y := z.cross(x)
				mesh_i.transform = Transform3D(Basis(x * d.length() * 0.7, y, z), d * 0.6)
		"zap":
			dur = 0.28
			arc = ImmediateMesh.new()
			mesh_i = MeshInstance3D.new()
			mesh_i.mesh = arc
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.7, 0.9, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.5, 0.8, 1.0)
			m.emission_energy_multiplier = 6.0
			mesh_i.material_override = m
			mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh_i)
			light = OmniLight3D.new()
			light.light_color = Color(0.5, 0.75, 1.0)
			light_e = 4.0
			light.light_energy = light_e
			light.omni_range = 3.0
			add_child(light)
		"spark":
			dur = 0.6
			var sp := make_particles(self, 10, 0.4, true, ramp([Color(0.8, 0.95, 1, 1), Color(0.3, 0.6, 1, 0)]), 0.15, true)
			sp.spread = 180.0
			sp.initial_velocity_min = 1.0
			sp.initial_velocity_max = 2.5
			sp.emitting = true
		"flame_burst":
			dur = 1.2
			var fl := make_particles(self, 14, 0.5, true, ramp([Color(1, 0.9, 0.5, 1), Color(1, 0.4, 0.05, 0.8), Color(0.3, 0.1, 0.05, 0)]), 0.4, true)
			fl.spread = 70.0
			fl.direction = Vector3.UP
			fl.initial_velocity_min = 0.4
			fl.initial_velocity_max = 1.2
			fl.emitting = true
			light = OmniLight3D.new()
			light.light_color = Color(1, 0.5, 0.15)
			light_e = 2.0
			light.light_energy = light_e
			light.omni_range = 2.0
			add_child(light)
		"crater":
			dur = 30.0
			mesh_i = MeshInstance3D.new()
			mesh_i.mesh = Models.cyl_mesh(1.0, 1.0, 0.01, 14)
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color(0.06, 0.05, 0.04, 0.7)
			cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cm.roughness = 1.0
			mesh_i.material_override = cm
			var r: float = opts.get("r", 0.4)
			mesh_i.scale = Vector3(r, 1, r)
			mesh_i.position.y = 0.012
			mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh_i)
		_:
			dur = 0.01

func _process(delta: float) -> void:
	t += delta
	if t >= dur:
		queue_free()
		return
	var f := t / dur
	if light != null:
		light.light_energy = light_e * maxf(0.0, 1.0 - t / minf(dur, 0.35))
	if kind == "zap" and arc != null:
		arc.clear_surfaces()
		var to: Vector3 = opts.get("to", position) - position
		var side := to.cross(Vector3.UP).normalized()
		arc.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		arc.surface_add_vertex(Vector3.ZERO)
		for i in range(1, 9):
			var p := to * (float(i) / 9.0) + side * randf_range(-0.15, 0.15) + Vector3(0, randf_range(-0.1, 0.1), 0)
			arc.surface_add_vertex(p)
		arc.surface_add_vertex(to)
		arc.surface_end()
		mesh_i.transparency = f
	if kind == "crater" and f > 0.75:
		mesh_i.transparency = (f - 0.75) / 0.25
