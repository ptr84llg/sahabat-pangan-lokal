class_name ResponsiveConfig
extends Resource

@export_category("Orientation Guard")
@export var blocker_color: Color = Color(0.035, 0.075, 0.055, 0.97)
@export var panel_minimum_size: Vector2 = Vector2(520.0, 250.0)
@export var margin_left: int = 32
@export var margin_top: int = 28
@export var margin_right: int = 32
@export var margin_bottom: int = 28
@export var separation: int = 18
@export var title_text: String = "MODE LANDSCAPE"
@export var title_font_size: int = 30
@export var body_font_size: int = 20
@export var button_text: String = "AKTIFKAN LANDSCAPE"
@export var button_height: float = 52.0
@export_multiline var web_message: String = "Game ini tetap menggunakan landscape.\nTekan tombol di bawah jika browser belum berputar otomatis."
@export_multiline var native_message: String = "Game ini dimainkan dalam posisi landscape.\nPerangkat sedang menyesuaikan orientasi layar."