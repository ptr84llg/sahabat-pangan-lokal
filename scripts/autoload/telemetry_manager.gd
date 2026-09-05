extends Node
const SCHEMA_VERSION: int = 3
const L1_MAIN_GAME_ID: String = "L1-G01"
func begin_game(
    level_no: int,
    game_id: String,
    game_type: String,
    instruction: Dictionary = {}
) -> bool:
    var current: Dictionary = SaveManager.load_v3_active_current()
    if current.is_empty():
        return false
    var game: Dictionary = _ensure_game(current, level_no, game_id, game_type)
    if game.is_empty():
        return false
    var status: String = str(game.get("status", ""))
    if status != "in_progress":
        _start_new_attempt(game)
    if not instruction.is_empty():
        var mechanic_data: Dictionary = game.get("mechanic_data", {})
        mechanic_data["active_instruction"] = instruction.duplicate(true)
        game["mechanic_data"] = mechanic_data
    game["status"] = "in_progress"
    game["last_resumed_at_unix"] = Time.get_unix_time_from_system()
    return SaveManager.commit_v3_native_current(current)
func record_drop_event(context: Dictionary) -> bool:
    var level_no: int = int(context.get("level_no", 0))
    var game_id: String = str(context.get("game_id", "")).strip_edges()
    var game_type: String = str(context.get("game_type", "")).strip_edges()
    var result: String = str(context.get("result", "")).strip_edges()
    if level_no <= 0 or game_id.is_empty() or game_type.is_empty():
        return false
    if result != "correct_drop" and result != "wrong_target_drop" and result != "invalid_drop":
        return false
    var current: Dictionary = SaveManager.load_v3_active_current()
    if current.is_empty():
        return false
    var game: Dictionary = _ensure_game(current, level_no, game_id, game_type)
    if game.is_empty():
        return false
    var attempt_id: String = _ensure_active_attempt(game)
    var event_id: String = IdUtil.uuid_v4()
    var drop_event_id: String = "DROP-" + IdUtil.uuid_v4()
    var event: Dictionary = {
        "event_id": event_id,
        "drop_event_id": drop_event_id,
        "schema_version": SCHEMA_VERSION,
        "event_type": "drop",
        "result": result,
        "timestamp_unix": Time.get_unix_time_from_system(),
        "content_version": ContentDatabase.content_version,
        "level_id": "L" + str(level_no),
        "game_id": game_id,
        "round_id": context.get("round_id", null),
        "section_id": context.get("section_id", null),
        "attempt_id": attempt_id,
        "instruction": context.get("instruction", {}).duplicate(true),
        "dragged_item": context.get("dragged_item", {}).duplicate(true),
        "drop_result": context.get("drop_result", {}).duplicate(true),
        "timing": context.get("timing", {}).duplicate(true),
        "input_method": str(context.get("input_method", "unknown"))
    }
    var events: Array = game.get("interaction_events", [])
    events.append(event.duplicate(true))
    game["interaction_events"] = events
    var metrics: Dictionary = game.get("interaction_metrics", {})
    metrics["drag_count"] = int(metrics.get("drag_count", 0)) + 1
    if result == "correct_drop":
        metrics["correct_drop_count"] = int(metrics.get("correct_drop_count", 0)) + 1
    elif result == "wrong_target_drop":
        metrics["wrong_target_drop_count"] = int(metrics.get("wrong_target_drop_count", 0)) + 1
    else:
        metrics["invalid_drop_count"] = int(metrics.get("invalid_drop_count", 0)) + 1
    game["interaction_metrics"] = metrics
    var mechanic_data: Dictionary = game.get("mechanic_data", {})
    var attempts_by_food: Dictionary = mechanic_data.get("attempts_by_food", {})
    var dragged_item: Dictionary = event.get("dragged_item", {})
    var food_id: String = str(dragged_item.get("food_id", "")).strip_edges()
    if not food_id.is_empty():
        attempts_by_food[food_id] = int(attempts_by_food.get(food_id, 0)) + 1
    mechanic_data["attempts_by_food"] = attempts_by_food
    mechanic_data["last_drop_result"] = result
    mechanic_data["last_drop_event_id"] = drop_event_id
    mechanic_data["current_score"] = int(context.get("current_score", 0))
    game["mechanic_data"] = mechanic_data
    var score_block: Dictionary = game.get("score", {})
    score_block["current_score"] = int(context.get("current_score", 0))
    game["score"] = score_block
    if not SaveManager.commit_v3_native_current(current):
        return false
    var queue_ok: bool = SaveManager.append_v3_pending_event(event)
    if not queue_ok:
        push_warning("Event v3 sudah tersimpan pada current, tetapi pending queue gagal diperbarui.")
    if not SaveManager.refresh_v3_sync_metadata():
        push_warning("Metadata sync v3 gagal diperbarui setelah drop event.")
    return true
