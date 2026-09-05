extends Node

const STATUS_LOCKED = "LOCKED"
const STATUS_AVAILABLE = "AVAILABLE"
const STATUS_COMPLETED = "COMPLETED"

const STAR_TWO_THRESHOLD = 60
const STAR_THREE_THRESHOLD = 80

const CHARACTER_DATA = {
    "budi": {
        "display_name": "Budi",
        "gender": "male",
        "texture_path": "res://assets/visual/character_select/character_02_male_standing.png"
    },
    "rara": {
        "display_name": "Rara",
        "gender": "female",
        "texture_path": "res://assets/visual/character_select/character_01_female_standing.png"
    },
    "riski": {
        "display_name": "Riski",
        "gender": "male",
        "texture_path": "res://assets/visual/character_select/character_04_male_standing.png"
    },
    "anjani": {
        "display_name": "Anjani",
        "gender": "female",
        "texture_path": "res://assets/visual/character_select/character_03_female_standing.png"
    }
}

var profile: Dictionary = {}
var active_run: Dictionary = {}
var initialized: bool = false

func initialize(saved_state: Dictionary = {}) -> void:
    if not saved_state.is_empty():
        import_state(saved_state)

    if profile.is_empty():
        profile = _new_profile()

    profile["player_id"] = SaveManager.get_installation_id()
    _ensure_profile_fields()
    _ensure_run_fields()

    if _clear_completed_active_run():
        SaveManager.request_save()

    initialized = true

func _new_profile() -> Dictionary:
    return {
        "player_id": SaveManager.get_installation_id(),
        "display_name": "Pemain",
        "preferred_gender": "male",
        "active_run_id": "",
        "best_scores_by_level": {},
        "best_times_by_level": {},
        "best_stars_by_level": {},
        "badges": {},
        "gallery_unlocks": [],
        "processed_gallery_unlocks": [],
        "completion_counts_by_level": {},
        "completed_run_history": []
    }

func _ensure_profile_fields() -> void:
    if not profile.has("display_name"):
        profile["display_name"] = "Pemain"
    if not profile.has("preferred_gender"):
        profile["preferred_gender"] = "male"
    if not profile.has("best_scores_by_level"):
        profile["best_scores_by_level"] = {}
    if not profile.has("best_times_by_level"):
        profile["best_times_by_level"] = {}
    if not profile.has("best_stars_by_level"):
        profile["best_stars_by_level"] = {}
    if not profile.has("badges"):
        profile["badges"] = {}
    if not profile.has("gallery_unlocks"):
        profile["gallery_unlocks"] = []
    if not profile.has("processed_gallery_unlocks"):
        profile["processed_gallery_unlocks"] = []
    if not profile.has("completion_counts_by_level"):
        profile["completion_counts_by_level"] = {}
    if not profile.has("completed_run_history"):
        profile["completed_run_history"] = []


func _ensure_run_fields() -> void:
    if active_run.is_empty():
        return

    if not active_run.has("selected_character_id"):
        active_run["selected_character_id"] = ""
    if not active_run.has("selected_gender"):
        active_run["selected_gender"] = _infer_gender_from_character_id(str(active_run.get("selected_character_id", "")))
    if not active_run.has("level_scores"):
        active_run["level_scores"] = {}
    if not active_run.has("stars_by_level"):
        active_run["stars_by_level"] = {}
    if not active_run.has("level_durations_ms"):
        active_run["level_durations_ms"] = {}
    if not active_run.has("level_sessions"):
        active_run["level_sessions"] = []
    if not active_run.has("final_badges"):
        active_run["final_badges"] = []

    var level_scores: Dictionary = active_run.get("level_scores", {})
    var stars_by_level: Dictionary = active_run.get("stars_by_level", {})

    for key_value in level_scores.keys():
        var key: String = str(key_value)
        if not stars_by_level.has(key):
            stars_by_level[key] = stars_for_score(int(level_scores.get(key, 0)))

    active_run["stars_by_level"] = stars_by_level

    var active_gender: String = str(active_run.get("selected_gender", "male"))
    if active_gender != "female":
        active_gender = "male"

    active_run["selected_gender"] = active_gender
    profile["preferred_gender"] = active_gender

