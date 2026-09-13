extends Node

const CONFIG_PATH: String = "res://resources/config/audio_config.tres"

var config: AudioConfig

const META_AUDIO_BUTTON_BOUND: StringName = &"spl_audio_button_bound"
const META_AUDIO_MODAL_BOUND: StringName = &"spl_audio_modal_bound"
const META_AUDIO_MODAL_VISIBLE: StringName = &"spl_audio_modal_visible"

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var final_scene_sfx_players: Array[AudioStreamPlayer] = []
var sfx_cache: Dictionary = {}
var current_music_key: String = ""
var sfx_cursor: int = 0
var scene_sync_queued: bool = false
var final_scene_audio_active: bool = false


func _ready() -> void:
    var loaded := load(CONFIG_PATH)
    if loaded is AudioConfig:
        config = loaded as AudioConfig
    else:
        push_error("AudioConfig tidak dapat dimuat.")
        return

    _ensure_audio_buses()
    _create_music_player()
    _create_sfx_players()
    _create_final_scene_sfx_players()
    apply_settings()
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_bind_existing_ui_sfx")
    call_deferred("_sync_music_from_current_scene")


func _ensure_audio_buses() -> void:
    _ensure_bus("Music")
    _ensure_bus("SFX")


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) != -1:
        return

    AudioServer.add_bus()
    var bus_index: int = AudioServer.bus_count - 1
    AudioServer.set_bus_name(bus_index, bus_name)


func _create_music_player() -> void:
    music_player = AudioStreamPlayer.new()
    music_player.name = "MusicPlayer"
    music_player.bus = "Music"
    music_player.volume_db = config.music_player_volume_db
    add_child(music_player)


func _create_sfx_players() -> void:
    for index in range(config.sfx_player_count):
        var player := AudioStreamPlayer.new()
        player.name = "SfxPlayer%d" % index
        player.bus = "SFX"
        player.volume_db = config.sfx_player_volume_db
        add_child(player)
        sfx_players.append(player)


func _create_final_scene_sfx_players() -> void:
    for index in range(config.final_scene_sfx_player_count):
        var player := AudioStreamPlayer.new()
        player.name = "FinalSceneSfxPlayer%d" % (index + 1)
        player.bus = "SFX"
        player.volume_db = config.sfx_player_volume_db
        add_child(player)
        final_scene_sfx_players.append(player)


func apply_settings() -> void:
    var muted: bool = SettingsManager.get_flag("muted", false)
    var music_level: float = clampf(float(SettingsManager.get_value("music_volume", 0.80)), 0.0, 1.0)
    var sfx_level: float = clampf(float(SettingsManager.get_value("sfx_volume", 0.80)), 0.0, 1.0)

    _apply_bus("Master", 1.0, muted)
    _apply_bus(
        "Music",
        music_level,
        muted or final_scene_audio_active
    )
    _apply_bus("SFX", sfx_level, muted)


func _apply_bus(bus_name: String, linear_value: float, muted: bool) -> void:
    var bus_index: int = AudioServer.get_bus_index(bus_name)

    if bus_index == -1:
        return

    AudioServer.set_bus_mute(bus_index, muted)

    if muted or linear_value <= 0.001:
        AudioServer.set_bus_volume_db(bus_index, -80.0)
        return

    AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear_value))


func play_for_scene(scene_key: String) -> void:
    var music_key := _music_key_for_scene_key(scene_key)

    if not music_key.is_empty():
        play_music(music_key)


func play_music(music_key: String) -> void:
    if music_player == null:
        return

    if current_music_key == music_key and music_player.playing:
        return

    var stream_path: String = str(config.music_tracks.get(music_key, ""))

    if stream_path.is_empty():
        return

    var stream: AudioStream = load(stream_path)

    if stream == null:
        push_warning("BGM tidak dapat dimuat: %s" % stream_path)
        return

    if stream is AudioStreamMP3:
        stream.loop = true
    elif stream is AudioStreamOggVorbis:
        stream.loop = true

    music_player.stop()
    music_player.stream = stream
    current_music_key = music_key
    music_player.play()


func start_final_scene_audio() -> void:
    if final_scene_audio_active:
        return

    final_scene_audio_active = true
    apply_settings()


    for index in range(
        mini(
            config.final_scene_sfx_keys.size(),
            final_scene_sfx_players.size()
        )
    ):
        var source_stream: AudioStream = _get_sfx_stream(
            config.final_scene_sfx_keys[index]
        )

        if source_stream == null:
            continue

        var loop_stream: AudioStream = (
            source_stream.duplicate() as AudioStream
        )

        if loop_stream == null:
            loop_stream = source_stream

        if loop_stream is AudioStreamMP3:
            loop_stream.loop = true
        elif loop_stream is AudioStreamOggVorbis:
            loop_stream.loop = true

        var player: AudioStreamPlayer = (
            final_scene_sfx_players[index]
        )
        player.stop()
        player.stream = loop_stream
        player.play()


func stop_final_scene_audio() -> void:
    if not final_scene_audio_active:
        return

    for player in final_scene_sfx_players:
        player.stop()
        player.stream = null

    final_scene_audio_active = false
    apply_settings()


func play_sfx(sfx_key: String) -> void:
    if sfx_players.is_empty():
        return

    var stream: AudioStream = _get_sfx_stream(sfx_key)

    if stream == null:
        return

    var player: AudioStreamPlayer = sfx_players[sfx_cursor]
    sfx_cursor = (sfx_cursor + 1) % sfx_players.size()
    player.stop()
    player.stream = stream
    player.play()


func play_drop_feedback(correct: bool) -> void:
    play_sfx("drop_true" if correct else "drop_false")


func play_choice_feedback(correct: bool) -> void:
    play_sfx("choice_true" if correct else "choice_false")


