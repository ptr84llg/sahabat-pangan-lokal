extends Node

const PayloadBuilder = preload(
	"res://scripts/shared/sync/completed_history_payload_builder.gd"
)

const API_ENDPOINT: String = (
	"https://sahabatpanganlokal.id/api/v1/completed-history"
)
const LEDGER_SCHEMA_VERSION: int = 1
const STATE_PENDING: String = "pending"
const STATE_SYNCED: String = "synced"
const STATE_PERMANENT_FAILURE: String = "permanent_failure"
const REQUEST_TIMEOUT_SECONDS: float = 12.0
const WARNING_PAYLOAD_BYTES: int = 1048576
const MAX_ATTEMPTS_PER_CYCLE: int = 3
const NETWORK_BACKOFF_SECONDS: Array[int] = [2, 5, 10]

var http_request: HTTPRequest
var sync_running: bool = false
var sync_scheduled: bool = false
var resync_requested: bool = false
var last_schedule_reason: String = ""

func _ready() -> void:
	http_request = HTTPRequest.new()
	http_request.name = "CompletedHistoryRequest"
	http_request.use_threads = true
	http_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(http_request)

func schedule_sync(reason: String = "manual") -> void:
	last_schedule_reason = reason
	if sync_running:
		resync_requested = true
		return
	if sync_scheduled:
		return
	sync_scheduled = true
	call_deferred("_run_scheduled_sync")

func ledger_snapshot() -> Dictionary:
	return SaveManager.load_completed_history_sync_ledger().duplicate(true)

func _run_scheduled_sync() -> void:
	sync_scheduled = false
	if sync_running:
		resync_requested = true
		return

	sync_running = true
	var registered: bool = _register_completed_histories()
	if registered:
		await _sync_pending_histories()
	else:
		push_warning("Completed history sync ledger gagal diperbarui.")
	sync_running = false

	if resync_requested:
		resync_requested = false
		schedule_sync("rescheduled")

func _register_completed_histories() -> bool:
	var ledger: Dictionary = SaveManager.load_completed_history_sync_ledger()
	if ledger.is_empty():
		ledger = {
			"schema_version": LEDGER_SCHEMA_VERSION,
			"history_sync": {}
		}

	var history_sync: Dictionary = ledger.get("history_sync", {})
	var native_histories: Array = SaveManager.load_v3_history_records()
	var changed: bool = false

	for value in native_histories:
		if not value is Dictionary:
			continue
		var native_history: Dictionary = value
		var history: Dictionary = native_history.get("history", {})
		var history_id: String = str(
			history.get("id_history", "")
		).strip_edges()
		if history_id.is_empty():
			continue

		if history_sync.has(history_id):
			var existing_value: Variant = history_sync.get(history_id, {})
			if existing_value is Dictionary:
				var existing: Dictionary = existing_value
				var existing_payload_value: Variant = existing.get(
					"payload_snapshot",
					{}
				)
				if existing_payload_value is Dictionary:
					var existing_payload: Dictionary = existing_payload_value
					if not existing_payload.is_empty():
						continue

		var client_snapshot: Dictionary = (
			PayloadBuilder.freeze_client_snapshot(native_history)
		)
		if history_sync.has(history_id):
			var old_entry_value: Variant = history_sync.get(history_id, {})
			if old_entry_value is Dictionary:
				var old_entry: Dictionary = old_entry_value
				var old_client_value: Variant = old_entry.get(
					"client_snapshot",
					{}
				)
				if old_client_value is Dictionary:
					var old_client: Dictionary = old_client_value
					if not old_client.is_empty():
						client_snapshot = old_client.duplicate(true)

		var payload: Dictionary = PayloadBuilder.build_payload(
			native_history,
			client_snapshot
		)
		var validation: Dictionary = PayloadBuilder.validate_payload(payload)
		var valid: bool = bool(validation.get("ok", false))
		var payload_bytes: int = 0
		if valid:
			payload_bytes = JSON.stringify(payload).to_utf8_buffer().size()

		var entry: Dictionary = {
			"state": STATE_PENDING if valid else STATE_PERMANENT_FAILURE,
			"attempt_count": 0,
			"last_attempt_at": 0,
			"last_http_status": 0,
			"last_error": str(validation.get("error", "")),
			"server_received_at": "",
			"next_retry_at": 0,
			"payload_bytes": payload_bytes,
			"client_snapshot": client_snapshot.duplicate(true),
			"payload_snapshot": payload.duplicate(true)
		}
		history_sync[history_id] = entry
		changed = true

	ledger["schema_version"] = LEDGER_SCHEMA_VERSION
	ledger["history_sync"] = history_sync

	if not changed:
		return true

	return SaveManager.commit_completed_history_sync_ledger(ledger)

