extends LevelFlowController

const FOOD_CARD_SCENE := preload("res://scenes/shared/food_card.tscn")
const GROUP_ZONE_SCENE := preload("res://scenes/levels/level_02/level_02_group_drop_zone.tscn")
const DROP_SLOT_SCENE := preload("res://scenes/shared/drop_slot.tscn")

const LEVEL2_FOOD_TEXTURES := {
	"food_rice": "res://assets/visual/foods/food_rice.png",
	"food_cassava": "res://assets/visual/foods/food_cassava.png",
	"food_water_spinach": "res://assets/visual/foods/food_water_spinach.png",
	"food_spinach": "res://assets/visual/foods/food_spinach.png",
	"food_banana": "res://assets/visual/foods/food_banana.png",
	"food_papaya": "res://assets/visual/foods/food_papaya.png",
	"food_corn": "res://assets/visual/foods/food_corn.png",
	"food_sweet_potato": "res://assets/visual/foods/food_sweet_potato.png",
	"food_eggplant": "res://assets/visual/foods/food_eggplant.png",
	"food_cucumber": "res://assets/visual/foods/food_cucumber.png",
	"food_mango": "res://assets/visual/foods/food_mango.png",
	"food_guava": "res://assets/visual/foods/food_guava.png"
}

@onready var theme_panel: Control = %ThemePanel
@onready var dialogue_panel: Control = %DialoguePanel

@onready var tutorial_panel: Control = %TutorialPanel
@onready var gameplay_layer: Control = %GameplayLayer
@onready var batch_transition_panel: Control = %BatchTransitionPanel
@onready var gameplay_success_panel: Control = %GameplaySuccessPanel
@onready var literacy_panel: Control = %LiteracyPanel
@onready var result_panel: Control = %ResultPanel
@onready var info_panel: Control = %InfoPanel
@onready var badge_panel: Control = %BadgePanel
@onready var closing_panel: Control = %ClosingPanel
@onready var round_complete_mask: Control = %RoundCompleteMask
@onready var grouping_controller: GroupingController = %GroupingController

var screens: Array[Control] = []
var level_config: Dictionary = {}
var foods: Array[Dictionary] = []
var foods_by_id: Dictionary = {}
var level_session: Dictionary = {}
var dialogue_lines: Array = []
var dialogue_index := 0
var main_score := 0
var literacy_score := 0
var final_score := 0
var literacy_round_index := 0
var literacy_attempts: Dictionary = {}
var info_index := 0
var level_attempt_base_duration_ms: int = 0
var reset_count: int = 0
var back_to_map_count: int = 0
var game2_target_normal_style: StyleBoxFlat
var game2_target_hover_style: StyleBoxFlat
var game2_target_hover_active: bool = false

func _ready() -> void:
	if not _ensure_level_runtime_ready():
		return
	set_meta("level_no", 2)
	_prepare_level_presentation()
	level_config = ContentDatabase.get_level_02_config()
	foods = ContentDatabase.get_level_02_foods()
	for food in foods:
		foods_by_id[str(food.get("food_id", ""))] = food
	screens = [theme_panel, dialogue_panel, tutorial_panel, gameplay_layer, batch_transition_panel, gameplay_success_panel, literacy_panel, result_panel, info_panel, badge_panel, closing_panel]
	_connect_ui()
	_setup_grouping()
	_configure_gameplay_layout()
	_show_theme()

func _connect_ui() -> void:
	%ThemeStartButton.pressed.connect(_show_opening_dialogue)
	%DialogueNextButton.pressed.connect(_on_dialogue_next)
	%TutorialContinueButton.pressed.connect(_start_gameplay)
	%TutorialSkipButton.pressed.connect(_start_gameplay)
	%HintButton.pressed.connect(grouping_controller.request_hint)
	%ResetButton.pressed.connect(_on_reset_pressed)
	%GameplaySuccessNextButton.pressed.connect(_start_literacy)
	%ChallengeNextButton.pressed.connect(_advance_literacy)
	%ResultNextButton.pressed.connect(_show_info)
	%InfoNextButton.pressed.connect(_advance_info)
	%BadgeNextButton.pressed.connect(_show_closing)
	%ClosingMapButton.pressed.connect(_finish_level)
	%RoundCompleteNextButton.pressed.connect(_on_round_complete_next_pressed)
	grouping_controller.progress_changed.connect(_on_progress_changed)
	grouping_controller.batch_completed.connect(_on_batch_completed)
	grouping_controller.all_grouped.connect(_on_all_grouped)
	grouping_controller.feedback.connect(_show_feedback)

	_bind_motion_controls()

