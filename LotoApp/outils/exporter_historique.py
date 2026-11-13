#!/usr/bin/env python3
"""Convertit les dossiers `parties/` du dépôt en fichier JSON importable dans l'app Loto.

Usage :
    ./exporter_historique.py ../../parties -o historique.json \
        --phases quine,quine,doubleQuine,cartonPlein

Les parties d'une même date et d'un même lieu forment une soirée. Les planches
sont déduites des numéros de série consécutifs (6 cartons par planche).
"""
import argparse, json, uuid
from collections import defaultdict
from pathlib import Path

ESPACE = uuid.UUID("6f1c5d8e-6a51-4c0b-9a7e-1b2f0c3d4e5f")
TYPES = {"quine", "doubleQuine", "cartonPlein"}


def uid(*morceaux):
    return str(uuid.uuid5(ESPACE, "/".join(map(str, morceaux)))).upper()


def planches(cartons):
    """Lettre de planche par carton : séries consécutives, par paquets de 6."""
    avec_serie = sorted((c for c in cartons if str(c.get("serie") or "").isdigit()), key=lambda c: int(c["serie"]))
    res, lettre, precedent, taille = {}, -1, None, 0
    for c in avec_serie:
        s = int(c["serie"])
        if precedent is None or s != precedent + 1 or taille == 6:
            lettre, taille = lettre + 1, 0
        res[c["id"]] = chr(ord("A") + lettre)
        precedent, taille = s, taille + 1
    return res


def main():
    p = argparse.ArgumentParser()
    p.add_argument("parties", type=Path)
    p.add_argument("-o", "--sortie", type=Path, default=Path("historique.json"))
    p.add_argument("--phases", default="quine,doubleQuine,cartonPlein")
    a = p.parse_args()
    phases = a.phases.split(",")
    assert all(t in TYPES for t in phases), f"Types possibles : {TYPES}"

    soirees = defaultdict(list)
    for dossier in sorted(a.parties.iterdir()):
        meta = dossier / "partie.json"
        if not meta.exists():
            continue
        m = json.loads(meta.read_text())
        cartons = [json.loads((dossier / "cartons" / f"carton_{cid}.json").read_text()) for cid in m["cartons"]]
        tirage = json.loads((dossier / "tirage" / "numeros.json").read_text())
        soirees[(m["date"], m["lieu"])].append((m.get("partie", 1), m, cartons, tirage))

    sortie = []
    for (date, lieu), parties in sorted(soirees.items()):
        parties.sort(key=lambda x: x[0])
        cartons = parties[0][2]
        lettres = planches(cartons)
        sortie.append({
            "id": uid(date, lieu),
            "date": f"{date}T18:00:00Z",
            "lieu": lieu,
            "notes": parties[0][1].get("notes") or "",
            "deroulementParDefaut": phases,
            "cartons": [{
                "id": c["id"],
                **({"serie": str(c["serie"])} if c.get("serie") else {}),
                **({"planche": lettres[c["id"]]} if c["id"] in lettres else {}),
                **({"joueur": c["joueur"]} if c.get("joueur") else {}),
                "grille": c["grille"],
            } for c in cartons],
            "parties": [{
                "id": uid(date, lieu, num),
                "numero": num,
                "tirage": tirage,
                "notes": m.get("notes") or "",
                "importee": True,
                "phases": [{"id": uid(date, lieu, num, i), "type": t, "lot": ""} for i, t in enumerate(phases)],
            } for num, m, _, tirage in parties],
        })
    a.sortie.write_text(json.dumps(sortie, ensure_ascii=False, indent=1))
    print(f"{a.sortie} : {len(sortie)} soirée(s), {sum(len(s['parties']) for s in sortie)} partie(s)")


if __name__ == "__main__":
    main()