func reset_progress() -> void:
    profile = _new_profile()
    active_run = {}
    initialized = true

func has_active_run() -> bool:
    return not active_run.is_empty() and str(active_run.get("status", "")) == "IN_PROGRESS"

func reset_current_run() -> bool:
    if not has_active_run():
        return false

    active_run = {}
    profile["active_run_id"] = ""
    _rebuild_profile_from_completed_history()
    SaveManager.request_save()
    return true

# BUNDLE_53B_R2_ACTIVE_RUN_HISTORY_BEGIN
func finalize_completed_run() -> bool:
    if not _clear_completed_active_run():
        return false

    SaveManager.request_save()
    return true

func _clear_completed_active_run() -> bool:
    if active_run.is_empty():
        return false

    if str(active_run.get("status", "")) != "COMPLETED":
        return false

    _archive_completed_run()
    active_run = {}
    profile["active_run_id"] = ""
    _rebuild_profile_from_completed_history()
    return true

func active_run_badge_count() -> int:
    if active_run.is_empty():
        return 0

    var badge_ids: Array = active_run.get("final_badges", [])
    return clampi(badge_ids.size(), 0, 5)
# BUNDLE_53B_R2_ACTIVE_RUN_HISTORY_END

func completed_run_history() -> Array:
    var history: Array = profile.get("completed_run_history", [])
    return history.duplicate(true)

func sanitize_player_name(raw_name: String) -> String:
    var trimmed: String = raw_name.strip_edges()
    var builder: String = ""

    for index in range(trimmed.length()):
        var character: String = trimmed.substr(index, 1)
        if _is_ascii_letter(character) or _is_ascii_digit(character) or character == "_":
            builder += character

    while not builder.is_empty() and not _is_ascii_letter(builder.substr(0, 1)):
        builder = builder.substr(1)

    if builder.length() > 12:
        builder = builder.substr(0, 12)

    return builder

func is_valid_player_name(player_name: String) -> bool:
    var clean_name: String = sanitize_player_name(player_name)
    return clean_name == player_name and clean_name.length() >= 1 and clean_name.length() <= 12

func start_new_run(player_name: String = "", player_gender: String = "male") -> void:
    var clean_name: String = sanitize_player_name(player_name)
    var normalized_gender: String = "female" if player_gender == "female" else "male"

    if clean_name.is_empty():
        clean_name = "Pemain"

    profile["display_name"] = clean_name
    profile["preferred_gender"] = normalized_gender
    profile["player_id"] = SaveManager.get_installation_id()

    var run_id: String = IdUtil.uuid_v4()

    active_run = {
        "run_id": run_id,
        "status": "IN_PROGRESS",
        "game_version": "levels1-5-v1.4",
        "content_version": ContentDatabase.content_version,
        "started_at": Time.get_unix_time_from_system(),
        "completed_at": 0,
        "selected_gender": normalized_gender,
        "selected_character_id": "",
        "level_status": {
            "1": STATUS_AVAILABLE,
            "2": STATUS_LOCKED,
            "3": STATUS_LOCKED,
            "4": STATUS_LOCKED,
            "5": STATUS_LOCKED
        },
        "level_scores": {},
        "stars_by_level": {},
        "level_durations_ms": {},
        "level_sessions": [],
        "final_badges": []
    }

    profile["active_run_id"] = run_id

    AnalyticsLogger.log_event("run_started", {
        "run_id": run_id,
        "content_version": ContentDatabase.content_version,
        "installation_id": SaveManager.get_installation_id(),
        "player_gender": normalized_gender
    })

    SaveManager.request_save()

func set_player_display_name(player_name: String) -> bool:
    var clean_name: String = sanitize_player_name(player_name)

    if clean_name.is_empty() or clean_name.length() > 12:
        return false

    profile["display_name"] = clean_name
    SaveManager.request_save()
    return true

func player_display_name() -> String:
    var name_value: String = sanitize_player_name(str(profile.get("display_name", "Pemain")))

    if name_value.is_empty():
        return "Pemain"

    return name_value

