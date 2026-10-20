class_name Combat
extends RefCounted
## Weapon firing, armor/warhead damage calculation and splash damage.

static func roll_damage(w: Dictionary) -> float:
	var d = w.get("damage", 10)
	if d is Array:
		return randf_range(float(d[0]), float(d[1]))
	return float(d)

## Target classes: "air", "sub" (submerged submarine), "naval" (ships), "ground" (land and ships).
static func target_class(t) -> String:
	if t.is_air():
		return "air"
	if t.is_unit():
		if t.submarine and t.submerged():
			return "sub"
		if t.is_naval:
			return "naval"
	return "ground"

static func can_target(w: Dictionary, t) -> bool:
	var targets: Array = w.get("targets", ["ground"])
	var c := target_class(t)
	if targets.has(c):
		return true
	if c == "naval" and targets.has("ground"):
		return true
	return false

## Final damage against a target after armor, terrain cover and cheat modifiers.
static func damage_against(w: Dictionary, t, base: float) -> float:
	var mult := Data.warhead_mult(w.get("warhead", "SA"), t.armor)
	var dmg := base * mult
	if t.is_unit() and t.is_infantry():
		var cover := float(t.game.map.terrain_def(t.cell()).get("cover", 0.0))
		dmg *= 1.0 - cover
	return dmg

static func fire(game, shooter, w: Dictionary, t) -> void:
	if t == null or not is_instance_valid(t) or t.dead:
		return
	var from: Vector2 = shooter.pos
	var muzzle = from + (t.pos - from).normalized() * shooter.radius
	var h: float = shooter.altitude_now if shooter.is_unit() and shooter.is_air_unit else 0.0
	var kind: String = w.get("projectile", "bullet")
	game.play_sound(w.get("sound", ""), from)
	if kind == "bullet" or kind == "zap":
		var hit := randf() <= float(w.get("accuracy", 1.0))
		var impact: Vector2 = t.pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))
		if not hit:
			impact += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(8, 18)
		var th: float = t.altitude_now if t.is_unit() and t.is_air_unit else 0.0
		game.spawn_effect("zap" if kind == "zap" else "tracer", muzzle, {"to": impact, "h": h, "th": th})
		if kind == "bullet":
			game.spawn_effect("muzzle", muzzle, {"angle": (t.pos - from).angle(), "h": h})
		if hit:
			t.take_damage(damage_against(w, t, roll_damage(w)), shooter)
			if float(w.get("splash", 0.0)) > 0.0:
				splash(game, impact, w, shooter, t)
		if kind == "zap":
			game.spawn_effect("spark", impact)
		return
	var target_pos: Vector2 = t.pos
	if randf() > float(w.get("accuracy", 1.0)):
		target_pos += Vector2.RIGHT.rotated(randf() * TAU) * randf_range(10, 26)
	game.spawn_projectile(shooter, w, t, muzzle, target_pos)
	if kind == "shell":
		game.spawn_effect("muzzle", muzzle, {"angle": (t.pos - from).angle(), "big": true, "h": h})

## Called when a projectile arrives.
static func detonate(game, p: Vector2, w: Dictionary, shooter, direct) -> void:
	var kind: String = w.get("projectile", "shell")
	if direct != null and is_instance_valid(direct) and not direct.dead and direct.edge_distance(p) <= 6.0:
		direct.take_damage(damage_against(w, direct, roll_damage(w)), shooter)
	splash(game, p, w, shooter, direct)
	var fx := "explosion_small"
	if kind == "flame":
		fx = "flame_burst"
	elif float(w.get("splash", 0.0)) >= 0.8:
		fx = "explosion"
	var eh: float = direct.altitude_now if direct != null and is_instance_valid(direct) and direct.is_unit() and direct.is_air_unit else 0.0
	game.spawn_effect(fx, p, {"h": eh})

static func splash(game, p: Vector2, w: Dictionary, shooter, exclude) -> void:
	var r := float(w.get("splash", 0.0)) * MapGrid.T
	if r <= 0.0:
		return
	var shooter_pid: int = shooter.pid if shooter != null and is_instance_valid(shooter) else -1
	for e in game.entities_near(p, r + 16.0):
		if e == exclude or e.dead:
			continue
		if shooter_pid >= 0 and not game.are_enemies(shooter_pid, e.pid):
			continue
		var d: float = e.edge_distance(p)
		if d > r:
			continue
		var falloff := lerpf(0.75, 0.25, d / r)
		var src = shooter if shooter != null and is_instance_valid(shooter) else null
		e.take_damage(damage_against(w, e, roll_damage(w)) * falloff, src)
