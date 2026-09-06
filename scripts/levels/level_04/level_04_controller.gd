extends LevelFlowController

# BUNDLE49_LEVEL4_FLOW_FIX

const FOOD_CARD_SCENE := preload("res://scenes/shared/food_card.tscn")
const INGREDIENT_SLOT_SCENE := preload("res://scenes/shared/ingredient_slot.tscn")
const NAMED_CARD_SCENE := preload("res://scenes/shared/named_drag_card.tscn")
const NAMED_SLOT_SCENE := preload("res://scenes/shared/named_drop_slot.tscn")
const FOOD_DROP_SLOT_SCENE := preload("res://scenes/shared/drop_slot.tscn")

const PROCESSED_TEXTURE_PATHS := {
	"processed_banana_cassava_compote": "res://assets/visual/processed_foods/processed_banana_cassava_compote.png",
	"processed_spinach_corn_clear_soup": "res://assets/visual/processed_foods/processed_spinach_corn_clear_soup.png",
	"processed_water_spinach_eggplant_stirfry": "res://assets/visual/processed_foods/processed_water_spinach_eggplant_stirfry.png",
	"processed_papaya_mango_rujak": "res://assets/visual/processed_foods/processed_papaya_mango_rujak.png"
}

@onready var theme_panel: Control = %ThemePanel
@onready var dialogue_panel: Control = %DialoguePanel
@onready var tutorial_panel: Control = %TutorialPanel
@onready var pre_game_panel: Control = %PreGamePanel
@onready var main_game_hud: Control = %MainGameHUD
@onready var timeout_panel: Control = %TimeoutPanel
@onready var main_success_panel: Control = %MainGameSuccessPanel
@onready var literacy_intro_panel: Control = %LiteracyIntroPanel
@onready var literacy_hud: Control = %LiteracyHUD
@onready var result_panel: Control = %ResultPanel
@onready var info_panel: Control = %InfoPanel
@onready var badge_panel: Control = %BadgePanel
@onready var closing_panel: Control = %ClosingPanel
@onready var order_controller: OrderController = %OrderController
@onready var countdown_controller: CountdownController = %CountdownController
@onready var feedback_toast: Label = %FeedbackToast

var screens: Array[Control] = []
var level_config: Dictionary = {}
var processed_foods: Array[Dictionary] = []
var processed_by_id: Dictionary = {}
var level_session: Dictionary = {}
var dialogue_lines: Array = []
var dialogue_index := 0
var main_attempt_index := 0
var order_index := 0
var ingredient_slot_a: IngredientSlot
var ingredient_slot_b: IngredientSlot
var process_slot: NamedDropSlot
var main_score := 0
var literacy_score := 0
var final_score := 0
var literacy_round_index := 0
var literacy_attempts: Dictionary = {}
var info_index := 0
var closing_index := 0
var timeout_count := 0
var main_attempt_saved := false
var literacy_transition_pending := false

func _ready() -> void:
	if not _ensure_level_runtime_ready():
		return
	set_meta("level_no", 4)
	_prepare_level_presentation()
	level_config = ContentDatabase.get_level_04_config()
	processed_foods = ContentDatabase.get_level_04_processed_foods()
	for item in processed_foods:
		processed_by_id[str(item.get("processed_food_id", ""))] = item
	screens = [theme_panel, dialogue_panel, tutorial_panel, pre_game_panel, main_game_hud, timeout_panel, main_success_panel, literacy_intro_panel, literacy_hud, result_panel, info_panel, badge_panel, closing_panel]
	order_controller.configure(level_config)
	countdown_controller.configure(int(level_config.get("countdown_seconds", 120)))
	_connect_ui()
	_show_theme()

func _connect_ui() -> void:
	%ThemeStartButton.pressed.connect(_show_opening_dialogue)
	%DialogueNextButton.pressed.connect(_on_dialogue_next)
	%TutorialContinueButton.pressed.connect(_show_pre_game)
	%TutorialSkipButton.pressed.connect(_show_pre_game)
	%PreGameStartButton.pressed.connect(_start_main_attempt)
	%HintButton.pressed.connect(_request_hint)
	%TimeoutRetryButton.pressed.connect(_retry_main_game)
	%MainSuccessNextButton.pressed.connect(_show_literacy_intro)
	%LiteracyStartButton.pressed.connect(_start_literacy)
	%ResultNextButton.pressed.connect(_show_info)
	%InfoNextButton.pressed.connect(_advance_info)
	%BadgeNextButton.pressed.connect(_show_closing)
	%ClosingNextButton.pressed.connect(_advance_closing)
	countdown_controller.time_changed.connect(_on_countdown_changed)
	countdown_controller.warning_30.connect(_on_warning_30)
	countdown_controller.warning_10.connect(_on_warning_10)
	countdown_controller.timeout_triggered.connect(_on_timeout)

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
	%DialogueNextButton.text = "SIAP" if current_state == "DIALOGUE_MISSION" and dialogue_index == dialogue_lines.size()-1 else "LANJUT"

