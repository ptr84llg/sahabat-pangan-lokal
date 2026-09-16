extends Control

const HISTORY_VIEW_BUILDER_SCRIPT := preload("res://scripts/app/history_view_builder.gd")
const TITLE_UNLOCK_MODAL_SCENE: PackedScene = preload("res://scenes/shared/achievement/title_unlock_modal.tscn")

const GALLERY_PALETTE_CONFIG_PATH := "res://resources/config/gallery_palette_config.tres"
const GALLERY_GRID_SCENE: PackedScene = preload(
	"res://scenes/shared/ui/main_menu/gallery_grid.tscn"
)
const GALLERY_CARD_SCENE: PackedScene = preload(
	"res://scenes/shared/ui/main_menu/gallery_card.tscn"
)
const GALLERY_TITLE_CARD_SCENE: PackedScene = preload(
	"res://scenes/shared/ui/main_menu/gallery_title_card.tscn"
)
const GALLERY_EMPTY_CARD_SCENE: PackedScene = preload(
	"res://scenes/shared/ui/main_menu/gallery_empty_card.tscn"
)
const INFORMATION_SECTION_SCENE: PackedScene = preload(
	"res://scenes/shared/ui/main_menu/information_section.tscn"
)
const INFORMATION_ROW_SCENE: PackedScene = preload(
	"res://scenes/shared/ui/main_menu/information_row.tscn"
)

const RESET_CONFIRMATION_RESET := "reset"
const RESET_CONFIRMATION_NEW_RUN := "new_run"

var _modal_mask: ColorRect
var _medal_count_label: Label
var _medal_list: VBoxContainer
var _title_count_label: Label
var _title_list: VBoxContainer
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
var _history_view_builder: RefCounted
var _title_unlock_modal: TitleUnlockModal
var _pending_title_notifications: Array[Dictionary] = []

var _gallery_palette_config: GalleryPaletteConfig

func _ready() -> void:
	if not _bind_scene_authored_modals():
		return

	if not _load_gallery_palette_config():
		return

	_medal_count_label = %MedalCountLabel
	_medal_list = %MedalList
	_title_count_label = %TitleCountLabel
	_title_list = %TitleList

	%ContinueButton.visible = GameState.has_active_run()
	%ResetDataButton.visible = GameState.has_active_run()
	%ResetDataButton.text = "RESET GAME"

	%ContinueButton.pressed.connect(_continue_run)
	%NewRunButton.pressed.connect(_new_run)
	%GalleryButton.pressed.connect(_open_gallery)
	%AchievementProgressButton.pressed.connect(_open_title_gallery)
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
	%GalleryTabs.tab_changed.connect(_on_gallery_tab_changed)

	%AutosaveLabel.text = "Tersimpan otomatis di perangkat ini"

	for panel_value in [%NoticePanel, %GalleryPanel, %AudioPanel]:
		var panel: Control = panel_value as Control
		if panel != null:
			panel.z_index = 1000

	_refresh_audio_ui()
	_populate_gallery_preview()
	_refresh_achievement_progress_card()
	_setup_motion_presenter()
	_schedule_title_unlock_notifications()

func _load_gallery_palette_config() -> bool:
	var loaded := load(GALLERY_PALETTE_CONFIG_PATH)

	if not loaded is GalleryPaletteConfig:
		push_error("GalleryPaletteConfig tidak dapat dimuat.")
		return false

	_gallery_palette_config = loaded as GalleryPaletteConfig
	return true


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

func _setup_motion_presenter() -> void:
	ScreenMotionPresenter.bind_buttons([
		%ContinueButton,
		%NewRunButton,
		%GalleryButton,
		%AchievementProgressButton,
		%DeviceButton,
		%HistoryButton,
		%SettingsButton,
		%AboutButton,
		%ResetDataButton,
		%QuitButton,
		%NoticeClose,
		%GalleryClose,
		%AudioClose,
		_about_close_button,
		_exit_cancel_button,
		_exit_confirm_button,
		_reset_game_cancel_button,
		_reset_game_confirm_button,
		_device_close_button,
		_history_close_button
	])

	var menu_panel := get_node_or_null(
		"Safe/HBox/MenuPanel"
	) as Control
	var logo := get_node_or_null(
		"Safe/HBox/Brand/GameLogo"
	) as Control
	var description := get_node_or_null(
		"Safe/HBox/Brand/Desc"
	) as Control

	ScreenMotionPresenter.main_menu_entrance(
		menu_panel,
		logo,
		[
			description,
			%GalleryPreview,
			%AutosaveLabel
		]
	)

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
	ScreenMotionPresenter.open_modal(
		panel,
		_modal_mask
	)

