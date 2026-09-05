extends Node

signal layout_changed(viewport_size: Vector2, is_landscape: bool)

var _orientation_layer: CanvasLayer
var _orientation_blocker: ColorRect
var _orientation_label: Label
var _orientation_button: Button

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_orientation_guard()
    get_tree().root.size_changed.connect(_refresh_layout_state)
    _request_native_landscape()
    call_deferred("_refresh_layout_state")

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
    _orientation_blocker.color = Color(0.035, 0.075, 0.055, 0.97)
    _orientation_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
    _orientation_layer.add_child(_orientation_blocker)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _orientation_blocker.add_child(center)

    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(520.0, 250.0)
    center.add_child(panel)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 32)
    margin.add_theme_constant_override("margin_top", 28)
    margin.add_theme_constant_override("margin_right", 32)
    margin.add_theme_constant_override("margin_bottom", 28)
    panel.add_child(margin)

    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    margin.add_child(column)

    var title := Label.new()
    title.text = "MODE LANDSCAPE"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 30)
    column.add_child(title)

    _orientation_label = Label.new()
    _orientation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _orientation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _orientation_label.add_theme_font_size_override("font_size", 20)
    column.add_child(_orientation_label)

    _orientation_button = Button.new()
    _orientation_button.text = "AKTIFKAN LANDSCAPE"
    _orientation_button.custom_minimum_size = Vector2(0.0, 52.0)
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
        _orientation_label.text = "Game ini tetap menggunakan landscape.\nTekan tombol di bawah jika browser belum berputar otomatis."
        _orientation_button.visible = true
    else:
        _orientation_label.text = "Game ini dimainkan dalam posisi landscape.\nPerangkat sedang menyesuaikan orientasi layar."
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