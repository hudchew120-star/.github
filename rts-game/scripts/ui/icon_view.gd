class_name IconView
extends RefCounted
## Draws a unit or structure icon into a rectangle using the battlefield artwork.

static func draw(ci: CanvasItem, t: String, rect: Rect2, team: Color, faction: String) -> void:
	var d := Data.def(t)
	if d.is_empty():
		return
	ci.draw_rect(rect, Color(0.09, 0.11, 0.12))
	if Data.is_building(t):
		var sz: Vector2i = d.size
		var px := Vector2(sz) * MapGrid.T
		var s := minf(rect.size.x / px.x, rect.size.y / px.y) * 0.9
		var off := rect.position + (rect.size - px * s) * 0.5
		Sprites.base = Transform2D(0.0, Vector2(s, s), 0.0, off)
		ci.draw_set_transform_matrix(Sprites.base)
		Sprites.draw_building(ci, d.get("sprite", ""), sz, team, faction, 1.0, 0.0, -PI * 0.25)
	else:
		var r := float(d.get("radius", 8))
		var s := clampf(rect.size.y / (r * 3.2), 1.0, 3.2)
		Sprites.base = Transform2D(0.0, Vector2(s, s), 0.0, rect.get_center())
		ci.draw_set_transform_matrix(Sprites.base)
		Sprites.draw_unit(ci, d.get("sprite", ""), team, faction, -PI * 0.25, -PI * 0.25, 0.0)
	Sprites.base = Transform2D.IDENTITY
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
