class_name Sprites
extends RefCounted
## Procedural top-down artwork for every unit and building. Works on any CanvasItem,
## so the same code draws battlefield sprites and sidebar icons.

const TRACK := Color(0.13, 0.13, 0.12)
const TRACK_HI := Color(0.3, 0.29, 0.27)
const STEEL := Color(0.55, 0.57, 0.55)
const SHADOW := Color(0, 0, 0, 0.28)
const CONCRETE_C := Color(0.62, 0.64, 0.66)
const CONCRETE_D := Color(0.52, 0.47, 0.44)

static var base := Transform2D.IDENTITY   # extra transform applied to everything (icons, ghosts)

static func _xf(ci: CanvasItem, p: Vector2, rot: float, sc: Vector2) -> void:
	ci.draw_set_transform_matrix(base * Transform2D(rot, sc, 0.0, p))

static func hull_color(team: Color, faction: String) -> Color:
	var base := Color(0.42, 0.46, 0.36) if faction == "coalition" else Color(0.40, 0.36, 0.30)
	return base.lerp(team, 0.45)

static func _rect_c(ci: CanvasItem, cx: float, cy: float, w: float, h: float, col: Color) -> void:
	ci.draw_rect(Rect2(cx - w * 0.5, cy - h * 0.5, w, h), col)

# ---------------------------------------------------------------- units

static func draw_unit(ci: CanvasItem, sprite: String, team: Color, faction: String, facing: float, turret: float, anim: float, extra: float = 0.0) -> void:
	match sprite:
		"infantry", "rocket_inf", "heavy_inf", "flame_inf":
			_draw_infantry(ci, sprite, team, facing, anim)
		"jeep":
			_draw_jeep(ci, team, faction, facing, turret, anim)
		"tank_light":
			_draw_tank(ci, team, faction, facing, turret, anim, 22.0, 16.0, 4.5, 12.0, 1)
		"tank_medium":
			_draw_tank(ci, team, faction, facing, turret, anim, 25.0, 18.0, 5.5, 14.0, 1)
		"tank_heavy":
			_draw_tank(ci, team, faction, facing, turret, anim, 28.0, 21.0, 6.5, 15.0, 2)
		"harvester":
			_draw_harvester(ci, team, faction, facing, anim, extra)
		"mcv":
			_draw_mcv(ci, team, faction, facing, anim)
		_:
			Sprites._xf(ci, Vector2.ZERO, facing, Vector2.ONE)
			ci.draw_circle(Vector2.ZERO, 8, team)
	Sprites._xf(ci, Vector2.ZERO, 0.0, Vector2.ONE)

static func _draw_infantry(ci: CanvasItem, sprite: String, team: Color, facing: float, anim: float) -> void:
	Sprites._xf(ci, Vector2.ZERO, 0.0, Vector2(1.3, 1.3))
	ci.draw_circle(Vector2(1.5, 2.0), 4.5, SHADOW)
	Sprites._xf(ci, Vector2.ZERO, facing, Vector2(1.3, 1.3))
	var step := sin(anim * 10.0) * 2.2
	var boots := Color(0.18, 0.16, 0.13)
	ci.draw_circle(Vector2(step, -2.2), 1.5, boots)
	ci.draw_circle(Vector2(-step, 2.2), 1.5, boots)
	var body := team.darkened(0.15)
	var bulk := 4.6 if sprite == "heavy_inf" else 3.8
	if sprite == "flame_inf":
		_rect_c(ci, -4.0, 0, 3.5, 6.0, Color(0.55, 0.2, 0.12))
	ci.draw_circle(Vector2.ZERO, bulk, body)
	ci.draw_circle(Vector2(0.4, 0), 2.3, Color(0.32, 0.36, 0.28) if sprite != "heavy_inf" else Color(0.25, 0.25, 0.25))
	match sprite:
		"infantry":
			ci.draw_line(Vector2(0, 1.8), Vector2(7.5, 1.8), Color(0.1, 0.1, 0.1), 1.6)
		"rocket_inf":
			ci.draw_line(Vector2(-4, -2.2), Vector2(7, -2.2), Color(0.3, 0.33, 0.27), 2.6)
			ci.draw_line(Vector2(6, -2.2), Vector2(7.5, -2.2), Color(0.85, 0.75, 0.3), 2.6)
		"heavy_inf":
			ci.draw_line(Vector2(-3, -2.4), Vector2(7.5, -2.4), Color(0.2, 0.2, 0.2), 3.2)
			ci.draw_circle(Vector2(8, -2.4), 2.0, Color(0.45, 0.4, 0.3))
		"flame_inf":
			ci.draw_line(Vector2(0, 2.0), Vector2(7.5, 2.0), Color(0.2, 0.2, 0.2), 2.0)
			ci.draw_circle(Vector2(8, 2.0), 1.2, Color(1.0, 0.55, 0.1))

