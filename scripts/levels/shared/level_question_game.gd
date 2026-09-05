extends Control

const ANSWER_OPTION_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_question_answer_option.tscn"
)


@onready var question_ui: Control = %QuestionUI
@onready var question_text: RichTextLabel = %QuestionText
@onready var answer_list: VBoxContainer = %AnswerList
@onready var preview_answer_list: VBoxContainer = %PreviewAnswerList
@onready var explanation_text: RichTextLabel = %ExplanationText
@onready var action_button: Button = %ActionButton
@onready var meta_row: HBoxContainer = %MetaRow
@onready var progress_label: Label = %ProgressLabel
@onready var timer_label: Label = %TimerLabel
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _question_node: Node
var _native_answers: Array[Button] = []
var _answer_options: Array[Button] = []
var _selected_index: int = -1
var _review_active: bool = false
var _last_question_text: String = ""
var _native_action_button: Button
var _answer_result_sfx_played: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	preview_answer_list.visible = false
	_force_landscape()
	action_button.pressed.connect(_on_action_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()
	set_process(false)

func present(
	source_panel: Control,
	question_node: Node,
	native_answer_nodes: Array
) -> void:
	var source_changed: bool = _source_panel != source_panel
	_source_panel = source_panel
	_question_node = question_node
	_native_answers.clear()

	for node_variant in native_answer_nodes:
		var native_button: Button = node_variant as Button

		if native_button != null:
			_native_answers.append(native_button)

	if source_changed:
		_selected_index = -1
		_review_active = false
		_last_question_text = ""
		_answer_result_sfx_played = false

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	_rebuild_answer_options_if_needed()
	visible = true
	set_process(true)
	_sync_runtime()
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	set_process(false)
	_source_panel = null
	_question_node = null
	_native_answers.clear()
	_native_action_button = null
	_selected_index = -1
	_review_active = false
	_last_question_text = ""
	_answer_result_sfx_played = false


func _process(_delta: float) -> void:
	if not visible:
		return

	_sync_runtime()


func _sync_runtime() -> void:
	if not is_instance_valid(_source_panel):
		hide_presenter()
		return

	_source_panel.visible = false

	var current_question: String = _text_from_node(_question_node)

	if current_question.is_empty():
		return

	if current_question != _last_question_text:
		_selected_index = -1
		_review_active = false
		_answer_result_sfx_played = false
		_last_question_text = current_question

	_set_rich_text(
		question_text,
		current_question,
		true,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_rebuild_answer_options_if_needed()

	var feedback_node: Node = _find_first_node_by_names(
		_source_panel,
		[
			"LiteracyFeedbackText",
			"QuizFeedback",
			"QuizFeedbackText",
			"FeedbackText",
			"FeedbackLabel",
			"ExplanationText",
			"ExplanationLabel",
			"ReasonText"
		]
	)
	var feedback_value: String = _text_from_node(feedback_node)
	var feedback_visible: bool = (
		feedback_node != null
		and _is_locally_visible(feedback_node)
		and not feedback_value.is_empty()
	)

	_native_action_button = _find_visible_action_button()
	var review_now: bool = (
		feedback_visible
		or is_instance_valid(_native_action_button)
	)

	if _review_active and not review_now:
		_selected_index = -1
		_answer_result_sfx_played = false

	_review_active = review_now

	if _review_active and not _answer_result_sfx_played:
		_play_answer_result_sfx(feedback_value)

	_sync_answer_options(feedback_value)
	_sync_explanation(feedback_value)
	_sync_action_button()
	_sync_meta_row()


func _rebuild_answer_options_if_needed() -> void:
	if _answer_options.size() == _native_answers.size():
		return

	for option in _answer_options:
		if is_instance_valid(option):
			option.queue_free()

	_answer_options.clear()

	for index in range(_native_answers.size()):
		var option_node: Node = ANSWER_OPTION_SCENE.instantiate()
		var option_button: Button = option_node as Button

		if option_button == null:
			continue

		answer_list.add_child(option_button)
		option_button.pressed.connect(
			_on_option_pressed.bind(index)
		)
		_answer_options.append(option_button)


func _sync_answer_options(feedback_value: String) -> void:
	var feedback_kind: String = _feedback_kind(feedback_value)
	var correct_index: int = _correct_index_from_feedback(feedback_value)
	var option_count: int = mini(
		_answer_options.size(),
		_native_answers.size()
	)

	for index in range(option_count):
		var option: Button = _answer_options[index]
		var native_button: Button = _native_answers[index]
		var native_visible: bool = native_button.visible
		var interactive: bool = (
			native_visible
			and not _review_active
			and not native_button.disabled
		)
		var state_name: String = "neutral"

		option.visible = native_visible
		option.call("set_option_text", native_button.text)

		if _review_active:
			interactive = false

			if correct_index >= 0 and index == correct_index:
				state_name = "correct"
			elif index == _selected_index:
				if feedback_kind == "correct":
					state_name = "correct"
				elif feedback_kind == "wrong":
					state_name = "wrong"
				else:
					state_name = "disabled"
			else:
				state_name = "disabled"
		elif native_button.disabled:
			state_name = "disabled"

		option.call(
			"set_visual_state",
			state_name,
			interactive
		)


func _sync_explanation(feedback_value: String) -> void:
	if _review_active and not feedback_value.is_empty():
		_set_rich_text(
			explanation_text,
			feedback_value,
			false,
			HORIZONTAL_ALIGNMENT_LEFT
		)
	else:
		explanation_text.clear()


func _sync_action_button() -> void:
	if not is_instance_valid(_native_action_button):
		action_button.visible = false
		action_button.disabled = true
		return

	action_button.visible = true
	action_button.disabled = _native_action_button.disabled
	action_button.text = _native_action_button.text.strip_edges()

	if action_button.text.is_empty():
		action_button.text = "LANJUT"


func _sync_meta_row() -> void:
	var progress_node: Node = _find_first_node_by_names(
		_source_panel,
		[
			"QuestionProgress",
			"QuizProgress",
			"LiteracyProgress"
		]
	)
	var timer_node: Node = _find_first_node_by_names(
		_source_panel,
		[
			"QuestionTimerLabel",
			"QuizTimerLabel",
			"TimerLabel"
		]
	)
	var progress_text: String = _text_from_node(progress_node)
	var timer_text: String = _text_from_node(timer_node)

	progress_label.text = progress_text
	timer_label.text = timer_text
	progress_label.visible = not progress_text.is_empty()
	timer_label.visible = not timer_text.is_empty()
	meta_row.visible = progress_label.visible or timer_label.visible


func _on_option_pressed(index: int) -> void:
	if _review_active:
		return

	if index < 0 or index >= _native_answers.size():
		return

	var native_button: Button = _native_answers[index]

	if native_button.disabled or not native_button.visible:
		return

	_selected_index = index

	for option in _answer_options:
		if is_instance_valid(option):
			option.disabled = true

	native_button.emit_signal("pressed")
	call_deferred("_sync_runtime")


func _on_action_pressed() -> void:
	if not is_instance_valid(_native_action_button):
		return

	if _native_action_button.disabled:
		return

	action_button.disabled = true
	_native_action_button.emit_signal("pressed")
	call_deferred("_sync_runtime")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method("_refresh_level_question_game_presenter")
	):
		host.call_deferred(
			"_refresh_level_question_game_presenter"
		)


func _find_visible_action_button() -> Button:
	for target_name in [
		"LiteracyRetryButton",
		"LiteracyResultButton",
		"QuizNextButton",
		"NextQuestionButton",
		"RetryButton",
		"ResultButton",
		"NextButton",
		"ContinueButton"
	]:
		var found_node: Node = _find_descendant_by_name(
			_source_panel,
			target_name
		)

		if found_node is Button:
			var found_button: Button = found_node as Button

			if _is_locally_visible(found_button):
				return found_button

	return _find_visible_action_button_descendant(_source_panel)


func _find_visible_action_button_descendant(root_node: Node) -> Button:
	if root_node == null:
		return null

	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is Button:
			var child_button: Button = child_node as Button
			var lowered_name: String = str(child_button.name).to_lower()
			var valid_name: bool = (
				lowered_name.contains("retry")
				or lowered_name.contains("result")
				or lowered_name.contains("next")
				or lowered_name.contains("continue")
			)
			var blocked_name: bool = (
				lowered_name.contains("answer")
				or lowered_name.contains("option")
				or lowered_name.contains("choice")
				or lowered_name.contains("start")
				or lowered_name.contains("back")
				or lowered_name.contains("hint")
			)

			if (
				valid_name
				and not blocked_name
				and _is_locally_visible(child_button)
			):
				return child_button

		var nested_button: Button = _find_visible_action_button_descendant(
			child_node
		)

		if nested_button != null:
			return nested_button

	return null


func _is_locally_visible(source_node: Node) -> bool:
	if source_node == null:
		return false

	var current_node: Node = source_node

	while current_node != null and current_node != _source_panel:
		if current_node is CanvasItem:
			var canvas_item: CanvasItem = current_node as CanvasItem

			if not canvas_item.visible:
				return false

		current_node = current_node.get_parent()

	return current_node == _source_panel


func _find_first_node_by_names(root_node: Node, names: Array) -> Node:
	for name_variant in names:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			str(name_variant)
		)

		if found_node != null:
			return found_node

	return null


