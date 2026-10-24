extends Node3D
## High-resolution model renderer for design previews and the unit catalogue sheet.
##   godot --path . res://tools/showcase.tscn -- <set> <out.png> [px_per_unit]
## Sets are defined in tools/art/catalog.gd. Each entry renders into its own tile with the
## same lighting as the sprite baker, team-coloured, and captioned by the caller (Python).

const K := preload("res://tools/art/kit.gd")
const CAT := preload("res://tools/art/catalog.gd")

var vp: SubViewport
var cam: Camera3D
var holder: Node3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var set_name: String = args[0] if args.size() > 0 else "infantry"
	var out: String = args[1] if args.size() > 1 else "/tmp/showcase.png"
	var ppu: float = float(args[2]) if args.size() > 2 else 400.0
	K.toon_mode = args.has("--toon")
	_setup()
	await get_tree().process_frame
	var items: Array = CAT.showcase_set(set_name)
	var tiles := []
	var meta := []
	for it in items:
		var node: Node3D = it.build.call()
		var tile_w: int = int(it.get("w", 1.0) * ppu)
		var tile_h: int = int(it.get("h", 1.0) * ppu)
		vp.size = Vector2i(tile_w * 2, tile_h * 2)
		cam.size = float(tile_h) / ppu
		var b := cam.transform.basis
		var focus: Vector3 = it.get("focus", Vector3(0, 0.15, 0))
		cam.position = focus + b.z * 25.0
		holder.add_child(node)
		if it.get("fit", false):
			_fit(node, float(tile_w) / float(tile_h), float(it.get("margin", 1.12)))
		_team(node, it.get("team", Color(0.25, 0.48, 0.85)))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(tile_w, tile_h, Image.INTERPOLATE_LANCZOS)
		tiles.append(img)
		meta.append({"name": it.get("label", ""), "w": tile_w, "h": tile_h})
		holder.remove_child(node)
		node.queue_free()
	var cols: int = mini(int(CAT.showcase_cols(set_name)), tiles.size())
	var tw := 0
	var th := 0
	for t in tiles:
		tw = maxi(tw, t.get_width())
		th = maxi(th, t.get_height())
	var rows := int(ceil(float(tiles.size()) / cols))
	var sheet := Image.create(cols * tw, rows * th, false, Image.FORMAT_RGBA8)
	for i in tiles.size():
		var t: Image = tiles[i]
		sheet.blit_rect(t, Rect2i(Vector2i.ZERO, t.get_size()), Vector2i((i % cols) * tw + (tw - t.get_width()) / 2, (i / cols) * th))
	if out.ends_with("/"):
		DirAccess.make_dir_recursive_absolute(out)
		for i in tiles.size():
			tiles[i].save_png(out + String(meta[i].name) + ".png")
		print("saved ", tiles.size(), " tiles to ", out)
		get_tree().quit()
		return
	sheet.save_png(out)
	var f := FileAccess.open(out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cols": cols, "tw": tw, "th": th, "items": meta}))
	print("saved ", out)
	get_tree().quit()

## Frames the camera around the node's projected bounding box.
func _fit(node: Node3D, aspect: float, margin: float) -> void:
	var b := cam.transform.basis
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var bb: AABB = mi.mesh.get_aabb()
		var xf: Transform3D = mi.global_transform
		for k in 8:
			var c := xf * bb.get_endpoint(k)
			var q := Vector2(c.dot(b.x), c.dot(b.y))
			lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
			hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var size := hi - lo
	cam.size = maxf(size.y, size.x / aspect) * margin
	var mid := (lo + hi) * 0.5
	cam.position = b.x * mid.x + b.y * mid.y + b.z * 25.0

## Team parts are painted with the player colour directly (the game uses a mask instead).
func _team(node: Node, col: Color) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		if bool(mi.get_meta("team", false)) and mi.material_override is ShaderMaterial:
			var m: ShaderMaterial = mi.material_override.duplicate()
			var base: Color = m.get_shader_parameter("base_color")
			var lum := base.get_luminance() / 0.62
			m.set_shader_parameter("base_color", Color(col.r * 0.82 * lum, col.g * 0.82 * lum, col.b * 0.85 * lum))
			mi.material_override = m

func _setup() -> void:
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.66, 0.78)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.12
	env.ssao_intensity = 1.4
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	sun.shadow_bias = 0.005
	sun.shadow_normal_bias = 0.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 30.0
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.45, -0.62, 0.62), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.62, 0.72, 0.95)
	fill.light_energy = 0.42
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
