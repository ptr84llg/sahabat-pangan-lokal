extends Node

const SCHEMA_VERSION: int = 3
const STORAGE_MODE: String = "native"
const ROOT: String = "user://spl_data"
const TEST_ROOT: String = "user://spl_test_data"
const RETIRED_SAVE_PATHS: Array[String] = [
	"user://sahabat_pangan_lokal_save_v1_1.json",
	"user://spl_installation_v1.json",
	"user://spl_test_save.json",
	"user://spl_test_installation.json"
]

var pending_save: bool = false
var cached_installation_id: String = ""
var native_storage_initialized: bool = false

func _is_test_mode() -> bool:
	return OS.get_environment("SPL_TEST_MODE") == "1"

func _root() -> String:
	return TEST_ROOT if _is_test_mode() else ROOT

func _path(relative_path: String) -> String:
	return _root() + "/" + relative_path.trim_prefix("/")

func initialize_native_storage() -> bool:
	if native_storage_initialized:
		return true

	var marker: Dictionary = _read_json(_path("storage.json"))
	if not _is_valid_native_marker(marker):
		if not _fresh_reset_storage():
			return false
	else:
		if not _ensure_directories():
			return false
		if not _ensure_pending_event_queue():
			return false
		if not _ensure_installation():
			return false
		if not _ensure_identity():
			return false
		if not FileAccess.file_exists(_path("settings.json")):
			if not _atomic_write_json(
				_path("settings.json"),
				ProgressManager.normalize_settings({})
			):
				return false

	native_storage_initialized = true
	return true

func has_save() -> bool:
	if not initialize_native_storage():
		return false
	if not _read_json(_path("profile.json")).is_empty():
		return true
	if not load_v3_active_current().is_empty():
		return true
	return not load_v3_history_records().is_empty()

func get_installation_id() -> String:
	if not cached_installation_id.is_empty():
		return cached_installation_id
	if not initialize_native_storage():
		return ""
	var installation: Dictionary = _read_json(_path("installation.json"))
	cached_installation_id = str(
		installation.get("installation_id", "")
	).strip_edges()
	return cached_installation_id

func load_native_settings() -> Dictionary:
	if not initialize_native_storage():
		return ProgressManager.normalize_settings({})
	var settings: Dictionary = _read_json(_path("settings.json"))
	return ProgressManager.normalize_settings(settings)

func load_native_game_state() -> Dictionary:
	if not initialize_native_storage():
		return {}

	var profile_document: Dictionary = _read_json(_path("profile.json"))
	var profile: Dictionary = profile_document.get("profile", {})
	var active_run: Dictionary = {}
	var current: Dictionary = load_v3_active_current()

	if not current.is_empty():
		var runtime_state: Dictionary = current.get("runtime_state", {})
		var active_value: Variant = runtime_state.get("active_run", {})
		if active_value is Dictionary:
			active_run = active_value.duplicate(true)

	if profile.is_empty() and active_run.is_empty():
		return {}

	return {
		"profile": profile.duplicate(true),
		"active_run": active_run
	}

func request_save() -> void:
	pending_save = true
	call_deferred("save_now")

