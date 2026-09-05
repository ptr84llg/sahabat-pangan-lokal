class_name Level02GroupDropZone
extends GroupDropZone

const HOVER_BACKGROUND: Color = Color(1.0, 0.96, 0.68, 1.0)
const HOVER_BORDER: Color = Color(0.92, 0.70, 0.08, 1.0)

var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _hover_active: bool = false


func _ready() -> void:
    var source_style: StyleBox = get_theme_stylebox("panel")

    if source_style is StyleBoxFlat:
        _normal_style = (
            source_style.duplicate() as StyleBoxFlat
        )
    else:
        _normal_style = StyleBoxFlat.new()
        _normal_style.bg_color = Color(
            0.99,
            0.99,
            0.98,
            1.0
        )
        _normal_style.border_color = Color(
            0.0,
            0.36,
            0.22,
            1.0
        )
        _normal_style.set_border_width_all(2)

    _hover_style = (
        _normal_style.duplicate() as StyleBoxFlat
    )
    _hover_style.bg_color = HOVER_BACKGROUND
    _hover_style.border_color = HOVER_BORDER
    _hover_style.set_border_width_all(4)

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