func _bind_motion_controls() -> void:
	var motion_buttons: Array = [
		%ThemeStartButton,
		%DialogueNextButton,
		%TutorialContinueButton,
		%TutorialSkipButton,
		%HintButton,
		%ResetButton,
		%BackButton,
		%GameplaySuccessNextButton,
		%ChallengeNextButton,
		%ResultNextButton,
		%InfoNextButton,
		%BadgeNextButton,
		%ClosingMapButton,
		%RoundCompleteNextButton
	]

	for button_value in motion_buttons:
		var button := button_value as BaseButton

		if button != null:
			UIMotion.bind_button(button)

func _setup_grouping() -> void:
	grouping_controller.configure(level_config, foods)
	_rebuild_group_zones()


func _rebuild_group_zones() -> void:
	for child_variant in %GroupBoard.get_children():
		var child_node: Node = child_variant as Node

		if child_node == null:
			continue

		%GroupBoard.remove_child(child_node)
		child_node.queue_free()

	for group_id_value in level_config.get("group_ids", []):
		var group_id: String = str(group_id_value)
		var zone: GroupDropZone = GROUP_ZONE_SCENE.instantiate()
		%GroupBoard.add_child(zone)
		zone.setup(
			group_id,
			_level2_group_display_name(group_id),
			int(level_config.get("target_per_group", 4))
		)
		grouping_controller.register_zone(group_id, zone)

func _process(_delta: float) -> void:
	if not is_instance_valid(gameplay_layer):
		return

	var viewport: Viewport = get_viewport()
	var dragging: bool = viewport.gui_is_dragging()
	var mouse_position: Vector2 = viewport.get_mouse_position()
	var gameplay_visible: bool = gameplay_layer.visible
	var modal_visible: bool = round_complete_mask.visible

	for zone_variant in %GroupBoard.get_children():
		var zone_node: Node = zone_variant as Node
		var zone_control: Control = zone_node as Control

		if zone_node == null or zone_control == null:
			continue

		if not zone_node.has_method("set_drag_hover"):
			continue

		var should_highlight: bool = false

		if gameplay_visible and dragging:
			should_highlight = (
				zone_control.get_global_rect().has_point(
					mouse_position
				)
			)

		zone_node.call(
			"set_drag_hover",
			should_highlight
		)

	var literacy_target_hover: bool = false
	var target_control: Control = %TargetPanel as Control

	if (
		literacy_panel.visible
		and dragging
		and not modal_visible
		and target_control != null
	):
		literacy_target_hover = (
			target_control.get_global_rect().has_point(
				mouse_position
			)
		)

	_set_literacy_target_hover(
		literacy_target_hover
	)


func _level2_group_display_name(group_id: String) -> String:
	match group_id:
		"group_staple_root":
			return "KELOMPOK\nPANGAN / UMBI"
		"group_vegetable":
			return "KELOMPOK\nSAYURAN"
		"group_fruit":
			return "KELOMPOK\nBUAHAN"
		_:
			return ContentDatabase.get_group_name(group_id)


func _configure_gameplay_layout() -> void:
	%GroupSummary.visible = false
	%ScoreLabel.text = "0 / 60"
	%ProgressLabel.text = "0 / 12"
	%GameplayLogo.visible = false
	%Game2Logo.visible = false

	var logo_paths: Array[String] = [
		"res://assets/visual/ui/logo_game.png",
        "res://assets/visual/main_map/small_logo.png"
	]

	for logo_path in logo_paths:
		if not ResourceLoader.exists(logo_path):
			continue

		var resource: Resource = load(logo_path)

		if resource is Texture2D:
			var logo_texture: Texture2D = resource as Texture2D
			%GameplayLogo.texture = logo_texture
			%GameplayLogo.visible = true
			%Game2Logo.texture = logo_texture
			%Game2Logo.visible = true
			break
	_configure_literacy_target_hover_styles()

