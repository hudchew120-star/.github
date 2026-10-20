class_name Player
extends RefCounted
## One side in a match: money, stored resources, power, technology and vision.

const MAX_VALUE := 999_999_999_999   # hard ceiling for all balances; never overflows int64

var id: int = 0
var name: String = ""
var faction: String = "coalition"
var color: Color = Color.WHITE
var team: int = 0
var is_human: bool = false
var difficulty: String = "normal"
var defeated: bool = false

var cash: int = 0                     # spendable money not limited by storage
var resources := {"ore": 0, "gems": 0} # harvested resources, limited by storage capacity
var storage_cap: int = 0
var power_prod: int = 0
var power_use: int = 0
var power_bonus: int = 0              # cheat-provided power
var tech := {}                        # provided tag -> count of completed buildings
var primary := {}                     # production category -> building uid
var stats := {"spent_build": 0, "spent_units": 0, "harvested": 0, "units_lost": 0, "units_killed": 0, "buildings_lost": 0}
var vis := PackedByteArray()          # fog: 0 unexplored, 1 explored, 2 visible
var game = null

func credits() -> int:
	var t := cash
	for k in resources:
		t += int(resources[k])
	return mini(t, MAX_VALUE)

func stored_resources() -> int:
	var t := 0
	for k in resources:
		t += int(resources[k])
	return t

func can_afford(amount: int) -> bool:
	return credits() >= amount

## Spend from stored resources first (like classic silos), then cash. Returns false if not enough.
func spend(amount: int, kind: String = "build") -> bool:
	if amount <= 0:
		return true
	if credits() < amount:
		return false
	var left := amount
	for k in ["ore", "gems"]:
		var take := mini(int(resources[k]), left)
		resources[k] = int(resources[k]) - take
		left -= take
	cash -= left
	if kind == "build":
		stats.spent_build += amount
	else:
		stats.spent_units += amount
	return true

func add_cash(amount: int) -> void:
	cash = clampi(cash + amount, 0, MAX_VALUE)

func unlimited_storage() -> bool:
	return game != null and game.cheats != null and game.cheats.flag(id, "unlimited_storage")

## Deposits harvested resources, respecting storage capacity. Returns the amount accepted.
func deposit(kind: String, amount: int) -> int:
	var room := MAX_VALUE - credits()
	if not unlimited_storage():
		room = mini(room, storage_cap - stored_resources())
	var accepted := clampi(amount, 0, maxi(room, 0))
	resources[kind] = int(resources.get(kind, 0)) + accepted
	stats.harvested += accepted
	return accepted

func set_resource(kind: String, value: int) -> void:
	resources[kind] = clampi(value, 0, MAX_VALUE)

func power_total() -> int:
	return power_prod + power_bonus

func power_ratio() -> float:
	if game != null and not game.power_enabled(id):
		return 1.0
	if power_use <= 0:
		return 1.0
	return clampf(float(power_total()) / float(power_use), 0.0, 1.0)

func low_power() -> bool:
	return power_ratio() < 1.0

func has_tech(tags: Array) -> bool:
	for t in tags:
		if int(tech.get(t, 0)) <= 0:
			return false
	return true

func missing_tech(tags: Array) -> Array:
	var out := []
	for t in tags:
		if int(tech.get(t, 0)) <= 0:
			out.append(t)
	return out

## Recalculate power, storage and technology from completed buildings.
func recompute(buildings: Array) -> void:
	power_prod = 0
	power_use = 0
	storage_cap = 0
	tech.clear()
	for b in buildings:
		if b.dead or b.pid != id or not b.completed:
			continue
		var p := int(b.def.get("power", 0))
		if p > 0:
			power_prod += int(round(p * b.hp_ratio_power()))
		else:
			power_use += -p
		storage_cap += int(b.def.get("storage", 0))
		for t in b.def.get("provides", []):
			tech[t] = int(tech.get(t, 0)) + 1

func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "faction": faction, "color": color.to_html(), "team": team,
		"is_human": is_human, "difficulty": difficulty, "defeated": defeated,
		"cash": cash, "resources": resources.duplicate(), "power_bonus": power_bonus,
		"primary": primary.duplicate(), "stats": stats.duplicate(),
		"vis": Marshalls.raw_to_base64(vis),
	}

func from_dict(d: Dictionary) -> void:
	id = int(d.id)
	name = d.name
	faction = d.faction
	color = Color(d.color)
	team = int(d.team)
	is_human = bool(d.is_human)
	difficulty = d.get("difficulty", "normal")
	defeated = bool(d.get("defeated", false))
	cash = int(d.cash)
	resources = {}
	for k in d.resources:
		resources[k] = int(d.resources[k])
	power_bonus = int(d.get("power_bonus", 0))
	primary = {}
	for k in d.get("primary", {}):
		primary[k] = int(d.primary[k])
	for k in d.get("stats", {}):
		stats[k] = int(d.stats[k])
	vis = Marshalls.base64_to_raw(d.get("vis", ""))
