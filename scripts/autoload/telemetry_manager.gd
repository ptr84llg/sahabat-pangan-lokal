extends Node
const SCHEMA_VERSION: int = 3
const L1_MAIN_GAME_ID: String = "L1-G01"
func begin_level_attempt(level_no: int) -> Dictionary:
    if level_no <= 0:
        return {}

    var current: Dictionary = SaveManager.load_v3_active_current()

    if current.is_empty():
        return {}

    var level: Dictionary = _ensure_level_container(
        current,
        level_no
    )

    if level.is_empty():
        return {}

    _close_interrupted_level_attempt(level)

    var attempt: Dictionary = _create_level_attempt(
        level
    )

    if attempt.is_empty():
        return {}

    _store_level_container(
        current,
        level_no,
        level
    )

    if not SaveManager.commit_v3_native_current(current):
        return {}

    return attempt.duplicate(true)


func begin_game(
    level_no: int,
    game_id: String,
    game_type: String,
    instruction: Dictionary = {}
) -> bool:
    var current: Dictionary = SaveManager.load_v3_active_current()

    if current.is_empty():
        return false

    var level_attempt: Dictionary = _ensure_level_attempt(
        current,
        level_no
    )

    if level_attempt.is_empty():
        return false

    var level_attempt_id: String = str(
        level_attempt.get("level_attempt_id", "")
    ).strip_edges()
    var game: Dictionary = _ensure_game(
        current,
        level_no,
        game_id,
        game_type
    )

    if game.is_empty():
        return false

    var status: String = str(game.get("status", ""))
    var active_level_attempt_id: String = (
        _resolve_active_game_attempt_level_id(game)
    )

    if (
        status != "in_progress"
        or active_level_attempt_id != level_attempt_id
    ):
        _start_new_attempt(game)

    if not _bind_active_game_attempt_to_level(
        game,
        level_attempt_id
    ):
        return false

    if not instruction.is_empty():
        var mechanic_data: Dictionary = game.get(
            "mechanic_data",
            {}
        )
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
    var score_snapshot: Dictionary = game.get("score", {})
    var score_before_event: int = int(
        score_snapshot.get("current_score", 0)
    )
    var score_after_event: int = int(
        context.get("current_score", score_before_event)
    )
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
        "input_method": str(context.get("input_method", "unknown")),
        "score_before_event": score_before_event,
        "score_after_event": score_after_event,
        "score_delta": score_after_event - score_before_event
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
func begin_question_occurrence(
    level_no: int,
    game_id: String,
    game_type: String,
    question_id: String,
    question_order: int,
    question_version: int,
    displayed_options: Array
) -> String:
    if level_no <= 0:
        return ""
    if game_id.strip_edges().is_empty() or game_type.strip_edges().is_empty():
        return ""
    if question_id.strip_edges().is_empty():
        return ""

    var current: Dictionary = SaveManager.load_v3_active_current()
    if current.is_empty():
        return ""

    var game: Dictionary = _ensure_game(current, level_no, game_id, game_type)
    if game.is_empty():
        return ""

    var attempt_id: String = _ensure_active_attempt(game)
    if attempt_id.is_empty():
        return ""

    var questions: Array = game.get("questions", [])
    var occurrence_id: String = "QO-" + IdUtil.uuid_v4()
    var question_entry: Dictionary = {
        "question_id": question_id,
        "question_occurrence_id": occurrence_id,
        "question_order": question_order,
        "question_version": question_version,
        "displayed_options": displayed_options.duplicate(true),
        "selected_answer_id": null,
        "correct_answer_id": null,
        "result": null,
        "response_time_ms": null,
        "hint_used": false,
        "timeout": false,
        "answered_at": null
    }

    var placeholder_index: int = _find_question_placeholder_index(
        questions,
        question_id
    )

    if placeholder_index >= 0:
        questions[placeholder_index] = question_entry
    else:
        questions.append(question_entry)

    game["questions"] = questions

    var mechanic_data: Dictionary = game.get("mechanic_data", {})
    mechanic_data["active_question_id"] = question_id
    mechanic_data["active_question_occurrence_id"] = occurrence_id
    mechanic_data["active_question_started_ticks_ms"] = Time.get_ticks_msec()
    mechanic_data["active_question_started_at_unix"] = Time.get_unix_time_from_system()
    game["mechanic_data"] = mechanic_data

    if not SaveManager.commit_v3_native_current(current):
        return ""

    return occurrence_id