func _configure_literacy_target_hover_styles() -> void:
	var source_style: StyleBox = %TargetPanel.get_theme_stylebox(
		"panel"
	)

	if source_style is StyleBoxFlat:
		game2_target_normal_style = (
			source_style.duplicate() as StyleBoxFlat
		)
	else:
		game2_target_normal_style = StyleBoxFlat.new()
		game2_target_normal_style.bg_color = Color(
			0.99,
			0.99,
			0.98,
			1.0
		)
		game2_target_normal_style.border_color = Color(
			0.0,
			0.36,
			0.22,
			1.0
		)
		game2_target_normal_style.set_border_width_all(2)

	game2_target_hover_style = (
		game2_target_normal_style.duplicate() as StyleBoxFlat
	)
	game2_target_hover_style.bg_color = Color(
		1.0,
		0.96,
		0.68,
		1.0
	)
	game2_target_hover_style.border_color = Color(
		0.92,
		0.70,
		0.08,
		1.0
	)
	game2_target_hover_style.set_border_width_all(4)

	game2_target_hover_active = true
	_set_literacy_target_hover(false)


func _set_literacy_target_hover(
	active: bool
) -> void:
	if (
		game2_target_normal_style == null
		or game2_target_hover_style == null
	):
		return

	if game2_target_hover_active == active:
		return

	game2_target_hover_active = active

	if active:
		%TargetPanel.add_theme_stylebox_override(
			"panel",
			game2_target_hover_style
		)
	else:
		%TargetPanel.add_theme_stylebox_override(
			"panel",
			game2_target_normal_style
		)


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
	_show_tutorial()

func _render_dialogue_line() -> void:
	if dialogue_lines.is_empty():
		return
	var line: Dictionary = dialogue_lines[dialogue_index]
	%SpeakerLabel.text = str(line.get("speaker", ""))
	_set_dialogue_speaker(%SpeakerLabel.text)
	%DialogueText.text = str(line.get("text", ""))
	var is_last := dialogue_index == dialogue_lines.size() - 1
	%DialogueNextButton.text = "SIAP" if current_state == "DIALOGUE_MISSION" and is_last else "LANJUT"

func _show_tutorial() -> void:
	var preview_flag_key: String = str(
		level_config.get(
			"preview_flag_key",
            "preview_food_seen_level_02"
		)
	)
	var preview_seen: bool = bool(
		SettingsManager.get_flag(
			preview_flag_key,
			false
		)
	)

	if not preview_seen:
		SettingsManager.set_flag(
			preview_flag_key,
			true
		)
		AnalyticsLogger.log_event(
			"content_preview_seen",
			{
				"level_no": 2,
				"food_ids": level_config.get(
					"preview_food_ids",
					[]
				)
			}
		)

	%TutorialText.text = (
        "Di Level 2 kamu mengenal enam pangan baru: "
		+ "Jagung, Ubi Jalar, Terung, Ketimun, Mangga, dan Jambu Biji.\n\n"
		+ "Seret setiap pangan ke kelompok yang sesuai. "
		+ "Setiap kelompok harus berisi empat pangan."
	)

	set_state("TUTORIAL_GROUPING")
	show_only(screens, tutorial_panel)
	%TutorialSkipButton.visible = bool(
		SettingsManager.get_flag(
			str(
				level_config.get(
					"tutorial_flag_key",
                    "tutorial_level_02_seen"
				)
			),
			false
		)
	)

