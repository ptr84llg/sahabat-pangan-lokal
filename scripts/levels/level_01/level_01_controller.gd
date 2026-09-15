extends LevelFlowController

const FOOD_CARD_SCENE := preload("res://scenes/levels/level_01/level_01_food_card.tscn")
const DROP_SLOT_SCENE := preload("res://scenes/levels/level_01/level_01_drop_slot.tscn")

const V3_MAIN_GAME_ID: String = "L1-G01"
const V3_MAIN_GAME_TYPE: String = "matching_drag_drop"
const V3_MAIN_INSTRUCTION_ID: String = "INST-L1-G01-MATCH"
const V3_MAIN_INSTRUCTION_TEXT: String = "Misi: Cocokkan gambar pangan dengan namanya."

const V3_LITERACY_GAME_ID: String = "L1-G02"
const V3_LITERACY_GAME_TYPE: String = "literacy_question"
const V3_LITERACY_INSTRUCTION_ID: String = "INST-L1-G02-LITERACY"
const V3_LITERACY_INSTRUCTION_TEXT: String = "Jawab lima pertanyaan tentang pangan yang baru dipelajari."

@onready var theme_panel: Control = %ThemePanel
@onready var dialogue_panel: Control = %DialoguePanel
@onready var tutorial_panel: Control = %TutorialPanel
@onready var gameplay_layer: Control = %GameplayLayer
@onready var gameplay_success_panel: Control = %GameplaySuccessPanel
@onready var literacy_panel: Control = %LiteracyPanel
@onready var result_panel: Control = %ResultPanel
@onready var info_panel: Control = %InfoPanel
@onready var badge_panel: Control = %BadgePanel
@onready var closing_panel: Control = %ClosingPanel
@onready var feedback_toast: Label = %FeedbackToast
@onready var progress_label: Label = %ProgressLabel
@onready var score_label: Label = %GameplayScoreLabel
@onready var matching_board: GridContainer = %MatchingBoard
@onready var food_tray: GridContainer = %FoodTray
@onready var info_glyph: FoodGlyph = %InfoGlyph
@onready var info_image: TextureRect = %InfoImage
@onready var matching_controller: MatchingController = %MatchingController

var screens: Array[Control] = []
var level_config: Dictionary = {}
var foods: Array[Dictionary] = []
var level_session: Dictionary = {}
var literacy_attempts: int = 0
var literacy_question_attempts: int = 0
var literacy_question_index: int = 0
var literacy_questions: Array = []
var literacy_current_answers: Array = []
var literacy_score: int = 0
var main_score: int = 0
var final_score: int = 0
var info_index: int = 0
var dialogue_lines: Array = []
var dialogue_index: int = 0
var closing_lines: Array = []
var closing_index: int = 0
var literacy_game_start_active_ms: int = -1
var level_attempt_base_duration_ms: int = 0
var reset_count: int = 0
var back_to_map_count: int = 0
var main_game_start_active_ms: int = -1

func _ready() -> void:
	set_meta("level_no", 1)
	_prepare_level_presentation()
	level_config = ContentDatabase.get_level_01_config()
	foods = ContentDatabase.get_level_01_foods()
	screens = [
		theme_panel,
		dialogue_panel,
		tutorial_panel,
		gameplay_layer,
		gameplay_success_panel,
		literacy_panel,
		result_panel,
		info_panel,
		badge_panel,
		closing_panel
	]

	_connect_ui()
	_setup_matching()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_show_theme()

func _connect_ui() -> void:
	%ThemeStartButton.pressed.connect(_show_opening_dialogue)
	%DialogueNextButton.pressed.connect(_on_dialogue_next)
	%TutorialContinueButton.pressed.connect(_on_tutorial_continue)
	%TutorialSkipButton.pressed.connect(_start_gameplay)
	%GameplaySuccessNextButton.pressed.connect(_show_literacy_dialogue)
	%LiteracyStartButton.pressed.connect(_start_literacy_challenge)

	for button_variant in [%AnswerA, %AnswerB, %AnswerC]:
		var button: Button = button_variant
		button.pressed.connect(_on_literacy_button_pressed.bind(button))

	%LiteracyRetryButton.pressed.connect(_retry_literacy_question)
	%LiteracyResultButton.pressed.connect(_on_literacy_continue_pressed)
	%ResultNextButton.pressed.connect(_show_info)
	%InfoNextButton.pressed.connect(_advance_info)
	%BadgeNextButton.pressed.connect(_show_closing)
	%ClosingMapButton.pressed.connect(_on_closing_next)

	matching_controller.progress_changed.connect(_on_progress_changed)
	matching_controller.feedback.connect(_show_feedback)
	matching_controller.all_matched.connect(_on_all_matched)

	_bind_motion_controls()

