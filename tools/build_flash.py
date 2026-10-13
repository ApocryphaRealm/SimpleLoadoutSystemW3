"""Build the loadout column into the game's inventory menu (between the ARMOR panel and the paperdoll).

    python tools/build_flash.py [--redkit "<The Witcher 3 REDkit folder>"] [--ffdec "<ffdec-cli.exe>"]

The same pipeline as Unbind Vanilla Controls W3's tools/build_flash.py (same author):
1. takes CD PROJEKT RED's source movie from REDkit's depot (r4data\\gameplay\\gui_new\\swf\\inventory\\panel_inventory.swf);
2. decompiles only red.game.witcher3.menus.inventory_menu.MenuInventory with FFDec and inserts flash/sls_column.as.txt
   plus the hook lines below, each at an anchor that must be found exactly once (else the build stops);
3. recompiles that class into the movie (FFDec -importScript);
4. REDkit's wcc_lite: swfimport (movie -> .redswf), pack (-> blob0.bundle) and metadatastore, into
   dist\\Mods\\modSimpleLoadoutSystem\\content - this mod's own bundle, never shared with another mod's.

Only our own code is kept in the repository; CD PROJEKT RED's movie and its decompiled class are read from the player's
REDkit install at build time and never committed. wcc_lite runs with -agreetoterms: the owner accepted the Witcher III
Modding Tool rules on 2026-10-06; they ask every distributed file made with the tool to carry a README line, which
dist\\README.txt starts with.

Paths: --redkit / W3_REDKIT, else Steam's library folders ("The Witcher 3 REDkit"); --ffdec / FFDEC, else
%USERPROFILE%\\tools\\ffdec\\ffdec-cli.exe, else FFDec's own install folder. Work files go to build\\flash (ignored by git).
"""
import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import winreg
import zlib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(REPO, "build", "flash")
CONTENT = os.path.join(REPO, "dist", "Mods", "modSimpleLoadoutSystem", "content")
CLASS = "red.game.witcher3.menus.inventory_menu.MenuInventory"
CLASS_FILE = "MenuInventory.as"
CLASS_REL = os.path.join("red", "game", "witcher3", "menus", "inventory_menu", CLASS_FILE)
SWF_DIR = os.path.join("gameplay", "gui_new", "swf", "inventory")
SWF_NAME = "panel_inventory"
SWF_REL = os.path.join("r4data", SWF_DIR, SWF_NAME + ".swf")
OURS = os.path.join("flash", "sls_column.as.txt")
DEPOT_OUT = "sls_build"   # a folder of ours inside REDkit's workspace, removed after the build

# (anchor, text inserted, where): every anchor must occur exactly once in FFDec's decompiled class
HOOKS = [
    ("import flash.events.Event;\n",
     "import flash.events.MouseEvent;\n   import flash.text.TextFormat;\n   ", "before"),
    # AFTER the menu tells the game it is ready (OnConfigUI fills the grid and the character preview): nothing of ours may
    # run before it - 1.0.1's first build put the column before it, the column threw, and the inventory stayed empty
    ("         dispatchEvent(new GameEvent(GameEvent.CALL,\"OnConfigUI\"));\n",
     "         this.slsSafeInit();\n", "after"),
    ("      override protected function handleInputNavigate(event:InputEvent) : void\n      {\n",
     "         if(this.slsSafeHandleInput(event))\n         {\n            return;\n         }\n", "after"),
]


def steam_libraries():
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
            steam = winreg.QueryValueEx(k, "SteamPath")[0]
        vdf = open(os.path.join(steam, "steamapps", "libraryfolders.vdf"), encoding="utf-8").read()
        return [p.replace("\\\\", "\\") for p in re.findall(r'"path"\s+"([^"]+)"', vdf)]
    except OSError:
        return []


def find_redkit(arg):
    for cand in [arg, os.environ.get("W3_REDKIT")] + [os.path.join(l, "steamapps", "common", "The Witcher 3 REDkit") for l in steam_libraries()]:
        if cand and os.path.isfile(os.path.join(cand, SWF_REL)):
            return cand
    sys.exit("REDkit not found: pass --redkit or set W3_REDKIT")


def find_ffdec(arg):
    for cand in [arg, os.environ.get("FFDEC"), os.path.join(os.environ.get("USERPROFILE", ""), "tools", "ffdec", "ffdec-cli.exe"),
                 os.path.join(os.environ.get("ProgramFiles(x86)", ""), "FFDec", "ffdec-cli.exe")]:
        if cand and os.path.isfile(cand):
            return cand
    sys.exit("FFDec not found: pass --ffdec or set FFDEC")


