extends Control

const PROCESSED_FOOD_TEXTURE_PATHS := {
	"processed_banana_cassava_compote": "res://assets/visual/processed_foods/processed_banana_cassava_compote.png",
	"processed_spinach_corn_clear_soup": "res://assets/visual/processed_foods/processed_spinach_corn_clear_soup.png",
	"processed_water_spinach_eggplant_stirfry": "res://assets/visual/processed_foods/processed_water_spinach_eggplant_stirfry.png",
	"processed_papaya_mango_rujak": "res://assets/visual/processed_foods/processed_papaya_mango_rujak.png"
}

const BADGE_TEXTURE_PATHS := {
	"badge_level_01": "res://assets/visual/badges/badge-1.png",
	"badge_level_02": "res://assets/visual/badges/badge-2.png",
	"badge_level_03": "res://assets/visual/badges/badge-3.png",
	"badge_level_04": "res://assets/visual/badges/badge-4.png",
	"badge_level_05": "res://assets/visual/badges/badge-5.png"
}

const RESET_CONFIRMATION_RESET := "reset"
const RESET_CONFIRMATION_NEW_RUN := "new_run"

var _modal_mask: ColorRect
var _medal_count_label: Label
var _medal_list: VBoxContainer
var _about_panel: PanelContainer
var _about_close_button: Button
var _exit_panel: PanelContainer
var _exit_cancel_button: Button
var _exit_confirm_button: Button
var _reset_game_panel: PanelContainer
var _reset_game_cancel_button: Button
var _reset_game_confirm_button: Button
var _reset_game_header: Label
var _reset_game_question: Label
var _reset_game_note: Label
var _reset_confirmation_mode: String = RESET_CONFIRMATION_RESET
var _device_panel: PanelContainer
var _device_close_button: Button
var _device_body: VBoxContainer
var _history_panel: PanelContainer
var _history_close_button: Button
var _history_body: VBoxContainer

func _ready() -> void:
	if not _bind_scene_authored_modals():
		return

	_medal_count_label = %MedalCountLabel
	_medal_list = %MedalList

	%ContinueButton.visible = GameState.has_active_run()
	%ResetDataButton.visible = GameState.has_active_run()
	%ResetDataButton.text = "RESET GAME"

	%ContinueButton.pressed.connect(_continue_run)
	%NewRunButton.pressed.connect(_new_run)
	%GalleryButton.pressed.connect(_open_gallery)
	%DeviceButton.pressed.connect(_open_device_panel)
	%HistoryButton.pressed.connect(_open_history_panel)
	%SettingsButton.pressed.connect(_open_audio_panel)
	%AboutButton.pressed.connect(_show_about)
	%ResetDataButton.pressed.connect(_show_reset_confirmation)
	%QuitButton.pressed.connect(_show_exit_confirmation)

	%NoticeClose.pressed.connect(func(): _close_modal(%NoticePanel))
	%GalleryClose.pressed.connect(func(): _close_modal(%GalleryPanel))
	%AudioClose.pressed.connect(func(): _close_modal(%AudioPanel))
	_about_close_button.pressed.connect(func(): _close_modal(_about_panel))
	_exit_cancel_button.pressed.connect(func(): _close_modal(_exit_panel))
	_exit_confirm_button.pressed.connect(_confirm_exit)
	_reset_game_cancel_button.pressed.connect(func(): _close_modal(_reset_game_panel))
	_reset_game_confirm_button.pressed.connect(_confirm_reset)
	_device_close_button.pressed.connect(func(): _close_modal(_device_panel))
	_history_close_button.pressed.connect(func(): _close_modal(_history_panel))

	%GlobalSoundCheckBox.toggled.connect(_on_global_sound_toggled)
	%MusicSlider.value_changed.connect(_on_music_changed)
	%SfxSlider.value_changed.connect(_on_sfx_changed)
	%ButtonHoverCheckBox.toggled.connect(_on_button_hover_toggled)
	%ButtonClickCheckBox.toggled.connect(_on_button_click_toggled)
	%MouseClickCheckBox.toggled.connect(_on_mouse_click_toggled)

	%AutosaveLabel.text = "Tersimpan otomatis di perangkat ini"

	for panel_value in [%NoticePanel, %GalleryPanel, %AudioPanel]:
		var panel: Control = panel_value as Control
		if panel != null:
			panel.z_index = 1000

	_refresh_audio_ui()
	_populate_gallery_preview()
	_setup_motion_pilot()