static func _draw_tracks(ci: CanvasItem, length: float, width: float, anim: float) -> void:
	var tw := maxf(4.0, width * 0.27)
	for side in [-1.0, 1.0]:
		var y: float = side * (width * 0.5 - tw * 0.5)
		_rect_c(ci, 0, y, length, tw, TRACK)
		var off := fposmod(anim * 18.0, 4.0)
		var x := -length * 0.5 + off
		while x < length * 0.5:
			ci.draw_line(Vector2(x, y - tw * 0.5 + 0.5), Vector2(x, y + tw * 0.5 - 0.5), TRACK_HI, 1.0)
			x += 4.0

static func _draw_tank(ci: CanvasItem, team: Color, faction: String, facing: float, turret: float, anim: float, length: float, width: float, tur_r: float, barrel: float, barrels: int) -> void:
	Sprites._xf(ci, Vector2(2.5, 3.0), facing, Vector2.ONE)
	_rect_c(ci, 0, 0, length + 1, width + 1, SHADOW)
	Sprites._xf(ci, Vector2.ZERO, facing, Vector2.ONE)
	_draw_tracks(ci, length, width, anim)
	var hull := hull_color(team, faction)
	var tw := maxf(4.0, width * 0.27)
	_rect_c(ci, -0.5, 0, length - 3.0, width - tw * 1.4, hull)
	_rect_c(ci, length * 0.5 - 3.5, 0, 3.0, width - tw * 1.6, hull.lightened(0.15))
	ci.draw_rect(Rect2(-length * 0.5 + 1.5, -width * 0.5 + tw * 0.7, length - 3.0, width - tw * 1.4), hull.darkened(0.35), false, 1.0)
	Sprites._xf(ci, Vector2.ZERO, turret, Vector2.ONE)
	var tc := hull.lightened(0.08)
	if barrels == 2:
		_rect_c(ci, barrel * 0.5 + tur_r * 0.5, -2.2, barrel, 2.6, Color(0.2, 0.21, 0.2))
		_rect_c(ci, barrel * 0.5 + tur_r * 0.5, 2.2, barrel, 2.6, Color(0.2, 0.21, 0.2))
	else:
		_rect_c(ci, barrel * 0.5 + tur_r * 0.5, 0, barrel, 3.0, Color(0.2, 0.21, 0.2))
	ci.draw_circle(Vector2(-1, 0), tur_r + 0.8, hull.darkened(0.4))
	ci.draw_circle(Vector2(-1, 0), tur_r, tc)
	ci.draw_circle(Vector2(-2.0, -1.2), tur_r * 0.35, team.lightened(0.25))

static func _draw_jeep(ci: CanvasItem, team: Color, faction: String, facing: float, turret: float, anim: float) -> void:
	Sprites._xf(ci, Vector2(2, 2.5), facing, Vector2.ONE)
	_rect_c(ci, 0, 0, 20, 13, SHADOW)
	Sprites._xf(ci, Vector2.ZERO, facing, Vector2.ONE)
	for p in [Vector2(-6, -6), Vector2(6, -6), Vector2(-6, 6), Vector2(6, 6)]:
		_rect_c(ci, p.x, p.y, 5.5, 3.2, TRACK)
	var hull := hull_color(team, faction)
	_rect_c(ci, 0, 0, 19, 10, hull)
	_rect_c(ci, 6.0, 0, 5, 9, hull.lightened(0.18))
	_rect_c(ci, 2.5, 0, 1.5, 9, Color(0.55, 0.75, 0.85, 0.9))
	Sprites._xf(ci, Vector2(-2, 0), turret, Vector2.ONE)
	_rect_c(ci, 5, 0, 9, 1.8, Color(0.12, 0.12, 0.12))
	ci.draw_circle(Vector2.ZERO, 3.0, hull.darkened(0.3))

