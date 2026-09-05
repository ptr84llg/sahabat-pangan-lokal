extends Control

@onready var challenge_ui: Control = %ChallengeUI
@onready var challenge_title: Label = %ChallengeTitle
@onready var challenge_instruction: RichTextLabel = %ChallengeInstruction
@onready var start_button: Button = %StartButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _start_target: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_force_landscape()
	start_button.pressed.connect(_on_start_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func present(
	source_panel: Control,
	title_text: String,
	instruction_text: String,
	start_target: Button
) -> void:
	_source_panel = source_panel
	_start_target = start_target

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	challenge_title.text = title_text.strip_edges()
	challenge_instruction.text = (
		"[center]" +
		instruction_text.strip_edges() +
		"[/center]"
	)
	start_button.disabled = _start_target == null
	visible = true
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	_source_panel = null
	_start_target = null


func _on_start_pressed() -> void:
	if not is_instance_valid(_start_target):
		return

	start_button.disabled = true
	_start_target.emit_signal("pressed")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method("_refresh_level_challenge_intro_presenter")
	):
		host.call_deferred(
			"_refresh_level_challenge_intro_presenter"
		)


func _force_landscape() -> void:
	if DisplayServer.has_feature(
		DisplayServer.FEATURE_ORIENTATION
	):
		DisplayServer.screen_set_orientation(
			DisplayServer.SCREEN_SENSOR_LANDSCAPE
		)


func _check_orientation() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = viewport_size.y > viewport_size.x

	portrait_blocker.visible = portrait
	challenge_ui.visible = not portrait


