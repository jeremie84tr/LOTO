#!/usr/bin/env python3
"""Crée un espace de travail pour une partie de loto.

Usage: ./nouvelle_partie.py 2026-11-20 "Salle des fêtes" --cartons 20
"""
import argparse, json, random, re, sys, unicodedata
from datetime import date
from pathlib import Path

RACINE = Path(__file__).parent / "parties"

def slug(texte):
    t = unicodedata.normalize("NFD", texte).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", t.lower()).strip("-")

def generer_carton(rng):
    """Carton français : 3 lignes x 9 colonnes, 5 numéros par ligne, 15 au total."""
    while True:
        comptes = [1] * 9
        while sum(comptes) < 15:
            c = rng.randrange(9)
            if comptes[c] < 3:
                comptes[c] += 1
        lignes_par_col = [rng.sample(range(3), n) for n in comptes]
        if all(sum(l in rows for rows in lignes_par_col) == 5 for l in range(3)):
            break
    grille = [[None] * 9 for _ in range(3)]
    for c, rows in enumerate(lignes_par_col):
        lo, hi = (1 if c == 0 else c * 10), (9 if c == 0 else 90 if c == 8 else c * 10 + 9)
        nums = sorted(rng.sample(range(lo, hi + 1), len(rows)))
        for l, n in zip(sorted(rows), nums):
            grille[l][c] = n
    return grille

def main():
    p = argparse.ArgumentParser()
    p.add_argument("date", help="AAAA-MM-JJ")
    p.add_argument("lieu")
    p.add_argument("--cartons", type=int, default=0, help="nombre de cartons à générer")
    a = p.parse_args()
    if a.cartons < 0:
        p.error("--cartons doit être positif ou nul")
    date.fromisoformat(a.date)
    if not slug(a.lieu):
        p.error(f"lieu invalide (aucune lettre ni chiffre) : {a.lieu!r}")
    dossier = RACINE / f"{a.date}_{slug(a.lieu)}"
    if dossier.exists():
        sys.exit(f"Existe déjà : {dossier}")
    (dossier / "cartons").mkdir(parents=True)
    (dossier / "tirage").mkdir()
    rng = random.Random()
    cartons = []
    for i in range(1, a.cartons + 1):
        cid = f"{i:03d}"
        cartons.append(cid)
        (dossier / "cartons" / f"carton_{cid}.json").write_text(
            json.dumps({"id": cid, "joueur": None, "grille": generer_carton(rng)}, ensure_ascii=False))
    (dossier / "partie.json").write_text(json.dumps(
        {"date": a.date, "lieu": a.lieu, "cartons": cartons, "notes": ""},
        ensure_ascii=False, indent=2))
    (dossier / "tirage" / "numeros.json").write_text("[]")
    print(f"Créé : {dossier} ({len(cartons)} cartons)")

if __name__ == "__main__":
    main()