func _bind_scene_authored_modals() -> bool:
	var layer: Control = get_node_or_null("ManualModalLayer") as Control
	if layer == null:
		push_error("70A: MainMenu ManualModalLayer tidak ditemukan.")
		return false

	_modal_mask = layer.get_node_or_null("ModalMask") as ColorRect
	_about_panel = layer.get_node_or_null("AboutModal") as PanelContainer
	_exit_panel = layer.get_node_or_null("ExitConfirmationModal") as PanelContainer
	_reset_game_panel = layer.get_node_or_null("ResetGameModal") as PanelContainer
	_device_panel = layer.get_node_or_null("DeviceModal") as PanelContainer
	_history_panel = layer.get_node_or_null("HistoryModal") as PanelContainer

	if _about_panel != null:
		_about_close_button = _about_panel.find_child("AboutCloseButton", true, false) as Button
	if _exit_panel != null:
		_exit_cancel_button = _exit_panel.find_child("ExitCancelButton", true, false) as Button
		_exit_confirm_button = _exit_panel.find_child("ExitConfirmButton", true, false) as Button
	if _reset_game_panel != null:
		_reset_game_cancel_button = _reset_game_panel.find_child("ResetGameCancelButton", true, false) as Button
		_reset_game_confirm_button = _reset_game_panel.find_child("ResetGameConfirmButton", true, false) as Button
		_reset_game_header = _reset_game_panel.find_child("Header", true, false) as Label
		_reset_game_question = _reset_game_panel.find_child("Question", true, false) as Label
		_reset_game_note = _reset_game_panel.find_child("Note", true, false) as Label
	if _device_panel != null:
		_device_body = _device_panel.find_child("ModalBody", true, false) as VBoxContainer
		_device_close_button = _device_panel.find_child("CloseButton", true, false) as Button
	if _history_panel != null:
		_history_body = _history_panel.find_child("ModalBody", true, false) as VBoxContainer
		_history_close_button = _history_panel.find_child("CloseButton", true, false) as Button

	var required_nodes: Array = [
		_modal_mask,
		_about_panel,
		_about_close_button,
		_exit_panel,
		_exit_cancel_button,
		_exit_confirm_button,
		_reset_game_panel,
		_reset_game_cancel_button,
		_reset_game_confirm_button,
		_reset_game_header,
		_reset_game_question,
		_reset_game_note,
		_device_panel,
		_device_body,
		_device_close_button,
		_history_panel,
		_history_body,
		_history_close_button
	]
	for node_value in required_nodes:
		if node_value == null:
			push_error("70A: Struktur modal MainMenu scene-authored tidak lengkap.")
			return false

	return true

func _setup_motion_pilot() -> void:
	var pilot_buttons: Array = [
		%ContinueButton,
		%NewRunButton,
		%GalleryButton,
		%DeviceButton,
		%HistoryButton,
		%SettingsButton,
		%AboutButton,
		%ResetDataButton,
		%QuitButton
	]

	for button_value in pilot_buttons:
		var button := button_value as BaseButton
		if button != null:
			UIMotion.bind_button(button)

	UIMotion.bind_button(%NoticeClose)
	UIMotion.bind_button(%GalleryClose)
	UIMotion.bind_button(%AudioClose)
	UIMotion.bind_button(_about_close_button)
	UIMotion.bind_button(_exit_cancel_button)
	UIMotion.bind_button(_exit_confirm_button)
	UIMotion.bind_button(_reset_game_cancel_button)
	UIMotion.bind_button(_reset_game_confirm_button)
	UIMotion.bind_button(_device_close_button)
	UIMotion.bind_button(_history_close_button)

func _set_modal_input_state(opened: bool) -> void:
	var safe := get_node_or_null("Safe") as Control
	if safe == null:
		push_error("MainMenu: Safe container tidak ditemukan untuk modal input state.")
		return

	_modal_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if opened:
		safe.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		return

	safe.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED

func _open_modal(panel: Control) -> void:
	_set_modal_input_state(true)
	_modal_mask.visible = true
	panel.visible = true
	UIMotion.play_pop(panel, 1.02)

func _close_modal(panel: Control) -> void:
	panel.visible = false
	_modal_mask.visible = false
	_set_modal_input_state(false)

func _continue_run() -> void:
	if GameState.has_selected_character():
		SceneRouter.goto("main_map")
		return

	SceneRouter.goto("character_select")

