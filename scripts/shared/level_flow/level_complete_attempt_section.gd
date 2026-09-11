extends MarginContainer
class_name LevelCompleteAttemptSection

@onready var attempt_heading: Label = %AttemptHeading
@onready var result_value: Label = %ResultValue
@onready var selected_row: HBoxContainer = %SelectedRow
@onready var selected_label: Label = %SelectedLabel
@onready var selected_value: Label = %SelectedValue
@onready var correct_row: HBoxContainer = %CorrectRow
@onready var correct_label: Label = %CorrectLabel
@onready var correct_value: Label = %CorrectValue
@onready var duration_value: Label = %DurationValue


func bind_attempt(
	data: Dictionary
) -> void:
	attempt_heading.text = "Percobaan %d" % int(
		data.get("attempt_no", 0)
	)
	result_value.text = str(
		data.get("result_text", "-")
	)

	var selected_label_text: String = str(
		data.get("selected_label", "")
	).strip_edges()
	selected_row.visible = not selected_label_text.is_empty()
	selected_label.text = selected_label_text
	selected_value.text = str(
		data.get("selected_value", "-")
	)

	var correct_label_text: String = str(
		data.get("correct_label", "")
	).strip_edges()
	correct_row.visible = not correct_label_text.is_empty()
	correct_label.text = correct_label_text
	correct_value.text = str(
		data.get("correct_value", "-")
	)

	duration_value.text = str(
		data.get("duration_text", "-")
	)