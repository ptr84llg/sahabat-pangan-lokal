class_name LevelFlowController
extends Control

const LEVEL_INTRO_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_intro.tscn"
)

const LEVEL_DIALOGUE_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_dialogue.tscn"
)

const LEVEL_TUTORIAL_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_tutorial.tscn"
)

const LEVEL_SUCCESS_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_success.tscn"
)

const LEVEL_CHALLENGE_INTRO_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_challenge_intro.tscn"
)

const LEVEL_QUESTION_GAME_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_question_game.tscn"
)

const LEVEL_COMPLETE_SCREEN_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_complete_screen.tscn"
)

const LEVEL_FOOD_INFORMATION_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_food_information.tscn"
)

const LEVEL_BADGE_REWARD_SCENE: PackedScene = preload(
	"res://scenes/levels/shared/level_badge_reward.tscn"
)

const LEVEL_BACKGROUND_PATHS: Dictionary = {
	2: "res://assets/visual/level_backgrounds/level_02_class_room.png",
	3: "res://assets/visual/level_backgrounds/level_03_market.png",
	4: "res://assets/visual/level_backgrounds/level_04_dapur.png",
	5: "res://assets/visual/level_backgrounds/level_05_festival.png"
}

const LEVEL_INTRO_NAMES: Dictionary = {
	1: "RUMAH",
	2: "SEKOLAH",
	3: "PASAR",
	4: "DAPUR",
	5: "FESTIVAL"
}

const LEVEL_INTRO_FALLBACK: Dictionary = {
	1: "Kenali pangan lokal di sekitar rumah dan siapkan diri untuk memulai permainan.",
	2: "Kelompokkan pangan lokal sesuai jenis dan kategorinya melalui tantangan di sekolah.",
	3: "Pilih pangan yang tepat saat berbelanja dan atur Koin Pangan dengan cermat.",
	4: "Padukan dua bahan pangan lokal lalu pilih proses pengolahan yang tepat.",
	5: "Gunakan seluruh pengetahuanmu untuk menyelesaikan tantangan Festival Pangan Lokal."
}

var current_state: String = ""
var _level_background: TextureRect
var _active_window: Control
var _global_audio_game_phase: String = ""
var _global_audio_last_event_token: String = ""
var _pending_speaker: String = ""
var _level4_helper_message: String = ""
var _level_intro_presenter: Control
var _level_dialogue_presenter: Control
var _level_tutorial_presenter: Control
var _level_success_presenter: Control
var _level_challenge_intro_presenter: Control
var _level_question_game_presenter: Control
var _level_complete_presenter: Control
var _level_food_information_presenter: Control
var _level_badge_reward_presenter: Control


func _prepare_level_presentation() -> void:
	_apply_level_background()
	_ensure_level_intro_presenter()
	_ensure_level_dialogue_presenter()
	_ensure_level_tutorial_presenter()
	_ensure_level_success_presenter()
	_ensure_level_challenge_intro_presenter()
	_ensure_level_question_game_presenter()
	_ensure_level_complete_presenter()
	_ensure_level_food_information_presenter()
	_ensure_level_badge_reward_presenter()
	call_deferred("_refresh_level_intro_presenter")
	call_deferred("_refresh_level_dialogue_presenter")
	call_deferred("_refresh_level_tutorial_presenter")
	call_deferred("_refresh_level_success_presenter")
	call_deferred("_refresh_level_challenge_intro_presenter")
	call_deferred("_refresh_level_question_game_presenter")
	call_deferred("_refresh_level_complete_presenter")
	call_deferred("_refresh_level_food_information_presenter")
	call_deferred("_refresh_level_badge_reward_presenter")


func set_state(new_state: String) -> void:
	current_state = new_state

	if not _is_dialogue_state():
		_pending_speaker = ""

	AnalyticsLogger.log_event(
		"level_state_changed",
		{
			"level": get_meta("level_no", 0),
			"state": new_state
		}
	)
	call_deferred("_refresh_level_intro_presenter")
	call_deferred("_refresh_level_dialogue_presenter")
	call_deferred("_refresh_level_tutorial_presenter")
	call_deferred("_refresh_level_success_presenter")
	call_deferred("_refresh_level_challenge_intro_presenter")
	call_deferred("_refresh_level_question_game_presenter")
	call_deferred("_refresh_level_complete_presenter")
	call_deferred("_refresh_level_food_information_presenter")
	call_deferred("_refresh_level_badge_reward_presenter")


func show_only(nodes: Array[Control], active: Control) -> void:
	for node_variant in nodes:
		var node: Control = node_variant as Control

		if node != null:
			node.visible = node == active

	_active_window = active
	_dispatch_global_screen_sfx(active)
	call_deferred("_refresh_level_intro_presenter")
	call_deferred("_refresh_level_dialogue_presenter")
	call_deferred("_refresh_level_tutorial_presenter")
	call_deferred("_refresh_level_success_presenter")
	call_deferred("_refresh_level_challenge_intro_presenter")
	call_deferred("_refresh_level_question_game_presenter")
	call_deferred("_refresh_level_complete_presenter")
	call_deferred("_refresh_level_food_information_presenter")
	call_deferred("_refresh_level_badge_reward_presenter")

func _dispatch_global_screen_sfx(active: Control) -> void:
	if active == null:
		return
	var state_upper: String = current_state.to_upper()
	var window_name: String = str(active.name).to_lower()
	var phase: String = _resolve_global_game_audio_phase(window_name, state_upper)
	if not phase.is_empty():
		if _global_audio_game_phase != phase:
			_global_audio_game_phase = phase
			AudioManager.play_sfx("scene_game_open")
		return
	var event_key: String = ""
	if _is_global_level_done_audio_state(window_name, state_upper):
		event_key = "scene_level_done"
	elif _is_global_badge_audio_state(window_name, state_upper):
		event_key = "scene_badge"
	if event_key.is_empty():
		return
	var event_token: String = event_key + ":" + str(active.get_instance_id())
	if _global_audio_last_event_token == event_token:
		return
	_global_audio_last_event_token = event_token
	AudioManager.play_sfx(event_key)

