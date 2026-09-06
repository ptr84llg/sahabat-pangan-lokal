class_name IdUtil
extends RefCounted

static func uuid_v4() -> String:
    var crypto := Crypto.new()
    var bytes := crypto.generate_random_bytes(16)
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    var hex := bytes.hex_encode()
    return "%s-%s-%s-%s-%s" % [
        hex.substr(0, 8),
        hex.substr(8, 4),
        hex.substr(12, 4),
        hex.substr(16, 4),
        hex.substr(20, 12)
    ]
