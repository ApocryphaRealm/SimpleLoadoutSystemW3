"""Package Simple Loadout System (The Witcher 3) for mod.io - the game's in-game Mods browser (cross-platform mod support).

    python tools/package_modio.py [--redkit <REDkit folder>] [--stage "7. current test builds"]

What mod.io installs is ONE folder: the game extracts the ZIP to C:\\Users\\Public\\mod.io\\8254\\mods\\<mod id>\\ and mounts
that folder as a mod named modio_<id>, reading <id>\\content\\ (witcher3.exe 5.01: "modio_" + "%s%s\\content\\", "info.json",
"missingScriptBlob"). So the ZIP's root holds content\\ directly - not Mods\\modSimpleLoadoutSystem\\content\\ (the 1.0.0
draft had that extra level). No bin\\config: mod.io cannot install a menu XML, so the Loadouts slider does not exist in
this build and the column shows ten loadouts (SimpleLoadoutSystem.ws SLS_Count reads a missing settings group as 10 and,
since 1.0.3, writes nothing).

The ZIP holds, every path lower case:
    content\\info.json                      name, version, gameVersion "29", useLooseScripts false (the REDkit fields)
    content\\precompiled.rsblob             the script cooked by REDkit: wcc_lite compilescripts <game scripts> -patch=<ours>
    content\\scripts\\local\\simpleloadoutsystem.ws   the same script, loose (PC script merging reads it)
    content\\blob0.bundle, metadata.store   the inventory movie (tools/build_flash.py)
    content\\*.w3strings                    the column's text, eleven languages
    readme.txt, license.txt, notice.txt

It is built from the repo's dist\\ at the version in VERSION (version-gate.ps1 writes it) and lands in
<stage>\\Witcher 3 - Simple Loadout System\\mod.io\\Simple Loadout System <version> (mod.io)\\ with its .zip beside it.
"""
import argparse
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
SRC = os.path.join(REPO, "dist", "Mods", "modSimpleLoadoutSystem", "content")
PROJECT = os.path.dirname(os.path.dirname(REPO))          # D:\Claude output (the repo sits in "6. current wip mods")
GAME_DISTRO_FOLDER = "Witcher 3 - Simple Loadout System"

DESCRIPTION = ("Loadouts inside the inventory, built for the controller: \"Always worn\" and ten loadout boxes between the "
               "item grid and the equipment slots. Switching stores the worn gear in the stash and puts the next "
               "loadout's gear on.")