static func _draw_harvester(ci: CanvasItem, team: Color, faction: String, facing: float, anim: float, load_ratio: float) -> void:
	Sprites._xf(ci, Vector2(2.5, 3), facing, Vector2.ONE)
	_rect_c(ci, 0, 0, 30, 22, SHADOW)
	Sprites._xf(ci, Vector2.ZERO, facing, Vector2.ONE)
	_draw_tracks(ci, 28, 22, anim)
	var hull := hull_color(team, faction).lightened(0.05)
	_rect_c(ci, -3, 0, 20, 14, hull.darkened(0.2))
	_rect_c(ci, -3, 0, 17, 11, Color(0.22, 0.2, 0.17))
	if load_ratio > 0.0:
		_rect_c(ci, -3 - 8.5 + 8.5 * load_ratio, 0, 17 * load_ratio, 11, Color(0.82, 0.66, 0.25))
	_rect_c(ci, 9, 0, 7, 14, hull)
	_rect_c(ci, 11, 0, 2, 11, Color(0.55, 0.75, 0.85, 0.9))
	_rect_c(ci, 15, 0, 3, 18, STEEL.darkened(0.2))
	var spin := fposmod(anim * 12.0, 3.0)
	for i in 6:
		ci.draw_line(Vector2(14, -8 + i * 3 + spin), Vector2(17, -8 + i * 3 + spin), Color(0.2, 0.2, 0.2), 1.0)

static func _draw_mcv(ci: CanvasItem, team: Color, faction: String, facing: float, anim: float) -> void:
	Sprites._xf(ci, Vector2(2.5, 3), facing, Vector2.ONE)
	_rect_c(ci, 0, 0, 32, 22, SHADOW)
	Sprites._xf(ci, Vector2.ZERO, facing, Vector2.ONE)
	_draw_tracks(ci, 31, 22, anim)
	var hull := hull_color(team, faction)
	_rect_c(ci, -2, 0, 25, 15, hull)
	_rect_c(ci, 11, 0, 6, 14, hull.lightened(0.15))
	_rect_c(ci, 12.5, 0, 2, 11, Color(0.55, 0.75, 0.85, 0.9))
	_rect_c(ci, -5, 0, 14, 9, CONCRETE_C)
	ci.draw_line(Vector2(-11, -3), Vector2(6, 3), Color(0.85, 0.7, 0.2), 2.0)
	ci.draw_line(Vector2(-11, 3), Vector2(6, -3), Color(0.85, 0.7, 0.2), 1.0)
	ci.draw_circle(Vector2(-10, 0), 2.5, team)

# ---------------------------------------------------------------- buildings

## Draws a building with its top-left corner at the origin. `progress` < 1 shows construction.
static func draw_building(ci: CanvasItem, sprite: String, size: Vector2i, team: Color, faction: String, progress: float, anim: float, turret: float = 0.0, damage: float = 0.0, extra: float = 0.0) -> void:
	var T := 32.0
	var W := size.x * T
	var H := size.y * T
	var conc := CONCRETE_C if faction == "coalition" else CONCRETE_D
	if progress < 1.0:
		# Foundation and scaffolding while the structure rises from the ground.
		ci.draw_rect(Rect2(2, 2, W - 4, H - 4), conc.darkened(0.25))
		Sprites._xf(ci, Vector2(0, H * (1.0 - progress)), 0.0, Vector2(1.0, maxf(progress, 0.05)))
	ci.draw_rect(Rect2(4, 6, W - 4, H - 4), SHADOW)
	match sprite:
		"conyard": _b_conyard(ci, W, H, team, conc, anim)
		"power": _b_power(ci, W, H, team, conc, anim, 2)
		"adv_power": _b_power(ci, W, H, team, conc, anim, 3)
		"refinery": _b_refinery(ci, W, H, team, conc, anim, extra)
		"silo": _b_silo(ci, W, H, team, conc, extra)
		"barracks": _b_barracks(ci, W, H, team, conc)
		"barracks_dom": _b_barracks_dom(ci, W, H, team, conc)
		"factory": _b_factory(ci, W, H, team, conc, anim)
		"radar": _b_radar(ci, W, H, team, conc, anim)
		"pillbox": _b_pillbox(ci, W, H, team, conc)
		"gun_turret": _b_gun_turret(ci, W, H, team, conc, turret)
		"flame_tower": _b_flame_tower(ci, W, H, team, conc, turret)
		"arc_coil": _b_arc_coil(ci, W, H, team, conc, anim, extra)
		_:
			ci.draw_rect(Rect2(2, 2, W - 4, H - 4), conc)
	Sprites._xf(ci, Vector2.ZERO, 0.0, Vector2.ONE)
	if progress < 1.0:
		var sc := Color(0.85, 0.7, 0.25, 0.9)
		var x := 3.0
		while x < W - 2:
			ci.draw_line(Vector2(x, 3), Vector2(x, H - 3), sc, 1.0)
			x += 8.0
		ci.draw_rect(Rect2(2, 2, W - 4, H - 4), sc, false, 1.5)
	if damage > 0.5:
		_scorch(ci, W, H, damage)

