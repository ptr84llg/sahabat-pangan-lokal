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


static func _config() -> MotionConfig:
	var resource := load(UIMotion.CONFIG_PATH)

	if resource is MotionConfig:
		return resource as MotionConfig

	push_error("ScreenMotionPresenter: MotionConfig tidak dapat dimuat.")
	return null