def steam_libraries():
    """Steam's own folder (from the registry, else the default) and every library its libraryfolders.vdf lists."""
    roots = [os.path.join(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"), "Steam")]
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
            roots.insert(0, os.path.normpath(winreg.QueryValueEx(k, "SteamPath")[0]))
    except OSError:
        pass
    out = list(roots)
    for r in roots:
        vdf = os.path.join(r, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            for m in re.finditer(r'"path"\s+"([^"]+)"', open(vdf, encoding="utf-8", errors="replace").read()):
                out.append(m.group(1).replace("\\\\", "\\"))
    return out


def find_dir(arg, env, name, probe):
    for cand in [arg, os.environ.get(env)] + [os.path.join(l, "steamapps", "common", name) for l in steam_libraries()]:
        if cand and os.path.exists(os.path.join(cand, probe)):
            return cand
    sys.exit(f"{name} not found: pass it on the command line or set {env}")


def cook_blob(redkit, game, script_dir, out_file, work):
    """REDkit's own script blob: compilescripts over the game's scripts with ours as the patch (output is a .rsblob)."""
    patch = os.path.join(work, "patch")
    shutil.copytree(script_dir, patch)
    outdir = os.path.join(work, "out")
    exe = os.path.join(redkit, "bin", "x64_RedKit", "wcc_lite.exe")
    args = [exe, "compilescripts", os.path.join(game, "content", "content0", "scripts") + "\\",
            "-patch=" + patch + "\\", "-out=" + outdir, "-agreetoterms"]
    print("  > wcc_lite " + " ".join(args[1:]))
    p = subprocess.run(args, cwd=os.path.dirname(exe), capture_output=True, text=True, errors="replace", timeout=900)
    log = p.stdout + p.stderr
    errors = [l for l in log.splitlines() if "[Error][WCC]" in l and "gameconf.cfg" not in l]
    blob = os.path.join(outdir, "blob.rsblob")
    if errors or "Success! Patch scripts blob saved" not in log or not os.path.isfile(blob):
        print("\n".join(errors or log.splitlines()[-20:]))
        sys.exit("the script blob was not cooked - the package is not built")
    shutil.copyfile(blob, out_file)
    print(f"  cooked {os.path.basename(out_file)} ({os.path.getsize(out_file)} bytes)")


def readme(version):
    text = open(os.path.join(REPO, "dist", "README.txt"), encoding="utf-8").read()
    text = re.sub(r"(?m)^Version \d+\.\d+\.\d+", f"Version {version} (mod.io)", text, count=1)
    settings = re.search(r"(?ms)^SETTINGS\n.*?(?=^\n\n|^INSTALL\n)", text)
    if not settings:
        sys.exit("README.txt has no SETTINGS section to replace")
    text = text.replace(settings.group(0), (
        "SETTINGS\n"
        "This is the mod.io version, installed from the game's own Mods menu. It has no settings page: mod.io installs a\n"
        "single mod folder and cannot add the menu file the settings need. The column always shows \"Always worn\" and ten\n"
        "loadouts. The Loadouts slider (1 to 10 boxes, on Options > Mods and on the Apocrypha Menu Framework's page) exists\n"
        "only in the Nexus Mods version.\n"))
    install = re.search(r"(?ms)^INSTALL\n.*?(?=^The column's text)", text)
    if install:
        text = text.replace(install.group(0), (
            "INSTALL\n"
            "Subscribe in the game's Mods menu (signed in to mod.io), or on mod.io; the game installs it. Do not also install the\n"
            "Nexus Mods version: the two are the same mod and must not load together. It replaces the inventory screen's movie\n"
            "(panel_inventory.redswf), so it does not combine with another mod that replaces that same file.\n\n"))
    text = text.replace("(LICENSE, NOTICE.md)", "(license.txt, notice.txt)")
    return text.replace("\r\n", "\n").replace("\n", "\r\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--redkit")
    ap.add_argument("--game")
    ap.add_argument("--stage", default="7. current test builds")
    a = ap.parse_args()

    version = open(os.path.join(REPO, "VERSION"), encoding="utf-8").read().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or version == "0.0.0":
        sys.exit(f"VERSION is '{version}' - issue a number with version-gate.ps1 -Action bump first")
    for f in ("blob0.bundle", "metadata.store"):
        if not os.path.isfile(os.path.join(SRC, f)):
            sys.exit(f"{f} is missing - run tools/build_flash.py first")
    redkit = find_dir(a.redkit, "W3_REDKIT", "The Witcher 3 REDkit", os.path.join("bin", "x64_RedKit", "wcc_lite.exe"))
    game = find_dir(a.game, "W3_GAME", "The Witcher 3", os.path.join("content", "content0", "scripts"))

    # a "mod.io" subfolder, so the version gate does not read it as a second test build of the same number
    root = os.path.join(PROJECT, a.stage, GAME_DISTRO_FOLDER, "mod.io")
    name = f"Simple Loadout System {version} (mod.io)"
    pkg = os.path.join(root, name)
    if os.path.exists(pkg) or os.path.exists(pkg + ".zip"):
        sys.exit(f"{pkg} already exists - a version is packaged once")
    content = os.path.join(pkg, "content")
    os.makedirs(content)

    # every file of the mod's content folder, lower-cased; the loose script kept beside the blob
    for src in glob.glob(os.path.join(glob.escape(SRC), "**", "*"), recursive=True):
        if os.path.isfile(src):
            rel = os.path.relpath(src, SRC).lower()
            dst = os.path.join(content, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(src, dst)

    work = os.path.join(REPO, "build", "modio_blob")
    shutil.rmtree(work, ignore_errors=True)
    os.makedirs(work)
    cook_blob(redkit, game, os.path.join(content, "scripts"), os.path.join(content, "precompiled.rsblob"), work)

    info = {
        "name": "modsimpleloadoutsystem",
        "modName": "Simple Loadout System",
        "version": version,
        "gameVersion": "29",
        "description": DESCRIPTION,
        "author": "ApocryphaRealm",
        "idSpace": 10000000,
        "workshopId": 0,
        "succesfullyCooked": True,
        "dependencies": [],
        "useLooseScripts": False,
    }
    with open(os.path.join(content, "info.json"), "w", encoding="utf-8", newline="\r\n") as f:
        json.dump(info, f, indent=4, ensure_ascii=False)
        f.write("\n")

    with open(os.path.join(pkg, "readme.txt"), "w", encoding="utf-8", newline="") as f:
        f.write(readme(version))
    shutil.copyfile(os.path.join(REPO, "LICENSE"), os.path.join(pkg, "license.txt"))
    shutil.copyfile(os.path.join(REPO, "NOTICE.md"), os.path.join(pkg, "notice.txt"))

    # the ZIP: the folder's contents at its root, every name lower case (checked, not assumed)
    names = []
    with zipfile.ZipFile(pkg + ".zip", "w", zipfile.ZIP_DEFLATED) as z:
        for src in sorted(glob.glob(os.path.join(glob.escape(pkg), "**", "*"), recursive=True)):
            if os.path.isfile(src):
                arc = os.path.relpath(src, pkg).replace("\\", "/")
                if arc != arc.lower():
                    sys.exit(f"upper case in the ZIP path {arc}")
                z.write(src, arc)
                names.append(arc)
    for need in ("content/info.json", "content/precompiled.rsblob", "content/blob0.bundle", "content/metadata.store",
                 "content/scripts/local/simpleloadoutsystem.ws", "content/en.w3strings"):
        if need not in names:
            sys.exit(f"{need} is missing from the ZIP")
    if any(n.startswith("bin/") or n.endswith(".xml") for n in names):
        sys.exit("a bin/ path or a menu XML reached the mod.io ZIP")
    print(f"packaged {pkg}.zip ({len(names)} files, {os.path.getsize(pkg + '.zip')} bytes)")


if __name__ == "__main__":
    main()
