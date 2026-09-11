extends Node

signal status_changed(message: String)
signal progress_changed(value: float)
signal update_installed(content_version: String)

const CONFIG_PATH: String = "res://resources/config/update_config.tres"
const UPDATE_ROOT: String = "user://updates"
const ACTIVE_DIR: String = "user://updates/active"
const PREVIOUS_DIR: String = "user://updates/previous"
const STAGING_DIR: String = "user://updates/staging"
const ACTIVE_PCK_PATH: String = "user://updates/active/spl-content-current.pck"
const PREVIOUS_PCK_PATH: String = "user://updates/previous/spl-content-previous.pck"
const STAGING_PCK_PATH: String = "user://updates/staging/spl-content-download.tmp"
const STATE_PATH: String = "user://updates/state.json"
const SUPPORTED_MANIFEST_SCHEMA: int = 1

var config: UpdateConfig
var manifest_request: HTTPRequest
var package_request: HTTPRequest
var download_expected_size: int = 0
var download_in_progress: bool = false

func _init() -> void:
	if not _ensure_update_directories():
		push_warning("Folder pembaruan tidak dapat disiapkan. Konten bawaan tetap digunakan.")
		return

	_recover_interrupted_activation()
	_load_active_pack_with_rollback()

func _ready() -> void:
	var loaded_config: Resource = load(CONFIG_PATH)
	if loaded_config is UpdateConfig:
		config = loaded_config as UpdateConfig
	else:
		push_warning("UpdateConfig tidak dapat dimuat. Pemeriksaan pembaruan dinonaktifkan.")

	manifest_request = HTTPRequest.new()
	manifest_request.name = "ManifestRequest"
	manifest_request.use_threads = true
	add_child(manifest_request)

	package_request = HTTPRequest.new()
	package_request.name = "PackageRequest"
	package_request.use_threads = true
	add_child(package_request)

	set_process(false)

func _process(_delta: float) -> void:
	if not download_in_progress:
		return
	if package_request == null:
		return
	if download_expected_size <= 0:
		return

	var downloaded_bytes: int = package_request.get_downloaded_bytes()
	var ratio: float = clampf(
		float(downloaded_bytes) / float(download_expected_size),
		0.0,
		0.98
	)
	progress_changed.emit(ratio)

func run_startup_update() -> Dictionary:
	if config == null:
		_emit_status("PEMBARUAN DINONAKTIFKAN • KONTEN BAWAAN")
		return _result(false, false, "config_unavailable", "Konfigurasi pembaruan tidak tersedia.")

	if not _ensure_update_directories():
		_emit_status("PENYIMPANAN UPDATE TIDAK TERSEDIA • LANJUT OFFLINE")
		return _result(false, false, "storage_unavailable", "Folder pembaruan tidak dapat disiapkan.")

	_emit_status("MEMERIKSA PEMBARUAN...")
	progress_changed.emit(0.05)

	var manifest_result: Dictionary = await _fetch_manifest()
	if not bool(manifest_result.get("ok", false)):
		var manifest_message: String = str(
			manifest_result.get("message", "Server pembaruan tidak dapat dihubungi.")
		)
		if config.allow_offline:
			_emit_status("OFFLINE • MENGGUNAKAN KONTEN TERSIMPAN")
			progress_changed.emit(1.0)
			return _result(false, false, "offline_fallback", manifest_message)
		return _result(true, false, "manifest_failed", manifest_message)

	var manifest_value: Variant = manifest_result.get("manifest", {})
	if not manifest_value is Dictionary:
		if config.allow_offline:
			_emit_status("MANIFEST TIDAK VALID • KONTEN TERSIMPAN")
			progress_changed.emit(1.0)
			return _result(false, false, "manifest_invalid", "Format manifest pembaruan tidak valid.")
		return _result(true, false, "manifest_invalid", "Format manifest pembaruan tidak valid.")

	var manifest: Dictionary = manifest_value
	var decision: Dictionary = _evaluate_manifest(manifest)
	if bool(decision.get("blocking", false)):
		return decision

	if not bool(decision.get("update_available", false)):
		_emit_status(str(decision.get("status_text", "KONTEN SUDAH TERBARU")))
		progress_changed.emit(1.0)
		return decision

	if not config.auto_download_content:
		_emit_status("PEMBARUAN KONTEN TERSEDIA")
		progress_changed.emit(1.0)
		return decision

	var content_value: Variant = decision.get("content", {})
	if not content_value is Dictionary:
		return _result(false, false, "content_invalid", "Metadata konten pembaruan tidak valid.")

	var content_info: Dictionary = content_value
	return await _download_and_install(content_info)

