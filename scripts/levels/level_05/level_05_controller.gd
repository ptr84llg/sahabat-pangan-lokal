extends LevelFlowController

const FOOD_SLOT_SCENE := preload("res://scenes/shared/festival_food_slot.tscn")
const BASKET_SLOT_SCENE := preload("res://scenes/shared/festival_basket_slot.tscn")

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
    DurationTracker.begin_level_session(str(level_session.get("level_session_id", "")), 5)
    DurationTracker.resume_active_play()
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
    AnalyticsLogger.log_event("level_main_started", {"level_session_id":str(level_session.get("level_session_id", "")),"attempt_id":attempt_id,"level_no":5,"main_timer_initial":int(config.get("main_timer_seconds",240)),"lane_assignment":moving_lane.assignment_snapshot(),"content_version":ContentDatabase.content_version})
    _load_schema(0)

func _load_schema(index: int) -> void:
    schema_index = index
    var schemas: Array = config.get("schemas", [])
    if index < 0 or index >= schemas.size():
        return
    _clear_container(%SchemaMissionContent)
    %ProcessChoiceRow.visible = false
    %SchemaFeedback.text = ""
    var data: Dictionary = schemas[index]
    %SchemaLabel.text = "SKEMA %d/4 • %s" % [index + 1, str(data.get("name", ""))]
    %SchemaProgress.text = ""
    set_state("SCHEMA_%d" % [index + 1])
    moving_lane.set_coin_visible(index == 2)
    match index:
        0: _setup_schema1(data)
        1: _setup_schema2(data)
        2: _setup_schema3(data)
        3: _setup_schema4(data)

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
    var title := Label.new()
    title.text = "TEMUKAN: %s" % str(food.get("display_name", food_id)).to_upper()
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    %SchemaMissionContent.add_child(title)
    var holder := CenterContainer.new()
    holder.custom_minimum_size = Vector2(0, 150)
    %SchemaMissionContent.add_child(holder)
    var slot: FestivalFoodSlot = FOOD_SLOT_SCENE.instantiate()
    holder.add_child(slot)
    slot.setup("TARGET %d/3" % [schema1_target_index + 1])
    slot.drop_received.connect(_on_schema1_drop.bind(food_id, slot))
    %SchemaProgress.text = "Target %d/3" % [schema1_target_index + 1]

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
    var intro := Label.new()
    intro.text = "Isi satu pangan yang benar untuk setiap kelompok."
    intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    %SchemaMissionContent.add_child(intro)
    var row := HBoxContainer.new()
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
    %SchemaProgress.text = "Kelompok 0/4"

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
    var top := Label.new()
    top.name = "ShopInfoDynamic"
    top.text = "Pilih tepat 4 pangan, satu dari setiap kelompok. Batas 15 Koin Pangan."
    top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    %SchemaMissionContent.add_child(top)
    var checklist := Label.new()
    checklist.name = "ShopChecklistDynamic"
    checklist.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    %SchemaMissionContent.add_child(checklist)
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
    %SchemaProgress.text = "Keranjang %d/4 • %d/15 Koin" % [schema3_selected.size(), schema3_total_coin]
    var label := %SchemaMissionContent.get_node_or_null("ShopChecklistDynamic") as Label
    if label != null:
        var groups := ["group_staple_root","group_vegetable","group_fruit","group_fishery"]
        var parts: Array[String] = []
        for gid in groups:
            parts.append(("✓ " if schema3_selected.has(gid) else "□ ") + ContentDatabase.get_group_name(gid))
        label.text = "   |   ".join(parts)

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
    label.text = "TARGET OLAHAN %d/2: %s" % [schema4_target_index + 1, str(processed.get("display_name", processed_id)).to_upper()]
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
    %SchemaProgress.text = "Olahan %d/2" % [schema4_target_index + 1]

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

func _register_invalid(schema_id: String, event_type: String, item_id: String) -> void:
    AudioManager.play_sfx("wrong")
    var score_now := schema_controller.register_invalid(schema_id, event_type, {"item_id":item_id,"timer_remaining":main_timer.seconds_left()})
    AnalyticsLogger.log_event("l5_invalid_event", {"level_session_id":str(level_session.get("level_session_id", "")),"attempt_id":attempt_id,"schema_id":schema_id,"event_type":event_type,"item_id":item_id,"timer_remaining":main_timer.seconds_left(),"schema_score_now":score_now})

