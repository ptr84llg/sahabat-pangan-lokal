extends Node

const SAVE_PATH = "user://sahabat_pangan_lokal_save_v1_1.json"
const INSTALLATION_PATH = "user://spl_installation_v1.json"
const TEST_SAVE_PATH = "user://spl_test_save.json"
const TEST_INSTALLATION_PATH = "user://spl_test_installation.json"
const SAVE_SCHEMA_VERSION = 2

const V3_ROOT: String = "user://spl_data"
const V3_TEST_ROOT: String = "user://spl_test_data"
const V3_SCHEMA_VERSION: int = 3

var pending_save: bool = false
var cached_installation_id: String = ""
var last_shadow_local_revision: int = 0

func _is_test_mode() -> bool:
	return OS.get_environment("SPL_TEST_MODE") == "1"

func _effective_save_path() -> String:
	return TEST_SAVE_PATH if _is_test_mode() else SAVE_PATH

func _effective_installation_path() -> String:
	return TEST_INSTALLATION_PATH if _is_test_mode() else INSTALLATION_PATH

func _v3_root() -> String:
	return V3_TEST_ROOT if _is_test_mode() else V3_ROOT

func _v3_path(relative_path: String) -> String:
	return _v3_root() + "/" + relative_path.trim_prefix("/")

func has_save() -> bool:
	return FileAccess.file_exists(_effective_save_path())

func get_installation_id() -> String:
	if not cached_installation_id.is_empty():
		return cached_installation_id

	var installation_path: String = _effective_installation_path()

	if FileAccess.file_exists(installation_path):
		var existing_file: FileAccess = FileAccess.open(installation_path, FileAccess.READ)

		if existing_file != null:
			var parsed_value = JSON.parse_string(existing_file.get_as_text())

			if parsed_value is Dictionary:
				var parsed: Dictionary = parsed_value
				var existing_id: String = str(parsed.get("installation_id", "")).strip_edges()

				if not existing_id.is_empty():
					cached_installation_id = existing_id
					return cached_installation_id

	cached_installation_id = IdUtil.uuid_v4()

	var payload: Dictionary = {
		"installation_id": cached_installation_id,
		"created_at": Time.get_unix_time_from_system()
	}

	var file: FileAccess = FileAccess.open(installation_path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(payload, "  "))

	return cached_installation_id

func load_payload() -> Dictionary:
	get_installation_id()

	var save_path: String = _effective_save_path()

	if not FileAccess.file_exists(save_path):
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return {}

	var parsed_value = JSON.parse_string(file.get_as_text())

	if parsed_value is Dictionary:
		return parsed_value

	return {}

func request_save() -> void:
	pending_save = true
	call_deferred("save_now")

func save_now() -> bool:
	var save_path: String = _effective_save_path()

	if not pending_save and FileAccess.file_exists(save_path):
		return true

	pending_save = false

	var payload: Dictionary = {
		"save_schema_version": SAVE_SCHEMA_VERSION,
		"content_version": ContentDatabase.content_version,
		"installation_id": get_installation_id(),
		"saved_at": Time.get_unix_time_from_system(),
		"game_state": GameState.export_state(),
		"settings": SettingsManager.export_state()
	}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		push_error("Tidak dapat menulis save file")
		return false

	file.store_string(JSON.stringify(payload, "  "))
	file.flush()
	file.close()

	if not refresh_v3_shadow(true):
		push_warning("Shadow storage schema v3 tidak dapat diperbarui. Save legacy tetap menjadi sumber aktif.")

	return true

func reset_local_save() -> bool:
	pending_save = false

	var save_path: String = _effective_save_path()

	if not FileAccess.file_exists(save_path):
		return true

	var absolute_path: String = ProjectSettings.globalize_path(save_path)
	var result: Error = DirAccess.remove_absolute(absolute_path)

	return result == OK

func load_v3_active_current() -> Dictionary:
	var current_dir: DirAccess = DirAccess.open(_v3_path("current"))
	if current_dir == null:
		return {}
	var json_files: Array[String] = []
	for file_name_value in current_dir.get_files():
		var file_name: String = str(file_name_value)
		if file_name.ends_with(".json"):
			json_files.append(file_name)
	if json_files.size() != 1:
		return {}
	return _read_json(_v3_path("current/" + json_files[0]))