func _show_tutorial() -> void:
	set_state("TUTORIAL")
	show_only(screens, tutorial_panel)
	%TutorialTitle.text = str(level_config.get("tutorial", {}).get("title", "DUA BAHAN + PROSES + TIMER"))
	%TutorialText.text = str(level_config.get("tutorial", {}).get("text", ""))
	%TutorialSkipButton.visible = bool(SettingsManager.get_flag(str(level_config.get("tutorial_flag_key", "level_04_tutorial_seen")), false))

func _show_pre_game() -> void:
	SettingsManager.set_flag(str(level_config.get("tutorial_flag_key", "level_04_tutorial_seen")), true)
	set_state("PRE_GAME")
	show_only(screens, pre_game_panel)
	var seconds := int(level_config.get("countdown_seconds", 120))
	%PreGameTimer.text = "%02d:%02d" % [int(seconds / 60.0), seconds % 60]

func _start_main_attempt() -> void:
	if level_session.is_empty():
		level_session = GameState.begin_level_session(4)
		level_session["timeout_count"] = 0
		DurationTracker.begin_level_session(str(level_session.get("level_session_id", "")), 4)
	main_attempt_index += 1
	var attempt_id := IdUtil.uuid_v4()
	main_attempt_saved = false
	order_index = 0
	main_score = 0
	order_controller.begin_main_attempt(attempt_id, main_attempt_index)
	countdown_controller.start()
	DurationTracker.resume_active_play()
	set_state("MAIN_GAME_PLAYER_CONTROL")
	show_only(screens, main_game_hud)
	_load_order(order_index)
	AnalyticsLogger.log_event("level_main_started", {
		"level_session_id":str(level_session.get("level_session_id", "")),
		"attempt_id":attempt_id,
		"attempt_index":main_attempt_index,
		"level_no":4,
		"countdown_initial":int(level_config.get("countdown_seconds", 120)),
		"content_version":ContentDatabase.content_version
	})

func _retry_main_game() -> void:
	level_session["retry_count"] = int(level_session.get("retry_count", 0)) + 1
	GameState.update_level_session(level_session)
	_start_main_attempt()

func _load_order(index: int) -> void:
	var orders: Array = level_config.get("orders", [])

	if index < 0 or index >= orders.size():
		return

	var order_data: Dictionary = orders[index]
	order_controller.begin_order(order_data)
	set_state("MAIN_GAME_PLAYER_CONTROL")

	var result_id := str(order_data.get("result_id", ""))
	var result: Dictionary = ContentDatabase.get_processed_food(result_id)
	var result_texture_path := str(PROCESSED_TEXTURE_PATHS.get(result_id, ""))

	%OrderProgress.text = "%d / %d" % [index + 1, orders.size()]
	%MainScoreLabel.text = "%d / 60" % order_controller.main_score
	%MainStatusLabel.text = "PILIH BAHAN"
	%TargetResultName.text = str(
		result.get("display_name", result_id)
	).to_upper()
	%TargetResultImage.texture = _load_processed_texture(
		result_texture_path
	)
	%MainInstructionLabel.text = (
        "LANGKAH 1 - SERET DUA BAHAN YANG SESUAI KE BAHAN 1 DAN BAHAN 2"
	)

	%FeedbackToast.text = ""
	%FeedbackToast.visible = false
	%CandidateFoodGrid.visible = true
	%ProcessTray.visible = false

	_set_level4_helper_message(
        "LANGKAH 1 - Seret dua bahan yang sesuai ke BAHAN 1 dan BAHAN 2."
	)

	_clear_container(%CandidateFoodGrid)
	_clear_container(%IngredientSlots)
	_clear_container(%ProcessSlotHolder)
	_clear_container(%ProcessTray)

	ingredient_slot_a = INGREDIENT_SLOT_SCENE.instantiate()
	ingredient_slot_b = INGREDIENT_SLOT_SCENE.instantiate()
	%IngredientSlots.add_child(ingredient_slot_a)
	%IngredientSlots.add_child(ingredient_slot_b)

	ingredient_slot_a.setup("BAHAN 1")
	ingredient_slot_b.setup("BAHAN 2")
	ingredient_slot_a.drop_received.connect(_on_ingredient_drop)
	ingredient_slot_b.drop_received.connect(_on_ingredient_drop)

	process_slot = NAMED_SLOT_SCENE.instantiate()
	%ProcessSlotHolder.add_child(process_slot)
	process_slot.custom_minimum_size = Vector2(150, 110)
	process_slot.setup(
		str(order_data.get("process_id", "")),
		"PROSES ?",
		"process_card",
		false
	)
	process_slot.drop_received.connect(_on_process_drop)

	var candidate_ids: Array = (
		order_data.get("candidate_food_ids", []).duplicate()
	)
	candidate_ids.shuffle()

	for food_id_value in candidate_ids:
		var food_id := str(food_id_value)
		var food: Dictionary = ContentDatabase.get_food(food_id)
		var card: FoodCard = FOOD_CARD_SCENE.instantiate()
		%CandidateFoodGrid.add_child(card)
		card.setup(
			food_id,
			str(food.get("display_name", "")),
			str(food.get("group_id", "")),
			-1,
			true,
			false,
            "ingredient_food_card"
		)
		UIMotion.play_pop(card, 1.02)

	UIMotion.play_pop(%TargetResultPanel, 1.025)

