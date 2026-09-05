extends Control

@onready var ui_root: Control = %UIRoot
@onready var level_name_label: Label = %LevelName
@onready var intro_text: RichTextLabel = %IntroText
@onready var back_button: Button = %BackButton
@onready var continue_button: Button = %ContinueButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _continue_target: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_landscape()
	back_button.pressed.connect(_on_back_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func present(
	source_panel: Control,
	level_name: String,
	body_text: String,
	continue_target: Button
) -> void:
	_source_panel = source_panel
	_continue_target = continue_target

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	level_name_label.text = level_name
	intro_text.text = "[center]" + body_text.strip_edges() + "[/center]"
	continue_button.disabled = _continue_target == null
	visible = true
	_check_orientation()


func hide_presenter() -> void:
	visible = false
	_source_panel = null
	_continue_target = null


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
	ui_root.visible = not portrait


func _on_back_pressed() -> void:
	var router_node: Node = get_node_or_null(
		NodePath("/root/SceneRouter")
	)

	if router_node != null and router_node.has_method("goto"):
		router_node.call("goto", "main_map")


func _on_continue_pressed() -> void:
	if is_instance_valid(_continue_target):
		_continue_target.emit_signal("pressed")
