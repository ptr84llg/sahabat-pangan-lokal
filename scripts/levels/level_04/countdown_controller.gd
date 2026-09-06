class_name CountdownController
extends Node

signal time_changed(seconds_remaining: int)
signal warning_30
signal warning_10
signal timeout_triggered

var initial_seconds := 120.0
var remaining_seconds := 120.0
var running := false
var warning_30_sent := false
var warning_10_sent := false
var last_display_seconds := -1

func configure(seconds: int) -> void:
    initial_seconds = float(max(1, seconds))
    reset()

func reset() -> void:
    remaining_seconds = initial_seconds
    running = false
    warning_30_sent = false
    warning_10_sent = false
    last_display_seconds = -1
    _emit_time_if_needed(true)

func start() -> void:
    reset()
    running = true

func resume() -> void:
    if remaining_seconds > 0.0:
        running = true

func pause() -> void:
    running = false

func stop() -> void:
    running = false

func seconds_left() -> int:
    return max(0, int(ceil(remaining_seconds)))

func _process(delta: float) -> void:
    if not running:
        return
    remaining_seconds = max(0.0, remaining_seconds - delta)
    _emit_time_if_needed(false)
    if not warning_30_sent and remaining_seconds <= 30.0 and remaining_seconds > 0.0:
        warning_30_sent = true
        warning_30.emit()
    if not warning_10_sent and remaining_seconds <= 10.0 and remaining_seconds > 0.0:
        warning_10_sent = true
        warning_10.emit()
    if remaining_seconds <= 0.0:
        running = false
        timeout_triggered.emit()

func _emit_time_if_needed(force: bool) -> void:
    var display_seconds := seconds_left()
    if force or display_seconds != last_display_seconds:
        last_display_seconds = display_seconds
        time_changed.emit(display_seconds)