func _start_gameplay() -> void:
	SettingsManager.set_flag(
		str(
			level_config.get(
				"tutorial_flag_key",
                "tutorial_level_02_seen"
			)
		),
		true
	)

	_prepare_or_resume_level_session()

	DurationTracker.begin_level_session(
		str(level_session.get("level_session_id", "")),
		2
	)
	DurationTracker.resume_active_play()

	set_state("GAMEPLAY_BATCH_1")
	show_only(screens, gameplay_layer)
	grouping_controller.activate_batch(0)
	_load_batch_cards(0)
	_on_progress_changed(
		0,
		foods.size(),
		0,
		{}
	)

	AnalyticsLogger.log_event(
		"level_main_started",
		{
			"level_session_id": level_session.get(
				"level_session_id",
                ""
			),
			"level_no": 2,
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

		if int(session_value.get("level_no", 0)) != 2:
			continue

		if int(session_value.get("completed_at", 0)) != 0:
			continue

		level_session = session_value.duplicate(true)
		break

	if level_session.is_empty():
		level_session = GameState.begin_level_session(2)

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

	reset_count += 1
	_persist_level_interaction_snapshot("reset")

	AnalyticsLogger.log_event(
		"level_game_reset",
		{
			"level_session_id": level_session.get(
				"level_session_id",
                ""
			),
			"level_no": 2,
			"reset_count": reset_count,
			"active_duration_ms": (
				level_attempt_base_duration_ms
				+ DurationTracker.current_active_ms()
			)
		}
	)

	main_score = 0
	%FeedbackToast.visible = false

	grouping_controller.configure(
		level_config,
		foods
	)
	_rebuild_group_zones()
	grouping_controller.activate_batch(0)
	_load_batch_cards(0)
	_on_progress_changed(
		0,
		foods.size(),
		0,
		{}
	)

	set_state("GAMEPLAY_BATCH_1")
	show_only(screens, gameplay_layer)


func _load_batch_cards(batch_index: int) -> void:
	for child in %FoodTray.get_children():
		child.queue_free()
	for food_id_value in grouping_controller.get_batch_food_ids(batch_index):
		var food_id := str(food_id_value)
		var food: Dictionary = foods_by_id.get(food_id, {})
		var card: FoodCard = FOOD_CARD_SCENE.instantiate()
		%FoodTray.add_child(card)
		card.setup(food_id, "", str(food.get("group_id", "")), -1, false, false)

func _on_progress_changed(matched: int, total: int, score: int, counts: Dictionary) -> void:
	main_score = score
	%ProgressLabel.text = "%d / %d" % [matched, total]
	%ScoreLabel.text = "%d / 60" % main_score

	var staple: int = int(counts.get("group_staple_root", 0))
	var veg: int = int(counts.get("group_vegetable", 0))
	var fruit: int = int(counts.get("group_fruit", 0))
	%GroupSummary.text = (
        "Pokok/Umbi %d/4 | Sayuran %d/4 | Buah %d/4"
		% [staple, veg, fruit]
	)

func _on_batch_completed(batch_id: int) -> void:
	if batch_id != 1:
		return
	DurationTracker.pause_active_play()
	%FeedbackToast.visible = false
	set_state("BATCH_TRANSITION")
	show_only(screens, batch_transition_panel)
	UIMotion.play_pop(batch_transition_panel, 1.02)
	var tween: Tween = create_tween()
	tween.tween_interval(2.6)
	tween.tween_callback(_start_batch_2)

func _start_batch_2() -> void:
	set_state("GAMEPLAY_BATCH_2")
	show_only(screens, gameplay_layer)
	grouping_controller.activate_batch(1)
	_load_batch_cards(1)
	DurationTracker.resume_active_play()

func _on_all_grouped(score: int) -> void:
	main_score = score
	DurationTracker.pause_active_play()
	set_state("GAMEPLAY_SUCCESS")
	show_only(screens, gameplay_success_panel)
	%SuccessText.text = "Hebat! Semua pangan sudah berada pada kelompok yang tepat.\nMain Game: %d/60" % main_score
	UIMotion.play_reward(gameplay_success_panel)

func _start_literacy() -> void:
	literacy_round_index = 0
	literacy_attempts.clear()
	literacy_score = 0
	set_state("LITERACY_ROUND_1")
	show_only(screens, literacy_panel)
	_render_literacy_round()

func _render_literacy_round() -> void:
	_clear_container(%ChallengeSlotHolder)
	_clear_container(%ChallengeChoiceTray)
	_hide_round_complete_modal()

	var rounds: Array = level_config.get("literacy_rounds", [])
	var round_data: Dictionary = rounds[literacy_round_index]
	var round_id: String = str(round_data.get("round_id", ""))

	if not literacy_attempts.has(round_id):
		literacy_attempts[round_id] = 0

	var given_names: Array[String] = []

	for food_id_value in round_data.get("given_ids", []):
		var food: Dictionary = ContentDatabase.get_food(
			str(food_id_value)
		)
		given_names.append(
			str(food.get("display_name", ""))
		)

	%ReferenceFood1.text = "-"
	%ReferenceFood2.text = "-"
	%ReferenceFood3.text = "-"

	if given_names.size() > 0:
		%ReferenceFood1.text = given_names[0]

	if given_names.size() > 1:
		%ReferenceFood2.text = given_names[1]

	if given_names.size() > 2:
		%ReferenceFood3.text = given_names[2]

	%LiteracyTitle.text = "PERMAINAN KEDUA"
	%LiteracyInstruction.text = (
        "Pindahkan 1 pangan di bawah ini "
		+ "untuk melengkapi kelompoknya."
	)
	%ChallengeFeedback.text = (
        "Seret satu pangan ke kotak kosong di sebelah kanan."
	)
	%ChallengeNextButton.visible = false

	_update_literacy_game2_hud(literacy_round_index)

	var slot: FoodDropSlot = DROP_SLOT_SCENE.instantiate()
	slot.custom_minimum_size = Vector2.ZERO
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	%ChallengeSlotHolder.add_child(slot)
	slot.setup(
		str(round_data.get("correct_food_id", "")),
        ""
	)
	_style_literacy_target_slot(slot)
	slot.drop_received.connect(
		_on_challenge_drop.bind(round_data)
	)

	for choice_id_value in round_data.get("choice_ids", []):
		var food_id: String = str(choice_id_value)
		var food: Dictionary = foods_by_id.get(
			food_id,
			ContentDatabase.get_food(food_id)
		)
		var card: FoodCard = FOOD_CARD_SCENE.instantiate()
		%ChallengeChoiceTray.add_child(card)
		card.setup(
			food_id,
			str(food.get("display_name", "")),
			str(food.get("group_id", "")),
			-1,
			true,
			false
		)

	DurationTracker.resume_active_play()


func _update_literacy_game2_hud(
	completed_matches: int
) -> void:
	var scoring: Dictionary = level_config.get("scoring", {})
	var max_literacy_score: int = (
		int(scoring.get("literacy_first_attempt", 10))
		* 3
	)
	var displayed_round: int = literacy_round_index + 1

	%LiteracyScoreLabel.text = "%d / %d" % [
		literacy_score,
		max_literacy_score
	]
	%LiteracyMatchLabel.text = "%d / 3" % completed_matches
	%LiteracyRoundLabel.text = "%d / 3" % displayed_round

func _on_challenge_drop(food_id: String, card: FoodCard, slot: FoodDropSlot, round_data: Dictionary) -> void:
	DurationTracker.pause_active_play()
	var round_id := str(round_data.get("round_id", ""))
	literacy_attempts[round_id] = int(literacy_attempts.get(round_id, 0)) + 1
	var attempt_no := int(literacy_attempts[round_id])
	var correct := food_id == str(round_data.get("correct_food_id", ""))
	AnalyticsLogger.log_event("literacy_answer", {"level_no":2,"literacy_round":literacy_round_index+1,"selected_answer":food_id,"correct":correct,"attempt_no":attempt_no})
	if correct:
		AudioManager.play_sfx(
			"character_select"
		)
		slot.accept_card(card)
		_style_literacy_target_card(card)
		_style_literacy_target_slot(slot)
		UIMotion.play_pop(card, 1.06)
		UIMotion.play_pop(%TargetPanel, 1.03)
		var scoring: Dictionary = level_config.get("scoring", {})
		literacy_score += (
			int(scoring.get("literacy_first_attempt", 10))
			if attempt_no == 1
			else int(scoring.get("literacy_after_retry", 7))
		)
		_update_literacy_game2_hud(
			literacy_round_index + 1
		)
		%ChallengeFeedback.text = (
            "Tepat! Kelompok ini sudah lengkap."
		)
		%ChallengeNextButton.visible = false
		_show_round_complete_modal(round_data)
	else:
		AudioManager.play_sfx(
			"click"
		)
		card.show_wrong_feedback()
		UIMotion.play_shake(card, 6.0)
		%ChallengeFeedback.text = "Belum melengkapi kelompok ini. Coba lihat kembali pangan yang sudah tersusun."
		DurationTracker.resume_active_play()

func _advance_literacy() -> void:
	_hide_round_complete_modal()
	if literacy_round_index < 2:
		literacy_round_index += 1
		set_state("LITERACY_ROUND_%d" % [literacy_round_index + 1])
		_render_literacy_round()
	else:
		_show_result()

func _on_round_complete_next_pressed() -> void:
	_hide_round_complete_modal()
	_advance_literacy()


func _show_round_complete_modal(round_data: Dictionary) -> void:
	_set_literacy_target_hover(false)
	%RoundCompleteHeaderLabel.text = (
        "HEBAT!"
	)
	%RoundCompleteMessage.text = (
		"Kelompok %s
Sudah Lengkap"
		% _resolve_round_group_name(round_data)
	)
	%RoundCompleteNextButton.text = (
        "LANJUT"
		if literacy_round_index == 2
		else "RONDE SELANJUTNYA"
	)
	_populate_round_complete_modal(round_data)
	round_complete_mask.visible = true

	var round_panel: Control = (
		round_complete_mask.get_node_or_null(
			"RoundCompleteCenter/RoundCompletePanel"
		) as Control
	)

	if round_panel != null:
		UIMotion.play_pop(round_panel, 1.025)


func _hide_round_complete_modal() -> void:
	round_complete_mask.visible = false


func _populate_round_complete_modal(round_data: Dictionary) -> void:
	var holder_nodes: Array[Node] = [
		%RoundCompleteFoodHolder1,
		%RoundCompleteFoodHolder2,
		%RoundCompleteFoodHolder3,
		%RoundCompleteFoodHolder4
	]

	for holder_variant in holder_nodes:
		var holder_node: Node = holder_variant as Node

		if holder_node == null:
			continue

		_clear_container(holder_node)

	var food_ids: Array[String] = []

	for food_id_value in round_data.get("given_ids", []):
		food_ids.append(str(food_id_value))

	food_ids.append(str(round_data.get("correct_food_id", "")))

	for index in range(min(food_ids.size(), holder_nodes.size())):
		var holder_node: Node = holder_nodes[index] as Node
		var food_id: String = food_ids[index]
		var food: Dictionary = foods_by_id.get(
			food_id,
			ContentDatabase.get_food(food_id)
		)
		var preview_texture: Texture2D = (
			_load_food_information_texture(food)
		)
		var preview_image: TextureRect = TextureRect.new()

		preview_image.custom_minimum_size = Vector2(144, 144)
		preview_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		preview_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview_image.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)
		preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview_image.texture = preview_texture
		holder_node.add_child(preview_image)


func _resolve_round_group_name(round_data: Dictionary) -> String:
	var correct_food_id: String = str(round_data.get("correct_food_id", ""))
	var correct_food: Dictionary = foods_by_id.get(
		correct_food_id,
		ContentDatabase.get_food(correct_food_id)
	)
	var group_name: String = str(correct_food.get("group_name", "")).strip_edges()

	if not group_name.is_empty():
		return group_name

	for food_id_value in round_data.get("given_ids", []):
		var food: Dictionary = ContentDatabase.get_food(str(food_id_value))
		group_name = str(food.get("group_name", "")).strip_edges()
		if not group_name.is_empty():
			return group_name

	return "Pangan Lokal"


func _style_literacy_target_slot(slot: FoodDropSlot) -> void:
	if slot == null:
		return

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left = 0
	slot.add_theme_stylebox_override(
		"panel",
		style
	)


func _style_literacy_target_card(card: FoodCard) -> void:
	if card == null:
		return

	card.custom_minimum_size = Vector2(230, 205)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.position = Vector2.ZERO

	for label_variant in card.find_children(
		"*",
		"Label",
		true,
		false
	):
		var label_node: Label = label_variant as Label

		if label_node != null:
			label_node.visible = false

	var image_node: Node = card.find_child(
		"FoodImage",
		true,
		false
	)
	var food_image: TextureRect = image_node as TextureRect

	if food_image != null:
		food_image.custom_minimum_size = Vector2(210, 180)
		food_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		food_image.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)


