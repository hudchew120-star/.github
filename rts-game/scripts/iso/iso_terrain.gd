class_name IsoTerrain
extends Node2D
## Painted isometric ground: a splat shader blends seamless hand-painted materials per
## cell with noisy, height-aware transitions and animated water with shore foam.
## Also draws ore clusters and scatters decorative trees, bushes, rocks and props.

const LAYERS := ["grass", "grass_dry", "dirt", "sand", "shore", "road", "rock", "cliff", "bridge", "forest", "waterbed"]
const TERRAIN_LAYER := {"grass": 0, "dirt": 2, "sand": 3, "water": 10, "shore": 4, "road": 5, "rock": 6, "cliff": 7, "bridge": 8, "forest": 9}
const ORE_CHUNK := 16

var game: Game
var map: MapGrid
var ground: Polygon2D
var ore_layer: Node2D
var ore_chunks := {}
var ore_sheet: SpriteLib.Sheet
var decor_by_cell := {}          # cell -> Array[Sprite2D]
var entity_layer: Node2D

const SHADER := """
shader_type canvas_item;
uniform sampler2D cell_tex : filter_nearest;
uniform sampler2DArray mats : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size;
uniform float tex_cells = 8.0;
varying vec2 cp;

float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }

vec3 mat(float m, vec2 uv, vec2 cpos) {
	if (m < 0.5) {
		float dry = smoothstep(0.42, 0.68, texture(noise_tex, cpos * 0.045 + 0.17).r);
		vec3 a = texture(mats, vec3(uv, 0.0)).rgb;
		vec3 b = texture(mats, vec3(uv * 1.07 + 0.31, 1.0)).rgb;
		return mix(a, b, dry * 0.85);
	}
	return texture(mats, vec3(uv, m)).rgb;
}

float layer_at(vec2 c) {
	ivec2 ic = clamp(ivec2(c), ivec2(0), ivec2(map_size) - 1);
	return floor(texelFetch(cell_tex, ic, 0).r * 255.0 + 0.5);
}

void vertex() {
	cp = vec2(VERTEX.x / 64.0 + VERTEX.y / 32.0, VERTEX.y / 32.0 - VERTEX.x / 64.0) * 0.5;
}

void fragment() {
	if (cp.x < 0.0 || cp.y < 0.0 || cp.x > map_size.x || cp.y > map_size.y) {
		COLOR = vec4(0.02, 0.022, 0.026, 1.0);
	} else {
		vec2 g = cp - 0.5;
		vec2 i0 = floor(g);
		vec2 f = g - i0;
		float n1 = texture(noise_tex, cp * 0.31).r - 0.5;
		float n2 = texture(noise_tex, cp * 0.29 + 0.5).r - 0.5;
		float n3 = texture(noise_tex, cp * 1.7).r - 0.5;
		vec2 fp = clamp(f + vec2(n1, n2) * 0.7 + n3 * 0.18, 0.0, 1.0);
		vec4 w = vec4((1.0 - fp.x) * (1.0 - fp.y), fp.x * (1.0 - fp.y), (1.0 - fp.x) * fp.y, fp.x * fp.y);
		vec4 wl = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
		float m00 = layer_at(i0);
		float m10 = layer_at(i0 + vec2(1.0, 0.0));
		float m01 = layer_at(i0 + vec2(0.0, 1.0));
		float m11 = layer_at(i0 + vec2(1.0, 1.0));
		vec2 uv = cp / tex_cells;
		vec3 s00 = mat(m00, uv, cp);
		vec3 s10 = (m10 == m00) ? s00 : mat(m10, uv, cp);
		vec3 s01 = (m01 == m00) ? s00 : ((m01 == m10) ? s10 : mat(m01, uv, cp));
		vec3 s11 = (m11 == m00) ? s00 : ((m11 == m10) ? s10 : ((m11 == m01) ? s01 : mat(m11, uv, cp)));
		vec4 h = vec4(lum(s00), lum(s10), lum(s01), lum(s11)) * 0.35 + w;
		float mx = max(max(h.x, h.y), max(h.z, h.w)) - 0.12;
		vec4 b = max(h - mx, vec4(0.0)) + 1e-4;
		vec3 col = (s00 * b.x + s10 * b.y + s01 * b.z + s11 * b.w) / (b.x + b.y + b.z + b.w);
		// Large-scale tonal variation breaks up repetition.
		float macro = texture(noise_tex, cp * 0.03).r;
		col *= 0.88 + 0.24 * macro;
		// Water surface over water-bed cells.
		vec4 isw = vec4(m00 > 9.5 ? 1.0 : 0.0, m10 > 9.5 ? 1.0 : 0.0, m01 > 9.5 ? 1.0 : 0.0, m11 > 9.5 ? 1.0 : 0.0);
		float ww = dot(isw, wl) + (n1 + n3) * 0.25 * step(0.01, dot(isw, vec4(1.0))) * step(dot(isw, vec4(1.0)), 3.99);
		if (ww > 0.2) {
			float t = TIME;
			float wave1 = texture(noise_tex, cp * 0.35 + vec2(t * 0.025, t * 0.017)).r;
			float wave2 = texture(noise_tex, cp * 0.6 - vec2(t * 0.02, -t * 0.028)).r;
			float depth = smoothstep(0.35, 1.0, ww);
			vec3 deep = vec3(0.07, 0.2, 0.32);
			vec3 shallow = vec3(0.16, 0.38, 0.42);
			vec3 wc = mix(shallow, deep, depth);
			float glint = smoothstep(0.62, 0.8, wave1 * 0.6 + wave2 * 0.4);
			wc += vec3(0.25, 0.32, 0.35) * glint * 0.55;
			wc *= 0.92 + 0.16 * wave2;
			float band = 0.5 + 0.5 * sin(t * 1.4 - ww * 14.0 + wave1 * 6.0);
			float foam = (1.0 - smoothstep(0.2, 0.55, ww)) * smoothstep(0.35, 0.75, wave2 + band * 0.4);
			wc = mix(wc, vec3(0.82, 0.88, 0.9), foam * 0.8);
			col = mix(col, wc, smoothstep(0.2, 0.42, ww));
		}
		COLOR = vec4(col, 1.0);
	}
}
"""

