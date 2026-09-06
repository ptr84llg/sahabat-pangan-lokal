extends Control
class_name LevelCompleteScreen

signal primary_action_requested

@onready var overlay_root: Control = %OverlayRoot
@onready var title_label: Label = %LevelCompleteTitle
@onready var completion_message: RichTextLabel = %CompletionMessage
@onready var duration_row: HBoxContainer = %DurationRow
@onready var duration_value: Label = %DurationValue
@onready var score_row: HBoxContainer = %ScoreRow
@onready var score_value: Label = %ScoreValue
@onready var result_row: HBoxContainer = %ResultRow
@onready var result_value: Label = %ResultValue
@onready var badge_row: HBoxContainer = %BadgeRow
@onready var badge_value: Label = %BadgeValue
@onready var primary_button: Button = %PrimaryButton

var _source_panel: Control
var _native_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	primary_button.pressed.connect(
		_on_primary_button_pressed
	)


func show_completion(
	source_panel: Control,
	data: Dictionary,
	native_button: Button
) -> void:
	_source_panel = source_panel
	_native_button = native_button

	var level_number_text: String = str(
		data.get("level", "")
	)

	if level_number_text.is_empty() or level_number_text == "0":
		title_label.text = "LEVEL SELESAI"
	else:
		title_label.text = (
			"LEVEL " +
			level_number_text +
			" SELESAI"
		)

	var message_text: String = str(
		data.get(
			"message",
			"Kamu telah menyelesaikan level ini."
		)
	)

	completion_message.clear()
	completion_message.push_paragraph(
		HORIZONTAL_ALIGNMENT_CENTER
	)
	completion_message.append_text(message_text)
	completion_message.pop()

	_set_metric_row(
		duration_row,
		duration_value,
		str(data.get("duration_text", ""))
	)
	_set_metric_row(
		score_row,
		score_value,
		str(data.get("score_text", ""))
	)
	_set_metric_row(
		result_row,
		result_value,
		str(data.get("result_text", ""))
	)
	badge_row.visible = false
	badge_value.text = ""

	var requested_button_text: String = str(
		data.get("button_text", "")
	).strip_edges()

	if requested_button_text.is_empty():
		requested_button_text = "LANJUT"

	primary_button.text = requested_button_text
	primary_button.disabled = false

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	overlay_root.visible = true
	visible = true
	primary_button.call_deferred("grab_focus")


func hide_presenter() -> void:
	primary_button.disabled = false
	_source_panel = null
	_native_button = null
	overlay_root.visible = false
	visible = false


func _set_metric_row(
	row: HBoxContainer,
	value_label: Label,
	value_text: String
) -> void:
	var clean_text: String = value_text.strip_edges()
	var has_value: bool = not clean_text.is_empty()

	row.visible = has_value
	value_label.text = clean_text


func _on_primary_button_pressed() -> void:
	if not is_instance_valid(_native_button):
		return

	primary_button.disabled = true
	primary_action_requested.emit()
	_native_button.emit_signal("pressed")


