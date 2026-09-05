class_name OrderController
extends Node

var scoring: Dictionary = {}
var attempt_id := ""
var attempt_index := 0
var main_score := 0
var current_order: Dictionary = {}
var current_pair_attempts := 0
var current_process_attempts := 0
var current_pair_correct := false
var current_process_correct := false
var current_order_score := 0
var completed_orders: Array[Dictionary] = []
var hint_used := false

func configure(level_config: Dictionary) -> void:
    scoring = level_config.get("scoring", {}).duplicate(true)

func begin_main_attempt(new_attempt_id: String, new_attempt_index: int) -> void:
    attempt_id = new_attempt_id
    attempt_index = new_attempt_index
    main_score = 0
    completed_orders.clear()
    current_order = {}
    current_pair_attempts = 0
    current_process_attempts = 0
    current_pair_correct = false
    current_process_correct = false
    current_order_score = 0
    hint_used = false

func begin_order(order_data: Dictionary) -> void:
    current_order = order_data.duplicate(true)
    current_pair_attempts = 0
    current_process_attempts = 0
    current_pair_correct = false
    current_process_correct = false
    current_order_score = 0
    hint_used = false

func validate_pair(food_a_id: String, food_b_id: String) -> Dictionary:
    if current_pair_correct:
        return {"correct":true, "attempt_no":current_pair_attempts, "score_awarded":0}
    current_pair_attempts += 1
    var selected := [food_a_id, food_b_id]
    selected.sort()
    var required := [str(current_order.get("ingredient_1_id", "")), str(current_order.get("ingredient_2_id", ""))]
    required.sort()
    var correct := selected == required
    var score_awarded := 0
    if correct:
        current_pair_correct = true
        score_awarded = int(scoring.get("ingredient_first_attempt", 10)) if current_pair_attempts == 1 else int(scoring.get("ingredient_after_retry", 5))
        current_order_score += score_awarded
    return {"correct":correct, "attempt_no":current_pair_attempts, "score_awarded":score_awarded}

func validate_process(process_id: String) -> Dictionary:
    if not current_pair_correct:
        return {"correct":false, "attempt_no":current_process_attempts, "score_awarded":0, "blocked":true}
    if current_process_correct:
        return {"correct":true, "attempt_no":current_process_attempts, "score_awarded":0, "blocked":false}
    current_process_attempts += 1
    var correct := process_id == str(current_order.get("process_id", ""))
    var score_awarded := 0
    if correct:
        current_process_correct = true
        score_awarded = int(scoring.get("process_first_attempt", 5)) if current_process_attempts == 1 else int(scoring.get("process_after_retry", 3))
        current_order_score += score_awarded
    return {"correct":correct, "attempt_no":current_process_attempts, "score_awarded":score_awarded, "blocked":false}

func can_complete_order() -> bool:
    return current_pair_correct and current_process_correct

func complete_current_order(timer_remaining: int) -> Dictionary:
    var metric := {
        "order_id":str(current_order.get("order_id", "")),
        "result_id":str(current_order.get("result_id", "")),
        "ingredient_pair_attempts":current_pair_attempts,
        "process_attempts":current_process_attempts,
        "hint_used":hint_used,
        "remaining_time":timer_remaining,
        "order_score":current_order_score,
        "completed":true
    }
    completed_orders.append(metric)
    main_score += current_order_score
    return metric

func mark_hint_used() -> void:
    hint_used = true

func attempt_snapshot(status: String, timer_remaining: int) -> Dictionary:
    return {
        "attempt_id":attempt_id,
        "attempt_index":attempt_index,
        "status":status,
        "score_snapshot":main_score,
        "current_order_id":str(current_order.get("order_id", "")),
        "current_pair_attempts":current_pair_attempts,
        "current_process_attempts":current_process_attempts,
        "timer_remaining":timer_remaining,
        "completed_orders":completed_orders.duplicate(true)
    }
