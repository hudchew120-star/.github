extends Node
## Loads all editable balance data (units, buildings, weapons, terrain...) from res://data.

var terrain_cfg: Dictionary = {}
var terrain: Dictionary = {}
var terrain_ids: Array = []           # index -> terrain id
var terrain_index: Dictionary = {}    # terrain id -> index
var resources: Dictionary = {}
var units: Dictionary = {}
var buildings: Dictionary = {}
var weapons: Dictionary = {}
var warheads: Dictionary = {}
var factions: Dictionary = {}
var countries: Dictionary = {}
var ai: Dictionary = {}
var tile_size: int = 32

func _ready() -> void:
	load_all()

func load_all() -> void:
	terrain_cfg = _load_json("res://data/terrain.json")
	terrain = terrain_cfg.get("types", {})
	resources = terrain_cfg.get("resources", {})
	tile_size = int(terrain_cfg.get("tile_size", 32))
	terrain_ids = terrain.keys()
	terrain_index.clear()
	for i in terrain_ids.size():
		terrain_index[terrain_ids[i]] = i
	units = _load_json("res://data/units.json")
	buildings = _load_json("res://data/buildings.json")
	weapons = _load_json("res://data/weapons.json")
	warheads = _load_json("res://data/warheads.json")
	factions = _load_json("res://data/factions.json")
	countries = _load_json("res://data/countries.json")
	for k in countries:
		countries[k]["id"] = k
	ai = _load_json("res://data/ai.json")
	for k in units:
		units[k]["id"] = k
		units[k]["kind"] = "unit"
	for k in buildings:
		buildings[k]["id"] = k
		buildings[k]["kind"] = "building"
		var fp: Array = buildings[k].get("footprint", ["x"])
		buildings[k]["size"] = Vector2i(String(fp[0]).length(), fp.size())

func _load_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data file: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON in " + path)
		return {}
	return parsed

func def(type: String) -> Dictionary:
	if units.has(type):
		return units[type]
	return buildings.get(type, {})

func is_building(type: String) -> bool:
	return buildings.has(type)

func exists(type: String) -> bool:
	return units.has(type) or buildings.has(type)

func available_for(type: String, faction: String, country: String = "") -> bool:
	return allowed(def(type), faction, country)

## True when a side (and, for country-specific items, a country) may use a definition.
## An empty country means "any country of the side" (used when listing art to load).
func allowed(d: Dictionary, faction: String, country: String = "") -> bool:
	if not d.get("factions", []).has(faction):
		return false
	if d.has("countries") and country != "" and not d.countries.has(country):
		return false
	return true

## All buildable types in a production category for a faction, in data order.
func types_in_category(category: String, faction: String, country: String = "") -> Array:
	var out := []
	var src: Dictionary = buildings if (category == "building" or category == "defense") else units
	for k in src:
		var d: Dictionary = src[k]
		if d.get("category", "") == category and allowed(d, faction, country) and d.get("buildable", true):
			out.append(k)
	return out

## Countries of a side in data order.
func countries_of(faction: String) -> Array:
	var out := []
	for k in countries:
		if countries[k].side == faction:
			out.append(k)
	return out

## The country used when only a side is known (old saves, quick matches).
func default_country(faction: String) -> String:
	for k in countries:
		if countries[k].side == faction and countries[k].get("default", false):
			return k
	var l := countries_of(faction)
	return l[0] if l.size() > 0 else ""

## A country's bonus multiplier, e.g. bonus("germany", "armor", "vehicle") -> 0.9.
func country_bonus(country: String, kind: String, category: String) -> float:
	return float(countries.get(country, {}).get("bonus", {}).get(kind, {}).get(category, 1.0))

## Finds the faction's building type that provides a tech tag (e.g. "barracks").
func building_for_tag(faction: String, tag: String) -> String:
	for k in buildings:
		var d: Dictionary = buildings[k]
		if d.get("buildable", true) and d.get("factions", []).has(faction) and d.get("provides", []).has(tag):
			return k
	return ""

func weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

func warhead_mult(warhead: String, armor: String) -> float:
	return float(warheads.get(warhead, {}).get("vs", {}).get(armor, 1.0))

func terrain_def_by_index(i: int) -> Dictionary:
	return terrain[terrain_ids[i]]

func faction_color(faction: String) -> Color:
	return Color(factions.get(faction, {}).get("color", "#888888"))
