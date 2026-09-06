class_name MatchingController
extends Node

const V3_GAME_ID: String = "L1-G01"
const V3_GAME_TYPE: String = "matching_drag_drop"
const V3_INSTRUCTION_ID: String = "INST-L1-G01-MATCH"
const V3_INSTRUCTION_TEXT: String = "Misi: Cocokkan gambar pangan dengan namanya."

signal progress_changed(matched: int, total: int, score: int)
signal all_matched(score: int)
signal feedback(text: String, correct: bool)

var config: Dictionary = {}
var foods: Array[Dictionary] = []
var cards_by_id: Dictionary = {}
var slots_by_id: Dictionary = {}
var attempts_by_food: Dictionary = {}
var matched_ids: Array[String] = []
var score := 0

func configure(level_config: Dictionary, food_data: Array[Dictionary]) -> void:
    config = level_config
    foods = food_data
    attempts_by_food.clear()
    matched_ids.clear()
    score = 0
    for food in foods:
        attempts_by_food[str(food.get("food_id", ""))] = 0

func register_card(food_id: String, card: FoodCard) -> void:
    cards_by_id[food_id] = card

func register_slot(food_id: String, slot: FoodDropSlot) -> void:
    slots_by_id[food_id] = slot
    slot.drop_received.connect(_on_drop_received)

func _on_drop_received(food_id: String, card: FoodCard, slot: FoodDropSlot) -> void:
    if food_id in matched_ids:
        return
    attempts_by_food[food_id] = int(attempts_by_food.get(food_id, 0)) + 1
    var attempt_no := int(attempts_by_food[food_id])
    var correct := food_id == slot.accepted_food_id
    AnalyticsLogger.log_event("drag_attempt", {
        "level_session_id": DurationTracker.session_id,
        "level_no": 1,
        "food_id": food_id,
        "target_id": slot.accepted_food_id,
        "correct": correct,
        "attempt_no": attempt_no
    })
    if correct:
        var scoring: Dictionary = config.get("scoring", {})
        score += int(scoring.get("food_first_attempt", 10)) if attempt_no == 1 else int(scoring.get("food_after_retry", 5))
        _record_v3_drop(food_id, card, slot, "correct_drop")
        matched_ids.append(food_id)
        slot.accept_card(card)
        UIMotion.play_pop(card, 1.06)
        UIMotion.play_pop(slot, 1.035)
        feedback.emit("Cocok!", true)
        progress_changed.emit(matched_ids.size(), foods.size(), score)
        if matched_ids.size() == foods.size():
            all_matched.emit(score)
    else:
        _record_v3_drop(food_id, card, slot, "wrong_target_drop")
        card.show_wrong_feedback()
        UIMotion.play_shake(card, 6.0)
        feedback.emit("Belum cocok. Coba lihat kembali nama pangannya.", false)

func request_hint() -> void:
    for food in foods:
        var food_id := str(food.get("food_id", ""))
        if food_id not in matched_ids and slots_by_id.has(food_id):
            var slot: FoodDropSlot = slots_by_id[food_id]
            slot.pulse_hint()
            AnalyticsLogger.log_event("hint_used", {"level_no":1, "context_id":food_id})
            TelemetryManager.record_hint_event(
                1,
                V3_GAME_ID,
                V3_GAME_TYPE,
                food_id
            )
            feedback.emit("Coba lihat nama yang sedang ditandai.", true)
            return

func _record_v3_drop(
    food_id: String,
    card: FoodCard,
    slot: FoodDropSlot,
    result: String
) -> void:
    var drag_started_ticks_ms: Variant = null
    if card.has_meta("spl_drag_started_ticks_ms"):
        drag_started_ticks_ms = int(card.get_meta("spl_drag_started_ticks_ms"))

    var drag_started_at_unix: Variant = null
    if card.has_meta("spl_drag_started_at_unix"):
        drag_started_at_unix = card.get_meta("spl_drag_started_at_unix")

    var dropped_ticks_ms: int = Time.get_ticks_msec()
    var decision_duration_ms: Variant = null
    if drag_started_ticks_ms != null:
        var started_ticks_ms: int = int(drag_started_ticks_ms)
        if dropped_ticks_ms >= started_ticks_ms:
            decision_duration_ms = dropped_ticks_ms - started_ticks_ms
    var expected_food_id: String = food_id
    var dropped_food_id: String = slot.accepted_food_id
    var context: Dictionary = {
        "level_no": 1,
        "game_id": V3_GAME_ID,
        "game_type": V3_GAME_TYPE,
        "result": result,
        "current_score": score,
        "instruction": {
            "instruction_id": V3_INSTRUCTION_ID,
            "instruction_version": 1,
            "instruction_text": V3_INSTRUCTION_TEXT,
            "content_version": ContentDatabase.content_version
        },
        "dragged_item": {
            "food_id": food_id,
            "food_name_snapshot": _food_display_name(food_id)
        },
        "drop_result": {
            "dropped_target_id": "L1-TARGET-" + dropped_food_id,
            "dropped_target_name_snapshot": _food_display_name(dropped_food_id),
            "expected_target_ids": ["L1-TARGET-" + expected_food_id],
            "expected_target_name_snapshot": _food_display_name(expected_food_id)
        },
        "timing": {
            "drag_started_at_unix": drag_started_at_unix,
            "drag_started_ticks_ms": drag_started_ticks_ms,
            "dropped_at_ticks_ms": dropped_ticks_ms,
            "decision_duration_ms": decision_duration_ms
        },
        "input_method": "unknown"
    }
    if not TelemetryManager.record_drop_event(context):
        push_warning("Telemetry v3 Level 1 Game 1 belum dapat merekam drop event.")
func _food_display_name(food_id: String) -> String:
    for food in foods:
        if str(food.get("food_id", "")) == food_id:
            return str(food.get("display_name", food_id))
    return food_id