func _new_run() -> void:
	if not GameState.has_active_run():
		SceneRouter.goto("player_setup")
		return

	_configure_reset_game_modal(RESET_CONFIRMATION_NEW_RUN)
	_open_modal(_reset_game_panel)

func _show_about() -> void:
	_open_modal(_about_panel)

func _show_notice(text: String) -> void:
	%NoticeText.text = text
	_open_modal(%NoticePanel)

func _show_exit_confirmation() -> void:
	_open_modal(_exit_panel)

func _confirm_exit() -> void:
	get_tree().quit()

func _open_gallery() -> void:
	_build_gallery_lists()
	%GalleryTabs.current_tab = 0
	_open_modal(%GalleryPanel)

func _open_audio_panel() -> void:
	_refresh_audio_ui()
	_open_modal(%AudioPanel)

func _open_device_panel() -> void:
	_populate_device_modal()
	_open_modal(_device_panel)

func _open_history_panel() -> void:
	_populate_history_modal()
	_open_modal(_history_panel)

func _show_reset_confirmation() -> void:
	if not GameState.has_active_run():
		_show_notice("Tidak ada permainan aktif yang dapat direset.")
		return

	_configure_reset_game_modal(RESET_CONFIRMATION_RESET)
	_open_modal(_reset_game_panel)

func _configure_reset_game_modal(mode: String) -> void:
	_reset_confirmation_mode = mode

	if mode == RESET_CONFIRMATION_NEW_RUN:
		_reset_game_header.text = "MULAI PERMAINAN BARU"
		_reset_game_question.text = "Permainan yang sedang berlangsung akan direset. Yakin ingin memulai permainan baru?"
		_reset_game_note.text = "Progress permainan saat ini akan dihapus. Riwayat permainan yang telah ditamatkan tetap tersimpan."
		_reset_game_confirm_button.text = "MULAI BARU"
		return

	_reset_game_header.text = "RESET GAME"
	_reset_game_question.text = "Yakin status permainan saat ini mau di hapus dan diulang?"
	_reset_game_note.text = "Reset game tidak menghapus riwayat permainan yang pernah ditamatkan sebelumnya."
	_reset_game_confirm_button.text = "RESET GAME"

func _confirm_reset() -> void:
	var confirmation_mode: String = _reset_confirmation_mode

	if not GameState.reset_current_run():
		_close_modal(_reset_game_panel)
		_show_notice("Permainan aktif belum dapat direset.")
		return

	if not SaveManager.save_now():
		_close_modal(_reset_game_panel)
		_show_notice("Perubahan reset belum dapat disimpan ke perangkat.")
		return

	_close_modal(_reset_game_panel)

	if confirmation_mode == RESET_CONFIRMATION_NEW_RUN:
		SceneRouter.goto("player_setup")
		return

	get_tree().reload_current_scene()
func _set_mute(value: bool) -> void:
	SettingsManager.set_flag("muted", value)
	AudioManager.apply_settings()
	_refresh_audio_ui()

func _on_global_sound_toggled(enabled: bool) -> void:
	_set_mute(not enabled)

func _on_music_changed(value: float) -> void:
	SettingsManager.set_value("music_volume", value / 100.0)
	AudioManager.apply_settings()
	_refresh_audio_ui()

func _on_sfx_changed(value: float) -> void:
	SettingsManager.set_value("sfx_volume", value / 100.0)
	AudioManager.apply_settings()
	_refresh_audio_ui()

func _on_button_hover_toggled(enabled: bool) -> void:
	SettingsManager.set_flag("button_hover_enabled", enabled)
	_refresh_audio_ui()

func _on_button_click_toggled(enabled: bool) -> void:
	SettingsManager.set_flag("button_click_enabled", enabled)
	_refresh_audio_ui()

func _on_mouse_click_toggled(enabled: bool) -> void:
	SettingsManager.set_flag("mouse_click_enabled", enabled)
	_refresh_audio_ui()

