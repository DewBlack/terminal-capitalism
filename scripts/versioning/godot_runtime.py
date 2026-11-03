"""Read only bounded primitive Godot ECFG metadata from actual Android exports."""
import struct
import zipfile

MAX_BYTES = 8 * 1024 * 1024


def pck_project(path):
    """Standalone unencrypted PCK v2/v3/v4, per Godot 4.6/4.7 core/io/file_access_pack.cpp."""
    with open(path, "rb") as stream:
        size = stream.seek(0, 2); stream.seek(0)
        def take(length):
            if length > size - stream.tell(): raise ValueError("Truncated PCK")
            data = stream.read(length)
            if len(data) != length: raise ValueError("Truncated PCK")
            return data
        def u32(): return struct.unpack("<I", take(4))[0]
        def u64(): return struct.unpack("<Q", take(8))[0]
        if take(4) != b"GDPC": raise ValueError("Expected a standalone Godot PCK")
        version = u32(); take(12); flags = u32(); base = u64()
        if flags & 5: raise ValueError("Encrypted/sparse PCK requires an explicit adapter")
        if version in (3, 4):
            directory = u64()
            if directory >= size: raise ValueError("PCK directory outside artifact")
            stream.seek(directory)
        elif version == 2: take(64)
        else: raise ValueError("Unsupported PCK version")
        count = u32()
        if count > size // 40: raise ValueError("Invalid PCK file count")
        found = []
        for _ in range(count):
            length = u32()
            if length > 8192: raise ValueError("Oversized PCK file name")
            name = take(length).rstrip(b"\0").decode("utf-8")
            offset, length = u64() + base, u64(); take(16); entry_flags = u32()
            if name in ("res://project.binary", "project.binary"):
                if entry_flags or length > MAX_BYTES or offset + length > size: raise ValueError("Invalid/encrypted PCK project.binary")
                found.append((offset, length))
        if len(found) != 1: raise ValueError("Expected one PCK project.binary")
        stream.seek(found[0][0]); return take(found[0][1])


def ecfg_values(data):
    if len(data) > MAX_BYTES or data[:4] != b"ECFG":
        raise ValueError("Invalid or oversized Godot project.binary")
    position = 4
    def take(length):
        nonlocal position
        if length > len(data) - position:
            raise ValueError("Truncated Godot project.binary")
        value = data[position:position + length]; position += length
        return value
    def uint32(): return struct.unpack("<I", take(4))[0]
    count = uint32()
    if count > (len(data) - position) // 8: raise ValueError("Invalid Godot setting count")
    values = {}
    for _ in range(count):
        length = uint32()
        if length > 1024: raise ValueError("Oversized Godot setting key")
        key = take(length).decode("utf-8")
        if key in values: raise ValueError("Duplicate Godot project setting")
        values[key] = take(uint32())
    if position != len(data): raise ValueError("Trailing Godot project.binary bytes")
    return values


def primitive(value):
    if len(value) < 4: raise ValueError("Truncated Godot Variant")
    kind = struct.unpack_from("<I", value)[0]
    if kind == 4 and len(value) >= 8:
        length = struct.unpack_from("<I", value, 4)[0]
        if len(value) != 8 + ((length + 3) & ~3) or any(value[8 + length:]):
            raise ValueError("Invalid Godot string Variant")
        return value[8:8 + length].decode("utf-8")
    if kind == 2 and len(value) == 8: return struct.unpack_from("<i", value, 4)[0]
    if kind == (2 | (1 << 16)) and len(value) == 12: return struct.unpack_from("<q", value, 4)[0]
    raise ValueError("Expected a primitive Godot string/integer Variant")


def metadata(artifact):
    if artifact.suffix.lower() == ".pck":
        values = ecfg_values(pck_project(artifact))
        return {"runtime_version": primitive(values["application/config/version"]), "runtime_version_code": None}
    with zipfile.ZipFile(artifact) as bundle:
        projects = [entry for entry in bundle.infolist() if entry.filename == "assets/project.binary" or entry.filename.endswith("/assets/project.binary")]
        if len(projects) != 1 or projects[0].file_size > MAX_BYTES:
            raise ValueError("Expected one bounded exported Godot project.binary")
        with bundle.open(projects[0]) as stream: values = ecfg_values(stream.read(MAX_BYTES + 1))
        for entry in bundle.infolist():
            if entry.filename == "assets/override.cfg" or entry.filename.endswith("/assets/override.cfg"):
                if entry.file_size > MAX_BYTES: raise ValueError("Oversized exported override.cfg")
                content = bundle.read(entry).decode("utf-8-sig")
                if "config/version" in content or "build/version_code" in content or "config/project_settings_override" in content:
                    raise ValueError("Exported override.cfg changes version metadata")
    for key in values:
        if key.startswith("application/config/version.") or key == "application/config/project_settings_override":
            raise ValueError("Exported feature/project overrides can change runtime version")
    return {"runtime_version": primitive(values["application/config/version"]),
            "runtime_version_code": primitive(values["pallobby/build/version_code"])}