func record_hint_event(
    level_no: int,
    game_id: String,
    game_type: String,
    context_id: String
) -> bool:
    var current: Dictionary = SaveManager.load_v3_active_current()
    if current.is_empty():
        return false
    var game: Dictionary = _ensure_game(current, level_no, game_id, game_type)
    if game.is_empty():
        return false
    var attempt_id: String = _ensure_active_attempt(game)
    var event: Dictionary = {
        "event_id": IdUtil.uuid_v4(),
        "schema_version": SCHEMA_VERSION,
        "event_type": "hint",
        "result": "hint_used",
        "timestamp_unix": Time.get_unix_time_from_system(),
        "content_version": ContentDatabase.content_version,
        "level_id": "L" + str(level_no),
        "game_id": game_id,
        "attempt_id": attempt_id,
        "context_id": context_id
    }
    var events: Array = game.get("interaction_events", [])
    events.append(event.duplicate(true))
    game["interaction_events"] = events
    var metrics: Dictionary = game.get("interaction_metrics", {})
    metrics["hint_click_count"] = int(metrics.get("hint_click_count", 0)) + 1
    game["interaction_metrics"] = metrics
    if not SaveManager.commit_v3_native_current(current):
        return false
    var queue_ok: bool = SaveManager.append_v3_pending_event(event)
    if not queue_ok:
        push_warning("Hint v3 tersimpan pada current, tetapi pending queue gagal diperbarui.")
    SaveManager.refresh_v3_sync_metadata()
    return true
func complete_game(
    level_no: int,
    game_id: String,
    game_type: String,
    final_score: int,
    total_duration_ms: int
) -> bool:
    var current: Dictionary = SaveManager.load_v3_active_current()
    if current.is_empty():
        return false
    var game: Dictionary = _ensure_game(current, level_no, game_id, game_type)
    if game.is_empty():
        return false
    var attempt_id: String = _ensure_active_attempt(game)
    var now_unix: float = Time.get_unix_time_from_system()
    game["status"] = "completed"
    game["completed_at_unix"] = now_unix
    game["total_duration_ms"] = maxi(0, total_duration_ms)
    var score_block: Dictionary = game.get("score", {})
    score_block["current_score"] = final_score
    score_block["final_score"] = final_score
    game["score"] = score_block
    var attempts: Array = game.get("attempts", [])
    for index in range(attempts.size()):
        var attempt_value: Variant = attempts[index]
        if not attempt_value is Dictionary:
            continue
        var attempt: Dictionary = attempt_value
        if str(attempt.get("attempt_id", "")) == attempt_id:
            attempt["status"] = "completed"
            attempt["completed_at_unix"] = now_unix
            attempt["final_score"] = final_score
            attempt["duration_ms"] = maxi(0, total_duration_ms)
            attempts[index] = attempt
            break
    game["attempts"] = attempts
    game["active_attempt_id"] = ""
    game["game_summary"] = _build_game_summary(game)
    var event: Dictionary = {
        "event_id": IdUtil.uuid_v4(),
        "schema_version": SCHEMA_VERSION,
        "event_type": "game_completed",
        "result": "completed",
        "timestamp_unix": now_unix,
        "content_version": ContentDatabase.content_version,
        "level_id": "L" + str(level_no),
        "game_id": game_id,
        "attempt_id": attempt_id,
        "final_score": final_score,
        "total_duration_ms": maxi(0, total_duration_ms)
    }
    var events: Array = game.get("interaction_events", [])
    events.append(event.duplicate(true))
    game["interaction_events"] = events
    if not SaveManager.commit_v3_native_current(current):
        return false
    var queue_ok: bool = SaveManager.append_v3_pending_event(event)
    if not queue_ok:
        push_warning("Game completion v3 tersimpan pada current, tetapi pending queue gagal diperbarui.")
    SaveManager.refresh_v3_sync_metadata()
    return true
func _ensure_game(
    current: Dictionary,
    level_no: int,
    game_id: String,
    game_type: String
) -> Dictionary:
    var levels: Dictionary = current.get("levels", {})
    var level_key: String = str(level_no)
    var level: Dictionary = levels.get(level_key, {})
    if level.is_empty():
        return {}
    var games: Dictionary = level.get("games", {})
    var game: Dictionary = games.get(game_id, {})
    if game.is_empty():
        game = _new_game(game_id, game_type)
        games[game_id] = game
        level["games"] = games
        levels[level_key] = level
        current["levels"] = levels
    elif str(game.get("game_type", "")) != game_type:
        return {}
    _hydrate_game(game)
    return game
