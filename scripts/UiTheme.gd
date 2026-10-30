extends RefCounted
class_name UiTheme
## Shared dark bunker theme with Turkish-capable Barlow fonts.


static func make() -> Theme:
	var t := Theme.new()
	var regular: FontFile = load("res://assets/fonts/Barlow-Regular.ttf")
	var medium: FontFile = load("res://assets/fonts/Barlow-Medium.ttf")
	var bold: FontFile = load("res://assets/fonts/Barlow-Bold.ttf")
	var cond: FontFile = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	t.default_font = regular
	t.default_font_size = 28
	t.set_font("font", "Label", regular)
	t.set_font("font", "Button", medium)
	t.set_font_size("font_size", "Label", 28)
	t.set_font_size("font_size", "Button", 30)
	t.set_color("font_color", "Label", Color("f2e6d0"))
	t.set_color("font_color", "Button", Color("f2e6d0"))
	t.set_color("font_hover_color", "Button", Color("ffe7b0"))
	t.set_color("font_pressed_color", "Button", Color("e0a14a"))
	var panel := _flat(Color("1c1916ee"), Color("3a3228"), 16, 2)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("normal", "Button", _flat(Color("2a241e"), Color("e0a14a"), 14, 2))
	t.set_stylebox("hover", "Button", _flat(Color("3a3228"), Color("f2c56b"), 14, 2))
	t.set_stylebox("pressed", "Button", _flat(Color("1a1612"), Color("c45c3e"), 14, 2))
	t.set_stylebox("disabled", "Button", _flat(Color("1a161280"), Color("3a3228"), 14, 1))
	t.set_stylebox("focus", "Button", _flat(Color("2a241e"), Color("7d9a6a"), 14, 2))
	t.set_constant("h_separation", "BoxContainer", 12)
	t.set_constant("v_separation", "BoxContainer", 10)
	t.set_font("font", "Header", cond)
	return t


static func _flat(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func label(text: String, size: int = 28, color: Color = Color("f2e6d0"), condensed := false, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var font: FontFile = load("res://assets/fonts/BarlowCondensed-Bold.ttf" if condensed else "res://assets/fonts/Barlow-Regular.ttf")
	if size >= 40:
		font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	l.add_theme_font_override("font", font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	l.clip_text = false
	return l


static func btn(text: String, min_h: int = 72) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b
