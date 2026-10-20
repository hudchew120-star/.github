class_name Cheats
extends RefCounted
## Developer cheat system. Every command modifies the real simulation state.
## Used by both the text console and the graphical cheat panel.

const PLAYER_FLAGS := ["instant_build", "instant_units", "free_build", "free_units", "unlimited_queue",
	"no_prereq", "instant_deploy", "instant_repair", "unlimited_storage", "no_depletion",
	"auto_repair_units", "auto_repair_buildings", "build_anywhere"]
const GLOBAL_FLAGS := ["reveal_map", "no_fog", "reveal_enemies", "freeze_enemies", "ai_disabled", "no_power"]
const FLAG_LABELS := {
	"instant_build": "Instant building construction", "instant_units": "Instant unit production",
	"free_build": "Free buildings", "free_units": "Free units", "unlimited_queue": "Unlimited queues",
	"no_prereq": "No prerequisites (all tech unlocked)", "instant_deploy": "Instant structure deployment",
	"instant_repair": "Instant repair", "unlimited_storage": "Unlimited ore storage",
	"no_depletion": "Ore fields never deplete", "auto_repair_units": "Auto-repair units",
	"auto_repair_buildings": "Auto-repair buildings", "build_anywhere": "Build anywhere (ignore build radius)",
	"reveal_map": "Reveal entire map", "no_fog": "Disable fog of war", "reveal_enemies": "Reveal enemy units",
	"freeze_enemies": "Freeze enemy units", "ai_disabled": "Disable enemy AI", "no_power": "Disable power requirements",
}
const DESTRUCTIVE := ["destroy", "remove", "defeat", "kill"]
const MAX_SPAWN := 200

var game = null
var enabled: bool = false
var flags := {}
var persistence: String = "match"      # match, session, saved
var history: Array = []
static var session_flags := {}          # survives restarts during this run of the program

func _init(g) -> void:
	game = g
	reset_flags()

func reset_flags() -> void:
	flags.clear()
	for f in PLAYER_FLAGS + GLOBAL_FLAGS:
		flags[f] = false

func flag(pid: int, name: String) -> bool:
	if not enabled or not flags.get(name, false):
		return false
	if name in GLOBAL_FLAGS:
		return true
	return pid == game.human_pid

func set_flag(name: String, v: bool) -> void:
	if not flags.has(name):
		return
	flags[name] = v
	_after_flag_change(name)
	_persist()

func frozen(pid: int) -> bool:
	return enabled and flags.get("freeze_enemies", false) and game.are_enemies(game.human_pid, pid)

func _after_flag_change(name: String) -> void:
	if name in ["no_power", "no_prereq"]:
		for p in game.players:
			p.recompute(game.buildings)
	if name in ["reveal_map", "no_fog", "reveal_enemies"]:
		game.update_fog(true)

func _persist() -> void:
	match persistence:
		"session":
			session_flags = flags.duplicate()
		"saved":
			session_flags = flags.duplicate()
			Config.save_cheat_prefs(flags)

func set_persistence(mode: String) -> void:
	persistence = mode
	if mode == "match":
		session_flags = {}
		Config.clear_cheat_prefs()
	_persist()

func load_persisted() -> void:
	var src: Dictionary = session_flags if not session_flags.is_empty() else Config.load_cheat_prefs()
	if src.is_empty():
		return
	persistence = "session" if not session_flags.is_empty() else "saved"
	for k in src:
		if flags.has(k):
			flags[k] = bool(src[k])

func to_dict() -> Dictionary:
	return {"enabled": enabled, "flags": flags.duplicate(), "persistence": persistence}

func from_dict(d: Dictionary) -> void:
	enabled = bool(d.get("enabled", enabled))
	persistence = d.get("persistence", "match")
	for k in d.get("flags", {}):
		if flags.has(k):
			flags[k] = bool(d.flags[k])

# ---------------------------------------------------------------- command console

const COMMANDS := [
	"help", "list", "status", "money set|add|subtract <amount>", "resources set|add|subtract <ore|gems|all> <amount>",
	"power set <amount>", "storage unlimited on|off", "build instant on|off", "build free on|off",
	"units instant on|off", "units free on|off", "queue unlimited on|off", "prereq on|off", "research instant",
	"deploy instant on|off", "repair instant on|off", "buildanywhere on|off",
	"spawn <type> [count] [me|enemy|p2] [at <x> <y>]", "spawn harvester [count]",
	"health set <value>", "health full", "invulnerable on|off", "destroy selected", "repair selected",
	"teleport <x> <y>", "remove enemies", "remove friendly",
	"reveal on|off", "fog on|off", "enemies reveal on|off", "freeze on|off", "ai on|off",
	"victory", "defeat", "speed <0.25-8>", "speed reset", "powerreq on|off", "depletion on|off",
	"autorepair units|buildings on|off", "persist match|session|saved", "reset",
]

