extends LevelFlowController

const FOOD_SLOT_SCENE := preload("res://scenes/shared/festival_food_slot.tscn")
const BASKET_SLOT_SCENE := preload("res://scenes/shared/festival_basket_slot.tscn")

const V3_MAIN_GAME_ID: String = "L5-G01"
const V3_MAIN_GAME_TYPE: String = "festival_pangan_lokal"
const V3_MAIN_INSTRUCTION_ID: String = "INST-L5-G01-FESTIVAL"
const V3_MAIN_INSTRUCTION_TEXT: String = "Selesaikan empat skema Festival Pangan Lokal dengan satu Main Timer."

const V3_QUIZ_GAME_ID: String = "L5-G02"
const V3_QUIZ_GAME_TYPE: String = "literacy_question"
const V3_QUIZ_INSTRUCTION_ID: String = "INST-L5-G02-QUIZ"
const V3_QUIZ_INSTRUCTION_TEXT: String = "Jawab lima pertanyaan Uji Literasi Pangan dengan waktu 30 detik per pertanyaan."
@onready var theme_panel: Control = %ThemePanel
@onready var dialogue_panel: Control = %DialoguePanel
@onready var tutorial_panel: Control = %TutorialPanel
@onready var ready_panel: Control = %ReadyPanel
@onready var main_game_hud: Control = %MainGameHUD
@onready var main_result_panel: Control = %MainResultPanel
@onready var literacy_intro_panel: Control = %LiteracyIntroPanel
@onready var quiz_hud: Control = %QuizHUD
@onready var final_result_panel: Control = %FinalResultPanel
@onready var gallery_panel: Control = %GalleryPanel
@onready var badge_panel: Control = %BadgePanel
@onready var closing_panel: Control = %ClosingPanel
@onready var final_map_panel: Control = %FinalMapPanel
@onready var moving_lane: MovingLaneController = %MovingLaneController
@onready var schema_controller: FestivalSchemaController = %SchemaController
@onready var main_timer: FestivalMainTimerController = %MainTimerController
@onready var quiz_controller: FestivalQuizController = %QuizController
@onready var question_timer: QuestionTimerController = %QuestionTimerController

var screens: Array[Control] = []
var config: Dictionary = {}
var level_session: Dictionary = {}
var attempt_id := ""
var dialogue_lines: Array = []
var dialogue_index := 0
var schema_index := 0
var schema1_targets: Array = []
var schema1_target_index := 0
var schema2_completed_groups: Dictionary = {}
var schema3_selected: Dictionary = {}
var schema3_total_coin := 0
var schema4_targets: Array = []
var schema4_target_index := 0
var schema4_slots: Array[FestivalFoodSlot] = []
var main_game_score := 0
var time_bonus := 0
var quiz_score := 0
var final_score := 0
var active_duration_ms := 0
var final_saved := false
var closing_index := 0
var main_game_start_active_ms: int = -1
var quiz_game_start_active_ms: int = -1

func _ready() -> void:
    if not _ensure_level_runtime_ready():
        return
    set_meta("level_no", 5)
    _prepare_level_presentation()
    config = ContentDatabase.get_level_05_config()
    screens = [theme_panel, dialogue_panel, tutorial_panel, ready_panel, main_game_hud, main_result_panel, literacy_intro_panel, quiz_hud, final_result_panel, gallery_panel, badge_panel, closing_panel, final_map_panel]
    moving_lane.attach(%MovingLaneTop, %MovingLaneBottom)
    moving_lane.configure(config.get("bank_food_ids", []), float(config.get("lane", {}).get("speed_logical_px_per_second", 72)))
    schema_controller.configure(config.get("schemas", []))
    main_timer.configure(int(config.get("main_timer_seconds", 240)))
    quiz_controller.configure(config.get("quiz", {}))
    question_timer.configure(int(config.get("quiz", {}).get("seconds_per_question", 30)))
    _connect_ui()
    _show_theme()

func _connect_ui() -> void:
    %ThemeStartButton.pressed.connect(_show_opening_dialogue)
    %DialogueNextButton.pressed.connect(_on_dialogue_next)
    %TutorialContinueButton.pressed.connect(_show_ready)
    %TutorialSkipButton.pressed.connect(_show_ready)
    %FestivalStartButton.pressed.connect(_start_main_game)
    %MainResultNextButton.pressed.connect(_show_literacy_intro)
    %QuizStartButton.pressed.connect(_start_quiz)
    %QuizNextButton.pressed.connect(_advance_quiz)
    %FinalResultNextButton.pressed.connect(_show_gallery)
    %GalleryNextButton.pressed.connect(_show_badge)
    %BadgeNextButton.pressed.connect(_show_closing)
    %ClosingNextButton.pressed.connect(_advance_closing)
    %FinalReplayButton.pressed.connect(_finish_completed_journey.bind("player_setup"))
    %FinalMenuButton.pressed.connect(_finish_completed_journey.bind("main_menu"))
    main_timer.time_changed.connect(_on_main_time_changed)
    main_timer.warning_30.connect(_on_main_warning_30)
    main_timer.expired.connect(_on_main_timer_expired)
    question_timer.time_changed.connect(func(seconds: int): %QuestionTimerLabel.text = _format_seconds(seconds))
    question_timer.timeout.connect(_on_question_timeout)
    var answer_buttons := [%AnswerA, %AnswerB, %AnswerC, %AnswerD]
    for i in range(answer_buttons.size()):
        answer_buttons[i].pressed.connect(_on_answer_pressed.bind(i))

func _show_theme() -> void:
    set_state("THEME_INTRO")
    show_only(screens, theme_panel)

func _show_opening_dialogue() -> void:
    set_state("DIALOGUE_OPENING")
    dialogue_lines = config.get("dialogue", {}).get("opening", [])
    dialogue_index = 0
    show_only(screens, dialogue_panel)
    _render_dialogue()

