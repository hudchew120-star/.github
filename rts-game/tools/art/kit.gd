class_name ArtKit
extends RefCounted
## Mesh building kit for the sprite baker: chamfered/convex solids from planes, lathe
## (revolved) shapes, extruded profiles, tubes, plus a hand-painted look material.
## These meshes are only used offline to pre-render sprites; the game never loads them.

static var _mats := {}
static var shader: Shader
static var mask_mode: bool = false     # true while rendering team-colour masks

const PAINT := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx, cull_disabled;
uniform vec3 base_color : source_color = vec3(0.6);
uniform float metal = 0.0;
uniform float rough = 0.75;
uniform float panel = 0.0;
uniform float panel_dark = 0.32;
uniform float grime = 0.35;
uniform float stripes = 0.0;
uniform float tread = 0.0;
uniform float corrugate = 0.0;
uniform float noise_amt = 0.22;
uniform float burn = 0.0;
uniform float emit = 0.0;
uniform float cut_y = 99.0;
varying vec3 lpos;
varying vec3 wpos;
varying vec3 lnorm;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { lpos = VERTEX; lnorm = NORMAL; wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	if (wpos.y > cut_y) { discard; }
	vec3 c = base_color;
	float n = vnoise(wpos * 9.0) * 0.6 + vnoise(wpos * 31.0) * 0.4;
	c *= 1.0 - noise_amt * 0.5 + noise_amt * n;
	c *= mix(1.0, 0.72, grime * (1.0 - smoothstep(0.0, 0.3, wpos.y)));
	vec3 an = abs(lnorm);
	vec2 uv = an.y > 0.6 ? lpos.xz : (an.x > 0.6 ? lpos.zy : lpos.xy);
	if (panel > 0.0) {
		vec2 g = abs(fract(uv * panel) - 0.5);
		float line = smoothstep(0.455, 0.49, max(g.x, g.y));
		c *= 1.0 - line * panel_dark;
		c *= 1.0 + (hash(floor(vec3(uv * panel, 3.0))) - 0.5) * 0.08;
	}
	if (stripes > 0.0) {
		float s = step(0.5, fract((uv.x + uv.y) * stripes));
		c = mix(c, vec3(0.06), s);
	}
	if (tread > 0.0) {
		float t = step(0.55, fract(lpos.x * tread));
		c *= 1.0 - t * 0.45;
	}
	if (corrugate > 0.0) {
		c *= 0.86 + 0.14 * sin(uv.x * corrugate);
	}
	if (burn > 0.0) {
		float b = smoothstep(0.55, 0.75, vnoise(wpos * 4.0) * 0.7 + vnoise(wpos * 13.0) * 0.3);
		c = mix(c, c * 0.18, b * burn);
	}
	ALBEDO = c;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.3;
	EMISSION = base_color * emit;
}
"""

const MASK := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float value = 0.0;
uniform float cut_y = 99.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() { if (wpos.y > cut_y) { discard; } ALBEDO = vec3(value); }
"""

static func _shader() -> Shader:
	if shader == null:
		shader = Shader.new()
		shader.code = PAINT
	return shader

static var _mask_shader: Shader
static func mask_material(team: bool) -> ShaderMaterial:
	if _mask_shader == null:
		_mask_shader = Shader.new()
		_mask_shader.code = MASK
	var k := "mask_%s" % team
	if not _mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _mask_shader
		m.set_shader_parameter("value", 1.0 if team else 0.0)
		_mats[k] = m
	return _mats[k]

## Painted material. Extra params: panel, grime, stripes, tread, corrugate, noise_amt, emit.
static func paint(col: Color, metal: float = 0.0, rough: float = 0.75, extra: Dictionary = {}) -> ShaderMaterial:
	var k := "%s_%.2f_%.2f_%s" % [col.to_html(), metal, rough, str(extra)]
	if _mats.has(k):
		return _mats[k]
	var m := ShaderMaterial.new()
	m.shader = _shader()
	m.set_shader_parameter("base_color", col)
	m.set_shader_parameter("metal", metal * 0.35)   # no sky to reflect while baking, so keep metals readable
	m.set_shader_parameter("rough", rough)
	for e in extra:
		m.set_shader_parameter(e, extra[e])
	_mats[k] = m
	return m

# ---------------------------------------------------------------- mesh generators

static func convex(planes: Array) -> ArrayMesh:
	var raw := Geometry3D.compute_convex_mesh_points(planes)
	var pts: Array = []
	for p in raw:
		var dup := false
		for q in pts:
			if q.distance_to(p) < 0.0005:
				dup = true
				break
		if not dup:
			pts.append(p)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pl in planes:
		var face: Array = []
		for p in pts:
			if absf(pl.distance_to(p)) < 0.001:
				face.append(p)
		if face.size() < 3:
			continue
		var c := Vector3.ZERO
		for p in face:
			c += p
		c /= face.size()
		var n: Vector3 = pl.normal
		var u := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := n.cross(u)
		face.sort_custom(func(a, b): return atan2((a - c).dot(v), (a - c).dot(u)) < atan2((b - c).dot(v), (b - c).dot(u)))
		for i in range(1, face.size() - 1):
			var a: Vector3 = face[0]
			var b: Vector3 = face[i]
			var d: Vector3 = face[i + 1]
			if (b - a).cross(d - a).dot(n) > 0.0:
				var t := b
				b = d
				d = t
			for p in [a, b, d]:
				st.set_normal(n)
				st.add_vertex(p)
	return st.commit()