func _show_result() -> void:
	_hide_round_complete_modal()
	set_state("RESULT")

	var attempt_duration_ms: int = (
		DurationTracker.finish_level_session()
	)
	var duration_ms: int = (
		level_attempt_base_duration_ms
		+ attempt_duration_ms
	)

	final_score = (
		main_score
		+ literacy_score
		+ int(
			level_config.get(
				"scoring",
				{}
			).get(
				"completion",
				10
			)
		)
	)

	level_session["active_duration_ms"] = duration_ms
	level_session["reset_count"] = reset_count
	level_session["retry_count"] = reset_count
	level_session["back_to_map_count"] = back_to_map_count
	level_session["completed_at"] = (
		Time.get_unix_time_from_system()
	)
	GameState.update_level_session(level_session)
	SaveManager.request_save()

	show_only(screens, result_panel)
	UIMotion.play_pop(result_panel, 1.03)
	%ResultScore.text = "%d / 100" % final_score
	%ResultSummary.text = (
        "Pangan dikelompokkan: 12/12\n"
		+ "Tantangan literasi: 3/3\n"
		+ "Reset: %d kali\n" % reset_count
		+ "Kembali ke Peta: %d kali\n" % back_to_map_count
		+ "Durasi aktif: %s" % _format_ms(duration_ms)
	)

