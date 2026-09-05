class_name FestivalMainTimerController
extends Node

signal time_changed(seconds_remaining: int)
signal warning_30
signal expired

var initial_seconds := 240.0
var remaining_seconds := 240.0
var running := false
var is_expired := false
var warning_sent := false
var last_display := -1

func configure(seconds: int) -> void:
    initial_seconds = float(max(1, seconds))
    reset()

func reset() -> void:
    remaining_seconds = initial_seconds
    running = false
    is_expired = false
    warning_sent = false
    last_display = -1
    _emit_time(true)

func start() -> void:
    reset()
    running = true

func stop() -> void:
    running = false

func seconds_left() -> int:
    return max(0, int(ceil(remaining_seconds)))

func remaining_ratio() -> float:
    if initial_seconds <= 0.0:
        return 0.0
    return clamp(remaining_seconds / initial_seconds, 0.0, 1.0)

func _process(delta: float) -> void:
    if not running:
        return
    remaining_seconds = max(0.0, remaining_seconds - delta)
    _emit_time(false)
    if not warning_sent and remaining_seconds <= 30.0 and remaining_seconds > 0.0:
        warning_sent = true
        warning_30.emit()
    if remaining_seconds <= 0.0:
        running = false
        is_expired = true
        expired.emit()

func _emit_time(force: bool) -> void:
    var s := seconds_left()
    if force or s != last_display:
        last_display = s
        time_changed.emit(s)
