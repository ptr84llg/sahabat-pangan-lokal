extends Node

const SCHEMA_VERSION: int = 3
const STORAGE_MODE: String = "native"

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
	normalized["music_volume"] = clampf(
		float(normalized.get("music_volume", 0.80)), 0.0, 1.0
	)
	normalized["sfx_volume"] = clampf(
		float(normalized.get("sfx_volume", 0.80)), 0.0, 1.0
	)
	normalized["muted"] = bool(normalized.get("muted", false))
	normalized["button_hover_enabled"] = bool(
		normalized.get("button_hover_enabled", true)
	)
	normalized["button_click_enabled"] = bool(
		normalized.get("button_click_enabled", true)
	)
	normalized["mouse_click_enabled"] = bool(
		normalized.get("mouse_click_enabled", true)
	)
	return normalized

func build_native_current(
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
	return {
		"schema_version": SCHEMA_VERSION,
		"storage_mode": STORAGE_MODE,
		"version": _version_block(run),
		"device": _device_snapshot(device, installation_id),
		"identity": identity.duplicate(true),
		"progress": {
			"id_progress": "PRG-" + run_id,
			"status": "current",
			"revision": 0,
			"created_at_unix": run.get("started_at", 0),
			"updated_at_unix": Time.get_unix_time_from_system()
		},
		"settings": normalize_settings(settings),
		"character": _character_snapshot(profile, run),
		"levels": _build_levels(run),
		"summary": _build_summary(run),
		"runtime_state": {
			"active_run": run.duplicate(true)
		},
		"sync_state": {
			"status": "local_only",
			"local_revision": 0,
			"last_server_revision": 0,
			"server_revision": 0,
			"last_sync_at": null,
			"pending_event_count": 0
		}
	}

func merge_native_detail(
	fresh_payload: Dictionary,
	existing_payload: Dictionary
) -> Dictionary:
	if fresh_payload.is_empty() or existing_payload.is_empty():
		return fresh_payload
	if not _same_progress(fresh_payload, existing_payload):
		return fresh_payload
	_merge_level_games(fresh_payload, existing_payload)
	var fresh_progress: Dictionary = fresh_payload.get("progress", {})
	var existing_progress: Dictionary = existing_payload.get("progress", {})
	var fresh_sync: Dictionary = fresh_payload.get("sync_state", {})
	var existing_sync: Dictionary = existing_payload.get("sync_state", {})
	var revision: int = maxi(
		int(existing_progress.get("revision", 0)),
		int(existing_sync.get("local_revision", 0))
	)
	fresh_progress["revision"] = revision
	fresh_payload["progress"] = fresh_progress
	fresh_sync["local_revision"] = revision
	fresh_sync["pending_event_count"] = int(
		existing_sync.get("pending_event_count", 0)
	)
	fresh_payload["sync_state"] = fresh_sync
	return fresh_payload

func build_native_history(
	record: Dictionary,
	profile: Dictionary,
	installation_id: String,
	identity: Dictionary,
	device: Dictionary
) -> Dictionary:
	var run_id: String = str(record.get("run_id", "")).strip_edges()
	if run_id.is_empty():
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"storage_mode": STORAGE_MODE,
		"version": _version_block(record),
		"device": _device_snapshot(device, installation_id),
		"identity": identity.duplicate(true),
		"history": {
			"id_history": "HIS-" + run_id,
			"source_progress_id": "PRG-" + run_id,
			"status": "completed",
			"started_at_unix": record.get("started_at", 0),
			"completed_at_unix": record.get("completed_at", 0),
			"created_at_unix": Time.get_unix_time_from_system()
		},
		"character": _character_snapshot(profile, record),
		"levels": _build_levels(record),
		"summary": _build_summary(record),
		"runtime_state": {
			"completed_run": record.duplicate(true)
		}
	}

func merge_history_detail(
	fresh_history: Dictionary,
	existing_history: Dictionary
) -> Dictionary:
	if fresh_history.is_empty() or existing_history.is_empty():
		return fresh_history
	var fresh_block: Dictionary = fresh_history.get("history", {})
	var existing_block: Dictionary = existing_history.get("history", {})
	if str(fresh_block.get("id_history", "")) != str(
		existing_block.get("id_history", "")
	):
		return fresh_history
	_merge_level_games(fresh_history, existing_history)
	return fresh_history