func setup(g: Game, ent_layer: Node2D) -> void:
	game = g
	map = g.map
	entity_layer = ent_layer
	_build_ground()
	ore_layer = Node2D.new()
	add_child(ore_layer)
	ore_sheet = SpriteLib.sheet("ore", "ore")
	for cy in range(0, map.h, ORE_CHUNK):
		for cx in range(0, map.w, ORE_CHUNK):
			var ch := Node2D.new()
			ch.set_meta("k", Vector2i(cx / ORE_CHUNK, cy / ORE_CHUNK))
			ch.draw.connect(_draw_ore_chunk.bind(ch))
			ore_layer.add_child(ch)
			ore_chunks[Vector2i(cx / ORE_CHUNK, cy / ORE_CHUNK)] = ch
	_scatter_decor()

func _build_ground() -> void:
	var cell := Image.create(map.w, map.h, false, Image.FORMAT_R8)
	for y in map.h:
		for x in map.w:
			var id := map.terrain_id(Vector2i(x, y))
			cell.set_pixel(x, y, Color(TERRAIN_LAYER.get(id, 0) / 255.0, 0, 0))
	var imgs: Array[Image] = []
	for n in LAYERS:
		var t: Texture2D = SpriteLib._load_tex("res://assets/terrain/%s.png" % n)
		var img: Image = t.get_image() if t != null else Image.create(64, 64, false, Image.FORMAT_RGB8)
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != 1024:
			img.resize(1024, 1024)
		img.generate_mipmaps()
		imgs.append(img)
	var arr := Texture2DArray.new()
	arr.create_from_images(imgs)
	var noise := NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 512
	noise.height = 512
	noise.generate_mipmaps = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.012
	fn.fractal_octaves = 4
	noise.noise = fn
	var sh := Shader.new()
	sh.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("cell_tex", ImageTexture.create_from_image(cell))
	m.set_shader_parameter("mats", arr)
	m.set_shader_parameter("noise_tex", noise)
	m.set_shader_parameter("map_size", Vector2(map.w, map.h))
	ground = Polygon2D.new()
	var pad := 30.0
	ground.polygon = PackedVector2Array([SpriteLib.iso_cells(Vector2(-pad, -pad)), SpriteLib.iso_cells(Vector2(map.w + pad, -pad)),
		SpriteLib.iso_cells(Vector2(map.w + pad, map.h + pad)), SpriteLib.iso_cells(Vector2(-pad, map.h + pad))])
	ground.material = m
	add_child(ground)

# ---------------------------------------------------------------- ore

