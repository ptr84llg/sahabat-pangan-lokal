class_name BasketSlot
extends PanelContainer

signal drop_received(food_id: String, card: FoodCard, slot: BasketSlot)
signal cancel_requested(slot: BasketSlot)

@onready var holder: CenterContainer = %Holder
@onready var placeholder: Label = %Placeholder
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
    _prepare_drop_surface()
    cancel_button.mouse_filter = Control.MOUSE_FILTER_STOP
    cancel_button.pressed.connect(func(): cancel_requested.emit(self))
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

func _can_drop_data(_at_position: Vector2, data) -> bool:
    return data is Dictionary and data.get("kind", "") == "market_food_card" and current_card() == null

func _drop_data(_at_position: Vector2, data) -> void:
    var card = data.get("card")
    if card is FoodCard:
        drop_received.emit(str(data.get("food_id", "")), card, self)

func hold_card(card: FoodCard) -> void:
    var old_parent := card.get_parent()
    if old_parent != null:
        old_parent.remove_child(card)
    holder.add_child(card)
    card.set_market_selected(true)
    _refresh()

func current_card() -> FoodCard:
    for child in holder.get_children():
        if child is FoodCard:
            return child as FoodCard
    return null

func restore_placeholder() -> void:
    _refresh()

func is_empty() -> bool:
    return current_card() == null

func _refresh() -> void:
    if not is_node_ready():
        return
    var occupied := current_card() != null
    placeholder.visible = not occupied
    cancel_button.disabled = not occupied