func set_selected_gender(player_gender: String) -> bool:
    var normalized_gender: String = "female" if player_gender == "female" else "male"

    profile["preferred_gender"] = normalized_gender

    if not active_run.is_empty():
        active_run["selected_gender"] = normalized_gender

        var character_id: String = str(active_run.get("selected_character_id", ""))
        if not character_id.is_empty() and not _character_matches_gender(character_id, normalized_gender):
            active_run["selected_character_id"] = ""

    SaveManager.request_save()
    return true

func selected_gender() -> String:
    var gender_value: String = str(profile.get("preferred_gender", "male"))

    if not active_run.is_empty():
        gender_value = str(active_run.get("selected_gender", gender_value))

    if gender_value == "female":
        return "female"

    return "male"

func available_character_ids_for_gender(player_gender: String) -> Array[String]:
    if player_gender == "female":
        return ["rara", "anjani"]

    return ["budi", "riski"]

func available_character_ids_for_current_run() -> Array[String]:
    return available_character_ids_for_gender(selected_gender())

func set_selected_character(character_id: String) -> bool:
    if active_run.is_empty():
        return false

    if not CHARACTER_DATA.has(character_id):
        return false

    if not _character_matches_gender(character_id, selected_gender()):
        return false

    active_run["selected_character_id"] = character_id

    AnalyticsLogger.log_event("character_selected", {
        "run_id": active_run.get("run_id", ""),
        "character_id": character_id,
        "player_name": player_display_name(),
        "player_gender": selected_gender()
    })

    SaveManager.request_save()
    return true

func selected_character_id() -> String:
    return str(active_run.get("selected_character_id", ""))

func has_selected_character() -> bool:
    return CHARACTER_DATA.has(selected_character_id())

func selected_character_display_name() -> String:
    var character_id: String = selected_character_id()

    if not CHARACTER_DATA.has(character_id):
        return ""

    return str(CHARACTER_DATA[character_id].get("display_name", ""))

func selected_character_texture_path() -> String:
    var character_id: String = selected_character_id()

    if not CHARACTER_DATA.has(character_id):
        return ""

    return str(CHARACTER_DATA[character_id].get("texture_path", ""))

func total_points() -> int:
    var total: int = 0
    var scores: Dictionary = active_run.get("level_scores", {})

    for score_value in scores.values():
        total += int(score_value)

    return total

func total_stars() -> int:
    var total: int = 0
    var stars: Dictionary = active_run.get("stars_by_level", {})

    for star_value in stars.values():
        total += int(star_value)

    return total

func stars_for_level(level_no: int) -> int:
    var key: String = str(level_no)
    var stars: Dictionary = active_run.get("stars_by_level", {})

    if stars.has(key):
        return int(stars.get(key, 0))

    var scores: Dictionary = active_run.get("level_scores", {})
    return stars_for_score(int(scores.get(key, 0)))

func stars_for_score(score: int) -> int:
    if score >= STAR_THREE_THRESHOLD:
        return 3

    if score >= STAR_TWO_THRESHOLD:
        return 2

    if score > 0:
        return 1

    return 0

func level_status(level_no: int) -> String:
    if active_run.is_empty():
        return STATUS_LOCKED

    return str(active_run.get("level_status", {}).get(str(level_no), STATUS_LOCKED))

func can_open_level(level_no: int) -> bool:
    var status: String = level_status(level_no)
    return status == STATUS_AVAILABLE or status == STATUS_COMPLETED

func begin_level_session(level_no: int) -> Dictionary:
    var session: Dictionary = {
        "level_session_id": IdUtil.uuid_v4(),
        "run_id": active_run.get("run_id", ""),
        "level_no": level_no,
        "active_duration_ms": 0,
        "retry_count": 0,
        "successful_attempt_id": "",
        "started_at": Time.get_unix_time_from_system(),
        "completed_at": 0,
        "attempts": []
    }

    active_run["level_sessions"].append(session)
    return session

func update_level_session(session: Dictionary) -> void:
    var sessions: Array = active_run.get("level_sessions", [])

    for index in range(sessions.size()):
        if sessions[index].get("level_session_id", "") == session.get("level_session_id", ""):
            sessions[index] = session.duplicate(true)
            break

    active_run["level_sessions"] = sessions

