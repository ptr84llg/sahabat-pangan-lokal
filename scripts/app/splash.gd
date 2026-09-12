extends Control

const SOURCE_SIZE := Vector2(1672.0, 941.0)
const LOADER_SIZE := Vector2(670.0, 112.0)
const LOADER_BOTTOM_MARGIN: float = 52.0
const PROGRESS_WIDTH: float = 584.0
const PROGRESS_HEIGHT: float = 38.0

@onready var loader_root: Control = %LoaderRoot
@onready var progress_fill: NinePatchRect = %ProgressFill
@onready var update_status_label: Label = %UpdateStatusLabel
@onready var error_shade: ColorRect = %ErrorShade
@onready var error_label: Label = %ErrorLabel

func _ready() -> void:
	get_viewport().size_changed.connect(_layout_loader)
	_layout_loader()
	_set_progress(0.0)

	UpdateManager.status_changed.connect(_on_update_status_changed)
	UpdateManager.progress_changed.connect(_on_update_progress_changed)

	await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout

	_set_update_status("MEMERIKSA PEMBARUAN...")
	_set_progress(5.0)

	var update_result: Dictionary = await UpdateManager.run_startup_update()
	if bool(update_result.get("blocking", false)):
		_fail(
			str(
				update_result.get(
					"message",
					"Pembaruan aplikasi diperlukan."
				)
			)
		)
		return

	_set_update_status("MENYIAPKAN PERMAINAN...")
	_set_progress(45.0)
	await get_tree().create_timer(0.08).timeout

	if not ContentDatabase.initialize():
		_fail("Konten permainan gagal dimuat.")
		return

	_set_progress(58.0)
	await get_tree().create_timer(0.10).timeout

	SettingsManager.initialize()
	_set_progress(70.0)
	await get_tree().create_timer(0.10).timeout

	if not SaveManager.initialize_native_storage():
		_fail("Penyimpanan permainan gagal disiapkan.")
		return

	SettingsManager.import_state(
		SaveManager.load_native_settings()
	)
	GameState.initialize(
		SaveManager.load_native_game_state()
	)

	if not SaveManager.save_now():
		_fail("Penyimpanan permainan gagal disimpan.")
		return

	CompletedHistorySyncManager.schedule_sync("startup")

	_set_progress(85.0)
	await get_tree().create_timer(0.10).timeout

	AnalyticsLogger.initialize()
	AudioManager.apply_settings()

	_set_update_status("SIAP BERMAIN")
	_set_progress(100.0)
	await get_tree().create_timer(0.35).timeout

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

	loader_root.scale = Vector2(
		scale_factor,
		scale_factor
	)

	var scaled_size: Vector2 = LOADER_SIZE * scale_factor
	var bottom_margin: float = (
		LOADER_BOTTOM_MARGIN * scale_factor
	)

	loader_root.position = Vector2(
		round(
			(viewport_size.x - scaled_size.x) * 0.5
		),
		round(
			viewport_size.y
			- scaled_size.y
			- bottom_margin
		)
	)

func _set_progress(value: float) -> void:
	var safe_value: float = clampf(
		value,
		0.0,
		100.0
	)
	progress_fill.visible = safe_value > 0.0
	progress_fill.size = Vector2(
		PROGRESS_WIDTH * safe_value / 100.0,
		PROGRESS_HEIGHT
	)

func _set_update_status(message: String) -> void:
	update_status_label.text = message

func _on_update_status_changed(message: String) -> void:
	_set_update_status(message)

func _on_update_progress_changed(value: float) -> void:
	var safe_value: float = clampf(
		value,
		0.0,
		1.0
	)
	var mapped_value: float = lerpf(
		5.0,
		45.0,
		safe_value
	)
	_set_progress(mapped_value)

func _fail(message: String) -> void:
	error_label.text = message
	error_shade.visible = true

func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()
