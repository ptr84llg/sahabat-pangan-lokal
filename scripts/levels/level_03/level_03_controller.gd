extends LevelFlowController

const FOOD_CARD_SCENE := preload("res://scenes/shared/food_card.tscn")
const BASKET_SLOT_SCENE := preload("res://scenes/shared/basket_slot.tscn")
const DROP_SLOT_SCENE := preload("res://scenes/shared/drop_slot.tscn")

@onready var theme_panel: Control = %ThemePanel
@onready var dialogue_panel: Control = %DialoguePanel
@onready var tutorial_panel: Control = %TutorialPanel
@onready var main_game_hud: Control = %MainGameHUD
@onready var main_success_panel: Control = %MainGameSuccessPanel
@onready var literacy_hud: Control = %LiteracyHUD
@onready var result_panel: Control = %ResultPanel
@onready var info_panel: Control = %InfoPanel
@onready var badge_panel: Control = %BadgePanel
@onready var closing_panel: Control = %ClosingPanel
@onready var shopping_controller: ShoppingController = %ShoppingController

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
var r3_freed_coin := 0
var r3_replacement_id := ""
var literacy_transition_pending := false
var info_index := 0
var closing_index := 0
var main_game_penalty_total := 0
var dead_end_state_active := false
var back_to_map_count := 0
func _ready() -> void:
    if not _ensure_level_runtime_ready():
        return
    set_meta("level_no", 3)
    _prepare_level_presentation()
    level_config = ContentDatabase.get_level_03_config()
    foods = ContentDatabase.get_level_03_foods()
    for food in foods:
        foods_by_id[str(food.get("food_id", ""))] = food
    screens = [theme_panel, dialogue_panel, tutorial_panel, main_game_hud, main_success_panel, literacy_hud, result_panel, info_panel, badge_panel, closing_panel]
    _connect_ui()
    _setup_market()
    _show_theme()

func _connect_ui() -> void:
    %ThemeStartButton.pressed.connect(_show_opening_dialogue)
    %DialogueNextButton.pressed.connect(_on_dialogue_next)
    %TutorialContinueButton.pressed.connect(_start_gameplay)
    %TutorialSkipButton.pressed.connect(_start_gameplay)
    %HintButton.pressed.connect(shopping_controller.request_hint)
    %CheckShoppingButton.pressed.connect(shopping_controller.check_shopping)
    %DeadEndConfirmButton.pressed.connect(_hide_dead_end_modal)
    %MainSuccessNextButton.pressed.connect(_start_literacy)
    %ResultNextButton.pressed.connect(_show_info)
    %InfoNextButton.pressed.connect(_advance_info)
    %BadgeNextButton.pressed.connect(_show_closing)
    %ClosingNextButton.pressed.connect(_advance_closing)
    shopping_controller.basket_changed.connect(_on_basket_changed)
    shopping_controller.feedback.connect(_show_feedback)
    shopping_controller.shopping_success.connect(_on_shopping_success)

    _bind_motion_controls()

func _bind_motion_controls() -> void:
    var motion_buttons: Array = [
        %ThemeStartButton,
        %DialogueNextButton,
        %TutorialContinueButton,
        %TutorialSkipButton,
        %HintButton,
        %CheckShoppingButton,
        %BackButton,
        %DeadEndConfirmButton,
        %MainSuccessNextButton,
        %ResultNextButton,
        %InfoNextButton,
        %BadgeNextButton,
        %ClosingNextButton
    ]

    for button_value in motion_buttons:
        var button: BaseButton = button_value as BaseButton

        if button != null:
            UIMotion.bind_button(button)

func _setup_market() -> void:
    shopping_controller.configure(level_config, foods)
    shopping_controller.register_market_container(%MarketTray)
    var shuffled_foods: Array = foods.duplicate(true)
    shuffled_foods.shuffle()
    for food_value in shuffled_foods:
        var food: Dictionary = food_value
        var food_id := str(food.get("food_id", ""))
        var group_id := str(food.get("group_id", ""))
        var card: FoodCard = FOOD_CARD_SCENE.instantiate()
        card.custom_minimum_size = Vector2(124, 132)
        %MarketTray.add_child(card)
        card.setup(food_id, str(food.get("display_name", "")), group_id, int(food.get("coin_value", 0)), true, true, "market_food_card")
        _polish_market_card(card)
        _apply_square_style_recursive(card)
    for _i in range(4):
        var slot: BasketSlot = BASKET_SLOT_SCENE.instantiate()
        slot.custom_minimum_size = Vector2(118, 164)
        %BasketGrid.add_child(slot)
        _apply_square_style_recursive(slot)
        shopping_controller.register_basket_slot(slot)

        var cancel_button: BaseButton = (
            slot.find_child("CancelButton", true, false) as BaseButton
        )

        if cancel_button != null:
            UIMotion.bind_button(cancel_button)

