extends Node

const BYTES_PER_MB: float = 1048576.0
const WINDOWS_PROFILE_CACHE_MS: int = 60000

var _windows_profile_cache: Dictionary = {}
var _windows_profile_cached_at_msec: int = -1

func capture_snapshot(allow_windows_profile_refresh: bool = true) -> Dictionary:
	var screen_id: int = DisplayServer.SCREEN_OF_MAIN_WINDOW
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	var viewport_size: Vector2i = DisplayServer.window_get_size()
	var model_name: String = OS.get_model_name().strip_edges()
	var processor_name: String = OS.get_processor_name().strip_edges()
	var gpu_name: String = RenderingServer.get_video_adapter_name().strip_edges()
	var gpu_vendor: String = RenderingServer.get_video_adapter_vendor().strip_edges()
	var rendering_driver: String = RenderingServer.get_current_rendering_driver_name().strip_edges()
	var rendering_api_version: String = RenderingServer.get_video_adapter_api_version().strip_edges()
	var orientation: String = "unknown"
	var memory_info: Dictionary = OS.get_memory_info()
	var timezone_info: Dictionary = Time.get_time_zone_from_system()
	var windows_profile: Dictionary = {}
	if allow_windows_profile_refresh:
		windows_profile = _get_windows_profile()
	elif (
		_windows_profile_cached_at_msec >= 0
		and Time.get_ticks_msec() - _windows_profile_cached_at_msec < WINDOWS_PROFILE_CACHE_MS
		and not _windows_profile_cache.is_empty()
	):
		windows_profile = _windows_profile_cache.duplicate(true)

	var device_type_value: Variant = null
	var manufacturer_value: Variant = null
	var model_value: Variant = null
	var processor_name_value: Variant = null
	var renderer_value: Variant = null
	var gpu_name_value: Variant = null
	var gpu_vendor_value: Variant = null
	var driver_name_value: Variant = null
	var driver_version_value: Variant = null
	var api_version_value: Variant = null
	var physical_memory_value: Variant = null
	var free_memory_value: Variant = null
	var available_memory_value: Variant = null
	var used_memory_value: Variant = null
	var physical_width_value: Variant = null
	var physical_height_value: Variant = null
	var viewport_width_value: Variant = null
	var viewport_height_value: Variant = null
	var dpi_value: Variant = null
	var scale_value: Variant = null
	var refresh_rate_value: Variant = null
	var timezone_value: Variant = null
	var mouse_value: Variant = null
	var keyboard_value: Variant = null
	var online_value: Variant = null
	var connection_type_value: Variant = null
	var adapter_name_value: Variant = null
	var link_speed_value: Variant = null
	var battery_level_value: Variant = null
	var charging_value: Variant = null
	var os_edition_value: Variant = null
	var os_build_value: Variant = null

	if screen_size.x > 0 and screen_size.y > 0:
		if screen_size.x >= screen_size.y:
			orientation = "landscape"
		else:
			orientation = "portrait"

	if not model_name.is_empty():
		model_value = model_name

	if not processor_name.is_empty():
		processor_name_value = processor_name

	if not rendering_driver.is_empty():
		renderer_value = rendering_driver

	if not gpu_name.is_empty():
		gpu_name_value = gpu_name

	if not gpu_vendor.is_empty():
		gpu_vendor_value = gpu_vendor

	if not rendering_api_version.is_empty():
		api_version_value = rendering_api_version

	var physical_bytes: int = int(memory_info.get("physical", -1))
	var free_bytes: int = int(memory_info.get("free", -1))
	var available_bytes: int = int(memory_info.get("available", -1))

	if physical_bytes > 0:
		physical_memory_value = _bytes_to_mb(physical_bytes)

	if free_bytes >= 0:
		free_memory_value = _bytes_to_mb(free_bytes)

	if available_bytes >= 0:
		available_memory_value = _bytes_to_mb(available_bytes)

	if physical_bytes > 0 and free_bytes >= 0:
		used_memory_value = maxi(0, _bytes_to_mb(physical_bytes - free_bytes))

	if screen_size.x > 0:
		physical_width_value = screen_size.x

	if screen_size.y > 0:
		physical_height_value = screen_size.y

	if viewport_size.x > 0:
		viewport_width_value = viewport_size.x

	if viewport_size.y > 0:
		viewport_height_value = viewport_size.y

	var dpi: int = DisplayServer.screen_get_dpi(screen_id)
	if dpi > 0:
		dpi_value = dpi

	var refresh_rate: float = DisplayServer.screen_get_refresh_rate(screen_id)
	if refresh_rate > 0.0:
		refresh_rate_value = snappedf(refresh_rate, 0.01)

	if OS.get_name() != "Windows":
		var system_scale: float = DisplayServer.screen_get_scale(screen_id)
		if system_scale > 0.0:
			scale_value = snappedf(system_scale, 0.01)

	var timezone_name: String = str(timezone_info.get("name", "")).strip_edges()
	var timezone_bias: int = int(timezone_info.get("bias", 0))

	if not timezone_name.is_empty():
		timezone_value = "%s (%s)" % [
			timezone_name,
			Time.get_offset_string_from_offset_minutes(timezone_bias)
		]

	if OS.get_name() == "Windows" and not windows_profile.is_empty():
		var manufacturer: String = str(windows_profile.get("manufacturer", "")).strip_edges()
		var windows_model: String = str(windows_profile.get("model", "")).strip_edges()
		var os_caption: String = str(windows_profile.get("os_caption", "")).strip_edges()
		var build_number: String = str(windows_profile.get("build_number", "")).strip_edges()
		var adapter_name: String = str(windows_profile.get("adapter_name", "")).strip_edges()
		var physical_media: String = str(windows_profile.get("physical_media_type", "")).strip_edges()
		var link_speed: String = str(windows_profile.get("link_speed", "")).strip_edges()

		if not manufacturer.is_empty():
			manufacturer_value = manufacturer

		if not windows_model.is_empty():
			model_value = windows_model

		if not os_caption.is_empty():
			os_edition_value = os_caption

		if not build_number.is_empty():
			os_build_value = build_number

		device_type_value = _classify_windows_device_type(windows_profile)

		if windows_profile.has("mouse_present"):
			mouse_value = bool(windows_profile.get("mouse_present", false))

		if windows_profile.has("keyboard_present"):
			keyboard_value = bool(windows_profile.get("keyboard_present", false))

		if windows_profile.has("network_online"):
			online_value = bool(windows_profile.get("network_online", false))

		connection_type_value = _normalize_windows_connection_type(physical_media)

		if not adapter_name.is_empty():
			adapter_name_value = adapter_name

		if not link_speed.is_empty():
			link_speed_value = link_speed

		if windows_profile.has("battery_present") and bool(windows_profile.get("battery_present", false)):
			var battery_percent: int = int(windows_profile.get("battery_level", -1))
			var battery_status: int = int(windows_profile.get("battery_status", -1))

			if battery_percent >= 0 and battery_percent <= 100:
				battery_level_value = battery_percent

			charging_value = _windows_battery_charging_value(battery_status)

		var windows_scale: float = float(windows_profile.get("display_scale", 0.0))
		if windows_scale > 0.0:
			scale_value = snappedf(windows_scale, 0.01)

		var driver_selection: Dictionary = _select_windows_gpu_driver(
			windows_profile,
			gpu_name,
			gpu_vendor
		)

		var selected_driver_name: String = str(driver_selection.get("name", "")).strip_edges()
		var selected_driver_version: String = str(driver_selection.get("driver_version", "")).strip_edges()

		if not selected_driver_name.is_empty():
			driver_name_value = selected_driver_name

		if not selected_driver_version.is_empty():
			driver_version_value = selected_driver_version

	elif OS.get_name() == "Linux" or OS.get_name().contains("BSD"):
		var driver_info: PackedStringArray = OS.get_video_adapter_driver_info()

		if driver_info.size() >= 1:
			var driver_name: String = str(driver_info[0]).strip_edges()
			if not driver_name.is_empty():
				driver_name_value = driver_name

		if driver_info.size() >= 2:
			var driver_version: String = str(driver_info[1]).strip_edges()
			if not driver_version.is_empty():
				driver_version_value = driver_version

	var availability: Dictionary = _build_availability(
		device_type_value,
		manufacturer_value,
		driver_version_value,
		scale_value,
		mouse_value,
		keyboard_value,
		online_value,
		connection_type_value,
		battery_level_value,
		charging_value
	)

	var profile_source: String = "godot_core"

	if OS.get_name() == "Windows" and not windows_profile.is_empty():
		profile_source = "godot_core+windows_cim"

	return {
		"profile_source": profile_source,
		"device_type": device_type_value,
		"platform": OS.get_name().to_lower(),
		"manufacturer": manufacturer_value,
		"model": model_value,
		"os": {
			"name": OS.get_name(),
			"edition": os_edition_value,
			"version": OS.get_version(),
			"build_number": os_build_value,
			"architecture": Engine.get_architecture_name()
		},
		"cpu": {
			"architecture": Engine.get_architecture_name(),
			"processor_name": processor_name_value,
			"logical_core_count": OS.get_processor_count()
		},
		"memory": {
			"physical_memory_mb": physical_memory_value,
			"free_memory_mb": free_memory_value,
			"available_memory_mb": available_memory_value,
			"used_physical_memory_mb": used_memory_value
		},
		"graphics": {
			"renderer": renderer_value,
			"rendering_method": RenderingServer.get_current_rendering_method(),
			"gpu_name": gpu_name_value,
			"gpu_vendor": gpu_vendor_value,
			"driver_name": driver_name_value,
			"driver_version": driver_version_value,
			"api_version": api_version_value
		},
		"display": {
			"physical_width_px": physical_width_value,
			"physical_height_px": physical_height_value,
			"game_viewport_width": viewport_width_value,
			"game_viewport_height": viewport_height_value,
			"dpi": dpi_value,
			"scale": scale_value,
			"refresh_rate_hz": refresh_rate_value,
			"orientation": orientation
		},
		"input_capabilities": {
			"touch": DisplayServer.is_touchscreen_available(),
			"mouse": mouse_value,
			"keyboard": keyboard_value,
			"gamepad": Input.get_connected_joypads().size() > 0
		},
		"locale": {
			"language": OS.get_locale_language(),
			"locale": OS.get_locale(),
			"timezone": timezone_value
		},
		"network": {
			"online": online_value,
			"connection_type": connection_type_value,
			"adapter_name": adapter_name_value,
			"link_speed": link_speed_value,
			"server_seen_ip": null
		},
		"battery": {
			"battery_level": battery_level_value,
			"charging": charging_value
		},
		"availability": availability
	}

