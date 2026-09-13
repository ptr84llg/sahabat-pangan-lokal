class_name MotionConfig
extends Resource

@export_category("Global")
@export var motion_enabled: bool = true

@export_category("Button")
@export var hover_position: Vector2 = Vector2(0.0, -3.0)
@export var hover_scale: Vector2 = Vector2(1.025, 1.025)
@export var press_position: Vector2 = Vector2(0.0, 1.0)
@export var press_scale: Vector2 = Vector2(0.975, 0.975)
@export_range(0.01, 2.0, 0.01) var hover_duration: float = 0.14
@export_range(0.01, 2.0, 0.01) var press_duration: float = 0.08
@export_range(0.01, 2.0, 0.01) var release_duration: float = 0.12

@export_category("Panel")
@export var panel_enter_position: Vector2 = Vector2(0.0, 14.0)
@export var panel_enter_scale: Vector2 = Vector2(0.98, 0.98)
@export var panel_exit_position: Vector2 = Vector2(0.0, -8.0)
@export_range(0.01, 2.0, 0.01) var panel_enter_duration: float = 0.22
@export_range(0.01, 2.0, 0.01) var panel_exit_duration: float = 0.14

@export_category("Modal")
@export var modal_enter_scale: Vector2 = Vector2(0.96, 0.96)
@export var modal_exit_scale: Vector2 = Vector2(0.98, 0.98)
@export_range(0.01, 2.0, 0.01) var modal_mask_enter_duration: float = 0.14
@export_range(0.01, 2.0, 0.01) var modal_panel_enter_duration: float = 0.19
@export_range(0.01, 2.0, 0.01) var modal_exit_duration: float = 0.13

@export_category("Content")
@export_range(0.01, 2.0, 0.01) var content_out_duration: float = 0.11
@export_range(0.01, 2.0, 0.01) var content_in_duration: float = 0.14
@export_range(0.0, 1.0, 0.005) var item_stagger_duration: float = 0.045

@export_category("Scene")
@export_range(0.01, 2.0, 0.01) var scene_out_duration: float = 0.16
@export_range(0.01, 2.0, 0.01) var scene_in_duration: float = 0.22

@export_category("Feedback")
@export_range(1.0, 2.0, 0.01) var pop_peak_scale: float = 1.08
@export_range(0.0, 64.0, 0.5) var shake_strength: float = 8.0
@export_range(1.0, 2.0, 0.01) var pulse_peak_scale: float = 1.05
@export_range(0.01, 2.0, 0.01) var pop_up_duration: float = 0.09
@export_range(0.01, 2.0, 0.01) var pop_return_duration: float = 0.11
@export_range(0.01, 2.0, 0.01) var shake_step_duration: float = 0.035
@export_range(0.01, 2.0, 0.01) var pulse_up_duration: float = 0.14
@export_range(0.01, 2.0, 0.01) var pulse_return_duration: float = 0.16

@export_category("Reward")
@export var reward_start_position: Vector2 = Vector2(0.0, 8.0)
@export var reward_start_scale: Vector2 = Vector2(0.86, 0.86)
@export var reward_peak_scale: Vector2 = Vector2(1.08, 1.08)
@export_range(0.01, 2.0, 0.01) var reward_position_duration: float = 0.18
@export_range(0.01, 2.0, 0.01) var reward_peak_duration: float = 0.16
@export_range(0.01, 2.0, 0.01) var reward_return_duration: float = 0.08
@export_range(0.01, 2.0, 0.01) var badge_reveal_duration: float = 0.52
@export_range(0.01, 1.0, 0.01) var star_reveal_stagger: float = 0.12
@export_range(0.01, 2.0, 0.01) var score_count_duration: float = 0.65