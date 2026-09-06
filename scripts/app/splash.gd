extends Control

const SOURCE_SIZE := Vector2(1672.0, 941.0)
const LOADER_SIZE := Vector2(670.0, 112.0)
const LOADER_BOTTOM_MARGIN: float = 52.0
const PROGRESS_WIDTH: float = 584.0
const PROGRESS_HEIGHT: float = 38.0

@onready var loader_root: Control = %LoaderRoot
@onready var progress_fill: NinePatchRect = %ProgressFill
@onready var error_shade: ColorRect = %ErrorShade
@onready var error_label: Label = %ErrorLabel

func _ready() -> void:
    get_viewport().size_changed.connect(_layout_loader)
    _layout_loader()
    _set_progress(0.0)

    await get_tree().process_frame
    await get_tree().create_timer(0.10).timeout

    if not ContentDatabase.initialize():
        _fail("Konten permainan gagal dimuat.")
        return

    _set_progress(25.0)
    await get_tree().create_timer(0.12).timeout

    SettingsManager.initialize()
    _set_progress(50.0)
    await get_tree().create_timer(0.12).timeout

    var payload: Dictionary = SaveManager.load_payload()
    if not payload.is_empty():
        SettingsManager.import_state(payload.get("settings", {}))
        GameState.initialize(payload.get("game_state", {}))
    else:
        GameState.initialize()

    if not SaveManager.refresh_v3_shadow():
        push_warning("Shadow storage schema v3 belum dapat diperbarui. Save legacy tetap aktif.")

    _set_progress(75.0)
    await get_tree().create_timer(0.12).timeout

    AnalyticsLogger.initialize()
    AudioManager.apply_settings()

    _set_progress(100.0)
    await get_tree().create_timer(0.45).timeout

    SceneRouter.goto("main_menu")

func _layout_loader() -> void:
    var viewport_size: Vector2 = get_viewport_rect().size
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
        return

    var scale_factor: float = minf(
        viewport_size.x / SOURCE_SIZE.x,
        viewport_size.y / SOURCE_SIZE.y
    )
    scale_factor = clampf(scale_factor, 0.45, 1.35)

    loader_root.scale = Vector2(scale_factor, scale_factor)

    var scaled_size: Vector2 = LOADER_SIZE * scale_factor
    var bottom_margin: float = LOADER_BOTTOM_MARGIN * scale_factor

    loader_root.position = Vector2(
        round((viewport_size.x - scaled_size.x) * 0.5),
        round(viewport_size.y - scaled_size.y - bottom_margin)
    )

func _set_progress(value: float) -> void:
    var safe_value: float = clampf(value, 0.0, 100.0)
    progress_fill.visible = safe_value > 0.0
    progress_fill.size = Vector2(
        PROGRESS_WIDTH * safe_value / 100.0,
        PROGRESS_HEIGHT
    )

func _fail(message: String) -> void:
    error_label.text = message
    error_shade.visible = true

func _on_retry_button_pressed() -> void:
    get_tree().reload_current_scene()