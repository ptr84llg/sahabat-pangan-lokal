extends Node

const STATUS_COMPLETED: String = "completed"
const STATUS_AVAILABLE: String = "available"
const STATUS_LOCKED: String = "locked"
const STATUS_IN_PROGRESS: String = "in_progress"

const AUDIO_SETTING_KEYS: Array = [
    "muted",
    "music_volume",
    "sfx_volume",
    "button_hover_enabled",
    "button_click_enabled",
    "mouse_click_enabled"
]

const UX_SETTING_KEYS: Array = [
    "tutorial_level_01_seen",
    "tutorial_level_02_seen",
    "shopping_tutorial_seen",
    "preview_food_seen_level_02"
]

func normalize_settings(payload: Dictionary) -> Dictionary:
    var normalized: Dictionary = {}

    for key in AUDIO_SETTING_KEYS:
        if payload.has(key):
            normalized[key] = payload.get(key)

    for key in UX_SETTING_KEYS:
        if payload.has(key):
            normalized[key] = payload.get(key)

    if not normalized.has("muted"):
        normalized["muted"] = false
    if not normalized.has("music_volume"):
        normalized["music_volume"] = 0.80
    if not normalized.has("sfx_volume"):
        normalized["sfx_volume"] = 0.80
    if not normalized.has("button_hover_enabled"):
        normalized["button_hover_enabled"] = true
    if not normalized.has("button_click_enabled"):
        normalized["button_click_enabled"] = true
    if not normalized.has("mouse_click_enabled"):
        normalized["mouse_click_enabled"] = true

    normalized["music_volume"] = clampf(float(normalized.get("music_volume", 0.80)), 0.0, 1.0)
    normalized["sfx_volume"] = clampf(float(normalized.get("sfx_volume", 0.80)), 0.0, 1.0)
    normalized["muted"] = bool(normalized.get("muted", false))
    normalized["button_hover_enabled"] = bool(normalized.get("button_hover_enabled", true))
    normalized["button_click_enabled"] = bool(normalized.get("button_click_enabled", true))
    normalized["mouse_click_enabled"] = bool(normalized.get("mouse_click_enabled", true))

    return normalized

func progress_id_from_legacy_run_id(run_id: String) -> String:
    var clean_run_id: String = run_id.strip_edges()

    if clean_run_id.is_empty():
        return ""

    return "PRG-" + clean_run_id

func build_current_from_legacy(
    game_state: Dictionary,
    installation_id: String,
    identity: Dictionary,
    device: Dictionary,
    settings: Dictionary
) -> Dictionary:
    var profile: Dictionary = game_state.get("profile", {})
    var run: Dictionary = game_state.get("active_run", {})
    var run_id: String = str(run.get("run_id", "")).strip_edges()

    if run.is_empty() or run_id.is_empty():
        return {}

    if str(run.get("status", "")) != "IN_PROGRESS":
        return {}

    var id_progress: String = progress_id_from_legacy_run_id(run_id)

    return {
        "version": _version_block(run),
        "device": _device_snapshot(device, installation_id),
        "identity": identity.duplicate(true),
        "progress": {
            "id_progress": id_progress,
            "status": "current",
            "revision": 0,
            "created_at_legacy_unix": run.get("started_at", 0),
            "updated_at_unix": Time.get_unix_time_from_system()
        },
        "settings": normalize_settings(settings),
        "character": _character_snapshot(profile, run),
        "levels": _build_levels(run),
        "summary": _build_summary(run),
        "sync_state": {
            "status": "shadow_local_only",
            "local_revision": 0,
            "last_server_revision": 0,
            "server_revision": 0,
            "last_sync_at": null,
            "pending_event_count": 0
        },
        "migration": {
            "source_schema_version": 2,
            "shadow_source": "legacy_v2",
            "legacy_run_id": run_id,
            "legacy_level_sessions": run.get("level_sessions", []).duplicate(true),
            "legacy_snapshot": run.duplicate(true),
            "migrated_at_unix": Time.get_unix_time_from_system()
        }
    }

