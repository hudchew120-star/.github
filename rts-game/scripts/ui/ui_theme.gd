class_name UITheme
extends RefCounted
## Shared look for every screen: gunmetal panels, amber readouts, faction-colored accents.

const BG := Color("#101418")
const PANEL := Color("#181d22")
const PANEL_2 := Color("#222930")
const BORDER := Color("#3a444e")
const TEXT := Color("#d9dee3")
const DIM := Color("#8a96a2")
const AMBER := Color("#f0b03c")
const GOOD := Color("#55c46d")
const BAD := Color("#e2553f")
const STEEL := Color("#7f8c99")

static var accent := Color("#3f7fd9")

static func box(bg: Color, border: Color = BORDER, bw: int = 1, radius: int = 2, pad: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.6
	s.content_margin_bottom = pad * 0.6
	return s

static func make(acc: Color = accent) -> Theme:
	accent = acc
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "Button", box(PANEL_2, BORDER))
	t.set_stylebox("hover", "Button", box(PANEL_2.lightened(0.08), acc))
	t.set_stylebox("pressed", "Button", box(acc.darkened(0.45), acc))
	t.set_stylebox("disabled", "Button", box(PANEL, BORDER.darkened(0.3)))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), acc, 2))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_stylebox("panel", "Panel", box(PANEL, BORDER))
	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 1, 2, 10))
	t.set_stylebox("normal", "LineEdit", box(Color("#0c0f12"), BORDER))
	t.set_stylebox("focus", "LineEdit", box(Color("#0c0f12"), acc))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_stylebox("normal", "OptionButton", box(PANEL_2, BORDER))
	t.set_stylebox("hover", "OptionButton", box(PANEL_2.lightened(0.08), acc))
	t.set_stylebox("pressed", "OptionButton", box(PANEL_2, acc))
	t.set_stylebox("focus", "OptionButton", box(Color(0, 0, 0, 0), acc, 2))
	t.set_stylebox("panel", "PopupMenu", box(PANEL, BORDER))
	t.set_stylebox("hover", "PopupMenu", box(acc.darkened(0.4), acc))
	t.set_stylebox("panel", "TooltipPanel", box(Color("#0b0e11"), acc, 1, 2, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("tab_selected", "TabContainer", box(PANEL_2, acc))
	t.set_stylebox("tab_unselected", "TabContainer", box(PANEL, BORDER))
	t.set_stylebox("tab_hovered", "TabContainer", box(PANEL_2, BORDER))
	t.set_stylebox("panel", "TabContainer", box(PANEL, BORDER, 1, 2, 8))
	t.set_stylebox("normal", "RichTextLabel", box(Color("#0b0e11"), BORDER, 1, 2, 8))
	t.set_stylebox("background", "HSlider", box(Color("#0c0f12"), BORDER, 1, 2, 3))
	t.set_stylebox("grabber_area", "HSlider", box(acc.darkened(0.2), acc, 1, 2, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(acc, acc, 1, 2, 3))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t

static func title_label(text: String, size: int = 28, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func label(text: String, size: int = 15, col: Color = TEXT) -> Label:
	return title_label(text, size, col)

static func button(text: String, cb: Callable, min_w: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	if min_w > 0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(cb)
	return b

static func fmt(n: int) -> String:
	return Cheats._fmt(n)