func merge_current_detail_into_history(
	history_payload: Dictionary,
	current_payload: Dictionary
) -> Dictionary:
	if history_payload.is_empty() or current_payload.is_empty():
		return history_payload
	var history: Dictionary = history_payload.get("history", {})
	var progress: Dictionary = current_payload.get("progress", {})
	if str(history.get("source_progress_id", "")) != str(
		progress.get("id_progress", "")
	):
		return history_payload
	_merge_level_games(history_payload, current_payload)
	return history_payload

func _same_progress(a: Dictionary, b: Dictionary) -> bool:
	var a_progress: Dictionary = a.get("progress", {})
	var b_progress: Dictionary = b.get("progress", {})
	var a_id: String = str(a_progress.get("id_progress", "")).strip_edges()
	var b_id: String = str(b_progress.get("id_progress", "")).strip_edges()
	return not a_id.is_empty() and a_id == b_id

func _merge_level_games(
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
		destination_levels[key] = destination_level
	destination_payload["levels"] = destination_levels

func _build_levels(run: Dictionary) -> Dictionary:
	var levels: Dictionary = {}
	var statuses: Dictionary = run.get("level_status", {})
	var scores: Dictionary = run.get("level_scores", {})
	var stars: Dictionary = run.get("stars_by_level", {})
	var durations: Dictionary = run.get("level_durations_ms", {})
	for level_no in range(1, 6):
		var key: String = str(level_no)
		var status: String = _normalize_level_status(
			str(statuses.get(key, "LOCKED"))
		)
		var score: int = int(scores.get(key, 0))
		var star_count: int = int(stars.get(key, 0))
		var duration_ms: int = int(durations.get(key, 0))
		levels[key] = {
			"level_id": "L" + key,
			"level_no": level_no,
			"status": status,
			"games": {},
			"level_summary": {
				"status": status,
				"score": score,
				"stars": star_count,
				"total_duration_ms": duration_ms
			}
		}
	return levels

func _normalize_level_status(value: String) -> String:
	var upper: String = value.to_upper()
	if upper == "COMPLETED":
		return "completed"
	if upper == "AVAILABLE":
		return "available"
	if upper == "IN_PROGRESS":
		return "in_progress"
	return "locked"

func _build_summary(run: Dictionary) -> Dictionary:
	var scores: Dictionary = run.get("level_scores", {})
	var stars: Dictionary = run.get("stars_by_level", {})
	var durations: Dictionary = run.get("level_durations_ms", {})
	var total_score: int = 0
	var total_stars: int = 0
	var total_duration_ms: int = 0
	for value in scores.values():
		total_score += int(value)
	for value in stars.values():
		total_stars += int(value)
	for value in durations.values():
		total_duration_ms += int(value)
	return {
		"run_status": str(run.get("status", "")),
		"total_score": total_score,
		"total_stars": total_stars,
		"total_duration_ms": total_duration_ms,
		"completed_level_count": _completed_level_count(run)
	}

func _completed_level_count(run: Dictionary) -> int:
	var count: int = 0
	var statuses: Dictionary = run.get("level_status", {})
	for value in statuses.values():
		if str(value).to_upper() == "COMPLETED":
			count += 1
	return count

func _character_snapshot(profile: Dictionary, run: Dictionary) -> Dictionary:
	return {
		"player_name": str(profile.get("display_name", "Pemain")),
		"player_gender": str(
			run.get(
				"selected_gender",
				profile.get("preferred_gender", "male")
			)
		),
		"character_id": str(run.get("selected_character_id", ""))
	}

func _device_snapshot(
	device: Dictionary,
	installation_id: String
) -> Dictionary:
	var snapshot: Dictionary = device.duplicate(true)
	snapshot["installation_id"] = installation_id
	return snapshot

func _version_block(run: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"game_version": str(run.get("game_version", "levels1-5-v1.4")),
		"content_version": str(
			run.get("content_version", ContentDatabase.content_version)
		)
	}