func _build_game_skeletons(level_no: int) -> Dictionary:
    var games: Dictionary = {}

    if level_no == 1:
        games["L1-G01"] = _new_game_skeleton(
            "L1-G01",
            "matching_drag_drop",
            "pilot_58AD",
            null,
            null,
            "Telemetry v3 pilot dihubungkan pada 58AD. Reset Permainan belum diverifikasi pada game ini."
        )
        games["L1-G02"] = _new_game_skeleton(
            "L1-G02",
            "literacy_question",
            null,
            null,
            [_new_question_skeleton("l1_q01")],
            "Gameplay tersedia. Detail telemetry pertanyaan belum dihubungkan."
        )
    elif level_no == 2:
        games["L2-G01"] = _new_game_skeleton(
            "L2-G01",
            "classification_drag_drop",
            null,
            [
                _new_unit_skeleton("section", "L2-G01-B01", 1),
                _new_unit_skeleton("section", "L2-G01-B02", 2)
            ],
            null,
            "Dua batch diketahui. Reset Permainan terdeteksi pada Level 2. Detail telemetry v3 belum dihubungkan."
        )
        games["L2-G02"] = _new_game_skeleton(
            "L2-G02",
            "complete_group",
            null,
            [
                _new_unit_skeleton("round", "l2_r1", 1),
                _new_unit_skeleton("round", "l2_r2", 2),
                _new_unit_skeleton("round", "l2_r3", 3)
            ],
            null,
            "Tiga ronde diketahui. Detail telemetry v3 belum dihubungkan."
        )
    elif level_no == 3:
        games["L3-G01"] = _new_game_skeleton(
            "L3-G01",
            "selective_shopping",
            null,
            null,
            null,
            "Gameplay tersedia. Telemetry belanja v3 dan Reset Permainan belum dihubungkan atau diverifikasi."
        )
        games["L3-G02"] = _new_game_skeleton(
            "L3-G02",
            "complete_shopping",
            null,
            [
                _new_unit_skeleton("round", "l3_r1", 1),
                _new_unit_skeleton("round", "l3_r2", 2),
                _new_unit_skeleton("round", "l3_r3", 3)
            ],
            null,
            "Tiga ronde diketahui. Detail telemetry v3 belum dihubungkan."
        )
    elif level_no == 4:
        games["L4-G01"] = _new_game_skeleton(
            "L4-G01",
            "two_ingredient_process",
            null,
            [
                _new_unit_skeleton("section", "order_04_01", 1),
                _new_unit_skeleton("section", "order_04_02", 2),
                _new_unit_skeleton("section", "order_04_03", 3),
                _new_unit_skeleton("section", "order_04_04", 4)
            ],
            null,
            "Empat pesanan diketahui. Telemetry v3 dan Reset Permainan belum dihubungkan atau diverifikasi."
        )
        games["L4-G02"] = _new_game_skeleton(
            "L4-G02",
            "complete_processing_chain",
            null,
            [
                _new_unit_skeleton("round", "l4_r1", 1),
                _new_unit_skeleton("round", "l4_r2", 2),
                _new_unit_skeleton("round", "l4_r3", 3)
            ],
            null,
            "Tiga ronde diketahui. Detail telemetry v3 belum dihubungkan."
        )
    elif level_no == 5:
        games["L5-G01"] = _new_game_skeleton(
            "L5-G01",
            "festival_composite",
            null,
            [
                _new_unit_skeleton("phase", "schema_1", 1),
                _new_unit_skeleton("phase", "schema_2", 2),
                _new_unit_skeleton("phase", "schema_3", 3),
                _new_unit_skeleton("phase", "schema_4", 4)
            ],
            null,
            "Empat skema diketahui. Telemetry v3 dan Reset Permainan belum dihubungkan atau diverifikasi."
        )
        games["L5-G02"] = _new_game_skeleton(
            "L5-G02",
            "literacy_quiz",
            null,
            null,
            [
                _new_question_skeleton("Q01"),
                _new_question_skeleton("Q02"),
                _new_question_skeleton("Q03"),
                _new_question_skeleton("Q04"),
                _new_question_skeleton("Q05")
            ],
            "Lima question_id diketahui. Occurrence, jawaban, timing, dan telemetry belum dihubungkan."
        )

    return games

func _new_game_skeleton(
    game_id: String,
    game_type: String,
    telemetry_status: Variant,
    units: Variant,
    questions: Variant,
    note: String
) -> Dictionary:
    return {
        "game_id": game_id,
        "game_type": game_type,
        "status": null,
        "started_at_unix": null,
        "completed_at_unix": null,
        "total_duration_ms": null,
        "attempt_count": null,
        "active_attempt_id": null,
        "score": {
            "current_score": null,
            "final_score": null
        },
        "interaction_metrics": {
            "drag_count": null,
            "correct_drop_count": null,
            "wrong_target_drop_count": null,
            "invalid_drop_count": null,
            "wrong_answer_count": null,
            "in_game_reset_click_count": null,
            "back_to_map_click_count": null,
            "hint_click_count": null
        },
        "attempts": null,
        "rounds_or_sections": units,
        "questions": questions,
        "interaction_events": null,
        "mechanic_data": null,
        "game_summary": null,
        "implementation_notes": {
            "gameplay_exists": true,
            "v3_telemetry_status": telemetry_status,
            "in_game_reset_status": null,
            "null_policy": "Field null berarti elemen belum tersedia, belum terhubung, atau belum memiliki data pada run ini. Field tetap ada dan tidak dihapus dari schema.",
            "note": note
        }
    }