func mark_ore_dirty(c: Vector2i) -> void:
	var k := Vector2i(c.x / ORE_CHUNK, c.y / ORE_CHUNK)
	if ore_chunks.has(k):
		ore_chunks[k].queue_redraw()

func _draw_ore_chunk(ch: Node2D) -> void:
	if ore_sheet == null:
		return
	var k: Vector2i = ch.get_meta("k")
	for y in range(k.y * ORE_CHUNK, mini((k.y + 1) * ORE_CHUNK, map.h)):
		for x in range(k.x * ORE_CHUNK, mini((k.x + 1) * ORE_CHUNK, map.w)):
			var c := Vector2i(x, y)
			var st := map.ore_stage(c)
			if st <= 0:
				continue
			var kind := map.ore_kind[map.idx(c)]
			var v := (x * 7 + y * 13) % 4
			var i := ((kind - 1) * 4 + st - 1) * 4 + v
			var p := SpriteLib.iso_cells(Vector2(x + 0.5, y + 0.5)) - Vector2(ore_sheet.ax, ore_sheet.ay)
			ch.draw_texture_rect_region(ore_sheet.tex, Rect2(p, Vector2(ore_sheet.fw, ore_sheet.fh)), ore_sheet.region(i))

# ---------------------------------------------------------------- decorations

func _add_decor(sheet_name: String, frame: int, c: Vector2, scale_v: float = 1.0) -> void:
	var s := SpriteLib.sheet(sheet_name)
	if s == null:
		return
	var sp := Sprite2D.new()
	sp.texture = s.tex
	sp.region_enabled = true
	sp.region_rect = s.region(frame)
	sp.centered = false
	sp.offset = -Vector2(s.ax, s.ay)
	sp.position = SpriteLib.iso_cells(c)
	sp.scale = Vector2(scale_v, scale_v)
	if randf() < 0.5:
		sp.flip_h = true
		sp.offset.x = -(s.fw - s.ax)
	entity_layer.add_child(sp)
	var cell := Vector2i(floori(c.x), floori(c.y))
	if not decor_by_cell.has(cell):
		decor_by_cell[cell] = []
	decor_by_cell[cell].append(sp)

func _scatter_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map.w * 1000 + map.h
	var starts: Array = map.starts
	var density: float = Config.effects_density()
	for y in map.h:
		for x in map.w:
			var c := Vector2i(x, y)
			var id := map.terrain_id(c)
			var near_start := false
			for s in starts:
				if c.distance_to(s) < 7:
					near_start = true
			match id:
				"forest":
					for i in maxi(1, int(round(rng.randi_range(1, 3) * density))):
						var p := Vector2(x + rng.randf_range(0.15, 0.85), y + rng.randf_range(0.15, 0.85))
						_add_decor("d_tree_pine" if rng.randf() < 0.4 else "d_tree_broad", rng.randi() % 4, p, rng.randf_range(0.85, 1.15))
				"rock":
					if rng.randf() < 0.45:
						_add_decor("d_rock", rng.randi() % 4, Vector2(x + rng.randf_range(0.2, 0.8), y + rng.randf_range(0.2, 0.8)), rng.randf_range(0.7, 1.1))
				"cliff":
					if rng.randf() < 0.75:
						_add_decor("d_cliff", rng.randi() % 4, Vector2(x + 0.5, y + 0.5), rng.randf_range(0.8, 1.15))
				"grass", "dirt":
					if near_start or map.ore[map.idx(c)] > 0:
						continue
					var r := rng.randf() / density
					if r < 0.035:
						_add_decor("d_bush", rng.randi() % 4, Vector2(x + rng.randf(), y + rng.randf()), rng.randf_range(0.7, 1.1))
					elif r < 0.042:
						_add_decor("d_tree_broad", rng.randi() % 4, Vector2(x + rng.randf(), y + rng.randf()), rng.randf_range(0.8, 1.1))
					elif r < 0.044:
						var props := ["d_crates", "d_barrels", "d_sandbags", "d_fence", "d_wreck", "d_lamp"]
						var pn: String = props[rng.randi() % props.size()]
						var ps := SpriteLib.sheet(pn)
						if ps != null:
							_add_decor(pn, rng.randi() % ps.count, Vector2(x + 0.5, y + 0.5))

## Removes decorations under a new structure footprint.
func clear_decor(cells: Array) -> void:
	for c in cells:
		if decor_by_cell.has(c):
			for sp in decor_by_cell[c]:
				sp.queue_free()
			decor_by_cell.erase(c)
