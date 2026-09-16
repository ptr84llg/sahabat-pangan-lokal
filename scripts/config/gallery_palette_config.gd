class_name GalleryPaletteConfig
extends Resource

@export_category("Fresh Food")
@export var fresh_panel: Color = Color(0.95, 0.98, 0.91, 0.98)
@export var fresh_border: Color = Color(0.46, 0.60, 0.27, 0.44)
@export var fresh_thumb: Color = Color(0.88, 0.95, 0.78, 0.98)
@export var fresh_title: Color = Color(0.22, 0.38, 0.14, 1)
@export var fresh_chip_bg: Color = Color(0.84, 0.94, 0.72, 0.96)
@export var fresh_chip_border: Color = Color(0.46, 0.60, 0.27, 0.34)
@export var fresh_chip_text: Color = Color(0.25, 0.41, 0.15, 1)

@export_category("Processed Food")
@export var processed_panel: Color = Color(1.00, 0.96, 0.92, 0.98)
@export var processed_border: Color = Color(0.78, 0.55, 0.30, 0.46)
@export var processed_thumb: Color = Color(1.00, 0.90, 0.78, 0.98)
@export var processed_title: Color = Color(0.34, 0.40, 0.23, 1)
@export var processed_chip_bg: Color = Color(0.98, 0.86, 0.72, 0.96)
@export var processed_chip_border: Color = Color(0.78, 0.55, 0.30, 0.38)
@export var processed_chip_text: Color = Color(0.46, 0.26, 0.12, 1)

@export_category("Badge")
@export var badge_panel: Color = Color(1.00, 0.97, 0.88, 0.98)
@export var badge_border: Color = Color(0.78, 0.61, 0.16, 0.52)
@export var badge_thumb: Color = Color(1.00, 0.93, 0.68, 0.98)
@export var badge_title: Color = Color(0.54, 0.36, 0.05, 1)
@export var badge_chip_bg: Color = Color(0.97, 0.84, 0.39, 0.96)
@export var badge_chip_border: Color = Color(0.80, 0.61, 0.08, 0.48)
@export var badge_chip_text: Color = Color(0.47, 0.31, 0.04, 1)


func palette_for(entry_kind: String) -> Dictionary:
	match entry_kind:
		"badge":
			return _badge_palette()
		"processed":
			return _processed_palette()
		_:
			return _fresh_palette()


func _fresh_palette() -> Dictionary:
	return {
		"panel": fresh_panel,
		"border": fresh_border,
		"thumb": fresh_thumb,
		"title": fresh_title,
		"chip_bg": fresh_chip_bg,
		"chip_border": fresh_chip_border,
		"chip_text": fresh_chip_text
	}


func _processed_palette() -> Dictionary:
	return {
		"panel": processed_panel,
		"border": processed_border,
		"thumb": processed_thumb,
		"title": processed_title,
		"chip_bg": processed_chip_bg,
		"chip_border": processed_chip_border,
		"chip_text": processed_chip_text
	}


func _badge_palette() -> Dictionary:
	return {
		"panel": badge_panel,
		"border": badge_border,
		"thumb": badge_thumb,
		"title": badge_title,
		"chip_bg": badge_chip_bg,
		"chip_border": badge_chip_border,
		"chip_text": badge_chip_text
	}