func _new_unit_skeleton(unit_type: String, unit_id: String, order_no: int) -> Dictionary:
    var unit: Dictionary = {
        "unit_type": unit_type,
        "status": null,
        "order": order_no,
        "started_at_unix": null,
        "completed_at_unix": null,
        "active_duration_ms": null,
        "score": null,
        "attempt_id": null,
        "interaction_metrics": null,
        "mechanic_data": null,
        "events": null
    }

    if unit_type == "round":
        unit["round_id"] = unit_id
    elif unit_type == "section":
        unit["section_id"] = unit_id
    elif unit_type == "phase":
        unit["phase_id"] = unit_id

    return unit

func _new_question_skeleton(question_id: String) -> Dictionary:
    return {
        "question_id": question_id,
        "question_occurrence_id": null,
        "question_order": null,
        "question_version": null,
        "displayed_options": null,
        "selected_answer_id": null,
        "correct_answer_id": null,
        "result": null,
        "response_time_ms": null,
        "hint_used": null,
        "timeout": null,
        "answered_at": null
    }

func merge_existing_v3_native_detail(
    fresh_payload: Dictionary,
    existing_payload: Dictionary
) -> Dictionary:
    if fresh_payload.is_empty() or existing_payload.is_empty():
        return fresh_payload
    var fresh_progress: Dictionary = fresh_payload.get("progress", {})
    var existing_progress: Dictionary = existing_payload.get("progress", {})
    var fresh_id: String = str(fresh_progress.get("id_progress", "")).strip_edges()
    var existing_id: String = str(existing_progress.get("id_progress", "")).strip_edges()
    if fresh_id.is_empty() or fresh_id != existing_id:
        return fresh_payload
    _merge_level_native_detail(fresh_payload, existing_payload)
    var existing_revision: int = int(existing_progress.get("revision", 0))
    var fresh_sync: Dictionary = fresh_payload.get("sync_state", {})
    var existing_sync: Dictionary = existing_payload.get("sync_state", {})
    var existing_sync_revision: int = int(existing_sync.get("local_revision", 0))
    var preserved_revision: int = maxi(existing_revision, existing_sync_revision)
    fresh_progress["revision"] = preserved_revision
    fresh_payload["progress"] = fresh_progress
    fresh_sync["local_revision"] = preserved_revision
    fresh_sync["pending_event_count"] = int(existing_sync.get("pending_event_count", 0))
    fresh_payload["sync_state"] = fresh_sync
    return fresh_payload
func merge_current_native_detail_into_history(
    history_payload: Dictionary,
    current_payload: Dictionary
) -> Dictionary:
    if history_payload.is_empty() or current_payload.is_empty():
        return history_payload
    var history_block: Dictionary = history_payload.get("history", {})
    var current_progress: Dictionary = current_payload.get("progress", {})
    var source_progress_id: String = str(
        history_block.get("source_progress_id", "")
    ).strip_edges()
    var current_progress_id: String = str(
        current_progress.get("id_progress", "")
    ).strip_edges()
    if source_progress_id.is_empty() or source_progress_id != current_progress_id:
        return history_payload
    _merge_level_native_detail(history_payload, current_payload)
    var migration: Dictionary = history_payload.get("migration", {})
    migration["v3_native_detail_preserved"] = true
    history_payload["migration"] = migration
    return history_payload
func _merge_level_native_detail(
    destination_payload: Dictionary,
    source_payload: Dictionary
) -> void:
    var destination_levels: Dictionary = destination_payload.get("levels", {})
    var source_levels: Dictionary = source_payload.get("levels", {})
    for level_no in range(1, 6):
        var key: String = str(level_no)
        var destination_level: Dictionary = destination_levels.get(key, {})
        var source_level: Dictionary = source_levels.get(key, {})
        if destination_level.is_empty() or source_level.is_empty():
            continue
        var source_games: Dictionary = source_level.get("games", {})
        if not source_games.is_empty():
            destination_level["games"] = source_games.duplicate(true)
        var destination_summary: Dictionary = destination_level.get("level_summary", {})
        var source_summary: Dictionary = source_level.get("level_summary", {})
        for summary_key_value in source_summary.keys():
            var summary_key: String = str(summary_key_value)
            if summary_key.begins_with("legacy_") or summary_key == "data_quality":
                continue
            destination_summary[summary_key] = source_summary.get(summary_key_value)
        destination_level["level_summary"] = destination_summary
        destination_levels[key] = destination_level
    destination_payload["levels"] = destination_levels

