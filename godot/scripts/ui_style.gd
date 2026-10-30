extends RefCounted
## NightShift UI design tokens and reusable Godot Control styling.
const BG := Color("#10121d")
const PANEL := Color("#171a29")
const EDGE := Color("#38334d")
const TEXT := Color("#f3effa")
const MUTED := Color("#a6a1b9")
const ACCENT := Color("#d05ac3")

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style

static func button_style(hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#833b7e") if pressed else (Color("#33283f") if hovered else Color("#202235"))
	style.border_color = ACCENT if hovered or pressed else EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func decorate_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", panel_style())

static func decorate_button(button: Button, prominent: bool = false) -> void:
	button.add_theme_stylebox_override("normal", button_style(false, prominent))
	button.add_theme_stylebox_override("hover", button_style(true, prominent))
	button.add_theme_stylebox_override("pressed", button_style(true, true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", TEXT)
	button.add_theme_color_override("font_pressed_color", TEXT)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 13)

static func decorate_label(label: Label, size: int = 14, muted: bool = false) -> void:
	label.add_theme_color_override("font_color", MUTED if muted else TEXT)
	label.add_theme_font_size_override("font_size", size)

static func make_theme() -> Theme:
	# One native Godot Theme ensures consistent typography across all controls.
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Inter", "SF Pro Display", "Arial"])
	result.default_font = font
	result.default_font_size = 14
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_color", "OptionButton", TEXT)
	result.set_color("font_color", "PopupMenu", TEXT)
	return result

static func decorate_section(label: Label) -> void:
	decorate_label(label, 12, true)
	label.add_theme_color_override("font_color", Color("#e2a2d9"))

static func decorate_option(option: OptionButton) -> void:
	decorate_button(option)
	option.add_theme_stylebox_override("normal", button_style())
	option.add_theme_stylebox_override("hover", button_style(true))

static func decorate_progress(bar: ProgressBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#302b43")
	track.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8

static func perk_style(owned: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172d31") if owned else Color("#282035")
	style.border_color = Color("#4c807d") if owned else Color("#4c395e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 13
	style.content_margin_right = 13
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style