func _polish_market_card(card: FoodCard) -> void:
    var glyph: Control = card.get_node_or_null("%Glyph") as Control
    if glyph != null:
        glyph.custom_minimum_size = Vector2(112, 78)
    var name_label: Label = card.get_node_or_null("%NameLabel") as Label
    if name_label != null:
        name_label.add_theme_font_size_override("font_size", 16)
        name_label.add_theme_color_override("font_color", Color(0.02, 0.30, 0.20, 1))
    var coin_label: Label = card.get_node_or_null("%CoinLabel") as Label
    if coin_label != null:
        coin_label.add_theme_font_size_override("font_size", 15)
        coin_label.add_theme_color_override("font_color", Color(0.02, 0.30, 0.20, 1))

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
    var line: Dictionary = dialogue_lines[dialogue_index]
    %SpeakerLabel.text = str(line.get("speaker", ""))
    _set_dialogue_speaker(%SpeakerLabel.text)
    %DialogueText.text = str(line.get("text", ""))
    %DialogueNextButton.text = "SIAP" if current_state == "DIALOGUE_MISSION" and dialogue_index == dialogue_lines.size()-1 else "LANJUT"

func _show_tutorial() -> void:
    set_state("TUTORIAL_SHOPPING")
    show_only(screens, tutorial_panel)
    %TutorialSkipButton.visible = bool(SettingsManager.get_flag(str(level_config.get("tutorial_flag_key", "shopping_tutorial_seen")), false))

func _start_gameplay() -> void:
    SettingsManager.set_flag(str(level_config.get("tutorial_flag_key", "shopping_tutorial_seen")), true)
    if level_session.is_empty():
        level_session = GameState.begin_level_session(3)
        DurationTracker.begin_level_session(str(level_session.get("level_session_id", "")), 3)
    set_state("MAIN_GAME")
    show_only(screens, main_game_hud)
    main_game_penalty_total = 0
    dead_end_state_active = false
    %DeadEndMask.visible = false
    _set_market_blocked(false, "")
    DurationTracker.resume_active_play()
    _on_basket_changed([], int(level_config.get("coin_budget", 15)), {})
    AnalyticsLogger.log_event("level_main_started", {"level_session_id":level_session.get("level_session_id", ""),"level_no":3,"content_version":ContentDatabase.content_version})

func _on_basket_changed(selected_ids: Array, coin_remaining: int, selected_groups: Dictionary) -> void:
    %CoinLabel.text = str(coin_remaining)
    %TotalValueLabel.text = str(shopping_controller.coin_used())
    var group_ids: Array = level_config.get("group_ids", [])
    var check_labels: Array[Label] = [
        %ChecklistStapleLabel,
        %ChecklistVegetableLabel,
        %ChecklistFruitLabel,
        %ChecklistFishLabel
    ]
    for i in range(min(group_ids.size(), check_labels.size())):
        var group_id := str(group_ids[i])
        check_labels[i].text = ("[X] " if selected_groups.has(group_id) else "[ ] ") + _short_group_name(group_id)
    %CheckShoppingButton.disabled = selected_ids.size() != 4
    _refresh_main_gameplay_state(selected_ids, coin_remaining, selected_groups)

func _on_shopping_success(final_ids: Array) -> void:
    var base_main_score := int(level_config.get("scoring", {}).get("main_game_success", 60))
    main_score = max(0, base_main_score - main_game_penalty_total)
    DurationTracker.pause_active_play()
    %DeadEndMask.visible = false
    _set_market_blocked(false, "")
    set_state("MAIN_GAME_SUCCESS")
    show_only(screens, main_success_panel)
    UIMotion.play_reward(main_success_panel)
    var penalty_text := "" if main_game_penalty_total <= 0 else "