func get_current_content_version() -> String:
	var state: Dictionary = _read_json(STATE_PATH)
	var state_version: String = str(state.get("content_version", "")).strip_edges()

	if FileAccess.file_exists(ACTIVE_PCK_PATH) and not state_version.is_empty():
		return state_version

	if FileAccess.file_exists(ACTIVE_PCK_PATH):
		return "active-unknown"

	if config != null:
		return config.bundled_content_version

	return "unknown"

func get_app_version() -> String:
	if config == null:
		return ""
	return config.app_version

func get_version_code() -> int:
	if config == null:
		return 0
	return config.version_code

func get_save_schema_version() -> int:
	if config == null:
		return 0
	return config.save_schema_version

func _fetch_manifest() -> Dictionary:
	if manifest_request == null:
		return {
			"ok": false,
			"message": "HTTP manifest request belum siap."
		}

	manifest_request.timeout = config.request_timeout_seconds
	manifest_request.download_file = ""

	var headers: PackedStringArray = PackedStringArray([
		"Accept: application/json",
		"Cache-Control: no-cache",
		"User-Agent: SahabatPanganLokal/%s" % config.app_version
	])

	var request_error: Error = manifest_request.request(
		config.manifest_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if request_error != OK:
		return {
			"ok": false,
			"message": "Permintaan manifest gagal dimulai (%s)." % request_error
		}

	var response: Array = await manifest_request.request_completed
	if response.size() != 4:
		return {
			"ok": false,
			"message": "Respons manifest tidak lengkap."
		}

	var request_result: int = int(response[0])
	var response_code: int = int(response[1])
	var body_value: Variant = response[3]

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"message": "Koneksi pembaruan gagal (%s)." % request_result
		}

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"message": "Server pembaruan merespons HTTP %s." % response_code
		}

	if not body_value is PackedByteArray:
		return {
			"ok": false,
			"message": "Body manifest tidak valid."
		}

	var body: PackedByteArray = body_value
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		return {
			"ok": false,
			"message": "JSON manifest tidak valid."
		}

	return {
		"ok": true,
		"manifest": parsed
	}

