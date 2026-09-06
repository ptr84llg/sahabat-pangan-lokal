extends Control

@onready var success_ui: Control = %SuccessUI
@onready var message_label: RichTextLabel = %MessageLabel
@onready var continue_button: Button = %ContinueButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _continue_target: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_force_landscape()
	continue_button.pressed.connect(_on_continue_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func present(
	source_panel: Control,
	body_text: String,
	continue_target: Button
) -> void:
	_source_panel = source_panel
	_continue_target = continue_target

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	message_label.text = (
		"[center]" +
		_clean_message(body_text) +
		"[/center]"
	)
	continue_button.disabled = _continue_target == null
	visible = true
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	_source_panel = null
	_continue_target = null


func _clean_message(value: String) -> String:
	var cleaned: String = value.strip_edges()
	var lower_value: String = cleaned.to_lower()

	if lower_value.begins_with("hebat!"):
		cleaned = cleaned.substr(6).strip_edges()

	return cleaned


func _on_continue_pressed() -> void:
	if not is_instance_valid(_continue_target):
		return

	continue_button.disabled = true
	_continue_target.emit_signal("pressed")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method("_refresh_level_success_presenter")
	):
		host.call_deferred(
			"_refresh_level_success_presenter"
		)


func _force_landscape() -> void:
	if DisplayServer.has_feature(
		DisplayServer.FEATURE_ORIENTATION
	):
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_SENSOR_LANDSCAPE
		)


func _check_orientation() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = viewport_size.y > viewport_size.x

	portrait_blocker.visible = portrait
	success_ui.visible = not portrait