Pengurangan skor: -%d" % main_game_penalty_total
    %MainSuccessText.text = "Belanjamu lengkap dan Koin Panganmu cukup!
4/4 kelompok • Main Game %d/%d%s" % [main_score, base_main_score, penalty_text]
    AnalyticsLogger.log_event("shopping_success", {"level_no":3,"level_session_id":DurationTracker.session_id,"final_basket":final_ids,"coin_used_final":shopping_controller.coin_used(),"coin_remaining_final":shopping_controller.coin_remaining(),"main_game_penalty_total":main_game_penalty_total})

func _refresh_main_gameplay_state(selected_ids: Array, coin_remaining: int, selected_groups: Dictionary) -> void:
    if selected_ids.size() >= 4:
        dead_end_state_active = false
        %DeadEndMask.visible = false
        _set_market_blocked(true, "Keranjang sudah penuh. Batalkan satu pangan jika ingin mengganti pilihan.")
        return

    var has_affordable_choice := _has_affordable_remaining_choice(coin_remaining, selected_groups)
    if not has_affordable_choice:
        _set_market_blocked(true, "Koin tersisa belum cukup. Batalkan satu pangan di keranjang untuk melanjutkan.")
        if not dead_end_state_active:
            dead_end_state_active = true
            _apply_dead_end_penalty(coin_remaining, selected_ids, selected_groups)
            _show_dead_end_modal()
        return

    dead_end_state_active = false
    %DeadEndMask.visible = false
    _set_market_blocked(false, "")

func _has_affordable_remaining_choice(coin_remaining: int, selected_groups: Dictionary) -> bool:
    for food_value in foods:
        var food: Dictionary = food_value
        var group_id := str(food.get("group_id", ""))
        if selected_groups.has(group_id):
            continue
        if int(food.get("coin_value", 0)) <= coin_remaining:
            return true
    return false

func _apply_dead_end_penalty(coin_remaining: int, selected_ids: Array, selected_groups: Dictionary) -> void:
    var penalty := int(level_config.get("scoring", {}).get("main_game_dead_end_penalty", 5))
    main_game_penalty_total += penalty
    %DeadEndPenaltyLabel.text = "Skor permainan utama berkurang %d poin." % penalty
    AnalyticsLogger.log_event("shopping_dead_end", {"level_no":3,"level_session_id":DurationTracker.session_id,"selected_ids":selected_ids,"selected_groups":selected_groups.keys(),"coin_remaining":coin_remaining,"penalty":penalty,"main_game_penalty_total":main_game_penalty_total})

func _show_dead_end_modal() -> void:
    %DeadEndMessageLabel.text = "Koin tersisa sudah habis atau tidak cukup untuk membeli pangan yang masih tersedia. Silakan batalkan salah satu pangan yang sudah masuk ke keranjang, lalu pilih kembali."
    %DeadEndMask.visible = true

    var dead_end_dialog: Control = (
        %DeadEndMask.get_node_or_null(
            "DeadEndCenter/DeadEndDialog"
        ) as Control
    )

    if dead_end_dialog != null:
        UIMotion.play_pop(dead_end_dialog, 1.025)

    %DeadEndConfirmButton.call_deferred("grab_focus")

func _hide_dead_end_modal() -> void:
    %DeadEndMask.visible = false

func _set_market_blocked(blocked: bool, message: String) -> void:
    %MarketBlocker.visible = blocked
    %MarketBlockerText.text = message

func _apply_square_style_recursive(node: Node) -> void:
    if node is Control:
        var control := node as Control
        var style_names := ["panel", "normal", "hover", "pressed", "disabled", "focus"]
        for style_name_value in style_names:
            var style_name := str(style_name_value)
            var source_style: StyleBox = control.get_theme_stylebox(style_name)
            if source_style is StyleBoxFlat:
                var square_style := source_style.duplicate() as StyleBoxFlat
                square_style.corner_radius_top_left = 0
                square_style.corner_radius_top_right = 0
                square_style.corner_radius_bottom_left = 0
                square_style.corner_radius_bottom_right = 0
                control.add_theme_stylebox_override(style_name, square_style)
    for child in node.get_children():
        _apply_square_style_recursive(child)

