class_name LevelFlowController
extends Control

const LEVEL_INTRO_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_intro.tscn"
)

const LEVEL_DIALOGUE_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_dialogue.tscn"
)

const LEVEL_TUTORIAL_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_tutorial.tscn"
)

const LEVEL_SUCCESS_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_success.tscn"
)

const LEVEL_CHALLENGE_INTRO_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_challenge_intro.tscn"
)

const LEVEL_QUESTION_GAME_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_question_game.tscn"
)

const LEVEL_COMPLETE_SCREEN_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_complete_screen.tscn"
)

const LEVEL_FOOD_INFORMATION_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_food_information.tscn"
)

const LEVEL_BADGE_REWARD_SCENE: PackedScene = preload(
	"res://scenes/shared/level_flow/level_badge_reward.tscn"
)

const LEVEL_BACKGROUND_PATHS: Dictionary = {
	2: "res://assets/visual/backgrounds/levels/level_02_class_room.png",
	3: "res://assets/visual/backgrounds/levels/level_03_market.png",
	4: "res://assets/visual/backgrounds/levels/level_04_dapur.png",
	5: "res://assets/visual/backgrounds/levels/level_05_festival.png"
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
	2: "[color=#fd6001][b]Mengelompokkan pangan lokal[/b][/color]\nKita akan mengelompokkan pangan lokal sesuai jenis dan kategorinya.",
	3: "[color=#fd6001][b]Mari berbelanja dengan Koin.[/b][/color]\nPilih pangan yang tepat saat berbelanja dan gunakan Koin Pangan dengan cermat.",
	4: "[color=#fd6001][b]Mari kita mengolah pangan.[/b][/color]\nPadukan dua bahan pangan lokal,\nlalu pilih proses pengolahan yang tepat untuk menjadi sebuah pangan olahan.",
	5: "[color=#fd6001][b]Persiapkan semua pengetahuan mu.[/b][/color]\nGunakan seluruh pengetahuanmu untuk menyelesaikan tantangan Festival Pangan Lokal."
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
var _level_attempt_started: bool = false
var _level_attempt_id: String = ""
var _level_attempt_no: int = 0
var _last_finalized_level_attempt_id: String = ""


func _prepare_level_presentation() -> void:
	_ensure_level_attempt_started()
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


func _ensure_level_attempt_started() -> void:
	if _level_attempt_started:
		return

	_level_attempt_started = true
	var level_no: int = int(get_meta("level_no", 0))

	if level_no <= 0:
		return

	var attempt: Dictionary = TelemetryManager.begin_level_attempt(
		level_no
	)

	if attempt.is_empty():
		return

	_level_attempt_id = str(
		attempt.get("level_attempt_id", "")
	)
	_level_attempt_no = int(
		attempt.get("attempt_no", 0)
	)

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

	var state_upper: String = current_state.to_upper()
	var success_state: bool = state_upper.contains("SUCCESS")

	if state_upper == "MAIN_GAME_COMPLETE":
		success_state = true

	if not success_state:
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
		"MainResultText",
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
			"MainResultNextButton",
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
	_finalize_level_attempt_from_completion(
		completion_data
	)

	_level_complete_presenter.call(
		"show_completion",
		_active_window,
		completion_data,
		native_button
	)


func _finalize_level_attempt_from_completion(
	completion_data: Dictionary
) -> void:
	var level_attempt_id: String = str(
		completion_data.get("level_attempt_id", "")
	).strip_edges()

	if level_attempt_id.is_empty():
		return

	if _last_finalized_level_attempt_id == level_attempt_id:
		return

	var level_no: int = int(get_meta("level_no", 0))
	var success: bool = TelemetryManager.complete_level_attempt(
		level_no,
		level_attempt_id,
		int(completion_data.get("score_value", 0)),
		int(completion_data.get("duration_ms", 0)),
		float(completion_data.get("star_value", 0.0))
	)

	if success:
		_last_finalized_level_attempt_id = level_attempt_id

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
	var level_name: String = str(LEVEL_INTRO_NAMES.get(level_no, ""))
	var message_text: String = "Kamu berhasil menyelesaikan level ini."
	if not level_name.is_empty():
		message_text = "Kamu berhasil menyelesaikan seluruh kegiatan di " + level_name.to_lower().capitalize() + "."
	var badge_name: String = _resolve_level_complete_badge_name(level_no)
	var button_text: String = native_button.text.strip_edges()
	if button_text.is_empty():
		button_text = "LANJUT"
	var v3_metrics: Dictionary = _resolve_v3_level_complete_metrics(level_no)
	if not v3_metrics.is_empty():
		return {
			"level": level_no,
			"message": _merge_level_complete_message(message_text, str(v3_metrics.get("attempt_caption", ""))),
			"duration_text": str(v3_metrics.get("duration_text", "")),
			"score_text": str(v3_metrics.get("score_text", "")),
			"result_text": str(v3_metrics.get("result_text", "")),
			"detail_data": v3_metrics.get("detail_data", {}),
			"level_attempt_id": str(v3_metrics.get("level_attempt_id", "")),
			"score_value": int(v3_metrics.get("score_value", 0)),
			"duration_ms": int(v3_metrics.get("duration_ms", 0)),
			"star_value": float(v3_metrics.get("star_value", 0.0)),
			"badge_name": badge_name,
			"button_text": button_text
		}
	var summary_text: String = _resolve_level_complete_summary_from_window(root_node)
	var duration_text: String = _extract_level_complete_summary_value(summary_text, ["durasi aktif", "durasi", "waktu aktif", "waktu"])
	var result_text: String = _summary_without_duration(summary_text)
	var score_text: String = _resolve_level_complete_score_from_window(root_node)
	var fallback_attempt: Dictionary = _resolve_fallback_level_attempt(level_no)
	var level_attempt_id: String = str(fallback_attempt.get("level_attempt_id", "")).strip_edges()
	var level_attempt_no: int = int(fallback_attempt.get("attempt_no", 0))
	var score_value: int = _parse_level_complete_score_value(score_text)
	var duration_ms: int = _parse_level_complete_duration_ms(duration_text)
	var star_value: float = _resolve_level_star_value(score_value)
	var attempt_caption: String = ""
	if level_attempt_no > 1:
		attempt_caption = "(Percobaan ke-%d)" % level_attempt_no
	return {
		"level": level_no,
		"message": _merge_level_complete_message(message_text, attempt_caption),
		"duration_text": duration_text,
		"score_text": score_text,
		"result_text": result_text,
		"star_slots": _build_star_slots(star_value),
		"level_attempt_id": level_attempt_id,
		"score_value": score_value,
		"duration_ms": duration_ms,
		"star_value": star_value,
		"badge_name": badge_name,
		"button_text": button_text
	}

func _resolve_fallback_level_attempt(level_no: int) -> Dictionary:
	if level_no <= 0:
		return {}
	var current: Dictionary = SaveManager.load_v3_active_current()
	if current.is_empty():
		return {}
	var levels: Dictionary = current.get("levels", {})
	var level_value: Variant = levels.get(str(level_no), {})
	if not level_value is Dictionary:
		return {}
	var level: Dictionary = level_value
	return _resolve_active_level_attempt(level)

func _parse_level_complete_score_value(score_text: String) -> int:
	var normalized: String = score_text.strip_edges()
	if normalized.is_empty():
		return 0
	var parts: PackedStringArray = normalized.split("/", false, 1)
	var first_part: String = normalized
	if not parts.is_empty():
		first_part = parts[0].strip_edges()
	return clampi(int(first_part), 0, 100)

func _parse_level_complete_duration_ms(duration_text: String) -> int:
	var normalized: String = duration_text.strip_edges()
	if normalized.is_empty():
		return 0
	var parts: PackedStringArray = normalized.split(":", false)
	if parts.size() == 2:
		return (maxi(0, int(parts[0])) * 60 + maxi(0, int(parts[1]))) * 1000
	if parts.size() == 3:
		return (maxi(0, int(parts[0])) * 3600 + maxi(0, int(parts[1])) * 60 + maxi(0, int(parts[2]))) * 1000
	return 0

func _merge_level_complete_message(
	base_message: String,
	attempt_caption: String
) -> String:
	if attempt_caption.is_empty():
		return base_message

	return base_message + "\n" + attempt_caption


func _resolve_v3_level_complete_metrics(
	level_no: int
) -> Dictionary:
	if level_no <= 0:
		return {}

	var current: Dictionary = SaveManager.load_v3_active_current()

	if current.is_empty():
		return {}

	if int(current.get("schema_version", 0)) != 3:
		return {}

	if str(current.get("storage_mode", "")) != "native":
		return {}

	var levels: Dictionary = current.get("levels", {})
	var level: Dictionary = levels.get(str(level_no), {})
	var games: Dictionary = level.get("games", {})

	if games.is_empty():
		return {}

	var level_attempt: Dictionary = _resolve_active_level_attempt(
		level
	)
	var level_attempt_id: String = str(
		level_attempt.get("level_attempt_id", "")
	).strip_edges()
	var level_attempt_no: int = int(
		level_attempt.get("attempt_no", 0)
	)
	var game_ids: Array = games.keys()
	game_ids.sort()

	var completed_game_count: int = 0
	var game_score_total: int = 0
	var duration_total_ms: int = 0
	var game_details: Array[Dictionary] = []
	var result_lines: Array[String] = []

	for game_index in range(game_ids.size()):
		var game_id: String = str(game_ids[game_index])
		var game_value: Variant = games.get(game_id, {})

		if not game_value is Dictionary:
			continue

		var game: Dictionary = game_value

		if str(game.get("status", "")) != "completed":
			continue

		var attempt: Dictionary = _resolve_latest_completed_attempt(
			game,
			level_attempt_id
		)

		if attempt.is_empty():
			continue

		var summary: Dictionary = attempt.get(
			"game_summary",
			{}
		)

		if summary.is_empty():
			continue

		completed_game_count += 1
		game_score_total += int(
			summary.get("final_score", 0)
		)
		duration_total_ms += int(
			summary.get("total_duration_ms", 0)
		)

		var game_detail: Dictionary = _build_v3_game_detail(
			game_id,
			game_index + 1,
			game,
			attempt,
			summary
		)
		game_details.append(game_detail)
		result_lines.append(
			_format_v3_game_result_line(game_detail)
		)

	if completed_game_count <= 0:
		return {}

	var completion_bonus: int = _resolve_level_completion_bonus()
	var final_score: int = clampi(
		game_score_total + completion_bonus,
		0,
		100
	)
	var star_value: float = _resolve_level_star_value(
		final_score
	)
	var attempt_caption: String = ""

	if level_attempt_no > 1:
		attempt_caption = "(Percobaan ke-%d)" % level_attempt_no

	var star_slots: Array[String] = _build_star_slots(
		star_value
	)
	var duration_text: String = _format_level_complete_duration_ms(
		duration_total_ms
	)
	var score_text: String = "%d / 100" % final_score
	var detail_data: Dictionary = {
		"level_attempt_id": level_attempt_id,
		"attempt_no": level_attempt_no,
		"score_value": final_score,
		"score_text": score_text,
		"star_value": star_value,
		"star_slots": star_slots,
		"duration_ms": duration_total_ms,
		"duration_text": duration_text,
		"games": game_details
	}

	return {
		"level_attempt_id": level_attempt_id,
		"attempt_no": level_attempt_no,
		"attempt_caption": attempt_caption,
		"score_value": final_score,
		"score_text": score_text,
		"star_value": star_value,
		"star_slots": star_slots,
		"duration_ms": duration_total_ms,
		"duration_text": duration_text,
		"result_text": "\n\n".join(result_lines),
		"detail_data": detail_data
	}


func _resolve_active_level_attempt(level: Dictionary) -> Dictionary:
	var attempts: Array = level.get("level_attempts", [])
	var active_id: String = str(level.get("active_level_attempt_id", "")).strip_edges()
	if not active_id.is_empty():
		for value in attempts:
			if not value is Dictionary:
				continue
			var attempt: Dictionary = value
			if str(attempt.get("level_attempt_id", "")) == active_id:
				return attempt
	for index in range(attempts.size() - 1, -1, -1):
		var value: Variant = attempts[index]
		if not value is Dictionary:
			continue
		var attempt: Dictionary = value
		if str(attempt.get("status", "")) == "in_progress":
			return attempt
	for index in range(attempts.size() - 1, -1, -1):
		var value: Variant = attempts[index]
		if not value is Dictionary:
			continue
		var attempt: Dictionary = value
		if str(attempt.get("status", "")) == "completed":
			return attempt
	return {}

func _resolve_latest_completed_attempt(
	game: Dictionary,
	level_attempt_id: String = ""
) -> Dictionary:
	var attempts: Array = game.get("attempts", [])

	for index in range(attempts.size() - 1, -1, -1):
		var attempt_value: Variant = attempts[index]

		if not attempt_value is Dictionary:
			continue

		var attempt: Dictionary = attempt_value

		if str(attempt.get("status", "")) != "completed":
			continue

		if not level_attempt_id.is_empty():
			if str(attempt.get("level_attempt_id", "")) != level_attempt_id:
				continue

		var summary_value: Variant = attempt.get(
			"game_summary",
			{}
		)

		if summary_value is Dictionary:
			var summary: Dictionary = summary_value

			if not summary.is_empty():
				return attempt

	return {}


func _build_v3_game_detail(
	game_id: String,
	game_no: int,
	game: Dictionary,
	attempt: Dictionary,
	summary: Dictionary
) -> Dictionary:
	var title: String = _resolve_v3_game_title(
		game_id,
		game_no,
		game
	)
	var duration_ms: int = int(
		summary.get("total_duration_ms", 0)
	)
	var events: Array = game.get("interaction_events", [])
	var attempt_id: String = str(
		attempt.get("attempt_id", "")
	)
	var level_attempt_id: String = str(
		attempt.get("level_attempt_id", "")
	).strip_edges()
	var missions: Array[Dictionary] = _build_v3_mission_details(
		events,
		attempt_id,
		game_id
	)
	var attempt_history: Array[Dictionary] = (
		_build_v3_game_attempt_history(
			game,
			level_attempt_id
		)
	)
	var timeout_count: int = 0
	var reset_count: int = 0

	for history_value in attempt_history:
		var history: Dictionary = history_value
		var history_status: String = str(
			history.get("status", "")
		)

		if history_status == "timeout":
			timeout_count += 1
		elif history_status == "reset":
			reset_count += 1

	var penalty_count: int = 0
	var penalty_points_total: int = 0

	for mission_value in missions:
		var mission: Dictionary = mission_value
		var penalty_points: int = int(
			mission.get("penalty_points", 0)
		)

		if penalty_points <= 0:
			continue

		penalty_count += 1
		penalty_points_total += penalty_points

	return {
		"game_no": game_no,
		"game_id": game_id,
		"title": title,
		"score_value": int(summary.get("final_score", 0)),
		"score_text": str(int(summary.get("final_score", 0))),
		"duration_ms": duration_ms,
		"duration_text": _format_level_complete_duration_ms(duration_ms),
		"total_correct": int(summary.get("total_correct", 0)),
		"total_wrong": int(summary.get("total_wrong", 0)),
		"total_invalid": int(summary.get("total_invalid", 0)),
		"total_hint": int(summary.get("total_hint", 0)),
		"total_reset": int(summary.get("total_reset", 0)),
		"total_back_to_map": int(summary.get("total_back_to_map", 0)),
		"penalty_count": penalty_count,
		"penalty_points_total": penalty_points_total,
		"game_attempt_count": attempt_history.size(),
		"timeout_count": timeout_count,
		"reset_count": reset_count,
		"attempt_history": attempt_history,
		"missions": missions
	}

func _build_v3_game_attempt_history(
	game: Dictionary,
	level_attempt_id: String
) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var attempts: Array = game.get("attempts", [])

	for value in attempts:
		if not value is Dictionary:
			continue

		var attempt: Dictionary = value

		if not level_attempt_id.is_empty():
			if str(attempt.get("level_attempt_id", "")) != level_attempt_id:
				continue

		var status: String = str(
			attempt.get("status", "")
		).strip_edges().to_lower()

		if status not in [
			"completed",
			"timeout",
			"reset",
			"interrupted",
			"abandoned"
		]:
			continue

		var score_value: int = int(
			attempt.get("final_score", 0)
		)
		var selected_label: String = ""
		var selected_value: String = ""

		if status == "completed":
			selected_label = "Poin"
			selected_value = str(score_value)
		elif status == "reset":
			selected_label = "Poin sebelum reset"
			selected_value = str(
				int(
					attempt.get(
						"score_before_reset",
						score_value
					)
				)
			)

		var duration_ms: int = maxi(
			0,
			int(attempt.get("duration_ms", 0))
		)

		output.append({
			"attempt_no": int(attempt.get("attempt_no", 0)),
			"attempt_id": str(attempt.get("attempt_id", "")),
			"status": status,
			"result_text": _v3_game_attempt_status_text(status),
			"selected_label": selected_label,
			"selected_value": selected_value,
			"correct_label": "",
			"correct_value": "",
			"duration_ms": duration_ms,
			"duration_text": _format_level_complete_duration_ms(
				duration_ms
			)
		})

	return output

func _v3_game_attempt_status_text(status: String) -> String:
	match status:
		"completed":
			return "Selesai"
		"timeout":
			return "Waktu Habis"
		"reset":
			return "Direset"
		"interrupted":
			return "Terhenti"
		"abandoned":
			return "Ditinggalkan"

	return status.capitalize()

func _build_v3_mission_details(
	events: Array,
	attempt_id: String,
	game_id: String
) -> Array[Dictionary]:
	var missions: Array[Dictionary] = []
	var grouped_events: Dictionary = {}
	var mission_order: Array[String] = []

	for value in events:
		if not value is Dictionary:
			continue

		var event: Dictionary = value

		if str(event.get("attempt_id", "")) != attempt_id:
			continue

		if not _is_v3_mission_result_event(event):
			continue

		var mission_key: String = _resolve_v3_mission_group_key(
			event
		)

		if mission_key.is_empty():
			continue

		if not grouped_events.has(mission_key):
			grouped_events[mission_key] = []
			mission_order.append(mission_key)

		var group_value: Variant = grouped_events.get(
			mission_key,
			[]
		)
		var group_events: Array = []

		if group_value is Array:
			group_events = group_value

		group_events.append(event)
		grouped_events[mission_key] = group_events

	for mission_index in range(mission_order.size()):
		var mission_key: String = mission_order[mission_index]
		var group_value: Variant = grouped_events.get(
			mission_key,
			[]
		)

		if not group_value is Array:
			continue

		var group_events: Array = group_value

		if group_events.is_empty():
			continue

		var final_event: Dictionary = {}
		var last_event: Dictionary = {}
		var wrong_count: int = 0
		var invalid_count: int = 0

		for event_value in group_events:
			if not event_value is Dictionary:
				continue

			var event: Dictionary = event_value
			last_event = event

			var result: String = str(
				event.get("result", "")
			)

			if result in [
				"wrong",
				"wrong_target_drop"
			]:
				wrong_count += 1
			elif result == "invalid_drop":
				invalid_count += 1

			if result in [
				"correct",
				"correct_drop"
			]:
				final_event = event

		if final_event.is_empty():
			final_event = last_event

		if final_event.is_empty():
			continue

		var attempt_count: int = group_events.size()
		var awarded_points: int = _resolve_v3_mission_awarded_points(
			final_event
		)
		var scoring: Dictionary = _resolve_v3_mission_scoring(
			game_id,
			final_event,
			awarded_points
		)
		var duration_ms: int = _resolve_v3_grouped_mission_duration_ms(
			group_events,
			final_event
		)
		var duration_text: String = "-"

		if duration_ms > 0:
			if str(final_event.get("event_type", "")) == "drop":
				duration_text = _format_level_complete_drag_mission_duration_ms(
					duration_ms
				)
			else:
				duration_text = _format_level_complete_duration_ms(
					duration_ms
				)

		var control_counts: Dictionary = _linked_control_counts(
			events,
			attempt_id,
			final_event
		)
		var attempt_details: Array[Dictionary] = (
			_build_v3_attempt_details(group_events)
		)

		missions.append({
			"mission_no": mission_index + 1,
			"mission_key": mission_key,
			"title": _resolve_v3_mission_title(final_event),
			"attempt_count": attempt_count,
			"wrong_count": wrong_count,
			"invalid_count": invalid_count,
			"duration_ms": duration_ms,
			"duration_text": duration_text,
			"status_text": _resolve_v3_result_label(
				str(final_event.get("result", ""))
			),
			"base_points": int(scoring.get("base_points", awarded_points)),
			"base_point_text": str(
				int(scoring.get("base_points", awarded_points))
			),
			"penalty_points": int(scoring.get("penalty_points", 0)),
			"penalty_text": str(
				int(scoring.get("penalty_points", 0))
			),
			"point_value": awarded_points,
			"point_text": str(awarded_points),
			"attempt_details": attempt_details,
			"hint_click_count": int(
				control_counts.get("hint", 0)
			),
			"reset_click_count": int(
				control_counts.get("reset", 0)
			),
			"back_to_map_click_count": int(
				control_counts.get("back_to_map", 0)
			)
		})

	return missions


func _build_v3_attempt_details(
	group_events: Array
) -> Array[Dictionary]:
	var details: Array[Dictionary] = []

	for event_index in range(group_events.size()):
		var event_value: Variant = group_events[event_index]

		if not event_value is Dictionary:
			continue

		var event: Dictionary = event_value
		var event_type: String = str(
			event.get("event_type", "")
		)
		var selected_label: String = ""
		var selected_value: String = "-"
		var correct_label: String = ""
		var correct_value: String = "-"
		var duration_ms: int = _resolve_v3_attempt_duration_ms(
			event
		)

		if event_type == "drop":
			selected_label = "Target Dipilih"
			correct_label = "Target Benar"

			var drop_value: Variant = event.get(
				"drop_result",
				{}
			)

			if drop_value is Dictionary:
				var drop_result: Dictionary = drop_value
				selected_value = str(
					drop_result.get(
						"dropped_target_name_snapshot",
						""
					)
				).strip_edges()

				if selected_value.is_empty():
					selected_value = _clean_v3_target_id(
						str(
							drop_result.get(
								"dropped_target_id",
								""
							)
						)
					)

				correct_value = str(
					drop_result.get(
						"expected_target_name_snapshot",
						""
					)
				).strip_edges()

				if correct_value.is_empty():
					var expected_value: Variant = drop_result.get(
						"expected_target_ids",
						[]
					)

					if expected_value is Array:
						var expected_ids: Array = expected_value

						if not expected_ids.is_empty():
							correct_value = _clean_v3_target_id(
								str(expected_ids[0])
							)

		elif event_type == "question_answer":
			selected_label = "Jawaban Dipilih"
			correct_label = "Jawaban Benar"

			var selected_id: String = str(
				event.get(
					"selected_answer_id",
					""
				)
			).strip_edges()
			var correct_id: String = str(
				event.get(
					"correct_answer_id",
					""
				)
			).strip_edges()

			selected_value = _resolve_v3_answer_text(
				event,
				selected_id
			)
			correct_value = _resolve_v3_answer_text(
				event,
				correct_id
			)

		elif event_type == "mechanic_interaction":
			selected_label = "Pilihan"
			correct_label = "Target Benar"

			var selected_item_id: String = str(
				event.get(
					"selected_item_id",
					""
				)
			).strip_edges()
			var expected_item_id: String = str(
				event.get(
					"expected_item_id",
					""
				)
			).strip_edges()

			selected_value = _resolve_v3_answer_text(
				event,
				selected_item_id
			)
			correct_value = _resolve_v3_answer_text(
				event,
				expected_item_id
			)

		var duration_text: String = "-"

		if duration_ms > 0:
			duration_text = _format_level_complete_attempt_duration_ms(
				duration_ms
			)

		details.append({
			"attempt_no": event_index + 1,
			"result": str(event.get("result", "")),
			"result_text": _resolve_v3_result_label(
				str(event.get("result", ""))
			),
			"selected_label": selected_label,
			"selected_value": selected_value,
			"correct_label": correct_label,
			"correct_value": correct_value,
			"duration_ms": duration_ms,
			"duration_text": duration_text
		})

	return details

func _resolve_v3_attempt_duration_ms(
	event: Dictionary
) -> int:
	var event_type: String = str(
		event.get("event_type", "")
	)

	if event_type in [
		"question_answer",
		"mechanic_interaction"
	]:
		return maxi(
			0,
			int(event.get("response_time_ms", 0))
		)

	if event_type == "drop":
		var timing_value: Variant = event.get(
			"timing",
			{}
		)

		if timing_value is Dictionary:
			var timing: Dictionary = timing_value
			return maxi(
				0,
				int(
					timing.get(
						"decision_duration_ms",
						0
					)
				)
			)

		return maxi(
			0,
			int(event.get("decision_duration_ms", 0))
		)

	return 0

func _format_level_complete_attempt_duration_ms(
	duration_ms: int
) -> String:
	return _format_level_complete_drag_mission_duration_ms(
		duration_ms
	)


func _resolve_v3_answer_text(
	event: Dictionary,
	answer_id: String
) -> String:
	if answer_id.is_empty():
		return "-"

	var options_value: Variant = event.get(
		"displayed_options",
		[]
	)

	if options_value is Array:
		var options: Array = options_value

		for option_value in options:
			if not option_value is Dictionary:
				continue

			var option: Dictionary = option_value

			if str(option.get("answer_id", "")) != answer_id:
				continue

			var snapshot: String = str(
				option.get(
					"text_snapshot",
					""
				)
			).strip_edges()

			if not snapshot.is_empty():
				return snapshot

	return _humanize_v3_identifier(answer_id)


func _clean_v3_target_id(
	target_id: String
) -> String:
	var normalized: String = target_id.strip_edges()

	if normalized.begins_with("L1-TARGET-"):
		normalized = normalized.trim_prefix(
			"L1-TARGET-"
		)

	if normalized.is_empty():
		return "-"

	return _humanize_v3_identifier(normalized)

func _resolve_v3_mission_group_key(
	event: Dictionary
) -> String:
	var event_type: String = str(
		event.get("event_type", "")
	)

	if event_type == "drop":
		var dragged_value: Variant = event.get(
			"dragged_item",
			{}
		)

		if dragged_value is Dictionary:
			var dragged_item: Dictionary = dragged_value
			var food_id: String = str(
				dragged_item.get("food_id", "")
			).strip_edges()

			if not food_id.is_empty():
				return "drop:" + food_id

	if event_type == "question_answer":
		var question_id: String = str(
			event.get("question_id", "")
		).strip_edges()

		if not question_id.is_empty():
			return "question:" + question_id

	if event_type == "mechanic_interaction":
		var mechanic_id: String = str(
			event.get("mechanic_id", "")
		).strip_edges()

		if not mechanic_id.is_empty():
			return "mechanic:" + mechanic_id

	var section_id: String = str(
		event.get("section_id", "")
	).strip_edges()

	if not section_id.is_empty():
		return "section:" + section_id

	var round_id: String = str(
		event.get("round_id", "")
	).strip_edges()

	if not round_id.is_empty():
		return "round:" + round_id

	return (
		event_type
		+ ":"
		+ str(event.get("event_id", ""))
	)

func _resolve_v3_grouped_mission_duration_ms(
	group_events: Array,
	final_event: Dictionary
) -> int:
	if str(final_event.get("event_type", "")) == "drop":
		return _resolve_v3_event_duration_ms(final_event)

	var total_duration_ms: int = 0

	for event_value in group_events:
		if not event_value is Dictionary:
			continue

		var event: Dictionary = event_value
		total_duration_ms += _resolve_v3_event_duration_ms(
			event
		)

	return total_duration_ms


func _resolve_v3_mission_awarded_points(
	event: Dictionary
) -> int:
	var delta_value: Variant = event.get(
		"score_delta",
		null
	)

	if delta_value != null:
		return maxi(0, int(delta_value))

	var before_value: Variant = event.get(
		"score_before_event",
		null
	)
	var after_value: Variant = event.get(
		"score_after_event",
		null
	)

	if before_value != null and after_value != null:
		return maxi(
			0,
			int(after_value) - int(before_value)
		)

	return 0


func _resolve_v3_mission_scoring(
	game_id: String,
	final_event: Dictionary,
	awarded_points: int
) -> Dictionary:
	var base_points: int = awarded_points
	var retry_points: int = awarded_points

	if game_id in [
		"L1-G01",
		"L1-G02",
		"L2-G01",
		"L2-G02"
	]:
		var level_config: Dictionary = {}

		if game_id.begins_with("L1-"):
			level_config = (
				ContentDatabase.get_level_01_config()
			)
		elif game_id.begins_with("L2-"):
			level_config = (
				ContentDatabase.get_level_02_config()
			)

		var scoring_value: Variant = (
			level_config.get(
				"scoring",
				{}
			)
		)

		if scoring_value is Dictionary:
			var scoring: Dictionary = scoring_value

			if game_id == "L1-G01":
				base_points = int(
					scoring.get(
						"food_first_attempt",
						10
					)
				)
				retry_points = int(
					scoring.get(
						"food_after_retry",
						5
					)
				)
			elif game_id == "L1-G02":
				base_points = int(
					scoring.get(
						"literacy_first_attempt",
						30
					)
				)
				retry_points = int(
					scoring.get(
						"literacy_after_retry",
						20
					)
				)
			elif game_id == "L2-G01":
				base_points = int(
					scoring.get(
						"food_first_attempt",
						5
					)
				)
				retry_points = int(
					scoring.get(
						"food_after_retry",
						3
					)
				)
			elif game_id == "L2-G02":
				base_points = int(
					scoring.get(
						"literacy_first_attempt",
						10
					)
				)
				retry_points = int(
					scoring.get(
						"literacy_after_retry",
						7
					)
				)

	var final_result: String = str(
		final_event.get(
			"result",
			""
		)
	)
	var final_correct: bool = final_result in [
		"correct",
		"correct_drop"
	]
	var penalty_points: int = 0

	if final_correct:
		penalty_points = maxi(
			0,
			base_points - awarded_points
		)

	return {
		"base_points": base_points,
		"retry_points": retry_points,
		"awarded_points": awarded_points,
		"penalty_points": penalty_points
	}

func _is_v3_mission_result_event(
	event: Dictionary
) -> bool:
	var event_type: String = str(
		event.get("event_type", "")
	)

	return event_type in [
		"drop",
		"question_answer",
		"mechanic_interaction",
		"mission_result",
		"round_result",
		"section_result"
	]

func _resolve_v3_game_title(
	game_id: String,
	game_no: int,
	game: Dictionary
) -> String:
	var explicit_title: String = str(
		game.get("title", game.get("name", ""))
	).strip_edges()

	if not explicit_title.is_empty():
		return explicit_title

	var game_type: String = str(
		game.get("game_type", "")
	)

	if game_type == "matching_drag_drop":
		return "Cocokkan Pangan"

	if game_type == "classification_drag_drop":
		return "Klasifikasi Pangan"

	if game_type == "literacy_question":
		return "Tantangan Literasi"

	if not game_type.is_empty():
		return game_type.replace("_", " ").capitalize()

	return "Permainan %d - %s" % [game_no, game_id]


func _resolve_v3_mission_title(event: Dictionary) -> String:
	var event_type: String = str(event.get("event_type", ""))
	if event_type == "question_answer":
		var order: int = int(
			event.get(
				"question_order",
				0
			)
		)

		if str(event.get("game_id", "")) == "L2-G02":
			return (
				"Ronde Literasi %d" % order
				if order > 0
				else "Ronde Literasi"
			)

		return (
			"Pertanyaan %d" % order
			if order > 0
			else "Pertanyaan"
		)
	if event_type == "drop":
		var item: Dictionary = event.get("dragged_item", {})
		var snapshot: String = str(item.get("food_name_snapshot", "")).strip_edges()
		if not snapshot.is_empty():
			return snapshot
		for key in ["display_name", "name"]:
			var direct: String = str(item.get(key, "")).strip_edges()
			if not direct.is_empty():
				return direct
		var food_id: String = str(item.get("food_id", "")).strip_edges()
		if not food_id.is_empty():
			var food: Dictionary = ContentDatabase.get_food(food_id)
			var display: String = str(food.get("display_name", "")).strip_edges()
			if not display.is_empty():
				return display
			return _humanize_v3_identifier(food_id)
		return "Pencocokan Pangan"
	var section_id: String = str(event.get("section_id", "")).strip_edges()
	if not section_id.is_empty(): return _humanize_v3_identifier(section_id)
	var round_id: String = str(event.get("round_id", "")).strip_edges()
	if not round_id.is_empty(): return _humanize_v3_identifier(round_id)
	return _humanize_v3_identifier(event_type)

func _humanize_v3_identifier(value: String) -> String:
	var normalized: String = value.strip_edges()
	for prefix in ["food_", "processed_", "group_", "round_", "section_"]:
		if normalized.begins_with(prefix):
			normalized = normalized.trim_prefix(prefix)
			break
	return normalized.replace("_", " ").capitalize()

func _resolve_v3_result_label(result: String) -> String:
	match result:
		"correct", "correct_drop":
			return "Benar"
		"wrong", "wrong_target_drop":
			return "Salah"
		"invalid_drop":
			return "Tidak Valid"
		"timeout":
			return "Waktu Habis"
		"completed":
			return "Selesai"
		_:
			if result.is_empty():
				return "-"
			return result.replace("_", " ").capitalize()


func _format_level_complete_drag_mission_duration_ms(
	duration_ms: int
) -> String:
	var safe_ms: int = maxi(0, duration_ms)
	var total_centiseconds: int = int(
		round(float(safe_ms) / 10.0)
	)
	var centiseconds: int = total_centiseconds % 100
	var total_seconds: int = int(
		float(total_centiseconds) / 100.0
	)
	var seconds: int = total_seconds % 60
	var minutes: int = int(
		float(total_seconds) / 60.0
	)

	return "%02d:%02d.%02d" % [
		minutes,
		seconds,
		centiseconds
	]

func _resolve_v3_event_duration_ms(event: Dictionary) -> int:
	for key in [
		"duration_ms",
		"response_time_ms",
		"active_duration_ms",
		"mission_duration_ms",
		"decision_duration_ms"
	]:
		var value: Variant = event.get(key, null)
		if value != null and int(value) > 0:
			return int(value)

	var timing_value: Variant = event.get("timing", {})
	if timing_value is Dictionary:
		var timing: Dictionary = timing_value
		for key in [
			"duration_ms",
			"drag_duration_ms",
			"mission_duration_ms",
			"decision_duration_ms",
			"active_duration_ms",
			"elapsed_ms",
			"response_time_ms"
		]:
			var value: Variant = timing.get(key, null)
			if value != null and int(value) > 0:
				return int(value)

	return 0

func _linked_control_counts(
	events: Array,
	attempt_id: String,
	mission_event: Dictionary
) -> Dictionary:
	var output: Dictionary = {
		"hint": 0,
		"reset": 0,
		"back_to_map": 0
	}
	var context_tokens: Array[String] = _mission_context_tokens(
		mission_event
	)

	if context_tokens.is_empty():
		return output

	for value in events:
		if not value is Dictionary:
			continue

		var event: Dictionary = value

		if str(event.get("attempt_id", "")) != attempt_id:
			continue

		var event_type: String = str(
			event.get("event_type", "")
		)

		if event_type not in [
			"hint",
			"reset",
			"in_game_reset",
			"back_to_map"
		]:
			continue

		if not _control_event_matches_context(
			event,
			context_tokens
		):
			continue

		if event_type == "hint":
			output["hint"] = int(output.get("hint", 0)) + 1
		elif event_type == "back_to_map":
			output["back_to_map"] = int(output.get("back_to_map", 0)) + 1
		else:
			output["reset"] = int(output.get("reset", 0)) + 1

	return output


func _mission_context_tokens(
	event: Dictionary
) -> Array[String]:
	var output: Array[String] = []

	for key in [
		"question_occurrence_id",
		"question_id",
		"drop_event_id",
		"round_id",
		"section_id"
	]:
		var token: String = str(event.get(key, "")).strip_edges()

		if not token.is_empty() and not output.has(token):
			output.append(token)

	var dragged_item: Dictionary = event.get("dragged_item", {})
	var food_id: String = str(
		dragged_item.get("food_id", "")
	).strip_edges()

	if not food_id.is_empty() and not output.has(food_id):
		output.append(food_id)

	return output


func _control_event_matches_context(
	event: Dictionary,
	context_tokens: Array[String]
) -> bool:
	for key in [
		"context_id",
		"question_occurrence_id",
		"question_id",
		"round_id",
		"section_id"
	]:
		var token: String = str(event.get(key, "")).strip_edges()

		if not token.is_empty() and context_tokens.has(token):
			return true

	return false


func _format_v3_game_result_line(
	game_detail: Dictionary
) -> String:
	return (
		"Permainan ke-%d - %s\n"
		% [
			int(game_detail.get("game_no", 0)),
			str(game_detail.get("title", ""))
		]
		+ "Skor: %s\n"
		% str(game_detail.get("score_text", ""))
		+ "Benar: %d | Salah: %d"
		% [
			int(game_detail.get("total_correct", 0)),
			int(game_detail.get("total_wrong", 0))
		]
	)


func _resolve_level_star_value(
	score: int
) -> float:
	if score >= 100:
		return 3.0
	if score >= 90:
		return 2.5
	if score >= 75:
		return 2.0
	if score >= 50:
		return 1.5
	if score >= 35:
		return 1.0
	if score >= 5:
		return 0.5
	return 0.0


func _build_star_slots(
	star_value: float
) -> Array[String]:
	var slots: Array[String] = []
	var remainder: float = star_value

	for _index in range(3):
		if remainder >= 1.0:
			slots.append("full")
			remainder -= 1.0
		elif remainder >= 0.5:
			slots.append("half")
			remainder -= 0.5
		else:
			slots.append("empty")

	return slots

func _resolve_level_completion_bonus() -> int:
	for property_value in get_property_list():
		if not property_value is Dictionary:
			continue

		var property_data: Dictionary = property_value

		if str(property_data.get("name", "")) != "level_config":
			continue

		var config_value: Variant = get("level_config")

		if not config_value is Dictionary:
			return 0

		var config: Dictionary = config_value
		var scoring_value: Variant = config.get("scoring", {})

		if not scoring_value is Dictionary:
			return 0

		var scoring: Dictionary = scoring_value
		return int(scoring.get("completion", 0))

	return 0


func _format_level_complete_duration_ms(
	duration_ms: int
) -> String:
	var safe_ms: int = maxi(0, duration_ms)
	var total_centiseconds: int = int(
		round(float(safe_ms) / 10.0)
	)
	var centiseconds: int = total_centiseconds % 100
	var total_seconds: int = int(
		float(total_centiseconds) / 100.0
	)
	var seconds: int = total_seconds % 60
	var minutes: int = int(
		float(total_seconds) / 60.0
	)

	return "%02d:%02d.%02d" % [
		minutes,
		seconds,
		centiseconds
	]

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
		"InfoProcessedImage",
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