func _refresh_audio_ui() -> void:
	var muted: bool = SettingsManager.get_flag("muted", false)
	var music_value: int = int(round(float(SettingsManager.get_value("music_volume", 0.80)) * 100.0))
	var sfx_value: int = int(round(float(SettingsManager.get_value("sfx_volume", 0.80)) * 100.0))
	var button_hover_enabled: bool = SettingsManager.get_flag("button_hover_enabled", true)
	var button_click_enabled: bool = SettingsManager.get_flag("button_click_enabled", true)
	var mouse_click_enabled: bool = SettingsManager.get_flag("mouse_click_enabled", true)

	%GlobalSoundCheckBox.set_pressed_no_signal(not muted)
	%MusicSlider.set_value_no_signal(music_value)
	%SfxSlider.set_value_no_signal(sfx_value)
	%MusicValue.text = str(music_value) + "%"
	%SfxValue.text = str(sfx_value) + "%"
	%ButtonHoverCheckBox.set_pressed_no_signal(button_hover_enabled)
	%ButtonClickCheckBox.set_pressed_no_signal(button_click_enabled)
	%MouseClickCheckBox.set_pressed_no_signal(mouse_click_enabled)

func _populate_gallery_preview() -> void:
	var fresh_unlocks: Array = GameState.profile.get("gallery_unlocks", [])
	var processed_unlocks: Array = GameState.profile.get("processed_gallery_unlocks", [])
	var medal_count: int = _count_earned_badges()
	var bullet: String = String.chr(0x2022)

	%GalleryPreview.text = (
		"Koleksi terbuka: "
		+ str(fresh_unlocks.size())
		+ " bahan "
		+ bullet
		+ " "
		+ str(processed_unlocks.size())
		+ " olahan "
		+ bullet
		+ " "
		+ str(medal_count)
		+ " medali"
	)

func _build_gallery_lists() -> void:
	_clear_children(%FreshFoodList)
	_clear_children(%ProcessedFoodList)
	_clear_children(_medal_list)

	var fresh_grid: GridContainer = _create_gallery_grid(%FreshFoodList)
	var processed_grid: GridContainer = _create_gallery_grid(%ProcessedFoodList)
	var medal_grid: GridContainer = _create_gallery_grid(_medal_list)

	var fresh_unlocks: Array = GameState.profile.get("gallery_unlocks", [])
	var processed_unlocks: Array = GameState.profile.get("processed_gallery_unlocks", [])
	var badges: Dictionary = GameState.profile.get("badges", {})
	var found_any: bool = false

	%FreshCountLabel.text = "%d bahan ditemukan" % fresh_unlocks.size()
	%ProcessedCountLabel.text = "%d olahan ditemukan" % processed_unlocks.size()

	for food_value in ContentDatabase.master.get("foods", []):
		var food: Dictionary = food_value
		var food_id: String = str(food.get("food_id", ""))

		if food_id in fresh_unlocks:
			found_any = true
			fresh_grid.add_child(
				_make_gallery_card(
					str(food.get("display_name", "Pangan Lokal")),
					"Bahan pangan lokal",
					"Sudah ditemukan",
					"fresh",
					food_id
				)
			)

	for item_value in ContentDatabase.master.get("processed_foods", []):
		var item: Dictionary = item_value
		var item_id: String = str(item.get("processed_food_id", ""))

		if item_id in processed_unlocks:
			found_any = true
			processed_grid.add_child(
				_make_gallery_card(
					str(item.get("display_name", "Olahan Pangan")),
					"Pangan olahan",
					"Sudah ditemukan",
					"processed",
					item_id
				)
			)

	if fresh_grid.get_child_count() == 0:
		_clear_children(%FreshFoodList)
		%FreshFoodList.add_child(
			_make_empty_card(
				"Belum ada bahan pangan yang terbuka. Selesaikan misi untuk menambah koleksi."
			)
		)

	if processed_grid.get_child_count() == 0:
		_clear_children(%ProcessedFoodList)
		%ProcessedFoodList.add_child(
			_make_empty_card(
				"Belum ada pangan olahan yang terbuka. Lanjutkan permainan hingga misi dapur dan festival."
			)
		)

	var earned_badges: Array[Dictionary] = []

	for badge_id_value in badges.keys():
		var badge_id: String = str(badge_id_value)
		var badge: Dictionary = badges.get(badge_id, {})

		if bool(badge.get("earned", false)):
			earned_badges.append({
				"badge_id": badge_id,
				"display_name": str(badge.get("display_name", "Medali"))
			})

	earned_badges.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("display_name", "")) < str(b.get("display_name", ""))
	)

	_medal_count_label.text = "%d medali diperoleh" % earned_badges.size()

	for badge in earned_badges:
		found_any = true
		medal_grid.add_child(
			_make_gallery_card(
				str(badge.get("display_name", "Medali")),
				"Medali pencapaian",
				"Sudah diperoleh",
				"badge",
				str(badge.get("badge_id", ""))
			)
		)

	if medal_grid.get_child_count() == 0:
		_clear_children(_medal_list)
		_medal_list.add_child(
			_make_empty_card(
				"Belum ada medali. Medali diperoleh setelah kamu menyelesaikan pencapaian penting."
			)
		)

	%GalleryEmptyState.visible = not found_any
	%GalleryTabs.visible = found_any
	_populate_gallery_preview()