func _on_dialogue_next() -> void:
    dialogue_index += 1
    if dialogue_index < dialogue_lines.size():
        _render_dialogue()
        return
    if current_state == "DIALOGUE_OPENING":
        set_state("DIALOGUE_MISSION")
        dialogue_lines = config.get("dialogue", {}).get("mission", [])
        dialogue_index = 0
        _render_dialogue()
        return
    _show_tutorial()

func _render_dialogue() -> void:
    if dialogue_lines.is_empty():
        return
    var line: Dictionary = dialogue_lines[dialogue_index]
    %SpeakerLabel.text = str(line.get("speaker", ""))
    _set_dialogue_speaker(%SpeakerLabel.text)
    %DialogueText.text = str(line.get("text", ""))
    %DialogueNextButton.text = "SIAP" if current_state == "DIALOGUE_MISSION" and dialogue_index == dialogue_lines.size() - 1 else "LANJUT"

func _show_tutorial() -> void:
    set_state("TUTORIAL_FINAL")
    show_only(screens, tutorial_panel)
    %TutorialTitle.text = str(config.get("tutorial", {}).get("title", "TUTORIAL FINAL"))
    %TutorialText.text = str(config.get("tutorial", {}).get("text", ""))
    %TutorialTimerLabel.text = _format_seconds(int(config.get("main_timer_seconds", 240))) + " (belum berjalan)"
    %TutorialSkipButton.visible = bool(SettingsManager.get_flag(str(config.get("tutorial_flag_key", "level_05_tutorial_seen")), false))

func _show_ready() -> void:
    SettingsManager.set_flag(str(config.get("tutorial_flag_key", "level_05_tutorial_seen")), true)
    set_state("READY_FESTIVAL")
    show_only(screens, ready_panel)
    %ReadyText.text = "Empat skema menggunakan satu Main Timer.\nWaktu habis tidak menghentikan permainan."

func _start_main_game() -> void:
    level_session = GameState.begin_level_session(5)
    attempt_id = IdUtil.uuid_v4()
    level_session["attempts"] = []
    DurationTracker.begin_level_session(
        str(
            level_session.get(
                "level_session_id",
                ""
            )
        ),
        5
    )
    DurationTracker.resume_active_play()
    main_game_start_active_ms = DurationTracker.current_active_ms()

    if not TelemetryManager.begin_game(
        5,
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
            "Telemetry v3 Level 5 Game 1 belum dapat memulai game."
        )

    schema_controller.reset()
    schema_index = 0
    main_game_score = 0
    time_bonus = 0
    schema1_targets.clear()
    schema2_completed_groups.clear()
    schema3_selected.clear()
    schema3_total_coin = 0
    schema4_targets.clear()
    final_saved = false
    moving_lane.build_assignment()
    moving_lane.set_coin_visible(false)
    moving_lane.start()
    main_timer.start()
    show_only(screens, main_game_hud)

    AnalyticsLogger.log_event(
        "level_main_started",
        {
            "level_session_id": str(
                level_session.get(
                    "level_session_id",
                    ""
                )
            ),
            "attempt_id": attempt_id,
            "level_no": 5,
            "main_timer_initial": int(
                config.get(
                    "main_timer_seconds",
                    240
                )
            ),
            "lane_assignment": moving_lane.assignment_snapshot(),
            "content_version": ContentDatabase.content_version
        }
    )

    _load_schema(0)

func _load_schema(index: int) -> void:
    schema_index = index
    var schemas: Array = config.get("schemas", [])

    if index < 0 or index >= schemas.size():
        return

    _clear_container(%SchemaMissionContent)
    %ProcessChoiceRow.visible = false
    %SchemaFeedback.text = ""
    %SchemaDetailLabel.text = ""

    var data: Dictionary = schemas[index]
    var schema_id: String = str(
        data.get(
            "schema_id",
            ""
        )
    )
    %SchemaLabel.text = "SKEMA %d/4\n%s" % [
        index + 1,
        str(data.get("name", "")).to_upper()
    ]
    %SchemaProgress.text = ""
    set_state("SCHEMA_%d" % [index + 1])
    moving_lane.set_coin_visible(index == 2)

    match index:
        0:
            %SchemaInstructionLabel.text = "CARI PANGAN TARGET"
            _setup_schema1(data)
        1:
            %SchemaInstructionLabel.text = "ISI 4 KELOMPOK PANGAN"
            _setup_schema2(data)
        2:
            %SchemaInstructionLabel.text = "BELANJA 4 PANGAN"
            %SchemaDetailLabel.text = "1 dari setiap kelompok\nMaksimal 15 Koin Pangan"
            _setup_schema3(data)
        3:
            %SchemaInstructionLabel.text = "LENGKAPI 2 OLAHAN PANGAN"
            _setup_schema4(data)

    _begin_l5_schema_occurrence(schema_id)

func _setup_schema1(data: Dictionary) -> void:
    if schema1_targets.is_empty():
        schema1_targets = data.get("target_pool_ids", []).duplicate()
        schema1_targets.shuffle()
        schema1_targets = schema1_targets.slice(0, int(data.get("target_count", 3)))
    schema1_target_index = 0
    _render_schema1_target()

func _render_schema1_target() -> void:
    _clear_container(%SchemaMissionContent)
    var food_id := str(schema1_targets[schema1_target_index])
    var food := ContentDatabase.get_food(food_id)
    var target_name := Label.new()
    target_name.name = "TargetNameDynamic"
    target_name.text = str(food.get("display_name", food_id)).to_upper()
    target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    target_name.add_theme_font_size_override("font_size", 24)
    %SchemaMissionContent.add_child(target_name)
    var holder := CenterContainer.new()
    holder.custom_minimum_size = Vector2(0, 116)
    %SchemaMissionContent.add_child(holder)
    var slot: FestivalFoodSlot = FOOD_SLOT_SCENE.instantiate()
    holder.add_child(slot)
    slot.setup("TARGET %d/3" % [schema1_target_index + 1])
    slot.drop_received.connect(_on_schema1_drop.bind(food_id, slot))
    %SchemaProgress.text = "TARGET %d/3" % [schema1_target_index + 1]