func record_question_answer(
    level_no: int,
    game_id: String,
    game_type: String,
    selected_answer_id: String,
    correct_answer_id: String,
    current_score: int,
    hint_used: bool = false
) -> bool:
    if level_no <= 0:
        return false
    if game_id.strip_edges().is_empty() or game_type.strip_edges().is_empty():
        return false
    if selected_answer_id.strip_edges().is_empty():
        return false
    if correct_answer_id.strip_edges().is_empty():
        return false

    var current: Dictionary = SaveManager.load_v3_active_current()
    if current.is_empty():
        return false

    var game: Dictionary = _ensure_game(current, level_no, game_id, game_type)
    if game.is_empty():
        return false

    var attempt_id: String = _ensure_active_attempt(game)
    if attempt_id.is_empty():
        return false

    var mechanic_data: Dictionary = game.get("mechanic_data", {})
    var occurrence_id: String = str(
        mechanic_data.get("active_question_occurrence_id", "")
    ).strip_edges()

    if occurrence_id.is_empty():
        return false

    var questions: Array = game.get("questions", [])
    var question_index: int = _find_question_occurrence_index(
        questions,
        occurrence_id
    )

    if question_index < 0:
        return false

    var question_value: Variant = questions[question_index]
    if not question_value is Dictionary:
        return false

    var question: Dictionary = question_value
    var now_unix: float = Time.get_unix_time_from_system()
    var now_ticks_ms: int = Time.get_ticks_msec()
    var response_time_ms: int = 0
    var started_ticks_value: Variant = mechanic_data.get(
        "active_question_started_ticks_ms",
        null
    )

    var use_unix_fallback: bool = true

    if started_ticks_value != null:
        var started_ticks_ms: int = int(started_ticks_value)
        if now_ticks_ms >= started_ticks_ms:
            response_time_ms = now_ticks_ms - started_ticks_ms
            use_unix_fallback = false

    if use_unix_fallback:
        var started_at_unix: float = float(
            mechanic_data.get("active_question_started_at_unix", now_unix)
        )
        response_time_ms = maxi(
            0,
            int((now_unix - started_at_unix) * 1000.0)
        )

    var correct: bool = selected_answer_id == correct_answer_id
    var result: String = "correct" if correct else "wrong"

    question["selected_answer_id"] = selected_answer_id
    question["correct_answer_id"] = correct_answer_id
    question["result"] = result
    question["response_time_ms"] = response_time_ms
    question["hint_used"] = hint_used
    question["timeout"] = false
    question["answered_at"] = now_unix
    questions[question_index] = question
    game["questions"] = questions

    var metrics: Dictionary = game.get("interaction_metrics", {})
    if not correct:
        metrics["wrong_answer_count"] = int(
            metrics.get("wrong_answer_count", 0)
        ) + 1
    game["interaction_metrics"] = metrics

    var score_block: Dictionary = game.get("score", {})
    var score_before_event: int = int(
        score_block.get("current_score", 0)
    )
    score_block["current_score"] = current_score
    game["score"] = score_block

    mechanic_data["last_question_occurrence_id"] = occurrence_id
    mechanic_data["last_question_result"] = result
    mechanic_data["current_score"] = current_score
    mechanic_data.erase("active_question_id")
    mechanic_data.erase("active_question_occurrence_id")
    mechanic_data.erase("active_question_started_ticks_ms")
    mechanic_data.erase("active_question_started_at_unix")
    game["mechanic_data"] = mechanic_data

    var event: Dictionary = {
        "event_id": IdUtil.uuid_v4(),
        "schema_version": SCHEMA_VERSION,
        "event_type": "question_answer",
        "result": result,
        "timestamp_unix": now_unix,
        "content_version": ContentDatabase.content_version,
        "level_id": "L" + str(level_no),
        "game_id": game_id,
        "attempt_id": attempt_id,
        "question_id": str(question.get("question_id", "")),
        "question_occurrence_id": occurrence_id,
        "question_order": question.get("question_order", null),
        "question_version": question.get("question_version", null),
        "displayed_options": question.get("displayed_options", []).duplicate(true),
        "selected_answer_id": selected_answer_id,
        "correct_answer_id": correct_answer_id,
        "response_time_ms": response_time_ms,
        "hint_used": hint_used,
        "timeout": false,
        "score_before_event": score_before_event,
        "score_after_event": current_score,
        "score_delta": current_score - score_before_event
    }

    var events: Array = game.get("interaction_events", [])
    events.append(event.duplicate(true))
    game["interaction_events"] = events

    if not SaveManager.commit_v3_native_current(current):
        return false

    var queue_ok: bool = SaveManager.append_v3_pending_event(event)
    if not queue_ok:
        push_warning(
            "Question answer v3 tersimpan pada current, tetapi pending queue gagal diperbarui."
        )

    if not SaveManager.refresh_v3_sync_metadata():
        push_warning(
            "Metadata sync v3 gagal diperbarui setelah question answer."
        )

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

    var game: Dictionary = _ensure_game(
        current,
        level_no,
        game_id,
        game_type
    )

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

    var completed_attempt: Dictionary = {}
    var attempts: Array = game.get("attempts", [])

    for index in range(attempts.size()):
        var attempt_value: Variant = attempts[index]

        if not attempt_value is Dictionary:
            continue

        var attempt: Dictionary = attempt_value

        if str(attempt.get("attempt_id", "")) != attempt_id:
            continue

        attempt["status"] = "completed"
        attempt["completed_at_unix"] = now_unix
        attempt["final_score"] = final_score
        attempt["duration_ms"] = maxi(0, total_duration_ms)

        var attempt_metrics: Dictionary = _build_attempt_metrics(
            game,
            attempt_id
        )
        attempt["interaction_metrics"] = attempt_metrics
        attempt["interaction_event_ids"] = _collect_attempt_event_ids(
            game,
            attempt_id
        )
        attempt["question_occurrence_ids"] = (
            _collect_attempt_question_occurrence_ids(
                game,
                attempt_id
            )
        )
        attempt["game_summary"] = _build_attempt_summary(
            attempt_metrics,
            final_score,
            total_duration_ms
        )
        completed_attempt = attempt.duplicate(true)
        attempts[index] = attempt
        break

    game["attempts"] = attempts
    game["active_attempt_id"] = ""
    game["game_summary"] = _build_game_summary(game)

    if not completed_attempt.is_empty():
        _register_game_attempt_in_level_attempt(
            current,
            level_no,
            game_id,
            completed_attempt
        )

    var level_attempt_id: String = str(
        completed_attempt.get("level_attempt_id", "")
    ).strip_edges()
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
        "level_attempt_id": level_attempt_id,
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
        push_warning(
            "Game completion v3 tersimpan pada current, tetapi pending queue gagal diperbarui."
        )

    SaveManager.refresh_v3_sync_metadata()
    return true