func _populate_device_modal() -> void:
	_clear_runtime_children(_device_body)
	var snapshot: Dictionary = DeviceProfileManager.capture_snapshot()
	var availability: Dictionary = snapshot.get("availability", {})

	_add_information_section(_device_body, "IDENTITAS INSTALASI", [
		["Installation ID", SaveManager.get_installation_id()],
		["Sumber profil", snapshot.get("profile_source", null)],
		["Jenis perangkat", _device_field_value(snapshot.get("device_type", null), availability, "device_type")],
		["Platform", snapshot.get("platform", null)],
		["Produsen", _device_field_value(snapshot.get("manufacturer", null), availability, "manufacturer")],
		["Model", snapshot.get("model", null)]
	])
	_add_information_section(
		_device_body,
		"SISTEM OPERASI",
		_device_dictionary_rows(
			snapshot.get("os", {}),
			{
				"name": "Nama OS",
				"edition": "Edisi",
				"version": "Versi",
				"build_number": "Build",
				"architecture": "Arsitektur"
			},
			availability,
			"os"
		)
	)
	_add_information_section(
		_device_body,
		"PROSESOR",
		_device_dictionary_rows(
			snapshot.get("cpu", {}),
			{
				"architecture": "Arsitektur",
				"processor_name": "Nama prosesor",
				"logical_core_count": "Logical core"
			},
			availability,
			"cpu"
		)
	)
	_add_information_section(
		_device_body,
		"MEMORI",
		_device_dictionary_rows(
			snapshot.get("memory", {}),
			{
				"physical_memory_mb": "Memori fisik (MB)",
				"free_memory_mb": "Memori bebas fisik (MB)",
				"available_memory_mb": "Memori tersedia (MB)",
				"used_physical_memory_mb": "Memori fisik terpakai (MB)"
			},
			availability,
			"memory"
		)
	)
	_add_information_section(
		_device_body,
		"GRAFIS",
		_device_dictionary_rows(
			snapshot.get("graphics", {}),
			{
				"renderer": "Renderer",
				"rendering_method": "Rendering method",
				"gpu_name": "GPU",
				"gpu_vendor": "Vendor GPU",
				"driver_name": "Driver",
				"driver_version": "Versi driver",
				"api_version": "Versi API grafis"
			},
			availability,
			"graphics"
		)
	)
	_add_information_section(
		_device_body,
		"LAYAR",
		_device_dictionary_rows(
			snapshot.get("display", {}),
			{
				"physical_width_px": "Lebar layar fisik",
				"physical_height_px": "Tinggi layar fisik",
				"game_viewport_width": "Lebar viewport game",
				"game_viewport_height": "Tinggi viewport game",
				"dpi": "DPI",
				"scale": "Scale",
				"refresh_rate_hz": "Refresh rate (Hz)",
				"orientation": "Orientasi"
			},
			availability,
			"display"
		)
	)
	_add_information_section(
		_device_body,
		"INPUT",
		_device_dictionary_rows(
			snapshot.get("input_capabilities", {}),
			{
				"touch": "Touch",
				"mouse": "Mouse",
				"keyboard": "Keyboard",
				"gamepad": "Gamepad"
			},
			availability,
			"input_capabilities"
		)
	)
	_add_information_section(
		_device_body,
		"LOKALISASI",
		_device_dictionary_rows(
			snapshot.get("locale", {}),
			{
				"language": "Bahasa",
				"locale": "Locale",
				"timezone": "Zona waktu"
			},
			availability,
			"locale"
		)
	)
	_add_information_section(
		_device_body,
		"JARINGAN",
		_device_dictionary_rows(
			snapshot.get("network", {}),
			{
				"online": "Online",
				"connection_type": "Jenis koneksi",
				"adapter_name": "Adapter aktif",
				"link_speed": "Kecepatan link",
				"server_seen_ip": "IP yang terlihat server"
			},
			availability,
			"network"
		)
	)
	_add_information_section(
		_device_body,
		"BATERAI",
		_device_dictionary_rows(
			snapshot.get("battery", {}),
			{
				"battery_level": "Level baterai (%)",
				"charging": "Sedang mengisi daya"
			},
			availability,
			"battery"
		)
	)

