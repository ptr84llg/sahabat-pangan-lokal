extends Control
class_name LevelBadgeReward

const BADGE_PATHS: Dictionary = {
	"1": "res://assets/visual/badges/badge-1.png",
	"2": "res://assets/visual/badges/badge-2.png",
	"3": "res://assets/visual/badges/badge-3.png",
	"4": "res://assets/visual/badges/badge-4.png",
	"5": "res://assets/visual/badges/badge-5.png"
}
@onready var reward_ui: Control = %RewardUI
@onready var badge_image: TextureRect = %BadgeImage
@onready var reward_message: Label = %RewardMessage
@onready var action_button: Button = %ActionButton
@onready var portrait_blocker: Control = %PortraitBlocker

var _source_panel: Control
var _native_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	action_button.pressed.connect(_on_action_button_pressed)
	get_viewport().size_changed.connect(_check_orientation)
	_check_orientation()


func show_reward(
	source_panel: Control,
	data: Dictionary,
	native_button: Button
) -> void:
	_source_panel = source_panel
	_native_button = native_button

	var level_number: String = str(
		data.get("level_number", "")
	).strip_edges()
	var message_text: String = str(
		data.get("message_text", "")
	).strip_edges()
	var button_text: String = str(
		data.get("button_text", "")
	).strip_edges()
	var badge_name: String = str(
		data.get("badge_name", "")
	).strip_edges()

	if badge_name.is_empty():
		badge_name = _default_badge_name(level_number)

	if message_text.is_empty():
		message_text = (
			"Kamu mendapatkan badge \"%s\"." % badge_name
		)

	if button_text.is_empty():
		button_text = "LANJUT"

	var badge_texture: Texture2D = _load_badge_texture(
		level_number
	)

	badge_image.texture = badge_texture
	badge_image.visible = badge_texture != null
	reward_message.text = message_text
	action_button.text = button_text
	action_button.disabled = _native_button == null

	if is_instance_valid(_source_panel):
		_source_panel.visible = false

	reward_ui.visible = true
	visible = true
	_check_orientation()
	action_button.call_deferred("grab_focus")


func hide_presenter() -> void:
	action_button.disabled = false
	_source_panel = null
	_native_button = null
	reward_ui.visible = false
	visible = false


func _on_action_button_pressed() -> void:
	if not is_instance_valid(_native_button):
		return

	action_button.disabled = true
	_native_button.emit_signal("pressed")

	var host: Node = get_parent()

	if (
		host != null
		and host.has_method(
			"_refresh_level_badge_reward_presenter"
		)
	):
		host.call_deferred(
			"_refresh_level_badge_reward_presenter"
		)


func _check_orientation() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var portrait: bool = viewport_size.y > viewport_size.x

	portrait_blocker.visible = portrait
	reward_ui.visible = visible and not portrait


func _load_badge_texture(
	level_number: String
) -> Texture2D:
	var badge_path: String = str(
		BADGE_PATHS.get(level_number, "")
	)

	if badge_path.is_empty():
		return null

	if not ResourceLoader.exists(badge_path):
		return null

	var resource: Resource = load(badge_path)

	if resource is Texture2D:
		return resource as Texture2D

	return null


func _default_badge_name(
	level_number: String
) -> String:
	match level_number:
		"1":
			return "Penjelajah Pangan Lokal"
		"2":
			return "Penyusun Kelompok Pangan Lokal"
		"3":
			return "Perencana Belanja Pangan"
		"4":
			return "Peracik Pangan Lokal"
		"5":
			return "Duta Pangan Lokal"
		_:
			return "Badge Pangan Lokal"