func complete_level_attempt(
    level_no: int,
    level_attempt_id: String,
    final_score: int,
    total_duration_ms: int,
    star_value: float
) -> bool:
    if level_no <= 0 or level_attempt_id.strip_edges().is_empty():
        return false

    var current: Dictionary = SaveManager.load_v3_active_current()

    if current.is_empty():
        return false

    var level: Dictionary = _ensure_level_container(
        current,
        level_no
    )

    if level.is_empty():
        return false

    var attempts: Array = level.get("level_attempts", [])
    var attempt_index: int = _find_level_attempt_index(
        attempts,
        level_attempt_id
    )

    if attempt_index < 0:
        return false

    var attempt_value: Variant = attempts[attempt_index]

    if not attempt_value is Dictionary:
        return false

    var attempt: Dictionary = attempt_value

    if str(attempt.get("status", "")) == "completed":
        return true

    var now_unix: float = Time.get_unix_time_from_system()
    attempt["status"] = "completed"
    attempt["completed_at_unix"] = now_unix
    attempt["final_score"] = clampi(final_score, 0, 100)
    attempt["duration_ms"] = maxi(0, total_duration_ms)
    attempt["star_value"] = clampf(star_value, 0.0, 3.0)

    var game_attempt_refs: Array = attempt.get(
        "game_attempt_refs",
        []
    )
    attempt["summary"] = _build_level_attempt_summary(
        game_attempt_refs,
        attempt
    )
    attempts[attempt_index] = attempt
    level["level_attempts"] = attempts

    if str(level.get("active_level_attempt_id", "")) == level_attempt_id:
        level["active_level_attempt_id"] = ""

    level["latest_result"] = {
        "level_attempt_id": level_attempt_id,
        "attempt_no": int(attempt.get("attempt_no", 0)),
        "score": int(attempt.get("final_score", 0)),
        "stars": float(attempt.get("star_value", 0.0)),
        "star_slots": _star_slots_from_value(
            float(attempt.get("star_value", 0.0))
        ),
        "duration_ms": int(attempt.get("duration_ms", 0)),
        "completed_at_unix": now_unix
    }
    level["lifetime_summary"] = _build_level_lifetime_summary(
        attempts
    )
    _store_level_container(
        current,
        level_no,
        level
    )
    return SaveManager.commit_v3_native_current(current)


