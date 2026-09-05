extends Node

const EVENT_PATH := "user://sahabat_pangan_lokal_events_v1_1.jsonl"
var initialized := false

func initialize() -> void:
    initialized = true

func log_event(event_name: String, payload: Dictionary = {}) -> void:
    var event := {
        "event_id": IdUtil.uuid_v4(),
        "event_name": event_name,
        "timestamp_unix": Time.get_unix_time_from_system(),
        "content_version": ContentDatabase.content_version,
        "payload": payload.duplicate(true)
    }
    var file: FileAccess
    if FileAccess.file_exists(EVENT_PATH):
        file = FileAccess.open(EVENT_PATH, FileAccess.READ_WRITE)
        file.seek_end()
    else:
        file = FileAccess.open(EVENT_PATH, FileAccess.WRITE)
    if file != null:
        file.store_line(JSON.stringify(event))
