extends Node

const AUTOLOAD_ENTRY := "GlobalGameplayReturnModal"
const OVERLAY_SCENE := preload("res://scenes/shared/global_gameplay_return_modal.tscn")
const GAMEPLAY_ANCESTOR_NAMES := ["MainGameHUD", "GameplayLayer", "GameplayHUD", "MainGame", "GameHUD"]

var _bound_scene_id: int = 0
var _bound_button_ids: Dictionary = {}
var _active_scene: Node = null
var _overlay_layer: CanvasLayer = null
var _mask: ColorRect = null
var _cancel_button: Button = null
var _confirm_button: Button = null

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if not _mount_scene_authored_overlay():
        set_process(false)
        return
    set_process(true)

func _mount_scene_authored_overlay() -> bool:
    _overlay_layer = OVERLAY_SCENE.instantiate() as CanvasLayer
    if _overlay_layer == null:
        push_error("70A: Global gameplay return modal scene gagal diinstansiasi.")
        return false
    add_child(_overlay_layer)

    _mask = _overlay_layer.get_node_or_null("GlobalGameplayReturnMask") as ColorRect
    _cancel_button = _overlay_layer.get_node_or_null("GlobalGameplayReturnMask/Center/Dialog/Margin/VBox/ModalFooter/CancelButton") as Button
    _confirm_button = _overlay_layer.get_node_or_null("GlobalGameplayReturnMask/Center/Dialog/Margin/VBox/ModalFooter/ConfirmButton") as Button

    if _mask == null or _cancel_button == null or _confirm_button == null:
        push_error("70A: Struktur scene global gameplay return modal tidak lengkap.")
        return false

    _cancel_button.pressed.connect(_on_cancel_pressed)
    _confirm_button.pressed.connect(_on_confirm_pressed)
    return true

func _process(_delta: float) -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    var scene_id := scene.get_instance_id()
    if scene_id != _bound_scene_id:
        _bound_scene_id = scene_id
        _bound_button_ids.clear()
        _active_scene = scene
        call_deferred("_bind_gameplay_back_buttons")
    elif _bound_button_ids.is_empty():
        call_deferred("_bind_gameplay_back_buttons")

func _bind_gameplay_back_buttons() -> void:
    var scene := get_tree().current_scene
    if scene == null or not is_instance_valid(scene):
        return
    if not scene.has_meta("level_no"):
        return
    var candidates := scene.find_children("BackButton", "Button", true, false)
    for candidate in candidates:
        var button := candidate as Button
        if button == null:
            continue
        if not _is_gameplay_back_button(button, scene):
            continue
        var button_id := button.get_instance_id()
        if _bound_button_ids.has(button_id):
            continue
        for connection in button.pressed.get_connections():
            var existing_callable: Callable = connection["callable"]
            if existing_callable.is_valid():
                button.pressed.disconnect(existing_callable)
        var callable := Callable(self, "_on_gameplay_back_pressed").bind(button)
        button.pressed.connect(callable)
        _bound_button_ids[button_id] = true

func _is_gameplay_back_button(button: Button, scene: Node) -> bool:
    var node: Node = button.get_parent()
    while node != null and node != scene:
        if String(node.name) in GAMEPLAY_ANCESTOR_NAMES:
            return true
        node = node.get_parent()
    return false

func _on_gameplay_back_pressed(_button: Button) -> void:
    if AudioManager != null:
        AudioManager.play_sfx("click")
    var scene := get_tree().current_scene
    if scene == null:
        return
    _active_scene = scene
    if DurationTracker != null:
        DurationTracker.pause_active_play()
    _mask.visible = true
    _cancel_button.call_deferred("grab_focus")

func _on_cancel_pressed() -> void:
    if AudioManager != null:
        AudioManager.play_sfx("click")
    _mask.visible = false
    if DurationTracker != null:
        DurationTracker.resume_active_play()

func _on_confirm_pressed() -> void:
    if AudioManager != null:
        AudioManager.play_sfx("click")
    var scene := _active_scene
    if scene == null or not is_instance_valid(scene):
        scene = get_tree().current_scene
    if scene != null and is_instance_valid(scene):
        _persist_back_to_map(scene)
    _mask.visible = false
    SceneRouter.goto("main_map")

func _persist_back_to_map(scene: Node) -> void:
    var level_no := int(scene.get_meta("level_no", 0))
    if _has_property(scene, "back_to_map_count"):
        scene.set("back_to_map_count", int(scene.get("back_to_map_count")) + 1)
    if scene.has_method("_persist_level_interaction_snapshot"):
        scene.call("_persist_level_interaction_snapshot", "back_to_map")
    else:
        _persist_generic_level_session(scene)
    if AnalyticsLogger != null:
        AnalyticsLogger.log_event("level_exit_to_map", {
            "level_no": level_no,
            "source": "global_gameplay_return_modal",
            "active_duration_ms": DurationTracker.current_active_ms() if DurationTracker != null else 0
        })
    if SaveManager != null:
        if SaveManager.has_method("save_now"):
            SaveManager.save_now()
        elif SaveManager.has_method("request_save"):
            SaveManager.request_save()

func _persist_generic_level_session(scene: Node) -> void:
    if not _has_property(scene, "level_session"):
        return
    var session_value = scene.get("level_session")
    if not (session_value is Dictionary):
        return
    var session: Dictionary = session_value
    if session.is_empty():
        return
    session["active_duration_ms"] = DurationTracker.current_active_ms() if DurationTracker != null else int(session.get("active_duration_ms", 0))
    session["last_interaction"] = "back_to_map"
    session["last_interaction_at"] = Time.get_unix_time_from_system()
    if _has_property(scene, "back_to_map_count"):
        session["back_to_map_count"] = int(scene.get("back_to_map_count"))
    GameState.update_level_session(session)
    scene.set("level_session", session)

func _has_property(object: Object, property_name: String) -> bool:
    for property_data in object.get_property_list():
        if str(property_data.get("name", "")) == property_name:
            return true
    return false