func _ensure_level_container(
    current: Dictionary,
    level_no: int
) -> Dictionary:
    var levels: Dictionary = current.get("levels", {})
    var level_key: String = str(level_no)
    var level_value: Variant = levels.get(level_key, {})

    if not level_value is Dictionary:
        return {}

    var level: Dictionary = level_value

    if not level.get("level_attempts", null) is Array:
        level["level_attempts"] = []

    if level.get("active_level_attempt_id", null) == null:
        level["active_level_attempt_id"] = ""

    if not level.get("latest_result", null) is Dictionary:
        level["latest_result"] = {}

    if not level.get("lifetime_summary", null) is Dictionary:
        level["lifetime_summary"] = {}

    return level


func _store_level_container(
    current: Dictionary,
    level_no: int,
    level: Dictionary
) -> void:
    var levels: Dictionary = current.get("levels", {})
    levels[str(level_no)] = level
    current["levels"] = levels


func _ensure_level_attempt(
    current: Dictionary,
    level_no: int
) -> Dictionary:
    var level: Dictionary = _ensure_level_container(
        current,
        level_no
    )

    if level.is_empty():
        return {}

    var active_id: String = str(
        level.get("active_level_attempt_id", "")
    ).strip_edges()
    var attempts: Array = level.get("level_attempts", [])

    if not active_id.is_empty():
        var active_index: int = _find_level_attempt_index(
            attempts,
            active_id
        )

        if active_index >= 0:
            var active_value: Variant = attempts[active_index]

            if active_value is Dictionary:
                var active_attempt: Dictionary = active_value

                if str(active_attempt.get("status", "")) == "in_progress":
                    return active_attempt

    var created: Dictionary = _create_level_attempt(level)
    _store_level_container(current, level_no, level)
    return created


func _create_level_attempt(level: Dictionary) -> Dictionary:
    var attempts: Array = level.get("level_attempts", [])
    var attempt_no: int = _next_level_attempt_no(level)
    var level_no: int = int(level.get("level_no", 0))
    var attempt_id: String = (
        "LAT-L"
        + str(level_no)
        + "-"
        + IdUtil.uuid_v4()
    )
    var now_unix: float = Time.get_unix_time_from_system()
    var attempt: Dictionary = {
        "level_attempt_id": attempt_id,
        "attempt_no": attempt_no,
        "status": "in_progress",
        "started_at_unix": now_unix,
        "completed_at_unix": 0.0,
        "final_score": 0,
        "duration_ms": 0,
        "star_value": 0.0,
        "game_attempt_refs": [],
        "summary": {}
    }
    attempts.append(attempt)
    level["level_attempts"] = attempts
    level["active_level_attempt_id"] = attempt_id
    return attempt