func _bind_motion_controls() -> void:
	var motion_buttons: Array = [
		%ThemeStartButton,
		%DialogueNextButton,
		%TutorialContinueButton,
		%TutorialSkipButton,
		%GameplaySuccessNextButton,
		%LiteracyStartButton,
		%AnswerA,
		%AnswerB,
		%AnswerC,
		%LiteracyRetryButton,
		%LiteracyResultButton,
		%ResultNextButton,
		%InfoNextButton,
		%BadgeNextButton,
		%ClosingMapButton
	]

	for button_value in motion_buttons:
		var button := button_value as BaseButton

		if button != null:
			ScreenMotionPresenter.bind_button(button)

func _apply_responsive_layout() -> void:
	var viewport_width: float = size.x
	var viewport_height: float = size.y

	matching_board.columns = 3

	if viewport_width < 1120.0 or viewport_height >= 760.0:
		food_tray.columns = 3
	else:
		food_tray.columns = 6

func _setup_matching() -> void:
	_rebuild_matching_board()


func _rebuild_matching_board() -> void:
	for child_variant in matching_board.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		matching_board.remove_child(child_node)
		child_node.queue_free()

	for child_variant in food_tray.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		food_tray.remove_child(child_node)
		child_node.queue_free()

	matching_controller.configure(level_config, foods)

	var shuffled_foods: Array[Dictionary] = foods.duplicate(true)
	shuffled_foods.shuffle()

	for food in foods:
		var slot: FoodDropSlot = DROP_SLOT_SCENE.instantiate()
		var food_id: String = str(food.get("food_id", ""))

		matching_board.add_child(slot)
		slot.setup(food_id, str(food.get("display_name", "")))
		matching_controller.register_slot(food_id, slot)

	for food in shuffled_foods:
		var card: FoodCard = FOOD_CARD_SCENE.instantiate()
		var food_id: String = str(food.get("food_id", ""))

		food_tray.add_child(card)
		card.setup(food_id)
		matching_controller.register_card(food_id, card)

	_apply_responsive_layout()

func _show_theme() -> void:
	set_state("THEME_INTRO")
	show_only(screens, theme_panel)

func _show_opening_dialogue() -> void:
	set_state("DIALOGUE_OPENING")
	dialogue_lines = level_config.get("dialogue", {}).get("opening", [])
	dialogue_index = 0
	show_only(screens, dialogue_panel)
	_render_dialogue_line()


func _on_dialogue_next() -> void:
	dialogue_index += 1

	if dialogue_index < dialogue_lines.size():
		_render_dialogue_line()
		return

	if current_state == "DIALOGUE_OPENING":
		set_state("DIALOGUE_MISSION")
		dialogue_lines = level_config.get("dialogue", {}).get("mission", [])
		dialogue_index = 0
		_render_dialogue_line()
		return

	if current_state == "DIALOGUE_MISSION":
		_show_tutorial()
		return

	if current_state == "DIALOGUE_LITERACY":
		_show_literacy_intro()
		return

	_show_tutorial()

func _render_dialogue_line() -> void:
	if dialogue_lines.is_empty():
		return

	if dialogue_index < 0 or dialogue_index >= dialogue_lines.size():
		return

	var line: Dictionary = dialogue_lines[dialogue_index]
	%SpeakerLabel.text = str(line.get("speaker", ""))
	%DialogueText.text = str(line.get("text", ""))
	_set_dialogue_speaker(%SpeakerLabel.text)

	var is_last: bool = dialogue_index == dialogue_lines.size() - 1
	%DialogueNextButton.text = (
		"SIAP"
		if current_state == "DIALOGUE_MISSION" and is_last
		else "LANJUT"
	)

