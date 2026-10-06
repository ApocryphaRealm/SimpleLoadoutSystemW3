"""Write the mod's string tables: dist\\Mods\\modSimpleLoadoutSystem\\content\\<lang>.w3strings, one per language file the
game ships (content\\content0\\<lang>.w3strings), then read every file back.

    python tools/gen_strings.py [--check]

Our eleven languages (rule 66: English, Japanese, Korean, Chinese, Russian, German, French, Spanish, Italian, Polish,
Czech) are written out; the game's other language files get a near language (esmx: Spanish, zh: Chinese in traditional
characters) or English. --check only compares the files on disk with the table and fails on a difference.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import w3strings  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "dist", "Mods", "modSimpleLoadoutSystem", "content")

# Our string ids: idspace 7713 (2110000000 + 7713 * 1000 + n), next to Unbind Vanilla Controls W3's 7712, clear of the
# game's own ids and the usual mod ranges.
ID_BASE = 2117713000

KEYS = ["sls_menu", "sls_menu_count", "sls_count_1", "sls_count_2", "sls_count_3", "sls_count_4", "sls_loadout",
        "sls_always_worn", "sls_select_loadout", "sls_always_set", "sls_kept"]

_N = ["1", "2", "3", "4"]

# key order as KEYS: menu name, setting, 1-4, box word ("Loadout" + number), Always worn, the button hint, the two messages
TEXT = {
    "en": ["Simple Loadout System", "Loadouts"] + _N + ["Loadout", "Always worn", "Select loadout",
           "Always worn pieces:", "Kept in your inventory (quest items):"],
    "de": ["Simple Loadout System", "Ausrüstungssätze"] + _N + ["Ausrüstung", "Immer getragen", "Ausrüstung wählen",
           "Immer getragene Teile:", "Im Inventar behalten (Quest-Gegenstände):"],
    "fr": ["Simple Loadout System", "Équipements"] + _N + ["Équipement", "Toujours porté", "Choisir l'équipement",
           "Pièces toujours portées :", "Gardés dans l'inventaire (objets de quête) :"],
    "es": ["Simple Loadout System", "Equipamientos"] + _N + ["Equipamiento", "Siempre puesto", "Elegir equipamiento",
           "Piezas siempre puestas:", "Se quedan en el inventario (objetos de misión):"],
    "it": ["Simple Loadout System", "Equipaggiamenti"] + _N + ["Equipaggiamento", "Sempre indossato",
           "Scegli equipaggiamento", "Pezzi sempre indossati:", "Restano nell'inventario (oggetti delle missioni):"],
    "pl": ["Simple Loadout System", "Zestawy"] + _N + ["Zestaw", "Zawsze noszone", "Wybierz zestaw",
           "Zawsze noszone części:", "Zostają w ekwipunku (przedmioty fabularne):"],
    "cz": ["Simple Loadout System", "Sady výbavy"] + _N + ["Sada", "Vždy nošené", "Vybrat sadu",
           "Vždy nošené kusy:", "Zůstávají v inventáři (questové předměty):"],
    "ru": ["Simple Loadout System", "Комплекты"] + _N + ["Комплект", "Всегда надето", "Выбрать комплект",
           "Всегда надетые вещи:", "Остаются в инвентаре (предметы заданий):"],
    "jp": ["Simple Loadout System", "装備セット数"] + _N + ["装備セット", "常時装備", "装備セットを選択",
           "常時装備の数:", "インベントリに残る（クエストアイテム）:"],
    "kr": ["Simple Loadout System", "장비 세트 수"] + _N + ["장비 세트", "항상 착용", "장비 세트 선택",
           "항상 착용 장비:", "인벤토리에 남음(퀘스트 아이템):"],
    "cn": ["Simple Loadout System", "装备方案数"] + _N + ["装备方案", "始终穿戴", "选择装备方案",
           "始终穿戴物品：", "留在物品栏中（任务物品）："],
    "zh": ["Simple Loadout System", "裝備方案數"] + _N + ["裝備方案", "始終穿戴", "選擇裝備方案",
           "始終穿戴物品：", "留在物品欄中（任務物品）："],
}
NEAR = {"esmx": "es"}


def rows_for(lang):
    texts = TEXT.get(lang) or TEXT.get(NEAR.get(lang, "")) or TEXT["en"]
    assert len(texts) == len(KEYS), lang
    return [(ID_BASE + i + 1, key, texts[i]) for i, key in enumerate(KEYS)]


def game_languages():
    content0 = os.path.join(os.environ.get("W3_GAME", r"D:\Steam Library\steamapps\common\The Witcher 3"), "content", "content0")
    if os.path.isdir(content0):
        langs = sorted(f[:-10] for f in os.listdir(content0) if f.endswith(".w3strings"))
        if langs:
            return langs
    # the game's 5.0 set, when the game folder is not found
    return ["ar", "br", "cn", "cz", "de", "en", "es", "esmx", "fr", "hu", "it", "jp", "kr", "pl", "ru", "tr", "ua", "zh"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    problems = []
    for lang in game_languages():
        path = os.path.join(OUT, f"{lang}.w3strings")
        rows = rows_for(lang)
        if not a.check:
            w3strings.write(path, rows)
        got = w3strings.read(path) if os.path.isfile(path) else {}
        for _, key, text in rows:
            if got.get(w3strings.key_hash(key)) != text:
                problems.append(f"{lang}.w3strings: {key} missing or stale")
    if problems:
        print("\n".join(problems))
        sys.exit(1)
    print(f"ok    {len(game_languages())} language files, {len(KEYS)} strings each")


if __name__ == "__main__":
    main()