func save_now() -> bool:
	if not initialize_native_storage():
		return false

	pending_save = false
	var installation_id: String = get_installation_id()
	if installation_id.is_empty():
		push_error("Native V3 installation_id tidak tersedia.")
		return false

	var state: Dictionary = GameState.export_state()
	var profile: Dictionary = state.get("profile", {})
	var active_run: Dictionary = state.get("active_run", {})
	var settings: Dictionary = ProgressManager.normalize_settings(
		SettingsManager.export_state()
	)
	var identity: Dictionary = _read_json(_path("identity.json"))
	var device: Dictionary = DeviceProfileManager.capture_snapshot(false)
	device["installation_id"] = installation_id
	var current_before: Dictionary = load_v3_active_current()

	if not _atomic_write_json(
		_path("profile.json"),
		{
			"schema_version": SCHEMA_VERSION,
			"storage_mode": STORAGE_MODE,
			"profile": profile.duplicate(true),
			"updated_at_unix": Time.get_unix_time_from_system()
		}
	):
		return false

	if not _atomic_write_json(_path("settings.json"), settings):
		return false
	if not _atomic_write_json(_path("device.json"), device):
		return false

	if not _sync_native_histories(
		profile,
		active_run,
		current_before,
		installation_id,
		identity,
		device
	):
		return false

	if active_run.is_empty():
		if not _clear_current_files():
			return false
	else:
		var fresh_current: Dictionary = ProgressManager.build_native_current(
			state,
			installation_id,
			identity,
			device,
			settings
		)
		if fresh_current.is_empty():
			push_error("Native V3 current gagal dibangun dari GameState.")
			return false
		fresh_current = ProgressManager.merge_native_detail(
			fresh_current,
			current_before
		)
		if not commit_v3_native_current(fresh_current):
			return false

	return refresh_v3_sync_metadata()

func reset_local_save() -> bool:
	pending_save = false
	cached_installation_id = ""
	native_storage_initialized = false
	if not _fresh_reset_storage():
		return false
	native_storage_initialized = true
	return true

func load_v3_active_current() -> Dictionary:
	if not _ensure_directories():
		return {}
	var current_dir: DirAccess = DirAccess.open(_path("current"))
	if current_dir == null:
		return {}
	var files: Array[String] = []
	for value in current_dir.get_files():
		var file_name: String = str(value)
		if file_name.ends_with(".json"):
			files.append(file_name)
	if files.size() != 1:
		return {}
	var payload: Dictionary = _read_json(_path("current/" + files[0]))
	if not _is_native_payload(payload):
		return {}
	return payload

func load_v3_history_records() -> Array:
	var records: Array = []
	if not _ensure_directories():
		return records
	var history_dir: DirAccess = DirAccess.open(_path("history"))
	if history_dir == null:
		return records
	var files: PackedStringArray = history_dir.get_files()
	files.sort()
	for value in files:
		var file_name: String = str(value)
		if not file_name.ends_with(".json"):
			continue
		var payload: Dictionary = _read_json(_path("history/" + file_name))
		if not _is_native_payload(payload):
			continue
		var history: Dictionary = payload.get("history", {})
		if str(history.get("id_history", "")).strip_edges().is_empty():
			continue
		records.append(payload.duplicate(true))
	return records

func commit_v3_native_current(payload: Dictionary) -> bool:
	if not initialize_native_storage():
		return false
	if not _is_native_payload(payload):
		push_error("Native V3 current payload tidak valid.")
		return false

	var progress: Dictionary = payload.get("progress", {})
	var id_progress: String = str(
		progress.get("id_progress", "")
	).strip_edges()
	if id_progress.is_empty():
		push_error("Native V3 current tidak memiliki id_progress.")
		return false

	var existing: Dictionary = load_v3_active_current()
	var current_revision: int = int(progress.get("revision", 0))
	if not existing.is_empty():
		var existing_progress: Dictionary = existing.get("progress", {})
		var existing_id: String = str(
			existing_progress.get("id_progress", "")
		).strip_edges()
		if existing_id == id_progress:
			current_revision = maxi(
				current_revision,
				int(existing_progress.get("revision", 0))
			)

	var new_revision: int = current_revision + 1
	progress["revision"] = new_revision
	progress["updated_at_unix"] = Time.get_unix_time_from_system()
	payload["progress"] = progress
	payload["schema_version"] = SCHEMA_VERSION
	payload["storage_mode"] = STORAGE_MODE

	var sync_state: Dictionary = payload.get("sync_state", {})
	sync_state["status"] = "local_only"
	sync_state["local_revision"] = new_revision
	sync_state["pending_event_count"] = _count_pending_events()
	payload["sync_state"] = sync_state

	if not _clear_current_files(id_progress):
		return false
	return _atomic_write_json(
		_path("current/" + id_progress + ".json"),
		payload
	)

