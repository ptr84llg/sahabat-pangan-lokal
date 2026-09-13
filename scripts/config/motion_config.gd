class_name MotionConfig
extends Resource

@export_category("Button")
@export var hover_position: Vector2 = Vector2(0.0, -3.0)
@export var hover_scale: Vector2 = Vector2(1.025, 1.025)
@export var press_position: Vector2 = Vector2(0.0, 1.0)
@export var press_scale: Vector2 = Vector2(0.975, 0.975)
@export_range(0.01, 2.0, 0.01) var hover_duration: float = 0.14
@export_range(0.01, 2.0, 0.01) var press_duration: float = 0.08
@export_range(0.01, 2.0, 0.01) var release_duration: float = 0.12

@export_category("Feedback")
@export_range(1.0, 2.0, 0.01) var pop_peak_scale: float = 1.08
@export_range(0.0, 64.0, 0.5) var shake_strength: float = 8.0
@export_range(1.0, 2.0, 0.01) var pulse_peak_scale: float = 1.05
@export var reward_start_position: Vector2 = Vector2(0.0, 8.0)
@export var reward_start_scale: Vector2 = Vector2(0.86, 0.86)
@export var reward_peak_scale: Vector2 = Vector2(1.08, 1.08)
@export_range(0.01, 2.0, 0.01) var pop_up_duration: float = 0.10
@export_range(0.01, 2.0, 0.01) var pop_return_duration: float = 0.14
@export_range(0.01, 2.0, 0.01) var shake_step_duration: float = 0.035
@export_range(0.01, 2.0, 0.01) var pulse_up_duration: float = 0.14
@export_range(0.01, 2.0, 0.01) var pulse_return_duration: float = 0.16
@export_range(0.01, 2.0, 0.01) var reward_position_duration: float = 0.26
@export_range(0.01, 2.0, 0.01) var reward_peak_duration: float = 0.22
@export_range(0.01, 2.0, 0.01) var reward_return_duration: float = 0.14