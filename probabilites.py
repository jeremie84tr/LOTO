#!/usr/bin/env python3
"""Chances de carton plein, calcul exact et simulation.

Usage: ./probabilites.py parties/2026-11-11_orange [n1 n2 ...]
  (n = nombre de numéros tirés ; par défaut 40, 48, 55)
"""
import json, random, sys
from itertools import combinations
from math import comb
from pathlib import Path


def proba_un_carton(n, taille=15, total=90):
    """Probabilité qu'un carton de `taille` numéros soit plein après `n` tirages."""
    if not 0 <= n <= total:
        raise ValueError(f"n doit être entre 0 et {total}")
    return comb(total - taille, n - taille) / comb(total, n) if n >= taille else 0.0


def proba_au_moins_un(cartons, n, total=90):
    """Probabilité exacte qu'au moins un des cartons (ensembles de numéros) soit plein
    après `n` tirages, par inclusion-exclusion (tient compte des numéros communs)."""
    if not 0 <= n <= total:
        raise ValueError(f"n doit être entre 0 et {total}")
    cartons = [frozenset(c) for c in cartons]
    p = 0.0
    for k in range(1, len(cartons) + 1):
        for sous in combinations(cartons, k):
            u = len(frozenset().union(*sous))
            if u <= n:
                p += (-1) ** (k + 1) * comb(total - u, n - u) / comb(total, n)
    return p


def simuler(cartons, n, essais, rng=None, total=90):
    """Estimation par simulation de la même probabilité."""
    rng = rng or random.Random()
    cartons = [frozenset(c) for c in cartons]
    gagnes = 0
    for _ in range(essais):
        tirage = set(rng.sample(range(1, total + 1), n))
        gagnes += any(c <= tirage for c in cartons)
    return gagnes / essais


def charger_cartons(dossier):
    return [frozenset(x for l in json.loads(f.read_text())["grille"] for x in l if x)
            for f in sorted(Path(dossier, "cartons").glob("carton_*.json"))]


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    cartons = charger_cartons(argv[1])
    if not cartons:
        sys.exit(f"Aucun carton dans {argv[1]}")
    tirages = [int(a) for a in argv[2:]] or [40, 48, 55]
    print(f"| Numéros tirés | Un carton | Au moins un des {len(cartons)} cartons |")
    print("|---|---|---|")
    for n in tirages:
        print(f"| {n} | {proba_un_carton(n) * 100:.4f} % | {proba_au_moins_un(cartons, n) * 100:.4f} % |")


if __name__ == "__main__":
    main(sys.argv)
