class_name SpriteLib
extends RefCounted
## Loads pre-rendered sprite sheets (assets/sprites, assets/fx, assets/ore) and their
## metadata, and provides frame regions plus the team-colour material per player.

const ISO_W := 64.0          # half cell width in iso pixels (cells are 128x64 at art res)
const ISO_H := 32.0
const PXU := 90.509668       # pixels per world unit at art resolution
const HEIGHT_PX := 78.38     # pixels per world unit of height (PXU * cos 30)

static var _sheets := {}
static var _team_mats := {}
static var _team_shader: Shader

class Sheet:
	var tex: Texture2D
	var mask: Texture2D
	var fw: int
	var fh: int
	var ax: float
	var ay: float
	var cols: int
	var count: int
	var extra: Dictionary
	func region(i: int) -> Rect2:
		i = clampi(i, 0, count - 1)
		return Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)

static func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)

static func sheet(name: String, folder: String = "sprites") -> Sheet:
	var key := folder + "/" + name
	if _sheets.has(key):
		return _sheets[key]
	var base := "res://assets/%s/%s" % [folder, name]
	if not FileAccess.file_exists(base + ".json"):
		_sheets[key] = null
		return null
	var meta = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	var s := Sheet.new()
	s.tex = _load_tex(base + ".png")
	if bool(meta.get("mask", false)):
		s.mask = _load_tex(base + "_mask.png")
	s.fw = int(meta.fw)
	s.fh = int(meta.fh)
	s.ax = float(meta.ax)
	s.ay = float(meta.ay)
	s.cols = int(meta.cols)
	s.count = int(meta.get("count", s.cols * int(meta.get("rows", 1))))
	s.extra = meta.get("extra", {})
	_sheets[key] = s
	return s

static func has(name: String) -> bool:
	return sheet(name) != null

## Team recolouring: luminance of masked pixels is mapped onto the player colour.
static func team_material(col: Color, mask: Texture2D) -> ShaderMaterial:
	if _team_shader == null:
		_team_shader = Shader.new()
		_team_shader.code = """
shader_type canvas_item;
uniform sampler2D mask_tex : filter_linear;
uniform vec3 team = vec3(0.2, 0.4, 0.8);
uniform float use_mask = 1.0;
uniform float flash = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float k = use_mask > 0.5 ? texture(mask_tex, UV).r : 0.0;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float shade = lum / 0.62;
	vec3 tc = shade < 1.0 ? team * shade : team + (vec3(1.0) - team) * clamp(shade - 1.0, 0.0, 1.0) * 0.6;
	c.rgb = mix(c.rgb, tc, k);
	c.rgb = mix(c.rgb, vec3(1.0), flash);
	COLOR = c * COLOR;
}
"""
	var key := "%s_%d" % [col.to_html(), mask.get_instance_id() if mask != null else 0]
	if _team_mats.has(key):
		return _team_mats[key]
	var m := ShaderMaterial.new()
	m.shader = _team_shader
	var tc := team_tone(col)
	m.set_shader_parameter("team", Vector3(tc.r, tc.g, tc.b))
	m.set_shader_parameter("mask_tex", mask)
	m.set_shader_parameter("use_mask", 1.0 if mask != null else 0.0)
	_team_mats[key] = m
	return m

## Player colours are bright UI colours; armour paint looks better slightly deeper.
static func team_tone(col: Color) -> Color:
	return Color(col.r * 0.82, col.g * 0.82, col.b * 0.85)

## Sprite sheet name for an entity, with fallbacks when a faction variant was not baked.
static func entity_sheet_name(e) -> String:
	var sprite: String = e.def.get("sprite", "")
	var pl = e.player()
	var prefix := "b_" if e.is_building() else ("i_" if e.def.get("category", "") == "infantry" else "u_")
	# Country variants first (infantry uniforms), then the side's sheet.
	for f in [pl.country, pl.faction, "coalition", "dominion"]:
		var n := "%s%s_%s" % [prefix, sprite, f]
		if has(n):
			return n
	return ""

static func iso(p_world_px: Vector2, h: float = 0.0) -> Vector2:
	var cx := p_world_px.x / 32.0
	var cy := p_world_px.y / 32.0
	return Vector2((cx - cy) * ISO_W, (cx + cy) * ISO_H - h * HEIGHT_PX)

static func iso_cells(c: Vector2, h: float = 0.0) -> Vector2:
	return Vector2((c.x - c.y) * ISO_W, (c.x + c.y) * ISO_H - h * HEIGHT_PX)

static func from_iso(v: Vector2) -> Vector2:
	var cx := (v.x / ISO_W + v.y / ISO_H) * 0.5
	var cy := (v.y / ISO_H - v.x / ISO_W) * 0.5
	return Vector2(cx, cy) * 32.0

static func dir_index(angle: float, dirs: int) -> int:
	return posmod(int(round(angle / (TAU / dirs))), dirs)