def run(cmd, cwd=None, timeout=900, ok_text=None):
    print("  >", " ".join(os.path.basename(c) if i == 0 else c for i, c in enumerate(cmd)))
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace", timeout=timeout)
    out = p.stdout + p.stderr
    if p.returncode != 0 or (ok_text and ok_text not in out):
        print(out[-4000:])
        sys.exit(f"failed: {os.path.basename(cmd[0])} {cmd[1]}")
    return out


def wcc(redkit, args, timeout=900):
    exe = os.path.join(redkit, "bin", "x64_RedKit", "wcc_lite.exe")
    out = run([exe] + args + ["-agreetoterms"], cwd=os.path.dirname(exe), timeout=timeout)
    errs = [l for l in out.splitlines() if "[Error][WCC]" in l]
    if errs:
        print("\n".join(errs))
        sys.exit(f"wcc_lite {args[0]} reported errors")
    return out


def _crc(b):
    return zlib.crc32(b) & 0xFFFFFFFF


def _cr2w_check(d):
    """Every CRC a W3 CR2W file carries, recomputed: the header (first 0xA0 bytes with the field set to 0xDEADBEEF),
    each table's and each export's (plain CRC32). Returns the export table [(entry offset, size, data offset)]."""
    if d[:4] != b"CR2W":
        sys.exit("strip: not a CR2W file")
    h = bytearray(d[:0xA0])
    struct.pack_into("<I", h, 0x20, 0xDEADBEEF)
    if _crc(bytes(h)) != struct.unpack_from("<I", d, 0x20)[0]:
        sys.exit("strip: header CRC does not match the known recipe - format changed, not patching")
    eo, ec, ecrc = struct.unpack_from("<III", d, 0x28 + 12 * 4)
    if _crc(d[eo:eo + 24 * ec]) != ecrc:
        sys.exit("strip: export table CRC mismatch - not patching")
    exports = []
    for k in range(ec):
        e = eo + 24 * k
        size, off, xcrc = struct.unpack_from("<I", d, e + 8)[0], struct.unpack_from("<I", d, e + 12)[0], struct.unpack_from("<I", d, e + 20)[0]
        if _crc(d[off:off + size]) != xcrc:
            sys.exit(f"strip: export {k} CRC mismatch - not patching")
        exports.append((e, size, off))
    return exports


def strip_import_path(redswf):
    """swfimport records the absolute path of the source .swf (the CSwfResource's import-file String property, the first
    property of the first export) - our build folder. It is editor-only (REDkit's re-import); the game never reads it.
    Rewrite it to the bare file name and fix every size, offset and CRC after it, then check the result again."""
    d = bytearray(open(redswf, "rb").read())
    exports = _cr2w_check(bytes(d))
    e0, size0, off0 = exports[0]
    p = off0 + 1                                    # export data starts with a zero byte, then the properties
    name, typ, psize = struct.unpack_from("<HHI", d, p)
    v = p + 8
    b0, b1 = d[v], d[v + 1]
    if not (b0 & 0x80 and b0 & 0x40 and not b1 & 0x80):
        sys.exit("strip: first property is not a long ANSI string - not patching")
    n = (b0 & 0x3F) | (b1 << 6)
    old = bytes(d[v + 2:v + 2 + n])
    # the property's size counts its own 4 bytes and the value, not the name and type before it
    if psize != 4 + 2 + n or not re.match(rb"^[A-Za-z]:\\.*\.swf$", old):
        sys.exit(f"strip: first property is not the import path ({old[:40]!r}) - not patching")
    new = old.rsplit(b"\\", 1)[-1]
    if len(new) > 0x3F:
        sys.exit("strip: file name too long for a one-byte length")
    prop = struct.pack("<HHI", name, typ, 4 + 1 + len(new)) + bytes([0x80 | len(new)]) + new
    delta = (4 + psize) - len(prop)
    d[p:p + 4 + psize] = prop
    eo = struct.unpack_from("<I", d, 0x28 + 12 * 4)[0]
    for k, (e, size, off) in enumerate(exports):
        if k == 0:
            struct.pack_into("<I", d, e + 8, size - delta)
        elif off > off0:
            struct.pack_into("<I", d, e + 12, off - delta)
    for k, (e, size, off) in enumerate(exports):
        size, off = struct.unpack_from("<I", d, e + 8)[0], struct.unpack_from("<I", d, e + 12)[0]
        struct.pack_into("<I", d, e + 20, _crc(bytes(d[off:off + size])))
    ec = len(exports)
    struct.pack_into("<I", d, 0x28 + 12 * 4 + 8, _crc(bytes(d[eo:eo + 24 * ec])))
    for o in (0x18, 0x1C):                          # file size, buffer size (equal: no external buffers)
        struct.pack_into("<I", d, o, len(d))
    h = bytearray(d[:0xA0])
    struct.pack_into("<I", h, 0x20, 0xDEADBEEF)
    struct.pack_into("<I", d, 0x20, _crc(bytes(h)))
    _cr2w_check(bytes(d))
    if re.search(rb"[A-Za-z]:\\", bytes(d[:off0 + 64])) or b"Claude" in d:
        sys.exit("strip: a build path is still in the movie")
    open(redswf, "wb").write(d)
    print(f"ok    import path stripped ({old.decode('ascii', 'replace')[:3]}... -> {new.decode()})")


