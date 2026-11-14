#!/bin/sh
# Compile et lance les tests de la logique (sans Xcode).
# Les tests s'appuient sur les vraies parties du dépôt (dossier ../parties).
set -e
cd "$(dirname "$0")/.."
TMP="${TMPDIR:-/tmp}"
python3 outils/exporter_historique.py ../parties -o "$TMP/loto-historique.json" \
    --phases quine,quine,doubleQuine,cartonPlein >/dev/null
swiftc -O Loto/Modele/Modeles.swift Loto/Modele/Analyse.swift Loto/Modele/Statistiques.swift Tests/main.swift -o "$TMP/loto-tests"
"$TMP/loto-tests" "$TMP/loto-historique.json" Loto/Ressources/exemples.json
