class_name GroupDropZone
extends PanelContainer

signal drop_received(food_id: String, card: FoodCard, zone: GroupDropZone)

@export var accepted_group_id := ""
@onready var title_label: Label = %GroupTitle
@onready var progress_label: Label = %GroupProgress
@onready var accepted_grid: GridContainer = %AcceptedGrid

func _ready() -> void:
	_prepare_drop_surface()

func _prepare_drop_surface() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_non_interactive_children_ignore(self)

func _set_non_interactive_children_ignore(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Button:
			continue
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_non_interactive_children_ignore(child)

func setup(group_id: String, display_name: String, target_count: int = 4) -> void:
	accepted_group_id = group_id
	title_label.text = display_name
	progress_label.text = "0/%d" % target_count

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("kind", "") == "food_card"

func _drop_data(_at_position: Vector2, data) -> void:
	var card = data.get("card")
	if card is FoodCard:
		drop_received.emit(str(data.get("food_id", "")), card, self)

func accept_card(card: FoodCard, matched_count: int, target_count: int) -> void:
	var old_parent := card.get_parent()
	if old_parent != null:
		old_parent.remove_child(card)
	accepted_grid.add_child(card)
	card.lock_card()
	progress_label.text = "%d/%d" % [matched_count, target_count]

func pulse_hint() -> void:
	var tween := create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate", Color(1.0, 0.91, 0.52, 1.0), 0.18)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)