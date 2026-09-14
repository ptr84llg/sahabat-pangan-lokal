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


static func cancel(control: Control, restore_neutral: bool = true) -> void:
	if control == null or not is_instance_valid(control):
		return

	_stop_active_tween(control)

	if restore_neutral:
		_prepare_control(control)
		control.offset_transform_position = NEUTRAL_POSITION
		control.offset_transform_scale = NEUTRAL_SCALE


static func reset(control: Control, duration: float = -1.0) -> void:
	if control == null or not is_instance_valid(control):
		return

	var config := _config()

	if config == null:
		return

	if not config.motion_enabled or is_zero_approx(duration):
		cancel(control, true)
		return

	var resolved_duration := (
		config.release_duration
		if duration < 0.0
		else duration
	)

	_animate_transform(
		control,
		NEUTRAL_POSITION,
		NEUTRAL_SCALE,
		resolved_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)


static func play_panel_enter(
	control: Control,
	delay: float = 0.0
) -> void:
	if control == null or not is_instance_valid(control):
		return

	var config := _config()

	if config == null:
		return

	_prepare_control(control)
	_stop_active_tween(control)

	if not config.motion_enabled:
		control.offset_transform_position = NEUTRAL_POSITION
		control.offset_transform_scale = NEUTRAL_SCALE
		_set_canvas_alpha(control, 1.0)
		return

	var safe_delay: float = maxf(delay, 0.0)
	control.offset_transform_position = config.panel_enter_position
	control.offset_transform_scale = config.panel_enter_scale
	_set_canvas_alpha(control, 0.0)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"offset_transform_position",
		NEUTRAL_POSITION,
		config.panel_enter_duration
	).set_delay(safe_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		config.panel_enter_duration
	).set_delay(safe_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"modulate:a",
		1.0,
		config.panel_enter_duration
	).set_delay(safe_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func play_content_swap(
	control: Control,
	apply_content: Callable
) -> void:
	if control == null or not is_instance_valid(control):
		if apply_content.is_valid():
			apply_content.call()
		return

	var config := _config()

	if config == null:
		if apply_content.is_valid():
			apply_content.call()
		return

	_stop_active_tween(control)

	if not config.motion_enabled:
		if apply_content.is_valid():
			apply_content.call()
		_set_canvas_alpha(control, 1.0)
		return

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.tween_property(
		control,
		"modulate:a",
		0.0,
		config.content_out_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if apply_content.is_valid():
		tween.tween_callback(apply_content)

	tween.tween_property(
		control,
		"modulate:a",
		1.0,
		config.content_in_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func play_modal_open(
	panel: Control,
	mask: CanvasItem = null
) -> void:
	if panel == null or not is_instance_valid(panel):
		return

	var config := _config()

	if config == null:
		return

	_prepare_control(panel)
	_stop_active_tween(panel)

	if mask != null and is_instance_valid(mask):
		_stop_active_canvas_tween(mask)

	if not config.motion_enabled:
		panel.offset_transform_position = NEUTRAL_POSITION
		panel.offset_transform_scale = NEUTRAL_SCALE
		_set_canvas_alpha(panel, 1.0)

		if mask != null and is_instance_valid(mask):
			_set_canvas_alpha(mask, 1.0)

		return

	panel.offset_transform_position = NEUTRAL_POSITION
	panel.offset_transform_scale = config.modal_enter_scale
	_set_canvas_alpha(panel, 1.0)

	if mask != null and is_instance_valid(mask):
		_set_canvas_alpha(mask, 0.0)

	var tween := panel.create_tween()
	panel.set_meta(META_TWEEN, tween)

	if mask != null and is_instance_valid(mask):
		mask.set_meta(META_TWEEN, tween)
		tween.set_parallel(true)
		tween.tween_property(
			mask,
			"modulate:a",
			1.0,
			config.modal_mask_enter_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(
			panel,
			"offset_transform_scale",
			NEUTRAL_SCALE,
			config.modal_panel_enter_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return

	tween.tween_property(
		panel,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		config.modal_panel_enter_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func play_modal_close(
	panel: Control,
	mask: CanvasItem = null,
	on_finished: Callable = Callable()
) -> void:
	if panel == null or not is_instance_valid(panel):
		if on_finished.is_valid():
			on_finished.call()
		return

	var config := _config()

	if config == null:
		_finalize_modal_close(panel, mask, on_finished)
		return

	_prepare_control(panel)
	_stop_active_tween(panel)

	if mask != null and is_instance_valid(mask):
		_stop_active_canvas_tween(mask)

	if not config.motion_enabled:
		_finalize_modal_close(panel, mask, on_finished)
		return

	var tween := panel.create_tween()
	panel.set_meta(META_TWEEN, tween)

	if mask != null and is_instance_valid(mask):
		mask.set_meta(META_TWEEN, tween)

	tween.set_parallel(true)
	tween.tween_property(
		panel,
		"offset_transform_scale",
		config.modal_exit_scale,
		config.modal_exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		panel,
		"modulate:a",
		0.0,
		config.modal_exit_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if mask != null and is_instance_valid(mask):
		tween.tween_property(
			mask,
			"modulate:a",
			0.0,
			config.modal_exit_duration
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.finished.connect(
		_finalize_modal_close.bind(
			panel,
			mask,
			on_finished
		),
		CONNECT_ONE_SHOT
	)


static func play_pop(control: Control, peak_scale: float = -1.0) -> void:
	if control == null or not is_instance_valid(control):
		return

	var config := _config()

	if config == null:
		return

	if not config.motion_enabled:
		cancel(control, true)
		return

	var resolved_peak := (
		config.pop_peak_scale
		if peak_scale < 0.0
		else peak_scale
	)

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

	if not config.motion_enabled:
		cancel(control, true)
		return

	var resolved_strength := (
		config.shake_strength
		if strength < 0.0
		else strength
	)

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

	if not config.motion_enabled:
		cancel(control, true)
		return

	var resolved_peak := (
		config.pulse_peak_scale
		if peak_scale < 0.0
		else peak_scale
	)

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


static func play_badge_reveal(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return

	var config := _config()

	if config == null:
		return

	_prepare_control(control)
	_stop_active_tween(control)

	if not config.motion_enabled:
		control.offset_transform_position = NEUTRAL_POSITION
		control.offset_transform_scale = NEUTRAL_SCALE
		_set_canvas_alpha(control, 1.0)
		return

	var rise_duration: float = maxf(
		config.badge_reveal_duration * 0.68,
		0.01
	)
	var settle_duration: float = maxf(
		config.badge_reveal_duration - rise_duration,
		0.01
	)
	control.offset_transform_position = config.reward_start_position
	control.offset_transform_scale = config.reward_start_scale
	_set_canvas_alpha(control, 0.0)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"offset_transform_position",
		NEUTRAL_POSITION,
		rise_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"offset_transform_scale",
		config.reward_peak_scale,
		rise_duration
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"modulate:a",
		1.0,
		minf(rise_duration, 0.22)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		settle_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func play_star_reveal(
	control: Control,
	delay: float = 0.0
) -> void:
	if control == null or not is_instance_valid(control):
		return

	if not control.visible:
		return

	var config := _config()

	if config == null:
		return

	_prepare_control(control)
	_stop_active_tween(control)

	if not config.motion_enabled:
		control.offset_transform_position = NEUTRAL_POSITION
		control.offset_transform_scale = NEUTRAL_SCALE
		_set_canvas_alpha(control, 1.0)
		return

	var safe_delay: float = maxf(delay, 0.0)
	control.offset_transform_position = NEUTRAL_POSITION
	control.offset_transform_scale = config.reward_start_scale
	_set_canvas_alpha(control, 0.0)

	var tween := control.create_tween()
	control.set_meta(META_TWEEN, tween)
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"offset_transform_scale",
		config.reward_peak_scale,
		config.pop_up_duration
	).set_delay(safe_delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		control,
		"modulate:a",
		1.0,
		config.pop_up_duration
	).set_delay(safe_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(
		control,
		"offset_transform_scale",
		NEUTRAL_SCALE,
		config.pop_return_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func play_score_count(
	label: Label,
	final_text: String
) -> void:
	if label == null or not is_instance_valid(label):
		return

	var config := _config()

	if config == null or not config.motion_enabled:
		label.text = final_text
		return

	var regex := RegEx.new()

	if regex.compile("-?\\d+") != OK:
		label.text = final_text
		return

	var match_result := regex.search(final_text)

	if match_result == null:
		label.text = final_text
		return

	var target_value: int = int(match_result.get_string())
	var start_index: int = match_result.get_start()
	var end_index: int = match_result.get_end()
	var prefix: String = final_text.substr(0, start_index)
	var suffix: String = final_text.substr(end_index)

	_stop_active_tween(label)
	_set_score_count_value(
		0.0,
		label,
		prefix,
		suffix
	)

	var tween := label.create_tween()
	label.set_meta(META_TWEEN, tween)
	tween.tween_method(
		_set_score_count_value.bind(
			label,
			prefix,
			suffix
		),
		0.0,
		float(target_value),
		config.score_count_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(
		_finalize_score_count.bind(
			label,
			final_text
		),
		CONNECT_ONE_SHOT
	)


static func _set_score_count_value(
	value: float,
	label: Label,
	prefix: String,
	suffix: String
) -> void:
	if label == null or not is_instance_valid(label):
		return

	label.text = (
		prefix
		+ str(roundi(value))
		+ suffix
	)


static func _finalize_score_count(
	label: Label,
	final_text: String
) -> void:
	if label == null or not is_instance_valid(label):
		return

	label.text = final_text

static func play_reward(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return

	var config := _config()

	if config == null:
		return

	if not config.motion_enabled:
		cancel(control, true)
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

	if not config.motion_enabled:
		cancel(button, true)
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

	if not config.motion_enabled:
		cancel(button, true)
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

	if not config.motion_enabled:
		cancel(button, true)
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

	if not config.motion_enabled:
		cancel(button, true)
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

	if duration <= 0.0:
		control.offset_transform_position = target_position
		control.offset_transform_scale = target_scale
		return

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


static func _finalize_modal_close(
	panel: Control,
	mask: CanvasItem,
	on_finished: Callable
) -> void:
	if panel != null and is_instance_valid(panel):
		cancel(panel, true)
		_set_canvas_alpha(panel, 1.0)
		panel.visible = false

	if mask != null and is_instance_valid(mask):
		_stop_active_canvas_tween(mask)
		_set_canvas_alpha(mask, 1.0)
		mask.visible = false

	if on_finished.is_valid():
		on_finished.call()


static func _set_canvas_alpha(
	item: CanvasItem,
	alpha: float
) -> void:
	if item == null or not is_instance_valid(item):
		return

	var item_modulate := item.modulate
	item_modulate.a = clampf(alpha, 0.0, 1.0)
	item.modulate = item_modulate


static func _stop_active_canvas_tween(item: CanvasItem) -> void:
	if item == null or not is_instance_valid(item):
		return

	if not item.has_meta(META_TWEEN):
		return

	var tween_value: Variant = item.get_meta(META_TWEEN)

	if tween_value is Tween:
		var active_tween := tween_value as Tween

		if active_tween != null and active_tween.is_valid():
			active_tween.kill()

	item.remove_meta(META_TWEEN)


static func _stop_active_tween(control: Control) -> void:
	_stop_active_canvas_tween(control)