func _bytes_to_mb(byte_count: int) -> int:
	return int(round(float(byte_count) / BYTES_PER_MB))

func _get_windows_profile() -> Dictionary:
	if OS.get_name() != "Windows":
		return {}

	var now_msec: int = Time.get_ticks_msec()

	if (
		_windows_profile_cached_at_msec >= 0
		and now_msec - _windows_profile_cached_at_msec < WINDOWS_PROFILE_CACHE_MS
	):
		return _windows_profile_cache.duplicate(true)

	var command: String = (
        "$ErrorActionPreference='SilentlyContinue';"
		+ "$ProgressPreference='SilentlyContinue';"
		+ "$cs=Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue;"
		+ "$enc=Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue | Select-Object -First 1;"
		+ "$os=Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue;"
		+ "$bat=Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Select-Object -First 1;"
		+ "$video=@(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object Name,DriverVersion);"
		+ "$mouse=@(Get-CimInstance Win32_PointingDevice -ErrorAction SilentlyContinue).Count -gt 0;"
		+ "$keyboard=@(Get-CimInstance Win32_Keyboard -ErrorAction SilentlyContinue).Count -gt 0;"
		+ "$profile=Get-NetConnectionProfile -ErrorAction SilentlyContinue | Where-Object {($_.IPv4Connectivity -eq 'Internet') -or ($_.IPv6Connectivity -eq 'Internet')} | Select-Object -First 1;"
		+ "$adapter=$null;if($profile){$adapter=Get-NetAdapter -InterfaceIndex $profile.InterfaceIndex -ErrorAction SilentlyContinue};"
		+ "$dpiScale=$null;$dpiValue=(Get-ItemProperty 'HKCU:\\Control Panel\\Desktop\\WindowMetrics' -Name AppliedDPI -ErrorAction SilentlyContinue).AppliedDPI;if($dpiValue -and [int]$dpiValue -gt 0){$dpiScale=[math]::Round(([double]$dpiValue/96.0),2)};"
		+ "$manufacturer=$null;$model=$null;$pcType=$null;$chassis=@();$caption=$null;$build=$null;"
		+ "if($cs){$manufacturer=[string]$cs.Manufacturer;$model=[string]$cs.Model;$pcType=[int]$cs.PCSystemType};"
		+ "if($enc){$chassis=@($enc.ChassisTypes)};"
		+ "if($os){$caption=[string]$os.Caption;$build=[string]$os.BuildNumber};"
		+ "$batteryPresent=$false;$batteryLevel=$null;$batteryStatus=$null;"
		+ "if($bat){$batteryPresent=$true;$batteryLevel=[int]$bat.EstimatedChargeRemaining;$batteryStatus=[int]$bat.BatteryStatus};"
		+ "$online=($null -ne $profile);$adapterName=$null;$physicalMedia=$null;$linkSpeed=$null;"
		+ "if($adapter){$adapterName=[string]$adapter.Name;$physicalMedia=[string]$adapter.PhysicalMediaType;$linkSpeed=[string]$adapter.LinkSpeed};"
		+ "[pscustomobject]@{manufacturer=$manufacturer;model=$model;pc_system_type=$pcType;chassis_types=$chassis;os_caption=$caption;build_number=$build;mouse_present=$mouse;keyboard_present=$keyboard;battery_present=$batteryPresent;battery_level=$batteryLevel;battery_status=$batteryStatus;network_online=$online;adapter_name=$adapterName;physical_media_type=$physicalMedia;link_speed=$linkSpeed;display_scale=$dpiScale;video_controllers=$video}|ConvertTo-Json -Compress -Depth 5"
	)

	var output: Array = []
	var exit_code: int = OS.execute(
		"powershell.exe",
		PackedStringArray([
			"-NoProfile",
			"-NonInteractive",
			"-ExecutionPolicy",
			"Bypass",
			"-Command",
			command
		]),
		output,
		true,
		false
	)

	_windows_profile_cached_at_msec = now_msec
	_windows_profile_cache = {}

	if exit_code != 0 or output.is_empty():
		return {}

	var raw_output: String = str(output[0]).strip_edges()

	if raw_output.is_empty():
		return {}

	var parsed_value: Variant = JSON.parse_string(raw_output)

	if parsed_value is Dictionary:
		_windows_profile_cache = parsed_value
		return _windows_profile_cache.duplicate(true)

	return {}

