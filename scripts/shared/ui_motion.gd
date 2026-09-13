class_name UIMotion
extends RefCounted

const CONFIG_PATH: String = "res://resources/config/motion_config.tres"
const META_BOUND: StringName = &"spl_ui_motion_bound"
const META_TWEEN: StringName = &"spl_ui_motion_tween"
const NEUTRAL_POSITION := Vector2.ZERO
const NEUTRAL_SCALE := Vector2.ONE

static func _config() -> MotionConfig:
	var resource := load(CONFIG_PATH)
	if resource is MotionConfig:
		return resource as MotionConfig
	push_error("MotionConfig tidak dapat dimuat.")
	return null

static func bind_button(button: BaseButton) -> void:
	if button == null or not is_instance_valid(button):
		return
	if bool(button.get_meta(META_BOUND, false)):
		return

	_prepare_control(button)
	button.set_meta(META_BOUND, true)
	button.mouse_entered.connect(_on_button_hover_enter.bind(button))
	button.mouse_exited.connect(_on_button_hover_exit.bind(button))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))
	button.focus_entered.connect(_on_button_focus_enter.bind(button))
	button.focus_exited.connect(_on_button_focus_exit.bind(button))

static func reset(control: Control, duration: float = -1.0) -> void:
	if control == null or not is_instance_valid(control):
		return
	var config := _config()
	if config == null:
		return
	var resolved_duration := config.release_duration if duration < 0.0 else duration
	_animate_transform(
		control,
		NEUTRAL_POSITION,
		NEUTRAL_SCALE,
		resolved_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

static func play_pop(control: Control, peak_scale: float = -1.0) -> void:
	if control == null or not is_instance_valid(control):
		return
	var config := _config()
	if config == null:
		return
	var resolved_peak := config.pop_peak_scale if peak_scale < 0.0 else peak_scale

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.tween_property(
		control,
		"offset_transform_scale",
		Vector2(resolved_peak, resolved_peak),
		config.pop_up_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		config.pop_return_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func play_shake(control: Control, strength: float = -1.0) -> void:
	if control == null or not is_instance_valid(control):
		return
	var config := _config()
	if config == null:
		return
	var resolved_strength := config.shake_strength if strength < 0.0 else strength

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	var offsets: Array[float] = [
		-resolved_strength,
		resolved_strength,
		-resolved_strength * 0.65,
		resolved_strength * 0.65,
		-resolved_strength * 0.35,
		resolved_strength * 0.35,
		0.0
	]
	for x_offset in offsets:
		tween.tween_property(
			control,
			"offset_transform_position",
			Vector2(x_offset, 0.0),
			config.shake_step_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

static func play_pulse(control: Control, peak_scale: float = -1.0) -> void:
	if control == null or not is_instance_valid(control):
		return
	var config := _config()
	if config == null:
		return
	var resolved_peak := config.pulse_peak_scale if peak_scale < 0.0 else peak_scale

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.tween_property(
		control,
		"offset_transform_scale",
		Vector2(resolved_peak, resolved_peak),
		config.pulse_up_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		config.pulse_return_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

static func play_reward(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var config := _config()
	if config == null:
		return

	_prepare_control(control)
	_stop_active_tween(control)
	control.offset_transform_position = config.reward_start_position
	control.offset_transform_scale = config.reward_start_scale

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"offset_transform_position",
		NEUTRAL_POSITION,
		config.reward_position_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"offset_transform_scale",
		config.reward_peak_scale,
		config.reward_peak_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		config.reward_return_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func _prepare_control(control: Control) -> void:
	control.offset_transform_enabled = true
	control.offset_transform_visual_only = true
	control.offset_transform_pivot = Vector2.ZERO
	control.offset_transform_pivot_ratio = Vector2(0.5, 0.5)

static func _on_button_hover_enter(button: BaseButton) -> void:
	if button.disabled:
		reset(button)
		return
	var config := _config()
	if config == null:
		return
	_animate_transform(
		button,
		config.hover_position,
		config.hover_scale,
		config.hover_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

static func _on_button_hover_exit(button: BaseButton) -> void:
	reset(button)

static func _on_button_down(button: BaseButton) -> void:
	if button.disabled:
		reset(button)
		return
	var config := _config()
	if config == null:
		return
	_animate_transform(
		button,
		config.press_position,
		config.press_scale,
		config.press_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

static func _on_button_up(button: BaseButton) -> void:
	if button.disabled:
		reset(button)
		return
	var config := _config()
	if config == null:
		return
	if button.is_hovered():
		_animate_transform(
			button,
			config.hover_position,
			config.hover_scale,
			config.release_duration,
			Tween.TRANS_QUAD,
			Tween.EASE_OUT
		)
		return
	reset(button)

static func _on_button_focus_enter(button: BaseButton) -> void:
	if button.disabled or button.is_hovered():
		return
	var config := _config()
	if config == null:
		return
	_animate_transform(
		button,
		config.hover_position,
		config.hover_scale,
		config.hover_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)

static func _on_button_focus_exit(button: BaseButton) -> void:
	if button.is_hovered():
		return
	reset(button)

static func _animate_transform(
	control: Control,
	target_position: Vector2,
	target_scale: Vector2,
	duration: float,
	transition_type: Tween.TransitionType,
	ease_type: Tween.EaseType
) -> void:
	if control == null or not is_instance_valid(control):
		return

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"offset_transform_position",
		target_position,
		duration
	).set_trans(transition_type).set_ease(ease_type)
	tween.tween_property(
		control,
		"offset_transform_scale",
		target_scale,
		duration
	).set_trans(transition_type).set_ease(ease_type)

static func _stop_active_tween(control: Control) -> void:
	if not control.has_meta(META_TWEEN):
		return
	var tween_value: Variant = control.get_meta(META_TWEEN)
	if tween_value is Tween:
		var active_tween := tween_value as Tween
		if active_tween != null and active_tween.is_valid():
			active_tween.kill()
	control.remove_meta(META_TWEEN)