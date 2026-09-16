class_name DragPreview
extends PanelContainer

const MIN_PREVIEW_SIZE := Vector2(72.0, 64.0)

@export_group("Editable Layout")
@export var image_inset := Vector2(8.0, 8.0)
@export var fallback_inset := Vector2(16.0, 16.0)

func configure(
	texture: Texture2D,
	fallback_text: String = "",
	preview_size: Vector2 = Vector2(116.0, 98.0)
) -> void:
	var image := get_node_or_null(
		"Center/PreviewImage"
	) as TextureRect
	var fallback_label := get_node_or_null(
		"Center/PreviewFallback"
	) as Label

	if image == null or fallback_label == null:
		push_error(
			"DragPreview scene is missing PreviewImage or PreviewFallback."
		)
		return

	var safe_size := Vector2(
		maxf(preview_size.x, MIN_PREVIEW_SIZE.x),
		maxf(preview_size.y, MIN_PREVIEW_SIZE.y)
	)

	custom_minimum_size = safe_size
	size = safe_size

	image.custom_minimum_size = Vector2(
		maxf(32.0, safe_size.x - image_inset.x),
		maxf(32.0, safe_size.y - image_inset.y)
	)
	fallback_label.custom_minimum_size = Vector2(
		maxf(32.0, safe_size.x - fallback_inset.x),
		maxf(32.0, safe_size.y - fallback_inset.y)
	)

	image.texture = texture
	image.visible = texture != null

	var clean_fallback := fallback_text.strip_edges()
	fallback_label.text = clean_fallback
	fallback_label.visible = (
		texture == null
		and not clean_fallback.is_empty()
	)
