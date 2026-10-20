extends Node
## Local settings: display, controls (remappable), audio, and persisted cheat preferences.

const SETTINGS_PATH := "user://settings.cfg"
const CHEATS_PATH := "user://cheats.cfg"

var settings := {
	"ui_scale": 1.0,
	"graphics": "iso",
	"edge_scroll": true,
	"scroll_speed": 900.0,
	"fullscreen": false,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"ui_volume": 0.7,
	"confirm_destructive": true,
	"show_dev_tools": true,
	"autosave_minutes": 5,
	"refund_ratio": 1.0,
	"max_units": 600,
}

## Action -> array of key names. Remappable from the Settings screen.
var keymap := {
	"cam_up": ["W", "Up"], "cam_down": ["S", "Down"], "cam_left": ["A", "Left"], "cam_right": ["D", "Right"],
	"cmd_attack_move": ["Q"], "cmd_stop": ["X"], "cmd_guard": ["G"], "cmd_hold": ["H"], "cmd_patrol": ["P"],
	"cmd_scatter": ["V"], "cmd_deploy": ["E"], "pause": ["Pause", "F9"], "cheat_panel": ["F10"],
	"game_menu": ["Escape"], "select_all_army": ["Z"], "repair_mode": ["R"], "sell_mode": ["T"],
	"speed_up": ["Equal"], "speed_down": ["Minus"], "center_base": ["Home"],
}

func _ready() -> void:
	load_settings()
	apply_keymap()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		settings[k] = cf.get_value("settings", k, settings[k])
	for k in keymap.keys():
		var v = cf.get_value("keys", k, keymap[k])
		if v is Array and v.size() > 0:
			keymap[k] = v

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in settings:
		cf.set_value("settings", k, settings[k])
	for k in keymap:
		cf.set_value("keys", k, keymap[k])
	cf.save(SETTINGS_PATH)

func apply_keymap() -> void:
	for action in keymap:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		for key_name in keymap[action]:
			var code := OS.find_keycode_from_string(String(key_name))
			if code == KEY_NONE:
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

func rebind(action: String, key_name: String) -> void:
	keymap[action] = [key_name]
	apply_keymap()
	save_settings()

func apply_display() -> void:
	get_tree().root.content_scale_factor = float(settings.ui_scale)
	if settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func load_cheat_prefs() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(CHEATS_PATH) != OK:
		return {}
	var out := {}
	if not cf.has_section("cheats"):
		return out
	for k in cf.get_section_keys("cheats"):
		out[k] = cf.get_value("cheats", k)
	return out

func save_cheat_prefs(flags: Dictionary) -> void:
	var cf := ConfigFile.new()
	for k in flags:
		cf.set_value("cheats", k, flags[k])
	cf.save(CHEATS_PATH)

func clear_cheat_prefs() -> void:
	if FileAccess.file_exists(CHEATS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEATS_PATH))