func _resolve_global_game_audio_phase(window_name: String, state_upper: String) -> String:
	if window_name == "gameplaylayer" or window_name == "maingamehud" or window_name == "gameplayhud":
		if not state_upper.contains("SUCCESS") and not state_upper.contains("COMPLETE") and not state_upper.contains("RESULT"):
			return "game1"
	if state_upper in ["GAMEPLAY", "MAIN_GAME", "MAIN_GAME_PLAYER_CONTROL"]:
		return "game1"
	if window_name.contains("literacy") or window_name == "quizhud" or window_name.contains("game2"):
		return "game2"
	if state_upper.begins_with("LITERACY_") or state_upper.begins_with("QUESTION_") or state_upper.begins_with("QUIZ_"):
		if not state_upper.contains("RESULT") and not state_upper.contains("COMPLETE"):
			return "game2"
	return ""

func _is_global_level_done_audio_state(window_name: String, state_upper: String) -> bool:
	if state_upper == "RESULT" or state_upper == "FINAL_RESULT" or state_upper == "LEVEL_RESULT":
		return true
	if state_upper.ends_with("_RESULT") and not state_upper.begins_with("MAIN_GAME"):
		return true
	if window_name == "resultpanel" or window_name == "finalresultpanel":
		return true
	return false

func _is_global_badge_audio_state(window_name: String, state_upper: String) -> bool:
	return state_upper.contains("BADGE") or window_name.contains("badge")

func _set_dialogue_speaker(speaker: String) -> void:
	_pending_speaker = speaker
	call_deferred("_refresh_level_dialogue_presenter")


func _set_level4_helper_message(message: String) -> void:
	_level4_helper_message = message


func _ensure_level_intro_presenter() -> void:
	if is_instance_valid(_level_intro_presenter):
		return

	var presenter_node: Node = LEVEL_INTRO_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelIntro scene root must extend Control.")
		return

	_level_intro_presenter = presenter_control
	_level_intro_presenter.name = "LevelIntro"
	_level_intro_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_intro_presenter.z_index = 250
	add_child(_level_intro_presenter)


func _refresh_level_intro_presenter() -> void:
	_ensure_level_intro_presenter()

	if not is_instance_valid(_level_intro_presenter):
		return

	if current_state != "THEME_INTRO":
		_level_intro_presenter.call("hide_presenter")
		return

	if not is_instance_valid(_active_window):
		_level_intro_presenter.call("hide_presenter")
		return

	var level_no: int = int(get_meta("level_no", 0))
	var level_name: String = str(
		LEVEL_INTRO_NAMES.get(level_no, "LEVEL")
	)
	var intro_text: String = _resolve_level_intro_text(
		_active_window,
		level_no
	)
	var continue_target: Button = _find_button_by_names(
		_active_window,
		[
			"ThemeStartButton",
			"StartButton",
			"NextButton"
		]
	)

	_level_intro_presenter.call(
		"present",
		_active_window,
		level_name,
		intro_text,
		continue_target
	)


func _ensure_level_dialogue_presenter() -> void:
	if is_instance_valid(_level_dialogue_presenter):
		return

	var presenter_node: Node = LEVEL_DIALOGUE_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelDialogue scene root must extend Control.")
		return

	_level_dialogue_presenter = presenter_control
	_level_dialogue_presenter.name = "LevelDialogue"
	_level_dialogue_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_dialogue_presenter.z_index = 260
	add_child(_level_dialogue_presenter)


func _refresh_level_dialogue_presenter() -> void:
	_ensure_level_dialogue_presenter()

	if not is_instance_valid(_level_dialogue_presenter):
		return

	if not _is_dialogue_state():
		_level_dialogue_presenter.call("hide_presenter")
		return

	if not is_instance_valid(_active_window):
		_level_dialogue_presenter.call("hide_presenter")
		return

	var level_no: int = int(get_meta("level_no", 0))
	var speaker_name: String = _resolve_dialogue_speaker(
		_active_window
	)
	var dialogue_text: String = _resolve_dialogue_text(
		_active_window
	)
	var continue_target: Button = _find_button_by_names(
		_active_window,
		[
			"DialogueNextButton",
			"ClosingNextButton",
			"ClosingMapButton",
			"NextButton"
		]
	)

	_level_dialogue_presenter.call(
		"present",
		_active_window,
		level_no,
		speaker_name,
		dialogue_text,
		continue_target
	)


func _ensure_level_tutorial_presenter() -> void:
	if is_instance_valid(_level_tutorial_presenter):
		return

	var presenter_node: Node = LEVEL_TUTORIAL_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelTutorial scene root must extend Control.")
		return

	_level_tutorial_presenter = presenter_control
	_level_tutorial_presenter.name = "LevelTutorial"
	_level_tutorial_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_tutorial_presenter.z_index = 270
	add_child(_level_tutorial_presenter)


func _refresh_level_tutorial_presenter() -> void:
	_ensure_level_tutorial_presenter()

	if not is_instance_valid(_level_tutorial_presenter):
		return

	if not _is_tutorial_state():
		_level_tutorial_presenter.call("hide_presenter")
		return

	if not is_instance_valid(_active_window):
		_level_tutorial_presenter.call("hide_presenter")
		return

	var step_text: String = _resolve_tutorial_step(
		_active_window
	)
	var tutorial_text: String = _resolve_tutorial_text(
		_active_window
	)
	var continue_target: Button = _find_button_by_names(
		_active_window,
		[
			"TutorialContinueButton",
			"TutorialNextButton",
			"ContinueButton",
			"NextButton"
		]
	)

	_level_tutorial_presenter.call(
		"present",
		_active_window,
		step_text,
		tutorial_text,
		continue_target
	)


