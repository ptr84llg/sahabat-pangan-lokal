extends RefCounted

const DRAG_PREVIEW_SCENE: PackedScene = preload(
	"res://scenes/shared/gameplay/drag_preview.tscn"
)
const DEFAULT_PREVIEW_SIZE := Vector2(116.0, 98.0)


static func create_preview(
	texture: Texture2D,
	fallback_text: String = "",
	preview_size: Vector2 = DEFAULT_PREVIEW_SIZE
) -> PanelContainer:
	var preview := DRAG_PREVIEW_SCENE.instantiate() as PanelContainer

	if preview == null:
		push_error("DragPreview scene root must extend PanelContainer.")
		return null

	preview.call(
		"configure",
		texture,
		fallback_text,
		preview_size
	)
	return preview