func _start_literacy() -> void:
    literacy_round_index = 0
    literacy_attempts.clear()
    literacy_score = 0
    literacy_transition_pending = false
    set_state("LITERACY_ROUND_1")
    show_only(screens, literacy_hud)
    _render_literacy_round()


func _render_literacy_round() -> void:
    literacy_transition_pending = false
    _clear_container(%ChallengeSlotHolder)
    _clear_container(%BasketSummaryTray)
    _clear_container(%ChallengeChoiceTray)

    %PuzzleArea.visible = false
    %RearrangeSummaryArea.visible = false
    %ChallengeFeedback.text = ""

    var rounds: Array = level_config.get("literacy_rounds", [])
    var round_data: Dictionary = rounds[literacy_round_index]
    var round_id := str(round_data.get("round_id", ""))

    if not literacy_attempts.has(round_id):
        literacy_attempts[round_id] = 0

    set_state("LITERACY_ROUND_%d" % [literacy_round_index + 1])
    _refresh_literacy_sidebar()

    if str(round_data.get("kind", "select")) == "select":
        _render_select_round(round_data)
    else:
        _render_rearrange_round(round_data)

    DurationTracker.resume_active_play()


func _render_select_round(round_data: Dictionary) -> void:
    var coin_available := int(round_data.get("coin_available", 0))
    var required_group_id := str(round_data.get("required_group_id", ""))
    var required_group_name := ContentDatabase.get_group_name(required_group_id)

    %MissionText.text = (
        "Lengkapi keranjang dengan 1 pangan dari kelompok %s. "
        + "Gunakan Koin yang tersedia."
    ) % required_group_name

    %ReferenceCoinValue.text = "%d KOIN" % coin_available
    %ReferenceTargetValue.text = required_group_name.to_upper()
    %InstructionLabel.text = "SERET 1 PANGAN KE KOTAK TARGET"
    %LiteracyStatusLabel.text = "PILIH PANGAN"

    %PuzzleArea.visible = true
    %RearrangeSummaryArea.visible = false

    var slot: FoodDropSlot = DROP_SLOT_SCENE.instantiate()
    %ChallengeSlotHolder.add_child(slot)
    slot.setup(
        str(round_data.get("correct_food_id", "")),
        "TARGET: %s" % required_group_name.to_upper()
    )
    _style_literacy_drop_slot(slot)
    slot.drop_received.connect(_on_select_round_drop.bind(round_data))
    UIMotion.play_pulse(slot, 1.04)

    var choice_ids: Array = round_data.get("choice_ids", [])

    for choice_id_value in choice_ids:
        var food_id := str(choice_id_value)
        var food := ContentDatabase.get_food(food_id)
        var card: FoodCard = FOOD_CARD_SCENE.instantiate()
        %ChallengeChoiceTray.add_child(card)
        card.setup(
            food_id,
            str(food.get("display_name", "")),
            str(food.get("group_id", "")),
            int(food.get("coin_value", 0)),
            false,
            true
        )
        _style_literacy_card(card, false)
        UIMotion.play_pop(card, 1.025)

    UIMotion.play_pop(%ReferenceCoinValue, 1.025)
    UIMotion.play_pop(%ReferenceTargetValue, 1.025)