func _close_modal(panel: Control) -> void:
	ScreenMotionPresenter.close_modal(
		panel,
		_modal_mask,
		func(): _set_modal_input_state(false)
	)

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

func _refresh_achievement_progress_card() -> void:
	var earned: int = AchievementManager.earned_count()
	var total: int = AchievementManager.total_count()
	var remaining: int = maxi(0, total - earned)

	%AchievementProgressBar.max_value = maxf(1.0, float(total))
	%AchievementProgressBar.value = float(earned)

	if total <= 0:
		%AchievementProgressButton.text = "GELAR BELUM TERSEDIA"
		return

	if remaining <= 0:
		%AchievementProgressButton.text = (
			"%d/%d GELAR DIRAIH\n"
			+ "SEMUA GELAR BERHASIL DIKUMPULKAN!"
		) % [earned, total]
		return

	%AchievementProgressButton.text = (
		"%d/%d GELAR DIRAIH\n"
		+ "%d GELAR LAGI MENUNGGUMU!"
	) % [earned, total, remaining]


func _open_title_gallery() -> void:
	_build_gallery_lists()
	%GalleryTabs.current_tab = 3
	_open_modal(%GalleryPanel)
	_reveal_gallery_tab(3)


func _schedule_title_unlock_notifications() -> void:
	_pending_title_notifications = (
		AchievementManager.pending_title_notifications(
			"main_menu"
		)
	)

	if _pending_title_notifications.is_empty():
		return

	var timer := get_tree().create_timer(0.40)
	timer.timeout.connect(
		_show_title_notifications,
		CONNECT_ONE_SHOT
	)


func _show_title_notifications() -> void:
	if _pending_title_notifications.is_empty():
		_refresh_achievement_progress_card()
		_populate_gallery_preview()
		return

	if not is_instance_valid(_title_unlock_modal):
		var modal_node := TITLE_UNLOCK_MODAL_SCENE.instantiate()
		var modal := modal_node as TitleUnlockModal

		if modal == null:
			push_error("MainMenu gagal membuat TitleUnlockModal.")
			return

		modal.name = "MainMenuTitleUnlockModal"
		modal.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		modal.z_index = 2400
		add_child(modal)
		_title_unlock_modal = modal
		_title_unlock_modal.dismissed.connect(
			_on_main_menu_title_dismissed
		)

	_title_unlock_modal.present_titles(
		_pending_title_notifications
	)


func _on_main_menu_title_dismissed(
	title_ids: Array
) -> void:
	AchievementManager.acknowledge_title_notifications(
		title_ids
	)
	_pending_title_notifications.clear()
	_refresh_achievement_progress_card()
	_populate_gallery_preview()

func _open_gallery() -> void:
	_build_gallery_lists()
	%GalleryTabs.current_tab = 0
	_open_modal(%GalleryPanel)
	_reveal_gallery_tab(0)


func _on_gallery_tab_changed(tab_index: int) -> void:
	if not %GalleryPanel.visible:
		return

	_reveal_gallery_tab(tab_index)


func _reveal_gallery_tab(tab_index: int) -> void:
	if not %GalleryPanel.visible:
		return

	var items: Array = _gallery_reveal_items_for_tab(
		tab_index
	)

	ScreenMotionPresenter.collection_reveal(items)


func _gallery_reveal_items_for_tab(
	tab_index: int
) -> Array:
	var host: Node = null

	match tab_index:
		0:
			host = %FreshFoodList
		1:
			host = %ProcessedFoodList
		2:
			host = _medal_list
		3:
			host = _title_list
		_:
			return []

	var items: Array = []

	for child_value in host.get_children():
		var child := child_value as Node

		if child == null:
			continue

		if child is GridContainer:
			for item_value in child.get_children():
				var item := item_value as Control

				if item != null and item.visible:
					items.append(item)

			continue

		var direct_item := child as Control

		if direct_item != null and direct_item.visible:
			items.append(direct_item)

	return items


func _open_audio_panel() -> void:
	_refresh_audio_ui()
	_open_modal(%AudioPanel)

func _open_device_panel() -> void:
	_populate_device_modal()
	_open_modal(_device_panel)

