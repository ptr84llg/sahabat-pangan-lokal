extends Control
class_name LevelFoodInformation


@onready var information_ui: Control = %InformationUI
@onready var food_image: TextureRect = %FoodImage
@onready var counter_label: Label = %CounterLabel
@onready var food_name: Label = %FoodName
@onready var food_type: Label = %FoodType
@onready var description_scroll: ScrollContainer = %DescriptionScroll
@onready var food_description: RichTextLabel = %FoodDescription
@onready var action_button: Button = %ActionButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _native_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_button.pressed.connect(
		_on_action_button_pressed
	)
	get_viewport().size_changed.connect(
		_check_orientation
	)
	_check_orientation()


func show_information(
	source_panel: Control,
	data: Dictionary,
	native_button: Button
) -> void:
	_source_panel = source_panel
	_native_button = native_button

	var image_texture: Texture2D = data.get(
		"texture",
		null
	) as Texture2D

	food_image.texture = image_texture
	food_image.visible = image_texture != null

	counter_label.text = str(
		data.get("counter_text", "")
	).strip_edges()
	counter_label.visible = not counter_label.text.is_empty()

	food_name.text = str(
		data.get("name_text", "")
	).strip_edges()
	food_type.text = str(
		data.get("type_text", "")
	).strip_edges()

	var description_text: String = str(
		data.get("description_text", "")
	).strip_edges()

	food_description.clear()
	food_description.push_paragraph(
		HORIZONTAL_ALIGNMENT_FILL
	)
	food_description.append_text(description_text)
	food_description.pop()

	var native_button_text: String = str(
		data.get("button_text", "")
	).strip_edges()

	if native_button_text.is_empty():
		native_button_text = "LANJUT"

	action_button.text = native_button_text
	action_button.disabled = _native_button == null

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	information_ui.visible = true
	visible = true
	_check_orientation()
	call_deferred("_reset_description_scroll")
	action_button.call_deferred("grab_focus")


func hide_presenter() -> void:
	action_button.disabled = false
	_source_panel = null
	_native_button = null
	information_ui.visible = false
	visible = false


func _on_action_button_pressed() -> void:
	if not is_instance_valid(_native_button):
		return

	action_button.disabled = true
	_native_button.emit_signal("pressed")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method(
			"_refresh_level_food_information_presenter"
		)
	):
		host.call_deferred(
			"_refresh_level_food_information_presenter"
		)


func _reset_description_scroll() -> void:
	description_scroll.scroll_vertical = 0


func _check_orientation() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = viewport_size.y > viewport_size.x

	portrait_blocker.visible = portrait
	information_ui.visible = visible and not portrait