func commit_v3_native_current(payload: Dictionary) -> bool:
	if payload.is_empty() or not _is_legacy_shadow_owned(payload):
		push_error("V3 native current payload tidak valid atau bukan shadow legacy.")
		return false
	var progress: Dictionary = payload.get("progress", {})
	var id_progress: String = str(progress.get("id_progress", "")).strip_edges()
	if id_progress.is_empty():
		push_error("V3 native current tidak memiliki id_progress.")
		return false
	var current_path: String = _v3_path("current/" + id_progress + ".json")
	var existing: Dictionary = _read_json(current_path)
	if existing.is_empty() or not _is_legacy_shadow_owned(existing):
		push_error("V3 native current target tidak dapat diverifikasi.")
		return false
	var existing_progress: Dictionary = existing.get("progress", {})
	var existing_sync: Dictionary = existing.get("sync_state", {})
	var current_revision: int = maxi(
		int(existing_progress.get("revision", 0)),
		int(existing_sync.get("local_revision", 0))
	)
	var new_revision: int = current_revision + 1
	progress["revision"] = new_revision
	progress["updated_at_unix"] = Time.get_unix_time_from_system()
	payload["progress"] = progress
	var sync_state: Dictionary = payload.get("sync_state", {})
	sync_state["status"] = "shadow_local_only"
	sync_state["local_revision"] = new_revision
	sync_state["pending_event_count"] = _count_pending_events()
	payload["sync_state"] = sync_state
	if not _atomic_write_json(current_path, payload):
		return false
	last_shadow_local_revision = new_revision
	return true
