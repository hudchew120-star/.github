class_name TerrainArt
extends RefCounted
## Generates original terrain and ore tile textures procedurally at startup.

const T := 32
const VARIANTS := 4

static func _noise(seed_v: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	return n

static func build_terrain_tileset() -> TileSet:
	var ids: Array = Data.terrain_ids
	var img := Image.create(T * VARIANTS, T * ids.size(), false, Image.FORMAT_RGBA8)
	var n1 := _noise(11, 0.09)
	var n2 := _noise(23, 0.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for row in ids.size():
		var id: String = ids[row]
		var base := Color(Data.terrain[id].get("color", "#808080"))
		for v in VARIANTS:
			var ox := v * T
			var oy := row * T
			for y in T:
				for x in T:
					var wx := float(x + v * 37)
					var wy := float(y + v * 53)
					var a := n1.get_noise_2d(wx, wy)
					var b := n2.get_noise_2d(wx, wy)
					var c := base
					match id:
						"grass":
							c = base.lightened(a * 0.12) if a > 0 else base.darkened(-a * 0.15)
							if b > 0.55:
								c = c.darkened(0.18)
							elif b < -0.6:
								c = c.lightened(0.1)
						"dirt":
							c = base.darkened(a * 0.12)
							if b > 0.6:
								c = c.lightened(0.15)
						"sand":
							c = base.lightened(sin((wy + a * 6.0) * 0.6) * 0.04 + a * 0.05)
						"water":
							c = base.lightened(a * 0.08)
							if sin(wx * 0.35 + wy * 0.18 + a * 4.0) > 0.92:
								c = c.lightened(0.18)
						"shore":
							c = base.darkened(a * 0.1)
							if b > 0.5:
								c = c.lightened(0.18)
						"road":
							c = base.darkened(a * 0.08)
							if b > 0.65:
								c = c.lightened(0.12)
						"rock":
							c = base.darkened(a * 0.1)
						"cliff":
							c = base.darkened(absf(a) * 0.25)
							if absf(b) < 0.04:
								c = c.darkened(0.35)
						"bridge":
							c = base.darkened(0.12) if (y % 6) == 0 else base.lightened(a * 0.06)
							if x < 3 or x > T - 4:
								c = Color(0.35, 0.28, 0.2)
						"forest":
							c = Color(0.25, 0.35, 0.18).darkened(absf(a) * 0.1)
					img.set_pixel(ox + x, oy + y, c)
			# Decorations
			match id:
				"rock":
					for i in 3:
						_blob(img, ox + rng.randi_range(5, T - 6), oy + rng.randi_range(5, T - 6), rng.randi_range(3, 5), base.lightened(0.12), base.darkened(0.35))
				"cliff":
					for i in 2:
						_blob(img, ox + rng.randi_range(6, T - 7), oy + rng.randi_range(6, T - 7), rng.randi_range(5, 8), base.lightened(0.15), base.darkened(0.5))
				"forest":
					for i in 3:
						var cx := rng.randi_range(7, T - 8)
						var cy := rng.randi_range(7, T - 8)
						var r := rng.randi_range(6, 9)
						_blob(img, ox + cx + 2, oy + cy + 3, r, Color(0.08, 0.12, 0.06), Color(0.08, 0.12, 0.06))
						_blob(img, ox + cx, oy + cy, r, Color(0.24, 0.42, 0.18), Color(0.14, 0.27, 0.11))
				"grass":
					for i in 5:
						var px := ox + rng.randi_range(1, T - 2)
						var py := oy + rng.randi_range(1, T - 2)
						img.set_pixel(px, py, base.lightened(0.22))
				"dirt", "road":
					for i in 4:
						var px := ox + rng.randi_range(1, T - 2)
						var py := oy + rng.randi_range(1, T - 2)
						img.set_pixel(px, py, base.lightened(0.25))
						img.set_pixel(px + 1, py + 1, base.darkened(0.3))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(T, T)
	for row in ids.size():
		for v in VARIANTS:
			src.create_tile(Vector2i(v, row))
	ts.add_source(src, 0)
	return ts

static func _blob(img: Image, cx: int, cy: int, r: int, light: Color, dark: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d := sqrt(float(x * x + y * y))
			if d > r:
				continue
			var px := cx + x
			var py := cy + y
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			var shade := clampf((float(x + y) / float(r * 2) + 0.5), 0.0, 1.0)
			img.set_pixel(px, py, light.lerp(dark, shade))

## Ore atlas: rows 0..3 = ore stages 1..4, rows 4..7 = gem stages 1..4. Columns = variants.
static func build_ore_tileset() -> TileSet:
	var img := Image.create(T * VARIANTS, T * 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for kind in 2:
		var col := Color(0.88, 0.7, 0.22) if kind == 0 else Color(0.38, 0.78, 0.98)
		for stage in 4:
			for v in VARIANTS:
				var ox := v * T
				var oy := (kind * 4 + stage) * T
				var n := (stage + 1) * 3
				for i in n:
					var cx := rng.randi_range(4, T - 5)
					var cy := rng.randi_range(4, T - 5)
					var r := rng.randi_range(2, 3 + stage / 2)
					_blob(img, ox + cx, oy + cy, r, col.lightened(0.25), col.darkened(0.45))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(T, T)
	for row in 8:
		for v in VARIANTS:
			src.create_tile(Vector2i(v, row))
	ts.add_source(src, 0)
	return ts
