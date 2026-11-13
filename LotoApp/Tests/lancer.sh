#!/bin/sh
# Compile et lance les tests de la logique (sans Xcode).
set -e
cd "$(dirname "$0")/.."
SORTIE="${TMPDIR:-/tmp}/loto-tests"
swiftc -O Loto/Modele/Modeles.swift Loto/Modele/Analyse.swift Loto/Modele/Statistiques.swift Tests/main.swift -o "$SORTIE"
"$SORTIE" Loto/Ressources/historique_orange.json
