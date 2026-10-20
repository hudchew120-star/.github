class_name IsoFx
extends Node2D
## One isometric effect: an animated sprite-sheet (explosions, smoke, fire, muzzle
## flashes, corpses, craters) or a line effect (tracers, electric arcs).

var sheet: SpriteLib.Sheet
var fps: float = 20.0
var loop: bool = false
var life: float = 1.0
var t: float = 0.0
var hold_last: float = 0.0
var fade: float = 0.25
var drift := Vector2.ZERO
var line_to := Vector2.INF
var line_col := Color(1, 0.9, 0.5)
var line_w := 2.0
var zap: bool = false
var frame_override: int = -1

func play(s: SpriteLib.Sheet, p: Vector2, frames_per_sec: float, scale_v: float = 1.0) -> void:
	sheet = s
	position = p
	fps = frames_per_sec
	scale = Vector2(scale_v, scale_v)
	life = float(s.count) / fps if s != null else 0.3

func _process(delta: float) -> void:
	t += delta
	position += drift * delta
	if t >= life + hold_last:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if line_to != Vector2.INF:
		var a := clampf(1.0 - t / life, 0.0, 1.0)
		var to := line_to - position
		if zap:
			var pts := PackedVector2Array([Vector2.ZERO])
			var side := to.orthogonal().normalized()
			for i in range(1, 9):
				pts.append(to * (i / 9.0) + side * randf_range(-9, 9))
			pts.append(to)
			draw_polyline(pts, Color(0.55, 0.8, 1.0, a), line_w * 2.5)
			draw_polyline(pts, Color(1, 1, 1, a), line_w)
		else:
			draw_line(to * 0.25, to, Color(line_col.r, line_col.g, line_col.b, a), line_w)
		return
	if sheet == null:
		return
	var i := frame_override if frame_override >= 0 else int(t * fps)
	if loop:
		i = i % sheet.count
	else:
		i = mini(i, sheet.count - 1)
	var a := 1.0
	var total := life + hold_last
	if t > total - fade:
		a = clampf((total - t) / fade, 0.0, 1.0)
	draw_texture_rect_region(sheet.tex, Rect2(-Vector2(sheet.ax, sheet.ay), Vector2(sheet.fw, sheet.fh)), sheet.region(i), Color(1, 1, 1, a))