func _complete_schema(schema_id: String) -> void:
    var score_now := schema_controller.complete_schema(schema_id)
    AnalyticsLogger.log_event("l5_schema_complete", {"level_session_id":str(level_session.get("level_session_id", "")),"schema_id":schema_id,"schema_score":score_now,"timer_remaining":main_timer.seconds_left()})
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
    var attempt_snapshot := {"attempt_id":attempt_id,"attempt_index":1,"status":"MAIN_GAME_SUCCESS","schema":schema_controller.snapshot(),"main_timer_initial":int(config.get("main_timer_seconds",240)),"main_timer_remaining":main_timer.seconds_left(),"main_timer_expired":main_timer.is_expired,"time_bonus":time_bonus,"main_game_score":main_game_score,"lane_assignment":moving_lane.assignment_snapshot(),"completed_at":Time.get_unix_time_from_system()}
    level_session["attempts"].append(attempt_snapshot)
    level_session["successful_attempt_id"] = attempt_id
    GameState.update_level_session(level_session)
    set_state("MAIN_GAME_COMPLETE")
    show_only(screens, main_result_panel)
    var snap: Dictionary = schema_controller.snapshot()
    var scores: Dictionary = snap.get("scores", {})
    %MainResultText.text = "MAIN GAME SELESAI\nSkema 1: %d/10\nSkema 2: %d/12\nSkema 3: %d/13\nSkema 4: %d/15\nBonus waktu: %d/10\nMain Game: %d/60\nSisa waktu: %s%s" % [int(scores.get("schema_1",0)),int(scores.get("schema_2",0)),int(scores.get("schema_3",0)),int(scores.get("schema_4",0)),time_bonus,main_game_score,_format_seconds(main_timer.seconds_left())," - Bonus waktu habis" if main_timer.is_expired else ""]

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

func _show_literacy_intro() -> void:
    set_state("LITERACY_INTRO")
    show_only(screens, literacy_intro_panel)
    %LiteracyIntroText.text = str(config.get("quiz_intro", ""))

func _start_quiz() -> void:
    quiz_controller.begin()
    quiz_score = 0
    show_only(screens, quiz_hud)
    _advance_quiz()

func _advance_quiz() -> void:
    var next := quiz_controller.advance_question()
    if next.is_empty():
        _complete_quiz()
        return
    set_state("QUESTION_%d" % [int(next.get("index",0))+1])
    %QuizNextButton.visible = false
    %QuizFeedback.text = ""
    var q: Dictionary = next.get("question", {})
    %QuestionProgress.text = "SOAL %d / %d" % [int(next.get("index",0))+1, quiz_controller.question_count()]
    %QuestionText.text = str(q.get("question_text", ""))
    var buttons := [%AnswerA,%AnswerB,%AnswerC,%AnswerD]
    var answers: Array = next.get("answers", [])
    for i in range(buttons.size()):
        var b: Button = buttons[i]
        b.disabled = false
        b.visible = i < answers.size()
        if i < answers.size():
            b.set_meta("answer_id", str(answers[i].get("answer_id", "")))
            b.text = "%s. %s" % [["A","B","C","D"][i], str(answers[i].get("text", ""))]
    DurationTracker.resume_active_play()
    question_timer.start_question()

func _on_answer_pressed(button_index: int) -> void:
    if not question_timer.running:
        return
    question_timer.stop()
    DurationTracker.pause_active_play()
    var buttons := [%AnswerA,%AnswerB,%AnswerC,%AnswerD]
    var button: Button = buttons[button_index]
    var answer_id := str(button.get_meta("answer_id", ""))
    var result := quiz_controller.submit(answer_id, question_timer.elapsed_ms())
    _lock_answer_buttons()
    var q := quiz_controller.current_question
    if bool(result.get("correct", false)):
        %QuizFeedback.text = "BENAR +8\n" + str(q.get("feedback_correct", ""))
    else:
        %QuizFeedback.text = "BELUM TEPAT +0\nJawaban benar: %s\n%s" % [quiz_controller.current_correct_text(), str(q.get("feedback_wrong", ""))]
    _log_quiz_response(result)
    %QuizNextButton.text = "LIHAT HASIL" if not quiz_controller.has_more() else "SOAL BERIKUTNYA"
    %QuizNextButton.visible = true

func _on_question_timeout() -> void:
    DurationTracker.pause_active_play()
    var result := quiz_controller.submit_timeout(int(config.get("quiz", {}).get("seconds_per_question",30))*1000)
    _lock_answer_buttons()
    var q := quiz_controller.current_question
    %QuizFeedback.text = "WAKTU MENJAWAB HABIS +0\nJawaban benar: %s\n%s" % [quiz_controller.current_correct_text(), str(q.get("feedback_wrong", ""))]
    _log_quiz_response(result)
    %QuizNextButton.text = "LIHAT HASIL" if not quiz_controller.has_more() else "SOAL BERIKUTNYA"
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
        if str(response.get("question_status", "")) == "CORRECT":
            correct_count += 1
    %FinalResultText.text = "LEVEL 5 SELESAI\nPerforma Festival: %d/60\nUji Literasi: %d/40\nTOTAL: %d/100\nJawaban benar: %d/5" % [main_game_score, quiz_score, final_score, correct_count]

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
    var seconds := int(round(ms / 1000.0))
    return "%02d:%02d" % [int(seconds / 60.0), seconds % 60]

func _ensure_level_runtime_ready() -> bool:
    if not ContentDatabase.initialize():
        push_error("Level 5 gagal menginisialisasi ContentDatabase.")
        return false

    SettingsManager.initialize()

    if not GameState.initialized:
        GameState.initialize()

    AnalyticsLogger.initialize()
    return true
