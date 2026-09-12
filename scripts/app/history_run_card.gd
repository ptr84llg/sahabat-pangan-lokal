extends PanelContainer

signal accordion_toggled(card: Control, opened: bool)

const LEVEL_ROW_SCENE: PackedScene = preload(
	"res://scenes/app/history/history_level_row.tscn"
)

@onready var toggle_button: Button = %ToggleButton
@onready var arrow_label: Label = %ArrowLabel
@onready var journey_label: Label = %JourneyLabel
@onready var meta_label: Label = %MetaLabel
@onready var total_score_value: Label = %TotalScoreValue
@onready var total_stars_value: Label = %TotalStarsValue
@onready var total_time_value: Label = %TotalTimeValue
@onready var body_panel: PanelContainer = %BodyPanel
@onready var level_rows_host: VBoxContainer = %LevelRowsHost


func _ready() -> void:
	toggle_button.toggled.connect(_on_toggle_changed)
	set_opened(false)


func configure(data: Dictionary) -> void:
	journey_label.text = str(data.get("journey", "PERJALANAN"))
	meta_label.text = "%s  |  %s" % [
		str(data.get("completed_at", "Tanggal belum tersedia")),
		str(data.get("character", "-"))
	]
	total_score_value.text = str(data.get("total_score", "-"))
	total_stars_value.text = str(data.get("total_stars", "-"))
	total_time_value.text = str(data.get("total_duration", "-"))

	for child in level_rows_host.get_children():
		level_rows_host.remove_child(child)
		child.queue_free()

	var levels_value: Variant = data.get("levels", [])

	if levels_value is Array:
		for level_value in levels_value:
			if not level_value is Dictionary:
				continue

			var row: Control = LEVEL_ROW_SCENE.instantiate() as Control

			if row == null:
				continue

			level_rows_host.add_child(row)
			row.call("configure", level_value)

	set_opened(false)


func set_opened(opened: bool) -> void:
	toggle_button.set_pressed_no_signal(opened)
	body_panel.visible = opened
	arrow_label.text = "v" if opened else ">"


func _on_toggle_changed(opened: bool) -> void:
	body_panel.visible = opened
	arrow_label.text = "v" if opened else ">"
	accordion_toggled.emit(self, opened)