func _on_select_round_drop(
    food_id: String,
    card: FoodCard,
    slot: FoodDropSlot,
    round_data: Dictionary
) -> void:
    if literacy_transition_pending:
        return

    DurationTracker.pause_active_play()

    var round_id := str(round_data.get("round_id", ""))
    literacy_attempts[round_id] = int(literacy_attempts.get(round_id, 0)) + 1
    var attempt_no := int(literacy_attempts[round_id])
    var correct := food_id == str(round_data.get("correct_food_id", ""))

    AnalyticsLogger.log_event(
        "literacy_answer",
        {
            "level_no": 3,
            "literacy_round": literacy_round_index + 1,
            "selected_answer": food_id,
            "correct": correct,
            "attempt_no": attempt_no
        }
    )

    if correct:
        AudioManager.play_sfx("drop_correct")
        slot.accept_card(card)
        slot.title_label.text = "TARGET TERPENUHI"
        _style_literacy_card(card, true)
        UIMotion.play_pop(card, 1.06)
        UIMotion.play_reward(slot)
        _award_literacy_round(attempt_no)

        %LiteracyStatusLabel.text = "BERHASIL"
        %ChallengeFeedback.text = (
            "HEBAT! Kelompok dan jumlah Koin pilihanmu sudah tepat."
        )
        UIMotion.play_reward(%ChallengeFeedback)
        _schedule_literacy_auto_advance()
        return

    var food := ContentDatabase.get_food(food_id)

    if str(food.get("group_id", "")) == str(round_data.get("required_group_id", "")):
        %ChallengeFeedback.text = (
            "Kelompoknya sudah benar, tetapi Koin pilihan ini belum sesuai."
        )
    else:
        %ChallengeFeedback.text = (
            "Belum tepat. Lihat kembali TARGET di sebelah kiri."
        )

    card.show_wrong_feedback()
    UIMotion.play_shake(card, 6.0)
    UIMotion.play_shake(%ReferenceTargetValue, 5.0)
    AudioManager.play_sfx("wrong")
    DurationTracker.resume_active_play()


func _render_rearrange_round(round_data: Dictionary) -> void:
    r3_freed_coin = 0
    r3_replacement_id = ""

    %MissionText.text = (
        "Buah belum ada dan Koin sudah habis. Ganti 1 pangan "
        + "agar tersisa minimal 2 Koin, lalu pilih buah."
    )
    %PuzzleArea.visible = false
    %RearrangeSummaryArea.visible = true
    %RearrangeCoinValue.text = "SISA KOIN: 0"
    %RearrangeTargetValue.text = "TARGET: BUAH"
    %LiteracyStatusLabel.text = "ATUR ULANG"

    _render_rearrange_basket_summary(round_data)
    _render_rearrange_step_one(round_data)


func _render_rearrange_basket_summary(round_data: Dictionary) -> void:
    _clear_container(%BasketSummaryTray)

    for food_id_value in round_data.get("initial_ids", []):
        var food_id := str(food_id_value)
        var food := ContentDatabase.get_food(food_id)
        var card: FoodCard = FOOD_CARD_SCENE.instantiate()
        %BasketSummaryTray.add_child(card)
        card.setup(
            food_id,
            str(food.get("display_name", "")),
            str(food.get("group_id", "")),
            int(food.get("coin_value", 0)),
            false,
            true
        )
        card.set_static_preview()
        _style_literacy_card(card, true)


func _render_rearrange_step_one(round_data: Dictionary) -> void:
    _clear_container(%ChallengeChoiceTray)

    %InstructionLabel.text = "LANGKAH 1 / 2 - PILIH PENGGANTI YANG MENGHEMAT MINIMAL 2 KOIN"
    %RearrangeCoinValue.text = "SISA KOIN: 0"
    %LiteracyStatusLabel.text = "PILIH PENGGANTI"

    for food_id_value in round_data.get("replacement_choices", []):
        var food_id := str(food_id_value)
        var food := ContentDatabase.get_food(food_id)
        var current_food := _find_initial_food_by_group(
            round_data,
            str(food.get("group_id", ""))
        )

        var current_coin := int(current_food.get("coin_value", 0))
        var replacement_coin := int(food.get("coin_value", 0))
        var saved_coin := maxi(0, current_coin - replacement_coin)

        _add_visual_food_option(
            food_id,
            "HEMAT %d KOIN" % saved_coin,
            _on_replacement_selected.bind(food_id, round_data)
        )


