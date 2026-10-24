class_name Entity
extends Node2D
## Base class for units and buildings: ownership, health, armor, damage and death.

var game = null
var uid: int = 0
var type: String = ""
var def: Dictionary = {}
var pid: int = 0
var hp: float = 100.0
var max_hp: float = 100.0
var armor: String = "none"
var pos: Vector2 = Vector2.ZERO
var radius: float = 8.0
var sight: int = 4
var dead: bool = false
var selected: bool = false
var hovered: bool = false
var invulnerable: bool = false
var last_attacker_uid: int = 0
var last_damaged_time: float = -100.0
var hit_flash: float = 0.0
var seen_by_human: bool = false

func init_entity(g, t: String, owner_pid: int) -> void:
	game = g
	type = t
	def = Data.def(t)
	pid = owner_pid
	max_hp = float(def.get("hp", 100))
	hp = max_hp
	armor = def.get("armor", "none")
	sight = int(def.get("sight", 4))

func player():
	return game.players[pid]

func team_color() -> Color:
	return game.players[pid].color

func is_unit() -> bool:
	return false

func is_building() -> bool:
	return false

func is_air() -> bool:
	return false

func is_enemy(other) -> bool:
	if other == null or other.pid == pid:
		return false
	return game.players[other.pid].team != game.players[pid].team

func hp_ratio() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)

func cell() -> Vector2i:
	return MapGrid.to_cell(pos)

## Distance from a point to this entity's edge (used for weapon range checks).
func edge_distance(p: Vector2) -> float:
	return maxf(0.0, pos.distance_to(p) - radius)

func take_damage(amount: float, attacker) -> void:
	if dead or amount <= 0.0:
		return
	if invulnerable:
		return
	amount *= player().bonus("armor", def.get("category", ""))
	hp -= amount
	hit_flash = 0.12
	last_damaged_time = game.sim_time
	if attacker != null and is_instance_valid(attacker):
		last_attacker_uid = attacker.uid
	game.on_entity_damaged(self, attacker)
	if hp <= 0.0:
		hp = 0.0
		die(attacker)

func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)

func set_health(v: float) -> void:
	hp = clampf(v, 1.0, max_hp)
	queue_redraw()

func die(killer) -> void:
	if dead:
		return
	dead = true
	game.on_entity_died(self, killer)

func draw_health_bar(width: float, y: float) -> void:
	var r := hp_ratio()
	var col := Color(0.2, 0.85, 0.3) if r > 0.6 else (Color(0.95, 0.8, 0.2) if r > 0.3 else Color(0.9, 0.2, 0.15))
	draw_rect(Rect2(-width * 0.5 - 1, y - 1, width + 2, 5), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-width * 0.5, y, width * r, 3), col)
	if invulnerable:
		draw_rect(Rect2(-width * 0.5 - 1, y - 1, width + 2, 5), Color(0.6, 0.9, 1.0), false, 1.0)

func base_dict() -> Dictionary:
	return {"uid": uid, "type": type, "pid": pid, "hp": hp, "x": pos.x, "y": pos.y, "inv": invulnerable, "seen": seen_by_human}

func apply_base_dict(d: Dictionary) -> void:
	uid = int(d.uid)
	hp = float(d.hp)
	pos = Vector2(float(d.x), float(d.y))
	invulnerable = bool(d.get("inv", false))
	seen_by_human = bool(d.get("seen", false))