func _sync_pending_histories() -> void:
	var ledger: Dictionary = SaveManager.load_completed_history_sync_ledger()
	var history_sync: Dictionary = ledger.get("history_sync", {})
	var history_ids: Array[String] = []

	for key_value in history_sync.keys():
		history_ids.append(str(key_value))
	history_ids.sort()

	for history_id in history_ids:
		var entry_value: Variant = history_sync.get(history_id, {})
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		if str(entry.get("state", "")) != STATE_PENDING:
			continue

		var now_unix: float = Time.get_unix_time_from_system()
		if float(entry.get("next_retry_at", 0)) > now_unix:
			continue

		await _sync_one_history(
			ledger,
			history_sync,
			history_id
		)

func _sync_one_history(
	ledger: Dictionary,
	history_sync: Dictionary,
	history_id: String
) -> void:
	var entry_value: Variant = history_sync.get(history_id, {})
	if not entry_value is Dictionary:
		return
	var entry: Dictionary = entry_value
	var payload_value: Variant = entry.get("payload_snapshot", {})
	if not payload_value is Dictionary:
		_mark_local_permanent_failure(
			ledger,
			history_sync,
			history_id,
			entry,
			"payload_snapshot_missing"
		)
		return

	var payload: Dictionary = payload_value
	var validation: Dictionary = PayloadBuilder.validate_payload(payload)
	if not bool(validation.get("ok", false)):
		_mark_local_permanent_failure(
			ledger,
			history_sync,
			history_id,
			entry,
			str(validation.get("error", "invalid_payload"))
		)
		return

	for local_try in range(MAX_ATTEMPTS_PER_CYCLE):
		entry["attempt_count"] = int(entry.get("attempt_count", 0)) + 1
		entry["last_attempt_at"] = Time.get_unix_time_from_system()
		entry["last_http_status"] = 0
		entry["last_error"] = ""
		history_sync[history_id] = entry
		ledger["history_sync"] = history_sync
		if not SaveManager.commit_completed_history_sync_ledger(ledger):
			push_warning(
				"Attempt sync history gagal dipersist sebelum HTTP."
			)
			return

		var response: Dictionary = await _post_payload(payload)
		var classification: Dictionary = _classify_response(
			response,
			local_try
		)
		var state: String = str(
			classification.get("state", STATE_PENDING)
		)
		entry["state"] = state
		entry["last_http_status"] = int(
			classification.get("http_status", 0)
		)
		entry["last_error"] = str(
			classification.get("error", "")
		)

		if state == STATE_SYNCED:
			entry["server_received_at"] = str(
				classification.get("server_received_at", "")
			)
			entry["next_retry_at"] = 0
		elif state == STATE_PERMANENT_FAILURE:
			entry["next_retry_at"] = 0
		else:
			var delay_seconds: int = int(
				classification.get(
					"retry_after_seconds",
					_network_backoff_seconds(local_try)
				)
			)
			delay_seconds = maxi(1, delay_seconds)
			entry["next_retry_at"] = (
				Time.get_unix_time_from_system() + delay_seconds
			)

		history_sync[history_id] = entry
		ledger["history_sync"] = history_sync
		if not SaveManager.commit_completed_history_sync_ledger(ledger):
			push_warning("Hasil sync history gagal dipersist.")
			return

		if state != STATE_PENDING:
			return

		if bool(classification.get("respect_retry_after", false)):
			return

		if local_try >= MAX_ATTEMPTS_PER_CYCLE - 1:
			return

		var wait_seconds: int = int(
			classification.get(
				"retry_after_seconds",
				_network_backoff_seconds(local_try)
			)
		)
		await get_tree().create_timer(float(maxi(1, wait_seconds))).timeout