func complete_level(level_no: int, score: int, duration_ms: int, badge_id: String, badge_name: String, level_session_id: String) -> void:
    var key: String = str(level_no)
    var earned_stars: int = stars_for_score(score)

    active_run["level_status"][key] = STATUS_COMPLETED
    active_run["level_scores"][key] = score
    active_run["stars_by_level"][key] = earned_stars
    active_run["level_durations_ms"][key] = duration_ms

    if level_no < 5:
        var next_key: String = str(level_no + 1)

        if active_run["level_status"].get(next_key, STATUS_LOCKED) != STATUS_COMPLETED:
            active_run["level_status"][next_key] = STATUS_AVAILABLE
    else:
        active_run["status"] = "COMPLETED"
        active_run["completed_at"] = Time.get_unix_time_from_system()

    var best_scores: Dictionary = profile.get("best_scores_by_level", {})
    best_scores[key] = max(int(best_scores.get(key, 0)), score)
    profile["best_scores_by_level"] = best_scores

    var best_times: Dictionary = profile.get("best_times_by_level", {})
    var old_time: int = int(best_times.get(key, 0))

    if old_time == 0 or duration_ms < old_time:
        best_times[key] = duration_ms

    profile["best_times_by_level"] = best_times

    var best_stars: Dictionary = profile.get("best_stars_by_level", {})
    best_stars[key] = max(int(best_stars.get(key, 0)), earned_stars)
    profile["best_stars_by_level"] = best_stars

    var badges: Dictionary = profile.get("badges", {})
    badges[badge_id] = {
        "earned": true,
        "display_name": badge_name
    }
    profile["badges"] = badges

    var completion_counts: Dictionary = profile.get("completion_counts_by_level", {})
    completion_counts[key] = int(completion_counts.get(key, 0)) + 1
    profile["completion_counts_by_level"] = completion_counts

    if badge_id not in active_run["final_badges"]:
        active_run["final_badges"].append(badge_id)

    _unlock_gallery_for_level(level_no)

    if level_no == 5:
        _archive_completed_run()

    AnalyticsLogger.log_event("level_complete", {
        "level_session_id": level_session_id,
        "level_no": level_no,
        "score": score,
        "stars": earned_stars,
        "active_duration_ms": duration_ms
    })

    SaveManager.request_save()

func _archive_completed_run() -> bool:
    if active_run.is_empty():
        return false

    if str(active_run.get("status", "")) != "COMPLETED":
        return false

    var run_id: String = str(active_run.get("run_id", ""))

    if run_id.is_empty():
        return false

    var history: Array = profile.get("completed_run_history", [])

    for record_value in history:
        if record_value is Dictionary:
            var existing_record: Dictionary = record_value

            if str(existing_record.get("run_id", "")) == run_id:
                return false

    var record: Dictionary = active_run.duplicate(true)
    record["player_name"] = player_display_name()
    record["selected_character_display_name"] = selected_character_display_name()
    record["archived_at"] = Time.get_unix_time_from_system()
    record["badges_snapshot"] = profile.get("badges", {}).duplicate(true)
    record["gallery_unlocks_snapshot"] = profile.get("gallery_unlocks", []).duplicate()
    record["processed_gallery_unlocks_snapshot"] = profile.get("processed_gallery_unlocks", []).duplicate()

    history.append(record)
    profile["completed_run_history"] = history
    profile["active_run_id"] = ""
    return true

