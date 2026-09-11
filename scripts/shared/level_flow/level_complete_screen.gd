extends Control
class_name LevelCompleteScreen

signal primary_action_requested

const METRIC_ROW_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_metric_row.tscn"
)
const GAME_SECTION_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_game_section.tscn"
)

@onready var overlay_root: Control = %OverlayRoot
@onready var title_label: Label = %LevelCompleteTitle
@onready var completion_message: RichTextLabel = %CompletionMessage
@onready var primary_button: Button = %PrimaryButton
@onready var level_summary_vbox: VBoxContainer = %LevelSummaryVBox
@onready var top_summary_separator: HSeparator = %TopSummarySeparator
@onready var game_sections: VBoxContainer = %GameSections
@onready var fallback_text: Label = %FallbackText

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
			"LEVEL "
			+ level_number_text
			+ " SELESAI"
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

	_render_completion_detail(data)

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


func _render_completion_detail(data: Dictionary) -> void:
	_clear_dynamic_content()

	var detail_value: Variant = data.get(
		"detail_data",
		{}
	)

	if not detail_value is Dictionary:
		_render_fallback_detail(data)
		return

	var detail: Dictionary = detail_value

	if detail.is_empty():
		_render_fallback_detail(data)
		return

	_add_level_metric(
		"Total Poin",
		str(
			detail.get(
				"score_text",
				data.get("score_text", "")
			)
		)
	)
	_add_level_stars(
		"Jumlah Bintang",
		detail.get("star_slots", [])
	)
	_add_level_metric(
		"Durasi Level",
		str(
			detail.get(
				"duration_text",
				data.get("duration_text", "")
			)
		)
	)

	var games_value: Variant = detail.get(
		"games",
		[]
	)

	if not games_value is Array:
		return

	var games: Array = games_value
	top_summary_separator.visible = not games.is_empty()

	for game_value in games:
		if not game_value is Dictionary:
			continue

		_add_game_section(game_value)


func _render_fallback_detail(
	data: Dictionary
) -> void:
	_add_level_metric(
		"Total Poin",
		str(data.get("score_text", ""))
	)

	var fallback_star_slots: Variant = data.get(
		"star_slots",
		[]
	)

	if fallback_star_slots is Array:
		var star_slots: Array = fallback_star_slots

		if not star_slots.is_empty():
			_add_level_stars(
				"Jumlah Bintang",
				star_slots
			)

	_add_level_metric(
		"Durasi Level",
		str(data.get("duration_text", ""))
	)

	var result_text: String = str(
		data.get("result_text", "")
	).strip_edges()

	if result_text.is_empty():
		return

	top_summary_separator.visible = true
	fallback_text.text = result_text
	fallback_text.visible = true


func _add_level_metric(
	label_text: String,
	value_text: String
) -> void:
	var row: Node = METRIC_ROW_SCENE.instantiate()
	level_summary_vbox.add_child(row)
	row.call(
		"bind_metric",
		label_text,
		value_text
	)


func _add_level_stars(
	label_text: String,
	slots_value: Variant
) -> void:
	var row: Node = METRIC_ROW_SCENE.instantiate()
	level_summary_vbox.add_child(row)
	row.call(
		"bind_stars",
		label_text,
		slots_value
	)


func _add_game_section(
	game: Dictionary
) -> void:
	var section: Node = GAME_SECTION_SCENE.instantiate()
	game_sections.add_child(section)
	section.call(
		"bind_game",
		game
	)


func _clear_dynamic_content() -> void:
	_clear_container(level_summary_vbox)
	_clear_container(game_sections)
	top_summary_separator.visible = false
	fallback_text.text = ""
	fallback_text.visible = false


func _clear_container(
	container: Node
) -> void:
	for child_value in container.get_children():
		var child: Node = child_value as Node

		if child == null:
			continue

		container.remove_child(child)
		child.queue_free()


func _on_primary_button_pressed() -> void:
	if not is_instance_valid(_native_button):
		return

	primary_button.disabled = true
	primary_action_requested.emit()
	_native_button.emit_signal("pressed")
