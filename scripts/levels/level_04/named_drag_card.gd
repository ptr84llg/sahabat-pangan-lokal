class_name NamedDragCard
extends PanelContainer

const DRAG_PREVIEW_FACTORY := preload("res://scripts/shared/gameplay/drag_preview_factory.gd")

@export var item_id := ""
@export var drag_kind := "named_card"
var display_name := ""
var locked := false
var drag_preview_texture: Texture2D = null
var drag_preview_size := Vector2(150, 72)
@onready var title_label: Label = %TitleLabel

func setup(new_item_id: String, new_display_name: String, new_drag_kind: String) -> void:
	item_id = new_item_id
	display_name = new_display_name
	drag_kind = new_drag_kind
	if is_node_ready():
		_apply_visual()

func _ready() -> void:
	custom_minimum_size = Vector2(150, 72)
	_prepare_drag_surface()
	_apply_visual()

func _prepare_drag_surface() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ScreenMotionPresenter.bind_gameplay_hover(self, not locked)
	_set_descendant_mouse_ignore(self)

func _set_descendant_mouse_ignore(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_ignore(child)

func _apply_visual() -> void:
	title_label.text = display_name

func set_image_drag_preview(
	texture: Texture2D,
	preview_size: Vector2
) -> void:
	drag_preview_texture = texture

	if preview_size.x > 0.0 and preview_size.y > 0.0:
		drag_preview_size = preview_size


func _get_drag_data(_at_position: Vector2):
	if locked or item_id.is_empty():
		return null

	ScreenMotionPresenter.cancel_control(self, true)
	var preview_size := (
		drag_preview_size
		if drag_preview_texture != null
		else Vector2(150.0, 72.0)
	)
	var preview := DRAG_PREVIEW_FACTORY.create_preview(
		drag_preview_texture,
		display_name,
		preview_size
	)
	set_drag_preview(preview)
	return {
		"kind": drag_kind,
		"item_id": item_id,
		"card": self
	}

func lock_card() -> void:
	locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	modulate = Color(0.82, 0.96, 0.84, 1.0)
	ScreenMotionPresenter.set_gameplay_hover_enabled(self, false)

func show_wrong_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.68, 0.68, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)