func _on_ingredient_drop(_food_id: String, card: FoodCard, slot: IngredientSlot) -> void:
	if current_state != "MAIN_GAME_PLAYER_CONTROL" or order_controller.current_pair_correct:
		return
	var source_slot := _find_parent_ingredient_slot(card)
	if source_slot != null and source_slot != slot:
		source_slot.release_current_to(%CandidateFoodGrid)
	if slot.current_card() != null and slot.current_card() != card:
		slot.release_current_to(%CandidateFoodGrid)
	slot.hold_card(card)
	if ingredient_slot_a.current_card() != null and ingredient_slot_b.current_card() != null:
		_validate_ingredient_pair()

func _find_parent_ingredient_slot(card: FoodCard) -> IngredientSlot:
	var node: Node = card.get_parent()
	while node != null and node != self:
		if node is IngredientSlot:
			return node as IngredientSlot
		node = node.get_parent()
	return null

func _validate_ingredient_pair() -> void:
	var card_a := ingredient_slot_a.current_card()
	var card_b := ingredient_slot_b.current_card()

	if card_a == null or card_b == null:
		return

	var result := order_controller.validate_pair(
		card_a.food_id,
		card_b.food_id
	)
	var correct := bool(result.get("correct", false))

	AnalyticsLogger.log_event(
		"l4_ingredient_pair",
		{
			"level_session_id": str(
				level_session.get("level_session_id", "")
			),
			"attempt_id": order_controller.attempt_id,
			"order_id": str(
				order_controller.current_order.get("order_id", "")
			),
			"selected_food_ids": [
				card_a.food_id,
				card_b.food_id
			],
			"attempt_no": int(result.get("attempt_no", 0)),
			"correct": correct,
			"timer_remaining": countdown_controller.seconds_left()
		}
	)

	if correct:
		ingredient_slot_a.lock_current()
		ingredient_slot_b.lock_current()
		process_slot.set_drop_enabled(true)

		%CandidateFoodGrid.visible = false
		%ProcessTray.visible = true
		%MainStatusLabel.text = "PILIH PROSES"
		%MainInstructionLabel.text = (
            "LANGKAH 2 - SERET PROSES MEMASAK YANG TEPAT KE KOTAK PROSES"
		)

		_populate_process_choices()

		AudioManager.play_sfx("drop_correct")
		_show_feedback(
			"Bahan sudah tepat! Sekarang pilih proses pengolahannya.",
			true
		)
		_set_level4_helper_message(
            "LANGKAH 2 - Bahan sudah tepat. Pilih proses yang sesuai."
		)
		UIMotion.play_reward(ingredient_slot_a)
		UIMotion.play_reward(ingredient_slot_b)
		UIMotion.play_pop(%ProcessPanel, 1.03)
		return

	card_a.show_wrong_feedback()
	card_b.show_wrong_feedback()
	UIMotion.play_shake(card_a, 6.0)
	UIMotion.play_shake(card_b, 6.0)
	AudioManager.play_sfx("wrong")
	_show_feedback(
		"Kombinasi bahan belum tepat. Kedua bahan dikembalikan.",
		false
	)
	_set_level4_helper_message(
        "BELUM TEPAT - Cocokkan dua bahan dengan target hasil olahan."
	)
	ingredient_slot_a.release_current_to(%CandidateFoodGrid)
	ingredient_slot_b.release_current_to(%CandidateFoodGrid)

func _populate_process_choices() -> void:
	_clear_container(%ProcessTray)

	var ids: Array = (
		order_controller.current_order.get(
			"candidate_process_ids",
			[]
		).duplicate()
	)
	ids.shuffle()

	for process_id_value in ids:
		var process_id := str(process_id_value)
		var process: Dictionary = ContentDatabase.get_process(process_id)
		var card: NamedDragCard = NAMED_CARD_SCENE.instantiate()
		%ProcessTray.add_child(card)
		card.setup(
			process_id,
			str(process.get("display_name", process_id)),
            "process_card"
		)
		card.custom_minimum_size = Vector2(170, 72)
		UIMotion.play_pop(card, 1.025)

func _on_process_drop(
	process_id: String,
	card: NamedDragCard,
	slot: NamedDropSlot
) -> void:
	if current_state != "MAIN_GAME_PLAYER_CONTROL":
		return

	var result := order_controller.validate_process(process_id)
	var correct := bool(result.get("correct", false))

	AnalyticsLogger.log_event(
		"l4_process_attempt",
		{
			"level_session_id": str(
				level_session.get("level_session_id", "")
			),
			"attempt_id": order_controller.attempt_id,
			"order_id": str(
				order_controller.current_order.get("order_id", "")
			),
			"process_id": process_id,
			"attempt_no": int(result.get("attempt_no", 0)),
			"correct": correct,
			"timer_remaining": countdown_controller.seconds_left()
		}
	)

	if not correct:
		card.show_wrong_feedback()
		UIMotion.play_shake(card, 6.0)
		AudioManager.play_sfx("wrong")
		_show_feedback(
			"Proses belum tepat. Hubungkan bahan dengan hasil olahan.",
			false
		)
		_set_level4_helper_message(
            "PROSES BELUM TEPAT - Coba proses lain."
		)
		return

	AudioManager.play_sfx("drop_correct")
	slot.accept_card(card)
	%MainStatusLabel.text = "PESANAN SELESAI"
	%MainInstructionLabel.text = (
        "BENAR - RANTAI BAHAN, PROSES, DAN HASIL SUDAH LENGKAP"
	)
	UIMotion.play_reward(slot)
	UIMotion.play_reward(%TargetResultPanel)
	_set_level4_helper_message(
        "BENAR - Pesanan selesai. Menyiapkan pesanan berikutnya."
	)
	await _complete_current_order()

