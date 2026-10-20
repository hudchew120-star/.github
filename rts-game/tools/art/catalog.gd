extends RefCounted
## Named model sets for tools/showcase.gd (design previews and the catalogue sheet).

const H := preload("res://tools/art/humans.gd")
const V := preload("res://tools/art/vehicles.gd")
const HB := preload("res://tools/art/hd_buildings.gd")
const HM := preload("res://tools/art/hd_models.gd")

## Model id for a unit sprite (see data/units.json) and faction.
static func unit_model(sprite: String, f: String) -> Node3D:
	match sprite:
		"infantry", "rocket_inf", "heavy_inf", "flame_inf", "engineer":
			return H.soldier(sprite, f, {})
		"tank_light": return _veh(V.light_tank(), 0.0)
		"tank_medium": return _veh(V.medium_tank(), 0.0)
		"tank_heavy": return _veh(V.heavy_tank(), 0.0)
		"jeep": return _veh(V.jeep(), 0.0)
		"harvester": return _veh(V.harvester(f, 1.0), 0.0)
		"mcv": return _veh(V.mcv(f), 0.0)
		"aa": return _veh(V.aa_coalition() if f == "coalition" else V.aa_dominion(), 0.0)
		"heli": return _veh(V.heli_coalition() if f == "coalition" else V.heli_dominion(), 0.0)
		"jet": return _veh(V.jet_coalition() if f == "coalition" else V.jet_dominion(), 0.0)
		"gunboat": return _veh(V.boat_coalition(), 0.0)
		"destroyer": return _veh(V.destroyer_coalition(), 0.0)
		"submarine": return _veh(V.sub_dominion(), 0.0)
		"cruiser": return _veh(V.cruiser_dominion(), 0.0)
	return Node3D.new()

static func building_model(sprite: String, f: String) -> Node3D:
	var d: Dictionary = HB.build(sprite, f)
	var root: Node3D = d.root
	if d.has("pivot"):
		var P := HM.pal(f)
		var t: Node3D
		if d.has("top"):
			t = d.top.call(P, f)
		elif sprite == "gun_turret":
			t = HB.gun_turret_top(P, f)
		else:
			t = HB.flame_turret_top(P, f)
		t.position = d.pivot
		t.rotation_degrees.y = -20.0
		root.add_child(t)
	return root

static func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func _veh(d: Dictionary, deg: float) -> Node3D:
	var root: Node3D = d.root
	if d.turret != null:
		d.turret.position = d.pivot
		root.add_child(d.turret)
	return _rot(root, deg)

const VEHICLES := [
	["light_tank", "coalition", "Lynx light tank", 1.0], ["medium_tank", "coalition", "Paladin battle tank", 1.0], ["jeep", "coalition", "Ranger utility vehicle", 0.8],
	["aa_coalition", "coalition", "Skyguard AA", 1.0], ["harv_c", "coalition", "Mining truck", 1.1], ["mcv_c", "coalition", "Construction vehicle", 1.2],
	["heavy_tank", "dominion", "Mammoth heavy tank", 1.2], ["aa_dominion", "dominion", "Volga SAM carrier", 1.1], ["harv_d", "dominion", "Strip miner", 1.1], ["mcv_d", "dominion", "Construction crawler", 1.2],
]
const AIR := [
	["heli_coalition", "coalition", "Hawk attack helicopter", 1.4], ["jet_coalition", "coalition", "Falcon stealth fighter", 1.2],
	["heli_dominion", "dominion", "Krait gunship", 1.6], ["jet_dominion", "dominion", "Sokol strike fighter", 1.3],
]
const SHIPS := [
	["boat_coalition", "coalition", "Patrol gunboat", 1.0], ["destroyer_coalition", "coalition", "Guardian destroyer", 2.0],
	["sub_dominion", "dominion", "Akula submarine", 1.5], ["cruiser_dominion", "dominion", "Kirov battlecruiser", 2.2],
]