func _open_history_panel() -> void:
	_populate_history_modal()
	_open_modal(_history_panel)
	_reveal_history_items()


func _reveal_history_items() -> void:
	if not _history_panel.visible:
		return

	var items: Array = []
	var intro_note := _history_body.get_node_or_null(
		"HistoryIntroNote"
	) as Control
	var state_label := _history_body.get_node_or_null(
		"HistoryStateLabel"
	) as Control
	var cards_host := _history_body.get_node_or_null(
		"HistoryCardsHost"
	) as Node

	if intro_note != null and intro_note.visible:
		items.append(intro_note)

	if state_label != null and state_label.visible:
		items.append(state_label)

	if cards_host != null:
		for card_value in cards_host.get_children():
			var card := card_value as Control

			if card != null and card.visible:
				items.append(card)

	ScreenMotionPresenter.collection_reveal(items)


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
	var fresh_unlocks: Array = GameState.gallery_unlocks_for_menu()
	var processed_unlocks: Array = GameState.processed_gallery_unlocks_for_menu()
	var medal_count: int = _count_earned_badges()
	var title_count: int = AchievementManager.earned_count()
	var bullet: String = String.chr(0x2022)

	%GalleryPreview.text = (
		"Koleksi perjalanan: "
		+ str(fresh_unlocks.size())
		+ " bahan "
		+ bullet
		+ " "
		+ str(processed_unlocks.size())
		+ " olahan "
		+ bullet
		+ " "
		+ str(medal_count)
		+ " medali "
		+ bullet
		+ " "
		+ str(title_count)
		+ " gelar"
	)