func _on_schema1_drop(food_id: String, card: FoodCard, _slot: FestivalFoodSlot, target_id: String, __slot_ref: FestivalFoodSlot) -> void:
    if food_id != target_id:
        _register_invalid("schema_1", "wrong_target_drop", food_id)
        card.show_wrong_feedback()
        _feedback("Belum tepat. Cari pangan yang sesuai dengan nama target.", false)
        return
    AudioManager.play_sfx("drop_correct")
    moving_lane.hold_card(card, %HeldPool)
    schema1_target_index += 1
    if schema1_target_index >= schema1_targets.size():
        _complete_schema("schema_1")
    else:
        _feedback("Tepat! Lanjut ke target berikutnya.", true)
        _render_schema1_target()

func _setup_schema2(data: Dictionary) -> void:
    schema2_completed_groups.clear()
    var row := HBoxContainer.new()
    row.name = "GroupTargetsDynamic"
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    %SchemaMissionContent.add_child(row)
    for gid_value in data.get("group_ids", []):
        var gid := str(gid_value)
        var slot: FestivalFoodSlot = FOOD_SLOT_SCENE.instantiate()
        row.add_child(slot)
        slot.custom_minimum_size.x = 145
        slot.setup(ContentDatabase.get_group_name(gid))
        slot.drop_received.connect(_on_schema2_drop.bind(gid, slot))
    %SchemaProgress.text = "KELOMPOK 0/4"

func _on_schema2_drop(food_id: String, card: FoodCard, _emitter_slot: FestivalFoodSlot, group_id: String, slot: FestivalFoodSlot) -> void:
    var food := ContentDatabase.get_food(food_id)
    if str(food.get("group_id", "")) != group_id:
        _register_invalid("schema_2", "wrong_group_drop", food_id)
        card.show_wrong_feedback()
        _feedback("Belum sesuai dengan kelompok ini. Coba perhatikan kembali jenis pangannya.", false)
        return
    if schema2_completed_groups.has(group_id):
        return
    AudioManager.play_sfx("drop_correct")
    slot.hold_card(card)
    schema2_completed_groups[group_id] = food_id
    %SchemaProgress.text = "Kelompok %d/4" % schema2_completed_groups.size()
    if schema2_completed_groups.size() >= 4:
        _complete_schema("schema_2")
    else:
        _feedback("Kelompok terisi dengan tepat.", true)

func _setup_schema3(_data: Dictionary) -> void:
    schema3_selected.clear()
    schema3_total_coin = 0
    var basket := HBoxContainer.new()
    basket.name = "ShopBasketDynamic"
    basket.alignment = BoxContainer.ALIGNMENT_CENTER
    basket.add_theme_constant_override("separation", 8)
    %SchemaMissionContent.add_child(basket)
    for i in range(4):
        var slot: FestivalBasketSlot = BASKET_SLOT_SCENE.instantiate()
        basket.add_child(slot)
        slot.setup("SLOT %d" % [i + 1])
        slot.drop_received.connect(_on_schema3_drop)
        slot.return_requested.connect(_on_schema3_return)
    _refresh_schema3_ui()

func _on_schema3_drop(food_id: String, card: FoodCard, slot: FestivalBasketSlot) -> void:
    var food := ContentDatabase.get_food(food_id)
    var group_id := str(food.get("group_id", ""))
    if schema3_selected.has(group_id):
        _register_invalid("schema_3", "duplicate_group_drop", food_id)
        card.show_wrong_feedback()
        _feedback("Kelompok ini sudah terisi. Pilih pangan dari kelompok lain.", false)
        return
    var coin := int(food.get("coin_value", 0))
    if schema3_total_coin + coin > int(config.get("schemas", [])[2].get("coin_budget", 15)):
        _register_invalid("schema_3", "insufficient_coin_drop", food_id)
        card.show_wrong_feedback()
        _feedback("Koin Pangan tidak cukup untuk pilihan ini. Coba pertimbangkan pilihan lain.", false)
        return
    AudioManager.play_sfx("drop_correct")
    slot.hold_card(card)
    schema3_selected[group_id] = {"food_id":food_id,"coin":coin,"slot":slot}
    schema3_total_coin += coin
    _refresh_schema3_ui()
    if schema3_selected.size() == 4:
        _complete_schema("schema_3")

func _on_schema3_return(slot: FestivalBasketSlot) -> void:
    var card := slot.release_card()
    if card == null:
        return
    var group_id := card.group_id
    var info: Dictionary = schema3_selected.get(group_id, {})
    schema3_total_coin -= int(info.get("coin", card.coin_value))
    schema3_selected.erase(group_id)
    moving_lane.return_card(card)
    _refresh_schema3_ui()

func _refresh_schema3_ui() -> void:
    %SchemaProgress.text = "KERANJANG %d/4 • %d/15 KOIN" % [
        schema3_selected.size(),
        schema3_total_coin
    ]
    var groups := [
        "group_staple_root",
        "group_vegetable",
        "group_fruit",
        "group_fishery"
    ]
    var parts: Array[String] = []

    for gid in groups:
        parts.append(
            ("✓ " if schema3_selected.has(gid) else "□ ")
            + ContentDatabase.get_group_name(gid)
        )

    %SchemaDetailLabel.text = "\n".join(parts)

func _setup_schema4(data: Dictionary) -> void:
    if schema4_targets.is_empty():
        schema4_targets = data.get("processed_pool_ids", []).duplicate()
        schema4_targets.shuffle()
        schema4_targets = schema4_targets.slice(0, int(data.get("processed_target_count", 2)))
    schema4_target_index = 0
    _render_schema4_target()

func _render_schema4_target() -> void:
    _clear_container(%SchemaMissionContent)
    %ProcessChoiceRow.visible = false
    schema4_slots.clear()
    var processed_id := str(schema4_targets[schema4_target_index])
    var processed := ContentDatabase.get_processed_food(processed_id)
    var label := Label.new()
    label.name = "ProcessedTargetDynamic"
    label.text = "OLAHAN %d/2\n%s" % [
        schema4_target_index + 1,
        str(processed.get("display_name", processed_id)).to_upper()
    ]
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 20)
    %SchemaMissionContent.add_child(label)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    %SchemaMissionContent.add_child(row)
    for title in ["BAHAN 1", "BAHAN 2"]:
        var slot: FestivalFoodSlot = FOOD_SLOT_SCENE.instantiate()
        row.add_child(slot)
        slot.setup(title)
        slot.drop_received.connect(_on_schema4_ingredient_drop.bind(slot))
        schema4_slots.append(slot)
    %SchemaProgress.text = "OLAHAN %d/2" % [schema4_target_index + 1]

