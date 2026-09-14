class_name TitleUnlockItem
extends PanelContainer

@onready var title_icon: TextureRect = %TitleIcon
@onready var title_name: Label = %TitleName
@onready var requirement_label: Label = %RequirementLabel


func bind_entry(
	entry: Dictionary,
	compact: bool = false
) -> void:
	title_name.text = str(
		entry.get(
			"display_name",
			"Gelar"
		)
	)

	requirement_label.text = str(
		entry.get(
			"requirement_text",
			""
		)
	).strip_edges()
	requirement_label.visible = (
		not compact
		and not requirement_label.text.is_empty()
	)

	var icon_path: String = str(
		entry.get(
			"icon_path",
			""
		)
	).strip_edges()

	title_icon.texture = null

	if not icon_path.is_empty():
		title_icon.texture = load(icon_path) as Texture2D

	title_icon.modulate = AchievementManager.icon_modulate_for(true)


func reveal_icon() -> void:
	ScreenMotionPresenter.reveal_badge(title_icon)