static func vehicle_model(id: String) -> Dictionary:
	match id:
		"harv_c": return V.harvester("coalition", 1.0)
		"harv_d": return V.harvester("dominion", 1.0)
		"mcv_c": return V.mcv("coalition")
		"mcv_d": return V.mcv("dominion")
		"light_tank": return V.light_tank()
		"medium_tank": return V.medium_tank()
		"jeep": return V.jeep()
		"aa_coalition": return V.aa_coalition()
		"heavy_tank": return V.heavy_tank()
		"aa_dominion": return V.aa_dominion()
		"heli_coalition": return V.heli_coalition()
		"heli_dominion": return V.heli_dominion()
		"jet_coalition": return V.jet_coalition()
		"jet_dominion": return V.jet_dominion()
		"boat_coalition": return V.boat_coalition()
		"destroyer_coalition": return V.destroyer_coalition()
		"sub_dominion": return V.sub_dominion()
		"cruiser_dominion": return V.cruiser_dominion()
	return {}

static func showcase_cols(set_name: String) -> int:
	return {"infantry": 7, "poses": 7, "closeup": 5, "vehicles": 5, "air": 4, "ships": 4}.get(set_name, 6)

static func _rot(n: Node3D, deg: float) -> Node3D:
	var w := Node3D.new()
	n.rotation_degrees.y = deg
	w.add_child(n)
	return w

static func showcase_set(set_name: String) -> Array:
	var out := []
	var BLUE := Color(0.25, 0.48, 0.85)
	var RED := Color(0.78, 0.2, 0.15)
	match set_name:
		"infantry":
			for e in [["infantry", "coalition", "Rifleman"], ["rocket_inf", "coalition", "Rocket trooper"], ["engineer", "coalition", "Engineer"],
					["infantry", "dominion", "Conscript"], ["heavy_inf", "dominion", "RPG trooper"], ["flame_inf", "dominion", "Flame trooper"], ["engineer", "dominion", "Combat engineer"]]:
				var k: String = e[0]
				var f: String = e[1]
				out.append({"label": e[2], "w": 0.5, "h": 0.6, "focus": Vector3(0, 0.2, 0), "team": BLUE if f == "coalition" else RED,
					"build": func(): return _rot(H.soldier(k, f, {}), -60.0)})
		"vehicles", "air", "ships":
			var lst: Array = VEHICLES if set_name == "vehicles" else (AIR if set_name == "air" else SHIPS)
			for e in lst:
				var id: String = e[0]
				var sz: float = e[3]
				out.append({"label": e[2], "w": sz * 1.2, "h": sz * 0.9, "focus": Vector3(0, 0.15, 0), "team": BLUE if e[1] == "coalition" else RED,
					"build": func(): return _veh(vehicle_model(id), -20.0)})
		"cameos":
			var units := _json("res://data/units.json")
			var blds := _json("res://data/buildings.json")
			for f in ["coalition", "dominion"]:
				for t in units:
					if not units[t].factions.has(f):
						continue
					var sp: String = units[t].sprite
					var ff: String = f
					var inf: bool = units[t].category == "infantry"
					out.append({"label": "%s_%s" % [t, f], "w": 0.96, "h": 0.76, "fit": true, "margin": 1.0 if inf else 1.08, "team": BLUE if f == "coalition" else RED,
						"build": func(): return _rot(unit_model(sp, ff), -70.0 if inf else -25.0)})
				for t in blds:
					if not blds[t].factions.has(f):
						continue
					var sp: String = blds[t].sprite
					var ff: String = f
					out.append({"label": "%s_%s" % [t, f], "w": 0.96, "h": 0.76, "fit": true, "margin": 1.04, "team": BLUE if f == "coalition" else RED,
						"build": func(): return building_model(sp, ff)})
		"closeup":
			for f in ["coalition", "dominion"]:
				for ang in [0.0, -45.0, -90.0, -135.0, 180.0]:
					var ff: String = f
					var a: float = ang
					out.append({"label": "", "w": 0.32, "h": 0.5, "focus": Vector3(0, 0.2, 0), "team": BLUE if f == "coalition" else RED,
						"build": func(): return _rot(H.soldier("infantry", ff, {}), a)})
		"poses":
			for f in ["coalition", "dominion"]:
				for p in [{}, {"walk": 0.0}, {"walk": 0.17}, {"walk": 0.5}, {"fire": 1}, {"fire": 2}, {"dead": 1.0}]:
					var pp: Dictionary = p
					var ff: String = f
					out.append({"label": str(p), "w": 0.5, "h": 0.6, "focus": Vector3(0, 0.2, 0), "team": BLUE if f == "coalition" else RED,
						"build": func(): return _rot(H.soldier("infantry", ff, pp), -90.0)})
	return out