func _ensure_level_success_presenter() -> void:
	if is_instance_valid(_level_success_presenter):
		return

	var presenter_node: Node = LEVEL_SUCCESS_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelSuccess scene root must extend Control.")
		return

	_level_success_presenter = presenter_control
	_level_success_presenter.name = "LevelSuccess"
	_level_success_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_success_presenter.z_index = 280
	add_child(_level_success_presenter)


func _refresh_level_success_presenter() -> void:
	_ensure_level_success_presenter()

	if not is_instance_valid(_level_success_presenter):
		return

	if not _has_success_signature():
		_level_success_presenter.call("hide_presenter")
		return

	var success_text: String = _resolve_success_text(
		_active_window
	)
	var continue_target: Button = _resolve_success_button(
		_active_window
	)

	if success_text.is_empty() or continue_target == null:
		_level_success_presenter.call("hide_presenter")
		return

	_level_success_presenter.call(
		"present",
		_active_window,
		success_text,
		continue_target
	)


func _has_success_signature() -> bool:
	if not is_instance_valid(_active_window):
		return false

	var window_name: String = str(
		_active_window.name
	).to_lower()

	if window_name.contains("success"):
		return true

	if not current_state.contains("SUCCESS"):
		return false

	var success_text: String = _resolve_success_text(
		_active_window
	)
	var success_button: Button = _resolve_success_button(
		_active_window
	)

	return (
		not success_text.is_empty()
		and success_button != null
	)


