class_name UpdateConfig
extends Resource

@export_category("Endpoint")
@export var manifest_url: String = "https://sahabatpanganlokal.id/updates/manifest.json"
@export var channel: String = "stable"
@export_range(1.0, 60.0, 0.5) var request_timeout_seconds: float = 12.0

@export_category("Application Version")
@export var app_version: String = "1.0.0"
@export_range(1, 1000000, 1) var version_code: int = 100
@export var bundled_content_version: String = "1.1-normalized"
@export_range(1, 1000, 1) var save_schema_version: int = 3

@export_category("Behavior")
@export var allow_offline: bool = true
@export var auto_download_content: bool = true
