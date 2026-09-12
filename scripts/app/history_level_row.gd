extends PanelContainer

@onready var level_label: Label = %LevelLabel
@onready var score_value: Label = %ScoreValue
@onready var stars_value: Label = %StarsValue
@onready var time_value: Label = %TimeValue


func configure(data: Dictionary) -> void:
	var level_no: int = int(data.get("level_no", 0))
	level_label.text = "LEVEL %d" % level_no if level_no > 0 else "LEVEL"
	score_value.text = str(data.get("score", "-"))
	stars_value.text = str(data.get("stars", "-"))
	time_value.text = str(data.get("duration", "-"))