func append_v3_pending_event(event: Dictionary) -> bool:
	if event.is_empty():
		return false
	var event_id: String = str(event.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		push_error("Pending event schema v3 tidak memiliki event_id.")
		return false
	if not _ensure_v3_directories() or not _ensure_empty_pending_event_queue():
		return false
	var line_text: String = JSON.stringify(event)
	var parsed_line: Variant = JSON.parse_string(line_text)
	if not parsed_line is Dictionary:
		push_error("Pending event schema v3 tidak valid.")
		return false
	var pending_path: String = _v3_path("telemetry/pending_events.jsonl")
	var file: FileAccess = FileAccess.open(pending_path, FileAccess.READ_WRITE)
	if file == null:
		push_error("Tidak dapat membuka pending event queue schema v3.")
		return false
	file.seek_end()
	file.store_line(line_text)
	file.flush()
	file.close()
	return true
func refresh_v3_sync_metadata() -> bool:
	var current_payload: Dictionary = load_v3_active_current()
	var local_revision: int = last_shadow_local_revision
	if not current_payload.is_empty():
		var progress: Dictionary = current_payload.get("progress", {})
		var current_sync: Dictionary = current_payload.get("sync_state", {})
		local_revision = maxi(
			int(progress.get("revision", 0)),
			int(current_sync.get("local_revision", 0))
		)
		current_sync["local_revision"] = local_revision
		current_sync["pending_event_count"] = _count_pending_events()
		current_payload["sync_state"] = current_sync
		var id_progress: String = str(progress.get("id_progress", "")).strip_edges()
		if id_progress.is_empty():
			return false
		if not _atomic_write_json(
			_v3_path("current/" + id_progress + ".json"),
			current_payload
		):
			return false
	last_shadow_local_revision = local_revision
	var sync_payload: Dictionary = {
		"schema_version": V3_SCHEMA_VERSION,
		"status": "local_only",
		"shadow_mode": true,
		"local_revision": local_revision,
		"last_server_revision": 0,
		"server_revision": 0,
		"last_sync_at": null,
		"pending_event_count": _count_pending_events(),
		"shadow_refresh_completed_at_unix": Time.get_unix_time_from_system()
	}
	return _atomic_write_json(_v3_path("telemetry/sync_state.json"), sync_payload)
func refresh_v3_shadow(increment_revision: bool = false) -> bool:
	if not _ensure_v3_directories():
		return false
	var installation_id: String = get_installation_id()
	var legacy_installation: Dictionary = _read_json(_effective_installation_path())
	var existing_installation: Dictionary = _read_json(_v3_path("installation.json"))
	var installation_payload: Dictionary = _build_v3_installation_payload(
		installation_id,
		legacy_installation,
		existing_installation
	)
	var identity_path: String = _v3_path("identity.json")
	var existing_identity: Dictionary = _read_json(identity_path)
	if FileAccess.file_exists(identity_path) and existing_identity.is_empty():
		push_error("identity.json schema v3 ada tetapi tidak dapat dibaca. Identity tidak akan dirotasi otomatis.")
		return false
	var identity_payload: Dictionary = AccountManager.ensure_local_identity(
		existing_identity,
		installation_id
	)
	var settings_payload: Dictionary = ProgressManager.normalize_settings(
		SettingsManager.export_state()
	)
	var device_payload: Dictionary = DeviceProfileManager.capture_snapshot(false)
	device_payload["installation_id"] = installation_id
	var game_state: Dictionary = GameState.export_state()
	var history_scan: Dictionary = _scan_v3_history_sources()
	if not bool(history_scan.get("ok", false)):
		push_error(str(history_scan.get("error", "History shadow scan failed.")))
		return false
	var known_history_sources: Dictionary = history_scan.get("sources", {})
	if not _atomic_write_json(_v3_path("installation.json"), installation_payload):
		return false
	if not _atomic_write_json(_v3_path("identity.json"), identity_payload):
		return false
	if not _atomic_write_json(_v3_path("settings.json"), settings_payload):
		return false
	if not _ensure_empty_pending_event_queue():
		return false
	if not _refresh_v3_histories(
		game_state,
		installation_id,
		identity_payload,
		device_payload,
		settings_payload,
		known_history_sources
	):
		return false
	if not _refresh_v3_current(
		game_state,
		installation_id,
		identity_payload,
		device_payload,
		settings_payload,
		increment_revision
	):
		return false
	return refresh_v3_sync_metadata()

func _build_v3_installation_payload(
	installation_id: String,
	legacy_installation: Dictionary,
	existing_installation: Dictionary
) -> Dictionary:
	var first_install_at = existing_installation.get(
		"first_install_at",
		legacy_installation.get("created_at", Time.get_unix_time_from_system())
	)

	return {
		"schema_version": V3_SCHEMA_VERSION,
		"installation_id": installation_id,
		"first_install_at": first_install_at,
		"migrated_from_legacy": true
	}

func _refresh_v3_current(
	game_state: Dictionary,
	installation_id: String,
	identity: Dictionary,
	device: Dictionary,
	settings: Dictionary,
	increment_revision: bool
) -> bool:
	var current_payload: Dictionary = ProgressManager.build_current_from_legacy(
		game_state,
		installation_id,
		identity,
		device,
		settings
	)
	if current_payload.is_empty():
		return _retire_other_shadow_current("")
	var progress: Dictionary = current_payload.get("progress", {})
	var id_progress: String = str(progress.get("id_progress", "")).strip_edges()
	if id_progress.is_empty():
		push_error("V3 shadow current tidak memiliki id_progress.")
		return false
	var current_path: String = _v3_path("current/" + id_progress + ".json")
	var existing_current: Dictionary = {}
	if FileAccess.file_exists(current_path):
		existing_current = _read_json(current_path)
		if not _is_legacy_shadow_owned(existing_current):
			push_error("V3 current target sudah ada tetapi bukan shadow legacy yang aman ditimpa.")
			return false
		current_payload = ProgressManager.merge_existing_v3_native_detail(
			current_payload,
			existing_current
		)
		if not existing_current.is_empty():
			var backup_payload: Dictionary = {
				"schema_version": V3_SCHEMA_VERSION,
				"source_path": current_path,
				"captured_at_unix": Time.get_unix_time_from_system(),
				"payload": existing_current
			}
			if not _atomic_write_json(
				_v3_path("backups/last_safe_snapshot.json"),
				backup_payload
			):
				return false
	var merged_progress: Dictionary = current_payload.get("progress", {})
	var merged_sync: Dictionary = current_payload.get("sync_state", {})
	var local_revision: int = maxi(
		int(merged_progress.get("revision", 0)),
		int(merged_sync.get("local_revision", 0))
	)
	if increment_revision:
		local_revision += 1
	merged_progress["revision"] = local_revision
	merged_progress["updated_at_unix"] = Time.get_unix_time_from_system()
	current_payload["progress"] = merged_progress
	merged_sync["local_revision"] = local_revision
	merged_sync["pending_event_count"] = _count_pending_events()
	current_payload["sync_state"] = merged_sync
	last_shadow_local_revision = local_revision
	if not _atomic_write_json(current_path, current_payload):
		return false
	return _retire_other_shadow_current(id_progress + ".json")

func _retire_other_shadow_current(active_file_name: String) -> bool:
	var current_dir_path: String = _v3_path("current")
	var current_dir: DirAccess = DirAccess.open(current_dir_path)

	if current_dir == null:
		push_error("Tidak dapat membuka folder current schema v3.")
		return false

	var files: PackedStringArray = current_dir.get_files()

	for file_name_value in files:
		var file_name: String = str(file_name_value)

		if not file_name.ends_with(".json"):
			continue

		if not active_file_name.is_empty() and file_name == active_file_name:
			continue

		var source_path: String = current_dir_path + "/" + file_name
		var payload: Dictionary = _read_json(source_path)

		if payload.is_empty():
			push_error("Current shadow lama tidak dapat dibaca: " + file_name)
			return false

		if not _is_legacy_shadow_owned(payload):
			push_error("Current file bukan milik shadow legacy dan tidak akan dipindahkan: " + file_name)
			return false

		var retired_name: String = (
            "retired_current_"
			+ str(int(Time.get_unix_time_from_system()))
			+ "_"
			+ file_name
		)
		var destination_path: String = _v3_path("backups/" + retired_name)
		var rename_error: Error = DirAccess.rename_absolute(
			ProjectSettings.globalize_path(source_path),
			ProjectSettings.globalize_path(destination_path)
		)

		if rename_error != OK:
			push_error("Gagal memindahkan current shadow lama ke backup.")
			return false

	return true

func _refresh_v3_histories(
	game_state: Dictionary,
	installation_id: String,
	identity: Dictionary,
	device: Dictionary,
	settings: Dictionary,
	known_sources: Dictionary
) -> bool:
	var profile: Dictionary = game_state.get("profile", {})
	var completed_history: Array = profile.get("completed_run_history", [])

	for record_value in completed_history:
		if not record_value is Dictionary:
			continue

		var record: Dictionary = record_value

		if not ProgressManager.is_legacy_history_eligible(record):
			continue

		var run_id: String = str(record.get("run_id", "")).strip_edges()
		var source_progress_id: String = ProgressManager.progress_id_from_legacy_run_id(run_id)

		if source_progress_id.is_empty():
			continue

		if known_sources.has(source_progress_id):
			continue

		var id_history: String = "HIS-" + IdUtil.uuid_v4()
		var history_payload: Dictionary = ProgressManager.build_history_from_legacy(
			record,
			id_history,
			installation_id,
			identity,
			device,
			settings
		)

		var source_current: Dictionary = _find_v3_current_by_progress_id(
			source_progress_id
		)
		if not source_current.is_empty():
			history_payload = ProgressManager.merge_current_native_detail_into_history(
				history_payload,
				source_current
			)

		if history_payload.is_empty():
			push_error("Gagal membangun history shadow dari run legacy: " + run_id)
			return false

		var history_path: String = _v3_path("history/" + id_history + ".json")

		if not _atomic_write_json(history_path, history_payload):
			return false

		known_sources[source_progress_id] = id_history

	return true

func _scan_v3_history_sources() -> Dictionary:
	var history_dir_path: String = _v3_path("history")
	var history_dir: DirAccess = DirAccess.open(history_dir_path)
	var sources: Dictionary = {}

	if history_dir == null:
		return {
			"ok": false,
			"error": "Tidak dapat membuka folder history schema v3.",
			"sources": sources
		}

	var files: PackedStringArray = history_dir.get_files()

	for file_name_value in files:
		var file_name: String = str(file_name_value)

		if not file_name.ends_with(".json"):
			continue

		var payload: Dictionary = _read_json(history_dir_path + "/" + file_name)

		if payload.is_empty():
			return {
				"ok": false,
				"error": "History schema v3 tidak dapat dibaca: " + file_name,
				"sources": sources
			}

		var history: Dictionary = payload.get("history", {})
		var source_progress_id: String = str(
			history.get("source_progress_id", "")
		).strip_edges()

		if source_progress_id.is_empty():
			return {
				"ok": false,
				"error": "History schema v3 tanpa source_progress_id: " + file_name,
				"sources": sources
			}

		if sources.has(source_progress_id):
			return {
				"ok": false,
				"error": "Duplikasi source_progress_id pada history schema v3: " + source_progress_id,
				"sources": sources
			}

		sources[source_progress_id] = str(history.get("id_history", ""))

	return {
		"ok": true,
		"error": "",
		"sources": sources
	}

func _find_v3_current_by_progress_id(id_progress: String) -> Dictionary:
	if id_progress.is_empty():
		return {}
	var path: String = _v3_path("current/" + id_progress + ".json")
	var payload: Dictionary = _read_json(path)
	if payload.is_empty() or not _is_legacy_shadow_owned(payload):
		return {}
	return payload
func _count_pending_events() -> int:
	var pending_path: String = _v3_path("telemetry/pending_events.jsonl")
	if not FileAccess.file_exists(pending_path):
		return 0
	var file: FileAccess = FileAccess.open(pending_path, FileAccess.READ)
	if file == null:
		return 0
	var count: int = 0
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			count += 1
	file.close()
	return count

func _is_legacy_shadow_owned(payload: Dictionary) -> bool:
	var migration: Dictionary = payload.get("migration", {})
	return str(migration.get("shadow_source", "")) == "legacy_v2"

func _ensure_v3_directories() -> bool:
	var directories: Array = [
		_v3_root(),
		_v3_path("current"),
		_v3_path("history"),
		_v3_path("telemetry"),
		_v3_path("backups")
	]

	for directory_path in directories:
		var absolute_path: String = ProjectSettings.globalize_path(directory_path)
		var error_code: Error = DirAccess.make_dir_recursive_absolute(absolute_path)

		if error_code != OK:
			var directory_check: DirAccess = DirAccess.open(directory_path)

			if directory_check == null:
				push_error("Tidak dapat membuat folder schema v3: " + directory_path)
				return false

	return true

func _ensure_empty_pending_event_queue() -> bool:
	var pending_path: String = _v3_path("telemetry/pending_events.jsonl")

	if FileAccess.file_exists(pending_path):
		return true

	var file: FileAccess = FileAccess.open(pending_path, FileAccess.WRITE)

	if file == null:
		push_error("Tidak dapat membuat pending event queue schema v3.")
		return false

	file.flush()
	file.close()
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)

	if file == null:
		return {}

	var text: String = file.get_as_text()
	file.close()

	var parsed_value = JSON.parse_string(text)

	if parsed_value is Dictionary:
		return parsed_value

	return {}