func command_names() -> Array:
	var out := []
	for c in COMMANDS:
		out.append(String(c).split(" ")[0])
	return out

func autocomplete(prefix: String) -> Array:
	var out := []
	for c in COMMANDS:
		if String(c).begins_with(prefix):
			out.append(c)
	if prefix.begins_with("spawn "):
		var part := prefix.substr(6)
		for t in Data.units.keys() + Data.buildings.keys():
			if String(t).begins_with(part):
				out.append("spawn " + t)
	return out

func _ok(msg: String) -> Dictionary:
	return {"ok": true, "msg": msg}

func _err(msg: String) -> Dictionary:
	return {"ok": false, "msg": msg}

func _parse_amount(s: String) -> int:
	var clean := s.replace(",", "").replace("_", "")
	if not clean.is_valid_int():
		return -1
	if clean.length() > 13:
		return Player.MAX_VALUE
	return clampi(clean.to_int(), 0, Player.MAX_VALUE)

func _onoff(s: String) -> int:
	if s in ["on", "true", "1", "enable", "enabled"]:
		return 1
	if s in ["off", "false", "0", "disable", "disabled"]:
		return 0
	return -1

func _set_flag_cmd(name: String, arg: String) -> Dictionary:
	var v := _onoff(arg)
	if v < 0:
		return _err("Expected 'on' or 'off'.")
	set_flag(name, v == 1)
	return _ok("%s: %s" % [FLAG_LABELS.get(name, name), "ON" if v == 1 else "OFF"])