static func _scorch(ci: CanvasItem, W: float, H: float, damage: float) -> void:
	var n := int((damage - 0.5) * 10.0) + 1
	for i in n:
		var px := fposmod(i * 37.0 + 11.0, W - 8.0) + 4.0
		var py := fposmod(i * 23.0 + 7.0, H - 8.0) + 4.0
		ci.draw_circle(Vector2(px, py), 3.0 + (i % 3), Color(0.08, 0.07, 0.06, 0.55))

static func _pad(ci: CanvasItem, W: float, H: float, conc: Color) -> void:
	ci.draw_rect(Rect2(1, 1, W - 2, H - 2), conc.darkened(0.12))
	ci.draw_rect(Rect2(1, 1, W - 2, H - 2), conc.darkened(0.4), false, 1.0)

static func _box(ci: CanvasItem, r: Rect2, col: Color, height: float = 4.0) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(0, height), r.size), col.darkened(0.45))
	ci.draw_rect(r, col)
	ci.draw_line(r.position, r.position + Vector2(r.size.x, 0), col.lightened(0.25), 1.0)

static func _b_conyard(ci, W, H, team, conc, anim) -> void:
	_pad(ci, W, H, conc)
	_box(ci, Rect2(10, 14, W - 20, H - 34), conc.lightened(0.05), 6)
	_box(ci, Rect2(16, 20, W - 32, 18), team.darkened(0.2), 3)
	for i in 4:
		ci.draw_rect(Rect2(W - 30 + i * 5, H - 22, 3, 10), Color(0.9, 0.75, 0.2))
	var base := Vector2(W * 0.3, H * 0.62)
	var arm = Vector2.RIGHT.rotated(sin(anim * 0.6) * 1.2 - 0.6) * (W * 0.45)
	ci.draw_circle(base, 5, Color(0.85, 0.7, 0.2))
	ci.draw_line(base, base + arm, Color(0.85, 0.7, 0.2), 3.0)
	ci.draw_line(base + arm, base + arm + Vector2(0, 8), Color(0.2, 0.2, 0.2), 1.0)

static func _b_power(ci, W, H, team, conc, anim, towers) -> void:
	_pad(ci, W, H, conc)
	_box(ci, Rect2(4, H * 0.55, W - 8, H * 0.38), conc.darkened(0.05), 3)
	ci.draw_rect(Rect2(6, H * 0.62, W - 12, 4), team.darkened(0.1))
	for i in towers:
		var c := Vector2(W * (i + 0.5) / towers, H * 0.36)
		var r := minf(W / towers * 0.42, 15.0)
		ci.draw_circle(c + Vector2(2, 3), r, Sprites.SHADOW)
		ci.draw_circle(c, r, conc.lightened(0.1))
		ci.draw_circle(c, r * 0.65, conc.darkened(0.35))
		var puff := fposmod(anim * 0.8 + i * 0.37, 1.0)
		ci.draw_circle(c + Vector2(puff * 6, -puff * 10), r * 0.4 * (1.0 - puff * 0.5), Color(0.9, 0.9, 0.9, 0.35 * (1.0 - puff)))