func _on_replacement_selected(
    food_id: String,
    round_data: Dictionary
) -> void:
    if literacy_transition_pending:
        return

    var food := ContentDatabase.get_food(food_id)
    var current_food := _find_initial_food_by_group(
        round_data,
        str(food.get("group_id", ""))
    )

    var current_coin := int(current_food.get("coin_value", 0))
    var replacement_coin := int(food.get("coin_value", 0))
    r3_freed_coin = maxi(0, current_coin - replacement_coin)
    r3_replacement_id = food_id

    if r3_freed_coin < 2:
        _register_rearrange_invalid(
            food_id,
            "Belum cukup. Cari pilihan yang menghemat minimal 2 Koin."
        )
        return

    %RearrangeCoinValue.text = "SISA KOIN: %d" % r3_freed_coin
    %InstructionLabel.text = (
        "LANGKAH 2 / 2 - PILIH BUAH MAKSIMAL %d KOIN"
        % r3_freed_coin
    )
    %LiteracyStatusLabel.text = "PILIH BUAH"
    %ChallengeFeedback.text = (
        "BAGUS! Sekarang tersedia %d Koin untuk melengkapi kelompok Buah."
        % r3_freed_coin
    )

    _clear_container(%ChallengeChoiceTray)

    for fruit_id_value in round_data.get("fruit_choices", []):
        var fruit_id := str(fruit_id_value)
        var fruit := ContentDatabase.get_food(fruit_id)

        _add_visual_food_option(
            fruit_id,
            "%d KOIN" % int(fruit.get("coin_value", 0)),
            _on_rearrange_fruit_selected.bind(fruit_id, round_data)
        )

    UIMotion.play_reward(%RearrangeCoinValue)
    UIMotion.play_pop(%ChallengeChoiceTray, 1.03)


func _on_rearrange_fruit_selected(
    food_id: String,
    round_data: Dictionary
) -> void:
    if literacy_transition_pending:
        return

    DurationTracker.pause_active_play()

    var fruit := ContentDatabase.get_food(food_id)
    var cost := int(fruit.get("coin_value", 0))
    var correct := (
        food_id == str(round_data.get("correct_fruit_id", ""))
        and cost <= r3_freed_coin
        and r3_replacement_id == str(round_data.get("correct_replacement_id", ""))
    )

    var round_id := str(round_data.get("round_id", ""))
    literacy_attempts[round_id] = int(literacy_attempts.get(round_id, 0)) + 1
    var attempt_no := int(literacy_attempts[round_id])

    AnalyticsLogger.log_event(
        "literacy_answer",
        {
            "level_no": 3,
            "literacy_round": 3,
            "selected_answer": "%s+%s" % [r3_replacement_id, food_id],
            "correct": correct,
            "attempt_no": attempt_no
        }
    )

    if correct:
        AudioManager.play_sfx("drop_correct")
        _award_literacy_round(attempt_no)
        %LiteracyStatusLabel.text = "BERHASIL"
        %ChallengeFeedback.text = (
            "HEBAT! Kamu berhasil menghemat Koin dan melengkapi kelompok Buah."
        )
        _clear_container(%ChallengeChoiceTray)
        UIMotion.play_reward(%ChallengeFeedback)
        _schedule_literacy_auto_advance()
        return

    AudioManager.play_sfx("wrong")

    if r3_replacement_id != str(round_data.get("correct_replacement_id", "")):
        %ChallengeFeedback.text = (
            "Penggantian sebelumnya belum tepat. Coba kembali dari Langkah 1."
        )
    else:
        %ChallengeFeedback.text = (
            "Buah ini belum sesuai dengan Koin yang tersedia. Coba kembali."
        )

    UIMotion.play_shake(%ChallengeFeedback, 5.0)
    r3_freed_coin = 0
    r3_replacement_id = ""
    _render_rearrange_step_one(round_data)
    DurationTracker.resume_active_play()


func _register_rearrange_invalid(
    selected_id: String,
    message: String
) -> void:
    AudioManager.play_sfx("wrong")
    DurationTracker.pause_active_play()

    var round_data: Dictionary = (
        level_config.get("literacy_rounds", [])[literacy_round_index]
    )
    var round_id := str(round_data.get("round_id", ""))
    literacy_attempts[round_id] = int(literacy_attempts.get(round_id, 0)) + 1

    %ChallengeFeedback.text = message
    UIMotion.play_shake(%ChallengeFeedback, 5.0)

    AnalyticsLogger.log_event(
        "literacy_answer",
        {
            "level_no": 3,
            "literacy_round": 3,
            "selected_answer": selected_id,
            "correct": false,
            "attempt_no": literacy_attempts[round_id]
        }
    )

    r3_freed_coin = 0
    r3_replacement_id = ""
    _render_rearrange_step_one(round_data)
    DurationTracker.resume_active_play()