func _resolve_success_text(
	root_node: Node
) -> String:
	for target_name in [
		"GameplaySuccessText",
		"MainSuccessText",
		"LiteracySuccessText",
		"QuizSuccessText",
		"ChallengeSuccessText",
		"SuccessMessage",
		"SuccessText"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		var value: String = _text_from_node(
			found_node
		)

		if not value.is_empty():
			return value

	return _find_success_text_descendant(
		root_node
	)


func _find_success_text_descendant(
	root_node: Node
) -> String:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		var child_name: String = str(
			child_node.name
		).to_lower()
		var candidate_name: bool = (
			child_name.contains("success")
			and not child_name.contains("button")
			and not child_name.contains("title")
		)

		if candidate_name:
			var candidate_text: String = _text_from_node(
				child_node
			)

			if not candidate_text.is_empty():
				return candidate_text

		var nested_text: String = _find_success_text_descendant(
			child_node
		)

		if not nested_text.is_empty():
			return nested_text

	return ""


func _text_from_node(
	source_node: Node
) -> String:
	if source_node == null:
		return ""

	if source_node is Label:
		var source_label: Label = source_node as Label
		return source_label.text.strip_edges()

	if source_node is RichTextLabel:
		var source_rich: RichTextLabel = source_node as RichTextLabel
		return source_rich.text.strip_edges()

	return ""


func _resolve_success_button(
	root_node: Node
) -> Button:
	var named_button: Button = _find_button_by_names(
		root_node,
		[
			"GameplaySuccessNextButton",
			"MainSuccessNextButton",
			"LiteracySuccessNextButton",
			"QuizSuccessNextButton",
			"ChallengeSuccessNextButton",
			"SuccessNextButton",
			"SuccessContinueButton"
		]
	)

	if named_button != null:
		return named_button

	return _find_success_button_descendant(
		root_node
	)


func _find_success_button_descendant(
	root_node: Node
) -> Button:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is Button:
			var button_node: Button = child_node as Button
			var button_name: String = str(
				button_node.name
			).to_lower()

			if (
				button_name.contains("success")
				or button_name.contains("next")
				or button_name.contains("continue")
			):
				return button_node

		var nested_button: Button = _find_success_button_descendant(
			child_node
		)

		if nested_button != null:
			return nested_button

	return null

func _ensure_level_challenge_intro_presenter() -> void:
	if is_instance_valid(_level_challenge_intro_presenter):
		return

	var presenter_node: Node = LEVEL_CHALLENGE_INTRO_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelChallengeIntro scene root must extend Control.")
		return

	_level_challenge_intro_presenter = presenter_control
	_level_challenge_intro_presenter.name = "LevelChallengeIntro"
	_level_challenge_intro_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_challenge_intro_presenter.z_index = 290
	add_child(_level_challenge_intro_presenter)


func _refresh_level_challenge_intro_presenter() -> void:
	_ensure_level_challenge_intro_presenter()

	if not is_instance_valid(_level_challenge_intro_presenter):
		return

	if not _is_challenge_intro_state():
		_level_challenge_intro_presenter.call("hide_presenter")
		return

	if not is_instance_valid(_active_window):
		_level_challenge_intro_presenter.call("hide_presenter")
		return

	var title_text: String = _resolve_challenge_title(_active_window)
	var instruction_text: String = _resolve_challenge_instruction(
		_active_window
	)
	var start_target: Button = _resolve_challenge_start_button(
		_active_window
	)

	if (
		title_text.is_empty()
		or instruction_text.is_empty()
		or start_target == null
	):
		_level_challenge_intro_presenter.call("hide_presenter")
		return

	_level_challenge_intro_presenter.call(
		"present",
		_active_window,
		title_text,
		instruction_text,
		start_target
	)


func _is_challenge_intro_state() -> bool:
	if not is_instance_valid(_active_window):
		return false

	var state_upper: String = current_state.to_upper()

	for blocked_token in [
		"THEME_INTRO",
		"DIALOGUE",
		"TUTORIAL",
		"SUCCESS",
		"GAMEPLAY",
		"RESULT",
		"INFO",
		"BADGE",
		"CLOSING"
	]:
		if state_upper.contains(blocked_token):
			return false

	for accepted_token in [
		"LITERACY_PREP",
		"CHALLENGE_PREP",
		"QUIZ_PREP",
		"QUESTION_PREP",
		"LITERACY_INTRO",
		"CHALLENGE_INTRO",
		"QUIZ_INTRO",
		"QUESTION_INTRO",
		"LITERACY_READY",
		"CHALLENGE_READY",
		"QUIZ_READY",
		"QUESTION_READY",
		"PREPARE",
		"PREPARATION"
	]:
		if state_upper.contains(accepted_token):
			return true

	var window_name: String = str(_active_window.name).to_lower()
	var family_match: bool = (
		window_name.contains("literacy")
		or window_name.contains("challenge")
		or window_name.contains("quiz")
		or window_name.contains("question")
	)
	var preparation_match: bool = (
		window_name.contains("prep")
		or window_name.contains("intro")
		or window_name.contains("ready")
	)

	return family_match and preparation_match


func _resolve_challenge_title(root_node: Node) -> String:
	for target_name in [
		"LiteracyTitle",
		"ChallengeTitle",
		"QuizTitle",
		"QuestionTitle",
		"PreparationTitle",
		"PrepareTitle",
		"TitleLabel",
		"Title"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return _find_challenge_title_descendant(root_node)


func _find_challenge_title_descendant(root_node: Node) -> String:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		var child_name: String = str(child_node.name).to_lower()
		var title_candidate: bool = (
			child_name.contains("title")
			or child_name.contains("header")
			or child_name.contains("challenge_name")
		)

		if title_candidate:
			var title_text: String = _text_from_node(child_node)

			if not title_text.is_empty():
				return title_text

		var nested_text: String = _find_challenge_title_descendant(
			child_node
		)

		if not nested_text.is_empty():
			return nested_text

	return ""


func _resolve_challenge_instruction(root_node: Node) -> String:
	for target_name in [
		"LiteracyIntroText",
		"LiteracyInstruction",
		"ChallengeInstruction",
		"QuizInstruction",
		"QuestionInstruction",
		"PreparationText",
		"PrepareText",
		"InstructionText",
		"DescriptionText",
		"MissionIntro",
		"BodyText",
		"Text"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return _find_challenge_instruction_descendant(root_node)


func _find_challenge_instruction_descendant(
	root_node: Node
) -> String:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		var child_name: String = str(child_node.name).to_lower()
		var instruction_candidate: bool = (
			child_name.contains("instruction")
			or child_name.contains("guide")
			or child_name.contains("description")
			or child_name.contains("mission")
			or child_name.contains("body")
		)

		if instruction_candidate:
			var instruction_text: String = _text_from_node(child_node)

			if not instruction_text.is_empty():
				return instruction_text

		var nested_text: String = _find_challenge_instruction_descendant(
			child_node
		)

		if not nested_text.is_empty():
			return nested_text

	return ""


func _resolve_challenge_start_button(root_node: Node) -> Button:
	var named_button: Button = _find_button_by_names(
		root_node,
		[
			"LiteracyStartButton",
			"LiteracyPrepareNextButton",
			"LiteracyNextButton",
			"ChallengeStartButton",
			"QuizStartButton",
			"QuestionStartButton",
			"StartChallengeButton",
			"StartQuizButton",
			"PrepareNextButton",
			"StartButton",
			"ContinueButton",
			"NextButton"
		]
	)

	if named_button != null:
		return named_button

	return _find_challenge_start_button_descendant(root_node)


func _find_challenge_start_button_descendant(
	root_node: Node
) -> Button:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is Button:
			var button_node: Button = child_node as Button
			var button_name: String = str(button_node.name).to_lower()
			var valid_button: bool = (
				button_name.contains("start")
				or button_name.contains("continue")
				or button_name.contains("next")
			)
			var blocked_button: bool = (
				button_name.contains("back")
				or button_name.contains("skip")
				or button_name.contains("close")
			)

			if valid_button and not blocked_button:
				return button_node

		var nested_button: Button = _find_challenge_start_button_descendant(
			child_node
		)

		if nested_button != null:
			return nested_button

	return null

func _ensure_level_question_game_presenter() -> void:
	if is_instance_valid(_level_question_game_presenter):
		return

	var presenter_node: Node = LEVEL_QUESTION_GAME_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelQuestionGame scene root must extend Control.")
		return

	_level_question_game_presenter = presenter_control
	_level_question_game_presenter.name = "LevelQuestionGame"
	_level_question_game_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_question_game_presenter.z_index = 300
	add_child(_level_question_game_presenter)


func _refresh_level_question_game_presenter() -> void:
	_ensure_level_question_game_presenter()

	if not is_instance_valid(_level_question_game_presenter):
		return

	if not _is_question_game_state():
		_level_question_game_presenter.call("hide_presenter")
		return

	if not is_instance_valid(_active_window):
		_level_question_game_presenter.call("hide_presenter")
		return

	var question_node: Node = _resolve_question_text_node(
		_active_window
	)
	var answer_buttons: Array[Button] = _resolve_question_answer_buttons(
		_active_window
	)

	if question_node == null or answer_buttons.size() < 2:
		_level_question_game_presenter.call("hide_presenter")
		return

	var question_value: String = _text_from_node(question_node)

	if question_value.is_empty():
		_level_question_game_presenter.call("hide_presenter")
		return

	_level_question_game_presenter.call(
		"present",
		_active_window,
		question_node,
		answer_buttons
	)


func _is_question_game_state() -> bool:
	if not is_instance_valid(_active_window):
		return false

	var state_upper: String = current_state.to_upper()

	for blocked_token in [
		"THEME_INTRO",
		"DIALOGUE",
		"TUTORIAL",
		"SUCCESS",
		"PREP",
		"INTRO",
		"READY",
		"RESULT",
		"INFO",
		"BADGE",
		"CLOSING",
		"GAMEPLAY",
		"SCHEMA"
	]:
		if state_upper.contains(blocked_token):
			return false

	var family_match: bool = (
		state_upper.contains("QUESTION")
		or state_upper.contains("QUIZ")
		or state_upper.contains("LITERACY")
		or state_upper.contains("CHALLENGE")
	)

	if not family_match:
		var window_name: String = str(_active_window.name).to_upper()
		family_match = (
			window_name.contains("QUESTION")
			or window_name.contains("QUIZ")
			or window_name.contains("LITERACY")
			or window_name.contains("CHALLENGE")
		)

	if not family_match:
		return false

	var question_node: Node = _resolve_question_text_node(
		_active_window
	)
	var answer_buttons: Array[Button] = _resolve_question_answer_buttons(
		_active_window
	)

	return (
		question_node != null
		and not _text_from_node(question_node).is_empty()
		and answer_buttons.size() >= 2
	)


func _resolve_question_text_node(root_node: Node) -> Node:
	for target_name in [
		"QuestionText",
		"LiteracyQuestionText",
		"QuizQuestionText",
		"QuestionLabel",
		"PromptText",
		"Prompt",
		"Question"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if (
			found_node is Label
			or found_node is RichTextLabel
		):
			var value: String = _text_from_node(found_node)

			if not value.is_empty():
				return found_node

	return _find_question_text_descendant(root_node)


func _find_question_text_descendant(root_node: Node) -> Node:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		var child_name: String = str(child_node.name).to_lower()
		var candidate_name: bool = (
			child_name.contains("question")
			or child_name.contains("prompt")
	)
		var blocked_name: bool = (
			child_name.contains("progress")
			or child_name.contains("timer")
			or child_name.contains("title")
			or child_name.contains("button")
		)

		if candidate_name and not blocked_name:
			if child_node is Label or child_node is RichTextLabel:
				var value: String = _text_from_node(child_node)

				if not value.is_empty():
					return child_node

		var nested_node: Node = _find_question_text_descendant(
			child_node
		)

		if nested_node != null:
			return nested_node

	return null


func _resolve_question_answer_buttons(root_node: Node) -> Array[Button]:
	var output: Array[Button] = []

	for target_name in [
		"AnswerA",
		"AnswerB",
		"AnswerC",
		"AnswerD",
		"LiteracyAnswerA",
		"LiteracyAnswerB",
		"LiteracyAnswerC",
		"LiteracyAnswerD",
		"QuizAnswerA",
		"QuizAnswerB",
		"QuizAnswerC",
		"QuizAnswerD",
		"OptionA",
		"OptionB",
		"OptionC",
		"OptionD",
		"ChoiceA",
		"ChoiceB",
		"ChoiceC",
		"ChoiceD",
		"Answer1",
		"Answer2",
		"Answer3",
		"Answer4"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Button:
			var found_button: Button = found_node as Button

			if not output.has(found_button):
				output.append(found_button)

	if output.size() >= 2:
		return output

	output.clear()
	_collect_question_answer_buttons(root_node, output)
	return output


func _collect_question_answer_buttons(
	root_node: Node,
	output: Array[Button]
) -> void:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is Button:
			var child_button: Button = child_node as Button
			var button_name: String = str(child_button.name).to_lower()
			var candidate_name: bool = (
				button_name.contains("answer")
				or button_name.contains("option")
				or button_name.contains("choice")
			)
			var blocked_name: bool = (
				button_name.contains("start")
				or button_name.contains("retry")
				or button_name.contains("result")
				or button_name.contains("next")
				or button_name.contains("continue")
				or button_name.contains("back")
				or button_name.contains("hint")
			)

			if (
				candidate_name
				and not blocked_name
				and not output.has(child_button)
			):
				output.append(child_button)

		_collect_question_answer_buttons(child_node, output)


func _ensure_level_complete_presenter() -> void:
	if is_instance_valid(_level_complete_presenter):
		return

	var presenter_node: Node = LEVEL_COMPLETE_SCREEN_SCENE.instantiate()
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error("LevelCompleteScreen scene root must extend Control.")
		return

	_level_complete_presenter = presenter_control
	_level_complete_presenter.name = "LevelCompleteScreen"
	_level_complete_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_complete_presenter.z_index = 300
	add_child(_level_complete_presenter)


func _refresh_level_complete_presenter() -> void:
	_ensure_level_complete_presenter()

	if not is_instance_valid(_level_complete_presenter):
		return

	if not _has_level_complete_signature():
		_level_complete_presenter.call("hide_presenter")
		return

	var native_button: Button = _resolve_level_complete_primary_button(
		_active_window
	)

	if native_button == null:
		_level_complete_presenter.call("hide_presenter")
		return

	var completion_data: Dictionary = _build_level_complete_data(
		_active_window,
		native_button
	)

	_level_complete_presenter.call(
		"show_completion",
		_active_window,
		completion_data,
		native_button
	)


func _has_level_complete_signature() -> bool:
	if not is_instance_valid(_active_window):
		return false

	var state_upper: String = current_state.to_upper()
	var window_name: String = str(_active_window.name).to_lower()

	var result_state: bool = (
		state_upper == "RESULT"
		or state_upper.ends_with("_RESULT")
		or state_upper.contains("LEVEL_RESULT")
	)
	var result_window: bool = (
		window_name.contains("result")
		or window_name.contains("complete")
		or window_name.contains("summary")
		or window_name.contains("finish")
	)

	if not result_window:
		return false

	var native_button: Button = _resolve_level_complete_primary_button(
		_active_window
	)
	var score_text: String = _resolve_level_complete_score_from_window(
		_active_window
	)
	var summary_text: String = _resolve_level_complete_summary_from_window(
		_active_window
	)

	var has_native_content: bool = (
		not score_text.is_empty()
		or not summary_text.is_empty()
	)

	return (
		native_button != null
		and has_native_content
		and (
			result_state
			or window_name.contains("result")
			or window_name.contains("summary")
		)
	)


func _build_level_complete_data(
	root_node: Node,
	native_button: Button
) -> Dictionary:
	var level_no: int = int(get_meta("level_no", 0))
	var level_name: String = str(
		LEVEL_INTRO_NAMES.get(level_no, "")
	)
	var message_text: String = "Kamu berhasil menyelesaikan level ini."

	if not level_name.is_empty():
		var readable_name: String = level_name.to_lower().capitalize()
		message_text = (
			"Kamu berhasil menyelesaikan seluruh kegiatan di " +
			readable_name +
			"."
		)

	var summary_text: String = _resolve_level_complete_summary_from_window(
		root_node
	)
	var duration_text: String = _extract_level_complete_summary_value(
		summary_text,
		[
			"durasi aktif",
			"durasi",
			"waktu aktif",
			"waktu"
		]
	)
	var result_text: String = _summary_without_duration(
		summary_text
	)
	var score_text: String = _resolve_level_complete_score_from_window(
		root_node
	)
	var badge_name: String = _resolve_level_complete_badge_name(
		level_no
	)
	var button_text: String = native_button.text.strip_edges()

	if button_text.is_empty():
		button_text = "LANJUT"

	return {
		"level": level_no,
		"message": message_text,
		"duration_text": duration_text,
		"score_text": score_text,
		"result_text": result_text,
		"badge_name": badge_name,
		"button_text": button_text
	}


func _resolve_level_complete_score_from_window(
	root_node: Node
) -> String:
	for target_name in [
		"ResultScore",
		"FinalScore",
		"ScoreValue",
		"TotalScore",
		"CompletionScore"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return ""


func _resolve_level_complete_summary_from_window(
	root_node: Node
) -> String:
	for target_name in [
		"ResultSummary",
		"SummaryText",
		"ResultText",
		"CompletionSummary",
		"FinalSummary"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return _find_longest_result_summary_text(root_node)


func _find_longest_result_summary_text(
	root_node: Node
) -> String:
	var best_text: String = ""

	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if not (child_node is Button):
			var child_text: String = _text_from_node(child_node)

			if child_text.length() > best_text.length():
				best_text = child_text

		var nested_text: String = _find_longest_result_summary_text(
			child_node
		)

		if nested_text.length() > best_text.length():
			best_text = nested_text

	return best_text.strip_edges()


func _extract_level_complete_summary_value(
	summary_text: String,
	label_tokens: Array
) -> String:
	if summary_text.is_empty():
		return ""

	for line_variant in summary_text.split("\n"):
		var line_text: String = str(line_variant).strip_edges()
		var line_lower: String = line_text.to_lower()

		for token_variant in label_tokens:
			var token_text: String = str(token_variant).to_lower()

			if not line_lower.begins_with(token_text):
				continue

			var colon_index: int = line_text.find(":")

			if colon_index >= 0:
				return line_text.substr(
					colon_index + 1
				).strip_edges()

	return ""


func _summary_without_duration(
	summary_text: String
) -> String:
	if summary_text.is_empty():
		return ""

	var kept_lines: Array[String] = []

	for line_variant in summary_text.split("\n"):
		var line_text: String = str(line_variant).strip_edges()
		var line_lower: String = line_text.to_lower()

		if line_text.is_empty():
			continue

		var is_duration_line: bool = (
			line_lower.begins_with("durasi")
			or line_lower.begins_with("waktu")
		)

		if not is_duration_line:
			kept_lines.append(line_text)

	return "\n".join(kept_lines)


func _resolve_level_complete_badge_name(
	level_no: int
) -> String:
	match level_no:
		1:
			return "Penjelajah Pangan Lokal"
		2:
			return "Penyusun Kelompok Pangan Lokal"
		3:
			return "Perencana Belanja Pangan"
		4:
			return "Peracik Pangan Lokal"
		5:
			return "Duta Pangan Lokal"
		_:
			return ""


func _resolve_level_complete_primary_button(
	root_node: Node
) -> Button:
	var named_button: Button = _find_button_by_names(
		root_node,
		[
			"ResultNextButton",
			"ResultContinueButton",
			"LevelResultNextButton",
			"SummaryNextButton",
			"SummaryContinueButton",
			"CompletionNextButton",
			"CompletionContinueButton"
		]
	)

	if named_button != null and named_button.visible:
		return named_button

	return _find_visible_level_result_button(root_node)


func _find_visible_level_result_button(
	root_node: Node
) -> Button:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is Button:
			var button_node: Button = child_node as Button
			var button_name: String = str(button_node.name).to_lower()
			var button_text: String = button_node.text.to_lower()

			var blocked_button: bool = (
				button_name.contains("retry")
				or button_name.contains("question")
				or button_name.contains("answer")
				or button_text.contains("coba lagi")
				or button_text.contains("soal berikut")
			)

			if button_node.visible and not blocked_button:
				return button_node

		var nested_button: Button = _find_visible_level_result_button(
			child_node
		)

		if nested_button != null:
			return nested_button

	return null


func _ensure_level_food_information_presenter() -> void:
	if is_instance_valid(_level_food_information_presenter):
		return

	var presenter_node: Node = (
		LEVEL_FOOD_INFORMATION_SCENE.instantiate()
	)
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error(
			"LevelFoodInformation scene root must extend Control."
		)
		return

	_level_food_information_presenter = presenter_control
	_level_food_information_presenter.name = (
		"LevelFoodInformation"
	)
	_level_food_information_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_food_information_presenter.z_index = 310
	add_child(_level_food_information_presenter)


func _refresh_level_food_information_presenter() -> void:
	_ensure_level_food_information_presenter()

	if not is_instance_valid(
		_level_food_information_presenter
	):
		return

	if not _has_food_information_signature():
		_level_food_information_presenter.call(
			"hide_presenter"
		)
		return

	var native_button: Button = (
		_resolve_food_information_button(
			_active_window
		)
	)

	if native_button == null:
		_level_food_information_presenter.call(
			"hide_presenter"
		)
		return

	var information_data: Dictionary = (
		_build_food_information_data(
			_active_window,
			native_button
		)
	)

	var name_text: String = str(
		information_data.get(
			"name_text",
			""
		)
	).strip_edges()
	var description_text: String = str(
		information_data.get(
			"description_text",
			""
		)
	).strip_edges()

	if name_text.is_empty() or description_text.is_empty():
		_level_food_information_presenter.call(
			"hide_presenter"
		)
		return

	_level_food_information_presenter.call(
		"show_information",
		_active_window,
		information_data,
		native_button
	)


func _has_food_information_signature() -> bool:
	if not is_instance_valid(_active_window):
		return false

	var state_upper: String = current_state.to_upper()
	var window_name: String = str(
		_active_window.name
	).to_lower()

	var info_state: bool = (
		state_upper.contains("FOOD_INFORMATION")
		or state_upper.contains("FOOD_INFO")
		or state_upper == "INFORMATION"
		or state_upper.ends_with("_INFO")
	)
	var info_window: bool = (
		window_name == "infopanel"
		or window_name.contains("foodinfo")
		or window_name.contains("food_info")
		or window_name.contains("information")
	)

	if not info_state and not info_window:
		return false

	var title_text: String = (
		_resolve_food_information_name(
			_active_window
		)
	)
	var description_text: String = (
		_resolve_food_information_description(
			_active_window
		)
	)
	var native_button: Button = (
		_resolve_food_information_button(
			_active_window
		)
	)

	return (
		not title_text.is_empty()
		and not description_text.is_empty()
		and native_button != null
	)


func _build_food_information_data(
	root_node: Node,
	native_button: Button
) -> Dictionary:
	return {
		"texture": _resolve_food_information_texture(
			root_node
		),
		"counter_text": _resolve_food_information_counter(
			root_node
		),
		"name_text": _resolve_food_information_name(
			root_node
		),
		"type_text": _resolve_food_information_type(
			root_node
		),
		"description_text": (
			_resolve_food_information_description(
				root_node
			)
		),
		"button_text": native_button.text
	}


func _resolve_food_information_texture(
	root_node: Node
) -> Texture2D:
	for target_name in [
		"InfoImage",
		"FoodImage",
		"PreviewImage",
		"ResultImage",
		"ProcessedImage",
		"ItemImage"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is TextureRect:
			var texture_rect: TextureRect = (
				found_node as TextureRect
			)

			if texture_rect.texture != null:
				return texture_rect.texture

	return null


func _resolve_food_information_counter(
	root_node: Node
) -> String:
	for target_name in [
		"InfoCounter",
		"FoodCounter",
		"CounterLabel",
		"InfoIndex",
		"PageCounter"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return ""


func _resolve_food_information_name(
	root_node: Node
) -> String:
	for target_name in [
		"InfoTitle",
		"FoodName",
		"InfoName",
		"ProcessedTitle",
		"ItemTitle"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return ""


func _resolve_food_information_type(
	root_node: Node
) -> String:
	for target_name in [
		"InfoType",
		"FoodType",
		"TypeLabel",
		"CategoryLabel",
		"InfoCategory"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return ""


func _resolve_food_information_description(
	root_node: Node
) -> String:
	for target_name in [
		"InfoText",
		"FoodDescription",
		"DescriptionText",
		"InfoDescription",
		"DetailText",
		"BodyText"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	return ""


func _resolve_food_information_button(
	root_node: Node
) -> Button:
	var named_button: Button = _find_button_by_names(
		root_node,
		[
			"InfoNextButton",
			"InfoContinueButton",
			"FoodInfoNextButton",
			"FoodInfoContinueButton",
			"NextButton",
			"ContinueButton",
			"DoneButton",
			"FinishButton"
		]
	)

	if named_button != null and named_button.visible:
		return named_button

	return _find_visible_food_information_button(
		root_node
	)


func _find_visible_food_information_button(
	root_node: Node
) -> Button:
	for child_variant in root_node.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		if child_node is Button:
			var button_node: Button = child_node as Button
			var button_name: String = str(
				button_node.name
			).to_lower()
			var blocked_button: bool = (
				button_name.contains("back")
				or button_name.contains("close")
				or button_name.contains("retry")
			)

			if button_node.visible and not blocked_button:
				return button_node

		var nested_button: Button = (
			_find_visible_food_information_button(
				child_node
			)
		)

		if nested_button != null:
			return nested_button

	return null


func _ensure_level_badge_reward_presenter() -> void:
	if is_instance_valid(_level_badge_reward_presenter):
		return

	var presenter_node: Node = (
		LEVEL_BADGE_REWARD_SCENE.instantiate()
	)
	var presenter_control: Control = presenter_node as Control

	if presenter_control == null:
		push_error(
			"LevelBadgeReward scene root must extend Control."
		)
		return

	_level_badge_reward_presenter = presenter_control
	_level_badge_reward_presenter.name = "LevelBadgeReward"
	_level_badge_reward_presenter.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_badge_reward_presenter.z_index = 315
	add_child(_level_badge_reward_presenter)


func _refresh_level_badge_reward_presenter() -> void:
	_ensure_level_badge_reward_presenter()

	if not is_instance_valid(
		_level_badge_reward_presenter
	):
		return

	if not _has_badge_reward_signature():
		_level_badge_reward_presenter.call(
			"hide_presenter"
		)
		return

	var native_button: Button = (
		_resolve_badge_reward_button(
			_active_window
		)
	)

	if native_button == null:
		_level_badge_reward_presenter.call(
			"hide_presenter"
		)
		return

	var reward_data: Dictionary = (
		_build_badge_reward_data(
			_active_window,
			native_button
		)
	)

	_level_badge_reward_presenter.call(
		"show_reward",
		_active_window,
		reward_data,
		native_button
	)


func _has_badge_reward_signature() -> bool:
	if not is_instance_valid(_active_window):
		return false

	var state_upper: String = current_state.to_upper()
	var window_name: String = str(
		_active_window.name
	).to_lower()

	var state_match: bool = (
		state_upper.contains("BADGE")
	)
	var window_match: bool = (
		window_name == "badgepanel"
		or window_name.contains("badge")
	)

	if not state_match and not window_match:
		return false

	return (
		_resolve_badge_reward_button(
			_active_window
		) != null
	)


func _build_badge_reward_data(
	root_node: Node,
	native_button: Button
) -> Dictionary:
	var level_number: String = str(
		int(get_meta("level_no", 0))
	)
	var badge_name: String = (
		_resolve_badge_reward_name(
			root_node,
			level_number
		)
	)
	var message_text: String = (
		_resolve_badge_reward_message(
			root_node,
			badge_name
		)
	)
	var button_text: String = native_button.text.strip_edges()

	if button_text.is_empty():
		button_text = "LANJUT"

	return {
		"level_number": level_number,
		"badge_name": badge_name,
		"message_text": message_text,
		"button_text": button_text
	}


func _resolve_badge_reward_button(
	root_node: Node
) -> Button:
	for target_name in [
		"BadgeNextButton",
		"BadgeButton",
		"ContinueButton",
		"NextButton",
		"PrimaryButton",
		"ActionButton"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Button:
			return found_node as Button

	return null


func _resolve_badge_reward_name(
	root_node: Node,
	level_number: String
) -> String:
	for target_name in [
		"BadgeTitle",
		"BadgeName",
		"Title",
		"BadgeHeader"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	match level_number:
		"1":
			return "Penjelajah Pangan Lokal"
		"2":
			return "Penyusun Kelompok Pangan Lokal"
		"3":
			return "Perencana Belanja Pangan"
		"4":
			return "Peracik Pangan Lokal"
		"5":
			return "Duta Pangan Lokal"
		_:
			return "Badge Pangan Lokal"


func _resolve_badge_reward_message(
	root_node: Node,
	badge_name: String
) -> String:
	for target_name in [
		"BadgeText",
		"BadgeDescription",
		"Description",
		"Text",
		"MessageLabel",
		"BodyLabel"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)
		var value: String = _text_from_node(found_node)

		if not value.is_empty():
			return value

	if badge_name.is_empty():
		return "Kamu mendapatkan badge baru."

	return "Kamu mendapatkan badge \"%s\"." % badge_name


func _badge_reward_extract_first_integer(
	text_value: String
) -> String:
	var digits: String = ""
	var started: bool = false

	for index in text_value.length():
		var character: String = text_value.substr(index, 1)
		var code_point: int = character.unicode_at(0)
		var is_digit: bool = code_point >= 48 and code_point <= 57

		if is_digit:
			digits += character
			started = true
		elif started:
			break

	return digits


func _is_dialogue_state() -> bool:
	return current_state.contains("DIALOGUE")


func _is_tutorial_state() -> bool:
	return current_state.contains("TUTORIAL")


func _resolve_dialogue_speaker(
	root_node: Node
) -> String:
	if not _pending_speaker.strip_edges().is_empty():
		return _pending_speaker.strip_edges()

	for target_name in [
		"SpeakerLabel",
		"ClosingSpeaker",
		"Speaker",
		"SpeakerName"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Label:
			var found_label: Label = found_node as Label
			var value: String = found_label.text.strip_edges()

			if not value.is_empty():
				return value

	return ""


func _resolve_dialogue_text(
	root_node: Node
) -> String:
	for target_name in [
		"DialogueText",
		"ClosingText",
		"ConversationText",
		"Text"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Label:
			var found_label: Label = found_node as Label
			var value: String = found_label.text.strip_edges()

			if not value.is_empty():
				return value

		if found_node is RichTextLabel:
			var found_rich_text: RichTextLabel = found_node as RichTextLabel
			var rich_value: String = found_rich_text.text.strip_edges()

			if not rich_value.is_empty():
				return rich_value

	return ""


func _resolve_tutorial_step(
	root_node: Node
) -> String:
	for target_name in [
		"TutorialStepLabel",
		"StepLabel",
		"TutorialStep",
		"StepText"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Label:
			var found_label: Label = found_node as Label
			var value: String = found_label.text.strip_edges()

			if not value.is_empty():
				return value

	return ""


func _resolve_tutorial_text(
	root_node: Node
) -> String:
	for target_name in [
		"TutorialText",
		"InstructionText",
		"TutorialInstruction",
		"DescriptionText",
		"Text"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Label:
			var found_label: Label = found_node as Label
			var value: String = found_label.text.strip_edges()

			if not value.is_empty():
				return value

		if found_node is RichTextLabel:
			var found_rich_text: RichTextLabel = found_node as RichTextLabel
			var rich_value: String = found_rich_text.text.strip_edges()

			if not rich_value.is_empty():
				return rich_value

	return ""


func _resolve_level_intro_text(
	root_node: Node,
	level_no: int
) -> String:
	for target_name in [
		"MissionIntro",
		"ThemeIntroText",
		"DescriptionText",
		"IntroText",
		"BodyText"
	]:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			target_name
		)

		if found_node is Label:
			var found_label: Label = found_node as Label
			var value: String = found_label.text.strip_edges()

			if not value.is_empty():
				return value

	return str(
		LEVEL_INTRO_FALLBACK.get(
			level_no,
			""
		)
	)


func _find_button_by_names(
	root_node: Node,
	names: Array
) -> Button:
	for name_variant in names:
		var found_node: Node = _find_descendant_by_name(
			root_node,
			str(name_variant)
		)

		if found_node is Button:
			return found_node as Button

	return null


func _find_descendant_by_name(
	root_node: Node,
	target_name: String
) -> Node:
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


func _apply_level_background() -> void:
	var level_no: int = int(get_meta("level_no", 0))
	var texture_path: String = str(
		LEVEL_BACKGROUND_PATHS.get(level_no, "")
	)

	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		return

	if is_instance_valid(_level_background):
		_level_background.queue_free()

	var loaded_resource: Resource = load(texture_path)

	if not loaded_resource is Texture2D:
		return

	_level_background = TextureRect.new()
	_level_background.name = "LevelBackgroundTexture"
	_level_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_level_background.texture = loaded_resource as Texture2D
	_level_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_level_background.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	_level_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_background.z_index = -100
	add_child(_level_background)
	move_child(_level_background, 0)


func _set_rect(
	control: Control,
	left: float,
	top: float,
	right: float,
	bottom: float
) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
