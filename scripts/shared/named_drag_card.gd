class_name NamedDragCard
extends PanelContainer

@export var item_id := ""
@export var drag_kind := "named_card"
var display_name := ""
var locked := false
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
	_set_descendant_mouse_ignore(self)

func _set_descendant_mouse_ignore(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_ignore(child)

func _apply_visual() -> void:
	title_label.text = display_name

func _get_drag_data(_at_position: Vector2):
	if locked or item_id.is_empty():
		return null

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(150, 72)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(label)

	preview.modulate.a = 0.92
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

func show_wrong_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.68, 0.68, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)