extends LevelFlowController

const FOOD_CARD_SCENE := preload("res://scenes/levels/level_01/level_01_food_card.tscn")
const DROP_SLOT_SCENE := preload("res://scenes/levels/level_01/level_01_drop_slot.tscn")

const V3_MAIN_GAME_ID: String = "L1-G01"
const V3_MAIN_GAME_TYPE: String = "matching_drag_drop"
const V3_MAIN_INSTRUCTION_ID: String = "INST-L1-G01-MATCH"
const V3_MAIN_INSTRUCTION_TEXT: String = "Misi: Cocokkan gambar pangan dengan namanya."

const PLAYER_STANDING_TEXTURES := {
	"rara": "res://assets/visual/character_select/character_01_female_standing.png",
	"budi": "res://assets/visual/character_select/character_02_male_standing.png",
	"anjani": "res://assets/visual/character_select/character_03_female_standing.png",
	"riski": "res://assets/visual/character_select/character_04_male_standing.png"
}

const PLAYER_HAPPY_TEXTURES := {
	"rara": "res://assets/visual/character_select/character_01_female_happy.png",
	"budi": "res://assets/visual/character_select/character_02_male_happy.png",
	"anjani": "res://assets/visual/character_select/character_03_female_happy.png",
	"riski": "res://assets/visual/character_select/character_04_male_happy.png"
}

const NPC_MOTHER_TEXTURES := {
	"standing": "res://assets/visual/npc/ibu/standing.png",
	"talking": "res://assets/visual/npc/ibu/talking.png",
	"happy": "res://assets/visual/npc/ibu/standing.png"
}

const FOOD_TEXTURES := {
	"food_rice": "res://assets/visual/foods/food_rice.png",
	"food_cassava": "res://assets/visual/foods/food_cassava.png",
	"food_water_spinach": "res://assets/visual/foods/food_water_spinach.png",
	"food_spinach": "res://assets/visual/foods/food_spinach.png",
	"food_banana": "res://assets/visual/foods/food_banana.png",
	"food_papaya": "res://assets/visual/foods/food_papaya.png"
}

@onready var character_layer: Control = %CharacterLayer
@onready var mother_card: PanelContainer = %MotherNPC
@onready var mother_visual: TextureRect = %MotherVisual
@onready var player_card: PanelContainer = %PlayerCard
@onready var player_visual: TextureRect = %PlayerVisual
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
var literacy_score: int = 0
var main_score: int = 0
var final_score: int = 0
var info_index: int = 0
var dialogue_step: int = 0
var tutorial_step: int = 0

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
	_apply_selected_player()
	_apply_mother_pose("standing")
	_setup_matching()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_show_theme()

func _connect_ui() -> void:
	%ThemeStartButton.pressed.connect(_show_opening_dialogue)
	%DialogueNextButton.pressed.connect(_on_dialogue_next)
	%TutorialContinueButton.pressed.connect(_on_tutorial_continue)
	%TutorialSkipButton.pressed.connect(_start_gameplay)
	%HintButton.pressed.connect(matching_controller.request_hint)
	%GameplaySuccessNextButton.pressed.connect(_show_literacy_intro)
	%LiteracyStartButton.pressed.connect(_start_literacy_question)

	for button_variant in [%AnswerA, %AnswerB, %AnswerC]:
		var button: Button = button_variant
		button.pressed.connect(_on_literacy_button_pressed.bind(button))

	%LiteracyRetryButton.pressed.connect(_start_literacy_question)
	%LiteracyResultButton.pressed.connect(_show_result)
	%ResultNextButton.pressed.connect(_show_info)
	%InfoNextButton.pressed.connect(_advance_info)
	%BadgeNextButton.pressed.connect(_show_closing)
	%ClosingMapButton.pressed.connect(_finish_level)

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
		%HintButton,
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
			UIMotion.bind_button(button)

func _apply_selected_player() -> void:
	_apply_player_pose(false)