func _evaluate_manifest(manifest: Dictionary) -> Dictionary:
	var schema_version: int = int(manifest.get("schema_version", 0))
	if schema_version != SUPPORTED_MANIFEST_SCHEMA:
		return _result(
			false,
			false,
			"schema_unsupported",
			"Versi manifest pembaruan tidak didukung."
		)

	var manifest_channel: String = str(
		manifest.get("channel", "")
	).strip_edges()

	if not manifest_channel.is_empty() and manifest_channel != config.channel:
		return {
			"blocking": false,
			"installed": false,
			"update_available": false,
			"outcome": "channel_mismatch",
			"message": "Channel pembaruan berbeda.",
			"status_text": "CHANNEL UPDATE TIDAK SESUAI"
		}

	var app_info: Dictionary = _dictionary_value(manifest, "app")
	var content_info: Dictionary = _dictionary_value(manifest, "content")
	var save_info: Dictionary = _dictionary_value(manifest, "save")

	if content_info.is_empty():
		return _result(
			false,
			false,
			"content_missing",
			"Metadata konten tidak tersedia pada manifest."
		)

	var min_supported_version_code: int = int(
		app_info.get("min_supported_version_code", 0)
	)
	var force_update: bool = bool(app_info.get("force_update", false))

	if (
		min_supported_version_code > config.version_code
		and force_update
	):
		return _result(
			true,
			false,
			"app_update_required",
			"Versi aplikasi ini harus diperbarui melalui kanal distribusi resmi."
		)

	var remote_save_schema: int = int(
		save_info.get("schema_version", config.save_schema_version)
	)
	if remote_save_schema > config.save_schema_version:
		if force_update:
			return _result(
				true,
				false,
				"save_schema_update_required",
				"Versi aplikasi baru diperlukan untuk kompatibilitas penyimpanan."
			)
		return {
			"blocking": false,
			"installed": false,
			"update_available": false,
			"outcome": "save_schema_newer",
			"message": "Konten terbaru membutuhkan versi aplikasi yang lebih baru.",
			"status_text": "KONTEN TERSIMPAN TETAP DIGUNAKAN"
		}

	var content_available: bool = bool(
		content_info.get("available", true)
	)
	if not content_available:
		return {
			"blocking": false,
			"installed": false,
			"update_available": false,
			"outcome": "content_disabled",
			"message": "Server tidak menawarkan pembaruan konten.",
			"status_text": "KONTEN SUDAH TERBARU"
		}

	var remote_content_version: String = str(
		content_info.get("version", "")
	).strip_edges()

	if remote_content_version.is_empty():
		return _result(
			false,
			false,
			"content_version_missing",
			"Versi konten pada manifest tidak valid."
		)

	var current_content_version: String = get_current_content_version()
	if remote_content_version == current_content_version:
		return {
			"blocking": false,
			"installed": false,
			"update_available": false,
			"outcome": "up_to_date",
			"message": "Konten sudah menggunakan versi terbaru.",
			"status_text": "KONTEN SUDAH TERBARU",
			"content_version": current_content_version
		}

	var required_app_version_code: int = int(
		content_info.get("required_app_version_code", 0)
	)
	if required_app_version_code > config.version_code:
		if force_update:
			return _result(
				true,
				false,
				"content_requires_new_app",
				"Konten terbaru membutuhkan pembaruan aplikasi."
			)
		return {
			"blocking": false,
			"installed": false,
			"update_available": false,
			"outcome": "content_requires_new_app",
			"message": "Konten terbaru belum kompatibel dengan aplikasi ini.",
			"status_text": "KONTEN TERSIMPAN TETAP DIGUNAKAN"
		}

	var package_url: String = str(
		content_info.get("url", "")
	).strip_edges()
	var package_sha256: String = str(
		content_info.get("sha256", "")
	).strip_edges().to_lower()
	var package_size: int = int(
		content_info.get("size", 0)
	)

	if not package_url.begins_with("https://"):
		return _result(
			false,
			false,
			"package_url_invalid",
			"URL paket pembaruan harus menggunakan HTTPS."
		)

	if package_size <= 0:
		return _result(
			false,
			false,
			"package_size_invalid",
			"Ukuran paket pembaruan tidak valid."
		)

	if not _is_valid_sha256(package_sha256):
		return _result(
			false,
			false,
			"package_hash_invalid",
			"SHA-256 paket pembaruan tidak valid."
		)

	return {
		"blocking": false,
		"installed": false,
		"update_available": true,
		"outcome": "content_update_available",
		"message": "Pembaruan konten tersedia.",
		"status_text": "PEMBARUAN KONTEN TERSEDIA",
		"content": content_info.duplicate(true),
		"content_version": remote_content_version
	}