func _close_interrupted_level_attempt(level: Dictionary) -> void:
    var active_id: String = str(
        level.get("active_level_attempt_id", "")
    ).strip_edges()

    if active_id.is_empty():
        return

    var attempts: Array = level.get("level_attempts", [])
    var index: int = _find_level_attempt_index(
        attempts,
        active_id
    )

    if index < 0:
        level["active_level_attempt_id"] = ""
        return

    var value: Variant = attempts[index]

    if value is Dictionary:
        var attempt: Dictionary = value

        if str(attempt.get("status", "")) == "in_progress":
            attempt["status"] = "interrupted"
            attempt["completed_at_unix"] = Time.get_unix_time_from_system()
            attempts[index] = attempt

    level["level_attempts"] = attempts
    level["active_level_attempt_id"] = ""


func _next_level_attempt_no(level: Dictionary) -> int:
    var highest: int = 0
    var attempts: Array = level.get("level_attempts", [])

    for attempt_value in attempts:
        if attempt_value is Dictionary:
            var attempt: Dictionary = attempt_value
            highest = maxi(
                highest,
                int(attempt.get("attempt_no", 0))
            )

    var games: Dictionary = level.get("games", {})

    for game_value in games.values():
        if not game_value is Dictionary:
            continue

        var game: Dictionary = game_value
        var game_attempts: Array = game.get("attempts", [])

        for game_attempt_value in game_attempts:
            if not game_attempt_value is Dictionary:
                continue

            var game_attempt: Dictionary = game_attempt_value
            highest = maxi(
                highest,
                int(game_attempt.get("attempt_no", 0))
            )

    return highest + 1


func _find_level_attempt_index(
    attempts: Array,
    level_attempt_id: String
) -> int:
    for index in range(attempts.size()):
        var value: Variant = attempts[index]

        if not value is Dictionary:
            continue

        var attempt: Dictionary = value

        if str(attempt.get("level_attempt_id", "")) == level_attempt_id:
            return index

    return -1


func _resolve_active_game_attempt_level_id(
    game: Dictionary
) -> String:
    var active_attempt_id: String = str(
        game.get("active_attempt_id", "")
    ).strip_edges()

    if active_attempt_id.is_empty():
        return ""

    var attempts: Array = game.get("attempts", [])

    for value in attempts:
        if not value is Dictionary:
            continue

        var attempt: Dictionary = value

        if str(attempt.get("attempt_id", "")) != active_attempt_id:
            continue

        return str(
            attempt.get("level_attempt_id", "")
        ).strip_edges()

    return ""


func _bind_active_game_attempt_to_level(
    game: Dictionary,
    level_attempt_id: String
) -> bool:
    var active_attempt_id: String = str(
        game.get("active_attempt_id", "")
    ).strip_edges()

    if active_attempt_id.is_empty():
        return false

    var attempts: Array = game.get("attempts", [])

    for index in range(attempts.size()):
        var value: Variant = attempts[index]

        if not value is Dictionary:
            continue

        var attempt: Dictionary = value

        if str(attempt.get("attempt_id", "")) != active_attempt_id:
            continue

        attempt["level_attempt_id"] = level_attempt_id
        attempts[index] = attempt
        game["attempts"] = attempts
        return true

    return false


func _register_game_attempt_in_level_attempt(
    current: Dictionary,
    level_no: int,
    game_id: String,
    game_attempt: Dictionary
) -> void:
    var level_attempt_id: String = str(
        game_attempt.get("level_attempt_id", "")
    ).strip_edges()

    if level_attempt_id.is_empty():
        return

    var level: Dictionary = _ensure_level_container(
        current,
        level_no
    )

    if level.is_empty():
        return

    var attempts: Array = level.get("level_attempts", [])
    var level_index: int = _find_level_attempt_index(
        attempts,
        level_attempt_id
    )

    if level_index < 0:
        return

    var value: Variant = attempts[level_index]

    if not value is Dictionary:
        return

    var level_attempt: Dictionary = value
    var refs: Array = level_attempt.get(
        "game_attempt_refs",
        []
    )
    var summary: Dictionary = game_attempt.get(
        "game_summary",
        {}
    )
    var reference: Dictionary = {
        "game_id": game_id,
        "attempt_id": str(game_attempt.get("attempt_id", "")),
        "attempt_no": int(game_attempt.get("attempt_no", 0)),
        "final_score": int(game_attempt.get("final_score", 0)),
        "duration_ms": int(game_attempt.get("duration_ms", 0)),
        "game_summary": summary.duplicate(true)
    }
    var replaced: bool = false

    for ref_index in range(refs.size()):
        var ref_value: Variant = refs[ref_index]

        if not ref_value is Dictionary:
            continue

        var ref: Dictionary = ref_value

        if str(ref.get("game_id", "")) == game_id:
            refs[ref_index] = reference
            replaced = true
            break

    if not replaced:
        refs.append(reference)

    level_attempt["game_attempt_refs"] = refs
    attempts[level_index] = level_attempt
    level["level_attempts"] = attempts
    _store_level_container(current, level_no, level)