func _show_info() -> void:
	set_state("FOOD_INFORMATION")
	info_index = 0
	show_only(screens, info_panel)
	_render_info()

func _render_info() -> void:
	var food: Dictionary = foods[info_index]
	%InfoTitle.text = str(food.get("display_name", ""))
	%InfoGroup.text = "Kelompok: %s" % str(food.get("group_name", ""))
	%InfoNew.text = "Baru di Level 2" if bool(food.get("is_new_in_current_level", false)) else "Sudah dikenal sejak Level 1"
	%InfoType.text = "Jenis sederhana: %s" % str(food.get("group_name", ""))
	%InfoImage.texture = _load_food_information_texture(food)
	%InfoText.text = str(food.get("info_level_02", ""))
	%InfoCounter.text = "%d / %d" % [info_index + 1, foods.size()]
	%InfoNextButton.text = "LANJUT" if info_index < foods.size() - 1 else "SELESAI"


func _load_food_information_texture(food: Dictionary) -> Texture2D:
	var food_id: String = str(food.get("food_id", "")).strip_edges()
	var canonical_path: String = str(
		LEVEL2_FOOD_TEXTURES.get(food_id, "")
	).strip_edges()

	if (
		not canonical_path.is_empty()
		and ResourceLoader.exists(canonical_path)
	):
		var canonical_resource: Resource = load(canonical_path)

		if canonical_resource is Texture2D:
			return canonical_resource as Texture2D

	var direct_texture: Variant = food.get("texture", null)

	if direct_texture is Texture2D:
		return direct_texture as Texture2D

	for key_variant in [
		"image_path",
		"texture_path",
		"asset_path"
	]:
		var key_name: String = str(key_variant)
		var texture_path: String = str(
			food.get(key_name, "")
		).strip_edges()

		if texture_path.is_empty():
			continue

		if not ResourceLoader.exists(texture_path):
			continue

		var resource: Resource = load(texture_path)

		if resource is Texture2D:
			return resource as Texture2D

	return null


