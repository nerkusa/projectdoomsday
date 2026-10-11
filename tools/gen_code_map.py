"""Карта кода: docs/code_map.md — что где лежит, чтобы читать только нужные строки.

  * разделы docs/design.md с номерами строк (читать: sed -n 'a,bp');
  * задания: id → название → файлы, где оно упоминается (диалоги, скрипты, тесты);
  * места карты мира → сцена → скрипт;
  * скрипты и сборщики: строк, назначение, функции с номерами строк.

Запуск: python3 tools/gen_code_map.py  (после крупных правок — перегенерировать)
"""
import glob
import json
import os
import re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
os.chdir(ROOT)
out = ["# Карта кода (сгенерировано tools/gen_code_map.py — руками не править)", "",
       "Искать тему: `grep -n -i 'слово' docs/code_map.md`, потом читать только указанные строки: "
       "`sed -n 'a,bp' файл`.", ""]

# ---------- design.md ----------
lines = open("docs/design.md", encoding="utf-8").read().split("\n")
heads = [(i + 1, len(m.group(1)), m.group(2)) for i, l in enumerate(lines) if (m := re.match(r"^(#+)\s+(.*)", l))]
out += ["## docs/design.md — разделы", ""]
for k, (ln, lvl, name) in enumerate(heads):
    end = len(lines)
    for ln2, lvl2, _ in heads[k + 1:]:
        if lvl2 <= lvl:
            end = ln2 - 1
            break
    out.append("%s%s — %d–%d" % ("  " * (lvl - 1), name, ln, end))
out.append("")


def text_of(path):
    try:
        return open(path, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        return ""


code_files = sorted(glob.glob("scripts/**/*.gd", recursive=True)) + sorted(glob.glob("tools/*.gd"))
data_files = sorted(glob.glob("data/**/*.json", recursive=True))
texts = {p: text_of(p) for p in code_files + data_files}

# ---------- задания ----------
quests = json.load(open("data/quests.json", encoding="utf-8"))
out += ["## Задания (data/quests.json) — где упоминаются", ""]
for qid, q in quests.items():
    if qid.startswith("_") or not isinstance(q, dict):
        continue
    q_ = re.escape(qid)
    # только там, где это именно задание: quest_stage("id"…), set_quest("id"…), "quest": "id"
    pat = re.compile(r"(quest\w*\(\s*[\"']%s[\"'])|(\"quests?\"\s*:\s*\[?\s*\"%s\")|(\"%s\"\s*:\s*\d)|(\"id\"\s*:\s*\"%s\")" % (q_, q_, q_, q_))
    where = [p for p, t in texts.items() if p != "data/quests.json" and pat.search(t)]
    out.append("- **%s** «%s»: %s" % (qid, q.get("title", q.get("name", "")), ", ".join(where) or "—"))
out.append("")

# ---------- места карты мира ----------
world = json.load(open("data/world.json", encoding="utf-8"))
LOCS = dict(re.findall(r'"(\w+)":\s*"res://(scenes/[^"]+\.tscn)"', text_of("scripts/main.gd").split("}")[0]))
out += ["## Места карты мира (data/world.json → сцена → скрипт)", ""]
for nid, n in world["nodes"].items():
    loc = LOCS.get(n.get("loc", nid), "")
    scr = ""
    if loc:
        st = text_of(loc)
        m = re.search(r'path="res://(scripts/[^"]+\.gd)"', st)
        scr = m.group(1) if m else ""
    out.append("- %s «%s»: %s %s" % (nid, n.get("name", ""), loc or "—", ("→ " + scr) if scr else ""))
out.append("")

# ---------- жители: диалог → где поставлен ----------
out += ["## Жители: файл диалога → где поставлен (сборщик:строка)", ""]
for d in sorted(glob.glob("data/dialogs/*.json")):
    did = os.path.splitext(os.path.basename(d))[0]
    pat = re.compile(r"[\"']dialog[\"']\s*:\s*[\"']%s[\"']" % re.escape(did))
    at = []
    for p_ in code_files:
        for m in pat.finditer(texts[p_]):
            at.append("%s:%d" % (p_, texts[p_].count("\n", 0, m.start()) + 1))
    out.append("- %s: %s" % (did, ", ".join(at) or "—"))
out.append("")

# ---------- скрипты ----------
out += ["## Скрипты и сборщики", "",
        "Формат: файл (строк) — назначение. Ниже — функции `имя:строка` (для файлов от 150 строк).", ""]
for p in code_files:
    t = texts[p]
    ls = t.split("\n")
    doc = ""
    for l in ls[:12]:
        if l.startswith("##"):
            doc = l.lstrip("#").strip()
            break
    cls = re.search(r"^class_name\s+(\w+)", t, re.M)
    out.append("### %s (%d)%s" % (p, len(ls), (" · class " + cls.group(1)) if cls else ""))
    if doc:
        out.append(doc)
    if len(ls) >= 150:
        fn = ["%s:%d" % (m.group(1), t.count("\n", 0, m.start()) + 1) for m in re.finditer(r"^(?:static )?func (\w+)", t, re.M)]
        if fn:
            out.append("`" + "` `".join(fn) + "`")
    out.append("")

# ---------- данные ----------
out += ["## Данные (data/)", ""]
for p in data_files:
    n = texts[p].count("\n") + 1
    out.append("- %s (%d строк)" % (p, n))
open("docs/code_map.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("docs/code_map.md:", len(out), "строк")