func _device_dictionary_rows(
	source_value: Variant,
	labels: Dictionary,
	availability: Dictionary,
	prefix: String
) -> Array:
	var rows: Array = []
	var source: Dictionary = {}

	if source_value is Dictionary:
		source = source_value

	for key_value in labels.keys():
		var key: String = str(key_value)
		var field_path: String = prefix + "." + key
		rows.append([
			str(labels.get(key, key)),
			_device_field_value(source.get(key, null), availability, field_path)
		])

	return rows

func _device_field_value(
	value: Variant,
	availability: Dictionary,
	field_path: String
) -> Variant:
	if value != null:
		return value

	var reason: String = str(availability.get(field_path, "")).strip_edges()

	if reason == "server_only":
		return "Menunggu sinkronisasi server"

	if reason == "no_battery_device":
		return "Tidak ada baterai pada perangkat"

	if reason == "windows_provider_unavailable":
		return "Provider Windows tidak tersedia"

	if reason == "android_runtime_provider_pending":
		return "Menunggu provider runtime Android"

	if reason == "not_supported_on_platform":
		return "Tidak didukung pada platform ini"

	if reason == "not_detected_or_not_supported":
		return "Tidak terdeteksi / tidak didukung"

	if reason == "not_reported":
		return "Tidak dilaporkan oleh sistem"

	if reason == "provider_unavailable":
		return "Provider sistem tidak tersedia"

	return "Belum tersedia"

func _populate_history_modal() -> void:
	_clear_runtime_children(_history_body)
	var history_items: Array = []
	var history_value: Variant = GameState.profile.get("completed_run_history", [])
	if history_value is Array:
		var source_history: Array = history_value
		history_items = source_history.duplicate(true)
	if history_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Belum ada permainan yang ditamatkan. Riwayat akan muncul setelah Level 1 sampai Level 5 selesai."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.36, 0.36, 0.28, 1))
		empty_label.add_theme_font_size_override("font_size", 18)
		_history_body.add_child(empty_label)
		return

	history_items.reverse()
	var display_no: int = 1
	for record_value in history_items:
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		_history_body.add_child(_make_history_card(record, display_no))
		display_no += 1

func _make_history_card(record: Dictionary, display_no: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.97, 0.91, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.48, 0.40, 0.24, 0.32)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	var title := Label.new()
	title.text = "PERJALANAN %d • %s" % [display_no, _format_history_datetime(record.get("completed_at", null))]
	title.add_theme_color_override("font_color", Color(0.18, 0.31, 0.12, 1))
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	var player_name: String = str(record.get("player_name", "")).strip_edges()
	var character_name: String = str(record.get("selected_character_display_name", "")).strip_edges()
	if player_name.is_empty():
		player_name = "Belum tersedia"
	if character_name.is_empty():
		character_name = "Belum tersedia"

	var total_duration_ms: int = 0
	var durations: Dictionary = record.get("level_durations_ms", {})
	for level_no in range(1, 6):
		total_duration_ms += int(durations.get(str(level_no), 0))

	var summary := Label.new()
	summary.text = "Pemain: %s\nKarakter: %s\nDurasi total: %s" % [player_name, character_name, _format_duration_ms(total_duration_ms)]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", Color(0.28, 0.28, 0.22, 1))
	summary.add_theme_font_size_override("font_size", 16)
	column.add_child(summary)

	var scores: Dictionary = record.get("level_scores", {})
	var stars: Dictionary = record.get("stars_by_level", {})
	var level_lines: PackedStringArray = PackedStringArray()
	for level_no in range(1, 6):
		var key: String = str(level_no)
		level_lines.append(
			"Level %d: skor %d • %d bintang • %s" % [
				level_no,
				int(scores.get(key, 0)),
				int(stars.get(key, 0)),
				_format_duration_ms(int(durations.get(key, 0)))
			]
		)

	var details := Label.new()
	details.text = "\n".join(level_lines)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_color_override("font_color", Color(0.36, 0.36, 0.28, 1))
	details.add_theme_font_size_override("font_size", 15)
	column.add_child(details)
	return panel

