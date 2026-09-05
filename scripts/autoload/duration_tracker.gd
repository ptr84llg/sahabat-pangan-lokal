extends Node

var session_id := ""
var level_no := 0
var accumulated_ms := 0
var segment_started_ms := 0
var running := false

func begin_level_session(new_session_id: String, new_level_no: int) -> void:
    session_id = new_session_id
    level_no = new_level_no
    accumulated_ms = 0
    segment_started_ms = 0
    running = false

func resume_active_play() -> void:
    if running:
        return
    segment_started_ms = Time.get_ticks_msec()
    running = true

func pause_active_play() -> void:
    if not running:
        return
    accumulated_ms += Time.get_ticks_msec() - segment_started_ms
    running = false
    segment_started_ms = 0

func finish_level_session() -> int:
    pause_active_play()
    return accumulated_ms

func current_active_ms() -> int:
    if running:
        return accumulated_ms + (Time.get_ticks_msec() - segment_started_ms)
    return accumulated_ms

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        pause_active_play()
