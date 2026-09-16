class_name Level02GroupDropZone
extends GroupDropZone

const HOVER_BACKGROUND: Color = Color(1.0, 0.96, 0.68, 1.0)
const HOVER_BORDER: Color = Color(0.92, 0.70, 0.08, 1.0)

const HOVER_STYLE_RESOURCE: StyleBoxFlat = preload(
    "res://resources/ui_styles/l2_group_hover.tres"
)

var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _hover_active: bool = false


func _ready() -> void:
    ScreenMotionPresenter.bind_gameplay_hover(self, true)
    var source_style: StyleBox = get_theme_stylebox("panel")

    if not source_style is StyleBoxFlat:
        push_error("Level02GroupDropZone membutuhkan StyleBoxFlat scene-authored.")
        return

    _normal_style = source_style.duplicate() as StyleBoxFlat
    _hover_style = HOVER_STYLE_RESOURCE
    set_drag_hover(false)

func set_drag_hover(active: bool) -> void:
    if _normal_style == null or _hover_style == null:
        return

    if _hover_active == active:
        return

    _hover_active = active

    if active:
        add_theme_stylebox_override(
            "panel",
            _hover_style
        )
    else:
        add_theme_stylebox_override(
            "panel",
            _normal_style
        )