def patch(text):
    ours = open(os.path.join(REPO, OURS), encoding="utf-8").read()
    text = text.replace("\r\n", "\n")
    for anchor, add, where in HOOKS:
        n = text.count(anchor)
        if n != 1:
            sys.exit(f"anchor found {n} times (the game's class changed?): {anchor[:60]!r}")
        text = text.replace(anchor, add + anchor if where == "before" else anchor + add)
    end = text.rstrip().rfind("}")          # the package's brace
    end = text.rstrip()[:end].rstrip().rfind("}")   # the class's brace
    return text[:end] + ours + "\n" + text[end:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--redkit")
    ap.add_argument("--ffdec")
    ap.add_argument("--movie-only", action="store_true", help="stop after the recompiled .swf (no wcc_lite)")
    args = ap.parse_args()
    redkit = find_redkit(args.redkit)
    ffdec = find_ffdec(args.ffdec)
    shutil.rmtree(BUILD, ignore_errors=True)
    os.makedirs(BUILD)
    src = os.path.join(BUILD, SWF_NAME + ".swf")
    shutil.copyfile(os.path.join(redkit, SWF_REL), src)

    print("1. decompile", CLASS)
    exp = os.path.join(BUILD, "export")
    run([ffdec, "-selectclass", CLASS, "-export", "script", exp, src])
    found = [os.path.join(r, f) for r, _, fs in os.walk(exp) for f in fs if f == CLASS_FILE]
    if len(found) != 1:
        sys.exit(f"decompiled class not found ({found})")
    patched = patch(open(found[0], encoding="utf-8").read())
    imp = os.path.join(BUILD, "import")
    os.makedirs(os.path.dirname(os.path.join(imp, CLASS_REL)))
    open(os.path.join(imp, CLASS_REL), "w", encoding="utf-8", newline="\n").write(patched)

    print("2. recompile into the movie")
    swfdir = os.path.join(BUILD, "swf")
    os.makedirs(swfdir)
    out_swf = os.path.join(swfdir, SWF_NAME + ".swf")
    out = run([ffdec, "-importScript", src, out_swf, imp])
    if not os.path.isfile(out_swf) or re.search(r"(?i)error|exception", out):
        print(out[-4000:])
        sys.exit("FFDec did not compile the class")
    print(f"ok    {out_swf} ({os.path.getsize(out_swf)} bytes)")
    if args.movie_only:
        return

    print("3. wcc_lite swfimport / pack / metadatastore")
    work = os.path.join(redkit, "bin", "workspace", DEPOT_OUT)
    shutil.rmtree(work, ignore_errors=True)
    try:
        wcc(redkit, ["swfimport", f"-fromAbsPath={swfdir}\\", f"-toDepotPath={DEPOT_OUT}\\{SWF_DIR}\\"])
        redswf = os.path.join(work, SWF_DIR, SWF_NAME + ".redswf")
        if not os.path.isfile(redswf):
            sys.exit("swfimport wrote no .redswf")
        unc = os.path.join(BUILD, "uncooked", SWF_DIR)
        os.makedirs(unc)
        shutil.copyfile(redswf, os.path.join(unc, SWF_NAME + ".redswf"))
        strip_import_path(os.path.join(unc, SWF_NAME + ".redswf"))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    os.makedirs(CONTENT, exist_ok=True)
    for f in ("blob0.bundle", "metadata.store"):
        if os.path.exists(os.path.join(CONTENT, f)):
            os.remove(os.path.join(CONTENT, f))
    wcc(redkit, ["pack", f"-dir={os.path.join(BUILD, 'uncooked')}\\", f"-outdir={CONTENT}\\"])
    wcc(redkit, ["metadatastore", f"-path={CONTENT}\\"])
    for f in ("blob0.bundle", "metadata.store"):
        p = os.path.join(CONTENT, f)
        if not os.path.isfile(p):
            sys.exit(f"{f} was not written")
        print(f"ok    {p} ({os.path.getsize(p)} bytes)")


if __name__ == "__main__":
    main()