func execute(line: String) -> Dictionary:
	var text := line.strip_edges().to_lower()
	if text == "":
		return _err("")
	history.append(line.strip_edges())
	if not enabled:
		return _err("Cheats are disabled for this match. Enable them in the skirmish setup or use Sandbox mode.")
	var a := text.split(" ", false)
	var confirmed := a[a.size() - 1] == "confirm"
	if confirmed:
		a.remove_at(a.size() - 1)
	if a.is_empty():
		return _err("Type 'help' for a list of commands.")
	if a[0] in DESTRUCTIVE and not confirmed and Config.settings.get("confirm_destructive", true):
		return _err("'%s' is destructive. Repeat it with 'confirm' at the end, e.g. '%s confirm'." % [text, text])
	var hp = game.players[game.human_pid]
	match a[0]:
		"help", "list":
			return _ok("Commands:\n  " + "\n  ".join(COMMANDS))
		"status":
			var on := []
			for k in flags:
				if flags[k]:
					on.append(k)
			return _ok("Credits %d (cash %d, ore %d, gems %d) | Power %d/%d | Active cheats: %s" % [hp.credits(), hp.cash, hp.resources.ore, hp.resources.gems, hp.power_total(), hp.power_use, ", ".join(on) if on.size() > 0 else "none"])
		"money":
			if a.size() < 3:
				return _err("Usage: money set|add|subtract <amount>")
			var n := _parse_amount(a[2])
			if n < 0:
				return _err("'%s' is not a valid whole number." % a[2])
			match a[1]:
				"set":
					hp.cash = n
					for k in hp.resources:
						hp.resources[k] = 0
				"add":
					hp.add_cash(n)
				"subtract":
					var left := n
					for k in ["ore", "gems"]:
						var take := mini(int(hp.resources[k]), left)
						hp.resources[k] = int(hp.resources[k]) - take
						left -= take
					hp.cash = maxi(0, hp.cash - left)
				_:
					return _err("Use set, add or subtract.")
			return _ok("Credits are now %s." % _fmt(hp.credits()))
		"resources":
			if a.size() < 4:
				return _err("Usage: resources set|add|subtract <ore|gems|all> <amount>")
			var n := _parse_amount(a[3])
			if n < 0:
				return _err("'%s' is not a valid whole number." % a[3])
			var kinds := ["ore", "gems"] if a[2] == "all" else [a[2]]
			for k in kinds:
				if not hp.resources.has(k):
					return _err("Unknown resource '%s'. Use ore, gems or all." % k)
			var warn := ""
			for k in kinds:
				var cur := int(hp.resources[k])
				var v: int = n if a[1] == "set" else (cur + n if a[1] == "add" else cur - n)
				hp.set_resource(k, v)
			if not hp.unlimited_storage() and hp.stored_resources() > hp.storage_cap:
				warn = " (above storage capacity %s; harvesting pauses until you spend it or enable 'storage unlimited on')" % _fmt(hp.storage_cap)
			return _ok("Resources: ore %s, gems %s. Credits %s.%s" % [_fmt(hp.resources.ore), _fmt(hp.resources.gems), _fmt(hp.credits()), warn])
		"power":
			if a.size() < 3 or a[1] != "set":
				return _err("Usage: power set <amount>")
			var n := _parse_amount(a[2])
			if n < 0:
				return _err("Invalid amount.")
			hp.power_bonus = maxi(0, n - hp.power_prod)
			return _ok("Power output set to %s (plants %d + bonus %d)." % [_fmt(hp.power_total()), hp.power_prod, hp.power_bonus])
		"storage":
			if a.size() < 3:
				return _err("Usage: storage unlimited on|off")
			return _set_flag_cmd("unlimited_storage", a[2])
		"build":
			if a.size() < 3:
				return _err("Usage: build instant|free on|off")
			return _set_flag_cmd("instant_build" if a[1] == "instant" else "free_build", a[2])
		"units":
			if a.size() < 3:
				return _err("Usage: units instant|free on|off")
			return _set_flag_cmd("instant_units" if a[1] == "instant" else "free_units", a[2])
		"queue":
			return _set_flag_cmd("unlimited_queue", a[2] if a.size() > 2 else "")
		"prereq":
			var v := _onoff(a[1] if a.size() > 1 else "")
			if v < 0:
				return _err("Usage: prereq on|off")
			set_flag("no_prereq", v == 0)
			return _ok("Prerequisites are now %s." % ("enforced" if v == 1 else "ignored"))
		"research":
			set_flag("no_prereq", true)
			return _ok("All technology unlocked.")
		"deploy":
			return _set_flag_cmd("instant_deploy", a[2] if a.size() > 2 else "")
		"repair":
			if a.size() > 1 and a[1] == "selected":
				var n := 0
				for e in game.selection_entities():
					e.hp = e.max_hp
					e.queue_redraw()
					n += 1
				return _ok("Repaired %d selected object(s)." % n)
			return _set_flag_cmd("instant_repair", a[2] if a.size() > 2 else "")
		"buildanywhere":
			return _set_flag_cmd("build_anywhere", a[1] if a.size() > 1 else "")
		"spawn":
			return _cmd_spawn(a)
		"health":
			var sel: Array = game.selection_entities()
			if sel.is_empty():
				return _err("Select one or more units or structures first.")
			if a.size() > 1 and a[1] == "full":
				for e in sel:
					e.hp = e.max_hp
				return _ok("Restored %d object(s) to full health." % sel.size())
			if a.size() < 3 or not a[2].is_valid_float():
				return _err("Usage: health set <value> | health full")
			var v := float(a[2])
			for e in sel:
				e.set_health(v)
			return _ok("Set health of %d object(s) to %s (clamped to each maximum)." % [sel.size(), a[2]])
		"invulnerable", "invuln":
			var sel: Array = game.selection_entities()
			var v := _onoff(a[1] if a.size() > 1 else "")
			if sel.is_empty() or v < 0:
				return _err("Select objects, then use: invulnerable on|off")
			for e in sel:
				e.invulnerable = v == 1
			return _ok("%d object(s) are now %s." % [sel.size(), "invulnerable" if v == 1 else "vulnerable"])
		"destroy", "kill":
			var sel: Array = game.selection_entities()
			if sel.is_empty():
				return _err("Nothing selected.")
			var n := sel.size()
			for e in sel:
				e.invulnerable = false
				e.take_damage(e.hp + 1.0, null)
			return _ok("Destroyed %d object(s)." % n)
		"teleport":
			if a.size() < 3 or not a[1].is_valid_int() or not a[2].is_valid_int():
				return _err("Usage: teleport <cell x> <cell y>")
			var c := Vector2i(a[1].to_int(), a[2].to_int())
			var n := 0
			for e in game.selection_entities():
				if e.is_unit():
					var dest: Vector2i = game.map.nearest_passable(c, e.move_class, 8)
					if dest.x < 0:
						continue
					e.pos = MapGrid.cell_center(dest) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
					e.position = e.pos
					e.reset_physics_interpolation()
					e.cmd_stop()
					n += 1
			return _ok("Teleported %d unit(s)." % n) if n > 0 else _err("No selected unit could reach that cell.")
		"remove":
			if a.size() < 2:
				return _err("Usage: remove enemies|friendly")
			var enemies := a[1].begins_with("enem")
			var n := 0
			for e in game.units + game.buildings:
				if e.dead:
					continue
				var is_en: bool = game.are_enemies(game.human_pid, e.pid)
				if (enemies and is_en) or (not enemies and e.pid == game.human_pid):
					e.invulnerable = false
					e.take_damage(e.hp + 1.0, null)
					n += 1
			return _ok("Removed %d %s object(s)." % [n, "enemy" if enemies else "friendly"])
		"reveal":
			return _set_flag_cmd("reveal_map", a[1] if a.size() > 1 else "on")
		"fog":
			var v := _onoff(a[1] if a.size() > 1 else "")
			if v < 0:
				return _err("Usage: fog on|off")
			set_flag("no_fog", v == 0)
			return _ok("Fog of war %s." % ("enabled" if v == 1 else "disabled"))
		"enemies":
			return _set_flag_cmd("reveal_enemies", a[2] if a.size() > 2 else "on")
		"freeze":
			return _set_flag_cmd("freeze_enemies", a[1] if a.size() > 1 else "on")
		"ai":
			var v := _onoff(a[1] if a.size() > 1 else "")
			if v < 0:
				return _err("Usage: ai on|off")
			set_flag("ai_disabled", v == 0)
			return _ok("Enemy AI %s." % ("enabled" if v == 1 else "disabled"))
		"victory":
			game.force_end(true)
			return _ok("Victory forced.")
		"defeat":
			game.force_end(false)
			return _ok("Defeat forced.")
		"speed":
			if a.size() > 1 and a[1] == "reset":
				game.set_speed(1.0)
				return _ok("Game speed reset to 1x.")
			if a.size() < 2 or not a[1].is_valid_float():
				return _err("Usage: speed <0.25-8> | speed reset")
			game.set_speed(clampf(float(a[1]), 0.25, 8.0))
			return _ok("Game speed %.2fx." % game.speed)
		"powerreq":
			var v := _onoff(a[1] if a.size() > 1 else "")
			if v < 0:
				return _err("Usage: powerreq on|off")
			set_flag("no_power", v == 0)
			return _ok("Power requirements %s." % ("enabled" if v == 1 else "disabled"))
		"depletion":
			var v := _onoff(a[1] if a.size() > 1 else "")
			if v < 0:
				return _err("Usage: depletion on|off")
			set_flag("no_depletion", v == 0)
			return _ok("Resource depletion %s." % ("enabled" if v == 1 else "disabled"))
		"autorepair":
			if a.size() < 3:
				return _err("Usage: autorepair units|buildings on|off")
			return _set_flag_cmd("auto_repair_units" if a[1].begins_with("unit") else "auto_repair_buildings", a[2])
		"persist":
			if a.size() < 2 or not a[1] in ["match", "session", "saved"]:
				return _err("Usage: persist match|session|saved")
			set_persistence(a[1])
			return _ok("Cheat settings persistence: %s." % a[1])
		"reset":
			reset_flags()
			hp.power_bonus = 0
			set_persistence("match")
			for p in game.players:
				p.recompute(game.buildings)
			game.update_fog(true)
			return _ok("All cheat toggles reset to defaults.")
	return _err("Unknown command '%s'. Type 'help' for the list." % a[0])

