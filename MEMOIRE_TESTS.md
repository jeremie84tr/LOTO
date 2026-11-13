# Mémoire des tests : LOTO

Liste de tout ce qu'il faut tester dans l'application, avec le statut de chaque point.
Les identifiants (`NP-xx`, `SU-xx`…) sont repris en commentaire dans les tests Python (`tests/`). Les points `AP-xx` de l'application correspondent aux sections de `LotoApp/Tests/main.swift`.

Dernière exécution : 13/11/2026, `python -m pytest` : **128 réussis, 2 ignorés (rapports sans section concernée), 0 échec**.

Légende des statuts :

- ✅ **OK** : testé, passe.
- ❌ **Échec connu** : testé, le défaut existe. Le test est marqué `xfail(strict=True)` : la CI reste verte tant que le bug existe et devient rouge quand il est corrigé, pour penser à retirer le marqueur et à passer le statut à ✅.
- ⏳ **À confirmer** : test écrit, pas encore vu passer (tests Swift : ils ne tournent que sur Mac, donc dans la CI).
- ⬜ **Non testé** : identifié, pas encore automatisé.

Lancer les tests :

    pip install -r requirements-dev.txt
    python -m pytest            # scripts Python et données
    ./LotoApp/Tests/lancer.sh   # logique de l'app (Mac avec Xcode)

La CI (`.github/workflows/tests.yml`) lance tout à chaque push sur toutes les branches et sur chaque pull request : les tests Python sous Python 3.10 et 3.13 (Linux), les tests Swift et la compilation de l'app sur macOS.

## 1. `nouvelle_partie.py` : création d'une partie (`tests/test_nouvelle_partie.py`)

### Nom de dossier (`slug`)

| ID | Point à tester | Statut |
|---|---|---|
| NP-01 | Lieu simple mis en minuscules (`Orange` → `orange`) | ✅ OK |
| NP-02 | Accents retirés, espaces remplacés par des tirets (`Salle des fêtes` → `salle-des-fetes`) | ✅ OK |
| NP-03 | Ponctuation et tirets multiples fusionnés, pas de tiret en début ou fin | ✅ OK |
| NP-04 | Caractères non décomposables (`Œ`) supprimés, chiffres conservés | ✅ OK |

### Génération d'un carton (`generer_carton`, 300 cartons générés)

| ID | Point à tester | Statut |
|---|---|---|
| NP-05 | Grille de 3 lignes × 9 colonnes | ✅ OK |
| NP-06 | Exactement 5 numéros par ligne | ✅ OK |
| NP-07 | 15 numéros au total, tous différents | ✅ OK |
| NP-08 | Chaque colonne contient 1 à 3 numéros | ✅ OK |
| NP-09 | Plages par colonne : 1-9, 10-19, …, 70-79, 80-90 | ✅ OK |
| NP-10 | Numéros triés de haut en bas dans chaque colonne | ✅ OK |
| NP-11 | Tous les numéros de 1 à 90 peuvent sortir (bornes 1 et 90 incluses) | ✅ OK |
| NP-12 | Même graine aléatoire → même carton (reproductible) | ✅ OK |

### Ligne de commande (`main`)