func _apply_player_pose(happy: bool) -> void:
	var character_id: String = GameState.selected_character_id()
	var texture_path: String = ""

	if happy:
		texture_path = str(PLAYER_HAPPY_TEXTURES.get(character_id, ""))
	else:
		texture_path = str(PLAYER_STANDING_TEXTURES.get(character_id, ""))

	if texture_path.is_empty():
		texture_path = GameState.selected_character_texture_path()

	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		return

	var loaded_resource: Resource = load(texture_path)

	if loaded_resource is Texture2D:
		player_visual.texture = loaded_resource

func _apply_mother_pose(pose: String) -> void:
	var texture_path: String = str(
		NPC_MOTHER_TEXTURES.get(pose, NPC_MOTHER_TEXTURES["standing"])
	)

	if texture_path.is_empty():
		return

	if not ResourceLoader.exists(texture_path):
		return

	var loaded_resource: Resource = load(texture_path)

	if loaded_resource is Texture2D:
		mother_visual.texture = loaded_resource

func _apply_responsive_layout() -> void:
	var viewport_width: float = size.x
	var viewport_height: float = size.y

	matching_board.columns = 3

	if viewport_width < 1120.0 or viewport_height >= 760.0:
		food_tray.columns = 3
	else:
		food_tray.columns = 6

func _setup_matching() -> void:
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

func _show_theme() -> void:
	set_state("THEME_INTRO")
	_set_character_layer(false)
	show_only(screens, theme_panel)

func _show_opening_dialogue() -> void:
	set_state("DIALOGUE_OPENING")
	dialogue_step = 0
	_set_character_layer(false)
	show_only(screens, dialogue_panel)

	%SpeakerLabel.text = str(
		level_config.get("dialogue", {}).get("opening_speaker", "Ibu")
	)
	%DialogueText.text = str(
		level_config.get("dialogue", {}).get("opening_text", "")
	)
	%DialogueNextButton.text = "LANJUT"
	_set_dialogue_speaker(%SpeakerLabel.text)

func _on_dialogue_next() -> void:
	if dialogue_step == 0:
		set_state("DIALOGUE_MISSION")
		dialogue_step = 1
		%SpeakerLabel.text = _player_speaker_name()
		%DialogueText.text = str(
			level_config.get("dialogue", {}).get("mission_player", "")
		)
		%DialogueNextButton.text = "LANJUT"
		_set_dialogue_speaker(%SpeakerLabel.text)
		return

	if dialogue_step == 1:
		dialogue_step = 2
		%SpeakerLabel.text = str(
			level_config.get("dialogue", {}).get("mission_speaker", "Ibu")
		)
		%DialogueText.text = str(
			level_config.get("dialogue", {}).get("mission_text", "")
		)
		%DialogueNextButton.text = "SIAP"
		_set_dialogue_speaker(%SpeakerLabel.text)
		return

	_show_tutorial()

func _apply_speaker_focus(mother_active: bool) -> void:
	mother_card.add_theme_stylebox_override(
		"panel",
		_make_character_style(mother_active)
	)
	player_card.add_theme_stylebox_override(
		"panel",
		_make_character_style(not mother_active)
	)

func _make_character_style(active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(1.0, 0.97, 0.87, 0.97)
		if active
		else Color(0.96, 0.96, 0.91, 0.82)
	)
	style.border_width_left = 4 if active else 2
	style.border_width_top = 4 if active else 2
	style.border_width_right = 4 if active else 2
	style.border_width_bottom = 4 if active else 2
	style.border_color = (
		Color(0.24, 0.58, 0.18, 1)
		if active
		else Color(0.48, 0.45, 0.36, 0.55)
	)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0, 0, 0, 0.18)
	style.shadow_size = 7 if active else 3
	return style

func _show_tutorial() -> void:
	set_state("TUTORIAL_PICK")
	_set_character_layer(false)
	show_only(screens, tutorial_panel)

	%TutorialStepLabel.text = "LANGKAH 1 DARI 2"
	%TutorialText.text = (
		"1. Tekan dan tahan gambar pangan.\n"
		+ "2. Seret gambar menuju nama yang sesuai."
	)
	%TutorialContinueButton.text = "LANJUT"
	%TutorialSkipButton.visible = bool(
		SettingsManager.get_flag("tutorial_level_01_seen", false)
	)
	tutorial_step = 0