func _build_level_attempt_summary(
    refs: Array,
    attempt: Dictionary
) -> Dictionary:
    var total_correct: int = 0
    var total_wrong: int = 0
    var total_invalid: int = 0
    var total_hint: int = 0
    var total_reset: int = 0
    var total_back_to_map: int = 0

    for ref_value in refs:
        if not ref_value is Dictionary:
            continue

        var ref: Dictionary = ref_value
        var summary: Dictionary = ref.get("game_summary", {})
        total_correct += int(summary.get("total_correct", 0))
        total_wrong += int(summary.get("total_wrong", 0))
        total_invalid += int(summary.get("total_invalid", 0))
        total_hint += int(summary.get("total_hint", 0))
        total_reset += int(summary.get("total_reset", 0))
        total_back_to_map += int(summary.get("total_back_to_map", 0))

    return {
        "final_score": int(attempt.get("final_score", 0)),
        "duration_ms": int(attempt.get("duration_ms", 0)),
        "star_value": float(attempt.get("star_value", 0.0)),
        "game_count": refs.size(),
        "total_correct": total_correct,
        "total_wrong": total_wrong,
        "total_invalid": total_invalid,
        "total_hint": total_hint,
        "total_reset": total_reset,
        "total_back_to_map": total_back_to_map
    }


func _build_level_lifetime_summary(
    attempts: Array
) -> Dictionary:
    var completed_count: int = 0
    var best_score: int = 0
    var latest_score: int = 0
    var total_duration_ms: int = 0
    var total_correct: int = 0
    var total_wrong: int = 0
    var total_invalid: int = 0
    var total_hint: int = 0
    var total_reset: int = 0
    var total_back_to_map: int = 0

    for value in attempts:
        if not value is Dictionary:
            continue

        var attempt: Dictionary = value

        if str(attempt.get("status", "")) != "completed":
            continue

        completed_count += 1
        latest_score = int(attempt.get("final_score", 0))
        best_score = maxi(best_score, latest_score)
        total_duration_ms += int(attempt.get("duration_ms", 0))

        var summary: Dictionary = attempt.get("summary", {})
        total_correct += int(summary.get("total_correct", 0))
        total_wrong += int(summary.get("total_wrong", 0))
        total_invalid += int(summary.get("total_invalid", 0))
        total_hint += int(summary.get("total_hint", 0))
        total_reset += int(summary.get("total_reset", 0))
        total_back_to_map += int(summary.get("total_back_to_map", 0))

    return {
        "total_attempt": completed_count,
        "best_score": best_score,
        "latest_score": latest_score,
        "total_duration_ms": total_duration_ms,
        "total_correct": total_correct,
        "total_wrong": total_wrong,
        "total_invalid": total_invalid,
        "total_hint": total_hint,
        "total_reset": total_reset,
        "total_back_to_map": total_back_to_map
    }


func _star_slots_from_value(star_value: float) -> Array[String]:
    var slots: Array[String] = []
    var remainder: float = clampf(star_value, 0.0, 3.0)

    for _index in range(3):
        if remainder >= 1.0:
            slots.append("full")
            remainder -= 1.0
        elif remainder >= 0.5:
            slots.append("half")
            remainder -= 0.5
        else:
            slots.append("empty")

    return slots