func _show_tutorial() -> void:
	set_state("TUTORIAL_INTERACTIVE")
	show_only(screens, tutorial_panel)

	%TutorialStepLabel.text = "LATIHAN LANGSUNG"
	%TutorialText.text = "Klik dan tahan gambar pangan di sebelah kiri."
	%TutorialContinueButton.text = "MULAI BERMAIN"
	%TutorialSkipButton.visible = bool(
		SettingsManager.get_flag("tutorial_level_01_seen", false)
	)

func _on_tutorial_continue() -> void:
	SettingsManager.set_flag("tutorial_level_01_seen", true)
	_start_gameplay()

func _start_gameplay() -> void:
	_prepare_or_resume_level_session()

	DurationTracker.begin_level_session(
		str(level_session.get("level_session_id", "")),
		1
	)
	DurationTracker.resume_active_play()
	main_game_start_active_ms = DurationTracker.current_active_ms()

	set_state("GAMEPLAY")
	show_only(screens, gameplay_layer)
	_apply_responsive_layout()
	matching_controller.begin_mission_timing()

	if not TelemetryManager.begin_game(
		1,
		V3_MAIN_GAME_ID,
		V3_MAIN_GAME_TYPE,
		{
			"instruction_id": V3_MAIN_INSTRUCTION_ID,
			"instruction_version": 1,
			"instruction_text": V3_MAIN_INSTRUCTION_TEXT,
			"content_version": ContentDatabase.content_version
		}
	):
		push_warning(
			"Telemetry v3 Level 1 Game 1 belum dapat memulai game."
		)

	progress_label.text = "Pangan 0/6"
	score_label.text = "Skor Main Game: 0/60"

	TelemetryManager.log_event(
		"level_main_started",
		{
			"level_session_id": level_session.get("level_session_id", ""),
			"level_no": 1,
			"content_version": ContentDatabase.content_version,
			"reset_count": reset_count,
			"back_to_map_count": back_to_map_count
		}
	)


func _prepare_or_resume_level_session() -> void:
	if not level_session.is_empty():
		return

	var sessions: Array = GameState.active_run.get(
		"level_sessions",
		[]
	)

	for index in range(
		sessions.size() - 1,
		-1,
		-1
	):
		var session_value: Dictionary = sessions[index]

		if int(session_value.get("level_no", 0)) != 1:
			continue

		if int(session_value.get("completed_at", 0)) != 0:
			continue

		level_session = session_value.duplicate(true)
		break

	if level_session.is_empty():
		level_session = GameState.begin_level_session(1)

	level_attempt_base_duration_ms = int(
		level_session.get(
			"active_duration_ms",
			0
		)
	)
	reset_count = int(
		level_session.get(
			"reset_count",
			0
		)
	)
	back_to_map_count = int(
		level_session.get(
			"back_to_map_count",
			0
		)
	)

	level_session["reset_count"] = reset_count
	level_session["retry_count"] = reset_count
	level_session["back_to_map_count"] = back_to_map_count
	GameState.update_level_session(level_session)
	SaveManager.request_save()


func _persist_level_interaction_snapshot(
	interaction_name: String
) -> void:
	if level_session.is_empty():
		return

	var cumulative_duration_ms: int = (
		level_attempt_base_duration_ms
		+ DurationTracker.current_active_ms()
	)

	level_session["active_duration_ms"] = cumulative_duration_ms
	level_session["reset_count"] = reset_count
	level_session["retry_count"] = reset_count
	level_session["back_to_map_count"] = back_to_map_count
	level_session["last_interaction"] = interaction_name
	level_session["last_interaction_at"] = (
		Time.get_unix_time_from_system()
	)

	GameState.update_level_session(level_session)
	SaveManager.request_save()


