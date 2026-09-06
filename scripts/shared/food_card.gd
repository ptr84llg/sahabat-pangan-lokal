class_name FoodCard
extends PanelContainer

@export var food_id := ""
@export var group_id := ""
@export var drag_kind := "food_card"
var display_name := ""
var coin_value := -1
var locked := false
@onready var glyph: FoodGlyph = %Glyph
@onready var name_label: Label = %NameLabel
@onready var coin_label: Label = %CoinLabel

func setup(new_food_id: String, new_display_name: String = "", new_group_id: String = "", new_coin_value: int = -1, show_name: bool = false, show_coin: bool = false, new_drag_kind: String = "food_card") -> void:
	food_id = new_food_id
	display_name = new_display_name
	group_id = new_group_id
	coin_value = new_coin_value
	drag_kind = new_drag_kind
	if is_node_ready():
		_apply_visual(show_name, show_coin)
	else:
		set_meta("show_name", show_name)
		set_meta("show_coin", show_coin)

func _ready() -> void:
	custom_minimum_size = Vector2(112, 104)
	_prepare_drag_surface()
	_apply_visual(bool(get_meta("show_name", false)), bool(get_meta("show_coin", false)))

func _prepare_drag_surface() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_set_descendant_mouse_ignore(self)

func _set_descendant_mouse_ignore(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendant_mouse_ignore(child)

func _apply_visual(show_name: bool, show_coin: bool) -> void:
	glyph.food_id = food_id
	name_label.text = display_name
	name_label.visible = show_name and not display_name.is_empty()
	coin_label.text = "%d Koin" % coin_value if coin_value >= 0 else ""
	coin_label.visible = show_coin and coin_value >= 0

func _get_drag_data(_at_position: Vector2):
	if locked or food_id.is_empty():
		return null
	set_meta("spl_drag_started_ticks_ms", Time.get_ticks_msec())
	set_meta("spl_drag_started_at_unix", Time.get_unix_time_from_system())

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(112, 104)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_box := VBoxContainer.new()
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(preview_box)

	var preview_glyph := FoodGlyph.new()
	preview_glyph.custom_minimum_size = Vector2(104, 76)
	preview_glyph.food_id = food_id
	preview_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_box.add_child(preview_glyph)

	if not display_name.is_empty() and name_label.visible:
		var label := Label.new()
		label.text = display_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_box.add_child(label)

	preview.modulate.a = 0.92
	set_drag_preview(preview)

	return {
		"kind": drag_kind,
		"food_id": food_id,
		"group_id": group_id,
		"coin_value": coin_value,
		"card": self
	}

func lock_card() -> void:
	locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	modulate = Color(0.82, 0.96, 0.84, 1.0)

func set_static_preview() -> void:
	locked = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW

func set_market_selected(selected: bool) -> void:
	locked = false
	_prepare_drag_surface()
	modulate = Color(0.90, 0.96, 1.0, 1.0) if selected else Color.WHITE

func show_wrong_feedback() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.68, 0.68, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)