func _on_schema4_ingredient_drop(_food_id: String, card: FoodCard, _emitter: FestivalFoodSlot, slot: FestivalFoodSlot) -> void:
    slot.hold_card(card)
    if schema4_slots[0].current_card() == null or schema4_slots[1].current_card() == null:
        return
    var target := ContentDatabase.get_processed_food(str(schema4_targets[schema4_target_index]))
    var selected := [schema4_slots[0].current_card().food_id, schema4_slots[1].current_card().food_id]
    selected.sort()
    var required := [str(target.get("ingredient_a_id", "")), str(target.get("ingredient_b_id", ""))]
    required.sort()
    if selected != required:
        _register_invalid("schema_4", "wrong_pair_validation", str(selected))
        _feedback("Kombinasi bahan belum sesuai dengan hasil olahan.", false)
        for s in schema4_slots:
            var wrong := s.release_card()
            if wrong != null:
                wrong.show_wrong_feedback()
                moving_lane.return_card(wrong)
        return
    AudioManager.play_sfx("drop_correct")
    _feedback("Dua bahan sudah tepat. Pilih prosesnya.", true)
    _render_schema4_process_choices(target)

func _render_schema4_process_choices(target: Dictionary) -> void:
    _clear_container(%ProcessChoiceRow)
    %ProcessChoiceRow.visible = true
    var ids: Array = config.get("schemas", [])[3].get("process_choice_ids", []).duplicate()
    ids.shuffle()
    for pid_value in ids:
        var pid := str(pid_value)
        var button := Button.new()
        button.custom_minimum_size = Vector2(160, 44)
        button.text = ContentDatabase.get_process_name(pid)
        button.pressed.connect(_on_schema4_process.bind(pid, str(target.get("process_id", ""))))
        %ProcessChoiceRow.add_child(button)
        UIMotion.bind_button(button)
        UIMotion.play_pop(button, 1.02)

func _on_schema4_process(process_id: String, correct_id: String) -> void:
    if process_id != correct_id:
        _register_invalid("schema_4", "wrong_process_drop", process_id)
        _feedback("Prosesnya belum tepat. Perhatikan kembali hubungan bahan dan hasil olahan.", false)
        return
    for slot in schema4_slots:
        var card := slot.release_card()
        if card != null:
            moving_lane.hold_card(card, %HeldPool)
    schema4_target_index += 1
    if schema4_target_index >= schema4_targets.size():
        _complete_schema("schema_4")
    else:
        _feedback("Olahan pertama selesai. Lanjut ke olahan berikutnya.", true)
        _render_schema4_target()

func _register_invalid(
    schema_id: String,
    event_type: String,
    item_id: String
) -> void:
    AudioManager.play_sfx("wrong")

    var score_now := schema_controller.register_invalid(
        schema_id,
        event_type,
        {
            "item_id": item_id,
            "timer_remaining": main_timer.seconds_left()
        }
    )
    var selected_answer_id: String = (
        event_type
        + ":"
        + item_id
    )
    var correct_answer_id: String = (
        schema_id
        + ":complete"
    )
    var completed_score_before: int = (
        _l5_completed_schema_score_before(
            schema_id
        )
    )

    if not TelemetryManager.record_mechanic_interaction(
        5,
        V3_MAIN_GAME_ID,
        V3_MAIN_GAME_TYPE,
        selected_answer_id,
        correct_answer_id,
        completed_score_before
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 1 belum dapat merekam invalid mechanic interaction."
        )

    _begin_l5_schema_occurrence(schema_id)

    AnalyticsLogger.log_event(
        "l5_invalid_event",
        {
            "level_session_id": str(
                level_session.get(
                    "level_session_id",
                    ""
                )
            ),
            "attempt_id": attempt_id,
            "schema_id": schema_id,
            "event_type": event_type,
            "item_id": item_id,
            "timer_remaining": main_timer.seconds_left(),
            "schema_score_now": score_now
        }
    )

func _complete_schema(schema_id: String) -> void:
    var score_now := schema_controller.complete_schema(
        schema_id
    )
    var completed_score_before: int = (
        _l5_completed_schema_score_before(
            schema_id
        )
    )
    var current_score: int = (
        completed_score_before
        + score_now
    )
    var completion_answer_id: String = (
        schema_id
        + ":complete"
    )

    if not TelemetryManager.record_mechanic_interaction(
        5,
        V3_MAIN_GAME_ID,
        V3_MAIN_GAME_TYPE,
        completion_answer_id,
        completion_answer_id,
        current_score
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 1 belum dapat merekam penyelesaian mechanic skema."
        )

    AnalyticsLogger.log_event(
        "l5_schema_complete",
        {
            "level_session_id": str(
                level_session.get(
                    "level_session_id",
                    ""
                )
            ),
            "schema_id": schema_id,
            "schema_score": score_now,
            "timer_remaining": main_timer.seconds_left()
        }
    )

    moving_lane.return_all_held()
    UIMotion.play_reward(%MissionArea)
    await get_tree().create_timer(0.35).timeout

    if schema_index < 3:
        _load_schema(schema_index + 1)
    else:
        _complete_main_game()