func _complete_current_order() -> void:
	countdown_controller.pause()
	DurationTracker.pause_active_play()
	set_state("ORDER_SUCCESS_ANIMATION")

	var metric := order_controller.complete_current_order(
		countdown_controller.seconds_left()
	)

	%MainScoreLabel.text = "%d / 60" % order_controller.main_score
	_show_feedback("Pesanan selesai!", true)
	UIMotion.play_reward(%TargetResultPanel)

	AnalyticsLogger.log_event(
		"l4_order_complete",
		{
			"level_session_id": str(
				level_session.get("level_session_id", "")
			),
			"attempt_id": order_controller.attempt_id,
			"order_metric": metric
		}
	)

	await get_tree().create_timer(1.1).timeout

	var orders: Array = level_config.get("orders", [])

	if order_index < orders.size() - 1:
		order_index += 1
		set_state("ORDER_TRANSITION")
		_load_order(order_index)
		DurationTracker.resume_active_play()
		countdown_controller.resume()
		return

	_save_main_attempt_success()
	_show_main_success()

func _save_main_attempt_success() -> void:
	if main_attempt_saved:
		return
	main_attempt_saved = true
	main_score = order_controller.main_score
	var snapshot := order_controller.attempt_snapshot("MAIN_GAME_SUCCESS", countdown_controller.seconds_left())
	snapshot["completed_at"] = Time.get_unix_time_from_system()
	level_session["attempts"].append(snapshot)
	level_session["successful_attempt_id"] = order_controller.attempt_id
	GameState.update_level_session(level_session)

func _show_main_success() -> void:
	countdown_controller.stop()
	DurationTracker.pause_active_play()
	set_state("MAIN_GAME_SUCCESS")
	show_only(screens, main_success_panel)
	%MainSuccessText.text = "SEMUA PESANAN SELESAI!\n4/4 pesanan\nSisa waktu: %s\nMain Game: %d/60" % [_format_seconds(countdown_controller.seconds_left()), main_score]

func _on_countdown_changed(seconds_remaining: int) -> void:
	%CountdownLabel.text = _format_seconds(seconds_remaining)

func _on_warning_30() -> void:
	_show_feedback("Waktu tinggal 30 detik.", false)
	AnalyticsLogger.log_event("l4_timer_warning", {"level_session_id":str(level_session.get("level_session_id", "")), "threshold":30, "attempt_id":order_controller.attempt_id})

func _on_warning_10() -> void:
	var tween := create_tween()
	tween.set_loops(3)
	tween.tween_property(%CountdownLabel, "modulate", Color(1.0, 0.55, 0.40, 1.0), 0.14)
	tween.tween_property(%CountdownLabel, "modulate", Color.WHITE, 0.14)
	AnalyticsLogger.log_event("l4_timer_warning", {"level_session_id":str(level_session.get("level_session_id", "")), "threshold":10, "attempt_id":order_controller.attempt_id})

func _on_timeout() -> void:
	if current_state not in ["MAIN_GAME_PLAYER_CONTROL", "ORDER_SUCCESS_ANIMATION", "ORDER_TRANSITION"]:
		return
	DurationTracker.pause_active_play()
	countdown_controller.stop()
	timeout_count += 1
	level_session["timeout_count"] = timeout_count
	var snapshot := order_controller.attempt_snapshot("TIMEOUT", 0)
	snapshot["completed_at"] = Time.get_unix_time_from_system()
	level_session["attempts"].append(snapshot)
	GameState.update_level_session(level_session)
	set_state("TIMEOUT")
	show_only(screens, timeout_panel)
	%TimeoutText.text = "WAKTU HABIS\nEmpat pesanan belum selesai.\nCoba lagi dan susun bahan dengan lebih teliti.\nTimeout tercatat: %d" % timeout_count
	AnalyticsLogger.log_event("l4_timeout", {
		"level_session_id":str(level_session.get("level_session_id", "")),
		"attempt_id":order_controller.attempt_id,
		"order_index":order_index + 1,
		"timeout_count":timeout_count
	})

