class_name FestivalBasketSlot
extends PanelContainer

signal drop_received(food_id: String, card: FoodCard, slot: FestivalBasketSlot)
signal return_requested(slot: FestivalBasketSlot)

@onready var holder: CenterContainer = %Holder
@onready var placeholder: Label = %Placeholder
@onready var return_button: Button = %ReturnButton
@onready var slot_label: Label = %SlotLabel

func _ready() -> void:
	_prepare_drop_surface()
	return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	return_button.pressed.connect(func(): return_requested.emit(self))
	_refresh()

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

func setup(label_text: String) -> void:
	slot_label.text = label_text
	_refresh()

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and str(data.get("kind", "")) == "festival_food_card" and current_card() == null

func _drop_data(_at_position: Vector2, data) -> void:
	var card = data.get("card")
	if card is FoodCard:
		drop_received.emit(str(data.get("food_id", "")), card, self)

func hold_card(card: FoodCard) -> void:
	var parent := card.get_parent()
	if parent != null:
		parent.remove_child(card)
	holder.add_child(card)
	card.position = Vector2.ZERO
	card.lock_card()
	_refresh()

func release_card() -> FoodCard:
	var card := current_card()
	if card == null:
		return null
	holder.remove_child(card)
	_refresh()
	return card

func current_card() -> FoodCard:
	for child in holder.get_children():
		if child is FoodCard:
			return child as FoodCard
	return null

func _refresh() -> void:
	var occupied := current_card() != null if is_node_ready() else false
	if is_node_ready():
		placeholder.visible = not occupied
		return_button.visible = occupied