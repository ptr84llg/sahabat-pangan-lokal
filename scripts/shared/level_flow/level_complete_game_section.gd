extends VBoxContainer
class_name LevelCompleteGameSection

const METRIC_ROW_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_metric_row.tscn"
)
const MISSION_SECTION_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_mission_section.tscn"
)
const ATTEMPT_SECTION_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_attempt_section.tscn"
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

	game_attempt_history_heading.visible = false
	game_attempt_history_vbox.visible = false
	result_heading.visible = false
	missions_vbox.visible = false

	var game_no: int = int(
		data.get("game_no", 0)
	)
	var game_title: String = str(
		data.get("title", "")
	).strip_edges()
	var heading: String = "PERMAINAN"

	if game_no > 0:
		heading += " %d" % game_no

	if not game_title.is_empty():
		heading += " · " + game_title

	game_heading.text = heading

	_add_metric(
		"POIN",
		str(data.get("score_text", ""))
	)
	_add_metric(
		"WAKTU",
		str(data.get("duration_text", ""))
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
