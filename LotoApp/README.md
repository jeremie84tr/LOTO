# Loto : app iOS / iPadOS / macOS

App SwiftUI (une seule cible multiplateforme, iOS 17+ et macOS 14+) pour suivre les lotos en direct.

## Ce qu'elle fait

- **Soirées** (lieu, date, notes), avec leurs **cartons** regroupés par **planche**. On peut reprendre les cartons d'une soirée précédente.
- **Lecture des cartons par photo** (appareil photo ou photothèque, framework Vision, tout sur l'appareil). Les numéros lus passent par un écran de vérification : chaque numéro douteux (lecture peu nette, autre lecture possible, position sur le carton qui ne correspond pas à sa dizaine, doublon) doit être confirmé ou corrigé avec un zoom sur la photo, la grille doit former un carton possible (3 × 5 numéros, chacun dans sa colonne), et il faut attester l'avoir comparée au carton papier.
- **Plusieurs cartons sur une photo** : la feuille est repérée, remise à plat et tournée dans le bon sens ; les cartons sont retrouvés grâce à la structure de leurs numéros (3 lignes × 9 colonnes, un numéro dans la colonne de sa dizaine), sans dépendre de leur cadre. Chaque case est ensuite relue seule, et seul un numéro lu pareil par les deux lectures est considéré comme sûr. Depuis la liste des cartons (bouton 📷), on ajoute une planche entière en une photo ; les cartons déjà enregistrés ne sont pas ajoutés deux fois.
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
- **Import / export** JSON de toutes les données. Des données d'exemple **fictives** (3 soirées) sont chargées au premier lancement ; elles sont générées par `outils/generer_exemples.py`.

Les données sont enregistrées automatiquement (`Application Support/Loto/loto.json`).

## Lancer l'app

Ouvrir `Loto.xcodeproj` dans Xcode, choisir la cible « Loto » puis un iPhone, un iPad ou « My Mac », et lancer avec ⌘R. Pour un vrai iPhone, choisir votre équipe dans *Signing & Capabilities*.

Pour compiler en ligne de commande, Xcode doit être l'outil actif :

    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
    xcodebuild -project Loto.xcodeproj -scheme Loto -destination 'platform=macOS' build

## Tests de la logique

    ./Tests/lancer.sh

Ils vérifient la saisie des cartons, les objectifs par phase, l'enchaînement 2 quines → double quine → carton plein, les textes des conseils et les probabilités. Ils retrouvent aussi les chiffres des rapports d'Orange à partir des dossiers `parties/` du dépôt (500 numéros, carton 009 à 97 cases), et contrôlent que les données d'exemple embarquées sont anonymes.

Essai du détecteur sur une planche de 4 cartons photographiée de biais et à l'envers :

    ./outils/essai_planche.sh

## Reprendre l'historique du dépôt

Le script `outils/exporter_historique.py` convertit les dossiers `parties/` du dépôt en fichier importable (menu ⋯ › Importer) :

    ./outils/exporter_historique.py ../parties -o historique.json --phases quine,quine,doubleQuine,cartonPlein

## Publication sur l'App Store

Tout est dans [`AppStore/`](AppStore/FICHE_APP_STORE.md) :

- `FICHE_APP_STORE.md` : textes prêts à copier-coller (nom, sous-titre, description, mots-clés, URL, confidentialité, classification, notes pour la vérification) ;
- `captures/iphone-6.9/` (1320 × 2868) et `captures/ipad-13/` (2064 × 2752) : visuels habillés ; `captures/brutes/` : les mêmes sans habillage ;
- `promo/` : icône 1024 × 1024 et bannière 1920 × 1080 ;
- `outils/captures.sh` puis `outils/composer.sh` pour tout régénérer.

Le site d'aide et la politique de confidentialité sont dans [`../docs/`](../docs/index.html), à publier avec GitHub Pages.

## Organisation du code

- `Loto/Modele/Modeles.swift` : cartons, phases, parties, soirées.
- `Loto/Modele/Analyse.swift` : ce qu'il manque à chaque carton, conseils, probabilités, simulation.
- `Loto/Modele/Statistiques.swift` : statistiques sur un ensemble de parties.
- `Loto/Modele/LectureCarton.swift` : de la photo à la grille, contrôles de la lecture ; `LecteurVision.swift` : appel à Vision ; `DetecteurCartons.swift` : feuille, sens, découpage des cartons et double lecture.
- `Loto/Modele/Magasin.swift` : stockage JSON et modifications.
- `Loto/Vues/` : écrans SwiftUI (`PartieView` = suivi en direct).
