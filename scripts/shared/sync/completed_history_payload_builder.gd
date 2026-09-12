extends RefCounted

const API_SCHEMA_VERSION: int = 1
const SAVE_SCHEMA_VERSION: int = 3
const REQUIRED_LEVEL_KEYS: Array[String] = ["1", "2", "3", "4", "5"]
const FORBIDDEN_KEYS: Array[String] = [
	"player_name",
	"runtime_state",
	"completed_run",
	"precise_location",
	"latitude",
	"longitude",
	"email",
	"phone",
	"telephone",
	"imei",
	"mac",
	"mac_address",
	"serial",
	"android_id",
	"advertising_id",
	"adapter_name",
	"credential",
	"credentials",
	"api_key",
	"secret",
	"private_key",
	"settings",
	"current_progress",
	"checkpoint"
]

static func freeze_client_snapshot(native_history: Dictionary) -> Dictionary:
	var version: Dictionary = native_history.get("version", {})
	return {
		"app_version": str(version.get("app_version", UpdateManager.get_app_version())),
		"version_code": int(version.get("version_code", UpdateManager.get_version_code())),
		"save_schema_version": int(version.get("save_schema_version", SAVE_SCHEMA_VERSION)),
		"game_version": str(version.get("game_version", "")),
		"content_version": str(version.get("content_version", ""))
	}

static func build_payload(native_history: Dictionary, client_snapshot: Dictionary) -> Dictionary:
	var history: Dictionary = native_history.get("history", {})
	var history_id: String = str(history.get("id_history", "")).strip_edges()
	if not history_id.begins_with("HIS-"):
		return {}

	var run_id: String = history_id.trim_prefix("HIS-")
	if run_id.is_empty():
		return {}

	var identity: Dictionary = native_history.get("identity", {})
	var character: Dictionary = native_history.get("character", {})
	var device: Dictionary = native_history.get("device", {})
	var device_os: Dictionary = device.get("os", {})
	var device_display: Dictionary = device.get("display", {})
	var input_capabilities: Dictionary = device.get("input_capabilities", {})
	var native_levels: Dictionary = native_history.get("levels", {})
	var levels: Dictionary = {}

	for key in REQUIRED_LEVEL_KEYS:
		var level_value: Variant = native_levels.get(key, null)
		if not level_value is Dictionary:
			return {}
		var level: Dictionary = level_value
		levels[key] = level.duplicate(true)

	var summary: Dictionary = native_history.get("summary", {})

	return {
		"api_schema_version": API_SCHEMA_VERSION,
		"history_id": history_id,
		"run_id": run_id,
		"identity": {
			"identity_id": str(identity.get("identity_id", "")),
			"installation_id": str(identity.get("installation_id", ""))
		},
		"client": {
			"app_version": str(client_snapshot.get("app_version", "")),
			"version_code": int(client_snapshot.get("version_code", 0)),
			"save_schema_version": int(client_snapshot.get("save_schema_version", 0)),
			"game_version": str(client_snapshot.get("game_version", "")),
			"content_version": str(client_snapshot.get("content_version", ""))
		},
		"run": {
			"source_progress_id": str(history.get("source_progress_id", "")),
			"status": str(history.get("status", "")),
			"started_at_unix": history.get("started_at_unix", 0),
			"completed_at_unix": history.get("completed_at_unix", 0)
		},
		"character": {
			"player_gender": str(character.get("player_gender", "")),
			"character_id": str(character.get("character_id", ""))
		},
		"device": {
			"platform": device.get("platform", null),
			"device_type": device.get("device_type", null),
			"os": {
				"name": device_os.get("name", null),
				"version": device_os.get("version", null),
				"architecture": device_os.get("architecture", null)
			},
			"display": {
				"game_viewport_width": device_display.get("game_viewport_width", null),
				"game_viewport_height": device_display.get("game_viewport_height", null)
			},
			"input_capabilities": {
				"touch": input_capabilities.get("touch", false)
			}
		},
		"levels": levels,
		"summary": {
			"run_status": str(summary.get("run_status", "")),
			"total_score": int(summary.get("total_score", 0)),
			"total_stars": int(summary.get("total_stars", 0)),
			"total_duration_ms": int(summary.get("total_duration_ms", 0)),
			"completed_level_count": int(summary.get("completed_level_count", 0))
		}
	}