static func plane_at(n: Vector3, p: Vector3) -> Plane:
	return Plane(n.normalized(), p)

## Box (centred on origin) with chamfered edges and corners.
static func bevel_box(size: Vector3, b: float) -> ArrayMesh:
	var h := size * 0.5
	b = minf(b, minf(h.x, minf(h.y, h.z)) * 0.9)
	var planes := []
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var he := [h.x, h.y, h.z]
	for i in 3:
		planes.append(plane_at(axes[i], axes[i] * he[i]))
		planes.append(plane_at(-axes[i], -axes[i] * he[i]))
	for i in 3:
		for j in range(i + 1, 3):
			for si in [-1.0, 1.0]:
				for sj in [-1.0, 1.0]:
					var n: Vector3 = axes[i] * si + axes[j] * sj
					var p: Vector3 = axes[i] * si * he[i] + axes[j] * sj * (he[j] - b)
					planes.append(plane_at(n, p))
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var n := Vector3(sx, sy, sz)
				planes.append(plane_at(n, Vector3(sx * h.x, sy * h.y, sz * (h.z - b * 1.5))))
	return convex(planes)

## Revolved shape around Y. profile: Array[Vector2(radius, y)], bottom to top.
static func lathe(profile: Array, seg: int = 20, smooth: bool = true, cap_top: bool = true, cap_bottom: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n2 := []
	for i in profile.size():
		var a: Vector2 = profile[maxi(i - 1, 0)]
		var b: Vector2 = profile[mini(i + 1, profile.size() - 1)]
		var t := (b - a).normalized()
		n2.append(Vector2(t.y, -t.x))
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		for i in profile.size() - 1:
			var p0: Vector2 = profile[i]
			var p1: Vector2 = profile[i + 1]
			var q := [Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x), Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x),
				Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x), Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)]
			var nn := []
			if smooth:
				for k in [[i, a0], [i, a1], [i + 1, a1], [i + 1, a0]]:
					var nv: Vector2 = n2[k[0]]
					nn.append(Vector3(cos(k[1]) * nv.x, nv.y, sin(k[1]) * nv.x).normalized())
			else:
				var fn: Vector3 = (q[1] - q[0]).cross(q[3] - q[0]).normalized()
				if fn.dot(q[0] - Vector3(0, q[0].y, 0)) < 0:
					fn = -fn
				nn = [fn, fn, fn, fn]
			for idx in [0, 2, 1, 0, 3, 2]:
				st.set_normal(nn[idx])
				st.add_vertex(q[idx])
	if cap_top and profile[-1].x > 0.0001:
		_cap(st, profile[-1], seg, 1.0)
	if cap_bottom and profile[0].x > 0.0001:
		_cap(st, profile[0], seg, -1.0)
	return st.commit()

static func _cap(st: SurfaceTool, p: Vector2, seg: int, ny: float) -> void:
	for s in seg:
		var a0 := TAU * s / seg
		var a1 := TAU * (s + 1) / seg
		for v in [Vector3(0, p.y, 0), Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x), Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)]:
			st.set_normal(Vector3(0, ny, 0))
			st.add_vertex(v)

static func cylinder(r: float, h: float, seg: int = 16, smooth: bool = true) -> ArrayMesh:
	return lathe([Vector2(r, -h * 0.5), Vector2(r, h * 0.5)], seg, smooth)

## Polygon in the XY plane extruded along Z (centred).
static func extrude(poly: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_polygon(poly)
	var hz := depth * 0.5
	for k in range(0, tri.size(), 3):
		for side in [1.0, -1.0]:
			var ids := [tri[k], tri[k + 1], tri[k + 2]]
			for idx in ids:
				st.set_normal(Vector3(0, 0, side))
				st.add_vertex(Vector3(poly[idx].x, poly[idx].y, hz * side))
	var centroid := Vector2.ZERO
	for q in poly:
		centroid += q
	centroid /= poly.size()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var e := b - a
		var n2 := Vector2(e.y, -e.x).normalized()
		if ((a + b) * 0.5 - centroid).dot(n2) < 0.0:
			n2 = -n2
		var n := Vector3(n2.x, n2.y, 0)
		for v in [Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, -hz)]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()

static func stadium(x0: float, x1: float, y0: float, y1: float, seg: int = 8) -> PackedVector2Array:
	var r := (y1 - y0) * 0.5
	var cy := (y0 + y1) * 0.5
	var pts := PackedVector2Array()
	for i in seg + 1:
		var a := -PI * 0.5 + PI * i / seg
		pts.append(Vector2(x1 - r + cos(a) * r, cy + sin(a) * r))
	for i in seg + 1:
		var a := PI * 0.5 + PI * i / seg
		pts.append(Vector2(x0 + r + cos(a) * r, cy + sin(a) * r))
	return pts

# ---------------------------------------------------------------- scene helpers

static func add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, team: bool = false, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = sc
	mi.set_meta("team", team)
	parent.add_child(mi)
	return mi

static func tube(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material, seg: int = 8) -> MeshInstance3D:
	var d := b - a
	var mi := MeshInstance3D.new()
	mi.mesh = cylinder(r, 1.0, seg)
	mi.material_override = mat
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * d.length(), z), a + d * 0.5)
	mi.set_meta("team", false)
	parent.add_child(mi)
	return mi

static func pivot(parent: Node3D, pos: Vector3, name: String = "pivot") -> Node3D:
	var p := Node3D.new()
	p.name = name
	p.position = pos
	parent.add_child(p)
	return p