func _download_and_install(content_info: Dictionary) -> Dictionary:
	if package_request == null:
		return _result(
			false,
			false,
			"package_request_unavailable",
			"HTTP package request belum siap."
		)

	var content_version: String = str(
		content_info.get("version", "")
	).strip_edges()
	var package_url: String = str(
		content_info.get("url", "")
	).strip_edges()
	var expected_sha256: String = str(
		content_info.get("sha256", "")
	).strip_edges().to_lower()
	var expected_size: int = int(
		content_info.get("size", 0)
	)

	if not _remove_file(STAGING_PCK_PATH):
		return _result(
			false,
			false,
			"staging_cleanup_failed",
			"File staging lama tidak dapat dibersihkan."
		)

	_emit_status("MENGUNDUH KONTEN TERBARU...")
	progress_changed.emit(0.08)

	package_request.timeout = maxf(
		config.request_timeout_seconds,
		30.0
	)
	package_request.download_file = STAGING_PCK_PATH
	download_expected_size = expected_size
	download_in_progress = true
	set_process(true)

	var headers: PackedStringArray = PackedStringArray([
		"Cache-Control: no-cache",
		"User-Agent: SahabatPanganLokal/%s" % config.app_version
	])

	var request_error: Error = package_request.request(
		package_url,
		headers,
		HTTPClient.METHOD_GET
	)

	if request_error != OK:
		_finish_download_tracking()
		package_request.download_file = ""
		return _result(
			false,
			false,
			"download_start_failed",
			"Unduhan konten gagal dimulai (%s)." % request_error
		)

	var response: Array = await package_request.request_completed
	_finish_download_tracking()
	package_request.download_file = ""

	if response.size() != 4:
		_remove_file(STAGING_PCK_PATH)
		return _result(
			false,
			false,
			"download_response_invalid",
			"Respons unduhan tidak lengkap."
		)

	var request_result: int = int(response[0])
	var response_code: int = int(response[1])

	if request_result != HTTPRequest.RESULT_SUCCESS:
		_remove_file(STAGING_PCK_PATH)
		return _result(
			false,
			false,
			"download_failed",
			"Unduhan konten gagal (%s)." % request_result
		)

	if response_code < 200 or response_code >= 300:
		_remove_file(STAGING_PCK_PATH)
		return _result(
			false,
			false,
			"download_http_failed",
			"Server paket merespons HTTP %s." % response_code
		)

	if not FileAccess.file_exists(STAGING_PCK_PATH):
		return _result(
			false,
			false,
			"download_missing",
			"File hasil unduhan tidak ditemukan."
		)

	_emit_status("MEMVERIFIKASI PEMBARUAN...")
	progress_changed.emit(0.985)

	var downloaded_size: int = FileAccess.get_size(STAGING_PCK_PATH)
	if downloaded_size != expected_size:
		_remove_file(STAGING_PCK_PATH)
		return _result(
			false,
			false,
			"size_mismatch",
			"Ukuran paket tidak sesuai."
		)

	var downloaded_sha256: String = FileAccess.get_sha256(
		STAGING_PCK_PATH
	).to_lower()

	if downloaded_sha256 != expected_sha256:
		_remove_file(STAGING_PCK_PATH)
		return _result(
			false,
			false,
			"sha256_mismatch",
			"Verifikasi SHA-256 paket gagal."
		)

	_emit_status("MENGAKTIFKAN PEMBARUAN...")
	progress_changed.emit(0.995)

	if not _activate_downloaded_pack(
		content_version,
		downloaded_sha256,
		downloaded_size
	):
		return _result(
			false,
			false,
			"activation_failed",
			"Paket baru tidak dapat diaktifkan. Konten sebelumnya tetap digunakan."
		)

	_emit_status("PEMBARUAN KONTEN SELESAI")
	progress_changed.emit(1.0)
	update_installed.emit(content_version)

	return {
		"blocking": false,
		"installed": true,
		"update_available": false,
		"outcome": "content_installed",
		"message": "Pembaruan konten berhasil dipasang.",
		"status_text": "PEMBARUAN KONTEN SELESAI",
		"content_version": content_version
	}

func _activate_downloaded_pack(
	content_version: String,
	sha256_value: String,
	size_value: int
) -> bool:
	if FileAccess.file_exists(PREVIOUS_PCK_PATH):
		if not _remove_file(PREVIOUS_PCK_PATH):
			_remove_file(STAGING_PCK_PATH)
			return false

	if FileAccess.file_exists(ACTIVE_PCK_PATH):
		if not _move_file(ACTIVE_PCK_PATH, PREVIOUS_PCK_PATH):
			_remove_file(STAGING_PCK_PATH)
			return false

	if not _move_file(STAGING_PCK_PATH, ACTIVE_PCK_PATH):
		if FileAccess.file_exists(PREVIOUS_PCK_PATH):
			_move_file(PREVIOUS_PCK_PATH, ACTIVE_PCK_PATH)
		return false

	if not ProjectSettings.load_resource_pack(ACTIVE_PCK_PATH, true):
		_remove_file(ACTIVE_PCK_PATH)
		if FileAccess.file_exists(PREVIOUS_PCK_PATH):
			_move_file(PREVIOUS_PCK_PATH, ACTIVE_PCK_PATH)
		return false

	var state_payload: Dictionary = {
		"schema_version": 1,
		"content_version": content_version,
		"sha256": sha256_value,
		"size": size_value,
		"installed_at_unix": Time.get_unix_time_from_system(),
		"app_version": config.app_version,
		"version_code": config.version_code,
		"save_schema_version": config.save_schema_version
	}

	if not _atomic_write_json(STATE_PATH, state_payload):
		push_warning(
			"Paket pembaruan aktif, tetapi metadata state.json gagal disimpan."
		)

	return true