func _dictionary_rows(source_value: Variant, labels: Dictionary) -> Array:
	var rows: Array = []
	var source: Dictionary = {}
	if source_value is Dictionary:
		source = source_value
	for key_value in labels.keys():
		var key: String = str(key_value)
		rows.append([str(labels.get(key, key)), source.get(key, null)])
	return rows

func _add_information_section(parent: VBoxContainer, title_text: String, rows: Array) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", Color(0.55, 0.38, 0.08, 1))
	title.add_theme_font_size_override("font_size", 18)
	parent.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)

	for row_value in rows:
		if not (row_value is Array):
			continue
		var row: Array = row_value
		if row.size() < 2:
			continue
		var key_label := Label.new()
		key_label.text = str(row[0])
		key_label.custom_minimum_size = Vector2(230, 0)
		key_label.add_theme_color_override("font_color", Color(0.36, 0.36, 0.28, 1))
		key_label.add_theme_font_size_override("font_size", 15)
		grid.add_child(key_label)

		var value_label := Label.new()
		value_label.text = _display_optional_value(row[1])
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.add_theme_color_override("font_color", Color(0.20, 0.20, 0.16, 1))
		value_label.add_theme_font_size_override("font_size", 15)
		grid.add_child(value_label)

	var separator := HSeparator.new()
	parent.add_child(separator)

func _display_optional_value(value: Variant) -> String:
	if value == null:
		return "Belum tersedia"
	if value is bool:
		return "Ya" if bool(value) else "Tidak"
	var text_value: String = str(value).strip_edges()
	if text_value.is_empty():
		return "Belum tersedia"
	return text_value

func _format_duration_ms(duration_ms: int) -> String:
	var total_seconds: int = maxi(0, int(duration_ms / 1000.0))
	var hours: int = int(total_seconds / 3600.0)
	var minutes: int = int((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, seconds]
	return "%02d:%02d" % [minutes, seconds]

func _format_history_datetime(value: Variant) -> String:
	if value == null:
		return "Waktu belum tersedia"
	var unix_time: int = int(float(value))
	if unix_time <= 0:
		return "Waktu belum tersedia"
	return Time.get_datetime_string_from_unix_time(unix_time, true)

func _clear_runtime_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _count_earned_badges() -> int:
	var badges: Dictionary = GameState.profile.get("badges", {})
	var total: int = 0

	for badge_id_value in badges.keys():
		var badge_id: String = str(badge_id_value)
		var badge: Dictionary = badges.get(badge_id, {})

		if bool(badge.get("earned", false)):
			total += 1

	return total

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _create_gallery_grid(host: VBoxContainer) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	host.add_child(grid)
	return grid

func _make_gallery_card(
	title: String,
	subtitle: String,
	state_text: String,
	entry_kind: String,
	entry_id: String
) -> Control:
	var palette: Dictionary = _gallery_palette(entry_kind)

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 136)

	var style := StyleBoxFlat.new()
	style.bg_color = palette.get("panel")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = palette.get("border")
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	row.add_child(_make_gallery_thumbnail(entry_kind, entry_id, palette))

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 6)
	row.add_child(content)

	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_color_override("font_color", palette.get("title"))
	title_label.add_theme_font_size_override("font_size", 19)
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = subtitle
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override("font_color", Color(0.37, 0.39, 0.30, 1))
	subtitle_label.add_theme_font_size_override("font_size", 14)
	content.add_child(subtitle_label)

	content.add_child(_make_gallery_state_chip(state_text, palette))

	return panel

