extends Node

const MUSIC_TRACKS := {
    "shell": "res://assets/audio/music/bgm_shell.mp3",
    "map": "res://assets/audio/music/bgm_map.mp3",
    "game": "res://assets/audio/music/bgm_game.mp3"
}

const SHELL_SCENE_KEYS := ["splash", "main_menu", "player_setup", "character_select", "intro"]
const GAME_SCENE_KEYS := ["level_01", "level_02", "level_03", "level_04", "level_05"]

var music_player: AudioStreamPlayer
var current_music_key: String = ""
var scene_sync_queued: bool = false


func _ready() -> void:
    _ensure_audio_buses()
    _create_music_player()
    apply_settings()
    get_tree().node_added.connect(_on_node_added)
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
    music_player.volume_db = -4.0
    add_child(music_player)


func apply_settings() -> void:
    var muted: bool = SettingsManager.get_flag("muted", false)
    var music_level: float = clampf(float(SettingsManager.get_value("music_volume", 0.80)), 0.0, 1.0)
    var sfx_level: float = clampf(float(SettingsManager.get_value("sfx_volume", 0.80)), 0.0, 1.0)

    _apply_bus("Master", 1.0, muted)
    _apply_bus("Music", music_level, muted)
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

    var stream_path: String = str(MUSIC_TRACKS.get(music_key, ""))

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


func _on_node_added(_node: Node) -> void:
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
    if scene_key in SHELL_SCENE_KEYS:
        return "shell"

    if scene_key == "main_map":
        return "map"

    if scene_key in GAME_SCENE_KEYS:
        return "game"

    return ""


func _music_key_for_scene_path(scene_path: String) -> String:
    if scene_path == "res://scenes/app/splash_scene.tscn":
        return "shell"

    if scene_path == "res://scenes/app/main_menu_scene.tscn":
        return "shell"

    if scene_path == "res://scenes/app/player_setup_scene.tscn":
        return "shell"

    if scene_path == "res://scenes/app/character_select_scene.tscn":
        return "shell"

    if scene_path == "res://scenes/app/intro_scene.tscn":
        return "shell"

    if scene_path == "res://scenes/app/main_map_scene.tscn":
        return "map"

    if scene_path.begins_with("res://scenes/levels/level_"):
        return "game"

    return ""
