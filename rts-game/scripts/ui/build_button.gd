class_name BuildButton
extends Control
## Sidebar production button: icon, price, progress wipe, READY state, queue count, lock reason.

var hud = null
var type: String = ""
var cat: String = ""
var progress: float = -1.0
var count: int = 0
var ready_state: bool = false
var on_hold: bool = false
var reason: String = ""
var blink: float = 0.0
var cameo: Texture2D = null
static var _cameo_cache := {}

static func cameo_for(t: String, faction: String) -> Texture2D:
	var k := "%s_%s" % [t, faction]
	if _cameo_cache.has(k):
		return _cameo_cache[k]
	var tex: Texture2D = null
	for f in [faction, "coalition", "dominion"]:
		var p := "res://assets/ui/cameos/%s_%s.png" % [t, f]
		if ResourceLoader.exists(p):
			tex = load(p)
			break
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(ProjectSettings.globalize_path(p))
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
				break
	_cameo_cache[k] = tex
	return tex

func setup(h, t: String, c: String) -> void:
	hud = h
	type = t
	cat = c
	custom_minimum_size = Vector2(94, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func refresh(g: Game) -> void:
	var pid := g.human_pid
	reason = g.availability(pid, type)
	progress = -1.0
	count = 0
	ready_state = false
	on_hold = false
	var b = g.producer_for(pid, cat)
	if b != null:
		var q: Array = b.queues.get(cat, [])
		for i in q.size():
			if q[i].type == type:
				count += 1
				if i == 0:
					progress = float(q[i].progress)
					ready_state = q[i].state == "ready"
					on_hold = q[i].state == "hold"
	var d := Data.def(type)
	var lines := ["%s  -  $%s" % [d.name, UITheme.fmt(g.cost_of(pid, type))]]
	lines.append("Build time: %ds" % int(d.get("build_time", 0)))
	if d.has("power") and int(d.power) != 0:
		lines.append("Power: %+d" % int(d.power))
	if d.has("role"):
		lines.append(d.role)
	if d.has("hp"):
		lines.append("Armor: %s  |  HP %d" % [d.get("armor", "-"), int(d.hp)])
	if reason != "":
		lines.append("Unavailable - " + reason)
	elif not g.players[pid].can_afford(1) and g.cost_of(pid, type) > 0:
		lines.append("Insufficient credits")
	lines.append("Left-click: build / place   Shift: x5   Right-click: cancel")
	tooltip_text = "\n".join(lines)
	queue_redraw()

func _process(delta: float) -> void:
	blink += delta
	if ready_state:
		queue_redraw()

## Card look: navy plate with the illustrated cameo, a gold price tag top-left, a dark name bar,
## rounded border that lights up on hover (green when ready).
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var g: Game = hud.game if hud != null else null
	if g == null:
		return
	var p = g.players[g.human_pid]
	if cameo == null:
		cameo = cameo_for(type, p.faction)
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.05, 0.08, 0.14)
	card.set_corner_radius_all(6)
	draw_style_box(card, r)
	if cameo != null:
		draw_texture_rect(cameo, r.grow(-2), false)
	else:
		IconView.draw(self, type, Rect2(2, 2, size.x - 4, size.y - 22), p.color, p.faction)
	var f := ThemeDB.fallback_font
	var d := Data.def(type)
	draw_rect(Rect2(2, size.y - 19, size.x - 4, 17), Color(0.02, 0.03, 0.055, 0.88))
	draw_string(f, Vector2(5, size.y - 6), String(d.name).substr(0, 15), HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 11, Color(0.94, 0.95, 0.98))
	var price := "$" + UITheme.fmt(g.cost_of(g.human_pid, type))
	var pw := f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(0.02, 0.03, 0.05, 0.85)
	tag.set_corner_radius_all(3)
	draw_style_box(tag, Rect2(3, 3, pw, 16))
	draw_string(f, Vector2(7, 15), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.77, 0.16))
	if progress >= 0.0 and not ready_state:
		# Clock wipe over the remaining part.
		var c := Vector2(size.x * 0.5, (size.y - 20) * 0.5)
		var pts := PackedVector2Array([c])
		var steps := 24
		for i in steps + 1:
			var a := -PI * 0.5 + TAU * progress + (TAU * (1.0 - progress)) * float(i) / steps
			pts.append(c + Vector2.RIGHT.rotated(a) * size.x)
		var clip := Rect2(2, 2, size.x - 4, size.y - 22)
		var clipped := Geometry2D.intersect_polygons(pts, PackedVector2Array([clip.position, Vector2(clip.end.x, clip.position.y), clip.end, Vector2(clip.position.x, clip.end.y)]))
		for poly in clipped:
			draw_colored_polygon(poly, Color(0, 0, 0, 0.6))
		draw_string(f, Vector2(size.x - 34, 15), "%d%%" % int(progress * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	if on_hold:
		draw_string(f, Vector2(6, size.y * 0.5), "ON HOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.BAD)
	if ready_state and fmod(blink, 0.8) < 0.55:
		draw_rect(Rect2(2, size.y * 0.5 - 20, size.x - 4, 18), Color(0, 0, 0, 0.55))
		var txt := "READY"
		var left: int = g.wall_sections_left(g.human_pid, cat) if d.get("wall", false) else 0
		if left > 0:
			txt = "READY x%d" % left
		draw_string(f, Vector2(0, size.y * 0.5 - 6), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, UITheme.GOOD)
	if count > 1:
		draw_circle(Vector2(size.x - 12, 28), 9, Color(0.12, 0.43, 0.9))
		draw_string(f, Vector2(size.x - 21, 33), str(count), HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Color.WHITE)
	if reason != "":
		draw_rect(r.grow(-2), Color(0.02, 0.02, 0.03, 0.62))
		draw_string(f, Vector2(0, size.y * 0.5 - 4), "LOCKED", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, UITheme.DIM)
	var hover := get_global_rect().has_point(get_global_mouse_position())
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.set_corner_radius_all(6)
	frame.set_border_width_all(2 if hover or ready_state else 1)
	frame.border_color = UITheme.GOOD if ready_state else (Color(0.5, 0.75, 1.0) if hover else Color(0.39, 0.51, 0.67))
	draw_style_box(frame, r)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			hud.on_build_click(self, event.shift_pressed)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			hud.on_build_cancel(self)
			accept_event()
	elif event is InputEventMouseMotion:
		queue_redraw()
