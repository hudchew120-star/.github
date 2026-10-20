class_name TerrainBlend
extends Node2D
## Soft transitions between terrain types. Each chunk draws gradient strips where a
## higher-priority terrain meets a lower one. Drawn once and cached by the renderer.

const CHUNK := 32
const PRIORITY := {"water": 0, "shore": 1, "sand": 2, "dirt": 3, "road": 4, "grass": 5, "rock": 6, "forest": 7, "cliff": 8}
const WIDTH := 10.0

var map: MapGrid
var cx: int = 0
var cy: int = 0

static func build(parent: Node, m: MapGrid) -> void:
	for y in range(0, m.h, CHUNK):
		for x in range(0, m.w, CHUNK):
			var c := TerrainBlend.new()
			c.map = m
			c.cx = x
			c.cy = y
			parent.add_child(c)

func _draw() -> void:
	var T := float(MapGrid.T)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for y in range(cy, mini(cy + CHUNK, map.h)):
		for x in range(cx, mini(cx + CHUNK, map.w)):
			var c := Vector2i(x, y)
			var tid := map.terrain_id(c)
			if tid == "bridge":
				continue
			var p0: int = PRIORITY.get(tid, 5)
			var o := Vector2(x, y) * T
			for d in dirs:
				var n: Vector2i = c + d
				if not map.in_bounds(n):
					continue
				var nid := map.terrain_id(n)
				if nid == tid or nid == "bridge":
					continue
				var p1: int = PRIORITY.get(nid, 5)
				if p1 <= p0:
					continue
				var col := Color(Data.terrain[nid].color)
				if nid == "forest":
					col = Color(0.27, 0.38, 0.2)
				elif nid == "cliff":
					col = Color(0.2, 0.19, 0.17)
				var solid := Color(col.r, col.g, col.b, 0.85)
				var clear := Color(col.r, col.g, col.b, 0.0)
				var pts: PackedVector2Array
				var cols: PackedColorArray
				match d:
					Vector2i(1, 0):
						pts = PackedVector2Array([o + Vector2(T, 0), o + Vector2(T, T), o + Vector2(T - WIDTH, T), o + Vector2(T - WIDTH, 0)])
					Vector2i(-1, 0):
						pts = PackedVector2Array([o, o + Vector2(0, T), o + Vector2(WIDTH, T), o + Vector2(WIDTH, 0)])
					Vector2i(0, 1):
						pts = PackedVector2Array([o + Vector2(0, T), o + Vector2(T, T), o + Vector2(T, T - WIDTH), o + Vector2(0, T - WIDTH)])
					_:
						pts = PackedVector2Array([o, o + Vector2(T, 0), o + Vector2(T, WIDTH), o + Vector2(0, WIDTH)])
				cols = PackedColorArray([solid, solid, clear, clear])
				draw_polygon(pts, cols)
				if tid == "water" and (nid == "shore" or nid == "sand"):
					# Surf line along beaches.
					var a: Vector2 = pts[0].lerp(pts[3], 0.9)
					var b: Vector2 = pts[1].lerp(pts[2], 0.9)
					draw_line(a, b, Color(0.85, 0.92, 0.95, 0.18), 1.5)