func _find_descendant_by_name(root_node: Node, target_name: String) -> Node:
	if root_node == null:
		return null

	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if str(child_node.name) == target_name:
			return child_node

		var nested_node: Node = _find_descendant_by_name(
			child_node,
			target_name
		)

		if nested_node != null:
			return nested_node

	return null


func _text_from_node(source_node: Node) -> String:
	if source_node == null:
		return ""

	if source_node is Label:
		var source_label: Label = source_node as Label
		return source_label.text.strip_edges()

	if source_node is RichTextLabel:
		var source_rich: RichTextLabel = source_node as RichTextLabel
		return source_rich.text.strip_edges()

	return ""


func _set_rich_text(
	target: RichTextLabel,
	value: String,
	bold: bool,
	alignment: HorizontalAlignment
) -> void:
	target.clear()
	target.push_paragraph(alignment)

	if bold:
		target.push_bold()

	target.add_text(value.strip_edges())

	if bold:
		target.pop()

	target.pop()


func _correct_index_from_feedback(value: String) -> int:
	var lowered: String = value.to_lower()
	var marker: String = "jawaban benar:"
	var marker_index: int = lowered.find(marker)

	if marker_index < 0:
		return -1

	var answer_start: int = marker_index + marker.length()
	var remainder: String = value.substr(answer_start).strip_edges()
	var newline_index: int = remainder.find("\n")

	if newline_index >= 0:
		remainder = remainder.substr(0, newline_index).strip_edges()

	var expected_text: String = _normalize_answer_text(remainder)

	if expected_text.is_empty():
		return -1

	for index in range(_native_answers.size()):
		var candidate_text: String = _normalize_answer_text(
			_native_answers[index].text
		)

		if candidate_text == expected_text:
			return index

	return -1


func _normalize_answer_text(value: String) -> String:
	var cleaned: String = value.strip_edges()

	if cleaned.length() >= 2:
		var prefix: String = cleaned.substr(0, 2).to_upper()

		if prefix in ["A.", "B.", "C.", "D."]:
			cleaned = cleaned.substr(2).strip_edges()

	return cleaned.to_lower()


func _play_answer_result_sfx(feedback_value: String) -> void:
	var feedback_kind: String = _feedback_kind(feedback_value)
	if feedback_kind == "correct":
		_answer_result_sfx_played = true
	elif feedback_kind == "wrong":
		AudioManager.play_sfx("wrong")
		_answer_result_sfx_played = true

func _feedback_kind(value: String) -> String:
	var lowered: String = value.to_lower()

	for wrong_token in [
		"belum",
		"salah",
		"wrong",
		"waktu menjawab habis",
		"timeout",
		"coba lagi"
	]:
		if lowered.contains(wrong_token):
			return "wrong"

	for correct_token in [
		"benar",
		"tepat",
		"correct",
		"hebat"
	]:
		if lowered.contains(correct_token):
			return "correct"

	return "neutral"


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
	question_ui.visible = not portrait


