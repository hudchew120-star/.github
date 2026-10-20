class_name SpatialHash
extends RefCounted
## Uniform-grid spatial partition for fast "entities near point" queries.

var cell_size: float = 128.0
var buckets := {}

func _init(cs: float = 128.0) -> void:
	cell_size = cs

func clear() -> void:
	buckets.clear()

func insert(e) -> void:
	var k := Vector2i(floori(e.pos.x / cell_size), floori(e.pos.y / cell_size))
	if buckets.has(k):
		buckets[k].append(e)
	else:
		buckets[k] = [e]

func rebuild(list: Array) -> void:
	buckets.clear()
	for e in list:
		if not e.dead:
			insert(e)

func query(p: Vector2, r: float) -> Array:
	var out := []
	var x0 := floori((p.x - r) / cell_size)
	var x1 := floori((p.x + r) / cell_size)
	var y0 := floori((p.y - r) / cell_size)
	var y1 := floori((p.y + r) / cell_size)
	var r2 := r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var b = buckets.get(Vector2i(x, y))
			if b == null:
				continue
			for e in b:
				if not e.dead and e.pos.distance_squared_to(p) <= r2 + e.radius * e.radius + 2.0 * r * e.radius:
					out.append(e)
	return out