func _build_gallery_lists() -> void:
	_clear_children(%FreshFoodList)
	_clear_children(%ProcessedFoodList)
	_clear_children(_medal_list)
	_clear_children(_title_list)

	var fresh_grid: GridContainer = _create_gallery_grid(%FreshFoodList)
	var processed_grid: GridContainer = _create_gallery_grid(%ProcessedFoodList)
	var medal_grid: GridContainer = _create_gallery_grid(_medal_list)
	var title_grid: GridContainer = _create_gallery_grid(_title_list)

	var fresh_unlocks: Array = GameState.gallery_unlocks_for_menu()
	var processed_unlocks: Array = GameState.processed_gallery_unlocks_for_menu()
	var badges: Dictionary = GameState.badges_for_menu()
	var title_entries: Array[Dictionary] = AchievementManager.title_entries()

	%FreshCountLabel.text = "%d bahan ditemukan" % fresh_unlocks.size()
	%ProcessedCountLabel.text = "%d olahan ditemukan" % processed_unlocks.size()

	for food_value in ContentDatabase.master.get("foods", []):
		var food: Dictionary = food_value
		var food_id: String = str(food.get("food_id", ""))

		if food_id in fresh_unlocks:
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
				"Belum ada bahan pangan pada perjalanan saat ini. Selesaikan misi untuk membuka koleksi."
			)
		)

	if processed_grid.get_child_count() == 0:
		_clear_children(%ProcessedFoodList)
		%ProcessedFoodList.add_child(
			_make_empty_card(
				"Belum ada pangan olahan pada perjalanan saat ini. Lanjutkan hingga misi dapur dan festival."
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
		medal_grid.add_child(
			_make_gallery_card(
				str(badge.get("display_name", "Medali")),
				"Medali perjalanan saat ini",
				"Sudah diperoleh",
				"badge",
				str(badge.get("badge_id", ""))
			)
		)

	if medal_grid.get_child_count() == 0:
		_clear_children(_medal_list)
		_medal_list.add_child(
			_make_empty_card(
				"Belum ada medali pada perjalanan saat ini."
			)
		)

	var earned_title_count: int = 0

	for entry in title_entries:
		var earned: bool = bool(entry.get("earned", false))

		if earned:
			earned_title_count += 1

		title_grid.add_child(
			_make_gallery_card(
				str(entry.get("display_name", "Gelar")),
				str(entry.get("requirement_text", "")),
				"SUDAH DIPEROLEH" if earned else "BELUM DIPEROLEH",
				"title_earned" if earned else "title_locked",
				str(entry.get("title_id", ""))
			)
		)

	_title_count_label.text = (
		"%d/%d gelar diperoleh"
		% [
			earned_title_count,
			title_entries.size()
		]
	)

	if title_grid.get_child_count() == 0:
		_clear_children(_title_list)
		_title_list.add_child(
			_make_empty_card(
				"Daftar gelar belum tersedia."
			)
		)

	%GalleryEmptyState.visible = false
	%GalleryTabs.visible = true
	_populate_gallery_preview()

func _populate_device_modal() -> void:
	_clear_runtime_children(_device_body)
	var snapshot: Dictionary = DeviceProfileManager.get_cached_snapshot()
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
	if _history_view_builder == null:
		_history_view_builder = HISTORY_VIEW_BUILDER_SCRIPT.new()

	_history_view_builder.call(
		"populate",
		_history_body
	)

func _dictionary_rows(source_value: Variant, labels: Dictionary) -> Array:
	var rows: Array = []
	var source: Dictionary = {}
	if source_value is Dictionary:
		source = source_value
	for key_value in labels.keys():
		var key: String = str(key_value)
		rows.append([str(labels.get(key, key)), source.get(key, null)])
	return rows

func _add_information_section(
	parent: VBoxContainer,
	title_text: String,
	rows: Array
) -> void:
	var section := INFORMATION_SECTION_SCENE.instantiate() as VBoxContainer

	if section == null:
		push_error("InformationSection scene root harus VBoxContainer.")
		return

	parent.add_child(section)
	var title := section.get_node("SectionTitle") as Label
	var rows_host := section.get_node("Rows") as VBoxContainer

	if title == null or rows_host == null:
		push_error("InformationSection scene-authored structure tidak lengkap.")
		section.queue_free()
		return

	title.text = title_text

	for row_value in rows:
		if not row_value is Array:
			continue

		var row: Array = row_value

		if row.size() < 2:
			continue

		var row_control := (
			INFORMATION_ROW_SCENE.instantiate()
			as HBoxContainer
		)

		if row_control == null:
			push_error("InformationRow scene root harus HBoxContainer.")
			continue

		rows_host.add_child(row_control)
		var key_label := row_control.get_node("KeyLabel") as Label
		var value_label := row_control.get_node("ValueLabel") as Label

		if key_label == null or value_label == null:
			push_error("InformationRow scene-authored structure tidak lengkap.")
			row_control.queue_free()
			continue

		key_label.text = str(row[0])
		value_label.text = _display_optional_value(row[1])

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
	return GameState.badges_for_menu().size()

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _create_gallery_grid(host: VBoxContainer) -> GridContainer:
	var grid := GALLERY_GRID_SCENE.instantiate() as GridContainer

	if grid == null:
		push_error("GalleryGrid scene root harus GridContainer.")
		return null

	host.add_child(grid)
	return grid

func _make_gallery_card(
	title: String,
	subtitle: String,
	state_text: String,
	entry_kind: String,
	entry_id: String
) -> Control:
	var scene := (
		GALLERY_TITLE_CARD_SCENE
		if entry_kind.begins_with("title_")
		else GALLERY_CARD_SCENE
	)
	var panel := scene.instantiate() as PanelContainer

	if panel == null:
		push_error("GalleryCard scene root harus PanelContainer.")
		return null

	var title_label := panel.get_node(
		"Margin/Row/Content/TitleLabel"
	) as Label
	var subtitle_label := panel.get_node(
		"Margin/Row/Content/SubtitleLabel"
	) as Label
	var thumbnail_frame := panel.get_node(
		"Margin/Row/ThumbnailFrame"
	) as PanelContainer
	var glyph := panel.get_node(
		"Margin/Row/ThumbnailFrame/ThumbnailCenter/FoodGlyph"
	) as FoodGlyph
	var texture_rect := panel.get_node(
		"Margin/Row/ThumbnailFrame/ThumbnailCenter/ThumbnailTexture"
	) as TextureRect
	var fallback := panel.get_node(
		"Margin/Row/ThumbnailFrame/ThumbnailCenter/ThumbnailFallback"
	) as Label
	var state_chip := panel.get_node(
		"Margin/Row/Content/StateChip"
	) as PanelContainer
	var state_label := panel.get_node(
		"Margin/Row/Content/StateChip/StateLabel"
	) as Label

	if (
		title_label == null
		or subtitle_label == null
		or thumbnail_frame == null
		or glyph == null
		or texture_rect == null
		or fallback == null
		or state_chip == null
		or state_label == null
	):
		push_error("GalleryCard scene-authored structure tidak lengkap.")
		panel.queue_free()
		return null

	var palette: Dictionary = _gallery_palette(entry_kind)
	_apply_gallery_palette(
		panel,
		thumbnail_frame,
		title_label,
		state_chip,
		state_label,
		fallback,
		palette
	)

	title_label.text = title
	subtitle_label.text = subtitle
	state_label.text = state_text
	glyph.visible = false
	texture_rect.visible = false
	fallback.visible = false

	if entry_kind == "fresh":
		glyph.food_id = entry_id
		glyph.visible = true
		return panel

	var texture_path: String = _resolve_gallery_texture_path(
		entry_kind,
		entry_id
	)
	var texture: Texture2D = _load_texture_or_null(texture_path)

	if texture != null:
		texture_rect.texture = texture
		texture_rect.visible = true

		if entry_kind.begins_with("title_"):
			texture_rect.modulate = AchievementManager.icon_modulate_for(
				entry_kind == "title_earned"
			)

		return panel

	fallback.text = (
		"MEDALI"
		if entry_kind == "badge"
		else (
			"GELAR"
			if entry_kind.begins_with("title_")
			else "OLAHAN"
		)
	)
	fallback.visible = true
	return panel

func _gallery_palette(entry_kind: String) -> Dictionary:
	if entry_kind == "title_earned":
		return AchievementManager.gallery_palette_for(true)

	if entry_kind == "title_locked":
		return AchievementManager.gallery_palette_for(false)

	if _gallery_palette_config == null:
		return {}

	return _gallery_palette_config.palette_for(entry_kind)

func _apply_gallery_palette(
	panel: PanelContainer,
	thumbnail_frame: PanelContainer,
	title_label: Label,
	state_chip: PanelContainer,
	state_label: Label,
	fallback: Label,
	palette: Dictionary
) -> void:
	var panel_style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	var thumbnail_style := (
		thumbnail_frame.get_theme_stylebox("panel")
		as StyleBoxFlat
	)
	var chip_style := state_chip.get_theme_stylebox("panel") as StyleBoxFlat

	if panel_style != null:
		panel_style = panel_style.duplicate() as StyleBoxFlat
		panel_style.bg_color = palette.get(
			"panel",
			panel_style.bg_color
		)
		panel_style.border_color = palette.get(
			"border",
			panel_style.border_color
		)
		panel.add_theme_stylebox_override("panel", panel_style)

	if thumbnail_style != null:
		thumbnail_style = thumbnail_style.duplicate() as StyleBoxFlat
		thumbnail_style.bg_color = palette.get(
			"thumb",
			thumbnail_style.bg_color
		)
		thumbnail_style.border_color = palette.get(
			"border",
			thumbnail_style.border_color
		)
		thumbnail_frame.add_theme_stylebox_override(
			"panel",
			thumbnail_style
		)

	if chip_style != null:
		chip_style = chip_style.duplicate() as StyleBoxFlat
		chip_style.bg_color = palette.get(
			"chip_bg",
			chip_style.bg_color
		)
		chip_style.border_color = palette.get(
			"chip_border",
			chip_style.border_color
		)
		state_chip.add_theme_stylebox_override(
			"panel",
			chip_style
		)

	title_label.add_theme_color_override(
		"font_color",
		palette.get("title", Color(0.22, 0.38, 0.14, 1))
	)
	state_label.add_theme_color_override(
		"font_color",
		palette.get("chip_text", Color(0.25, 0.41, 0.15, 1))
	)
	fallback.add_theme_color_override(
		"font_color",
		palette.get("title", Color(0.22, 0.38, 0.14, 1))
	)


func _resolve_gallery_texture_path(entry_kind: String, entry_id: String) -> String:
	if entry_kind == "processed":
		return str(VisualAssets.processed_food_texture_paths().get(entry_id, ""))
	if entry_kind == "badge":
		return str(VisualAssets.badge_texture_paths().get(entry_id, ""))
	if entry_kind.begins_with("title_"):
		return AchievementManager.icon_path_for(entry_id)
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
	var panel := GALLERY_EMPTY_CARD_SCENE.instantiate() as PanelContainer

	if panel == null:
		push_error("GalleryEmptyCard scene root harus PanelContainer.")
		return null

	var label := panel.get_node("Margin/MessageLabel") as Label

	if label == null:
		push_error("GalleryEmptyCard MessageLabel tidak ditemukan.")
		panel.queue_free()
		return null

	label.text = message
	return panel
