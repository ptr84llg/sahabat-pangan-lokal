extends RefCounted

const DEFAULT_PREVIEW_SIZE := Vector2(116.0, 98.0)
const DEFAULT_IMAGE_INSET := Vector2(8.0, 8.0)
const BACKGROUND_COLOR := Color(1.0, 0.98, 0.90, 0.98)
const BORDER_COLOR := Color(0.33, 0.55, 0.20, 1.0)
const BORDER_WIDTH := 3
const CORNER_RADIUS := 14


static func create_preview(
	texture: Texture2D,
	fallback_text: String = "",
	preview_size: Vector2 = DEFAULT_PREVIEW_SIZE
) -> PanelContainer:
	var safe_size := Vector2(
		maxf(preview_size.x, 72.0),
		maxf(preview_size.y, 64.0)
	)

	var preview := PanelContainer.new()
	preview.custom_minimum_size = safe_size
	preview.size = safe_size
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = 4090

	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND_COLOR
	style.border_width_left = BORDER_WIDTH
	style.border_width_top = BORDER_WIDTH
	style.border_width_right = BORDER_WIDTH
	style.border_width_bottom = BORDER_WIDTH
	style.border_color = BORDER_COLOR
	style.corner_radius_top_left = CORNER_RADIUS
	style.corner_radius_top_right = CORNER_RADIUS
	style.corner_radius_bottom_right = CORNER_RADIUS
	style.corner_radius_bottom_left = CORNER_RADIUS
	preview.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(center)

	if texture != null:
		var image := TextureRect.new()
		image.custom_minimum_size = Vector2(
			maxf(32.0, safe_size.x - DEFAULT_IMAGE_INSET.x),
			maxf(32.0, safe_size.y - DEFAULT_IMAGE_INSET.y)
		)
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		image.z_index = 4091
		center.add_child(image)
	elif not fallback_text.strip_edges().is_empty():
		var label := Label.new()
		label.custom_minimum_size = Vector2(
			maxf(32.0, safe_size.x - 16.0),
			maxf(32.0, safe_size.y - 16.0)
		)
		label.text = fallback_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(
			"font_color",
			Color(0.18, 0.31, 0.12, 1.0)
		)
		label.add_theme_font_size_override("font_size", 16)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(label)

	preview.modulate.a = 0.98
	return preview