func _on_reset_pressed() -> void:
	if not gameplay_layer.visible:
		return

	var reset_game_duration_ms: int = 0

	if main_game_start_active_ms >= 0:
		reset_game_duration_ms = maxi(
			0,
			DurationTracker.current_active_ms()
			- main_game_start_active_ms
		)

	reset_count += 1

	if not TelemetryManager.reset_game(
		1,
		V3_MAIN_GAME_ID,
		V3_MAIN_GAME_TYPE,
		main_score,
		reset_game_duration_ms
	):
		push_warning(
			"Telemetry v3 Level 1 Game 1 belum dapat mencatat reset secara canonical."
		)

	_persist_level_interaction_snapshot("reset")

	TelemetryManager.log_event(
		"level_game_reset",
		{
			"level_session_id": level_session.get(
				"level_session_id",
				""
			),
			"level_no": 1,
			"reset_count": reset_count,
			"active_duration_ms": (
				level_attempt_base_duration_ms
				+ DurationTracker.current_active_ms()
			)
		}
	)

	main_score = 0
	feedback_toast.visible = false
	_rebuild_matching_board()

	progress_label.text = "Pangan 0/6"
	score_label.text = "Skor Main Game: 0/60"
	main_game_start_active_ms = DurationTracker.current_active_ms()

	if not TelemetryManager.begin_game(
		1,
		V3_MAIN_GAME_ID,
		V3_MAIN_GAME_TYPE,
		{
			"instruction_id": V3_MAIN_INSTRUCTION_ID,
			"instruction_version": 1,
			"instruction_text": V3_MAIN_INSTRUCTION_TEXT,
			"content_version": ContentDatabase.content_version
		}
	):
		push_warning(
			"Telemetry v3 Level 1 Game 1 belum dapat memulai attempt baru setelah reset."
		)

	matching_controller.begin_mission_timing()
	set_state("GAMEPLAY")
	show_only(screens, gameplay_layer)

func _on_progress_changed(matched: int, total: int, score: int) -> void:
	main_score = score
	progress_label.text = "Pangan %d/%d" % [matched, total]
	score_label.text = "Skor Main Game: %d/60" % main_score

func _show_feedback(text: String, correct: bool) -> void:
	feedback_toast.text = ""
	feedback_toast.visible = false
	AudioManager.play_drop_feedback(correct)
	_present_gameplay_feedback(text, correct, 1.05)
func _on_all_matched(score: int) -> void:
	main_score = score
	var main_game_duration_ms: int = 0

	if main_game_start_active_ms >= 0:
		main_game_duration_ms = maxi(
			0,
			DurationTracker.current_active_ms()
			- main_game_start_active_ms
		)

	DurationTracker.pause_active_play()

	if not TelemetryManager.complete_game(
		1,
		V3_MAIN_GAME_ID,
		V3_MAIN_GAME_TYPE,
		main_score,
		main_game_duration_ms
	):
		push_warning(
			"Telemetry v3 Level 1 Game 1 belum dapat menyelesaikan game."
		)

	set_state("GAMEPLAY_SUCCESS")
	show_only(screens, gameplay_success_panel)
	%GameplaySuccessText.text = "Hebat! Semua pangan berhasil kamu kenali."
	ScreenMotionPresenter.gameplay_reward(gameplay_success_panel)

func _show_literacy_dialogue() -> void:
	set_state("DIALOGUE_LITERACY")
	dialogue_lines = level_config.get(
		"dialogue",
		{}
	).get(
		"before_literacy",
		[]
	)
	dialogue_index = 0
	show_only(screens, dialogue_panel)
	_render_dialogue_line()

func _show_literacy_intro() -> void:
	set_state("LITERACY_INTRO")
	show_only(screens, literacy_panel)
	%LiteracyIntro.visible = true
	%LiteracyQuestion.visible = false
	%LiteracyFeedback.visible = false

func _literacy_question_bank() -> Array:
	var literacy: Dictionary = level_config.get("literacy", {})
	var questions_value: Variant = literacy.get("questions", [])

	if questions_value is Array:
		var questions: Array = questions_value
		return questions

	return []


