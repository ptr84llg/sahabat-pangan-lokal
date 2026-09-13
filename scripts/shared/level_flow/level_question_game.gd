extends Control

const ANSWER_OPTION_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_question_answer_option.tscn"
)

@export_group("Feedback Header")
@export var feedback_header_correct_bg: Color = Color(0.90, 0.96, 0.91, 1.0)
@export var feedback_header_wrong_bg: Color = Color(0.98, 0.90, 0.90, 1.0)
@export var feedback_header_timeout_bg: Color = Color(0.93, 0.94, 0.93, 1.0)
@export var feedback_header_neutral_bg: Color = Color(0.9843137, 0.972549, 0.9137255, 1.0)

@onready var question_ui: Control = %QuestionUI
@onready var question_text: RichTextLabel = %QuestionText
@onready var answer_list: VBoxContainer = %AnswerList
@onready var preview_answer_list: VBoxContainer = %PreviewAnswerList
@onready var explanation_text: RichTextLabel = %ExplanationText
@onready var action_button: Button = %ActionButton
@onready var feedback_modal_layer: Control = %FeedbackModalLayer
@onready var feedback_status_label: Label = %FeedbackStatusLabel
@onready var feedback_status_panel: PanelContainer = %PanelFeedbackStatus
@onready var meta_row: HBoxContainer = %MetaRow
@onready var progress_label: Label = %ProgressLabel
@onready var score_label: Label = %ScoreLabel
@onready var timer_label: Label = %TimerLabel
@onready var question_media_panel: PanelContainer = %QuestionMediaPanel
@onready var question_media_image: TextureRect = %QuestionMediaImage
@onready var image_answer_grid: GridContainer = %ImageAnswerGrid
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _question_node: Node
var _native_answers: Array[Button] = []
var _answer_options: Array[Button] = []
var _selected_index: int = -1
var _review_active: bool = false
var _last_question_text: String = ""
var _last_question_key: String = ""
var _loaded_media_path: String = ""
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
		_last_question_key = ""
		_loaded_media_path = ""
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
	_last_question_key = ""
	_loaded_media_path = ""
	question_media_image.texture = null
	feedback_modal_layer.visible = false
	feedback_status_label.text = ""
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

	var current_question_key: String = _question_key(current_question)

	if current_question_key != _last_question_key:
		_selected_index = -1
		_review_active = false
		_answer_result_sfx_played = false
		_last_question_text = current_question
		_last_question_key = current_question_key

	_set_rich_text(
		question_text,
		current_question,
		true,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_sync_presentation_mode()
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
	var mode: String = _presentation_mode()
	var target_container: Container = answer_list

	if mode == "IMAGE_OPTIONS":
		if _native_answers.size() >= 4:
			image_answer_grid.columns = 4
		else:
			image_answer_grid.columns = 3
		target_container = image_answer_grid

	answer_list.visible = mode != "IMAGE_OPTIONS"
	image_answer_grid.visible = mode == "IMAGE_OPTIONS"

	var correct_parent: bool = true

	for option in _answer_options:
		if not is_instance_valid(option) or option.get_parent() != target_container:
			correct_parent = false
			break

	if _answer_options.size() == _native_answers.size() and correct_parent:
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

		target_container.add_child(option_button)
		option_button.pressed.connect(
			_on_option_pressed.bind(index)
		)
		_answer_options.append(option_button)

func _sync_answer_options(feedback_value: String) -> void:
	var feedback_kind: String = _feedback_kind(feedback_value)
	var correct_index: int = _correct_index_from_feedback(feedback_value)
	var mode: String = _presentation_mode()
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
		option.call(
			"set_option_presentation",
			native_button.text,
			str(native_button.get_meta("image_path", "")),
			mode == "IMAGE_OPTIONS"
		)

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
	feedback_modal_layer.visible = _review_active

	if not _review_active:
		feedback_status_label.text = ""
		explanation_text.clear()
		return

	var feedback_kind: String = _feedback_kind(feedback_value)
	var is_timeout: bool = _feedback_is_timeout(feedback_value)

	if is_timeout:
		feedback_status_label.text = "\u2715 WAKTU HABIS"
		_apply_feedback_header_style("timeout")
	else:
		match feedback_kind:
			"correct":
				feedback_status_label.text = "\u2713 BENAR!"
				_apply_feedback_header_style("correct")
			"wrong":
				feedback_status_label.text = "\u2715 BELUM TEPAT"
				_apply_feedback_header_style("wrong")
			_:
				feedback_status_label.text = "HASIL JAWABAN"
				_apply_feedback_header_style("neutral")

	if not feedback_value.is_empty():
		_set_feedback_explanation_text(feedback_value)
	else:
		explanation_text.clear()


func _apply_feedback_header_style(state_name: String) -> void:
	var source_style: StyleBox = feedback_status_panel.get_theme_stylebox(
		"panel"
	)
	var flat_style: StyleBoxFlat = source_style as StyleBoxFlat

	if flat_style == null:
		return

	var runtime_style: StyleBoxFlat = flat_style.duplicate() as StyleBoxFlat

	match state_name:
		"correct":
			runtime_style.bg_color = feedback_header_correct_bg
		"wrong":
			runtime_style.bg_color = feedback_header_wrong_bg
		"timeout":
			runtime_style.bg_color = feedback_header_timeout_bg
		_:
			runtime_style.bg_color = feedback_header_neutral_bg

	feedback_status_panel.add_theme_stylebox_override(
		"panel",
		runtime_style
	)


func _set_feedback_explanation_text(value: String) -> void:
	var lines: PackedStringArray = value.strip_edges().split("\n")
	var wrote_line: bool = false

	explanation_text.clear()
	explanation_text.push_paragraph(HORIZONTAL_ALIGNMENT_CENTER)

	for raw_line in lines:
		var display_line: String = _feedback_display_line(
			str(raw_line)
		)

		if display_line.is_empty():
			continue

		if wrote_line:
			explanation_text.add_text("\n")

		if display_line.begins_with("Jawaban benar:"):
			explanation_text.push_bold()
			explanation_text.add_text("Jawaban benar:")
			explanation_text.pop()

			var answer_text: String = display_line.trim_prefix(
				"Jawaban benar:"
			).strip_edges()

			if not answer_text.is_empty():
				explanation_text.add_text(" " + answer_text)
		else:
			explanation_text.add_text(display_line)

		wrote_line = true

	explanation_text.pop()


func _feedback_display_line(value: String) -> String:
	var clean_line: String = value.strip_edges()
	var upper_line: String = clean_line.to_upper()

	if upper_line.begins_with("BENAR +"):
		var plus_index: int = clean_line.find("+")

		if plus_index >= 0:
			return "POIN +" + clean_line.substr(
				plus_index + 1
			).strip_edges()

	if upper_line.begins_with("BELUM TEPAT +"):
		return "POIN +0 (JAWABAN SALAH)"

	if upper_line.begins_with("WAKTU MENJAWAB HABIS +"):
		return "POIN +0 (WAKTU HABIS)"

	return clean_line

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
	var score_text: String = ""

	if is_instance_valid(_question_node):
		if progress_text.is_empty():
			progress_text = str(
				_question_node.get_meta("progress_text", "")
			).strip_edges()
		score_text = str(
			_question_node.get_meta("score_text", "")
		).strip_edges()

	progress_label.text = progress_text
	score_label.text = score_text
	timer_label.text = timer_text
	progress_label.visible = not progress_text.is_empty()
	score_label.visible = not score_text.is_empty()
	timer_label.visible = not timer_text.is_empty()
	meta_row.visible = (
		progress_label.visible
		or score_label.visible
		or timer_label.visible
	)

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


func _question_key(current_question: String) -> String:
	if is_instance_valid(_question_node):
		var question_id: String = str(
			_question_node.get_meta("question_id", "")
		).strip_edges()

		if not question_id.is_empty():
			return question_id

	return current_question


func _presentation_mode() -> String:
	if not is_instance_valid(_question_node):
		return "TEXT_ONLY"

	var mode: String = str(
		_question_node.get_meta("presentation_mode", "TEXT_ONLY")
	).strip_edges().to_upper()

	if mode not in ["TEXT_ONLY", "IMAGE_STIMULUS", "IMAGE_OPTIONS"]:
		return "TEXT_ONLY"

	return mode


func _sync_presentation_mode() -> void:
	var mode: String = _presentation_mode()
	var media_path: String = ""

	if is_instance_valid(_question_node):
		media_path = str(
			_question_node.get_meta("media_path", "")
		).strip_edges()

	var show_media: bool = (
		mode == "IMAGE_STIMULUS"
		and not media_path.is_empty()
		and ResourceLoader.exists(media_path)
	)

	question_media_panel.visible = show_media

	if not show_media:
		_loaded_media_path = ""
		question_media_image.texture = null
		return

	if media_path == _loaded_media_path and question_media_image.texture != null:
		return

	var loaded_resource: Resource = load(media_path)
	question_media_image.texture = loaded_resource as Texture2D
	_loaded_media_path = media_path

func _play_answer_result_sfx(feedback_value: String) -> void:
	var feedback_kind: String = _feedback_kind(feedback_value)
	if feedback_kind == "correct":
		AudioManager.play_choice_feedback(true)
		_answer_result_sfx_played = true
	elif feedback_kind == "wrong":
		AudioManager.play_choice_feedback(false)
		_answer_result_sfx_played = true

func _feedback_first_line(value: String) -> String:
	var lines: PackedStringArray = value.strip_edges().split("\n")

	for raw_line in lines:
		var line: String = str(raw_line).strip_edges()

		if not line.is_empty():
			return line

	return ""


func _feedback_is_timeout(value: String) -> bool:
	var lowered: String = _feedback_first_line(value).to_lower()

	return (
		lowered.begins_with("waktu menjawab habis")
		or lowered.begins_with("timeout")
	)


func _feedback_kind(value: String) -> String:
	var lowered: String = _feedback_first_line(value).to_lower()

	if lowered.is_empty():
		return "neutral"

	if (
		lowered.begins_with("waktu menjawab habis")
		or lowered.begins_with("timeout")
	):
		return "wrong"

	for wrong_token in [
		"belum tepat",
		"jawaban salah",
		"salah",
		"wrong",
		"coba lagi"
	]:
		if lowered.begins_with(wrong_token):
			return "wrong"

	for correct_token in [
		"benar",
		"tepat",
		"correct",
		"hebat"
	]:
		if lowered.begins_with(correct_token):
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