func _select_windows_gpu_driver(
	profile: Dictionary,
	gpu_name: String,
	gpu_vendor: String
) -> Dictionary:
	var controllers_value: Variant = profile.get("video_controllers", [])
	var controllers: Array = []

	if controllers_value is Array:
		controllers = controllers_value
	elif controllers_value is Dictionary:
		controllers.append(controllers_value)

	var normalized_gpu_name: String = gpu_name.to_lower()
	var normalized_vendor: String = gpu_vendor.to_lower()
	var fallback: Dictionary = {}

	for controller_value in controllers:
		if not controller_value is Dictionary:
			continue

		var controller: Dictionary = controller_value
		var controller_name: String = str(controller.get("Name", controller.get("name", ""))).strip_edges()
		var driver_version: String = str(
			controller.get("DriverVersion", controller.get("driver_version", ""))
		).strip_edges()

		if controller_name.is_empty():
			continue

		var candidate: Dictionary = {
			"name": controller_name,
			"driver_version": driver_version
		}

		if fallback.is_empty() and not controller_name.to_lower().contains("microsoft basic"):
			fallback = candidate

		var normalized_name: String = controller_name.to_lower()

		if not normalized_gpu_name.is_empty():
			if normalized_name.contains(normalized_gpu_name) or normalized_gpu_name.contains(normalized_name):
				return candidate

		if not normalized_vendor.is_empty() and normalized_name.contains(normalized_vendor):
			return candidate

	return fallback