func _request_hint() -> void:
	if current_state != "MAIN_GAME_PLAYER_CONTROL":
		return
	order_controller.mark_hint_used()
	AnalyticsLogger.log_event("hint_used", {
		"level_no":4,
		"level_session_id":str(level_session.get("level_session_id", "")),
		"attempt_id":order_controller.attempt_id,
		"order_id":str(order_controller.current_order.get("order_id", ""))
	})
	if not order_controller.current_pair_correct:
		var required := [str(order_controller.current_order.get("ingredient_1_id", "")), str(order_controller.current_order.get("ingredient_2_id", ""))]
		var selected: Array[String] = []
		if ingredient_slot_a.current_card() != null:
			selected.append(ingredient_slot_a.current_card().food_id)
		if ingredient_slot_b.current_card() != null:
			selected.append(ingredient_slot_b.current_card().food_id)
		for child in %CandidateFoodGrid.get_children():
			if child is FoodCard and child.food_id in required and child.food_id not in selected:
				_pulse_control(child)
				_show_feedback("Petunjuk: perhatikan salah satu pangan yang sedang ditandai.", true)
				return
		_show_feedback("Petunjuk: perhatikan kembali dua pangan utama untuk hasil olahan ini.", true)
	else:
		_show_feedback("Petunjuk: perhatikan kembali proses yang menghubungkan bahan dengan hasil olahan.", true)

func _show_literacy_intro() -> void:
	set_state("LITERACY_INTRO")
	show_only(screens, literacy_intro_panel)
	%LiteracyIntroText.text = str(level_config.get("literacy_intro", "Kamu sudah menyelesaikan pesanan. Sekarang coba lengkapi bagian yang hilang dari rantai olahan."))

func _start_literacy() -> void:
	literacy_round_index = 0
	literacy_attempts.clear()
	literacy_score = 0
	literacy_transition_pending = false
	show_only(screens, literacy_hud)
	_render_literacy_round()


func _render_literacy_round() -> void:
	literacy_transition_pending = false
	_clear_container(%LiteracyChainRow)
	_clear_container(%ChoiceGrid)
	%ChallengeFeedback.text = ""

	var rounds: Array = level_config.get("literacy_rounds", [])

	if literacy_round_index < 0 or literacy_round_index >= rounds.size():
		return

	var round_data: Dictionary = rounds[literacy_round_index]
	var round_id := str(round_data.get("round_id", ""))

	if not literacy_attempts.has(round_id):
		literacy_attempts[round_id] = 0

	set_state("LITERACY_R%d" % [literacy_round_index + 1])
	_refresh_literacy_sidebar()

	%LiteracyMissionText.text = (
        "Lengkapi bagian yang kosong pada rantai "
		+ "BAHAN > PROSES > HASIL OLAHAN."
	)
	%LiteracyStatusLabel.text = "PILIH JAWABAN"

	var kind := str(round_data.get("kind", ""))

	match kind:
		"processed_result":
			%LiteracyInstructionLabel.text = (
                "SERET HASIL OLAHAN YANG TEPAT KE BAGIAN YANG KOSONG"
			)
		"food":
			%LiteracyInstructionLabel.text = (
                "SERET BAHAN YANG TEPAT KE BAGIAN YANG KOSONG"
			)
		"process":
			%LiteracyInstructionLabel.text = (
                "SERET PROSES YANG TEPAT KE BAGIAN YANG KOSONG"
			)
		_:
			%LiteracyInstructionLabel.text = (
                "SERET PILIHAN YANG TEPAT"
			)

	var reference_order := _resolve_literacy_reference_order(
		round_data
	)

	if reference_order.is_empty():
		push_error(
            "Level 4 literacy gagal menemukan referensi order."
		)
		return

	_build_literacy_chain(round_data, reference_order)
	_populate_literacy_choices(round_data)
	DurationTracker.resume_active_play()


func _resolve_literacy_reference_order(
	round_data: Dictionary
) -> Dictionary:
	var kind := str(round_data.get("kind", ""))
	var correct_id := str(round_data.get("correct_id", ""))
	var orders: Array = level_config.get("orders", [])

	for order_variant in orders:
		var order_data: Dictionary = order_variant

		match kind:
			"processed_result":
				if str(order_data.get("result_id", "")) == correct_id:
					return order_data
			"food":
				if (
					str(order_data.get("ingredient_1_id", "")) == correct_id
					or str(order_data.get("ingredient_2_id", "")) == correct_id
				):
					return order_data
			"process":
				if str(order_data.get("process_id", "")) == correct_id:
					return order_data

	return {}


func _build_literacy_chain(
	round_data: Dictionary,
	order_data: Dictionary
) -> void:
	var kind := str(round_data.get("kind", ""))
	var correct_id := str(round_data.get("correct_id", ""))
	var ingredient_1_id := str(
		order_data.get("ingredient_1_id", "")
	)
	var ingredient_2_id := str(
		order_data.get("ingredient_2_id", "")
	)
	var process_id := str(order_data.get("process_id", ""))
	var result_id := str(order_data.get("result_id", ""))

	if kind == "food" and ingredient_1_id == correct_id:
		_add_missing_food_chain_slot(round_data)
	else:
		_add_static_food_chain_card(ingredient_1_id)

	_add_literacy_chain_separator("+")

	if kind == "food" and ingredient_2_id == correct_id:
		_add_missing_food_chain_slot(round_data)
	else:
		_add_static_food_chain_card(ingredient_2_id)

	_add_literacy_chain_separator(">")

	if kind == "process":
		_add_missing_named_chain_slot(
			round_data,
			"PROSES ?",
            "process_card"
		)
	else:
		_add_static_process_chain_card(process_id)

	_add_literacy_chain_separator(">")

	if kind == "processed_result":
		_add_missing_named_chain_slot(
			round_data,
			"HASIL ?",
            "processed_food_card"
		)
	else:
		_add_static_processed_chain_card(result_id)


