class_name TitleUnlockModal
extends Control

signal dismissed(title_ids: Array)

const ITEM_SCENE: PackedScene = preload(
	"res://scenes/shared/achievement/title_unlock_item.tscn"
)

@onready var mask: ColorRect = %TitleUnlockMask
@onready var modal_panel: PanelContainer = %TitleUnlockPanel
@onready var subtitle_label: Label = %TitleUnlockSubtitle
@onready var items_grid: GridContainer = %TitleUnlockItems
@onready var gallery_info: Label = %GalleryInfo
@onready var keren_button: Button = %KerenButton

var _title_ids: Array[String] = []
var _items: Array[Control] = []
var _closing: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	keren_button.pressed.connect(_on_keren_pressed)
	ScreenMotionPresenter.bind_button(keren_button)


func present_titles(entries: Array[Dictionary]) -> void:
	if entries.is_empty():
		return

	_clear_items()
	_title_ids.clear()
	_closing = false
	keren_button.disabled = false

	var count: int = entries.size()
	items_grid.columns = (
		1
		if count == 1
		else (2 if count <= 4 else 3)
	)

	if count == 1:
		subtitle_label.text = "Kamu berhasil mendapatkan gelar baru!"
		gallery_info.text = (
			"Gelar ini dapat dilihat kembali di Galeri pada Menu Utama."
		)
	else:
		subtitle_label.text = (
			"Kamu berhasil mendapatkan %d gelar baru!" % count
		)
		gallery_info.text = (
			"Gelar-gelar ini dapat dilihat kembali di Galeri pada Menu Utama."
		)

	var compact: bool = count > 2
	var card_width: float = (
		520.0
		if count == 1
		else (350.0 if count <= 4 else 260.0)
	)

	for entry in entries:
		var item := ITEM_SCENE.instantiate() as Control

		if item == null:
			continue

		item.custom_minimum_size.x = card_width
		items_grid.add_child(item)
		item.call(
			"bind_entry",
			entry,
			compact
		)
		_items.append(item)

		var title_id: String = str(
			entry.get(
				"title_id",
				""
			)
		).strip_edges()

		if not title_id.is_empty():
			_title_ids.append(title_id)

	if _items.is_empty():
		return

	visible = true
	mask.visible = true
	modal_panel.visible = true

	ScreenMotionPresenter.open_modal(
		modal_panel,
		mask
	)

	var reveal_controls: Array = []

	for item in _items:
		reveal_controls.append(item)

	reveal_controls.append(gallery_info)

	ScreenMotionPresenter.enter_staggered(
		reveal_controls
	)

	_reveal_icons.call_deferred()
	_reveal_keren_button.call_deferred()


func _reveal_keren_button() -> void:
	if not visible or _closing:
		return

	var config := load(
		UIMotion.CONFIG_PATH
	) as MotionConfig
	var duration: float = 0.22
	var delay: float = 0.09

	if config != null:
		duration = config.panel_enter_duration
		delay = (
			config.item_stagger_duration
			* float(_items.size() + 1)
		)

	UIMotion.play_fade_in(
		keren_button,
		duration,
		delay
	)

	var focus_delay: float = maxf(
		0.0,
		delay + duration
	)

	if focus_delay > 0.0:
		await get_tree().create_timer(
			focus_delay
		).timeout

	if (
		visible
		and not _closing
		and is_instance_valid(keren_button)
	):
		keren_button.grab_focus()


func _reveal_icons() -> void:
	if not visible or _items.is_empty():
		return

	var config := load(
		UIMotion.CONFIG_PATH
	) as MotionConfig
	var initial_delay: float = 0.19
	var stagger: float = 0.045

	if config != null:
		initial_delay = config.modal_panel_enter_duration
		stagger = config.item_stagger_duration

	if initial_delay > 0.0:
		await get_tree().create_timer(
			initial_delay
		).timeout

	for item in _items:
		if not visible:
			return

		if is_instance_valid(item):
			item.call("reveal_icon")

		if stagger > 0.0:
			await get_tree().create_timer(
				stagger
			).timeout


func _on_keren_pressed() -> void:
	if _closing:
		return

	_closing = true
	keren_button.disabled = true

	ScreenMotionPresenter.close_modal(
		modal_panel,
		mask,
		_finish_dismiss
	)


func _finish_dismiss() -> void:
	var dismissed_ids: Array = _title_ids.duplicate()
	visible = false
	keren_button.disabled = false
	_closing = false
	_clear_items()
	_title_ids.clear()
	dismissed.emit(dismissed_ids)


func _clear_items() -> void:
	for child_value in items_grid.get_children():
		var child := child_value as Node

		if child == null:
			continue

		items_grid.remove_child(child)
		child.queue_free()

	_items.clear()
