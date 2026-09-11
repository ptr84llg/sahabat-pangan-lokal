class_name NamedDropSlot
extends PanelContainer

signal drop_received(item_id: String, card: NamedDragCard, slot: NamedDropSlot)

@export var accepted_kind := "named_card"
@export var accepted_id := ""
var drop_enabled := true
@onready var title_label: Label = %TitleLabel
@onready var holder: CenterContainer = %Holder

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

func setup(new_accepted_id: String, display_name: String, new_kind: String, enabled: bool = true) -> void:
	accepted_id = new_accepted_id
	accepted_kind = new_kind
	drop_enabled = enabled
	title_label.text = display_name
	modulate = Color.WHITE if enabled else Color(0.72, 0.72, 0.72, 1.0)

func set_drop_enabled(enabled: bool) -> void:
	drop_enabled = enabled
	modulate = Color.WHITE if enabled else Color(0.72, 0.72, 0.72, 1.0)

func _can_drop_data(_at_position: Vector2, data) -> bool:
	return drop_enabled and data is Dictionary and str(data.get("kind", "")) == accepted_kind and current_card() == null

func _drop_data(_at_position: Vector2, data) -> void:
	var card = data.get("card")
	if card is NamedDragCard:
		drop_received.emit(str(data.get("item_id", "")), card, self)

func accept_card(card: NamedDragCard) -> void:
	var old_parent := card.get_parent()
	if old_parent != null:
		old_parent.remove_child(card)
	holder.add_child(card)
	card.lock_card()
	title_label.text = "%s  âœ“" % title_label.text

func current_card() -> NamedDragCard:
	for child in holder.get_children():
		if child is NamedDragCard:
			return child as NamedDragCard
	return null