func _get_sfx_stream(sfx_key: String) -> AudioStream:
    if sfx_cache.has(sfx_key):
        return sfx_cache[sfx_key]

    var stream_path: String = str(config.sfx_tracks.get(sfx_key, ""))

    if stream_path.is_empty():
        return null

    var stream: AudioStream = load(stream_path)

    if stream == null:
        push_warning("SFX tidak dapat dimuat: %s" % stream_path)
        return null

    sfx_cache[sfx_key] = stream
    return stream


func _input(event: InputEvent) -> void:
    if not SettingsManager.get_flag("mouse_click_enabled", true):
        return

    if not (event is InputEventMouseButton):
        return

    var mouse_event := event as InputEventMouseButton

    if (
        mouse_event.button_index != MOUSE_BUTTON_LEFT
        or not mouse_event.pressed
    ):
        return

    var hovered_control: Control = get_viewport().gui_get_hovered_control()

    if _control_is_inside_button(hovered_control):
        return

    play_sfx("click_press")


func _control_is_inside_button(control: Control) -> bool:
    var node: Node = control

    while node != null:
        if node is BaseButton:
            return true

        node = node.get_parent()

    return false


func _bind_existing_ui_sfx() -> void:
    var root: Node = get_tree().root

    if root == null:
        return

    _bind_ui_recursive(root)


func _bind_ui_recursive(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return

    _bind_ui_node(node)

    for child in node.get_children():
        _bind_ui_recursive(child)


func _bind_ui_node(node: Node) -> void:
    if node == null or not is_instance_valid(node):
        return

    if node is BaseButton:
        _bind_button(node as BaseButton)

    if node is Control:
        _bind_modal_candidate(node as Control)


func _bind_button(button: BaseButton) -> void:
    if button == null or not is_instance_valid(button):
        return

    if bool(button.get_meta(META_AUDIO_BUTTON_BOUND, false)):
        return

    button.set_meta(META_AUDIO_BUTTON_BOUND, true)
    button.mouse_entered.connect(
        _on_button_hover.bind(button)
    )
    button.pressed.connect(
        _on_button_pressed.bind(button)
    )


func _on_button_hover(button: BaseButton) -> void:
    if button == null or not is_instance_valid(button):
        return

    if button.disabled:
        return

    if not SettingsManager.get_flag(
        "button_hover_enabled",
        true
    ):
        return

    play_sfx("hover")


func _on_button_pressed(button: BaseButton) -> void:
    if button == null or not is_instance_valid(button):
        return

    if button.disabled:
        return

    if not SettingsManager.get_flag(
        "button_click_enabled",
        true
    ):
        return

    play_sfx("click_press")


func _bind_modal_candidate(control: Control) -> void:
    if control == null or not is_instance_valid(control):
        return

    if not _is_modal_candidate(control):
        return

    if bool(control.get_meta(META_AUDIO_MODAL_BOUND, false)):
        return

    control.set_meta(META_AUDIO_MODAL_BOUND, true)
    control.set_meta(
        META_AUDIO_MODAL_VISIBLE,
        control.is_visible_in_tree()
    )
    control.visibility_changed.connect(
        _on_modal_visibility_changed.bind(control)
    )


func _is_modal_candidate(control: Control) -> bool:
    if _is_named_modal_root(control):
        return true

    var node_name := str(control.name).to_lower()

    if (
        node_name.contains("modal")
        and node_name.ends_with("mask")
    ):
        return not _has_descendant_named_modal_root(control)

    return false


func _is_named_modal_root(control: Control) -> bool:
    var node_name := str(control.name).to_lower()

    return (
        node_name.ends_with("modal")
        or node_name.ends_with("modalpanel")
    )


func _has_descendant_named_modal_root(node: Node) -> bool:
    for child in node.get_children():
        if child is Control:
            var child_control := child as Control

            if _is_named_modal_root(child_control):
                return true

        if _has_descendant_named_modal_root(child):
            return true

    return false


func _on_modal_visibility_changed(control: Control) -> void:
    if control == null or not is_instance_valid(control):
        return

    var visible_now: bool = control.is_visible_in_tree()
    var visible_before: bool = bool(
        control.get_meta(
            META_AUDIO_MODAL_VISIBLE,
            false
        )
    )

    control.set_meta(
        META_AUDIO_MODAL_VISIBLE,
        visible_now
    )

    if visible_now and not visible_before:
        play_sfx("menu_modal_open")


func _on_node_added(node: Node) -> void:
    call_deferred("_bind_ui_node", node)
    _queue_scene_sync()


func _queue_scene_sync() -> void:
    if scene_sync_queued:
        return

    scene_sync_queued = true
    call_deferred("_run_scene_sync")


func _run_scene_sync() -> void:
    scene_sync_queued = false
    _sync_music_from_current_scene()


func _sync_music_from_current_scene() -> void:
    var current_scene: Node = get_tree().current_scene

    if current_scene == null:
        return

    var scene_path: String = current_scene.scene_file_path
    var music_key := _music_key_for_scene_path(scene_path)

    if not music_key.is_empty():
        play_music(music_key)


func _music_key_for_scene_key(scene_key: String) -> String:
    if scene_key in config.shell_scene_keys:
        return config.shell_music_key

    if scene_key == config.main_map_scene_key:
        return config.map_music_key

    if scene_key in config.game_scene_keys:
        return config.game_music_key

    return ""


func _music_key_for_scene_path(scene_path: String) -> String:
    var direct_key: String = str(config.direct_scene_music.get(scene_path, ""))

    if not direct_key.is_empty():
        return direct_key

    if scene_path.begins_with(config.level_scene_prefix):
        return config.level_music_key

    return ""