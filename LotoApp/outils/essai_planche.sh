#!/bin/sh
# Essai de bout en bout du détecteur de cartons sur une planche photographiée de biais.
# Usage : ./outils/essai_planche.sh [dossier où écrire la photo et les cartons redressés]
set -e
cd "$(dirname "$0")/.."
SORTIE="${1:-${TMPDIR:-/tmp}/loto-essai-planche}"
mkdir -p "$SORTIE"
swiftc -O Loto/Modele/Modeles.swift Loto/Modele/LectureCarton.swift Loto/Modele/LecteurVision.swift \
    Loto/Modele/DetecteurCartons.swift outils/essai_planche/main.swift -o "$SORTIE/essai"
"$SORTIE/essai" Loto/Ressources/exemples.json "$SORTIE"
