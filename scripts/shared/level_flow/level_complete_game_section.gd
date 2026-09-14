extends PanelContainer
class_name LevelCompleteGameSection

const METRIC_ROW_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_metric_row.tscn"
)

@onready var game_heading: Label = %GameHeading
@onready var summary_rows: VBoxContainer = %SummaryRows


func bind_game(
	data: Dictionary
) -> void:
	_clear_container(summary_rows)

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
		heading += " · " + game_title.to_upper()

	game_heading.text = heading

	_add_metric(
		"POIN",
		str(data.get("score_text", ""))
	)
	_add_metric(
		"DURASI",
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