func _add_literacy_chain_separator(text: String) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(38, 0)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override(
		"font_color",
		Color(0.055, 0.36, 0.22, 1)
	)
	%LiteracyChainRow.add_child(label)


func _add_static_food_chain_card(food_id: String) -> void:
	var food: Dictionary = ContentDatabase.get_food(food_id)
	var card: FoodCard = FOOD_CARD_SCENE.instantiate()
	%LiteracyChainRow.add_child(card)
	card.setup(
		food_id,
		str(food.get("display_name", food_id)),
		str(food.get("group_id", "")),
		-1,
		true,
		false,
        "food_card"
	)
	card.set_static_preview()
	card.custom_minimum_size = Vector2(126, 112)


func _add_static_process_chain_card(process_id: String) -> void:
	var process: Dictionary = ContentDatabase.get_process(process_id)
	var card: NamedDragCard = NAMED_CARD_SCENE.instantiate()
	%LiteracyChainRow.add_child(card)
	card.setup(
		process_id,
		str(process.get("display_name", process_id)),
        "process_card"
	)
	card.custom_minimum_size = Vector2(145, 92)
	card.lock_card()


func _add_static_processed_chain_card(processed_id: String) -> void:
	var processed: Dictionary = ContentDatabase.get_processed_food(
		processed_id
	)
	var card: NamedDragCard = NAMED_CARD_SCENE.instantiate()
	%LiteracyChainRow.add_child(card)
	card.setup(
		processed_id,
		str(processed.get("display_name", processed_id)),
        "processed_food_card"
	)
	_decorate_processed_choice_card(card, processed_id)
	card.lock_card()


func _add_missing_food_chain_slot(round_data: Dictionary) -> void:
	var slot: FoodDropSlot = FOOD_DROP_SLOT_SCENE.instantiate()
	%LiteracyChainRow.add_child(slot)
	slot.custom_minimum_size = Vector2(150, 132)
	slot.setup(
		str(round_data.get("correct_id", "")),
        "BAHAN ?"
	)
	slot.drop_received.connect(
		_on_food_literacy_drop.bind(round_data)
	)
	UIMotion.play_pulse(slot, 1.035)


func _add_missing_named_chain_slot(
	round_data: Dictionary,
	title: String,
	drag_kind: String
) -> void:
	var slot: NamedDropSlot = NAMED_SLOT_SCENE.instantiate()
	%LiteracyChainRow.add_child(slot)
	slot.custom_minimum_size = Vector2(155, 118)
	slot.setup(
		str(round_data.get("correct_id", "")),
		title,
		drag_kind,
		true
	)
	slot.drop_received.connect(
		_on_named_literacy_drop.bind(round_data)
	)
	UIMotion.play_pulse(slot, 1.035)


func _populate_literacy_choices(round_data: Dictionary) -> void:
	var ids: Array = round_data.get("choice_ids", []).duplicate()
	ids.shuffle()

	match str(round_data.get("kind", "")):
		"processed_result":
			for item_id_value in ids:
				var item_id := str(item_id_value)
				var processed: Dictionary = (
					ContentDatabase.get_processed_food(item_id)
				)
				var card: NamedDragCard = NAMED_CARD_SCENE.instantiate()
				%ChoiceGrid.add_child(card)
				card.setup(
					item_id,
					str(processed.get("display_name", item_id)),
                    "processed_food_card"
				)
				_decorate_processed_choice_card(card, item_id)
				UIMotion.play_pop(card, 1.025)

		"food":
			for item_id_value in ids:
				var food_id := str(item_id_value)
				var food: Dictionary = ContentDatabase.get_food(food_id)
				var card: FoodCard = FOOD_CARD_SCENE.instantiate()
				%ChoiceGrid.add_child(card)
				card.setup(
					food_id,
					str(food.get("display_name", food_id)),
					str(food.get("group_id", "")),
					-1,
					true,
					false,
                    "food_card"
				)
				card.custom_minimum_size = Vector2(126, 112)
				UIMotion.play_pop(card, 1.025)

		"process":
			for item_id_value in ids:
				var process_id := str(item_id_value)
				var process: Dictionary = ContentDatabase.get_process(
					process_id
				)
				var card: NamedDragCard = NAMED_CARD_SCENE.instantiate()
				%ChoiceGrid.add_child(card)
				card.setup(
					process_id,
					str(process.get("display_name", process_id)),
                    "process_card"
				)
				card.custom_minimum_size = Vector2(170, 78)
				UIMotion.play_pop(card, 1.025)


