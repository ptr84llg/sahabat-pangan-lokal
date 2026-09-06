class_name IngredientSlot
extends PanelContainer

signal drop_received(food_id: String, card: FoodCard, slot: IngredientSlot)

@onready var holder: CenterContainer = %Holder
@onready var placeholder: Label = %Placeholder
@onready var title_label: Label = %TitleLabel

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

func setup(title: String) -> void:
	title_label.text = title

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "ingredient_food_card"

func _drop_data(_at_position: Vector2, data) -> void:
	var card = data.get("card")
	if card is FoodCard:
		drop_received.emit(str(data.get("food_id", "")), card, self)

func hold_card(card: FoodCard) -> FoodCard:
	var previous := current_card()
	if previous == card:
		return previous
	var old_parent := card.get_parent()
	if old_parent != null:
		old_parent.remove_child(card)
	holder.add_child(card)
	placeholder.visible = false
	card.locked = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	return previous

func release_current_to(target: Node) -> FoodCard:
	var card := current_card()
	if card == null:
		return null
	holder.remove_child(card)
	target.add_child(card)
	card.locked = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.modulate = Color.WHITE
	placeholder.visible = true
	return card

func current_card() -> FoodCard:
	for child in holder.get_children():
		if child is FoodCard:
			return child as FoodCard
	return null

func lock_current() -> void:
	var card := current_card()
	if card != null:
		card.lock_card()