func append_v3_pending_event(event: Dictionary) -> bool:
	if event.is_empty():
		return false
	var event_id: String = str(event.get("event_id", "")).strip_edges()
	if event_id.is_empty():
		push_error("Native V3 event tidak memiliki event_id.")
		return false
	if not initialize_native_storage() or not _ensure_pending_event_queue():
		return false

	var line_text: String = JSON.stringify(event)
	if not JSON.parse_string(line_text) is Dictionary:
		return false

	var pending_path: String = _path("telemetry/pending_events.jsonl")
	var file: FileAccess = FileAccess.open(pending_path, FileAccess.READ_WRITE)
	if file == null:
		return false
	file.seek_end()
	file.store_line(line_text)
	file.flush()
	file.close()
	return true

func refresh_v3_sync_metadata() -> bool:
	if not initialize_native_storage():
		return false
	var current: Dictionary = load_v3_active_current()
	var local_revision: int = 0
	if not current.is_empty():
		var progress: Dictionary = current.get("progress", {})
		var sync_state: Dictionary = current.get("sync_state", {})
		local_revision = maxi(
			int(progress.get("revision", 0)),
			int(sync_state.get("local_revision", 0))
		)
		sync_state["status"] = "local_only"
		sync_state["local_revision"] = local_revision
		sync_state["pending_event_count"] = _count_pending_events()
		current["sync_state"] = sync_state
		var id_progress: String = str(
			progress.get("id_progress", "")
		).strip_edges()
		if not id_progress.is_empty():
			if not _atomic_write_json(
				_path("current/" + id_progress + ".json"),
				current
			):
				return false

	return _write_sync_metadata(local_revision)

func _write_sync_metadata(local_revision: int) -> bool:
	return _atomic_write_json(
		_path("telemetry/sync_state.json"),
		{
			"schema_version": SCHEMA_VERSION,
			"storage_mode": STORAGE_MODE,
			"status": "local_only",
			"local_revision": local_revision,
			"last_server_revision": 0,
			"server_revision": 0,
			"last_sync_at": null,
			"pending_event_count": _count_pending_events(),
			"updated_at_unix": Time.get_unix_time_from_system()
		}
	)

func _fresh_reset_storage() -> bool:
	for retired_path in RETIRED_SAVE_PATHS:
		if not _remove_file(retired_path):
			return false
	if not _remove_tree(_root()):
		return false
	if not _ensure_directories():
		return false
	if not _atomic_write_json(
		_path("storage.json"),
		{
			"schema_version": SCHEMA_VERSION,
			"storage_mode": STORAGE_MODE,
			"created_at_unix": Time.get_unix_time_from_system(),
			"fresh_cutover": true
		}
	):
		return false
	if not _ensure_installation():
		return false
	if not _ensure_identity():
		return false
	if not _atomic_write_json(
		_path("settings.json"),
		ProgressManager.normalize_settings({})
	):
		return false
	if not _ensure_pending_event_queue():
		return false
	return _write_sync_metadata(0)

func _ensure_installation() -> bool:
	var installation: Dictionary = _read_json(_path("installation.json"))
	var installation_id: String = str(
		installation.get("installation_id", "")
	).strip_edges()
	if not installation_id.is_empty():
		cached_installation_id = installation_id
		return true

	cached_installation_id = IdUtil.uuid_v4()
	return _atomic_write_json(
		_path("installation.json"),
		{
			"schema_version": SCHEMA_VERSION,
			"storage_mode": STORAGE_MODE,
			"installation_id": cached_installation_id,
			"created_at_unix": Time.get_unix_time_from_system()
		}
	)

func _ensure_identity() -> bool:
	var identity: Dictionary = _read_json(_path("identity.json"))
	identity = AccountManager.ensure_local_identity(
		identity,
		cached_installation_id
	)
	identity["schema_version"] = SCHEMA_VERSION
	identity["storage_mode"] = STORAGE_MODE
	return _atomic_write_json(_path("identity.json"), identity)

