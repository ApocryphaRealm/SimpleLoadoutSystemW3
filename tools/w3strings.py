"""Read and write The Witcher 3's .w3strings string tables (format as found in the 5.0 game files).

  "RTSW"  u32 version (164 = UTF-8 text)  u16 key1
  bit6 count, then entries  {u32 id ^ magic, u32 offset, u32 length}   offset/length in text units
  bit6 count, then keys     {u32 hash, u32 id ^ magic}
  bit6 count of text units, then the text buffer: each string XORed, followed by one NUL unit
  u16 key2

(key1 << 16 | key2) names the language and maps to a magic through the table below; 0 means the file is not obfuscated
(the game's own cn.w3strings is written that way). Each string is XORed with (length + 1) * k, k starting at
(magic >> 8) & 0xFFFF and rotating left by one bit per unit.

The key hash is Java's String.hashCode over the UTF-16 units of the LOWER-CASED key: h = h * 31 + unit, no seed.

Written from the format notes in the logic library (AMF Witcher 3 M4); the reader is a port of the Apocrypha Menu
Framework's own ReadW3Strings. Our files are written with key 0, so the text is stored as plain UTF-8.
"""
import struct

MAGIC = {
    0x00000000: 0x00000000, 0x24987354: 0x21793217, 0x75886138: 0x42791159, 0x43975139: 0x79321793,
    0x18796651: 0x42387566, 0x23863176: 0x75921975, 0x42378932: 0x67823218, 0x45931894: 0x12375973,
    0x54834893: 0x59825646, 0x83496237: 0x73946816, 0x63481486: 0x42386347, 0x18632176: 0x16875467,
}


def key_hash(key):
    h = 0
    b = key.lower().encode("utf-16-le")
    for i in range(0, len(b), 2):
        h = (h * 31 + (b[i] | b[i + 1] << 8)) & 0xFFFFFFFF
    return h


def _read_bit6(d, p):
    b = d[p]
    p += 1
    v = b & 0x3F
    if b & 0x40:
        shift = 6
        while True:
            b = d[p]
            p += 1
            v |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                break
    return v, p


def _write_bit6(v):
    out = bytearray()
    first = v & 0x3F
    v >>= 6
    out.append(first | (0x40 if v else 0))
    while v:
        b = v & 0x7F
        v >>= 7
        out.append(b | (0x80 if v else 0))
    return bytes(out)


def _xor(raw, length, magic, unit):
    raw = bytearray(raw)
    k = (magic >> 8) & 0xFFFF
    for i in range(length):
        ck = (length + 1) * k
        if unit == 2:
            raw[2 * i] ^= ck & 0xFF
            raw[2 * i + 1] ^= (ck >> 8) & 0xFF
        else:
            raw[i] ^= ck & 0xFF
        k = ((k << 1) | (k >> 15)) & 0xFFFF
    return bytes(raw)


def read(path):
    """{key hash: text} for every keyed string in the file."""
    d = open(path, "rb").read()
    if d[:4] != b"RTSW":
        raise ValueError(f"{path}: not a w3strings file")
    version = struct.unpack_from("<I", d, 4)[0]
    key1 = struct.unpack_from("<H", d, 8)[0]
    key2_at = len(d) - 2
    key2 = struct.unpack_from("<H", d, key2_at)[0]
    magic = MAGIC[(key1 << 16) | key2]
    p = 10
    n_entries, p = _read_bit6(d, p)
    entries_at = p
    p += 12 * n_entries
    n_keys, p = _read_bit6(d, p)
    keys_at = p
    p += 8 * n_keys
    n_units, p = _read_bit6(d, p)
    start = p
    unit = 1 if version >= 164 else 2
    if unit == 2 and n_units and start + 2 * n_units != key2_at and start + n_units == key2_at:
        unit = 1
    id_to_hashes = {}
    for i in range(n_keys):
        h, sid = struct.unpack_from("<II", d, keys_at + 8 * i)
        id_to_hashes.setdefault(sid ^ magic, []).append(h)
    out = {}
    for i in range(n_entries):
        sid, off, length = struct.unpack_from("<III", d, entries_at + 12 * i)
        sid ^= magic
        if sid not in id_to_hashes:
            continue
        raw = _xor(d[start + off * unit:start + (off + length) * unit], length, magic, unit)
        text = raw.decode("utf-16-le" if unit == 2 else "utf-8", "replace")
        for h in id_to_hashes[sid]:
            out[h] = text
    return out


def write(path, strings):
    """strings: list of (id, key, text). Written as version 164, key 0 (plain UTF-8)."""
    buf = bytearray()
    entries = bytearray()
    keys = bytearray()
    for sid, key, text in sorted(strings):
        data = text.encode("utf-8")
        entries += struct.pack("<III", sid, len(buf), len(data))
        buf += data + b"\0"
    # The key table is SORTED BY HASH (unsigned), as in every game file: the game binary-searches it. Written in id
    # order, 1.0.0's table let the search find some keys and miss others - "##uvc_choice_up" on the Key Bindings page
    # while "Sailing - Stop / Reverse" from the same file showed (Main Agent's run, 2026-10-06).
    for sid, key, text in sorted(strings, key=lambda s: key_hash(s[1])):
        keys += struct.pack("<II", key_hash(key), sid)
    out = bytearray(b"RTSW") + struct.pack("<IH", 164, 0)
    out += _write_bit6(len(strings)) + entries
    out += _write_bit6(len(strings)) + keys
    out += _write_bit6(len(buf)) + buf
    out += struct.pack("<H", 0)
    open(path, "wb").write(bytes(out))
