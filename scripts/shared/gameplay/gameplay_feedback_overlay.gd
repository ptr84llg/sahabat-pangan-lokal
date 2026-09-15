class_name GameplayFeedbackOverlay
extends Control

signal dismissed

@onready var mask: ColorRect = %FeedbackMask
@onready var panel: PanelContainer = %FeedbackPanel
@onready var state_label: Label = %FeedbackState
@onready var message_label: Label = %FeedbackMessage
@onready var timer: Timer = %AutoCloseTimer

var _closing := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer.timeout.connect(dismiss)
	gui_input.connect(_on_gui_input)


func present_feedback(
	message: String,
	correct: bool,
	auto_close_seconds: float = 1.05
) -> void:
	var clean_message := message.strip_edges()

	if clean_message.is_empty():
		return

	timer.stop()
	_closing = false
	state_label.text = "TEPAT!" if correct else "COBA LAGI"
	message_label.text = clean_message
	_apply_state_style(correct)

	visible = true
	mask.visible = true
	panel.visible = true
	ScreenMotionPresenter.open_modal(panel, mask)

	if auto_close_seconds > 0.0:
		timer.start(auto_close_seconds)


func dismiss() -> void:
	if not visible or _closing:
		return

	_closing = true
	timer.stop()
	ScreenMotionPresenter.close_modal(
		panel,
		mask,
		_finish_dismiss
	)


func _finish_dismiss() -> void:
	visible = false
	_closing = false
	dismissed.emit()


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
	):
		dismiss()
		accept_event()
		return

	if (
		event is InputEventScreenTouch
		and event.pressed
	):
		dismiss()
		accept_event()


func _apply_state_style(correct: bool) -> void:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 28.0
	style.content_margin_top = 24.0
	style.content_margin_right = 28.0
	style.content_margin_bottom = 24.0
	style.bg_color = (
		Color(0.95, 0.99, 0.90, 0.99)
		if correct
		else Color(1.0, 0.95, 0.88, 0.99)
	)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = (
		Color(0.28, 0.57, 0.18, 0.95)
		if correct
		else Color(0.84, 0.39, 0.14, 0.95)
	)
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.02, 0.04, 0.02, 0.28)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)

	state_label.add_theme_color_override(
		"font_color",
		Color(0.18, 0.42, 0.12, 1.0)
		if correct
		else Color(0.68, 0.25, 0.09, 1.0)
	)