func _classify_windows_device_type(profile: Dictionary) -> Variant:
	var chassis_value: Variant = profile.get("chassis_types", [])
	var chassis_types: Array = []

	if chassis_value is Array:
		chassis_types = chassis_value
	elif chassis_value != null:
		chassis_types.append(chassis_value)

	for chassis_item in chassis_types:
		var chassis_code: int = int(chassis_item)

		if chassis_code == 30 or chassis_code == 32:
			return "tablet"

		if chassis_code in [8, 9, 10, 14, 31]:
			return "laptop"

		if chassis_code in [3, 4, 5, 6, 7, 13, 15, 16, 24, 35, 36]:
			return "desktop"

	var pc_system_type: int = int(profile.get("pc_system_type", 0))

	if pc_system_type == 2:
		return "laptop"

	if pc_system_type == 1 or pc_system_type == 3:
		return "desktop"

	return null

func _normalize_windows_connection_type(physical_media: String) -> Variant:
	var normalized: String = physical_media.to_lower().strip_edges()

	if normalized.is_empty():
		return null

	if normalized.contains("802.11") or normalized.contains("wireless"):
		return "wifi"

	if normalized.contains("802.3") or normalized.contains("ethernet"):
		return "ethernet"

	return null

func _windows_battery_charging_value(status_code: int) -> Variant:
	if status_code in [6, 7, 8, 9]:
		return true

	if status_code in [1, 3, 4, 5, 11]:
		return false

	return null