func _complete_main_game() -> void:
    main_timer.stop()
    moving_lane.stop()
    moving_lane.return_all_held()
    DurationTracker.pause_active_play()
    main_game_score = schema_controller.total_accuracy_score()
    time_bonus = _calculate_time_bonus()
    main_game_score += time_bonus

    var main_game_duration_ms: int = 0

    if main_game_start_active_ms >= 0:
        main_game_duration_ms = maxi(
            0,
            DurationTracker.current_active_ms()
            - main_game_start_active_ms
        )

    if not TelemetryManager.complete_game(
        5,
        V3_MAIN_GAME_ID,
        V3_MAIN_GAME_TYPE,
        main_game_score,
        main_game_duration_ms
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 1 belum dapat menyelesaikan game."
        )

    var attempt_snapshot := {
        "attempt_id": attempt_id,
        "attempt_index": 1,
        "status": "MAIN_GAME_SUCCESS",
        "schema": schema_controller.snapshot(),
        "main_timer_initial": int(
            config.get(
                "main_timer_seconds",
                240
            )
        ),
        "main_timer_remaining": main_timer.seconds_left(),
        "main_timer_expired": main_timer.is_expired,
        "time_bonus": time_bonus,
        "main_game_score": main_game_score,
        "lane_assignment": moving_lane.assignment_snapshot(),
        "completed_at": Time.get_unix_time_from_system()
    }
    level_session["attempts"].append(attempt_snapshot)
    level_session["successful_attempt_id"] = attempt_id
    GameState.update_level_session(level_session)
    set_state("MAIN_GAME_COMPLETE")
    show_only(screens, main_result_panel)

    var snap: Dictionary = schema_controller.snapshot()
    var scores: Dictionary = snap.get("scores", {})

    %MainResultText.text = (
        "MAIN GAME SELESAI\n"
        + "Skema 1: %d/10\n" % int(scores.get("schema_1", 0))
        + "Skema 2: %d/12\n" % int(scores.get("schema_2", 0))
        + "Skema 3: %d/13\n" % int(scores.get("schema_3", 0))
        + "Skema 4: %d/15\n" % int(scores.get("schema_4", 0))
        + "Bonus waktu: %d/10\n" % time_bonus
        + "Main Game: %d/60\n" % main_game_score
        + "Sisa waktu: %s%s" % [
            _format_seconds(main_timer.seconds_left()),
            (
                " - Bonus waktu habis"
                if main_timer.is_expired
                else ""
            )
        ]
    )

func _calculate_time_bonus() -> int:
    var ratio := main_timer.remaining_ratio()
    for band in config.get("time_bonus_bands", []):
        if ratio >= float(band.get("min_remaining_ratio", 0.0)):
            return int(band.get("bonus", 0))
    return 0

func _on_main_time_changed(seconds: int) -> void:
    %MainCountdownLabel.text = _format_seconds(seconds)

func _on_main_warning_30() -> void:
    _feedback("Waktu tinggal 30 detik.", false)
    AnalyticsLogger.log_event("l5_timer_warning", {"level_session_id":str(level_session.get("level_session_id", "")),"threshold":30,"schema_index":schema_index+1})

func _on_main_timer_expired() -> void:
    %MainCountdownLabel.text = "00:00"
    _feedback("Bonus waktu habis. Permainan tetap lanjut sampai Skema 4 selesai.", false)
    AnalyticsLogger.log_event("l5_main_timer_expired", {"level_session_id":str(level_session.get("level_session_id", "")),"schema_id":"schema_%d" % [schema_index+1]})

func _l5_schema_data(schema_id: String) -> Dictionary:
    for schema_value in config.get("schemas", []):
        if not schema_value is Dictionary:
            continue

        var schema_data: Dictionary = schema_value

        if str(
            schema_data.get(
                "schema_id",
                ""
            )
        ) == schema_id:
            return schema_data

    return {}


func _l5_completed_schema_score_before(
    schema_id: String
) -> int:
    var total: int = 0

    for schema_value in config.get("schemas", []):
        if not schema_value is Dictionary:
            continue

        var schema_data: Dictionary = schema_value
        var current_schema_id: String = str(
            schema_data.get(
                "schema_id",
                ""
            )
        )

        if current_schema_id == schema_id:
            break

        total += schema_controller.schema_score(
            current_schema_id
        )

    return total


func _build_l5_schema_options(
    schema_id: String
) -> Array:
    var output: Array = []
    var display_order: int = 0

    for food_value in config.get(
        "bank_food_ids",
        []
    ):
        var food_id: String = str(food_value)
        var food: Dictionary = ContentDatabase.get_food(
            food_id
        )
        display_order += 1
        output.append(
            {
                "answer_id": food_id,
                "text_snapshot": str(
                    food.get(
                        "display_name",
                        food_id
                    )
                ),
                "display_order": display_order
            }
        )

    if schema_id == "schema_4":
        var schema_data: Dictionary = _l5_schema_data(
            schema_id
        )

        for process_value in schema_data.get(
            "process_choice_ids",
            []
        ):
            var process_id: String = str(
                process_value
            )
            display_order += 1
            output.append(
                {
                    "answer_id": process_id,
                    "text_snapshot": ContentDatabase.get_process_name(
                        process_id
                    ),
                    "display_order": display_order
                }
            )

    display_order += 1
    output.append(
        {
            "answer_id": schema_id + ":complete",
            "text_snapshot": "Skema selesai",
            "display_order": display_order
        }
    )

    return output


func _begin_l5_schema_occurrence(
    schema_id: String
) -> void:
    if schema_id.strip_edges().is_empty():
        push_warning(
            "Telemetry v3 Level 5 Game 1 tidak memiliki schema_id."
        )
        return

    var occurrence_id: String = (
        TelemetryManager.begin_mechanic_occurrence(
            5,
            V3_MAIN_GAME_ID,
            V3_MAIN_GAME_TYPE,
            schema_id,
            schema_index + 1,
            "festival_schema",
            _build_l5_schema_options(
                schema_id
            )
        )
    )

    if occurrence_id.is_empty():
        push_warning(
            "Telemetry v3 Level 5 Game 1 belum dapat membuka mechanic occurrence skema."
        )

func _build_l5_quiz_options(
    answers: Array
) -> Array:
    var output: Array = []
    var display_order: int = 0

    for answer_value in answers:
        if not answer_value is Dictionary:
            continue

        var answer_data: Dictionary = answer_value
        display_order += 1
        output.append(
            {
                "answer_id": str(
                    answer_data.get(
                        "answer_id",
                        ""
                    )
                ),
                "text_snapshot": str(
                    answer_data.get(
                        "text",
                        ""
                    )
                ),
                "display_order": display_order
            }
        )

    return output


