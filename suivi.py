#!/usr/bin/env python3
"""Usage: ./suivi.py parties/2026-11-11_orange [n1 n2 ...]  (ajoute des numéros puis affiche l'état)"""
import json, os, sys, glob
from pathlib import Path
try: import fcntl  # verrou Linux/macOS ; sans effet sous Windows
except ImportError: fcntl = None
if len(sys.argv) < 2: sys.exit(__doc__)
d = Path(sys.argv[1]); f = d / "tirage" / "numeros.json"
if not f.is_file(): sys.exit(f"Partie introuvable : {d} (fichier {f} absent)")
verrou = open(f.parent / ".numeros.lock", "w")  # un seul suivi.py écrit à la fois
if fcntl: fcntl.flock(verrou, fcntl.LOCK_EX)
tires = json.loads(f.read_text())
for a in sys.argv[2:]:
    try: n = int(a)
    except ValueError: print(f"Ignoré (pas un numéro): {a}"); continue
    if not 1 <= n <= 90: print(f"Ignoré (hors 1-90): {n}"); continue
    if n in tires: print(f"Déjà tiré: {n}"); continue
    tires.append(n)
tmp = f.with_name(f.name + ".tmp"); tmp.write_text(json.dumps(tires)); os.replace(tmp, f)  # écriture atomique
verrou.close()
print(f"{len(tires)} numéros tirés, dernier: {tires[-1] if tires else '-'}")
for c in sorted(glob.glob(str(d / "cartons" / "*.json"))):
    c = json.load(open(c)); lignes = [sum(x in tires for x in r if x) for r in c["grille"]]
    tot = sum(lignes); mq = [5 - l for l in lignes]
    print(f"{c['id']}: {tot:2d}/15  lignes {lignes}  manque {min(mq)} pour quine, {15 - tot} pour carton plein")