func is_legacy_history_eligible(record: Dictionary) -> bool:
    if str(record.get("status", "")) != "COMPLETED":
        return false

    var run_id: String = str(record.get("run_id", "")).strip_edges()

    if run_id.is_empty():
        return false

    var statuses: Dictionary = record.get("level_status", {})

    for level_no in range(1, 6):
        if str(statuses.get(str(level_no), "")) != "COMPLETED":
            return false

    return true

func build_history_from_legacy(
    record: Dictionary,
    id_history: String,
    installation_id: String,
    identity: Dictionary,
    device: Dictionary,
    settings: Dictionary
) -> Dictionary:
    if not is_legacy_history_eligible(record):
        return {}

    var run_id: String = str(record.get("run_id", "")).strip_edges()
    var profile_stub: Dictionary = {
        "display_name": str(record.get("player_name", "Pemain"))
    }

    return {
        "history": {
            "id_history": id_history,
            "source_progress_id": progress_id_from_legacy_run_id(run_id),
            "status": "completed",
            "completed_at_legacy_unix": record.get("completed_at", 0),
            "archived_at_legacy_unix": record.get("archived_at", 0)
        },
        "version": _version_block(record),
        "device": _device_snapshot(device, installation_id),
        "identity": identity.duplicate(true),
        "settings": normalize_settings(settings),
        "character": _character_snapshot(profile_stub, record),
        "levels": _build_levels(record),
        "summary": _build_summary(record),
        "migration": {
            "source_schema_version": 2,
            "shadow_source": "legacy_v2",
            "legacy_run_id": run_id,
            "detail_quality": "legacy_summary_and_session_snapshot",
            "legacy_level_sessions": record.get("level_sessions", []).duplicate(true),
            "legacy_snapshot": record.duplicate(true),
            "migrated_at_unix": Time.get_unix_time_from_system()
        }
    }

func _version_block(run: Dictionary) -> Dictionary:
    return {
        "schema_version": 3,
        "game_version": str(run.get("game_version", "levels1-5-v1.4")),
        "content_version": run.get("content_version", ContentDatabase.content_version)
    }

func _device_snapshot(device: Dictionary, installation_id: String) -> Dictionary:
    var snapshot: Dictionary = device.duplicate(true)
    snapshot["installation_id"] = installation_id
    return snapshot

func _character_snapshot(profile: Dictionary, run: Dictionary) -> Dictionary:
    return {
        "player_name": str(profile.get("display_name", run.get("player_name", "Pemain"))),
        "gender": str(run.get("selected_gender", "male")),
        "character_id": str(run.get("selected_character_id", ""))
    }

func _build_levels(run: Dictionary) -> Dictionary:
    var statuses: Dictionary = run.get("level_status", {})
    var scores: Dictionary = run.get("level_scores", {})
    var stars: Dictionary = run.get("stars_by_level", {})
    var durations: Dictionary = run.get("level_durations_ms", {})
    var levels: Dictionary = {}

    for level_no in range(1, 6):
        var key: String = str(level_no)
        levels[key] = {
            "status": _normalize_level_status(str(statuses.get(key, "LOCKED"))),
            "games": _build_game_skeletons(level_no),
            "level_summary": {
                "legacy_score": int(scores.get(key, 0)),
                "legacy_stars": int(stars.get(key, 0)),
                "legacy_active_duration_ms": int(durations.get(key, 0)),
                "data_quality": "legacy_summary_only"
            }
        }

    return levels

func _build_summary(run: Dictionary) -> Dictionary:
    var statuses: Dictionary = run.get("level_status", {})
    var scores: Dictionary = run.get("level_scores", {})
    var stars: Dictionary = run.get("stars_by_level", {})
    var durations: Dictionary = run.get("level_durations_ms", {})
    var levels_completed: int = 0
    var total_score: int = 0
    var total_stars: int = 0
    var total_duration_ms: int = 0

    for level_no in range(1, 6):
        var key: String = str(level_no)

        if str(statuses.get(key, "")) == "COMPLETED":
            levels_completed += 1

        total_score += int(scores.get(key, 0))
        total_stars += int(stars.get(key, 0))
        total_duration_ms += int(durations.get(key, 0))

    return {
        "levels_completed": levels_completed,
        "total_score": total_score,
        "total_stars": total_stars,
        "total_duration_ms": total_duration_ms
    }

func _normalize_level_status(legacy_status: String) -> String:
    if legacy_status == "COMPLETED":
        return STATUS_COMPLETED
    if legacy_status == "AVAILABLE":
        return STATUS_AVAILABLE
    if legacy_status == "IN_PROGRESS":
        return STATUS_IN_PROGRESS

    return STATUS_LOCKED
