extends Control

var selected_gender: String = "male"
var applying_name_guard: bool = false

func _ready() -> void:
    var existing_name: String = GameState.player_display_name()

    if existing_name != "Pemain":
        %NameInput.text = existing_name

    selected_gender = GameState.selected_gender()

    %MaleButton.pressed.connect(_set_gender.bind("male"))
    %FemaleButton.pressed.connect(_set_gender.bind("female"))
    %NameInput.text_changed.connect(_on_name_changed)
    %BackButton.pressed.connect(func(): SceneRouter.goto("main_menu"))
    %ContinueButton.pressed.connect(_continue_to_character)

    UIMotion.bind_button(%MaleButton)
    UIMotion.bind_button(%FemaleButton)
    UIMotion.bind_button(%BackButton)
    UIMotion.bind_button(%ContinueButton)

    call_deferred("_focus_input")
    _render_gender_buttons()
    _render_state()

func _focus_input() -> void:
    %NameInput.grab_focus()
    %NameInput.caret_column = %NameInput.text.length()

func _set_gender(player_gender: String) -> void:
    selected_gender = "female" if player_gender == "female" else "male"
    GameState.set_selected_gender(selected_gender)
    _render_gender_buttons()
    _render_state()

func _render_gender_buttons() -> void:
    %MaleButton.button_pressed = selected_gender == "male"
    %FemaleButton.button_pressed = selected_gender == "female"

func _normalized_name() -> String:
    return GameState.sanitize_player_name(%NameInput.text)

func _on_name_changed(new_text: String) -> void:
    if applying_name_guard:
        return

    var sanitized: String = GameState.sanitize_player_name(new_text)

    if sanitized != new_text:
        applying_name_guard = true
        %NameInput.text = sanitized
        %NameInput.caret_column = sanitized.length()
        applying_name_guard = false

    _render_state()

func _render_state() -> void:
    var clean_name: String = _normalized_name()
    var valid: bool = GameState.is_valid_player_name(clean_name)

    %ContinueButton.disabled = not valid

    if clean_name.is_empty():
        %HintLabel.text = "Awali dengan huruf. Gunakan hanya huruf, angka, dan garis bawah (_), maksimal 12 karakter."
    elif clean_name.length() > 12:
        %HintLabel.text = "Nama maksimal 12 karakter."
    elif not GameState.is_valid_player_name(clean_name):
        %HintLabel.text = "Nama harus diawali huruf dan hanya boleh berisi huruf, angka, atau garis bawah (_)."
    else:
        %HintLabel.text = "Nama akan mengikuti karakter yang kamu pilih dan progres tersimpan otomatis di perangkat ini."

    %GenderCaption.text = "Identitas dipilih: %s" % ("Laki-laki" if selected_gender == "male" else "Perempuan")

func _continue_to_character() -> void:
    var clean_name: String = _normalized_name()

    if not GameState.is_valid_player_name(clean_name):
        _render_state()
        return

    GameState.start_new_run(clean_name, selected_gender)
    SceneRouter.goto("character_select")
