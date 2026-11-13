# Loto : app iOS / iPadOS / macOS

App SwiftUI (une seule cible multiplateforme, iOS 17+ et macOS 14+) pour suivre les lotos en direct.

## Ce qu'elle fait

- **Soirées** (lieu, date, notes), avec leurs **cartons** regroupés par **planche**. On peut reprendre les cartons d'une soirée précédente.
- **Parties** avec un **ordre de phases libre**, choisi à chaque partie : quine, double quine, carton plein, dans n'importe quel ordre et autant de fois qu'il faut (ex. Orange : Quine → Quine → Double quine → Carton plein). L'ordre peut être modifié en cours de partie.
- **Saisie du tirage** : on touche le numéro sur le tableau 1–90, ou on le tape (plusieurs d'un coup : `12 45 3`). Appui long ou clic droit pour retirer un numéro, bouton pour annuler le dernier.
- **Détection automatique** quand un de vos cartons gagne la phase en cours (bandeau vert, vibration, annonce vocale en option).
- **Conseils en direct**, par exemple :
  - « Plus qu'un numéro avant la quine : le 23 ou le 45 ! (Carton 010 · planche B) »
  - « Plus que 2 numéros, 59 et 61, avant la quine ! (Carton 003 · planche A) »
  - les chances qu'un numéro gagnant sorte au prochain tirage ou dans les 5 prochains,
  - le numéro qui ferait avancer le plus de cartons,
  - une estimation par simulation du nombre de numéros avant votre quine ou carton plein,
  - la moyenne historique : après combien de numéros la phase tombe d'habitude.
- **Fin de phase** : gagnée par nous (sur quel carton) ou par un autre joueur, avec le lot. Pour une deuxième quine, les lignes déjà gagnées sur un carton ne comptent plus.
- **Statistiques** par soirée et globales : sorties par numéro, plus et moins sortis, numéros absents depuis le plus de parties, répartition par colonne, quand tombent les phases, performance des cartons, victoires.
- **Import / export** JSON de toutes les données. L'historique d'Orange (10 parties, 12 cartons) est chargé au premier lancement.

Les données sont enregistrées automatiquement (`Application Support/Loto/loto.json`).

## Lancer l'app

Ouvrir `Loto.xcodeproj` dans Xcode, choisir la cible « Loto » puis un iPhone, un iPad ou « My Mac », et lancer avec ⌘R. Pour un vrai iPhone, choisir votre équipe dans *Signing & Capabilities*.

Pour compiler en ligne de commande, Xcode doit être l'outil actif :

    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    xcodebuild -project Loto.xcodeproj -scheme Loto -destination 'platform=macOS' build

## Tests de la logique

    ./Tests/lancer.sh

Ils vérifient la saisie des cartons, les objectifs par phase, l'enchaînement 2 quines → double quine → carton plein, les textes des conseils, les probabilités, et retrouvent les chiffres des rapports d'Orange (500 numéros, carton 009 à 97 cases).

## Reprendre l'historique du dépôt

Le script `outils/exporter_historique.py` convertit les dossiers `parties/` du dépôt en fichier importable (menu ⋯ › Importer) :

    ./outils/exporter_historique.py ../parties -o historique.json --phases quine,quine,doubleQuine,cartonPlein

## Organisation du code

- `Loto/Modele/Modeles.swift` : cartons, phases, parties, soirées.
- `Loto/Modele/Analyse.swift` : ce qu'il manque à chaque carton, conseils, probabilités, simulation.
- `Loto/Modele/Statistiques.swift` : statistiques sur un ensemble de parties.
- `Loto/Modele/Magasin.swift` : stockage JSON et modifications.
- `Loto/Vues/` : écrans SwiftUI (`PartieView` = suivi en direct).
