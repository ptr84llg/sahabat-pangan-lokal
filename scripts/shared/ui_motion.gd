class_name UIMotion
extends RefCounted

const META_BOUND: StringName = &"spl_ui_motion_bound"
const META_TWEEN: StringName = &"spl_ui_motion_tween"

const HOVER_POSITION := Vector2(0.0, -3.0)
const HOVER_SCALE := Vector2(1.025, 1.025)
const PRESS_POSITION := Vector2(0.0, 1.0)
const PRESS_SCALE := Vector2(0.975, 0.975)
const NEUTRAL_POSITION := Vector2.ZERO
const NEUTRAL_SCALE := Vector2.ONE

const HOVER_DURATION := 0.14
const PRESS_DURATION := 0.08
const RELEASE_DURATION := 0.12

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


static func reset(control: Control, duration: float = RELEASE_DURATION) -> void:
	if control == null or not is_instance_valid(control):
		return

	_animate_transform(
		control,
		NEUTRAL_POSITION,
		NEUTRAL_SCALE,
		duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)


static func play_pop(control: Control, peak_scale: float = 1.08) -> void:
	if control == null or not is_instance_valid(control):
		return

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)

	tween.tween_property(
		control,
		"offset_transform_scale",
		Vector2(peak_scale, peak_scale),
		0.10
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func play_shake(control: Control, strength: float = 8.0) -> void:
	if control == null or not is_instance_valid(control):
		return

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)

	var offsets: Array[float] = [
		-strength,
		strength,
		-strength * 0.65,
		strength * 0.65,
		-strength * 0.35,
		strength * 0.35,
		0.0
	]

	for x_offset in offsets:
		tween.tween_property(
			control,
			"offset_transform_position",
			Vector2(x_offset, 0.0),
			0.035
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


static func play_pulse(control: Control, peak_scale: float = 1.05) -> void:
	if control == null or not is_instance_valid(control):
		return

	_prepare_control(control)
	_stop_active_tween(control)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)

	tween.tween_property(
		control,
		"offset_transform_scale",
		Vector2(peak_scale, peak_scale),
		0.14
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		0.16
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


static func play_reward(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return

	_prepare_control(control)
	_stop_active_tween(control)

	control.offset_transform_position = Vector2(0.0, 8.0)
	control.offset_transform_scale = Vector2(0.86, 0.86)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.set_parallel(true)

	tween.tween_property(
		control,
		"offset_transform_position",
		NEUTRAL_POSITION,
		0.26
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		control,
		"offset_transform_scale",
		Vector2(1.08, 1.08),
		0.22
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tween.chain().tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		0.14
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

	_animate_transform(
		button,
		HOVER_POSITION,
		HOVER_SCALE,
		HOVER_DURATION,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)


static func _on_button_hover_exit(button: BaseButton) -> void:
	reset(button)


static func _on_button_down(button: BaseButton) -> void:
	if button.disabled:
		reset(button)
		return

	_animate_transform(
		button,
		PRESS_POSITION,
		PRESS_SCALE,
		PRESS_DURATION,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)


static func _on_button_up(button: BaseButton) -> void:
	if button.disabled:
		reset(button)
		return

	if button.is_hovered():
		_animate_transform(
			button,
			HOVER_POSITION,
			HOVER_SCALE,
			RELEASE_DURATION,
			Tween.TRANS_QUAD,
			Tween.EASE_OUT
		)
		return

	reset(button)


static func _on_button_focus_enter(button: BaseButton) -> void:
	if button.disabled or button.is_hovered():
		return

	_animate_transform(
		button,
		HOVER_POSITION,
		HOVER_SCALE,
		HOVER_DURATION,
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