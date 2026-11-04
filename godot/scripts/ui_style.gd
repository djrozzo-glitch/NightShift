extends RefCounted
## Procedural glass/neon UI skin. No external textures required.
const BG := Color("#080b1b")
const PANEL := Color("#10122b")
const EDGE := Color("#54417f")
const TEXT := Color("#f3effa")
const MUTED := Color("#aaa5c5")
const ACCENT := Color("#eb4bdb")

static func _glass_texture(strong: bool = false) -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var edge := mini(mini(x, 95 - x), mini(y, 95 - y))
			var dx := float(mini(x, 95 - x))
			var dy := float(mini(y, 95 - y))
			var radius := 13.0
			if dx < radius and dy < radius:
				var corner := Vector2(radius - dx, radius - dy).length()
				if corner > radius + 0.6:
					image.set_pixel(x, y, Color.TRANSPARENT)
					continue
			var top := 1.0 - float(y) / 95.0
			var left := 1.0 - float(x) / 95.0
			var body := Color(0.055 + 0.045 * top, 0.055 + 0.018 * top, 0.135 + 0.065 * top, 0.91 if strong else 0.82)
			var rim := clampf(1.0 - absf(float(edge) - 1.5) / 2.0, 0.0, 1.0)
			var glow := clampf(1.0 - float(edge) / 11.0, 0.0, 1.0)
			body = body.lerp(Color(0.90, 0.28 + 0.27 * left, 0.98, 0.95), rim * (0.68 if strong else 0.38) * (0.3 + 0.7 * top))
			body = body.lerp(Color(0.42, 0.15, 0.68, body.a), glow * 0.10)
			image.set_pixel(x, y, body)
	return ImageTexture.create_from_image(image)

static func _glass_box(strong: bool = false) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _glass_texture(strong)
	style.texture_margin_left = 20.0
	style.texture_margin_right = 20.0
	style.texture_margin_top = 20.0
	style.texture_margin_bottom = 20.0
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 13.0
	return style

static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.057, 0.14, 0.83)
	style.border_color = Color("#604588")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0.25, 0.02, 0.44, 0.25)
	style.shadow_size = 12
	return style

static func button_style(hovered: bool = false, pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#9b2bb0") if pressed else (Color("#44205e") if hovered else Color(0.075, 0.075, 0.17, 0.90))
	style.border_color = ACCENT if hovered or pressed else Color("#574577")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0.89, 0.1, 0.8, 0.42 if hovered or pressed else 0.10)
	style.shadow_size = 12 if hovered or pressed else 4
	return style

static func decorate_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _glass_box())

static func decorate_button(button: Button, prominent: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _glass_box(true) if prominent else button_style())
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
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Rajdhani", "Inter", "Avenir Next", "SF Pro Display", "Arial"])
	result.default_font = font
	result.default_font_size = 14
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_color", "OptionButton", TEXT)
	result.set_color("font_color", "PopupMenu", TEXT)
	return result

static func decorate_section(label: Label) -> void:
	decorate_label(label, 12, true)
	label.add_theme_color_override("font_color", Color("#e9a1ed"))

static func decorate_option(option: OptionButton) -> void:
	decorate_button(option)
	option.add_theme_stylebox_override("normal", button_style())
	option.add_theme_stylebox_override("hover", button_style(true))

static func decorate_progress(bar: ProgressBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color("#201b3a")
	track.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8

static func perk_style(owned: bool) -> StyleBoxFlat:
	var style := button_style(false, false)
	style.bg_color = Color("#172d31") if owned else Color("#211a37")
	style.border_color = Color("#4c807d") if owned else Color("#684581")
	return style