func _begin_l5_quiz_occurrence(
    question: Dictionary,
    answers: Array,
    question_order: int
) -> void:
    var question_id: String = str(
        question.get(
            "question_id",
            ""
        )
    ).strip_edges()

    if question_id.is_empty():
        push_warning(
            "Telemetry v3 Level 5 Game 2 tidak memiliki question_id."
        )
        return

    var occurrence_id: String = (
        TelemetryManager.begin_question_occurrence(
            5,
            V3_QUIZ_GAME_ID,
            V3_QUIZ_GAME_TYPE,
            question_id,
            question_order,
            1,
            _build_l5_quiz_options(
                answers
            )
        )
    )

    if occurrence_id.is_empty():
        push_warning(
            "Telemetry v3 Level 5 Game 2 belum dapat membuka occurrence pertanyaan."
        )


func _resolve_v3_game_title(
    game_id: String,
    game_no: int,
    game: Dictionary
) -> String:
    if game_id == V3_MAIN_GAME_ID:
        return "Festival Pangan Lokal"

    if game_id == V3_QUIZ_GAME_ID:
        return "Uji Literasi Pangan"

    return super._resolve_v3_game_title(
        game_id,
        game_no,
        game
    )


func _resolve_v3_mission_title(
    event: Dictionary
) -> String:
    var game_id: String = str(
        event.get(
            "game_id",
            ""
        )
    )
    var mission_id: String = str(
        event.get(
            "mechanic_id",
            event.get(
                "question_id",
                ""
            )
        )
    )
    var mission_order: int = int(
        event.get(
            "mechanic_order",
            event.get(
                "question_order",
                0
            )
        )
    )

    if game_id == V3_MAIN_GAME_ID:
        var schema_data: Dictionary = _l5_schema_data(
            mission_id
        )

        if not schema_data.is_empty():
            return (
                "Skema %d - %s"
                % [
                    mission_order,
                    str(
                        schema_data.get(
                            "name",
                            mission_id
                        )
                    ).to_lower().capitalize()
                ]
            )

    if game_id == V3_QUIZ_GAME_ID:
        if mission_order > 0:
            return "Pertanyaan %d" % mission_order

        return "Pertanyaan"

    return super._resolve_v3_mission_title(event)

func _resolve_v3_mission_scoring(
    game_id: String,
    final_event: Dictionary,
    awarded_points: int
) -> Dictionary:
    var base_points: int = awarded_points
    var retry_points: int = awarded_points

    if game_id == V3_MAIN_GAME_ID:
        var schema_id: String = str(
            final_event.get(
                "mechanic_id",
                final_event.get(
                    "question_id",
                    ""
                )
            )
        )
        var schema_data: Dictionary = _l5_schema_data(
            schema_id
        )

        if not schema_data.is_empty():
            base_points = int(
                schema_data.get(
                    "max_score",
                    awarded_points
                )
            )
            retry_points = base_points

    elif game_id == V3_QUIZ_GAME_ID:
        var quiz_scoring: Dictionary = config.get(
            "quiz",
            {}
        )
        base_points = int(
            quiz_scoring.get(
                "score_correct",
                8
            )
        )
        retry_points = 0

    else:
        return super._resolve_v3_mission_scoring(
            game_id,
            final_event,
            awarded_points
        )

    var final_result: String = str(
        final_event.get(
            "result",
            ""
        )
    )
    var penalty_points: int = 0

    if (
        game_id == V3_MAIN_GAME_ID
        and final_result == "correct"
    ):
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

func _has_level_complete_signature() -> bool:
    if current_state != "FINAL_RESULT":
        return false

    if not is_instance_valid(_active_window):
        return false

    if _active_window != final_result_panel:
        return false

    return super._has_level_complete_signature()


func _resolve_v3_answer_text(
    event: Dictionary,
    answer_id: String
) -> String:
    if str(event.get("game_id", "")) != V3_MAIN_GAME_ID:
        return super._resolve_v3_answer_text(
            event,
            answer_id
        )

    var normalized: String = answer_id.strip_edges()

    if normalized.is_empty():
        return "-"

    if normalized.ends_with(":complete"):
        return "Skema selesai"

    var payload: String = normalized
    var separator_index: int = normalized.find(":")

    if (
        separator_index >= 0
        and separator_index + 1 < normalized.length()
    ):
        payload = normalized.substr(
            separator_index + 1
        )

    return _resolve_l5_readable_item_name(payload)


func _resolve_l5_readable_item_name(
    item_id: String
) -> String:
    var normalized: String = item_id.strip_edges()

    if normalized.is_empty():
        return "-"

    if (
        normalized.begins_with("[")
        and normalized.ends_with("]")
    ):
        var pair_text: String = normalized.trim_prefix(
            "["
        ).trim_suffix(
            "]"
        ).replace(
            "\"",
            ""
        )
        var pair_parts: PackedStringArray = pair_text.split(
            ",",
            false
        )
        var pair_names: Array[String] = []

        for pair_value in pair_parts:
            var pair_id: String = str(
                pair_value
            ).strip_edges()

            if not pair_id.is_empty():
                pair_names.append(
                    _resolve_l5_readable_item_name(
                        pair_id
                    )
                )

        if not pair_names.is_empty():
            return " + ".join(pair_names)

    var food: Dictionary = ContentDatabase.get_food(
        normalized
    )

    if not food.is_empty():
        return str(
            food.get(
                "display_name",
                normalized
            )
        )

    var process: Dictionary = ContentDatabase.get_process(
        normalized
    )

    if not process.is_empty():
        return str(
            process.get(
                "display_name",
                normalized
            )
        )

    return _humanize_v3_identifier(normalized)

func _show_literacy_intro() -> void:
    set_state("LITERACY_INTRO")
    show_only(screens, literacy_intro_panel)
    %LiteracyIntroText.text = str(config.get("quiz_intro", ""))

