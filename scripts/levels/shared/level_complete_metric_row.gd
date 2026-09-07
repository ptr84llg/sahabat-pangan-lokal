extends HBoxContainer
class_name LevelCompleteMetricRow

const STAR_TEXTURE_PATHS: Dictionary = {
	"full": "res://assets/ui/stars/star_full.png",
	"half": "res://assets/ui/stars/star_half.png",
	"empty": "res://assets/ui/stars/star_empty.png"
}

@onready var metric_label: Label = %MetricLabel
@onready var metric_value: Label = %MetricValue
@onready var star_slots: HBoxContainer = %StarSlots

var _star_textures: Dictionary = {}


func bind_metric(
	label_text: String,
	value_text: String
) -> void:
	metric_label.text = label_text
	metric_value.text = value_text
	metric_value.visible = true
	star_slots.visible = false


func bind_stars(
	label_text: String,
	slots_value: Variant
) -> void:
	metric_label.text = label_text
	metric_value.visible = false
	star_slots.visible = true

	var slots: Array = []

	if slots_value is Array:
		slots = slots_value

	var star_nodes: Array[Node] = star_slots.get_children()

	for index in range(star_nodes.size()):
		var node: Node = star_nodes[index]
		var star: TextureRect = node as TextureRect

		if star == null:
			continue

		if index >= slots.size():
			star.visible = false
			continue

		var slot: String = str(slots[index])
		var texture: Texture2D = _load_star_texture(slot)
		star.texture = texture
		star.visible = texture != null


func _load_star_texture(
	slot: String
) -> Texture2D:
	var cached_value: Variant = _star_textures.get(
		slot,
		null
	)

	if cached_value is Texture2D:
		return cached_value as Texture2D

	var path: String = str(
		STAR_TEXTURE_PATHS.get(slot, "")
	)

	if path.is_empty():
		return null

	var texture: Texture2D = load(path) as Texture2D

	if texture != null:
		_star_textures[slot] = texture

	return texture