| ID | Point à tester | Statut |
|---|---|---|
| NP-13 | Crée `parties/AAAA-MM-JJ_lieu/` avec `partie.json`, `cartons/`, `tirage/` | ✅ OK |
| NP-14 | Contenu de `partie.json` (date, lieu d'origine, liste des cartons, notes vides) | ✅ OK |
| NP-15 | Contenu d'un carton (`id`, `joueur` à `null`, grille) et tirage vide `[]` | ✅ OK |
| NP-16 | Sans `--cartons` : partie sans carton | ✅ OK |
| NP-17 | Refuse un dossier déjà existant sans rien écraser | ✅ OK |
| NP-18 | Refuse une date invalide sans créer de dossier | ✅ OK |
| NP-19 | Arguments manquants : sortie en erreur (code 2) | ✅ OK |
| NP-20 | Le script se lance en sous-processus (`--help`) | ✅ OK |
| NP-21 | Refuse un lieu qui ne contient aucune lettre ni chiffre | ✅ OK (BUG-01 corrigé) |
| NP-22 | Refuse un nombre de cartons négatif | ✅ OK (BUG-02 corrigé) |

## 2. `suivi.py` : saisie du tirage et état des cartons (`tests/test_suivi.py`)

| ID | Point à tester | Statut |
|---|---|---|
| SU-01 | Sans numéro : affiche l'état sans modifier le tirage | ✅ OK |
| SU-02 | Ajoute les numéros dans l'ordre donné et affiche le dernier tiré | ✅ OK |
| SU-03 | Ignore les numéros hors 1-90 (0, 91, négatifs) avec un message | ✅ OK |
| SU-04 | Ignore un numéro déjà tiré, y compris en double dans la même commande | ✅ OK |
| SU-05 | Accepte les bornes 1 et 90 | ✅ OK |
| SU-06 | Compte exact des cases cochées par ligne, total, manque pour quine et carton plein | ✅ OK |
| SU-07 | Quine détectée (« manque 0 pour quine ») | ✅ OK |
| SU-08 | Carton plein détecté (15/15) | ✅ OK |
| SU-09 | Cartons affichés dans l'ordre de leur numéro | ✅ OK |
| SU-10 | Le tirage est conservé d'un appel à l'autre | ✅ OK |
| SU-11 | Sur une vraie partie (copie), affichage correct sans modifier le fichier | ✅ OK |
| SU-12 | Un argument non numérique est ignoré avec un message (« Ignoré (pas un numéro) »), sans planter | ✅ OK (BUG-03 corrigé) |
| SU-13 | Dossier absent : message clair au lieu d'une trace d'erreur Python | ✅ OK (BUG-04 corrigé) |
| SU-14 | Sans argument : affiche l'usage, sans trace d'erreur | ✅ OK |
| SU-15 | 20 `suivi.py` lancés en même temps : aucun numéro perdu (verrou + écriture atomique) | ✅ OK (BUG-09 corrigé) |
| SU-16 | Aucun fichier temporaire laissé dans `tirage/` | ✅ OK |

## 3. `probabilites.py` : chances de carton plein (`tests/test_probabilites.py`)

| ID | Point à tester | Statut |
|---|---|---|
| PR-01 | Bornes : 0 sous 15 tirages, 1 à 90 tirages | ✅ OK |
| PR-02 | Refuse un nombre de tirages hors 0-90 | ✅ OK |
| PR-03 | Probabilité croissante avec le nombre de tirages | ✅ OK |
| PR-04 | Calcul exact identique à l'énumération de tous les tirages (petits cas, cartons disjoints ou avec numéros communs) | ✅ OK |
| PR-05 | Avec un seul carton, identique à la formule d'un carton | ✅ OK |
| PR-06 | La simulation donne le même résultat que le calcul exact | ✅ OK |
| PR-07 | Valeur pour les 12 cartons d'Orange à 48 tirages (0,0286 %) | ✅ OK |
| PR-08 | Ligne de commande : tableau correct, usage si argument manquant | ✅ OK |

## 4. Intégrité des données `parties/` (`tests/test_donnees.py`)

Vérifié sur chacun des dossiers de partie présents dans le dépôt.

| ID | Point à tester | Statut |
|---|---|---|
| DO-01 | Le dépôt contient au moins une partie | ✅ OK |
| DO-02 | Nom de dossier `AAAA-MM-JJ_lieu[_N]` et fichiers attendus présents | ✅ OK |
| DO-03 | `partie.json` complet, date cohérente avec le nom du dossier, cartons sans doublon | ✅ OK |
| DO-04 | Les cartons déclarés dans `partie.json` correspondent aux fichiers présents | ✅ OK |
| DO-05 | Chaque carton : `id` = nom du fichier, 3×9, 5 numéros par ligne, 15 numéros uniques, aucune colonne vide, plages de colonnes respectées | ✅ OK |
| DO-06 | Tirage : liste d'entiers de 1 à 90, sans doublon | ✅ OK |
| DO-07 | Pas deux dossiers avec le même numéro de partie pour un même jeu | ✅ OK |
| DO-08 | Numéros de série des cartons uniques dans une partie | ✅ OK |

Note : les cartons importés (Loto 2000) n'ont pas leurs colonnes triées de haut en bas. Ce n'est pas exigé pour les données, seulement pour les cartons générés (NP-10).

## 5. Cohérence des rapports Markdown (`tests/test_rapports.py`)

Les chiffres des rapports `*_AAAA-MM-JJ_lieu.md` sont recalculés à partir des données.

| ID | Point à tester | Statut |
|---|---|---|
| RA-01 | Chaque rapport correspond à un jeu présent dans `parties/` | ✅ OK |
| RA-02 | Nombre de parties et total de numéros tirés | ✅ OK |
| RA-03 | Tableau d'avancement : dossier, numéros tirés, dernier tiré, carton plein | ✅ OK |
| RA-04 | Cumul des cases cochées par carton, trié par ordre décroissant | ✅ OK |
| RA-05 | Statistiques par partie : nombre, dernier, pairs, ≤ 45, moyenne, cases cochées | ✅ OK |
| RA-06 | Répartition par dizaine | ✅ OK (BUG-05 corrigé) |
| RA-07 | Cases cochées par carton et par partie, avec total | ✅ OK |
| RA-08 | Listes « sortis dans N parties » | ✅ OK |
| RA-09 | Aucun rapport ne déclare périmé un fichier qui est à jour | ✅ OK (BUG-06 corrigé) |
| RA-10 | Tableau « Chances de carton plein » conforme au calcul exact, à la précision affichée | ✅ OK (BUG-07 corrigé) |

## 6. Application iOS / macOS (`LotoApp/Tests/main.swift`)

| ID | Point à tester | Statut |
|---|---|---|
| AP-01 | Saisie d'un carton : 15 numéros placés dans les bonnes colonnes (90 → colonne 80), refus de deux numéros de la même dizaine sur une ligne | ⏳ À confirmer |
| AP-02 | Objectifs : numéros manquants pour quine, double quine, carton plein ; plusieurs numéros gagnants possibles | ⏳ À confirmer |
| AP-03 | Enchaînement 2 quines → double quine → carton plein : noms des phases, ligne déjà gagnée exclue de la quine suivante | ⏳ À confirmer |
| AP-04 | Textes des conseils (« Plus qu'un numéro… », « Plus que 2 numéros… », planche indiquée) | ⏳ À confirmer |
| AP-05 | Victoire proposée au tirage qui complète la ligne, quel que soit l'ordre des numéros | ⏳ À confirmer |
| AP-06 | Victoire **plus** proposée au tirage suivant (quine ou double quine ratée), pas de « Criez-le ! » | ⏳ À confirmer (BUG-10 corrigé) |
| AP-07 | Après une victoire ratée, l'objectif devient une nouvelle ligne ; elle est réclamable à son propre tirage | ⏳ À confirmer |
| AP-08 | Double quine ratée : une ligne déjà complète reste utilisable avec une nouvelle ligne | ⏳ À confirmer |
| AP-09 | Simulation : après une victoire ratée, il faut encore des numéros ; carton sans ligne à compléter → pas de simulation | ⏳ À confirmer |
| AP-10 | Probabilité qu'un numéro gagnant sorte au prochain tirage | ⏳ À confirmer |
| AP-11 | Historique d'Orange importé : 10 parties, 500 numéros, le 80 sorti 10 fois, carton 009 à 97 cases, aller-retour JSON | ⏳ À confirmer |
| AP-12 | Données d'exemple : 3 soirées fictives, anonymes, cartons valides, partie en cours cohérente | ⏳ À confirmer |
| AP-13 | L'app compile pour macOS | ⏳ À confirmer |
| AP-14 | Saisie groupée (`12 45 3`) : arrêt sur le numéro qui fait gagner, le reste laissé dans le champ | ⬜ Non testé (interface, à vérifier à la main) |

## 7. Points non automatisés

| ID | Point à tester | Statut |
|---|---|---|
| MA-01 | Simulation des chances de carton plein | ✅ Automatisé : `probabilites.py`, tests PR-01 à PR-08 et RA-10 |
| MA-02 | Exactitude des cartons saisis par rapport aux cartons papier | ⬜ Vérification manuelle (le format est contrôlé par DO-05, pas les numéros) |
| MA-03 | Exactitude du tirage saisi par rapport aux annonces en salle (parties 6 à 10 plus longues, cf. rapports) | ⬜ Vérification manuelle (doublons et plages contrôlés par DO-06) |
| MA-04 | Écriture concurrente du tirage (deux `suivi.py` en même temps) | ✅ Automatisé : SU-15 (verrou Linux/macOS ; sous Windows, pas de verrou) |

## Défauts connus

Aucun.

## Défauts corrigés (13/11/2026)

| ID | Fichier | Défaut | Correction | Test |
|---|---|---|---|---|
| BUG-01 | `nouvelle_partie.py` | Un lieu comme `"!!!"` donne un dossier `2026-11-20_` sans nom de lieu | Refus avec message, aucun dossier créé | NP-21 |
| BUG-02 | `nouvelle_partie.py` | `--cartons -3` est accepté et crée une partie sans carton | Refus avec message, aucun dossier créé | NP-22 |
| BUG-03 | `suivi.py` | `./suivi.py dossier douze` plante (`ValueError`) | Argument ignoré avec le message « Ignoré (pas un numéro) » | SU-12 |
| BUG-04 | `suivi.py` | Dossier absent ou oublié : trace d'erreur Python au lieu d'un message d'usage | Message « Partie introuvable » ou usage, code de sortie 1 | SU-13 |
| BUG-05 | `statistiques_2026-11-11_orange.md` | La répartition par dizaine compte 1-10, 11-20, …, 81-90 alors que les colonnes annoncent 1-9, 10s, …, 80-90 (ex. partie 1 : 7 dans « 1-9 » au lieu de 6) | Tableau recalculé avec les plages annoncées | RA-06 |
| BUG-06 | `rapport_final_2026-11-11_orange.md` | Dit que `statistiques_2026-11-11_orange.md` est périmé (parties 1 à 4) alors qu'il couvre maintenant les 10 parties | Mention retirée | RA-09 |
| BUG-07 | `rapport_global_2026-11-11_orange.md` | Chance de carton plein à 55 tirages annoncée à 0,03 % au lieu de 0,31 % | Tableau remplacé par le calcul exact sur les 12 cartons | RA-10 |
| BUG-08 | `rapport_global_2026-11-11_orange.md` | « 1 sur 3 000 par carton » : c'est la chance pour les 12 cartons ensemble ; pour un carton c'est 1 sur 42 000 | Phrase corrigée | (relu à la main) |
| BUG-09 | `suivi.py` | Deux saisies simultanées pouvaient perdre des numéros (lecture puis écriture sans verrou) | Verrou de fichier et écriture atomique | SU-15 |
| BUG-10 | App (`Analyse.swift`) | Une quine (ou double quine, carton plein) restait proposée à la validation aux tirages suivants, alors qu'elle ne se réclame qu'au tirage qui la complète | La victoire n'est proposée que si le dernier numéro tiré complète une des lignes ; sinon il faut compléter une nouvelle ligne. La saisie groupée s'arrête sur le numéro gagnant | AP-05 à AP-09 |

## Mise à jour de cette mémoire

- Nouveau point à tester : lui donner l'identifiant suivant de sa section, écrire le test avec l'identifiant en commentaire, ajouter la ligne ici.
- Bug corrigé : retirer le `xfail` du test, passer le statut à ✅ et retirer la ligne de « Défauts connus ».
- Après chaque exécution, mettre à jour la ligne « Dernière exécution ».