func _on_tutorial_continue() -> void:
	if tutorial_step == 0:
		tutorial_step = 1
		set_state("TUTORIAL_DROP")
		%TutorialStepLabel.text = "LANGKAH 2 DARI 2"
		%TutorialText.text = (
			"Lepaskan gambar pada nama yang sesuai.\n"
			+ "Jika belum cocok, kartu akan kembali dan kamu bisa mencoba lagi."
		)
		%TutorialContinueButton.text = "COBA SEKARANG"
		return

	SettingsManager.set_flag("tutorial_level_01_seen", true)
	_start_gameplay()

func _start_gameplay() -> void:
	set_state("GAMEPLAY")
	_set_character_layer(false)
	show_only(screens, gameplay_layer)
	_apply_responsive_layout()

	if level_session.is_empty():
		level_session = GameState.begin_level_session(1)
		DurationTracker.begin_level_session(
			str(level_session.get("level_session_id", "")),
			1
		)

	DurationTracker.resume_active_play()
	TelemetryManager.begin_game(
		1,
		V3_MAIN_GAME_ID,
		V3_MAIN_GAME_TYPE,
		{
			"instruction_id": V3_MAIN_INSTRUCTION_ID,
			"instruction_version": 1,
			"instruction_text": V3_MAIN_INSTRUCTION_TEXT,
			"content_version": ContentDatabase.content_version
		}
	)
	progress_label.text = "Pangan 0/6"
	score_label.text = "Skor Main Game: 0/60"

	AnalyticsLogger.log_event(
		"level_main_started",
		{
			"level_session_id": level_session.get("level_session_id", ""),
			"level_no": 1,
			"content_version": ContentDatabase.content_version
		}
	)

func _on_progress_changed(matched: int, total: int, score: int) -> void:
	main_score = score
	progress_label.text = "Pangan %d/%d" % [matched, total]
	score_label.text = "Skor Main Game: %d/60" % main_score

func _show_feedback(text: String, correct: bool) -> void:
	feedback_toast.text = text
	feedback_toast.visible = true

	if correct:
		AudioManager.play_sfx("drop_correct")
		feedback_toast.add_theme_color_override(
			"font_color",
			Color(0.12, 0.42, 0.16)
		)
	else:
		AudioManager.play_sfx("wrong")
		feedback_toast.add_theme_color_override(
			"font_color",
			Color(0.66, 0.18, 0.12)
		)

	if correct:
		UIMotion.play_pop(feedback_toast, 1.04)
	else:
		UIMotion.play_shake(feedback_toast, 5.0)

	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(
		func() -> void:
			feedback_toast.visible = false
	)

func _on_all_matched(score: int) -> void:
	main_score = score
	DurationTracker.pause_active_play()
	TelemetryManager.complete_game(
		1,
		V3_MAIN_GAME_ID,
		V3_MAIN_GAME_TYPE,
		main_score,
		DurationTracker.current_active_ms()
	)
	set_state("GAMEPLAY_SUCCESS")
	_set_character_layer(false)
	show_only(screens, gameplay_success_panel)
	%GameplaySuccessText.text = "Hebat! Semua pangan berhasil kamu kenali."
	UIMotion.play_reward(gameplay_success_panel)

func _show_literacy_intro() -> void:
	set_state("LITERACY_INTRO")
	_set_character_layer(false)
	show_only(screens, literacy_panel)
	%LiteracyIntro.visible = true
	%LiteracyQuestion.visible = false
	%LiteracyFeedback.visible = false