func _build_availability(
	device_type_value: Variant,
	manufacturer_value: Variant,
	driver_version_value: Variant,
	scale_value: Variant,
	mouse_value: Variant,
	keyboard_value: Variant,
	online_value: Variant,
	connection_type_value: Variant,
	battery_level_value: Variant,
	charging_value: Variant
) -> Dictionary:
	var availability: Dictionary = {
		"network.server_seen_ip": "server_only"
	}

	if device_type_value == null:
		availability["device_type"] = _platform_provider_reason()

	if manufacturer_value == null:
		availability["manufacturer"] = _platform_provider_reason()

	if driver_version_value == null:
		availability["graphics.driver_version"] = "not_reported"

	if scale_value == null:
		availability["display.scale"] = "not_reported"

	if mouse_value == null:
		availability["input_capabilities.mouse"] = _platform_provider_reason()

	if keyboard_value == null:
		availability["input_capabilities.keyboard"] = _platform_provider_reason()

	if online_value == null:
		availability["network.online"] = _platform_provider_reason()

	if connection_type_value == null:
		availability["network.connection_type"] = "not_detected_or_not_supported"

	if battery_level_value == null:
		if OS.get_name() == "Windows" and not _windows_profile_cache.is_empty():
			if _windows_profile_cache.has("battery_present"):
				if not bool(_windows_profile_cache.get("battery_present", false)):
					availability["battery.battery_level"] = "no_battery_device"
				else:
					availability["battery.battery_level"] = "not_reported"
			else:
				availability["battery.battery_level"] = "provider_unavailable"
		else:
			availability["battery.battery_level"] = _platform_provider_reason()

	if charging_value == null:
		if availability.has("battery.battery_level"):
			availability["battery.charging"] = availability["battery.battery_level"]
		else:
			availability["battery.charging"] = "not_reported"

	return availability

func _platform_provider_reason() -> String:
	if OS.get_name() == "Windows":
		return "windows_provider_unavailable"

	if OS.get_name() == "Android":
		return "android_runtime_provider_pending"

	return "not_supported_on_platform"
