extends RefCounted

const PROCESS_TEXTURE_PATHS := {
    "process_boiled": "res://assets/visual/processes/direbus.png",
    "process_stir_fried": "res://assets/visual/processes/ditumis.png",
    "process_steamed": "res://assets/visual/processes/dikukus.png",
    "process_mixed": "res://assets/visual/processes/dicampur.png"
}

const PROCESS_DISPLAY_NAMES := {
    "process_boiled": "Direbus",
    "process_stir_fried": "Ditumis",
    "process_steamed": "Dikukus",
    "process_mixed": "Dicampur"
}

const CARD_VISUAL_SCENE := preload(
    "res://scenes/levels/level_04/process_visual_card_content.tscn"
)
const BUTTON_VISUAL_SCENE := preload(
    "res://scenes/shared/gameplay/process_visual_button_content.tscn"
)

static func get_texture(process_id: String) -> Texture2D:
    var texture_path := str(
        PROCESS_TEXTURE_PATHS.get(
            process_id,
            ""
        )
    )

    if texture_path.is_empty():
        return null

    return load(texture_path) as Texture2D


static func get_display_name(process_id: String) -> String:
    return str(
        PROCESS_DISPLAY_NAMES.get(
            process_id,
            process_id
        )
    )


static func _remove_existing_process_visual(host: Node) -> void:
    if host == null:
        return

    var existing := host.get_node_or_null(
        "ProcessVisual"
    )

    if existing != null:
        existing.free()


static func _build_visual_from_scene(
    visual_scene: PackedScene,
    process_id: String,
    texture: Texture2D
) -> Control:
    if visual_scene == null:
        return null

    var visual := visual_scene.instantiate() as Control

    if visual == null:
        return null

    var image_node := visual.get_node_or_null(
        "ProcessImage"
    ) as TextureRect
    var label_node := visual.get_node_or_null(
        "ProcessLabel"
    ) as Label

    if image_node == null or label_node == null:
        visual.free()
        return null

    image_node.texture = texture
    label_node.text = get_display_name(process_id)
    return visual


static func decorate_named_drag_card(
    card: NamedDragCard,
    process_id: String,
    image_size: Vector2 = Vector2(154, 104),
    card_size: Vector2 = Vector2(170, 112)
) -> bool:
    if card == null:
        return false

    var texture := get_texture(process_id)

    if texture == null:
        return false

    var title_node := card.get_node_or_null(
        "TitleLabel"
    ) as Label

    if title_node != null:
        title_node.visible = false

    _remove_existing_process_visual(card)

    var visual := _build_visual_from_scene(
        CARD_VISUAL_SCENE,
        process_id,
        texture
    )

    if visual == null:
        return false

    visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.add_child(visual)
    visual.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    card.custom_minimum_size = Vector2(
        card_size.x,
        maxf(
            card_size.y,
            image_size.y + 8.0
        )
    )
    card.set_image_drag_preview(
        texture,
        card_size
    )
    return true


static func decorate_button(
    button: Button,
    process_id: String,
    min_size: Vector2 = Vector2(128, 92)
) -> bool:
    if button == null:
        return false

    var texture := get_texture(process_id)

    if texture == null:
        return false

    button.text = ""
    button.tooltip_text = get_display_name(
        process_id
    )
    button.icon = null
    button.expand_icon = false
    button.custom_minimum_size = Vector2(
        min_size.x,
        maxf(
            min_size.y,
            112.0
        )
    )

    _remove_existing_process_visual(button)

    var visual := _build_visual_from_scene(
        BUTTON_VISUAL_SCENE,
        process_id,
        texture
    )

    if visual == null:
        return false

    visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(visual)
    visual.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    return true