func _add_visual_food_option(
    food_id: String,
    button_caption: String,
    pressed_callback: Callable
) -> void:
    var food := ContentDatabase.get_food(food_id)

    var option := VBoxContainer.new()
    option.custom_minimum_size = Vector2(144, 148)
    option.alignment = BoxContainer.ALIGNMENT_CENTER
    option.add_theme_constant_override("separation", 4)
    %ChallengeChoiceTray.add_child(option)

    var card: FoodCard = FOOD_CARD_SCENE.instantiate()
    option.add_child(card)
    card.setup(
        food_id,
        str(food.get("display_name", "")),
        str(food.get("group_id", "")),
        int(food.get("coin_value", 0)),
        false,
        true
    )
    card.set_static_preview()
    _style_literacy_card(card, true)

    var button := Button.new()
    button.text = button_caption
    option.add_child(button)
    _style_literacy_action_button(button)
    button.pressed.connect(pressed_callback)
    UIMotion.bind_button(button)
    UIMotion.play_pop(option, 1.02)


func _style_literacy_card(
    card: FoodCard,
    compact: bool
) -> void:
    card.custom_minimum_size = (
        Vector2(116, 102)
        if compact
        else Vector2(126, 126)
    )

    var glyph: Control = card.get_node_or_null("%Glyph") as Control

    if glyph != null:
        glyph.custom_minimum_size = (
            Vector2(106, 72)
            if compact
            else Vector2(116, 92)
        )

    var name_label: Label = card.get_node_or_null("%NameLabel") as Label

    if name_label != null:
        name_label.visible = false

    var coin_label: Label = card.get_node_or_null("%CoinLabel") as Label

    if coin_label != null:
        coin_label.visible = true
        coin_label.add_theme_font_size_override(
            "font_size",
            16 if compact else 19
        )
        coin_label.add_theme_color_override(
            "font_color",
            Color(0.055, 0.36, 0.22, 1)
        )
        coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_literacy_drop_slot(slot: Control) -> void:
    slot.custom_minimum_size = Vector2(270, 176)
    _apply_label_theme_recursive(slot, 18)

    var holder := slot.get_node_or_null("VBox/Holder") as CenterContainer

    if holder != null:
        holder.custom_minimum_size = Vector2(0, 126)


func _style_literacy_action_button(button: Button) -> void:
    button.custom_minimum_size = Vector2(138, 38)
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override(
        "font_color",
        Color(0.055, 0.30, 0.19, 1)
    )
    button.add_theme_color_override(
        "font_hover_color",
        Color(0.055, 0.30, 0.19, 1)
    )
    button.add_theme_color_override(
        "font_pressed_color",
        Color.WHITE
    )
    button.add_theme_stylebox_override(
        "normal",
        _make_literacy_option_style(
            Color(0.90, 0.95, 0.84, 1)
        )
    )
    button.add_theme_stylebox_override(
        "hover",
        _make_literacy_option_style(
            Color(0.96, 0.96, 0.04, 1)
        )
    )
    button.add_theme_stylebox_override(
        "pressed",
        _make_literacy_option_style(
            Color(0.055, 0.39, 0.24, 1)
        )
    )


func _make_literacy_option_style(
    background_color: Color
) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background_color
    style.border_color = Color(0.055, 0.36, 0.22, 1)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_left = 12
    style.corner_radius_bottom_right = 12
    return style


func _find_initial_food_by_group(
    round_data: Dictionary,
    group_id: String
) -> Dictionary:
    for food_id_value in round_data.get("initial_ids", []):
        var initial_food := ContentDatabase.get_food(str(food_id_value))

        if str(initial_food.get("group_id", "")) == group_id:
            return initial_food

    return {}


func _apply_label_theme_recursive(
    node: Node,
    font_size: int
) -> void:
    if node is Label:
        var label := node as Label
        label.add_theme_font_size_override("font_size", font_size)
        label.add_theme_color_override(
            "font_color",
            Color(0.055, 0.30, 0.19, 1)
        )
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    for child in node.get_children():
        _apply_label_theme_recursive(child, font_size)


func _refresh_literacy_sidebar() -> void:
    %LiteracyScoreLabel.text = "%d / 30" % literacy_score
    %LiteracyRoundLabel.text = "%d / 3" % [literacy_round_index + 1]