func _start_literacy_challenge() -> void:
	literacy_questions = _literacy_question_bank().duplicate(true)
	literacy_questions.shuffle()

	if literacy_questions.is_empty():
		push_error("Level 1 literacy question bank kosong.")
		return

	literacy_question_index = 0
	literacy_question_attempts = 0
	literacy_current_answers.clear()
	literacy_attempts = 0
	literacy_score = 0
	literacy_game_start_active_ms = DurationTracker.current_active_ms()

	if not TelemetryManager.begin_game(
		1,
		V3_LITERACY_GAME_ID,
		V3_LITERACY_GAME_TYPE,
		{
			"instruction_id": V3_LITERACY_INSTRUCTION_ID,
			"instruction_version": 1,
			"instruction_text": V3_LITERACY_INSTRUCTION_TEXT,
			"content_version": ContentDatabase.content_version
		}
	):
		push_warning(
			"Telemetry v3 Level 1 Game 2 belum dapat memulai game."
		)

	_show_current_literacy_question()


func _current_literacy_question() -> Dictionary:
	if literacy_question_index < 0 or literacy_question_index >= literacy_questions.size():
		return {}

	var question_value: Variant = literacy_questions[literacy_question_index]

	if question_value is Dictionary:
		return question_value

	return {}


func _show_current_literacy_question(reshuffle_answers: bool = true) -> void:
	var question: Dictionary = _current_literacy_question()

	if question.is_empty():
		push_error("Level 1 literacy question tidak valid pada index %d." % literacy_question_index)
		return

	set_state("LITERACY_QUESTION")
	show_only(screens, literacy_panel)
	%LiteracyIntro.visible = false
	%LiteracyQuestion.visible = true
	%LiteracyFeedback.visible = false
	%LiteracyRetryButton.visible = false
	%LiteracyResultButton.visible = false

	var question_id: String = str(
		question.get("question_id", "")
	).strip_edges()
	var question_text_value: String = str(
		question.get("question_text", "")
	).strip_edges()
	var presentation_mode: String = str(
		question.get("presentation_mode", "TEXT_ONLY")
	).strip_edges().to_upper()
	var media_path: String = str(
		question.get("media_path", "")
	).strip_edges()

	%QuestionText.text = question_text_value
	%QuestionText.set_meta("question_id", question_id)
	%QuestionText.set_meta("presentation_mode", presentation_mode)
	%QuestionText.set_meta("media_path", media_path)
	%QuestionText.set_meta(
		"progress_text",
		"PERTANYAAN %d / %d" % [
			literacy_question_index + 1,
			literacy_questions.size()
		]
	)
	%QuestionText.set_meta(
		"score_text",
		"POIN %d / 30" % literacy_score
	)

	var answers: Array = []

	if reshuffle_answers or literacy_current_answers.is_empty():
		var answers_value: Variant = question.get("answers", [])
		literacy_current_answers.clear()

		if answers_value is Array:
			var source_answers: Array = answers_value
			literacy_current_answers = source_answers.duplicate(true)
			literacy_current_answers.shuffle()

	answers = literacy_current_answers

	var buttons: Array = [%AnswerA, %AnswerB, %AnswerC]
	var displayed_options: Array = []

	for index in range(buttons.size()):
		var button: Button = buttons[index]
		button.visible = index < answers.size()
		button.disabled = index >= answers.size()
		button.set_meta("answer_id", "")
		button.set_meta("image_path", "")

		if index >= answers.size():
			continue

		var answer_value: Variant = answers[index]

		if not answer_value is Dictionary:
			continue

		var answer: Dictionary = answer_value
		var answer_id: String = str(
			answer.get("answer_id", "")
		).strip_edges()
		var answer_text: String = str(
			answer.get("text", "")
		).strip_edges()
		var image_path: String = str(
			answer.get("image_path", "")
		).strip_edges()

		button.text = answer_text
		button.set_meta("answer_id", answer_id)
		button.set_meta("image_path", image_path)

		displayed_options.append(
			{
				"answer_id": answer_id,
				"text_snapshot": answer_text,
				"display_order": index + 1
			}
		)

	DurationTracker.resume_active_play()

	var occurrence_id: String = (
		TelemetryManager.begin_question_occurrence(
			1,
			V3_LITERACY_GAME_ID,
			V3_LITERACY_GAME_TYPE,
			question_id,
			literacy_question_index + 1,
			1,
			displayed_options
		)
	)

	if occurrence_id.is_empty():
		push_warning(
			"Telemetry v3 Level 1 Game 2 belum dapat membuka question occurrence."
		)


func _retry_literacy_question() -> void:
	_show_current_literacy_question(false)


