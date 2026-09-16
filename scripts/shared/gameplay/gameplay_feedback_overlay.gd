class_name GameplayFeedbackOverlay
extends Control

signal dismissed

@export_group("Editable Visual State")
@export var correct_panel_style: StyleBox
@export var wrong_panel_style: StyleBox
@export var correct_state_color := Color(0.18, 0.42, 0.12, 1.0)
@export var wrong_state_color := Color(0.68, 0.25, 0.09, 1.0)
@export var correct_title := "TEPAT!"
@export var wrong_title := "COBA LAGI"

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
	state_label.text = correct_title if correct else wrong_title
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
	var selected_style: StyleBox = (
		correct_panel_style
		if correct
		else wrong_panel_style
	)

	if selected_style != null:
		panel.add_theme_stylebox_override(
			"panel",
			selected_style
		)
	else:
		panel.remove_theme_stylebox_override("panel")

	state_label.add_theme_color_override(
		"font_color",
		correct_state_color
		if correct
		else wrong_state_color
	)