func _find_question_placeholder_index(
    questions: Array,
    question_id: String
) -> int:
    for index in range(questions.size()):
        var question_value: Variant = questions[index]
        if not question_value is Dictionary:
            continue

        var question: Dictionary = question_value
        if str(question.get("question_id", "")) != question_id:
            continue

        var occurrence_value: Variant = question.get(
            "question_occurrence_id",
            null
        )
        if occurrence_value == null:
            return index

        if str(occurrence_value).strip_edges().is_empty():
            return index

    return -1

func _find_question_occurrence_index(
    questions: Array,
    occurrence_id: String
) -> int:
    for index in range(questions.size()):
        var question_value: Variant = questions[index]
        if not question_value is Dictionary:
            continue

        var question: Dictionary = question_value
        if str(question.get("question_occurrence_id", "")) == occurrence_id:
            return index

    return -1
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
    if not game.get("questions", null) is Array:
        game["questions"] = []
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
        "game_id": str(game.get("game_id", "")),
        "game_type": str(game.get("game_type", "")),
        "status": "in_progress",
        "started_at_unix": now_unix,
        "completed_at_unix": 0.0,
        "score_before_reset": 0,
        "final_score": 0,
        "duration_ms": 0,
        "interaction_metrics": _empty_attempt_metrics(),
        "interaction_event_ids": [],
        "question_occurrence_ids": [],
        "game_summary": {}
    }
    var score_value: Variant = game.get("score", {})
    var score: Dictionary = {}
    if score_value is Dictionary:
        score = score_value
    score["current_score"] = 0
    score["final_score"] = 0
    game["score"] = score
    game["total_duration_ms"] = 0
    game["completed_at_unix"] = 0.0
    var mechanic_value: Variant = game.get("mechanic_data", {})
    var mechanic_data: Dictionary = {}
    if mechanic_value is Dictionary:
        mechanic_data = mechanic_value
    mechanic_data["current_score"] = 0
    game["mechanic_data"] = mechanic_data
    attempts.append(attempt)
    game["attempts"] = attempts
    game["attempt_count"] = attempts.size()
    game["active_attempt_id"] = attempt_id
    game["status"] = "in_progress"
    if float(game.get("started_at_unix", 0.0)) <= 0.0:
        game["started_at_unix"] = now_unix
    return attempt_id
func _empty_attempt_metrics() -> Dictionary:
    return {
        "drag_count": 0,
        "correct_drop_count": 0,
        "wrong_target_drop_count": 0,
        "invalid_drop_count": 0,
        "correct_answer_count": 0,
        "wrong_answer_count": 0,
        "in_game_reset_click_count": 0,
        "back_to_map_click_count": 0,
        "hint_click_count": 0
    }

func _build_attempt_metrics(
    game: Dictionary,
    attempt_id: String
) -> Dictionary:
    var metrics: Dictionary = _empty_attempt_metrics()
    var events: Array = game.get("interaction_events", [])

    for event_value in events:
        if not event_value is Dictionary:
            continue

        var event: Dictionary = event_value

        if str(event.get("attempt_id", "")) != attempt_id:
            continue

        var event_type: String = str(event.get("event_type", ""))
        var result: String = str(event.get("result", ""))

        if event_type == "drop":
            metrics["drag_count"] = int(
                metrics.get("drag_count", 0)
            ) + 1

            if result == "correct_drop":
                metrics["correct_drop_count"] = int(
                    metrics.get("correct_drop_count", 0)
                ) + 1
            elif result == "wrong_target_drop":
                metrics["wrong_target_drop_count"] = int(
                    metrics.get("wrong_target_drop_count", 0)
                ) + 1
            elif result == "invalid_drop":
                metrics["invalid_drop_count"] = int(
                    metrics.get("invalid_drop_count", 0)
                ) + 1
        elif event_type == "question_answer":
            if result == "correct":
                metrics["correct_answer_count"] = int(
                    metrics.get("correct_answer_count", 0)
                ) + 1
            elif result == "wrong":
                metrics["wrong_answer_count"] = int(
                    metrics.get("wrong_answer_count", 0)
                ) + 1
        elif event_type == "hint":
            metrics["hint_click_count"] = int(
                metrics.get("hint_click_count", 0)
            ) + 1
        elif event_type == "in_game_reset" or event_type == "reset":
            metrics["in_game_reset_click_count"] = int(
                metrics.get("in_game_reset_click_count", 0)
            ) + 1
        elif event_type == "back_to_map":
            metrics["back_to_map_click_count"] = int(
                metrics.get("back_to_map_click_count", 0)
            ) + 1

    return metrics