func _rebuild_profile_from_completed_history() -> void:
    var history: Array = profile.get("completed_run_history", [])
    var best_scores: Dictionary = {}
    var best_times: Dictionary = {}
    var best_stars: Dictionary = {}
    var badges: Dictionary = {}
    var gallery_unlocks: Array = []
    var processed_unlocks: Array = []
    var completion_counts: Dictionary = {}

    for record_value in history:
        if not record_value is Dictionary:
            continue

        var record: Dictionary = record_value
        var scores: Dictionary = record.get("level_scores", {})
        var durations: Dictionary = record.get("level_durations_ms", {})
        var stars: Dictionary = record.get("stars_by_level", {})
        var statuses: Dictionary = record.get("level_status", {})

        for key_value in scores.keys():
            var key: String = str(key_value)
            best_scores[key] = max(
                int(best_scores.get(key, 0)),
                int(scores.get(key_value, 0))
            )

        for key_value in durations.keys():
            var key: String = str(key_value)
            var duration_ms: int = int(durations.get(key_value, 0))
            var old_duration: int = int(best_times.get(key, 0))

            if duration_ms > 0 and (old_duration == 0 or duration_ms < old_duration):
                best_times[key] = duration_ms

        for key_value in stars.keys():
            var key: String = str(key_value)
            best_stars[key] = max(
                int(best_stars.get(key, 0)),
                int(stars.get(key_value, 0))
            )

        for key_value in statuses.keys():
            if str(statuses.get(key_value, "")) == STATUS_COMPLETED:
                var key: String = str(key_value)
                completion_counts[key] = int(completion_counts.get(key, 0)) + 1

        var badge_snapshot: Dictionary = record.get("badges_snapshot", {})

        for badge_key_value in badge_snapshot.keys():
            var badge_key: String = str(badge_key_value)
            var badge_value = badge_snapshot.get(badge_key_value, {})

            if badge_value is Dictionary:
                badges[badge_key] = badge_value.duplicate(true)

        var gallery_snapshot: Array = record.get("gallery_unlocks_snapshot", [])

        for food_id_value in gallery_snapshot:
            var food_id: String = str(food_id_value)

            if food_id not in gallery_unlocks:
                gallery_unlocks.append(food_id)

        var processed_snapshot: Array = record.get(
            "processed_gallery_unlocks_snapshot",
            []
        )

        for processed_id_value in processed_snapshot:
            var processed_id: String = str(processed_id_value)

            if processed_id not in processed_unlocks:
                processed_unlocks.append(processed_id)

    profile["best_scores_by_level"] = best_scores
    profile["best_times_by_level"] = best_times
    profile["best_stars_by_level"] = best_stars
    profile["badges"] = badges
    profile["gallery_unlocks"] = gallery_unlocks
    profile["processed_gallery_unlocks"] = processed_unlocks
    profile["completion_counts_by_level"] = completion_counts

func export_state() -> Dictionary:
    return {
        "profile": profile.duplicate(true),
        "active_run": active_run.duplicate(true)
    }

func import_state(state: Dictionary) -> void:
    profile = state.get("profile", {}).duplicate(true)
    active_run = state.get("active_run", {}).duplicate(true)

func _unlock_gallery_for_level(level_no: int) -> void:
    var unlocks: Array = profile.get("gallery_unlocks", [])

    for food_value in ContentDatabase.master.get("foods", []):
        var food: Dictionary = food_value

        if int(food.get("introduced_level", 99)) <= level_no:
            var food_id: String = str(food.get("food_id", ""))

            if not food_id.is_empty() and food_id not in unlocks:
                unlocks.append(food_id)

    profile["gallery_unlocks"] = unlocks

    if level_no >= 4:
        var processed_unlocks: Array = profile.get("processed_gallery_unlocks", [])

        for item_value in ContentDatabase.master.get("processed_foods", []):
            var item: Dictionary = item_value
            var processed_id: String = str(item.get("processed_food_id", ""))

            if not processed_id.is_empty() and processed_id not in processed_unlocks:
                processed_unlocks.append(processed_id)

        profile["processed_gallery_unlocks"] = processed_unlocks

func _character_matches_gender(character_id: String, player_gender: String) -> bool:
    if not CHARACTER_DATA.has(character_id):
        return false

    return str(CHARACTER_DATA[character_id].get("gender", "male")) == player_gender

func _infer_gender_from_character_id(character_id: String) -> String:
    if CHARACTER_DATA.has(character_id):
        return str(CHARACTER_DATA[character_id].get("gender", "male"))

    if str(profile.get("preferred_gender", "male")) == "female":
        return "female"

    return "male"

func _is_ascii_letter(character: String) -> bool:
    if character.is_empty():
        return false

    var code: int = character.unicode_at(0)
    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)

func _is_ascii_digit(character: String) -> bool:
    if character.is_empty():
        return false

    var code: int = character.unicode_at(0)
    return code >= 48 and code <= 57