func _recover_interrupted_activation() -> void:
	if FileAccess.file_exists(STAGING_PCK_PATH):
		_remove_file(STAGING_PCK_PATH)

	if (
		not FileAccess.file_exists(ACTIVE_PCK_PATH)
		and FileAccess.file_exists(PREVIOUS_PCK_PATH)
	):
		_move_file(PREVIOUS_PCK_PATH, ACTIVE_PCK_PATH)

func _load_active_pack_with_rollback() -> bool:
	if not FileAccess.file_exists(ACTIVE_PCK_PATH):
		return false

	if ProjectSettings.load_resource_pack(ACTIVE_PCK_PATH, true):
		return true

	push_warning("Paket update aktif rusak. Mencoba rollback ke paket sebelumnya.")
	_remove_file(ACTIVE_PCK_PATH)

	if not FileAccess.file_exists(PREVIOUS_PCK_PATH):
		return false

	if not _move_file(PREVIOUS_PCK_PATH, ACTIVE_PCK_PATH):
		return false

	return ProjectSettings.load_resource_pack(
		ACTIVE_PCK_PATH,
		true
	)

func _ensure_update_directories() -> bool:
	for update_dir in [
		UPDATE_ROOT,
		ACTIVE_DIR,
		PREVIOUS_DIR,
		STAGING_DIR
	]:
		var absolute_path: String = ProjectSettings.globalize_path(
			str(update_dir)
		)
		var result: Error = DirAccess.make_dir_recursive_absolute(
			absolute_path
		)
		if result != OK and result != ERR_ALREADY_EXISTS:
			return false
	return true

func _atomic_write_json(path: String, payload: Dictionary) -> bool:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var parent_path: String = absolute_path.get_base_dir()
	var mkdir_result: Error = DirAccess.make_dir_recursive_absolute(
		parent_path
	)
	if mkdir_result != OK and mkdir_result != ERR_ALREADY_EXISTS:
		return false

	var temp_path: String = path + ".tmp"
	var temp_absolute: String = ProjectSettings.globalize_path(temp_path)
	var file: FileAccess = FileAccess.open(
		temp_path,
		FileAccess.WRITE
	)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "  "))
	file.flush()
	file.close()

	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(absolute_path) != OK:
			_remove_file(temp_path)
			return false

	var rename_result: Error = DirAccess.rename_absolute(
		temp_absolute,
		absolute_path
	)
	if rename_result != OK:
		_remove_file(temp_path)
		return false

	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if parsed is Dictionary:
		return parsed

	return {}

func _move_file(from_path: String, to_path: String) -> bool:
	if not FileAccess.file_exists(from_path):
		return false

	var from_absolute: String = ProjectSettings.globalize_path(
		from_path
	)
	var to_absolute: String = ProjectSettings.globalize_path(
		to_path
	)

	return DirAccess.rename_absolute(
		from_absolute,
		to_absolute
	) == OK

func _remove_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true

	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	) == OK

func _finish_download_tracking() -> void:
	download_in_progress = false
	download_expected_size = 0
	set_process(false)

func _dictionary_value(
	source: Dictionary,
	key: String
) -> Dictionary:
	var value: Variant = source.get(key, {})
	if value is Dictionary:
		return value
	return {}

func _is_valid_sha256(value: String) -> bool:
	if value.length() != 64:
		return false

	var valid_chars: String = "0123456789abcdef"
	for index in range(value.length()):
		var character: String = value.substr(index, 1)
		if not valid_chars.contains(character):
			return false

	return true

func _emit_status(message: String) -> void:
	status_changed.emit(message)

func _result(
	blocking: bool,
	installed: bool,
	outcome: String,
	message: String
) -> Dictionary:
	return {
		"blocking": blocking,
		"installed": installed,
		"update_available": false,
		"outcome": outcome,
		"message": message,
		"status_text": message
	}
