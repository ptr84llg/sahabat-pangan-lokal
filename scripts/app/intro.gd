extends Control

const INTRO_HAPPY_TEXTURES := {
    "rara": "res://assets/visual/character_select/character_01_female_happy.png",
    "budi": "res://assets/visual/character_select/character_02_male_happy.png",
    "anjani": "res://assets/visual/character_select/character_03_female_happy.png",
    "riski": "res://assets/visual/character_select/character_04_male_happy.png"
}

var page: int = 0
var lines: Array[String] = []

func _ready() -> void:
    if not GameState.has_selected_character():
        SceneRouter.goto("character_select")
        return

    var selected_character_id: String = GameState.selected_character_id()
    var texture_path: String = str(
        INTRO_HAPPY_TEXTURES.get(selected_character_id, "")
    )

    if texture_path.is_empty():
        texture_path = GameState.selected_character_texture_path()

    if not texture_path.is_empty():
        %PlayerAvatar.texture = load(texture_path)

    %PlayerName.text = GameState.player_display_name()

    lines = [
        "%s, hari ini petualanganmu dimulai. Kamu akan menjelajah lima tempat untuk mengenal pangan lokal di sekitarmu." % GameState.player_display_name(),
        "Di setiap tempat, kamu akan bermain sambil belajar. Ada tugas mengenali bahan, mengelompokkan pangan, belanja cermat, mengolah makanan, lalu mengikuti festival pangan lokal.",
        "Mulailah dari Rumah. Selesaikan setiap misi dengan teliti agar tempat berikutnya terbuka dan koleksi panganmu semakin lengkap."
    ]

    %BackButton.pressed.connect(_back)
    %ChangeCharacterButton.pressed.connect(func(): SceneRouter.goto("character_select"))
    %IntroNext.pressed.connect(_next)

    UIMotion.bind_button(%BackButton)
    UIMotion.bind_button(%ChangeCharacterButton)
    UIMotion.bind_button(%IntroNext)

    _render()

func _next() -> void:
    page += 1

    if page >= lines.size():
        SceneRouter.goto("main_map")
        return

    _render()

func _back() -> void:
    if page <= 0:
        SceneRouter.goto("character_select")
        return

    page -= 1
    _render()

func _render() -> void:
    %IntroText.text = lines[page]
    %IntroCounter.text = "%d / %d" % [page + 1, lines.size()]
    %IntroNext.text = "KE PETA" if page == lines.size() - 1 else "LANJUT"

    %Dot1.text = "●" if page == 0 else "○"
    %Dot2.text = "●" if page == 1 else "○"
    %Dot3.text = "●" if page == 2 else "○"