class_name Terrain3D
extends Node3D
## 3D battlefield: smooth vertex-coloured height mesh, animated water with shore foam,
## instanced trees, boulders, bridges and ore crystals, all darkened by the fog of war.

const CHUNK := 32
const SUB := 2
const HEIGHT := {"water": -0.42, "shore": -0.07, "sand": 0.0, "grass": 0.02, "dirt": 0.0, "road": -0.01,
	"rock": 0.1, "cliff": 0.8, "bridge": -0.42, "forest": 0.04}
const COLORS := {"grass": Color(0.36, 0.45, 0.22), "dirt": Color(0.43, 0.34, 0.22), "sand": Color(0.74, 0.65, 0.45),
	"water": Color(0.27, 0.27, 0.2), "shore": Color(0.63, 0.57, 0.41), "road": Color(0.38, 0.37, 0.35),
	"rock": Color(0.47, 0.45, 0.42), "cliff": Color(0.37, 0.34, 0.31), "bridge": Color(0.27, 0.27, 0.2),
	"forest": Color(0.22, 0.33, 0.14)}
const WATER_Y := -0.13

var game: Game
var map: MapGrid
var heights := PackedFloat32Array()   # per cell (mesh height)
var colors := PackedColorArray()      # per cell
var terrain_mat: ShaderMaterial
var prop_mat: ShaderMaterial
var water_mat: ShaderMaterial
var ore_mm := {}                      # chunk key -> MultiMeshInstance3D
var crystal_mesh: Mesh
var nugget_mesh: Mesh
var detail_tex: NoiseTexture2D
var color_noise := FastNoiseLite.new()

func setup(g: Game) -> void:
	game = g
	map = g.map
	_cache_cells()
	_make_materials()
	for cy in range(0, map.h, CHUNK):
		for cx in range(0, map.w, CHUNK):
			_build_chunk(cx, cy)
	_build_water()
	_build_props()
	crystal_mesh = _crystal_mesh()
	nugget_mesh = _nugget_mesh()
	for cy in range(0, map.h, CHUNK):
		for cx in range(0, map.w, CHUNK):
			rebuild_ore_chunk(cx / CHUNK, cy / CHUNK)

func _cache_cells() -> void:
	var n := map.w * map.h
	heights.resize(n)
	colors.resize(n)
	color_noise.seed = 77
	color_noise.frequency = 0.08
	for y in map.h:
		for x in map.w:
			var c := Vector2i(x, y)
			var id := map.terrain_id(c)
			heights[map.idx(c)] = HEIGHT.get(id, 0.0)
			var col: Color = COLORS.get(id, Color(0.4, 0.4, 0.4))
			var v := color_noise.get_noise_2d(x, y) * 0.12
			colors[map.idx(c)] = col.lightened(v) if v > 0 else col.darkened(-v)

## Smooth value at a continuous cell coordinate (bilinear between cell centres).
func _sample_h(fx: float, fy: float) -> float:
	var x := fx - 0.5
	var y := fy - 0.5
	var x0 := clampi(floori(x), 0, map.w - 1)
	var y0 := clampi(floori(y), 0, map.h - 1)
	var x1 := mini(x0 + 1, map.w - 1)
	var y1 := mini(y0 + 1, map.h - 1)
	var tx := clampf(x - floor(x), 0.0, 1.0)
	var ty := clampf(y - floor(y), 0.0, 1.0)
	var a := lerpf(heights[y0 * map.w + x0], heights[y0 * map.w + x1], tx)
	var b := lerpf(heights[y1 * map.w + x0], heights[y1 * map.w + x1], tx)
	return lerpf(a, b, ty)

func _sample_c(fx: float, fy: float) -> Color:
	var x := fx - 0.5
	var y := fy - 0.5
	var x0 := clampi(floori(x), 0, map.w - 1)
	var y0 := clampi(floori(y), 0, map.h - 1)
	var x1 := mini(x0 + 1, map.w - 1)
	var y1 := mini(y0 + 1, map.h - 1)
	var tx := clampf(x - floor(x), 0.0, 1.0)
	var ty := clampf(y - floor(y), 0.0, 1.0)
	var a := colors[y0 * map.w + x0].lerp(colors[y0 * map.w + x1], tx)
	var b := colors[y1 * map.w + x0].lerp(colors[y1 * map.w + x1], tx)
	return a.lerp(b, ty)

## Height units stand on (bridge decks count as land).
func ground_height(px: Vector2) -> float:
	var c := MapGrid.to_cell(px)
	if map.in_bounds(c) and map.terrain_id(c) == "bridge":
		return 0.07
	return maxf(_sample_h(px.x / MapGrid.T, px.y / MapGrid.T), WATER_Y - 0.05)