static func _b_refinery(ci, W, H, team, conc, anim, extra) -> void:
	_pad(ci, W, H, conc)
	_box(ci, Rect2(4, 6, W * 0.62, H * 0.56), conc.lightened(0.05), 6)
	ci.draw_rect(Rect2(8, 12, W * 0.62 - 8, 8), team.darkened(0.15))
	var sc := Vector2(W * 0.8, H * 0.32)
	ci.draw_circle(sc + Vector2(2, 3), 13, Sprites.SHADOW)
	ci.draw_circle(sc, 13, Color(0.72, 0.6, 0.3))
	ci.draw_circle(sc, 9, Color(0.82, 0.68, 0.32))
	# Dock ramp in the open bottom-middle cell.
	ci.draw_rect(Rect2(32, 64, 32, 32), Color(0.28, 0.27, 0.25))
	for i in 4:
		ci.draw_line(Vector2(34, 68 + i * 7), Vector2(62, 68 + i * 7), Color(0.85, 0.7, 0.2, 0.8), 1.5)
	ci.draw_rect(Rect2(40, H * 0.56, 16, 14), Sprites.STEEL)
	if extra > 0.0:
		ci.draw_circle(Vector2(48, 80), 4 + 3 * sin(anim * 8.0), Color(1, 0.8, 0.3, 0.6))

static func _b_silo(ci, W, H, team, conc, extra) -> void:
	_pad(ci, W, H, conc)
	var c := Vector2(W * 0.5, H * 0.45)
	ci.draw_circle(c + Vector2(2, 3), 12, Sprites.SHADOW)
	ci.draw_circle(c, 12, conc.lightened(0.15))
	ci.draw_arc(c, 8, -PI, -PI + TAU * clampf(extra, 0.0, 1.0), 20, Color(0.85, 0.68, 0.28), 4.0)
	ci.draw_circle(c, 4, team)

static func _b_barracks(ci, W, H, team, conc) -> void:
	_pad(ci, W, H, conc)
	for i in 2:
		var r := Rect2(5 + i * (W * 0.5 - 2), 6, W * 0.5 - 8, H - 22)
		_box(ci, r, Color(0.45, 0.5, 0.36), 3)
		ci.draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.end.y), Color(0.32, 0.36, 0.25), 2.0)
	ci.draw_rect(Rect2(4, H - 14, W - 8, 8), team.darkened(0.1))
	ci.draw_rect(Rect2(W * 0.5 - 5, H - 14, 10, 8), Color(0.15, 0.15, 0.15))

static func _b_barracks_dom(ci, W, H, team, conc) -> void:
	_pad(ci, W, H, conc)
	_box(ci, Rect2(5, 5, W - 10, H - 20), conc.darkened(0.08), 5)
	ci.draw_rect(Rect2(10, 10, W - 20, 6), team.darkened(0.15))
	var c := Vector2(W * 0.5, H * 0.45)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]), team)
	ci.draw_rect(Rect2(W * 0.5 - 6, H - 15, 12, 9), Color(0.12, 0.12, 0.12))

static func _b_factory(ci, W, H, team, conc, anim) -> void:
	_pad(ci, W, H, conc)
	_box(ci, Rect2(4, 4, W - 8, H - 22), conc.lightened(0.02), 7)
	var x := 10.0
	while x < W - 10:
		ci.draw_line(Vector2(x, 8), Vector2(x, H - 22), conc.darkened(0.25), 1.0)
		x += 9.0
	ci.draw_rect(Rect2(4, 4, W - 8, 8), team.darkened(0.15))
	ci.draw_rect(Rect2(W * 0.5 - 18, H - 22, 36, 18), Color(0.2, 0.2, 0.2))
	for i in 4:
		ci.draw_line(Vector2(W * 0.5 - 18, H - 19 + i * 4), Vector2(W * 0.5 + 18, H - 19 + i * 4), Color(0.4, 0.4, 0.38), 1.0)
	ci.draw_circle(Vector2(12, H - 12), 2.5, Color(1, 0.6, 0.1) if fposmod(anim, 1.0) < 0.5 else Color(0.4, 0.2, 0.05))