func _start_quiz() -> void:
    quiz_controller.begin()
    quiz_score = 0
    quiz_game_start_active_ms = DurationTracker.current_active_ms()

    if not TelemetryManager.begin_game(
        5,
        V3_QUIZ_GAME_ID,
        V3_QUIZ_GAME_TYPE,
        {
            "instruction_id": V3_QUIZ_INSTRUCTION_ID,
            "instruction_version": 1,
            "instruction_text": V3_QUIZ_INSTRUCTION_TEXT,
            "content_version": ContentDatabase.content_version
        }
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 2 belum dapat memulai game."
        )

    show_only(screens, quiz_hud)
    _advance_quiz()

func _advance_quiz() -> void:
    var next := quiz_controller.advance_question()

    if next.is_empty():
        _complete_quiz()
        return

    var question_order: int = int(
        next.get(
            "index",
            0
        )
    ) + 1
    set_state(
        "QUESTION_%d"
        % question_order
    )
    %QuizNextButton.visible = false
    %QuizFeedback.text = ""

    var q: Dictionary = next.get(
        "question",
        {}
    )
    %QuestionProgress.text = "SOAL %d / %d" % [
        question_order,
        quiz_controller.question_count()
    ]
    %QuestionText.text = str(
        q.get(
            "question_text",
            ""
        )
    )

    var buttons := [
        %AnswerA,
        %AnswerB,
        %AnswerC,
        %AnswerD
    ]
    var answers: Array = next.get(
        "answers",
        []
    )

    for i in range(buttons.size()):
        var b: Button = buttons[i]
        b.disabled = false
        b.visible = i < answers.size()

        if i < answers.size():
            b.set_meta(
                "answer_id",
                str(
                    answers[i].get(
                        "answer_id",
                        ""
                    )
                )
            )
            b.text = "%s. %s" % [
                ["A", "B", "C", "D"][i],
                str(
                    answers[i].get(
                        "text",
                        ""
                    )
                )
            ]

    DurationTracker.resume_active_play()
    question_timer.start_question()
    _begin_l5_quiz_occurrence(
        q,
        answers,
        question_order
    )

func _on_answer_pressed(button_index: int) -> void:
    if not question_timer.running:
        return

    question_timer.stop()
    DurationTracker.pause_active_play()

    var buttons := [
        %AnswerA,
        %AnswerB,
        %AnswerC,
        %AnswerD
    ]
    var button: Button = buttons[button_index]
    var answer_id := str(
        button.get_meta(
            "answer_id",
            ""
        )
    )
    var result := quiz_controller.submit(
        answer_id,
        question_timer.elapsed_ms()
    )
    var correct_answer_id: String = str(
        result.get(
            "correct_answer_id",
            ""
        )
    )

    if not TelemetryManager.record_question_answer(
        5,
        V3_QUIZ_GAME_ID,
        V3_QUIZ_GAME_TYPE,
        answer_id,
        correct_answer_id,
        quiz_controller.score,
        false
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 2 belum dapat merekam jawaban."
        )

    _lock_answer_buttons()
    var q := quiz_controller.current_question

    if bool(result.get("correct", false)):
        %QuizFeedback.text = (
            "BENAR +8\n"
            + str(
                q.get(
                    "feedback_correct",
                    ""
                )
            )
        )
    else:
        %QuizFeedback.text = (
            "BELUM TEPAT +0\n"
            + "Jawaban benar: %s\n%s"
            % [
                quiz_controller.current_correct_text(),
                str(
                    q.get(
                        "feedback_wrong",
                        ""
                    )
                )
            ]
        )

    _log_quiz_response(result)
    %QuizNextButton.text = (
        "LIHAT HASIL"
        if not quiz_controller.has_more()
        else "SOAL BERIKUTNYA"
    )
    %QuizNextButton.visible = true

func _on_question_timeout() -> void:
    DurationTracker.pause_active_play()

    var result := quiz_controller.submit_timeout(
        int(
            config.get(
                "quiz",
                {}
            ).get(
                "seconds_per_question",
                30
            )
        )
        * 1000
    )
    var correct_answer_id: String = str(
        result.get(
            "correct_answer_id",
            ""
        )
    )

    if not TelemetryManager.record_question_timeout(
        5,
        V3_QUIZ_GAME_ID,
        V3_QUIZ_GAME_TYPE,
        correct_answer_id,
        quiz_controller.score
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 2 belum dapat merekam timeout."
        )

    _lock_answer_buttons()
    var q := quiz_controller.current_question
    %QuizFeedback.text = (
        "WAKTU MENJAWAB HABIS +0\n"
        + "Jawaban benar: %s\n%s"
        % [
            quiz_controller.current_correct_text(),
            str(
                q.get(
                    "feedback_wrong",
                    ""
                )
            )
        ]
    )
    _log_quiz_response(result)
    %QuizNextButton.text = (
        "LIHAT HASIL"
        if not quiz_controller.has_more()
        else "SOAL BERIKUTNYA"
    )
    %QuizNextButton.visible = true

func _log_quiz_response(result: Dictionary) -> void:
    var response: Dictionary = result.get("response", {})
    response["level_session_id"] = str(level_session.get("level_session_id", ""))
    response["final_status"] = str(result.get("status", ""))
    AnalyticsLogger.log_event("quiz_answer", response)

func _lock_answer_buttons() -> void:
    for b in [%AnswerA,%AnswerB,%AnswerC,%AnswerD]:
        b.disabled = true