func _atomic_write_json(path: String, payload: Dictionary) -> bool:
	var candidate_text: String = JSON.stringify(payload, "  ")
	var parsed_candidate = JSON.parse_string(candidate_text)

	if not parsed_candidate is Dictionary:
		push_error("Candidate JSON schema v3 tidak valid: " + path)
		return false

	var temp_path: String = path + ".tmp"
	var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)

	if temp_file == null:
		push_error("Tidak dapat menulis file temporary schema v3: " + temp_path)
		return false

	temp_file.store_string(candidate_text)
	temp_file.flush()
	temp_file.close()

	var verify_payload: Dictionary = _read_json(temp_path)

	if verify_payload.is_empty() and not payload.is_empty():
		_remove_file_if_exists(temp_path)
		push_error("Read-back candidate schema v3 gagal: " + path)
		return false

	var rename_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(path)
	)

	if rename_error != OK:
		_remove_file_if_exists(temp_path)
		push_error("Atomic replace schema v3 gagal: " + path)
		return false

	var final_payload: Dictionary = _read_json(path)

	if final_payload.is_empty() and not payload.is_empty():
		push_error("Read-back final schema v3 gagal: " + path)
		return false

	return true

func _remove_file_if_exists(path: String) -> void:
	if not FileAccess.file_exists(path):
		return

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
