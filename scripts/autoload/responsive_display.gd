extends Node

signal layout_changed(viewport_size: Vector2, is_landscape: bool)

const CONFIG_PATH: String = "res://resources/config/responsive_config.tres"

var config: ResponsiveConfig
var _orientation_layer: CanvasLayer
var _orientation_blocker: ColorRect
var _orientation_label: Label
var _orientation_button: Button

func _ready() -> void:
	var loaded := load(CONFIG_PATH)
	if loaded is ResponsiveConfig:
		config = loaded as ResponsiveConfig
	else:
		push_error("ResponsiveConfig tidak dapat dimuat.")
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_orientation_guard()
	get_tree().root.size_changed.connect(_refresh_layout_state)
	get_tree().node_added.connect(_on_tree_node_added)
	_request_native_landscape()
	call_deferred("_refresh_layout_state")
	call_deferred("_configure_existing_touch_scroll")

func _configure_existing_touch_scroll() -> void:
	if not _supports_native_orientation():
		return

	_configure_touch_scroll_tree(
		get_tree().root
	)


func _on_tree_node_added(node: Node) -> void:
	if not _supports_native_orientation():
		return

	if node is ScrollContainer:
		call_deferred(
			"_configure_touch_scroll_container",
			node
		)
		return

	if not node is Control:
		return

	if _find_scroll_ancestor(node) != null:
		call_deferred(
			"_configure_touch_scroll_descendant",
			node
		)


func _configure_touch_scroll_tree(node: Node) -> void:
	if node == null:
		return

	if node is ScrollContainer:
		_configure_touch_scroll_container(
			node as ScrollContainer
		)
		return

	for child_value in node.get_children():
		var child := child_value as Node

		if child != null:
			_configure_touch_scroll_tree(child)


func _configure_touch_scroll_container(
	scroll: ScrollContainer
) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return

	scroll.scroll_deadzone = 0
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	for child_value in scroll.get_children():
		var child := child_value as Node

		if child != null:
			_configure_touch_scroll_descendant(child)


func _configure_touch_scroll_descendant(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is ScrollBar:
		return

	if node is ScrollContainer:
		_configure_touch_scroll_container(
			node as ScrollContainer
		)
		return

	if (
		node is Slider
		or node is LineEdit
		or node is TextEdit
	):
		return

	if node is Control:
		var control := node as Control

		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			control.mouse_filter = Control.MOUSE_FILTER_PASS

	for child_value in node.get_children():
		var child := child_value as Node

		if child != null:
			_configure_touch_scroll_descendant(child)


func _find_scroll_ancestor(node: Node) -> ScrollContainer:
	var current := node.get_parent()

	while current != null:
		if current is ScrollContainer:
			return current as ScrollContainer

		current = current.get_parent()

	return null


func _supports_native_orientation() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

func _request_native_landscape() -> void:
	if _supports_native_orientation():
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)

func _build_orientation_guard() -> void:
	_orientation_layer = CanvasLayer.new()
	_orientation_layer.layer = 10000
	add_child(_orientation_layer)

	_orientation_blocker = ColorRect.new()
	_orientation_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orientation_blocker.color = config.blocker_color
	_orientation_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_orientation_layer.add_child(_orientation_blocker)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orientation_blocker.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = config.panel_minimum_size
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", config.margin_left)
	margin.add_theme_constant_override("margin_top", config.margin_top)
	margin.add_theme_constant_override("margin_right", config.margin_right)
	margin.add_theme_constant_override("margin_bottom", config.margin_bottom)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", config.separation)
	margin.add_child(column)

	var title := Label.new()
	title.text = config.title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", config.title_font_size)
	column.add_child(title)

	_orientation_label = Label.new()
	_orientation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_orientation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_orientation_label.add_theme_font_size_override("font_size", config.body_font_size)
	column.add_child(_orientation_label)

	_orientation_button = Button.new()
	_orientation_button.text = config.button_text
	_orientation_button.custom_minimum_size = Vector2(0.0, config.button_height)
	_orientation_button.pressed.connect(_request_web_landscape)
	column.add_child(_orientation_button)

	_orientation_layer.visible = false

func _refresh_layout_state() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var is_landscape := viewport_size.x >= viewport_size.y
	_orientation_layer.visible = not is_landscape

	if not is_landscape:
		_request_native_landscape()

	if OS.has_feature("web"):
		_orientation_label.text = config.web_message
		_orientation_button.visible = true
	else:
		_orientation_label.text = config.native_message
		_orientation_button.visible = false

	layout_changed.emit(viewport_size, is_landscape)

func _request_web_landscape() -> void:
	if not OS.has_feature("web"):
		_request_native_landscape()
		return

	JavaScriptBridge.eval("""
(async () => {
    try {
        if (!document.fullscreenElement && document.documentElement.requestFullscreen) {
            await document.documentElement.requestFullscreen()
        }
        if (screen.orientation && screen.orientation.lock) {
            await screen.orientation.lock("landscape")
        }
    } catch (error) {
        console.log("SPL orientation fallback", error)
    }
})()
""")