func _gallery_palette(entry_kind: String) -> Dictionary:
	match entry_kind:
		"badge":
			return {
				"panel": Color(1.00, 0.97, 0.88, 0.98),
				"border": Color(0.78, 0.61, 0.16, 0.52),
				"thumb": Color(1.00, 0.93, 0.68, 0.98),
				"title": Color(0.54, 0.36, 0.05, 1),
				"chip_bg": Color(0.97, 0.84, 0.39, 0.96),
				"chip_border": Color(0.80, 0.61, 0.08, 0.48),
				"chip_text": Color(0.47, 0.31, 0.04, 1)
			}
		"processed":
			return {
				"panel": Color(1.00, 0.96, 0.92, 0.98),
				"border": Color(0.78, 0.55, 0.30, 0.46),
				"thumb": Color(1.00, 0.90, 0.78, 0.98),
				"title": Color(0.34, 0.40, 0.23, 1),
				"chip_bg": Color(0.98, 0.86, 0.72, 0.96),
				"chip_border": Color(0.78, 0.55, 0.30, 0.38),
				"chip_text": Color(0.46, 0.26, 0.12, 1)
			}
		_:
			return {
				"panel": Color(0.95, 0.98, 0.91, 0.98),
				"border": Color(0.46, 0.60, 0.27, 0.44),
				"thumb": Color(0.88, 0.95, 0.78, 0.98),
				"title": Color(0.22, 0.38, 0.14, 1),
				"chip_bg": Color(0.84, 0.94, 0.72, 0.96),
				"chip_border": Color(0.46, 0.60, 0.27, 0.34),
				"chip_text": Color(0.25, 0.41, 0.15, 1)
			}

func _make_gallery_thumbnail(entry_kind: String, entry_id: String, palette: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(96, 96)

	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = palette.get("thumb")
	frame_style.border_width_left = 1
	frame_style.border_width_top = 1
	frame_style.border_width_right = 1
	frame_style.border_width_bottom = 1
	frame_style.border_color = palette.get("border")
	frame_style.corner_radius_top_left = 12
	frame_style.corner_radius_top_right = 12
	frame_style.corner_radius_bottom_right = 12
	frame_style.corner_radius_bottom_left = 12
	frame.add_theme_stylebox_override("panel", frame_style)

	var center := CenterContainer.new()
	frame.add_child(center)

	if entry_kind == "fresh":
		var glyph := FoodGlyph.new()
		glyph.custom_minimum_size = Vector2(78, 78)
		glyph.food_id = entry_id
		center.add_child(glyph)
		return frame

	var texture_path: String = _resolve_gallery_texture_path(entry_kind, entry_id)
	var texture: Texture2D = _load_texture_or_null(texture_path)

	if texture != null:
		var texture_rect := TextureRect.new()
		texture_rect.texture = texture
		texture_rect.custom_minimum_size = Vector2(78, 78)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		center.add_child(texture_rect)
		return frame

	var fallback := Label.new()
	fallback.text = "MEDALI" if entry_kind == "badge" else "OLAHAN"
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fallback.custom_minimum_size = Vector2(76, 76)
	fallback.add_theme_color_override("font_color", palette.get("title"))
	fallback.add_theme_font_size_override("font_size", 13)
	center.add_child(fallback)
	return frame

func _make_gallery_state_chip(state_text: String, palette: Dictionary) -> Control:
	var chip := PanelContainer.new()

	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = palette.get("chip_bg")
	chip_style.border_width_left = 1
	chip_style.border_width_top = 1
	chip_style.border_width_right = 1
	chip_style.border_width_bottom = 1
	chip_style.border_color = palette.get("chip_border")
	chip_style.corner_radius_top_left = 999
	chip_style.corner_radius_top_right = 999
	chip_style.corner_radius_bottom_right = 999
	chip_style.corner_radius_bottom_left = 999
	chip_style.content_margin_left = 10.0
	chip_style.content_margin_top = 5.0
	chip_style.content_margin_right = 10.0
	chip_style.content_margin_bottom = 5.0
	chip.add_theme_stylebox_override("panel", chip_style)

	var label := Label.new()
	label.text = state_text
	label.add_theme_color_override("font_color", palette.get("chip_text"))
	label.add_theme_font_size_override("font_size", 13)
	chip.add_child(label)
	return chip

func _resolve_gallery_texture_path(entry_kind: String, entry_id: String) -> String:
	if entry_kind == "processed":
		return str(PROCESSED_FOOD_TEXTURE_PATHS.get(entry_id, ""))
	if entry_kind == "badge":
		return str(BADGE_TEXTURE_PATHS.get(entry_id, ""))
	return ""

func _load_texture_or_null(texture_path: String) -> Texture2D:
	if texture_path.is_empty():
		return null
	if not ResourceLoader.exists(texture_path):
		return null

	var resource: Resource = load(texture_path)
	if resource is Texture2D:
		return resource
	return null

func _make_empty_card(message: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 118)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.98, 0.96, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.48, 0.40, 0.24, 0.28)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.36, 0.37, 0.28, 1))
	label.add_theme_font_size_override("font_size", 14)
	margin.add_child(label)

	return panel