func _decorate_processed_choice_card(
	card: NamedDragCard,
	processed_id: String
) -> void:
	if card == null:
		return

	var processed: Dictionary = ContentDatabase.get_processed_food(
		processed_id
	)
	var texture_path := str(
		PROCESSED_TEXTURE_PATHS.get(processed_id, "")
	)
	var preview_texture := _load_processed_texture(texture_path)

	card.custom_minimum_size = Vector2(170, 142)

	var title_node := card.get_node_or_null("TitleLabel") as Label

	if title_node != null:
		title_node.visible = false

	var visual := VBoxContainer.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_theme_constant_override("separation", 3)
	card.add_child(visual)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(154, 98)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = preview_texture
	visual.add_child(image)

	var label := Label.new()
	label.text = str(processed.get("display_name", processed_id))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	visual.add_child(label)


func _on_named_literacy_drop(
	item_id: String,
	card: NamedDragCard,
	slot: NamedDropSlot,
	round_data: Dictionary
) -> void:
	if literacy_transition_pending:
		return

	DurationTracker.pause_active_play()

	var correct := item_id == str(round_data.get("correct_id", ""))
	var attempt_no := _register_literacy_attempt(
		round_data,
		item_id,
		correct
	)

	if correct:
		AudioManager.play_sfx("drop_correct")
		slot.accept_card(card)
		_award_literacy_round(attempt_no)
		%LiteracyStatusLabel.text = "BERHASIL"
		%ChallengeFeedback.text = (
            "TEPAT! Rantai bahan, proses, dan hasil sudah lengkap."
		)
		UIMotion.play_reward(slot)
		UIMotion.play_reward(%ChallengeFeedback)
		_schedule_literacy_auto_advance()
		return

	card.show_wrong_feedback()
	UIMotion.play_shake(card, 6.0)
	AudioManager.play_sfx("wrong")
	%ChallengeFeedback.text = (
        "Belum tepat. Perhatikan kembali bagian lain pada rantai."
	)
	DurationTracker.resume_active_play()


func _on_food_literacy_drop(
	food_id: String,
	card: FoodCard,
	slot: FoodDropSlot,
	round_data: Dictionary
) -> void:
	if literacy_transition_pending:
		return

	DurationTracker.pause_active_play()

	var correct := food_id == str(round_data.get("correct_id", ""))
	var attempt_no := _register_literacy_attempt(
		round_data,
		food_id,
		correct
	)

	if correct:
		AudioManager.play_sfx("drop_correct")
		slot.accept_card(card)
		_award_literacy_round(attempt_no)
		%LiteracyStatusLabel.text = "BERHASIL"
		%ChallengeFeedback.text = (
            "TEPAT! Bahan yang hilang sudah melengkapi rantai olahan."
		)
		UIMotion.play_reward(slot)
		UIMotion.play_reward(%ChallengeFeedback)
		_schedule_literacy_auto_advance()
		return

	card.show_wrong_feedback()
	UIMotion.play_shake(card, 6.0)
	AudioManager.play_sfx("wrong")
	%ChallengeFeedback.text = (
        "Belum tepat. Cocokkan bahan dengan proses dan hasil olahan."
	)
	DurationTracker.resume_active_play()

func _register_literacy_attempt(round_data: Dictionary, selected_id: String, correct: bool) -> int:
	var round_id := str(round_data.get("round_id", ""))
	literacy_attempts[round_id] = int(literacy_attempts.get(round_id, 0)) + 1
	var attempt_no := int(literacy_attempts[round_id])
	AnalyticsLogger.log_event("literacy_answer", {
		"level_no":4,
		"level_session_id":str(level_session.get("level_session_id", "")),
		"literacy_round":literacy_round_index + 1,
		"selected_answer":selected_id,
		"correct":correct,
		"attempt_no":attempt_no
	})
	return attempt_no

func _award_literacy_round(attempt_no: int) -> void:
	var scoring: Dictionary = level_config.get("scoring", {})
	literacy_score += (
		int(scoring.get("literacy_first_attempt", 10))
		if attempt_no == 1
		else int(scoring.get("literacy_after_retry", 5))
	)
	_refresh_literacy_sidebar()


func _refresh_literacy_sidebar() -> void:
	var rounds: Array = level_config.get("literacy_rounds", [])
	%LiteracyScoreLabel.text = "%d / 30" % literacy_score
	%LiteracyRoundLabel.text = "%d / %d" % [
		literacy_round_index + 1,
		rounds.size()
	]


func _schedule_literacy_auto_advance() -> void:
	if literacy_transition_pending:
		return

	literacy_transition_pending = true
	%LiteracyStatusLabel.text = "LANJUT OTOMATIS..."

	var transition_timer := get_tree().create_timer(1.8)
	transition_timer.timeout.connect(
		_on_literacy_auto_advance_timeout
	)


func _on_literacy_auto_advance_timeout() -> void:
	if not literacy_transition_pending:
		return

	if not literacy_hud.visible:
		literacy_transition_pending = false
		return

	literacy_transition_pending = false
	_advance_literacy()


func _advance_literacy() -> void:
	if literacy_round_index < 2:
		literacy_round_index += 1
		_render_literacy_round()
		return

	_show_result()

