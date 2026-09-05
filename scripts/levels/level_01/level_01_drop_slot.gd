extends FoodDropSlot

var _drag_hover_active: bool = false
var _matched_visual: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_set_non_interactive_children_ignore(self)
	set_process(true)
	_apply_slot_style()


func setup(
	food_id: String,
	display_name: String
) -> void:
	accepted_food_id = food_id
	title_label.text = display_name.to_upper()
	_matched_visual = false
	_drag_hover_active = false
	_apply_slot_style()


func _process(
	_delta: float
) -> void:
	if _matched_visual:
		if _drag_hover_active:
			_drag_hover_active = false
			_apply_slot_style()
		return

	var viewport: Viewport = get_viewport()
	var dragging: bool = viewport.gui_is_dragging()
	var pointer_inside: bool = get_global_rect().has_point(
		get_global_mouse_position()
	)
	var should_hover: bool = dragging and pointer_inside

	if should_hover == _drag_hover_active:
		return

	_drag_hover_active = should_hover
	_apply_slot_style()


func _can_drop_data(
	_at_position: Vector2,
	data: Variant
) -> bool:
	if not data is Dictionary:
		return false

	var drag_kind: String = str(
		data.get("kind", "")
	)

	return drag_kind in [
		"food_card",
		"market_food_card"
	]


func _drop_data(
	_at_position: Vector2,
	data: Variant
) -> void:
	_drag_hover_active = false
	_apply_slot_style()

	if not data is Dictionary:
		return

	var card_variant: Variant = data.get("card")
	var card: FoodCard = card_variant as FoodCard

	if card == null:
		return

	drop_received.emit(
		str(data.get("food_id", "")),
		card,
		self
	)


func accept_card(
	card: FoodCard
) -> void:
	var old_parent: Node = card.get_parent()

	if old_parent != null:
		old_parent.remove_child(card)

	holder.add_child(card)
	card.lock_card()

	# E35 guard: do not append decorative Unicode status symbols.
	# The matched card itself and green slot background are the status.
	_matched_visual = true
	_drag_hover_active = false
	_apply_slot_style()


func pulse_hint() -> void:
	var tween: Tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(
		self,
		"modulate",
		Color(1.0, 0.91, 0.52, 1.0),
		0.18
	)
	tween.tween_property(
		self,
		"modulate",
		Color.WHITE,
		0.18
	)


func _apply_slot_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	if _matched_visual:
		style.bg_color = Color(0.90, 0.97, 0.87, 1.0)
		style.border_color = Color(0.18, 0.50, 0.16, 1.0)
	elif _drag_hover_active:
		# Neutral hover only. It does NOT reveal correctness.
		style.bg_color = Color(1.0, 0.96, 0.72, 1.0)
		style.border_color = Color(0.33, 0.55, 0.20, 1.0)
	else:
		style.bg_color = Color(0.99, 0.99, 0.975, 1.0)
		style.border_color = Color(0.012, 0.35, 0.23, 1.0)

	add_theme_stylebox_override(
		"panel",
		style
	)
