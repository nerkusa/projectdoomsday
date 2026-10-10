# Помощники для генераторов данных (python3): load/dump сохраняют стиль JSON, o/n/save — диалоги.
import json
import os
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data") + "/"
D = R + "dialogs/"


def load(n):
    return json.load(open(R + n))


def dump(n, d):
    if n in ("characters.json", "items.json"):
        lines = ["  %s: %s" % (json.dumps(k, ensure_ascii=False), json.dumps(v, ensure_ascii=False)) for k, v in d.items()]
        txt = "{\n" + ",\n".join(lines) + "\n}\n"
        if list(d.keys())[0] == "_help":
            txt = txt.replace(",\n", ",\n\n", 1)
        open(R + n, "w").write(txt)
        return
    json.dump(d, open(R + n, "w"), ensure_ascii=False, indent=2)
    open(R + n, "a").write("\n")


def o(text, nxt=None, **kw):
    d = {"text": text, "next": nxt}
    d.update(kw)
    return d


def n(text, *opts, **kw):
    d = {"text": text}
    d.update(kw)
    d["options"] = list(opts)
    return d


LEAVE = o("[Уйти]")


def save(name, speaker, title, nodes, **extra):
    d = {"speaker": speaker, "title": title, "nodes": nodes}
    d.update(extra)
    json.dump(d, open(D + name + ".json", "w"), ensure_ascii=False, indent=2)


def chk(stat, skill, dc):
    return {"stat": stat, "skill": skill, "dc": dc}


def IF(**kw):
    return {"if": kw}


def person(C, key, name, stats, look, female=False, skills=None, pockets=None, weapon="fists", lethal=False, **extra):
    d = {"name": name, "stats": stats, "skills": skills or {}, "hp_roll": 3, "weapon": weapon, "lethal": lethal,
         "look": look, "pockets": pockets or {}}
    if female:
        d["female"] = True
    d.update(extra)
    C[key] = d