func _make_materials() -> void:
	detail_tex = NoiseTexture2D.new()
	detail_tex.seamless = true
	detail_tex.width = 256
	detail_tex.height = 256
	detail_tex.generate_mipmaps = true
	var dn := FastNoiseLite.new()
	dn.frequency = 0.03
	dn.fractal_octaves = 5
	detail_tex.noise = dn
	var fog_tex: Texture2D = game.fog_texture
	var msize := Vector2(map.w, map.h)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size;
varying vec3 wpos;
float fogb(vec2 p) {
	float f = texture(fog_tex, p / map_size).r;
	return f < 0.51 ? mix(1.0, 0.42, f / 0.51) : mix(0.42, 0.015, (f - 0.51) / 0.49);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d1 = texture(detail, wpos.xz * 0.18).r;
	float d2 = texture(detail, wpos.xz * 0.9).r;
	float d3 = texture(detail, wpos.xz * 3.1).r;
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	vec3 col = base * (0.7 + 0.55 * d1) * (0.84 + 0.32 * d2) * (0.9 + 0.2 * d3);
	ALBEDO = col * fogb(wpos.xz);
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
"""
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = sh
	terrain_mat.set_shader_parameter("fog_tex", fog_tex)
	terrain_mat.set_shader_parameter("detail", detail_tex)
	terrain_mat.set_shader_parameter("map_size", msize)
	var ps := Shader.new()
	ps.code = """
shader_type spatial;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform vec2 map_size;
uniform float metal = 0.0;
uniform float rough = 0.85;
uniform float glow = 0.0;
varying vec3 wpos;
float fogb(vec2 p) {
	float f = texture(fog_tex, p / map_size).r;
	return f < 0.51 ? mix(1.0, 0.42, f / 0.51) : mix(0.42, 0.015, (f - 0.51) / 0.49);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fb = fogb(wpos.xz);
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = base * fb;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = base * glow * fb;
}
"""
	prop_mat = ShaderMaterial.new()
	prop_mat.shader = ps
	prop_mat.set_shader_parameter("fog_tex", fog_tex)
	prop_mat.set_shader_parameter("map_size", msize)

func _build_chunk(cx: int, cy: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := mini(CHUNK, map.w - cx)
	var h := mini(CHUNK, map.h - cy)
	var vw := w * SUB + 1
	var vh := h * SUB + 1
	for vy in vh:
		for vx in vw:
			var fx := cx + float(vx) / SUB
			var fy := cy + float(vy) / SUB
			var hh := _sample_h(fx, fy)
			var col := _sample_c(fx, fy)
			# Darken steep or submerged ground a little for depth.
			if hh < -0.1:
				col = col.darkened(clampf((-hh - 0.1) * 1.2, 0.0, 0.5))
			st.set_color(col)
			st.set_uv(Vector2(fx, fy))
			st.add_vertex(Vector3(fx, hh, fy))
	for vy in vh - 1:
		for vx in vw - 1:
			var i := vy * vw + vx
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + vw)
			st.add_index(i + 1)
			st.add_index(i + vw + 1)
			st.add_index(i + vw)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	# Skirt along map edges so the world doesn't look paper-thin.
	if cx == 0 or cy == 0 or cx + w >= map.w or cy + h >= map.h:
		pass

func _build_water() -> void:
	var has_water := false
	for i in heights.size():
		if heights[i] < WATER_Y:
			has_water = true
			break
	if not has_water:
		return
	var himg := Image.create(map.w, map.h, false, Image.FORMAT_L8)
	for y in map.h:
		for x in map.w:
			var v := clampf((heights[y * map.w + x] + 1.0) * 0.5, 0.0, 1.0)
			himg.set_pixel(x, y, Color(v, v, v))
	var wave := NoiseTexture2D.new()
	wave.seamless = true
	wave.width = 256
	wave.height = 256
	wave.generate_mipmaps = true
	var wn := FastNoiseLite.new()
	wn.frequency = 0.05
	wave.noise = wn
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D height_tex : filter_linear, repeat_disable;
uniform sampler2D wave_noise : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size;
uniform float water_y;
varying vec3 wpos;
float fogb(vec2 p) {
	float f = texture(fog_tex, p / map_size).r;
	return f < 0.51 ? mix(1.0, 0.42, f / 0.51) : mix(0.42, 0.015, (f - 0.51) / 0.49);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.1 + wpos.x * 1.7 + wpos.z * 1.1) * 0.012;
}
void fragment() {
	float h = texture(height_tex, wpos.xz / map_size).r * 2.0 - 1.0;
	float depth = clamp((water_y - h) / 0.3, 0.0, 1.0);
	vec2 uv1 = wpos.xz * 0.22 + vec2(TIME * 0.018, TIME * 0.011);
	vec2 uv2 = wpos.xz * 0.37 - vec2(TIME * 0.014, -TIME * 0.017);
	float n1 = texture(wave_noise, uv1).r;
	float n2 = texture(wave_noise, uv2).r;
	float n = n1 * 0.5 + n2 * 0.5;
	vec3 deep = pow(vec3(0.05, 0.2, 0.33), vec3(2.2));
	vec3 shallow = pow(vec3(0.16, 0.45, 0.5), vec3(2.2));
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, depth));
	float band = 0.5 + 0.5 * sin(TIME * 1.6 - depth * 18.0 + n * 6.0);
	float foam = (1.0 - smoothstep(0.0, 0.32, depth)) * smoothstep(0.45, 0.85, n + band * 0.35);
	col = mix(col, vec3(0.75, 0.82, 0.86), foam * 0.85);
	float fb = fogb(wpos.xz);
	ALBEDO = col * fb;
	NORMAL_MAP = normalize(vec3(0.5 + (n1 - 0.5) * 0.5, 0.5 + (n2 - 0.5) * 0.5, 1.0));
	ROUGHNESS = 0.06 + foam * 0.5;
	SPECULAR = 0.7 * fb;
	METALLIC = 0.05;
	ALPHA = max(mix(0.62, 0.95, depth), 1.0 - fb);
}
"""
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water_mat.set_shader_parameter("fog_tex", game.fog_texture)
	water_mat.set_shader_parameter("height_tex", ImageTexture.create_from_image(himg))
	water_mat.set_shader_parameter("wave_noise", wave)
	water_mat.set_shader_parameter("map_size", Vector2(map.w, map.h))
	water_mat.set_shader_parameter("water_y", WATER_Y)
	var pm := PlaneMesh.new()
	pm.size = Vector2(map.w, map.h)
	pm.subdivide_width = map.w / 2
	pm.subdivide_depth = map.h / 2
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position = Vector3(map.w * 0.5, WATER_Y, map.h * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

# ---------------------------------------------------------------- props

func _merge(parts: Array) -> ArrayMesh:
	# parts: [[mesh, transform, color], ...] -> one vertex-coloured mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var m: Mesh = p[0]
		var arr := m.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var xf: Transform3D = p[1]
		var col: Color = p[2]
		var jitter: float = p[3] if p.size() > 3 else 0.0
		var order := idx if idx.size() > 0 else PackedInt32Array(range(verts.size()))
		for i in order:
			var v := xf * verts[i]
			if jitter > 0.0:
				var hsh := sin(verts[i].x * 12.9898 + verts[i].y * 78.233 + verts[i].z * 37.719) * 43758.5453
				v += xf.basis * (verts[i].normalized() * (fposmod(hsh, 1.0) - 0.5) * jitter)
			st.set_color(col)
			st.set_normal((xf.basis * norms[i]).normalized())
			st.add_vertex(v)
	return st.commit()

func _tree_mesh(conifer: bool) -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.03
	trunk.bottom_radius = 0.05
	trunk.height = 0.3
	trunk.radial_segments = 6
	var parts := [[trunk, Transform3D(Basis(), Vector3(0, 0.15, 0)), Color(0.33, 0.24, 0.15)]]
	if conifer:
		for i in 3:
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.26 - i * 0.06
			c.height = 0.32
			c.radial_segments = 8
			parts.append([c, Transform3D(Basis(), Vector3(0, 0.32 + i * 0.17, 0)), Color(0.13, 0.27, 0.12).lightened(i * 0.06)])
	else:
		var s := SphereMesh.new()
		s.radius = 0.27
		s.height = 0.46
		s.radial_segments = 9
		s.rings = 6
		parts.append([s, Transform3D(Basis(), Vector3(0, 0.48, 0)), Color(0.22, 0.38, 0.14), 0.09])
		var s2 := SphereMesh.new()
		s2.radius = 0.17
		s2.height = 0.3
		s2.radial_segments = 8
		s2.rings = 5
		parts.append([s2, Transform3D(Basis(), Vector3(0.1, 0.66, 0.05)), Color(0.27, 0.44, 0.17), 0.06])
	return _merge(parts)

func _tuft_mesh() -> ArrayMesh:
	var parts := []
	for i in 5:
		var b := BoxMesh.new()
		b.size = Vector3(0.012, 0.11, 0.012)
		var ang := i * TAU / 5.0
		var basis := Basis(Vector3(cos(ang), 0, sin(ang)), 0.35)
		parts.append([b, Transform3D(basis, Vector3(cos(ang) * 0.025, 0.05, sin(ang) * 0.025)), Color(0.32, 0.46, 0.16).lightened(i * 0.04)])
	return _merge(parts)

func _rock_mesh() -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.26
	s.radial_segments = 7
	s.rings = 4
	return _merge([[s, Transform3D(Basis(), Vector3(0, 0.06, 0)), Color(0.5, 0.48, 0.45), 0.12]])

func _crystal_mesh() -> ArrayMesh:
	var parts := []
	for i in 3:
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = 0.05 - i * 0.008
		c.height = 0.2 - i * 0.04
		c.radial_segments = 5
		var b := Basis(Vector3(0, 0, 1), (i - 1) * 0.45)
		parts.append([c, Transform3D(b, Vector3((i - 1) * 0.04, c.height * 0.45, 0)), Color.WHITE])
	return _merge(parts)

func _nugget_mesh() -> ArrayMesh:
	var a := SphereMesh.new()
	a.radius = 0.07
	a.height = 0.09
	a.radial_segments = 6
	a.rings = 4
	var b := SphereMesh.new()
	b.radius = 0.045
	b.height = 0.06
	b.radial_segments = 5
	b.rings = 3
	return _merge([[a, Transform3D(Basis(), Vector3(0, 0.02, 0)), Color.WHITE, 0.05],
		[b, Transform3D(Basis(), Vector3(0.07, 0.015, 0.03)), Color(0.9, 0.9, 0.9), 0.03],
		[b, Transform3D(Basis(), Vector3(-0.05, 0.012, -0.05)), Color(0.85, 0.85, 0.85), 0.03]])

func _bridge_mesh() -> ArrayMesh:
	var deck := BoxMesh.new()
	deck.size = Vector3(1.0, 0.07, 0.96)
	var rail := BoxMesh.new()
	rail.size = Vector3(1.0, 0.08, 0.05)
	var post := BoxMesh.new()
	post.size = Vector3(0.07, 0.6, 0.07)
	return _merge([[deck, Transform3D(Basis(), Vector3(0, 0.035, 0)), Color(0.45, 0.33, 0.21)],
		[rail, Transform3D(Basis(), Vector3(0, 0.13, 0.46)), Color(0.35, 0.26, 0.17)],
		[rail, Transform3D(Basis(), Vector3(0, 0.13, -0.46)), Color(0.35, 0.26, 0.17)],
		[post, Transform3D(Basis(), Vector3(0, -0.25, 0.42)), Color(0.3, 0.24, 0.18)],
		[post, Transform3D(Basis(), Vector3(0, -0.25, -0.42)), Color(0.3, 0.24, 0.18)]])

func _mm_instance(mesh: Mesh, xforms: Array, colors_arr: Array = [], mat: Material = null) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors_arr.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors_arr[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat if mat != null else prop_mat
	add_child(mmi)

func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var con := []
	var broad := []
	var rocks := []
	var bridges := []
	var tufts := []
	var pebbles := []
	for y in map.h:
		for x in map.w:
			var c := Vector2i(x, y)
			var id := map.terrain_id(c)
			if (id == "grass" or id == "forest") and map.ore[map.idx(c)] == 0:
				for i in rng.randi_range(0, 2):
					var s0 := rng.randf_range(0.6, 1.2)
					tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s0, s0 * rng.randf_range(0.7, 1.3), s0)), Vector3(x + rng.randf(), _sample_h(x + 0.5, y + 0.5), y + rng.randf())))
			elif (id == "dirt" or id == "sand" or id == "shore") and rng.randf() < 0.35:
				var s1 := rng.randf_range(0.12, 0.25)
				pebbles.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s1, s1 * 0.6, s1)), Vector3(x + rng.randf(), _sample_h(x + 0.5, y + 0.5), y + rng.randf())))
			match id:
				"forest":
					for i in rng.randi_range(2, 3):
						var p := Vector3(x + rng.randf_range(0.15, 0.85), 0.02, y + rng.randf_range(0.15, 0.85))
						var s := rng.randf_range(0.8, 1.25)
						var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.2), s)), p)
						if rng.randf() < 0.45:
							con.append(xf)
						else:
							broad.append(xf)
				"rock":
					if rng.randf() < 0.7:
						var p := Vector3(x + rng.randf_range(0.2, 0.8), 0.08, y + rng.randf_range(0.2, 0.8))
						var s := rng.randf_range(0.5, 1.1)
						rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * 0.8, s)), p))
				"cliff":
					for i in 2:
						var p := Vector3(x + rng.randf_range(0.1, 0.9), 0.55, y + rng.randf_range(0.1, 0.9))
						var s := rng.randf_range(1.3, 2.3)
						rocks.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.6), s)), p))
				"bridge":
					var horiz := _is_land_or_bridge(c + Vector2i(1, 0)) or _is_land_or_bridge(c + Vector2i(-1, 0))
					var vert := _is_land_or_bridge(c + Vector2i(0, 1)) or _is_land_or_bridge(c + Vector2i(0, -1))
					var rot := 0.0 if horiz and not vert else PI * 0.5
					if horiz and vert:
						rot = 0.0 if abs(x - map.w / 2) > abs(y - map.h / 2) else PI * 0.5
					bridges.append(Transform3D(Basis(Vector3.UP, rot), Vector3(x + 0.5, 0.0, y + 0.5)))
	_mm_instance(_tuft_mesh(), tufts)
	_mm_instance(_rock_mesh(), pebbles)
	_mm_instance(_tree_mesh(true), con)
	_mm_instance(_tree_mesh(false), broad)
	_mm_instance(_rock_mesh(), rocks)
	_mm_instance(_bridge_mesh(), bridges)

