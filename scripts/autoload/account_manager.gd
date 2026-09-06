extends Node

const MODE_GUEST: String = "guest"
const MODE_GOOGLE: String = "google"

func ensure_local_identity(existing: Dictionary, installation_id: String) -> Dictionary:
    var normalized: Dictionary = existing.duplicate(true)
    var mode: String = str(normalized.get("mode", "")).strip_edges()
    var identity_id: String = str(normalized.get("identity_id", "")).strip_edges()

    if mode == MODE_GOOGLE and identity_id.begins_with("USR-"):
        normalized["installation_id"] = installation_id
        return normalized

    if mode == MODE_GUEST and identity_id.begins_with("GST-"):
        normalized["installation_id"] = installation_id
        if not normalized.has("provider"):
            normalized["provider"] = null
        if not normalized.has("linked_guest_id"):
            normalized["linked_guest_id"] = null
        return normalized

    return {
        "mode": MODE_GUEST,
        "identity_id": "GST-" + IdUtil.uuid_v4(),
        "provider": null,
        "linked_guest_id": null,
        "installation_id": installation_id,
        "created_at_unix": Time.get_unix_time_from_system()
    }

func snapshot_identity(identity: Dictionary) -> Dictionary:
    return identity.duplicate(true)