func _complete_quiz() -> void:
    question_timer.stop()
    DurationTracker.pause_active_play()
    quiz_score = quiz_controller.score

    var quiz_game_duration_ms: int = 0

    if quiz_game_start_active_ms >= 0:
        quiz_game_duration_ms = maxi(
            0,
            DurationTracker.current_active_ms()
            - quiz_game_start_active_ms
        )

    if not TelemetryManager.complete_game(
        5,
        V3_QUIZ_GAME_ID,
        V3_QUIZ_GAME_TYPE,
        quiz_score,
        quiz_game_duration_ms
    ):
        push_warning(
            "Telemetry v3 Level 5 Game 2 belum dapat menyelesaikan game."
        )

    final_score = main_game_score + quiz_score
    active_duration_ms = DurationTracker.finish_level_session()
    level_session["active_duration_ms"] = active_duration_ms
    level_session["quiz"] = quiz_controller.snapshot()
    level_session["completed_at"] = Time.get_unix_time_from_system()
    GameState.update_level_session(level_session)
    set_state("FINAL_RESULT")
    show_only(screens, final_result_panel)

    var correct_count := 0

    for response in quiz_controller.responses:
        if str(
            response.get(
                "question_status",
                ""
            )
        ) == "CORRECT":
            correct_count += 1

    %FinalResultText.text = (
        "LEVEL 5 SELESAI\n"
        + "Performa Festival: %d/60\n" % main_game_score
        + "Uji Literasi: %d/40\n" % quiz_score
        + "TOTAL: %d/100\n" % final_score
        + "Jawaban benar: %d/5" % correct_count
    )

func _show_gallery() -> void:
    set_state("KNOWLEDGE_GALLERY")
    show_only(screens, gallery_panel)
    var lines: Array[String] = []
    lines.append("[b]SELURUH PANGAN[/b]")
    for fid_value in config.get("bank_food_ids", []):
        var f := ContentDatabase.get_food(str(fid_value))
        lines.append("• %s — %s" % [str(f.get("display_name", "")), ContentDatabase.get_group_name(str(f.get("group_id", "")))])
    lines.append("")
    lines.append("[b]HASIL OLAHAN LEVEL 4[/b]")
    for p in ContentDatabase.get_level_04_processed_foods():
        lines.append("• %s — %s + %s → %s" % [str(p.get("display_name", "")), str(p.get("ingredient_a_name", "")), str(p.get("ingredient_b_name", "")), str(p.get("process_name", ""))])
    lines.append("")
    lines.append(str(config.get("information_disclaimer", "")))
    %GalleryText.text = "\n".join(lines)

func _show_badge() -> void:
    set_state("FINAL_BADGE")
    show_only(screens, badge_panel)
    var badge: Dictionary = config.get("badge", {})
    %BadgeName.text = str(badge.get("display_name", "Duta Pangan Lokal"))
    %BadgeDescription.text = str(badge.get("description", ""))

func _show_closing() -> void:
    set_state("CLOSING_DIALOGUE")
    show_only(screens, closing_panel)
    dialogue_lines = config.get("dialogue", {}).get("closing", [])
    closing_index = 0
    _render_closing()

func _advance_closing() -> void:
    closing_index += 1
    if closing_index < dialogue_lines.size():
        _render_closing()
        return
    _show_final_map()

func _render_closing() -> void:
    var line: Dictionary = dialogue_lines[closing_index]
    %ClosingSpeaker.text = str(line.get("speaker", ""))
    _set_dialogue_speaker(%ClosingSpeaker.text)
    %ClosingText.text = str(line.get("text", ""))
    %ClosingNextButton.text = "LIHAT PERJALANAN" if closing_index == dialogue_lines.size()-1 else "LANJUT"

func _show_final_map() -> void:
    _save_final_completion()
    set_state("FINAL_MAP")
    show_only(screens, final_map_panel)
    %FinalReplayButton.text = "PERJALANAN BARU"
    var score_total := 0
    var duration_total := 0
    var rows: Array[String] = []
    for level_no in range(1,6):
        var key := str(level_no)
        var score := int(GameState.active_run.get("level_scores", {}).get(key, 0))
        var duration := int(GameState.active_run.get("level_durations_ms", {}).get(key, 0))
        score_total += score
        duration_total += duration
        rows.append("Level %d  ✓   %d/100   %s" % [level_no, score, _format_ms(duration)])
    %JourneyText.text = "PERJALANAN SELESAI\nBadge Final: Duta Pangan Lokal\n\n%s\n\nTotal skor game: %d/500\nTotal durasi aktif: %s\n\nPerjalanan ini sudah tersimpan di Riwayat. Mulai perjalanan baru untuk bermain lagi." % ["\n".join(rows), score_total, _format_ms(duration_total)]

# BUNDLE_53B_R2_LEVEL5_FINALIZE_BEGIN
func _finish_completed_journey(target_scene: String) -> void:
    var finalized: bool = GameState.finalize_completed_run()

    if not finalized:
        push_warning("Completed run sudah kosong atau belum berstatus COMPLETED.")

    if not SaveManager.save_now():
        push_warning("Finalisasi perjalanan belum dapat disimpan langsung. Autosave tetap diminta.")

    SceneRouter.goto(target_scene)
# BUNDLE_53B_R2_LEVEL5_FINALIZE_END

func _save_final_completion() -> void:
    if final_saved:
        return
    final_saved = true
    var badge: Dictionary = config.get("badge", {})
    GameState.complete_level(5, final_score, active_duration_ms, str(badge.get("badge_id", "badge_level_05")), str(badge.get("display_name", "Duta Pangan Lokal")), str(level_session.get("level_session_id", "")))

func _feedback(text: String, good: bool) -> void:
    %SchemaFeedback.text = text
    %SchemaFeedback.modulate = (
        Color(0.18, 0.46, 0.24, 1)
        if good
        else Color(0.68, 0.28, 0.18, 1)
    )

    if good:
        UIMotion.play_pop(%SchemaFeedback, 1.035)
    else:
        UIMotion.play_shake(%SchemaFeedback, 5.0)

func _clear_container(node: Node) -> void:
    for child in node.get_children():
        child.queue_free()

func _format_seconds(seconds: int) -> String:
    return "%02d:%02d" % [int(seconds / 60.0), seconds % 60]

func _format_ms(ms: int) -> String:
    var safe_ms: int = maxi(0, ms)
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


func _ensure_level_runtime_ready() -> bool:
    if not ContentDatabase.initialize():
        push_error("Level 5 gagal menginisialisasi ContentDatabase.")
        return false

    SettingsManager.initialize()

    if not GameState.initialized:
        GameState.initialize()

    AnalyticsLogger.initialize()
    return true