func _start_literacy_question() -> void:
	set_state("LITERACY_QUESTION")
	_set_character_layer(false)
	show_only(screens, literacy_panel)

	%LiteracyIntro.visible = false
	%LiteracyQuestion.visible = true
	%LiteracyFeedback.visible = false

	var literacy: Dictionary = level_config.get("literacy", {})
	%QuestionText.text = str(literacy.get("question_text", ""))

	var answers: Array = literacy.get("answers", [])
	var buttons: Array = [%AnswerA, %AnswerB, %AnswerC]

	for index in range(min(answers.size(), buttons.size())):
		var answer: Dictionary = answers[index]
		var button: Button = buttons[index]
		button.text = str(answer.get("text", ""))
		button.set_meta(
			"answer_id",
			str(answer.get("answer_id", ""))
		)

	DurationTracker.resume_active_play()

func _on_literacy_button_pressed(button: Button) -> void:
	_on_literacy_answer(str(button.get_meta("answer_id", "")))

func _on_literacy_answer(answer_id: String) -> void:
	DurationTracker.pause_active_play()
	literacy_attempts += 1

	var literacy: Dictionary = level_config.get("literacy", {})
	var correct_id: String = str(
		literacy.get("correct_answer_id", "")
	)
	var correct: bool = answer_id == correct_id

	AnalyticsLogger.log_event(
		"quiz_answer",
		{
			"level_no": 1,
			"question_id": literacy.get("question_id", "l1_q01"),
			"selected_answer_id": answer_id,
			"status": "CORRECT" if correct else "WRONG",
			"attempt_no": literacy_attempts
		}
	)

	%LiteracyQuestion.visible = false
	%LiteracyFeedback.visible = true

	if correct:
		if literacy_attempts == 1:
			literacy_score = int(
				level_config.get("scoring", {}).get(
					"literacy_first_attempt",
					30
				)
			)
		else:
			literacy_score = int(
				level_config.get("scoring", {}).get(
					"literacy_after_retry",
					20
				)
			)

		%LiteracyFeedbackText.text = str(
			literacy.get("feedback_correct", "Tepat!")
		)
		%LiteracyRetryButton.visible = false
		%LiteracyResultButton.visible = true
		UIMotion.play_reward(%LiteracyFeedback)

		AnalyticsLogger.log_event(
			"literacy_complete",
			{
				"level_no": 1,
				"challenge_score": literacy_score
			}
		)
		return

	%LiteracyFeedbackText.text = str(
		literacy.get("feedback_retry", "Belum tepat.")
	)
	UIMotion.play_shake(%LiteracyFeedback, 5.0)
	%LiteracyRetryButton.visible = true
	%LiteracyResultButton.visible = false

func _show_result() -> void:
	set_state("RESULT")
	_set_character_layer(false)

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
	UIMotion.play_pop(result_panel, 1.03)
	%ResultScore.text = "%d / 100" % final_score
	%ResultSummary.text = (
		"Pangan dikenali: 6/6\n"
		+ "Tantangan: Selesai\n"
		+ "Durasi aktif: %s" % _format_ms(duration_ms)
	)

func _show_info() -> void:
	set_state("FOOD_INFORMATION")
	_set_character_layer(false)
	info_index = 0
	show_only(screens, info_panel)
	_render_info()

func _render_info() -> void:
	var food: Dictionary = foods[info_index]
	var food_id: String = str(food.get("food_id", ""))

	info_glyph.food_id = food_id
	info_glyph.visible = false

	var texture_path: String = str(FOOD_TEXTURES.get(food_id, ""))

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
	_set_character_layer(false)
	show_only(screens, badge_panel)
	UIMotion.play_reward(badge_panel)

	var badge: Dictionary = level_config.get("badge", {})
	%BadgeName.text = str(
		badge.get("display_name", "Penjelajah Pangan Lokal")
	)
	%BadgeDescription.text = str(
		badge.get("description", "")
	)

func _show_closing() -> void:
	set_state("CLOSING_DIALOGUE")
	_set_character_layer(false)
	show_only(screens, closing_panel)
	%ClosingText.text = str(
		level_config.get("dialogue", {}).get("closing_text", "")
	)
	_set_dialogue_speaker("Ibu")

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

func _set_character_layer(_should_show: bool) -> void:
	character_layer.visible = false

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
	var total_seconds: int = maxi(0, int(value_ms / 1000.0))
	var minutes: int = int(total_seconds / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]
