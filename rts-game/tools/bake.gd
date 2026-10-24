extends Node3D
## Offline sprite baker. Renders the detailed models in tools/art from the game's
## isometric angle (2:1 tiles, 64x32 px per cell) into supersampled sprite sheets with
## baked ground shadows and team-colour masks. Run:
##   godot --path . res://tools/bake.tscn -- [filter]
## then: python3 tools/finalize_sprites.py

const SS := 3
const R := 2               # art resolution multiplier: cells are 128x64 px
const S := 45.254834 * R  # pixels per world unit (cell diagonal = 64*R px)
const K := preload("res://tools/art/kit.gd")
const M := preload("res://tools/art/hd_models.gd")
const SPECS := preload("res://tools/bake_specs.gd")

var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var ground: MeshInstance3D
var sun: DirectionalLight3D
var out_dir: String
var shadow_mat: ShaderMaterial

func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://tools/_bake_out")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_setup()
	var args := OS.get_cmdline_user_args()
	# Filters: comma-separated substrings; add "--resume" to skip sheets already in _bake_out.
	var filters: PackedStringArray = (args[0] if args.size() > 0 else "").split(",", false)
	var resume := args.has("--resume")
	K.toon_mode = args.has("--toon")     # hand-drawn look: cel shading (ink lines are added by finalize_sprites.py)
	await get_tree().process_frame
	var specs: Array = SPECS.all()
	var n := 0
	for spec in specs:
		if filters.size() > 0 and not Array(filters).any(func(f): return String(spec.name).contains(f)):
			continue
		if resume and FileAccess.file_exists(out_dir + "/" + spec.name + ".json"):
			continue
		var t0 := Time.get_ticks_msec()
		await bake_sheet(spec)
		n += 1
		print("baked %s (%d ms)" % [spec.name, Time.get_ticks_msec() - t0])
	print("done: %d sheets" % n)
	get_tree().quit()

func _setup() -> void:
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.78)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.18
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssao_detail = 0.6
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.62
	sun.shadow_bias = 0.01
	sun.shadow_normal_bias = 0.6
	sun.shadow_blur = 0.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.45, -0.62, 0.62), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.72, 0.95)
	fill.light_energy = 0.38
	vp.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(-0.5, -0.4, -0.6), Vector3.UP)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.05
	cam.far = 60.0
	cam.rotation_degrees = Vector3(-30, 45, 0)
	vp.add_child(cam)
	cam.current = true
	holder = Node3D.new()
	vp.add_child(holder)
	ground = MeshInstance3D.new()   # unused placeholder (shadows are a separate pass)
	ground.visible = false
	vp.add_child(ground)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
uniform vec3 light_dir;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w = w - light_dir * (w.y / light_dir.y);
	w.y = 0.0;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() { ALBEDO = vec3(0.0); }"""
	shadow_mat = ShaderMaterial.new()
	shadow_mat.shader = sh
	shadow_mat.set_shader_parameter("light_dir", Vector3(0.45, -0.62, 0.62).normalized())

func _frame_camera(fw: int, fh: int, anchor: Vector2) -> void:
	vp.size = Vector2i(fw * SS, fh * SS)
	cam.size = float(fh) / S
	var b := cam.transform.basis
	var center := -b.x * ((anchor.x - fw * 0.5) / S) + b.y * ((anchor.y - fh * 0.5) / S)
	cam.position = center + b.z * 25.0

func _capture() -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func _set_mask(node: Node, on: bool) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if on:
			mi.set_meta("orig_mat", mi.material_override)
			var m: ShaderMaterial = K.mask_material(bool(mi.get_meta("team", false)))
			mi.material_override = m
		elif mi.has_meta("orig_mat"):
			mi.material_override = mi.get_meta("orig_mat")

func _set_shadow(node: Node, on: bool) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if on:
			mi.set_meta("orig_mat", mi.material_override)
			mi.material_override = shadow_mat
		elif mi.has_meta("orig_mat"):
			mi.material_override = mi.get_meta("orig_mat")

func _set_cut(node: Node, cut: float) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = mi.material_override
		if m != null:
			# Materials are shared, so clone before changing per-frame parameters.
			if not mi.has_meta("own_mat"):
				mi.material_override = m.duplicate()
				mi.set_meta("own_mat", true)
			mi.material_override.set_shader_parameter("cut_y", cut)

func _set_burn(node: Node, burn: float) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = mi.material_override
		if m != null and burn > 0.0:
			if not mi.has_meta("own_mat"):
				mi.material_override = m.duplicate()
				mi.set_meta("own_mat", true)
			mi.material_override.set_shader_parameter("burn", burn)
			mi.material_override.set_shader_parameter("grime", 0.8)

## spec: {name, fw, fh, anchor, count, build: Callable(i)->Node3D, mask, shadow, scale, cut, burn, extra}
## Frames are laid out row-major in a grid (cols chosen so sheets stay under the GPU size limit).
func bake_sheet(spec: Dictionary) -> void:
	var fw: int = spec.fw
	var fh: int = spec.fh
	var count: int = spec.count
	var cols: int = clampi(5400 / fw, 1, count)
	var rows: int = int(ceil(float(count) / cols))
	var want_mask: bool = spec.get("mask", true)
	var want_shadow: bool = spec.get("shadow", true)
	_frame_camera(fw, fh, spec.anchor)
	var sheet := Image.create(cols * fw * SS, rows * fh * SS, false, Image.FORMAT_RGBA8)
	var msheet: Image = Image.create(cols * fw * SS, rows * fh * SS, false, Image.FORMAT_RGBA8) if want_mask else null
	var ssheet: Image = Image.create(cols * fw * SS, rows * fh * SS, false, Image.FORMAT_RGBA8) if want_shadow else null
	for i in count:
		var dst := Vector2i((i % cols) * fw * SS, (i / cols) * fh * SS)
		var node: Node3D = spec.build.call(i)
		node.scale *= float(spec.get("scale", 1.0))
		holder.add_child(node)
		if spec.has("cut"):
			_set_cut(node, spec.cut.call(i))
		if spec.has("burn"):
			_set_burn(node, spec.burn.call(i))
		var img := await _capture()
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), dst)
		if want_mask:
			_set_mask(node, true)
			var mimg := await _capture()
			msheet.blit_rect(mimg, Rect2i(Vector2i.ZERO, mimg.get_size()), dst)
			_set_mask(node, false)
		if want_shadow:
			_set_shadow(node, true)
			var simg := await _capture()
			ssheet.blit_rect(simg, Rect2i(Vector2i.ZERO, simg.get_size()), dst)
			_set_shadow(node, false)
		holder.remove_child(node)
		node.queue_free()
	sheet.save_png(out_dir + "/" + spec.name + ".png")
	if want_mask:
		msheet.save_png(out_dir + "/" + spec.name + "_mask.png")
	if want_shadow:
		ssheet.save_png(out_dir + "/" + spec.name + "_shadow.png")
	var meta := {"res": R, "fw": fw, "fh": fh, "ax": spec.anchor.x, "ay": spec.anchor.y, "cols": cols, "rows": rows, "count": count,
		"ss": SS, "mask": want_mask, "shadow": want_shadow, "separate_shadow": spec.get("separate_shadow", false), "toon": K.toon_mode, "extra": spec.get("extra", {})}
	var f := FileAccess.open(out_dir + "/" + spec.name + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
