extends MarginContainer
class_name LevelCompleteMissionSection

const METRIC_ROW_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_metric_row.tscn"
)
const ATTEMPT_SECTION_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_attempt_section.tscn"
)

@onready var mission_heading: Label = %MissionHeading
@onready var summary_rows: VBoxContainer = %SummaryRows
@onready var history_heading: Label = %HistoryHeading
@onready var attempts_vbox: VBoxContainer = %AttemptsVBox
@onready var interaction_rows: VBoxContainer = %InteractionRows


func bind_mission(
	data: Dictionary
) -> void:
	_clear_container(summary_rows)
	_clear_container(attempts_vbox)
	_clear_container(interaction_rows)

	var mission_no: int = int(
		data.get("mission_no", 0)
	)
	var mission_title: String = str(
		data.get("title", "")
	).strip_edges()
	var heading: String = "Misi ke-%d" % mission_no

	if not mission_title.is_empty():
		heading += " - " + mission_title

	mission_heading.text = heading

	_add_metric(
		summary_rows,
		"Durasi Misi",
		str(data.get("duration_text", "-"))
	)
	_add_metric(
		summary_rows,
		"Percobaan",
		str(data.get("attempt_count", 1))
	)
	_add_metric(
		summary_rows,
		"Jumlah Salah",
		str(data.get("wrong_count", 0))
	)

	var invalid_count: int = int(
		data.get("invalid_count", 0)
	)

	if invalid_count > 0:
		_add_metric(
			summary_rows,
			"Jumlah Tidak Valid",
			str(invalid_count)
		)

	_add_metric(
		summary_rows,
		"Status Hasil",
		str(data.get("status_text", "-"))
	)

	var base_point_text: String = str(
		data.get("base_point_text", "-")
	)

	if (
		not base_point_text.is_empty()
		and base_point_text != "-"
	):
		_add_metric(
			summary_rows,
			"Poin Dasar",
			base_point_text
		)

	var penalty_points: int = int(
		data.get("penalty_points", 0)
	)

	if penalty_points > 0:
		_add_metric(
			summary_rows,
			"Penalti",
			"-%d" % penalty_points
		)

	_add_metric(
		summary_rows,
		"Poin Akhir",
		str(data.get("point_text", "-"))
	)

	var attempts_value: Variant = data.get(
		"attempt_details",
		[]
	)
	var attempts: Array = []

	if attempts_value is Array:
		attempts = attempts_value

	history_heading.visible = not attempts.is_empty()
	attempts_vbox.visible = not attempts.is_empty()

	for attempt_value in attempts:
		if not attempt_value is Dictionary:
			continue

		var attempt_section: Node = (
			ATTEMPT_SECTION_SCENE.instantiate()
		)
		attempts_vbox.add_child(attempt_section)
		attempt_section.call(
			"bind_attempt",
			attempt_value
		)

	_add_optional_metric(
		"Klik Petunjuk",
		int(data.get("hint_click_count", 0))
	)
	_add_optional_metric(
		"Klik Reset",
		int(data.get("reset_click_count", 0))
	)
	_add_optional_metric(
		"Klik ke-Peta",
		int(data.get("back_to_map_click_count", 0))
	)


func _add_optional_metric(
	label_text: String,
	count: int
) -> void:
	if count <= 0:
		return

	_add_metric(
		interaction_rows,
		label_text,
		str(count)
	)


func _add_metric(
	container: VBoxContainer,
	label_text: String,
	value_text: String
) -> void:
	var row: Node = METRIC_ROW_SCENE.instantiate()
	container.add_child(row)
	row.call(
		"bind_metric",
		label_text,
		value_text
	)


func _clear_container(
	container: Node
) -> void:
	for child_value in container.get_children():
		var child: Node = child_value as Node

		if child == null:
			continue

		container.remove_child(child)
		child.queue_free()