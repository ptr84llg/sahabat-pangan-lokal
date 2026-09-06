class_name FestivalFoodSlot
extends PanelContainer

signal drop_received(food_id: String, card: FoodCard, slot: FestivalFoodSlot)

@onready var title_label: Label = %TitleLabel
@onready var holder: CenterContainer = %Holder
@onready var placeholder: Label = %Placeholder
var accepted_kind := "festival_food_card"

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

func setup(title: String, placeholder_text: String = "LETAKKAN PANGAN") -> void:
	title_label.text = title
	placeholder.text = placeholder_text

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == accepted_kind and current_card() == null

func _drop_data(_at_position: Vector2, data) -> void:
	var card = data.get("card")
	if card is FoodCard:
		drop_received.emit(str(data.get("food_id", "")), card, self)

func hold_card(card: FoodCard, lock_card: bool = true) -> void:
	var parent := card.get_parent()
	if parent != null:
		parent.remove_child(card)
	holder.add_child(card)
	card.position = Vector2.ZERO
	placeholder.visible = false
	if lock_card:
		card.lock_card()

func release_card() -> FoodCard:
	var card := current_card()
	if card == null:
		return null
	holder.remove_child(card)
	placeholder.visible = true
	return card

func current_card() -> FoodCard:
	for child in holder.get_children():
		if child is FoodCard:
			return child as FoodCard
	return null

func clear_visual() -> void:
	placeholder.visible = current_card() == null