func _on_literacy_button_pressed(button: Button) -> void:
	_on_literacy_answer(str(button.get_meta("answer_id", "")))


func _on_literacy_answer(answer_id: String) -> void:
	DurationTracker.pause_active_play()
	literacy_attempts += 1
	literacy_question_attempts += 1

	var question: Dictionary = _current_literacy_question()

	if question.is_empty():
		push_error("Level 1 literacy answer diterima tanpa question aktif.")
		return

	var question_id: String = str(
		question.get("question_id", "")
	).strip_edges()
	var correct_id: String = str(
		question.get("correct_answer_id", "")
	).strip_edges()
	var correct: bool = answer_id == correct_id

	if correct:
		var scoring: Dictionary = level_config.get("scoring", {})
		var awarded_points: int = (
			int(scoring.get("literacy_first_attempt", 6))
			if literacy_question_attempts == 1
			else int(scoring.get("literacy_after_retry", 4))
		)
		literacy_score += awarded_points
		%QuestionText.set_meta(
			"score_text",
			"POIN %d / 30" % literacy_score
		)

	TelemetryManager.log_event(
		"quiz_answer",
		{
			"level_no": 1,
			"question_id": question_id,
			"question_order": literacy_question_index + 1,
			"selected_answer_id": answer_id,
			"status": "CORRECT" if correct else "WRONG",
			"attempt_no": literacy_question_attempts,
			"challenge_score": literacy_score
		}
	)

	if not TelemetryManager.record_question_answer(
		1,
		V3_LITERACY_GAME_ID,
		V3_LITERACY_GAME_TYPE,
		answer_id,
		correct_id,
		literacy_score,
		false
	):
		push_warning(
			"Telemetry v3 Level 1 Game 2 belum dapat merekam jawaban."
		)

	%LiteracyQuestion.visible = false
	%LiteracyFeedback.visible = true

	if correct:
		%LiteracyFeedbackText.text = str(
			question.get("feedback_correct", "Tepat!")
		)
		%LiteracyRetryButton.visible = false
		%LiteracyResultButton.visible = true
		ScreenMotionPresenter.gameplay_reward(%LiteracyFeedback)

		var last_question: bool = (
			literacy_question_index >= literacy_questions.size() - 1
		)

		if last_question:
			%LiteracyResultButton.text = "LIHAT HASIL"
			var literacy_duration_ms: int = 0

			if literacy_game_start_active_ms >= 0:
				literacy_duration_ms = maxi(
					0,
					DurationTracker.current_active_ms()
					- literacy_game_start_active_ms
				)

			if not TelemetryManager.complete_game(
				1,
				V3_LITERACY_GAME_ID,
				V3_LITERACY_GAME_TYPE,
				literacy_score,
				literacy_duration_ms
			):
				push_warning(
					"Telemetry v3 Level 1 Game 2 belum dapat menyelesaikan game."
				)

			TelemetryManager.log_event(
				"literacy_complete",
				{
					"level_no": 1,
					"question_count": literacy_questions.size(),
					"answer_attempt_count": literacy_attempts,
					"challenge_score": literacy_score
				}
			)
		else:
			%LiteracyResultButton.text = "SOAL BERIKUTNYA"

		return

	%LiteracyFeedbackText.text = str(
		question.get("feedback_retry", "Belum tepat.")
	)
	ScreenMotionPresenter.gameplay_wrong(%LiteracyFeedback, 5.0)
	%LiteracyRetryButton.visible = true
	%LiteracyResultButton.visible = false


func _on_literacy_continue_pressed() -> void:
	if literacy_question_index >= literacy_questions.size() - 1:
		_show_result()
		return

	literacy_question_index += 1
	literacy_question_attempts = 0
	_show_current_literacy_question()

func _show_result() -> void:
	set_state("RESULT")

	var duration_ms: int = DurationTracker.finish_level_session()
	final_score = (
		main_score
		+ literacy_score
		+ int(
			level_config.get("scoring", {}).get(
				"completion",
				10
			)
		)
	)

	level_session["active_duration_ms"] = duration_ms
	level_session["completed_at"] = Time.get_unix_time_from_system()
	GameState.update_level_session(level_session)

	show_only(screens, result_panel)
	ScreenMotionPresenter.gameplay_pop(result_panel, 1.03)
	%ResultScore.text = "%d / 100" % final_score
	%ResultSummary.text = (
		"Pangan dikenali: 6/6\n"
		+ "Tantangan: Selesai\n"
		+ "Durasi aktif: %s" % _format_ms(duration_ms)
	)