func _award_literacy_round(attempt_no: int) -> void:
    var scoring: Dictionary = level_config.get("scoring", {})
    literacy_score += (
        int(scoring.get("literacy_first_attempt", 10))
        if attempt_no == 1
        else int(scoring.get("literacy_after_retry", 5))
    )
    _refresh_literacy_sidebar()


func _schedule_literacy_auto_advance() -> void:
    if literacy_transition_pending:
        return

    literacy_transition_pending = true
    %LiteracyStatusLabel.text = "LANJUT OTOMATIS..."

    var transition_timer := get_tree().create_timer(1.8)
    transition_timer.timeout.connect(_on_literacy_auto_advance_timeout)


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
    else:
        _show_result()

func _show_result() -> void:
    set_state("RESULT")
    var duration_ms := DurationTracker.finish_level_session()
    final_score = main_score + literacy_score + int(level_config.get("scoring", {}).get("completion", 10))
    level_session["active_duration_ms"] = duration_ms
    level_session["completed_at"] = Time.get_unix_time_from_system()
    GameState.update_level_session(level_session)
    show_only(screens, result_panel)
    UIMotion.play_pop(result_panel, 1.03)
    %ResultScore.text = "%d / 100" % final_score
    %ResultSummary.text = "Belanja: 4/4 kelompok\nLiteracy Challenge: 3/3 ronde\nDurasi aktif: %s" % _format_ms(duration_ms)

func _show_info() -> void:
    set_state("FOOD_INFORMATION")
    info_index = 0
    show_only(screens, info_panel)
    _render_info()

func _render_info() -> void:
    var food: Dictionary = foods[info_index]
    %InfoImage.texture = _load_level3_food_information_texture(food)
    %InfoTitle.text = str(food.get("display_name", ""))
    %InfoGroup.text = "Kelompok: %s" % str(food.get("group_name", ""))
    %InfoCoin.text = "Nilai Koin Pangan dalam game: %d" % int(food.get("coin_value", 0))
    %InfoText.text = str(food.get("info_level_03", ""))
    %InfoCounter.text = "%d / %d" % [info_index + 1, foods.size()]
    %InfoNextButton.text = "LANJUT" if info_index < foods.size()-1 else "SELESAI"


func _load_level3_food_information_texture(
    food: Dictionary
) -> Texture2D:
    var food_id: String = str(food.get("food_id", "")).strip_edges()
    var texture_path: String = str(
        FoodGlyph.FOOD_TEXTURE_PATHS.get(food_id, "")
    ).strip_edges()

    if texture_path.is_empty():
        return null

    if not ResourceLoader.exists(texture_path):
        return null

    var resource: Resource = load(texture_path)

    if resource is Texture2D:
        return resource as Texture2D

    return null


func _advance_info() -> void:
    if info_index < foods.size()-1:
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
    GameState.complete_level(3, final_score, duration_ms, str(badge.get("badge_id", "badge_level_03")), str(badge.get("display_name", "Perencana Belanja Pangan")), str(level_session.get("level_session_id", "")))
    SceneRouter.goto("main_map")

func _show_feedback(text: String, correct: bool) -> void:
    %FeedbackToast.text = text
    %FeedbackToast.visible = true

    if correct:
        UIMotion.play_pop(%FeedbackToast, 1.04)
    else:
        UIMotion.play_shake(%FeedbackToast, 5.0)

    var tween := create_tween()
    tween.tween_interval(1.3)
    tween.tween_callback(func(): %FeedbackToast.visible = false)

func _short_group_name(group_id: String) -> String:
    match group_id:
        "group_staple_root": return "Pokok/Umbi"
        "group_vegetable": return "Sayuran"
        "group_fruit": return "Buah"
        "group_fishery": return "Hasil Perikanan"
    return group_id

func _clear_container(container: Node) -> void:
    for child in container.get_children():
        child.queue_free()

func _format_ms(ms: int) -> String:
    var total_seconds := int(round(ms / 1000.0))
    return "%02d:%02d" % [int(total_seconds / 60.0), total_seconds % 60]

func _ensure_level_runtime_ready() -> bool:
    if not ContentDatabase.initialize():
        push_error("Level 3 gagal menginisialisasi ContentDatabase.")
        return false

    SettingsManager.initialize()

    if not GameState.initialized:
        GameState.initialize()

    AnalyticsLogger.initialize()
    return true
