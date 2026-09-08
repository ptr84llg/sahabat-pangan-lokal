extends VBoxContainer
class_name LevelCompleteGameSection

const METRIC_ROW_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_complete_metric_row.tscn"
)
const MISSION_SECTION_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_complete_mission_section.tscn"
)
const ATTEMPT_SECTION_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_complete_attempt_section.tscn"
)

@onready var game_heading: Label = %GameHeading
@onready var summary_rows: VBoxContainer = %SummaryRows
@onready var game_attempt_history_heading: Label = %GameAttemptHistoryHeading
@onready var game_attempt_history_vbox: VBoxContainer = %GameAttemptHistoryVBox
@onready var result_heading: Label = %ResultHeading
@onready var missions_vbox: VBoxContainer = %MissionsVBox


func bind_game(
	data: Dictionary
) -> void:
	_clear_container(summary_rows)
	_clear_container(game_attempt_history_vbox)
	_clear_container(missions_vbox)

	var game_no: int = int(
		data.get("game_no", 0)
	)
	var game_title: String = str(
		data.get("title", "")
	).strip_edges()
	var heading: String = "Permainan ke-%d" % game_no

	if not game_title.is_empty():
		heading += " - " + game_title

	game_heading.text = heading

	_add_metric(
		"Total Poin",
		str(data.get("score_text", ""))
	)
	_add_metric(
		"Durasi Permainan",
		str(data.get("duration_text", ""))
	)
	_add_metric(
		"Jumlah Benar",
		str(data.get("total_correct", 0))
	)
	_add_metric(
		"Jumlah Salah",
		str(data.get("total_wrong", 0))
	)

	var total_invalid: int = int(
		data.get("total_invalid", 0)
	)

	if total_invalid > 0:
		_add_metric(
			"Jumlah Tidak Valid",
			str(total_invalid)
		)

	var penalty_count: int = int(
		data.get("penalty_count", 0)
	)
	var penalty_points_total: int = int(
		data.get("penalty_points_total", 0)
	)

	if penalty_count > 0:
		_add_metric(
			"Jumlah Penalti",
			str(penalty_count)
		)
		_add_metric(
			"Total Pengurangan Poin",
			"-%d" % penalty_points_total
		)

	var attempt_history_value: Variant = data.get(
		"attempt_history",
		[]
	)
	var attempt_history: Array = []

	if attempt_history_value is Array:
		attempt_history = attempt_history_value

	var game_attempt_count: int = int(
		data.get(
			"game_attempt_count",
			attempt_history.size()
		)
	)
	var timeout_count: int = int(
		data.get("timeout_count", 0)
	)

	if game_attempt_count > 1:
		_add_metric(
			"Percobaan Permainan",
			str(game_attempt_count)
		)

	if timeout_count > 0:
		_add_metric(
			"Jumlah Timeout",
			str(timeout_count)
		)

	var show_game_attempt_history: bool = (
		game_attempt_count > 1
		or timeout_count > 0
	)
	game_attempt_history_heading.visible = show_game_attempt_history
	game_attempt_history_vbox.visible = show_game_attempt_history

	if show_game_attempt_history:
		for attempt_value in attempt_history:
			if not attempt_value is Dictionary:
				continue

			var attempt_section: Node = (
				ATTEMPT_SECTION_SCENE.instantiate()
			)
			game_attempt_history_vbox.add_child(
				attempt_section
			)
			attempt_section.call(
				"bind_attempt",
				attempt_value
			)

	var missions_value: Variant = data.get(
		"missions",
		[]
	)
	var missions: Array = []

	if missions_value is Array:
		missions = missions_value

	result_heading.text = (
		"Hasil Permainan ke-%d" % game_no
	)
	result_heading.visible = not missions.is_empty()
	missions_vbox.visible = not missions.is_empty()

	for mission_value in missions:
		if not mission_value is Dictionary:
			continue

		var mission_section: Node = (
			MISSION_SECTION_SCENE.instantiate()
		)
		missions_vbox.add_child(mission_section)
		mission_section.call(
			"bind_mission",
			mission_value
		)


func _add_metric(
	label_text: String,
	value_text: String
) -> void:
	var row: Node = METRIC_ROW_SCENE.instantiate()
	summary_rows.add_child(row)
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