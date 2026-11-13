#!/bin/sh
# Habille les captures brutes (titre + fond) aux tailles exactes de l'App Store.
# Usage : AppStore/outils/composer.sh      (depuis LotoApp/, après captures.sh)
set -e
cd "$(dirname "$0")/.."
BIN="${TMPDIR:-/tmp}/loto-composer"
swiftc -O outils/composer.swift -o "$BIN"
mkdir -p captures/iphone-6.9 captures/ipad-13 promo

legende() { # nom → « titre|sous-titre »
    case "$1" in
        01-partie)       echo "Ne ratez plus jamais une quine|Ce qui manque à chaque carton, en direct" ;;
        02-victoire)     echo "Quine ! L'app vous prévient|Détection automatique sur tous vos cartons" ;;
        03-tableau)      echo "Cochez le tirage d'un geste|Les numéros gagnants sont entourés" ;;
        04-cartons)      echo "Tous vos cartons, toutes vos planches|Suivez chacun d'eux numéro par numéro" ;;
        05-phases)       echo "Quine, double quine, carton plein|Dans l'ordre de votre salle" ;;
        06-statistiques) echo "Les statistiques de vos soirées|Phases, numéros, cartons : tout est mesuré" ;;
    esac
}

habiller() { # $1 dossier brut, $2 dossier final, $3 largeur, $4 hauteur, $5 mode
    for f in captures/brutes/$1/*.png; do
        nom=$(basename "$f" .png)
        [ "$1" = ipad ] && [ "$nom" = 03-tableau ] && continue   # identique à 04 sur iPad
        l=$(legende "$nom")
        "$BIN" "$f" "captures/$2/$nom.png" "$3" "$4" "${l%%|*}" "${l#*|}" $5
        echo "  $2/$nom.png"
    done
}

habiller iphone iphone-6.9 1320 2868 iphone
habiller ipad ipad-13 2064 2752 ipad

"$BIN" captures/brutes/iphone/01-partie.png promo/banniere-1920x1080.png 1920 1080 \
    "Carton Plein : suivi de loto" "Quines, conseils et statistiques, sur iPhone, iPad et Mac" banniere
cp ../Loto/Assets.xcassets/AppIcon.appiconset/icone-1024.png promo/icone-1024.png
echo "  promo/"
