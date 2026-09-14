class_name ScreenMotionPresenter
extends RefCounted


static func bind_buttons(button_values: Array) -> void:
	for button_value in button_values:
		var button := button_value as BaseButton

		if button != null:
			UIMotion.bind_button(button)


static func enter_screen(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return

	UIMotion.play_panel_enter(control)


static func enter_staggered(control_values: Array) -> void:
	var config := _config()
	var stagger_duration: float = (
		config.item_stagger_duration
		if config != null
		else 0.0
	)
	var valid_index: int = 0

	for control_value in control_values:
		var control := control_value as Control

		if control == null or not is_instance_valid(control):
			continue

		UIMotion.play_panel_enter(
			control,
			stagger_duration * float(valid_index)
		)
		valid_index += 1


static func main_menu_entrance(
	menu_panel: Control,
	logo: Control,
	brand_text_values: Array
) -> void:
	var config := _config()

	if config == null:
		return

	UIMotion.play_slide_fade_in(
		menu_panel,
		Vector2(config.main_menu_side_offset, 0.0),
		config.main_menu_panel_duration,
		config.main_menu_panel_delay
	)
	UIMotion.play_slide_fade_in(
		logo,
		Vector2(-config.main_menu_side_offset, 0.0),
		config.main_menu_logo_duration
	)

	var text_index: int = 0

	for text_value in brand_text_values:
		var text_control := text_value as Control

		if text_control == null or not is_instance_valid(text_control):
			continue

		if not text_control.visible:
			continue

		UIMotion.play_slide_fade_in(
			text_control,
			Vector2(
				0.0,
				config.main_menu_text_bottom_offset
			),
			config.main_menu_text_duration,
			config.main_menu_text_delay
			+ config.main_menu_text_stagger
			* float(text_index)
		)
		text_index += 1


static func collection_reveal(control_values: Array) -> void:
	var config := _config()

	if config == null:
		return

	var visible_index: int = 0

	for control_value in control_values:
		var control := control_value as Control

		if control == null or not is_instance_valid(control):
			continue

		if not control.visible:
			continue

		UIMotion.play_slide_fade_in(
			control,
			config.collection_item_position,
			config.collection_item_duration,
			config.collection_initial_delay
			+ config.collection_item_stagger
			* float(visible_index)
		)
		visible_index += 1


static func character_selected_flip_x(control: Control) -> void:
	var config := _config()

	if config == null:
		return

	UIMotion.play_flip_x_once(
		control,
		config.character_flip_degrees,
		config.character_flip_duration
	)


static func dialogue_enter(
	npc_control: Control,
	player_control: Control,
	name_panel_values: Array,
	text_control: Control,
	on_text_start: Callable = Callable()
) -> void:
	var config := _config()

	if config == null:
		if on_text_start.is_valid():
			on_text_start.call()
		return

	UIMotion.play_slide_fade_in(
		npc_control,
		Vector2(-config.dialogue_character_offset, 0.0),
		config.dialogue_character_duration
	)
	UIMotion.play_slide_fade_in(
		player_control,
		Vector2(config.dialogue_character_offset, 0.0),
		config.dialogue_character_duration
	)

	for panel_value in name_panel_values:
		var panel := panel_value as Control

		if panel == null or not is_instance_valid(panel):
			continue

		UIMotion.play_fade_in(
			panel,
			config.dialogue_name_fade_duration,
			config.dialogue_name_delay
		)

	UIMotion.play_fade_in(
		text_control,
		config.dialogue_text_fade_duration,
		config.dialogue_text_delay
	)
	_schedule_motion_callback(
		text_control,
		config.dialogue_text_delay,
		on_text_start,
		config.motion_enabled
	)


static func dialogue_line_reveal(
	_name_panel_values: Array,
	text_control: Control,
	on_text_start: Callable = Callable()
) -> void:
	var config := _config()

	if config == null:
		if on_text_start.is_valid():
			on_text_start.call()
		return

	UIMotion.play_fade_in(
		text_control,
		config.dialogue_text_fade_duration,
		config.dialogue_line_text_delay
	)
	_schedule_motion_callback(
		text_control,
		config.dialogue_line_text_delay,
		on_text_start,
		config.motion_enabled
	)


static func _schedule_motion_callback(
	context: Control,
	delay: float,
	callback: Callable,
	motion_enabled: bool
) -> void:
	if not callback.is_valid():
		return

	if (
		not motion_enabled
		or context == null
		or not is_instance_valid(context)
		or delay <= 0.0
	):
		callback.call()
		return

	var timer := context.get_tree().create_timer(delay)
	timer.timeout.connect(
		callback,
		CONNECT_ONE_SHOT
	)


static func tutorial_reveal(control_values: Array) -> void:
	var config := _config()

	if config == null:
		return

	var visible_index: int = 0

	for control_value in control_values:
		var control := control_value as Control

		if control == null or not is_instance_valid(control):
			continue

		if not control.visible:
			continue

		UIMotion.play_fade_in(
			control,
			config.tutorial_item_fade_duration,
			config.tutorial_item_stagger
			* float(visible_index)
		)
		visible_index += 1


static func select_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return

	var config := _config()

	if config == null:
		UIMotion.play_pop(control)
		return

	UIMotion.play_pop(
		control,
		config.hover_scale.x
	)


static func open_modal(
	panel: Control,
	mask: CanvasItem = null
) -> void:
	UIMotion.play_modal_open(panel, mask)


static func close_modal(
	panel: Control,
	mask: CanvasItem = null,
	on_finished: Callable = Callable()
) -> void:
	UIMotion.play_modal_close(
		panel,
		mask,
		on_finished
	)


static func swap_content(
	control: Control,
	apply_content: Callable
) -> void:
	UIMotion.play_content_swap(
		control,
		apply_content
	)


static func bind_button(button: BaseButton) -> void:
	UIMotion.bind_button(button)


static func bind_gameplay_hover(
	control: Control,
	enabled: bool = true
) -> void:
	UIMotion.bind_hover_control(control, enabled)


static func set_gameplay_hover_enabled(
	control: Control,
	enabled: bool
) -> void:
	UIMotion.set_hover_control_enabled(control, enabled)


static func gameplay_drop_success(
	source_control: Control,
	target_control: Control
) -> void:
	UIMotion.cancel(source_control, true)
	UIMotion.cancel(target_control, true)
	UIMotion.play_drop_landing(source_control)
	UIMotion.play_pulse(target_control)


static func gameplay_drop_wrong(
	source_control: Control,
	target_control: Control
) -> void:
	UIMotion.cancel(source_control, true)
	UIMotion.cancel(target_control, true)
	UIMotion.play_shake(source_control)
	UIMotion.play_shake(target_control)


static func gameplay_reveal(control_values: Array) -> void:
	var config := _config()

	if config == null:
		return

	var visible_index: int = 0

	for control_value in control_values:
		var control := control_value as Control

		if control == null or not is_instance_valid(control):
			continue

		if not control.visible:
			continue

		UIMotion.play_fade_in(
			control,
			config.gameplay_item_fade_duration,
			config.gameplay_item_stagger
			* float(visible_index)
		)
		visible_index += 1

static func level_complete_reveal(
	control_values: Array
) -> void:
	var config := _config()

	if config == null:
		return

	var visible_index: int = 0

	for control_value in control_values:
		var control := control_value as Control

		if control == null or not is_instance_valid(control):
			continue

		if not control.visible:
			continue

		var delay: float = (
			config.collection_initial_delay
			+ config.collection_item_stagger
			* float(visible_index)
		)

		UIMotion.play_fade_in(
			control,
			config.collection_item_duration,
			delay
		)
		UIMotion.play_rise_in(
			control,
			config.collection_item_position,
			config.collection_item_duration,
			delay
		)
		visible_index += 1

static func gameplay_pop(
	control: Control,
	_legacy_peak_scale: float = -1.0
) -> void:
	UIMotion.play_pop(control)


static func gameplay_wrong(
	control: Control,
	_legacy_strength: float = -1.0
) -> void:
	UIMotion.play_shake(control)


static func gameplay_hint(
	control: Control,
	_legacy_peak_scale: float = -1.0
) -> void:
	UIMotion.play_pulse(control)


static func gameplay_reward(control: Control) -> void:
	UIMotion.play_reward(control)


static func timer_warning(control: Control) -> void:
	UIMotion.play_pulse(control)


static func reset_control(
	control: Control,
	duration: float = -1.0
) -> void:
	UIMotion.reset(control, duration)


static func cancel_control(
	control: Control,
	restore_neutral: bool = true
) -> void:
	UIMotion.cancel(control, restore_neutral)


static func reveal_badge(control: Control) -> void:
	UIMotion.play_badge_reveal(control)


static func reveal_stars(star_values: Array) -> void:
	var config := _config()
	var stagger: float = (
		config.star_reveal_stagger
		if config != null
		else 0.0
	)
	var visible_index: int = 0

	for star_value in star_values:
		var star := star_value as Control

		if star == null or not is_instance_valid(star):
			continue

		if not star.visible:
			continue

		UIMotion.play_star_reveal(
			star,
			stagger * float(visible_index)
		)
		visible_index += 1


static func count_score(
	label: Label,
	final_text: String
) -> void:
	UIMotion.play_score_count(
		label,
		final_text
	)
static func _config() -> MotionConfig:
	var resource := load(UIMotion.CONFIG_PATH)

	if resource is MotionConfig:
		return resource as MotionConfig

	push_error("ScreenMotionPresenter: MotionConfig tidak dapat dimuat.")
	return null