func _is_land_or_bridge(c: Vector2i) -> bool:
	if not map.in_bounds(c):
		return false
	var id := map.terrain_id(c)
	return id != "water"

# ---------------------------------------------------------------- ore

func mark_ore_dirty(c: Vector2i) -> void:
	var key := Vector2i(c.x / CHUNK, c.y / CHUNK)
	set_meta("dirty_%d_%d" % [key.x, key.y], true)

func process_dirty() -> void:
	for k in get_meta_list():
		if String(k).begins_with("dirty_"):
			var parts := String(k).split("_")
			remove_meta(k)
			rebuild_ore_chunk(int(parts[1]), int(parts[2]))

func rebuild_ore_chunk(kx: int, ky: int) -> void:
	var key := Vector2i(kx, ky)
	if ore_mm.has(key):
		for n in ore_mm[key]:
			n.queue_free()
		ore_mm.erase(key)
	var lists := {1: [[], []], 2: [[], []]}
	for y in range(ky * CHUNK, mini((ky + 1) * CHUNK, map.h)):
		for x in range(kx * CHUNK, mini((kx + 1) * CHUNK, map.w)):
			var c := Vector2i(x, y)
			var st := map.ore_stage(c)
			if st <= 0:
				continue
			var kind := map.ore_kind[map.idx(c)]
			var rng := RandomNumberGenerator.new()
			rng.seed = x * 92821 + y * 68917
			var col := Color(0.98, 0.74, 0.25) if kind == 1 else Color(0.35, 0.78, 1.0)
			var gh := _sample_h(x + 0.5, y + 0.5) - 0.005
			for i in st * 3 + 2:
				var p := Vector3(x + rng.randf_range(0.05, 0.95), gh, y + rng.randf_range(0.05, 0.95))
				var sc := rng.randf_range(0.7, 1.3) * (0.75 + st * 0.12)
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				if kind == 2:
					basis = basis.rotated(Vector3(1, 0, 0), rng.randf_range(-0.3, 0.3))
				lists[kind][0].append(Transform3D(basis.scaled(Vector3(sc, sc * rng.randf_range(0.7, 1.2), sc)), p))
				lists[kind][1].append(col.lightened(rng.randf_range(-0.18, 0.15)))
	var nodes := []
	for kind in [1, 2]:
		var xforms: Array = lists[kind][0]
		if xforms.is_empty():
			continue
		var om := ShaderMaterial.new()
		om.shader = prop_mat.shader
		om.set_shader_parameter("fog_tex", game.fog_texture)
		om.set_shader_parameter("map_size", Vector2(map.w, map.h))
		om.set_shader_parameter("metal", 0.75 if kind == 1 else 0.3)
		om.set_shader_parameter("rough", 0.32 if kind == 1 else 0.12)
		om.set_shader_parameter("glow", 0.12 if kind == 1 else 0.45)
		var before := get_child_count()
		_mm_instance(nugget_mesh if kind == 1 else crystal_mesh, xforms, lists[kind][1], om)
		nodes.append(get_child(before))
	if not nodes.is_empty():
		ore_mm[key] = nodes