static func validate_payload(payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return _failure("empty_payload")

	if not _has_exact_keys(payload, [
		"api_schema_version", "history_id", "run_id", "identity", "client",
		"run", "character", "device", "levels", "summary"
	]):
		return _failure("top_level_contract_mismatch")

	if int(payload.get("api_schema_version", 0)) != API_SCHEMA_VERSION:
		return _failure("api_schema_version_invalid")

	var history_id: String = str(payload.get("history_id", ""))
	var run_id: String = str(payload.get("run_id", ""))
	if history_id != "HIS-" + run_id or run_id.is_empty():
		return _failure("history_id_mismatch")

	var identity: Dictionary = payload.get("identity", {})
	if not _has_exact_keys(identity, ["identity_id", "installation_id"]):
		return _failure("identity_contract_mismatch")
	if str(identity.get("identity_id", "")).is_empty():
		return _failure("identity_id_missing")
	if str(identity.get("installation_id", "")).is_empty():
		return _failure("installation_id_missing")

	var client: Dictionary = payload.get("client", {})
	if not _has_exact_keys(client, [
		"app_version", "version_code", "save_schema_version",
		"game_version", "content_version"
	]):
		return _failure("client_contract_mismatch")
	if int(client.get("save_schema_version", 0)) != SAVE_SCHEMA_VERSION:
		return _failure("save_schema_version_invalid")
	if str(client.get("app_version", "")).is_empty():
		return _failure("app_version_missing")
	if int(client.get("version_code", 0)) <= 0:
		return _failure("version_code_invalid")
	if str(client.get("game_version", "")).is_empty():
		return _failure("game_version_missing")
	if str(client.get("content_version", "")).is_empty():
		return _failure("content_version_missing")

	var run: Dictionary = payload.get("run", {})
	if not _has_exact_keys(run, [
		"source_progress_id", "status", "started_at_unix", "completed_at_unix"
	]):
		return _failure("run_contract_mismatch")
	if str(run.get("source_progress_id", "")) != "PRG-" + run_id:
		return _failure("source_progress_id_mismatch")
	if str(run.get("status", "")).to_lower() != "completed":
		return _failure("run_status_invalid")

	var started_at: float = float(run.get("started_at_unix", 0))
	var completed_at: float = float(run.get("completed_at_unix", 0))
	if completed_at <= 0.0:
		return _failure("completed_at_invalid")
	if started_at > 0.0 and completed_at < started_at:
		return _failure("timestamp_order_invalid")

	var character: Dictionary = payload.get("character", {})
	if not _has_exact_keys(character, ["player_gender", "character_id"]):
		return _failure("character_contract_mismatch")

	var device: Dictionary = payload.get("device", {})
	if not _has_exact_keys(device, [
		"platform", "device_type", "os", "display", "input_capabilities"
	]):
		return _failure("device_contract_mismatch")
	if not _has_exact_keys(device.get("os", {}), ["name", "version", "architecture"]):
		return _failure("device_os_contract_mismatch")
	if not _has_exact_keys(device.get("display", {}), [
		"game_viewport_width", "game_viewport_height"
	]):
		return _failure("device_display_contract_mismatch")
	if not _has_exact_keys(device.get("input_capabilities", {}), ["touch"]):
		return _failure("input_contract_mismatch")

	var levels: Dictionary = payload.get("levels", {})
	if levels.size() != REQUIRED_LEVEL_KEYS.size():
		return _failure("levels_count_invalid")
	for key in REQUIRED_LEVEL_KEYS:
		if not levels.has(key):
			return _failure("level_missing_" + key)
		if not levels.get(key) is Dictionary:
			return _failure("level_not_object_" + key)

	var summary: Dictionary = payload.get("summary", {})
	if not _has_exact_keys(summary, [
		"run_status", "total_score", "total_stars",
		"total_duration_ms", "completed_level_count"
	]):
		return _failure("summary_contract_mismatch")
	if str(summary.get("run_status", "")).to_upper() != "COMPLETED":
		return _failure("summary_run_status_invalid")
	if int(summary.get("completed_level_count", 0)) != 5:
		return _failure("completed_level_count_invalid")

	var privacy_result: Dictionary = _privacy_scan(payload, "root")
	if not bool(privacy_result.get("ok", false)):
		return privacy_result

	return {"ok": true, "error": ""}

static func _has_exact_keys(payload: Dictionary, expected: Array) -> bool:
	if payload.size() != expected.size():
		return false
	for key_value in expected:
		var key: String = str(key_value)
		if not payload.has(key):
			return false
	return true

static func _privacy_scan(value: Variant, path: String) -> Dictionary:
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key_value in dictionary.keys():
			var key: String = str(key_value)
			if FORBIDDEN_KEYS.has(key.to_lower()):
				return _failure("forbidden_field:" + path + "." + key)
			var nested_result: Dictionary = _privacy_scan(
				dictionary.get(key_value),
				path + "." + key
			)
			if not bool(nested_result.get("ok", false)):
				return nested_result
	elif value is Array:
		var array: Array = value
		for index in range(array.size()):
			var nested_result: Dictionary = _privacy_scan(
				array[index],
				path + "[" + str(index) + "]"
			)
			if not bool(nested_result.get("ok", false)):
				return nested_result

	return {"ok": true, "error": ""}

static func _failure(error_code: String) -> Dictionary:
	return {"ok": false, "error": error_code}