static func _b_radar(ci, W, H, team, conc, anim) -> void:
	_pad(ci, W, H, conc)
	_box(ci, Rect2(6, H * 0.5, W - 12, H * 0.42), conc, 3)
	var c := Vector2(W * 0.5, H * 0.42)
	ci.draw_circle(c, 4, Color(0.3, 0.3, 0.3))
	var a = anim * 1.4
	var d := Vector2.RIGHT.rotated(a)
	var n := d.orthogonal()
	var pts := PackedVector2Array([c - n * 14 - d * 2, c + n * 14 - d * 2, c + n * 10 + d * 6, c - n * 10 + d * 6])
	ci.draw_colored_polygon(pts, Color(0.85, 0.87, 0.88))
	ci.draw_line(c, c + d * 10, team, 2.0)

static func _b_pillbox(ci, W, H, team, conc) -> void:
	var c := Vector2(W * 0.5, H * 0.5)
	var pts := PackedVector2Array()
	for i in 6:
		pts.append(c + Vector2.RIGHT.rotated(i * TAU / 6.0) * 14.0)
	ci.draw_colored_polygon(pts, conc.darkened(0.1))
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), conc.darkened(0.45), 1.5)
	ci.draw_circle(c, 7, conc.lightened(0.1))
	ci.draw_rect(Rect2(c.x - 6, c.y - 1.5, 12, 3), Color(0.1, 0.1, 0.1))
	ci.draw_circle(c, 2.5, team)

static func _b_gun_turret(ci, W, H, team, conc, turret) -> void:
	_pad(ci, W, H, conc)
	var c := Vector2(W * 0.5, H * 0.5)
	ci.draw_circle(c, 12, conc.darkened(0.25))
	Sprites._xf(ci, c, turret, Vector2.ONE)
	ci.draw_rect(Rect2(4, -2, 15, 4), Color(0.18, 0.18, 0.18))
	ci.draw_circle(Vector2.ZERO, 8, Sprites.STEEL)
	ci.draw_circle(Vector2(-2, 0), 3, team)
	Sprites._xf(ci, Vector2.ZERO, 0.0, Vector2.ONE)

static func _b_flame_tower(ci, W, H, team, conc, turret) -> void:
	_pad(ci, W, H, conc)
	var c := Vector2(W * 0.5, H * 0.5)
	ci.draw_circle(c + Vector2(2, 3), 11, Sprites.SHADOW)
	ci.draw_circle(c, 11, conc.darkened(0.05))
	ci.draw_circle(c, 7, Color(0.5, 0.18, 0.1))
	Sprites._xf(ci, c, turret, Vector2.ONE)
	ci.draw_rect(Rect2(3, -2, 10, 4), Color(0.2, 0.2, 0.2))
	ci.draw_circle(Vector2(13, 0), 2, Color(1, 0.55, 0.1))
	Sprites._xf(ci, Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(c, 2.5, team)

static func _b_arc_coil(ci, W, H, team, conc, anim, charge) -> void:
	_pad(ci, W, H, conc)
	var c := Vector2(W * 0.5, H * 0.62)
	ci.draw_circle(c + Vector2(3, 4), 12, Sprites.SHADOW)
	ci.draw_circle(c, 12, conc.darkened(0.2))
	for i in 4:
		ci.draw_arc(c - Vector2(0, i * 8), 9 - i * 1.5, 0, TAU, 16, Color(0.75, 0.55, 0.3), 2.0)
	var top := c - Vector2(0, 32)
	ci.draw_circle(top, 6, Color(0.3, 0.3, 0.35))
	var glow := 0.3 + 0.7 * clampf(charge, 0.0, 1.0)
	ci.draw_circle(top, 4, Color(0.55, 0.8, 1.0, glow))
	ci.draw_circle(c, 3, team)

# ---------------------------------------------------------------- ore

static func draw_ore(ci: CanvasItem, origin: Vector2, stage: int, kind: int, seed_v: int) -> void:
	var col := Color(0.86, 0.68, 0.22) if kind == 1 else Color(0.35, 0.75, 0.95)
	var dark := col.darkened(0.45)
	var n := stage * 3
	for i in n:
		var h := (seed_v * 73856093 + i * 19349663) & 0xffff
		var px := origin.x + 4 + float(h % 24)
		var py := origin.y + 4 + float((h >> 5) % 24)
		var r := 2.0 + float((h >> 9) % 3)
		ci.draw_circle(Vector2(px + 1, py + 1), r, dark)
		ci.draw_circle(Vector2(px, py), r, col)
