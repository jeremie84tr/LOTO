#!/bin/sh
# Prend les captures d'écran brutes pour l'App Store (iPhone 6,9", iPad 13").
# Usage : AppStore/outils/captures.sh [iphone] [ipad]   (depuis LotoApp/, Xcode requis ; tout par défaut)
# Résultat : AppStore/captures/brutes/{iphone,ipad}/*.png
set -e
CIBLES="${*:-iphone ipad}"
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
TRAVAIL="${TMPDIR:-/tmp}/loto-captures"
BRUT="AppStore/captures/brutes"
DD="$TRAVAIL/dd"
mkdir -p "$TRAVAIL" "$BRUT/iphone" "$BRUT/ipad"

python3 outils/generer_exemples.py -o "$TRAVAIL/exemples.json" >/dev/null
python3 outils/generer_exemples.py --victoire -o "$TRAVAIL/victoire.json" >/dev/null

# nom | données | arguments
PLANS="01-partie|exemples|-ecran partie
02-victoire|victoire|-ecran partie
03-tableau|exemples|-ecran partie -defiler tableau
04-cartons|exemples|-ecran partie -defiler cartons
05-phases|exemples|-ecran soiree -feuille nouvellePartie
06-statistiques|exemples|-ecran statistiques"

simulateur() { # $1 = nom du modèle, $2 = dossier
    UDID=$(xcrun simctl list devices available | grep -m1 "    $1 (" | grep -oE "[0-9A-F-]{36}")
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" >/dev/null
    xcrun simctl status_bar "$UDID" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
        --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    xcodebuild -project Loto.xcodeproj -scheme Loto -configuration Debug -destination "platform=iOS Simulator,id=$UDID" \
        -derivedDataPath "$DD" CODE_SIGNING_ALLOWED=NO build -quiet
    xcrun simctl install "$UDID" "$DD/Build/Products/Debug-iphonesimulator/Loto.app"
    echo "$PLANS" | while IFS='|' read -r nom donnees args; do
        xcrun simctl terminate "$UDID" fr.loto.suivi 2>/dev/null || true
        cp "$TRAVAIL/$donnees.json" "$TRAVAIL/donnees.json"
        # shellcheck disable=SC2086
        xcrun simctl launch "$UDID" fr.loto.suivi -fichierDonnees "$TRAVAIL/donnees.json" $args >/dev/null
        sleep 12
        xcrun simctl io "$UDID" screenshot "$BRUT/$2/$nom.png" >/dev/null 2>&1
        echo "  $2/$nom.png"
    done
    xcrun simctl terminate "$UDID" fr.loto.suivi 2>/dev/null || true
}

case " $CIBLES " in *" iphone "*) echo "iPhone 6,9 pouces"; simulateur "iPhone 17 Pro Max" iphone ;; esac
case " $CIBLES " in *" ipad "*) echo "iPad 13 pouces"; simulateur "iPad Pro 13-inch (M4)" ipad ;; esac

