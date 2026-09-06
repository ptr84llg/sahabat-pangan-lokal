class_name FoodDropSlot
extends PanelContainer

signal drop_received(food_id: String, source_card: FoodCard, slot: FoodDropSlot)

@export var accepted_food_id := ""
@onready var title_label: Label = $VBox/Title
@onready var holder: CenterContainer = $VBox/Holder

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

func setup(food_id: String, display_name: String) -> void:
	accepted_food_id = food_id
	title_label.text = display_name

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.get("kind", "") in ["food_card", "market_food_card"]

func _drop_data(_at_position: Vector2, data) -> void:
	var card = data.get("card")
	if card is FoodCard:
		drop_received.emit(str(data.get("food_id", "")), card, self)

func accept_card(card: FoodCard) -> void:
	var old_parent := card.get_parent()
	if old_parent != null:
		old_parent.remove_child(card)
	holder.add_child(card)
	card.lock_card()
	title_label.text = "%s  âœ“" % title_label.text

func pulse_hint() -> void:
	var tween := create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate", Color(1.0, 0.91, 0.52, 1.0), 0.18)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)