func _advance_info() -> void:
	if info_index < foods.size() - 1:
		info_index += 1
		_render_info()
	else:
		_show_badge()

func _show_badge() -> void:
	set_state("BADGE_REWARD")
	show_only(screens, badge_panel)
	UIMotion.play_reward(badge_panel)
	var badge: Dictionary = level_config.get("badge", {})
	%BadgeName.text = str(badge.get("display_name", ""))
	%BadgeDescription.text = str(badge.get("description", ""))

func _show_closing() -> void:
	set_state("CLOSING_DIALOGUE")
	show_only(screens, closing_panel)
	%ClosingText.text = str(level_config.get("dialogue", {}).get("closing", ""))
	_set_dialogue_speaker("Ibu Guru")

func _finish_level() -> void:
	set_state("LEVEL_COMPLETE")
	var duration_ms := int(level_session.get("active_duration_ms", DurationTracker.current_active_ms()))
	var badge: Dictionary = level_config.get("badge", {})
	GameState.complete_level(2, final_score, duration_ms, str(badge.get("badge_id", "badge_level_02")), str(badge.get("display_name", "Penyusun Kelompok Pangan Lokal")), str(level_session.get("level_session_id", "")))
	SceneRouter.goto("main_map")

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _show_feedback(
	text: String,
	correct: bool
) -> void:
	if text.begins_with("Tepat!"):
		AudioManager.play_sfx(
            "character_select"
		)
	elif text.begins_with("Belum tepat."):
		AudioManager.play_sfx(
            "click"
		)

	%FeedbackToast.text = text
	%FeedbackToast.visible = true

	if correct:
		UIMotion.play_pop(%FeedbackToast, 1.04)
	else:
		UIMotion.play_shake(%FeedbackToast, 5.0)

	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(
		func() -> void:
			%FeedbackToast.visible = false
	)

func _format_ms(ms: int) -> String:
	var total_seconds := int(round(ms / 1000.0))
	return "%02d:%02d" % [int(total_seconds / 60.0), total_seconds % 60]

func _ensure_level_runtime_ready() -> bool:
	if not ContentDatabase.initialize():
		push_error("Level 2 gagal menginisialisasi ContentDatabase.")
		return false

	SettingsManager.initialize()

	if not GameState.initialized:
		GameState.initialize()

	AnalyticsLogger.initialize()
	return true
