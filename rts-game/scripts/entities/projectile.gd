class_name Projectile
extends Node2D
## A travelling munition (shell, rocket, flame). Detonates on arrival.

var game = null
var w: Dictionary = {}
var shooter = null
var target = null
var from := Vector2.ZERO
var to := Vector2.ZERO
var cur := Vector2.ZERO
var speed: float = 400.0
var kind: String = "shell"
var homing: bool = false
var t: float = 0.0
var dead: bool = false
var trail: Array = []
var h_from: float = 0.0      # launch / impact heights (aircraft), used by renderers
var h_to: float = 0.0

func _ready() -> void:
	z_index = 5

func setup(g, sh, weapon: Dictionary, tgt, start: Vector2, target_pos: Vector2) -> void:
	game = g
	shooter = sh
	w = weapon
	target = tgt
	from = start
	to = target_pos
	cur = start
	kind = w.get("projectile", "shell")
	speed = maxf(60.0, float(w.get("speed", 400)))
	homing = kind == "rocket" and target_pos.distance_to(tgt.pos) < 1.0
	position = cur
	if sh != null and sh.is_unit() and sh.is_air_unit:
		h_from = sh.altitude_now
	if tgt != null and tgt.is_unit() and tgt.is_air_unit:
		h_to = tgt.altitude_now

func tick(dt: float) -> void:
	if dead:
		return
	t += dt
	if homing and target != null and is_instance_valid(target) and not target.dead:
		to = target.pos
	var d := to - cur
	var step := speed * dt
	if kind == "rocket":
		trail.append(cur)
		if trail.size() > 6:
			trail.pop_front()
	if d.length() <= step:
		cur = to
		dead = true
		var tgt = target if target != null and is_instance_valid(target) else null
		Combat.detonate(game, cur, w, shooter if shooter != null and is_instance_valid(shooter) else null, tgt)
		return
	cur += d.normalized() * step
	position = cur
	rotation = d.angle()
	queue_redraw()

func _draw() -> void:
	match kind:
		"shell":
			draw_line(Vector2(-6, 0), Vector2(0, 0), Color(1, 0.85, 0.4, 0.5), 2.0)
			draw_circle(Vector2.ZERO, 2.0, Color(1, 0.95, 0.7))
		"rocket":
			for i in trail.size():
				var lp: Vector2 = (trail[i] - cur).rotated(-rotation)
				draw_circle(lp, 1.0 + i * 0.4, Color(0.8, 0.8, 0.8, 0.12 + i * 0.05))
			draw_line(Vector2(-5, 0), Vector2(3, 0), Color(0.75, 0.75, 0.7), 2.5)
			draw_circle(Vector2(-6, 0), 2.0, Color(1, 0.6, 0.15))
		"flame":
			var s := 3.0 + t * 18.0
			draw_circle(Vector2.ZERO, s, Color(1, 0.45, 0.1, 0.55))
			draw_circle(Vector2.ZERO, s * 0.55, Color(1, 0.85, 0.3, 0.8))
		_:
			draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
