class_name Effect
extends Node2D
## Short-lived cosmetic effect (explosions, muzzle flashes, tracers, smoke, fire).

var kind: String = "explosion"
var t: float = 0.0
var dur: float = 0.5
var opts: Dictionary = {}
var seed_v: int = 0

func setup(k: String, p: Vector2, o: Dictionary) -> void:
	kind = k
	position = p
	opts = o
	seed_v = randi()
	z_index = 6
	dur = {"explosion": 0.9, "explosion_small": 0.45, "explosion_big": 1.4, "muzzle": 0.07, "tracer": 0.07,
		"zap": 0.25, "spark": 0.3, "smoke": 1.6, "fire": 0.9, "flame_burst": 0.5, "crater": 25.0}.get(k, 0.5)
	if k == "crater":
		z_index = 0

func _process(delta: float) -> void:
	t += delta
	if kind == "smoke":
		position += Vector2(6, -14) * delta
	if t >= dur:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var f := t / dur
	match kind:
		"explosion", "explosion_small", "explosion_big":
			var big: float = {"explosion": 1.0, "explosion_small": 0.5, "explosion_big": 1.8}[kind]
			var r := (8.0 + 22.0 * f) * big
			draw_circle(Vector2.ZERO, r, Color(1.0, 0.55, 0.15, 0.7 * (1.0 - f)))
			draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.9, 0.5, 0.9 * (1.0 - f)))
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_v
			for i in int(6 * big):
				var a := rng.randf() * TAU
				var d := r * (0.8 + rng.randf() * 0.8)
				draw_circle(Vector2.RIGHT.rotated(a) * d, 2.0 * big * (1.0 - f) + 0.5, Color(0.25, 0.22, 0.2, 0.8 * (1.0 - f)))
			if f > 0.4:
				draw_circle(Vector2(0, -r * 0.3), r * 0.7, Color(0.2, 0.2, 0.2, 0.35 * (1.0 - f)))
		"muzzle":
			var a: float = opts.get("angle", 0.0)
			var len := 9.0 if opts.get("big", false) else 5.0
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(a) * len, Color(1, 0.9, 0.5), 3.0)
			draw_circle(Vector2.ZERO, len * 0.4, Color(1, 0.8, 0.3, 0.8))
		"tracer":
			var to: Vector2 = opts.get("to", position) - position
			draw_line(to * 0.3, to, Color(1, 0.95, 0.6, 0.85), 1.2)
		"zap":
			var to: Vector2 = opts.get("to", position) - position
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_v + int(t * 30.0)
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in range(1, 8):
				var p := to * (float(i) / 8.0)
				p += to.orthogonal().normalized() * rng.randf_range(-7, 7)
				pts.append(p)
			pts.append(to)
			draw_polyline(pts, Color(0.6, 0.85, 1.0, 1.0 - f), 3.0)
			draw_polyline(pts, Color(1, 1, 1, 1.0 - f), 1.0)
		"spark":
			draw_circle(Vector2.ZERO, 6.0 * (1.0 - f), Color(0.7, 0.9, 1.0, 1.0 - f))
		"smoke":
			draw_circle(Vector2.ZERO, 5.0 + f * 9.0, Color(0.25, 0.25, 0.25, 0.45 * (1.0 - f)))
		"fire":
			var flick := sin(t * 30.0) * 1.5
			draw_circle(Vector2(0, -f * 6.0), 6.0 - f * 3.0 + flick, Color(1, 0.45, 0.1, 0.8 * (1.0 - f)))
			draw_circle(Vector2(0, -f * 6.0), 3.0, Color(1, 0.9, 0.4, 0.9 * (1.0 - f)))
		"flame_burst":
			draw_circle(Vector2.ZERO, 6.0 + f * 16.0, Color(1, 0.4, 0.05, 0.6 * (1.0 - f)))
			draw_circle(Vector2.ZERO, 4.0 + f * 8.0, Color(1, 0.8, 0.3, 0.7 * (1.0 - f)))
		"crater":
			var a := 0.5 * (1.0 - maxf(0.0, f - 0.7) / 0.3)
			draw_circle(Vector2.ZERO, float(opts.get("r", 10.0)), Color(0.1, 0.09, 0.07, a))