func _collect_attempt_event_ids(
    game: Dictionary,
    attempt_id: String
) -> Array[String]:
    var output: Array[String] = []
    var events: Array = game.get("interaction_events", [])

    for event_value in events:
        if not event_value is Dictionary:
            continue

        var event: Dictionary = event_value

        if str(event.get("attempt_id", "")) != attempt_id:
            continue

        var event_id: String = str(
            event.get("event_id", "")
        ).strip_edges()

        if not event_id.is_empty():
            output.append(event_id)

    return output

func _collect_attempt_question_occurrence_ids(
    game: Dictionary,
    attempt_id: String
) -> Array[String]:
    var output: Array[String] = []
    var events: Array = game.get("interaction_events", [])

    for event_value in events:
        if not event_value is Dictionary:
            continue

        var event: Dictionary = event_value

        if str(event.get("attempt_id", "")) != attempt_id:
            continue

        if str(event.get("event_type", "")) != "question_answer":
            continue

        var occurrence_id: String = str(
            event.get("question_occurrence_id", "")
        ).strip_edges()

        if not occurrence_id.is_empty() and not output.has(occurrence_id):
            output.append(occurrence_id)

    return output

func _build_attempt_summary(
    metrics: Dictionary,
    final_score: int,
    total_duration_ms: int
) -> Dictionary:
    return {
        "final_score": final_score,
        "total_duration_ms": maxi(0, total_duration_ms),
        "total_correct": (
            int(metrics.get("correct_drop_count", 0))
            + int(metrics.get("correct_answer_count", 0))
        ),
        "total_wrong": (
            int(metrics.get("wrong_target_drop_count", 0))
            + int(metrics.get("wrong_answer_count", 0))
        ),
        "total_invalid": int(
            metrics.get("invalid_drop_count", 0)
        ),
        "total_hint": int(
            metrics.get("hint_click_count", 0)
        ),
        "total_reset": int(
            metrics.get("in_game_reset_click_count", 0)
        ),
        "total_back_to_map": int(
            metrics.get("back_to_map_click_count", 0)
        ),
        "correct_drop_count": int(
            metrics.get("correct_drop_count", 0)
        ),
        "correct_answer_count": int(
            metrics.get("correct_answer_count", 0)
        ),
        "wrong_target_drop_count": int(
            metrics.get("wrong_target_drop_count", 0)
        ),
        "wrong_answer_count": int(
            metrics.get("wrong_answer_count", 0)
        )
    }
func _build_game_summary(game: Dictionary) -> Dictionary:
    var metrics: Dictionary = game.get("interaction_metrics", {})
    var score_block: Dictionary = game.get("score", {})
    var question_correct_count: int = 0
    var questions_value: Variant = game.get("questions", [])

    if questions_value is Array:
        var questions: Array = questions_value
        for question_value in questions:
            if not question_value is Dictionary:
                continue

            var question: Dictionary = question_value
            if str(question.get("result", "")) == "correct":
                question_correct_count += 1

    return {
        "final_score": int(score_block.get("final_score", 0)),
        "total_duration_ms": int(game.get("total_duration_ms", 0)),
        "total_attempt": int(game.get("attempt_count", 0)),
        "total_correct": (
            int(metrics.get("correct_drop_count", 0))
            + question_correct_count
        ),
        "total_wrong": (
            int(metrics.get("wrong_target_drop_count", 0))
            + int(metrics.get("wrong_answer_count", 0))
        ),
        "total_invalid": int(metrics.get("invalid_drop_count", 0)),
        "total_hint": int(metrics.get("hint_click_count", 0)),
        "total_reset": int(metrics.get("in_game_reset_click_count", 0)),
        "total_back_to_map": int(metrics.get("back_to_map_click_count", 0))
    }