func _show_result() -> void:
	set_state("RESULT")
	var duration_ms := DurationTracker.finish_level_session()
	final_score = main_score + literacy_score + int(level_config.get("scoring", {}).get("completion", 10))
	level_session["active_duration_ms"] = duration_ms
	level_session["completed_at"] = Time.get_unix_time_from_system()
	GameState.update_level_session(level_session)
	show_only(screens, result_panel)
	%ResultScore.text = "%d / 100" % final_score
	%ResultSummary.text = "Pesanan selesai: 4/4\nTantangan Literasi: 3/3 ronde\nTimeout: %d\nDurasi aktif: %s" % [timeout_count, _format_ms(duration_ms)]

func _show_info() -> void:
	set_state("PROCESS_INFO")
	info_index = 0
	show_only(screens, info_panel)
	_render_info()

func _render_info() -> void:
	if processed_foods.is_empty():
		return
	var item: Dictionary = processed_foods[info_index]
	var processed_id: String = str(item.get("processed_food_id", ""))
	var processed_texture_path: String = str(PROCESSED_TEXTURE_PATHS.get(processed_id, ""))
	%InfoProcessedImage.texture = _load_processed_texture(processed_texture_path)
	%InfoTitle.text = str(item.get("display_name", ""))
	%InfoIngredients.text = "%s + %s" % [str(item.get("ingredient_a_name", "")), str(item.get("ingredient_b_name", ""))]
	%InfoProcess.text = "Proses sederhana: %s" % str(item.get("process_name", ""))
	%InfoText.text = str(item.get("info_level_04", ""))
	%InfoDisclaimer.text = str(level_config.get("information_disclaimer", ""))
	%InfoCounter.text = "%d / %d" % [info_index + 1, processed_foods.size()]
	%InfoNextButton.text = "LANJUT" if info_index < processed_foods.size()-1 else "SELESAI"

func _advance_info() -> void:
	if info_index < processed_foods.size()-1:
		info_index += 1
		_render_info()
	else:
		_show_badge()

func _show_badge() -> void:
	set_state("BADGE_REWARD")
	show_only(screens, badge_panel)
	var badge: Dictionary = level_config.get("badge", {})
	%BadgeName.text = str(badge.get("display_name", ""))
	%BadgeDescription.text = str(badge.get("description", ""))

func _show_closing() -> void:
	set_state("CLOSING_DIALOGUE")
	show_only(screens, closing_panel)
	closing_index = 0
	_render_closing_line()

func _render_closing_line() -> void:
	var lines: Array = level_config.get("dialogue", {}).get("closing", [])
	var line: Dictionary = lines[closing_index]
	%ClosingSpeaker.text = str(line.get("speaker", ""))
	_set_dialogue_speaker(%ClosingSpeaker.text)
	%ClosingText.text = str(line.get("text", ""))
	%ClosingNextButton.text = "KEMBALI KE PETA" if closing_index == lines.size()-1 else "LANJUT"

func _advance_closing() -> void:
	var lines: Array = level_config.get("dialogue", {}).get("closing", [])
	if closing_index < lines.size()-1:
		closing_index += 1
		_render_closing_line()
	else:
		_finish_level()

func _finish_level() -> void:
	set_state("LEVEL_COMPLETE")
	var duration_ms := int(level_session.get("active_duration_ms", DurationTracker.current_active_ms()))
	var badge: Dictionary = level_config.get("badge", {})
	GameState.complete_level(4, final_score, duration_ms, str(badge.get("badge_id", "badge_level_04")), str(badge.get("display_name", "Peracik Pangan Lokal")), str(level_session.get("level_session_id", "")))
	SceneRouter.goto("main_map")

func _show_feedback(text: String, correct: bool) -> void:
	feedback_toast.text = text
	feedback_toast.modulate = (
		Color(0.76, 1.0, 0.78, 1.0)
		if correct
		else Color(1.0, 0.86, 0.72, 1.0)
	)
	feedback_toast.visible = true

	if correct:
		UIMotion.play_pop(feedback_toast, 1.035)
	else:
		UIMotion.play_shake(feedback_toast, 5.0)

	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_callback(
		func():
			if is_instance_valid(feedback_toast):
				feedback_toast.visible = false
	)

func _pulse_control(control: Control) -> void:
	var tween := create_tween()
	tween.set_loops(2)
	tween.tween_property(control, "modulate", Color(1.0, 0.91, 0.52, 1.0), 0.18)
	tween.tween_property(control, "modulate", Color.WHITE, 0.18)

func _load_processed_texture(texture_path: String) -> Texture2D:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	var loaded_resource: Resource = load(texture_path)
	return loaded_resource if loaded_resource is Texture2D else null

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()

func _format_seconds(seconds: int) -> String:
	return "%02d:%02d" % [int(seconds / 60.0), seconds % 60]

func _format_ms(ms: int) -> String:
	var total_seconds := int(round(ms / 1000.0))
	return "%02d:%02d" % [int(total_seconds / 60.0), total_seconds % 60]

func _ensure_level_runtime_ready() -> bool:
	if not ContentDatabase.initialize():
		push_error("Level 4 gagal menginisialisasi ContentDatabase.")
		return false

	SettingsManager.initialize()

	if not GameState.initialized:
		GameState.initialize()

	AnalyticsLogger.initialize()
	return true