func _hydrate_game(game: Dictionary) -> void:
    if game.get("status", null) == null:
        game["status"] = "not_started"
    if game.get("started_at_unix", null) == null:
        game["started_at_unix"] = 0.0
    if game.get("completed_at_unix", null) == null:
        game["completed_at_unix"] = 0.0
    if game.get("total_duration_ms", null) == null:
        game["total_duration_ms"] = 0
    if game.get("attempt_count", null) == null:
        game["attempt_count"] = 0
    if game.get("active_attempt_id", null) == null:
        game["active_attempt_id"] = ""

    var score_value: Variant = game.get("score", null)
    if not score_value is Dictionary:
        game["score"] = {
            "current_score": 0,
            "final_score": 0
        }
    else:
        var score: Dictionary = score_value
        if score.get("current_score", null) == null:
            score["current_score"] = 0
        if score.get("final_score", null) == null:
            score["final_score"] = 0
        game["score"] = score

    var metrics_value: Variant = game.get("interaction_metrics", null)
    if not metrics_value is Dictionary:
        game["interaction_metrics"] = _empty_metrics()
    else:
        var metrics: Dictionary = metrics_value
        var metric_keys: Array = [
            "drag_count",
            "correct_drop_count",
            "wrong_target_drop_count",
            "invalid_drop_count",
            "wrong_answer_count",
            "in_game_reset_click_count",
            "back_to_map_click_count",
            "hint_click_count"
        ]

        for metric_key_value in metric_keys:
            var metric_key: String = str(metric_key_value)

            if metrics.get(metric_key, null) == null:
                metrics[metric_key] = 0

        game["interaction_metrics"] = metrics

    if not game.get("attempts", null) is Array:
        game["attempts"] = []
    if not game.get("interaction_events", null) is Array:
        game["interaction_events"] = []
    if not game.get("mechanic_data", null) is Dictionary:
        game["mechanic_data"] = {}
    if not game.get("game_summary", null) is Dictionary:
        game["game_summary"] = {}

    var notes_value: Variant = game.get("implementation_notes", null)

    if notes_value is Dictionary:
        var notes: Dictionary = notes_value
        notes["v3_telemetry_status"] = "active"
        notes["last_activated_at_unix"] = Time.get_unix_time_from_system()
        game["implementation_notes"] = notes

func _empty_metrics() -> Dictionary:
    return {
        "drag_count": 0,
        "correct_drop_count": 0,
        "wrong_target_drop_count": 0,
        "invalid_drop_count": 0,
        "wrong_answer_count": 0,
        "in_game_reset_click_count": 0,
        "back_to_map_click_count": 0,
        "hint_click_count": 0
    }

func _new_game(game_id: String, game_type: String) -> Dictionary:
    return {
        "game_id": game_id,
        "game_type": game_type,
        "status": "not_started",
        "started_at_unix": 0.0,
        "completed_at_unix": 0.0,
        "total_duration_ms": 0,
        "attempt_count": 0,
        "active_attempt_id": "",
        "score": {
            "current_score": 0,
            "final_score": 0
        },
        "interaction_metrics": _empty_metrics(),
        "attempts": [],
        "rounds_or_sections": [],
        "questions": [],
        "interaction_events": [],
        "mechanic_data": {},
        "game_summary": {}
    }
func _ensure_active_attempt(game: Dictionary) -> String:
    var active_attempt_id: String = str(
        game.get("active_attempt_id", "")
    ).strip_edges()
    if not active_attempt_id.is_empty():
        return active_attempt_id
    return _start_new_attempt(game)
func _start_new_attempt(game: Dictionary) -> String:
    var attempts: Array = game.get("attempts", [])
    var attempt_no: int = attempts.size() + 1
    var attempt_id: String = "ATT-" + IdUtil.uuid_v4()
    var now_unix: float = Time.get_unix_time_from_system()
    var attempt: Dictionary = {
        "attempt_id": attempt_id,
        "attempt_no": attempt_no,
        "status": "in_progress",
        "started_at_unix": now_unix,
        "completed_at_unix": 0.0,
        "score_before_reset": 0,
        "final_score": 0,
        "duration_ms": 0
    }
    attempts.append(attempt)
    game["attempts"] = attempts
    game["attempt_count"] = attempts.size()
    game["active_attempt_id"] = attempt_id
    game["status"] = "in_progress"
    if float(game.get("started_at_unix", 0.0)) <= 0.0:
        game["started_at_unix"] = now_unix
    return attempt_id
func _build_game_summary(game: Dictionary) -> Dictionary:
    var metrics: Dictionary = game.get("interaction_metrics", {})
    var score_block: Dictionary = game.get("score", {})
    return {
        "final_score": int(score_block.get("final_score", 0)),
        "total_duration_ms": int(game.get("total_duration_ms", 0)),
        "total_attempt": int(game.get("attempt_count", 0)),
        "total_correct": int(metrics.get("correct_drop_count", 0)),
        "total_wrong": int(metrics.get("wrong_target_drop_count", 0)),
        "total_invalid": int(metrics.get("invalid_drop_count", 0)),
        "total_hint": int(metrics.get("hint_click_count", 0)),
        "total_reset": int(metrics.get("in_game_reset_click_count", 0)),
        "total_back_to_map": int(metrics.get("back_to_map_click_count", 0))
    }