func _show_info() -> void:
	set_state("FOOD_INFORMATION")
	info_index = 0
	show_only(screens, info_panel)
	_render_info()

func _render_info() -> void:
	var food: Dictionary = foods[info_index]
	var food_id: String = str(food.get("food_id", ""))

	info_glyph.food_id = food_id
	info_glyph.visible = false

	var texture_path: String = str(VisualAssets.food_texture_paths().get(food_id, ""))

	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var loaded_resource: Resource = load(texture_path)

		if loaded_resource is Texture2D:
			info_image.texture = loaded_resource

	%InfoTitle.text = str(food.get("display_name", ""))
	%InfoType.text = "Jenis sederhana: %s" % str(
		food.get("simple_type", "")
	)
	%InfoText.text = str(food.get("short_info", ""))
	%InfoCounter.text = "%d / %d" % [
		info_index + 1,
		foods.size()
	]
	%InfoNextButton.text = (
		"LANJUT"
		if info_index < foods.size() - 1
		else "SELESAI"
	)

func _advance_info() -> void:
	if info_index < foods.size() - 1:
		info_index += 1
		_render_info()
		return

	_show_badge()

func _show_badge() -> void:
	set_state("BADGE_REWARD")
	show_only(screens, badge_panel)
	ScreenMotionPresenter.gameplay_reward(badge_panel)

	var badge: Dictionary = level_config.get("badge", {})
	%BadgeName.text = str(
		badge.get("display_name", "Penjelajah Pangan Lokal")
	)
	%BadgeDescription.text = str(
		badge.get("description", "")
	)

func _show_closing() -> void:
	set_state("CLOSING_DIALOGUE")
	show_only(screens, closing_panel)
	closing_lines = level_config.get("dialogue", {}).get("closing", [])
	closing_index = 0
	_render_closing_line()


func _render_closing_line() -> void:
	if closing_lines.is_empty():
		%ClosingText.text = ""
		%ClosingMapButton.text = "KEMBALI KE PETA"
		_set_dialogue_speaker("Ibu")
		return

	if closing_index < 0 or closing_index >= closing_lines.size():
		return

	var line: Dictionary = closing_lines[closing_index]
	var speaker_name: String = str(line.get("speaker", "Ibu"))
	%ClosingText.text = str(line.get("text", ""))
	_set_dialogue_speaker(speaker_name)

	var is_last: bool = closing_index == closing_lines.size() - 1
	%ClosingMapButton.text = "KEMBALI KE PETA" if is_last else "LANJUTKAN"


func _on_closing_next() -> void:
	if closing_lines.is_empty():
		_finish_level()
		return

	closing_index += 1

	if closing_index < closing_lines.size():
		_render_closing_line()
		return

	_finish_level()

func _finish_level() -> void:
	set_state("LEVEL_COMPLETE")

	var duration_ms: int = int(
		level_session.get(
			"active_duration_ms",
			DurationTracker.current_active_ms()
		)
	)
	var badge: Dictionary = level_config.get("badge", {})

	GameState.complete_level(
		1,
		final_score,
		duration_ms,
		str(badge.get("badge_id", "badge_level_01")),
		str(
			badge.get(
				"display_name",
				"Penjelajah Pangan Lokal"
			)
		),
		str(level_session.get("level_session_id", ""))
	)

	SceneRouter.goto("main_map")

func _player_speaker_name() -> String:
	if (
		is_instance_valid(GameState)
		and GameState.has_method("player_display_name")
	):
		var display_name_value: Variant = GameState.call(
			"player_display_name"
		)
		var display_name: String = str(display_name_value).strip_edges()

		if not display_name.is_empty():
			return display_name

	return "Pemain"

func _format_ms(value_ms: int) -> String:
	var safe_ms: int = maxi(0, value_ms)
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