func _post_payload(payload: Dictionary) -> Dictionary:
	if http_request == null:
		return {
			"request_result": -1,
			"response_code": 0,
			"headers": PackedStringArray(),
			"body": {},
			"error": "http_request_unavailable"
		}

	var body_text: String = JSON.stringify(payload)
	var body_bytes: int = body_text.to_utf8_buffer().size()
	if body_bytes >= WARNING_PAYLOAD_BYTES:
		push_warning(
			"Completed history payload >= 1 MiB: %d bytes" % body_bytes
		)

	var headers: PackedStringArray = PackedStringArray([
		"Accept: application/json",
		"Content-Type: application/json"
	])
	var request_error: Error = http_request.request(
		API_ENDPOINT,
		headers,
		HTTPClient.METHOD_POST,
		body_text
	)
	if request_error != OK:
		return {
			"request_result": -1,
			"response_code": 0,
			"headers": PackedStringArray(),
			"body": {},
			"error": "request_start_error:" + str(request_error)
		}

	var response: Array = await http_request.request_completed
	if response.size() != 4:
		return {
			"request_result": -1,
			"response_code": 0,
			"headers": PackedStringArray(),
			"body": {},
			"error": "incomplete_response"
		}

	var response_headers: PackedStringArray = response[2]
	var body_value: Variant = response[3]
	var parsed_body: Dictionary = {}
	if body_value is PackedByteArray:
		var body: PackedByteArray = body_value
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if parsed is Dictionary:
			parsed_body = parsed

	return {
		"request_result": int(response[0]),
		"response_code": int(response[1]),
		"headers": response_headers,
		"body": parsed_body,
		"error": ""
	}

func _classify_response(
	response: Dictionary,
	local_try: int
) -> Dictionary:
	var request_result: int = int(response.get("request_result", -1))
	var response_code: int = int(response.get("response_code", 0))
	var body: Dictionary = response.get("body", {})

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"state": STATE_PENDING,
			"http_status": response_code,
			"error": str(
				response.get(
					"error",
					"network_result_" + str(request_result)
				)
			),
			"retry_after_seconds": _network_backoff_seconds(local_try),
			"respect_retry_after": false
		}

	if response_code == 200:
		var status: String = str(body.get("status", ""))
		if (
			bool(body.get("ok", false))
			and (
				status == "stored"
				or status == "already_stored"
			)
		):
			return {
				"state": STATE_SYNCED,
				"http_status": 200,
				"error": "",
				"server_received_at": str(body.get("received_at", "")),
				"retry_after_seconds": 0,
				"respect_retry_after": false
			}
		return {
			"state": STATE_PENDING,
			"http_status": 200,
			"error": "invalid_success_ack",
			"retry_after_seconds": _network_backoff_seconds(local_try),
			"respect_retry_after": false
		}

	if response_code == 429:
		return {
			"state": STATE_PENDING,
			"http_status": 429,
			"error": str(body.get("error", "rate_limited")),
			"retry_after_seconds": _retry_after_seconds(
				response.get("headers", PackedStringArray())
			),
			"respect_retry_after": true
		}

	if response_code >= 500 and response_code <= 599:
		return {
			"state": STATE_PENDING,
			"http_status": response_code,
			"error": str(
				body.get(
					"error",
					"server_error_" + str(response_code)
				)
			),
			"retry_after_seconds": _network_backoff_seconds(local_try),
			"respect_retry_after": false
		}

	if response_code >= 400 and response_code <= 499:
		return {
			"state": STATE_PERMANENT_FAILURE,
			"http_status": response_code,
			"error": str(
				body.get(
					"error",
					"http_" + str(response_code)
				)
			),
			"retry_after_seconds": 0,
			"respect_retry_after": false
		}

	return {
		"state": STATE_PENDING,
		"http_status": response_code,
		"error": "unexpected_http_" + str(response_code),
		"retry_after_seconds": _network_backoff_seconds(local_try),
		"respect_retry_after": false
	}

func _mark_local_permanent_failure(
	ledger: Dictionary,
	history_sync: Dictionary,
	history_id: String,
	entry: Dictionary,
	error_code: String
) -> void:
	entry["state"] = STATE_PERMANENT_FAILURE
	entry["last_error"] = error_code
	entry["next_retry_at"] = 0
	history_sync[history_id] = entry
	ledger["history_sync"] = history_sync
	if not SaveManager.commit_completed_history_sync_ledger(ledger):
		push_warning("Permanent failure history sync gagal dipersist.")

func _network_backoff_seconds(local_try: int) -> int:
	var index: int = clampi(
		local_try,
		0,
		NETWORK_BACKOFF_SECONDS.size() - 1
	)
	return NETWORK_BACKOFF_SECONDS[index]

func _retry_after_seconds(headers_value: Variant) -> int:
	if not headers_value is PackedStringArray:
		return 60
	var headers: PackedStringArray = headers_value
	for header_value in headers:
		var line: String = str(header_value)
		var separator: int = line.find(":")
		if separator <= 0:
			continue
		var header_name: String = line.substr(
			0,
			separator
		).strip_edges().to_lower()
		if header_name != "retry-after":
			continue
		var value: String = line.substr(
			separator + 1
		).strip_edges()
		if value.is_valid_int():
			return maxi(1, int(value))
	return 60