func _sync_native_histories(
	profile: Dictionary,
	active_run: Dictionary,
	current: Dictionary,
	installation_id: String,
	identity: Dictionary,
	device: Dictionary
) -> bool:
	var records: Array = profile.get("completed_run_history", []).duplicate(true)
	if str(active_run.get("status", "")) == "COMPLETED":
		var active_id: String = str(active_run.get("run_id", "")).strip_edges()
		var already_present: bool = false
		for value in records:
			if value is Dictionary and str(value.get("run_id", "")) == active_id:
				already_present = true
				break
		if not already_present:
			records.append(active_run.duplicate(true))

	for value in records:
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		var history: Dictionary = ProgressManager.build_native_history(
			record,
			profile,
			installation_id,
			identity,
			device
		)
		if history.is_empty():
			continue
		var history_block: Dictionary = history.get("history", {})
		var id_history: String = str(
			history_block.get("id_history", "")
		).strip_edges()
		if id_history.is_empty():
			continue
		var history_path: String = _path("history/" + id_history + ".json")
		var existing: Dictionary = _read_json(history_path)
		history = ProgressManager.merge_history_detail(history, existing)
		history = ProgressManager.merge_current_detail_into_history(
			history,
			current
		)
		if not _atomic_write_json(history_path, history):
			return false
	return true

func _is_valid_native_marker(payload: Dictionary) -> bool:
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	return str(payload.get("storage_mode", "")) == STORAGE_MODE

func _is_native_payload(payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if int(payload.get("schema_version", 0)) != SCHEMA_VERSION:
		return false
	return str(payload.get("storage_mode", "")) == STORAGE_MODE

func _ensure_directories() -> bool:
	var directories: Array[String] = [
		_root(),
		_path("current"),
		_path("history"),
		_path("telemetry"),
		_path("backups")
	]
	for directory in directories:
		var absolute_path: String = ProjectSettings.globalize_path(directory)
		var result: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
		if result != OK and result != ERR_ALREADY_EXISTS:
			return false
	return true

func _ensure_pending_event_queue() -> bool:
	var path: String = _path("telemetry/pending_events.jsonl")
	if FileAccess.file_exists(path):
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("")
	file.close()
	return true

func _count_pending_events() -> int:
	var path: String = _path("telemetry/pending_events.jsonl")
	if not FileAccess.file_exists(path):
		return 0
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var count: int = 0
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if not line.is_empty():
			count += 1
	file.close()
	return count

func _clear_current_files(keep_progress_id: String = "") -> bool:
	if not _ensure_directories():
		return false
	var directory: DirAccess = DirAccess.open(_path("current"))
	if directory == null:
		return false
	for value in directory.get_files():
		var file_name: String = str(value)
		if not file_name.ends_with(".json"):
			continue
		if not keep_progress_id.is_empty() and file_name == keep_progress_id + ".json":
			continue
		if not _remove_file(_path("current/" + file_name)):
			return false
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		return parsed
	return {}

func _atomic_write_json(path: String, payload: Dictionary) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var parent_path: String = absolute_path.get_base_dir()
	var mkdir_result: Error = DirAccess.make_dir_recursive_absolute(parent_path)
	if mkdir_result != OK and mkdir_result != ERR_ALREADY_EXISTS:
		return false
	var temp_path: String = path + ".tmp"
	var temp_absolute: String = ProjectSettings.globalize_path(temp_path)
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(absolute_path) != OK:
			_remove_file(temp_path)
			return false
	var rename_result: Error = DirAccess.rename_absolute(temp_absolute, absolute_path)
	if rename_result != OK:
		_remove_file(temp_path)
		return false
	return true

func _remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	) == OK

func _remove_tree(path: String) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return true
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child: String = path.path_join(entry)
			if directory.current_is_dir():
				if not _remove_tree(child):
					directory.list_dir_end()
					return false
			else:
				if not _remove_file(child):
					directory.list_dir_end()
					return false
		entry = directory.get_next()
	directory.list_dir_end()
	return DirAccess.remove_absolute(absolute_path) == OK
