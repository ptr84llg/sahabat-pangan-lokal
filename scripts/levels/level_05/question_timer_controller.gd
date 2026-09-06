class_name QuestionTimerController
extends Node

signal time_changed(seconds_remaining: int)
signal timeout

var limit_seconds := 30.0
var remaining_seconds := 30.0
var running := false
var last_display := -1

func configure(seconds: int) -> void:
    limit_seconds = float(max(1, seconds))
    stop()

func start_question() -> void:
    remaining_seconds = limit_seconds
    running = true
    last_display = -1
    _emit_time(true)

func stop() -> void:
    running = false

func seconds_left() -> int:
    return max(0, int(ceil(remaining_seconds)))

func elapsed_ms() -> int:
    return int((limit_seconds - remaining_seconds) * 1000.0)

func _process(delta: float) -> void:
    if not running:
        return
    remaining_seconds = max(0.0, remaining_seconds - delta)
    _emit_time(false)
    if remaining_seconds <= 0.0:
        running = false
        timeout.emit()

func _emit_time(force: bool) -> void:
    var s := seconds_left()
    if force or s != last_display:
        last_display = s
        time_changed.emit(s)