func _cmd_spawn(a: Array) -> Dictionary:
	# Syntax: spawn <type> [count] [me|enemy|p<N>] [at <x> <y>]
	if a.size() < 2:
		return _err("Usage: spawn <type> [count] [me|enemy|p2] [at <x> <y>]")
	var t: String = a[1]
	if t == "harvester" or t == "collector":
		t = "harv"
	if not Data.exists(t):
		return _err("Unknown type '%s'. Units: %s. Buildings: %s." % [t, ", ".join(Data.units.keys()), ", ".join(Data.buildings.keys())])
	var count := 1
	var owner: int = game.human_pid
	var at := Vector2i(-1, -1)
	var i := 2
	while i < a.size():
		var tok: String = a[i]
		if tok == "at":
			if i + 2 >= a.size() or not a[i + 1].is_valid_int() or not a[i + 2].is_valid_int():
				return _err("Usage: ... at <cell x> <cell y>")
			at = Vector2i(a[i + 1].to_int(), a[i + 2].to_int())
			i += 3
			continue
		if tok.is_valid_int():
			count = clampi(tok.to_int(), 1, MAX_SPAWN)
		elif tok == "enemy":
			owner = game.first_enemy_of(game.human_pid)
		elif tok in ["me", "player", "friendly", "mine"]:
			owner = game.human_pid
		elif tok.begins_with("p") and tok.substr(1).is_valid_int():
			owner = tok.substr(1).to_int() - 1
			if owner < 0 or owner >= game.players.size():
				return _err("There is no player %s." % tok.substr(1))
		else:
			return _err("Could not understand '%s'." % tok)
		i += 1
	if owner < 0:
		return _err("There is no enemy player in this match.")
	var res: Dictionary = game.cheat_spawn(t, count, owner, at)
	return _ok(res.msg) if res.ok else _err(res.msg)

static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
