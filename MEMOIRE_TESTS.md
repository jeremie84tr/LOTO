# Mémoire des tests : LOTO

Liste de tout ce qu'il faut tester dans l'application, avec le statut de chaque point.
Les identifiants (`NP-xx`, `SU-xx`…) sont repris en commentaire dans les tests (`tests/`).

Dernière exécution : 13/11/2026, `python -m pytest` : **106 réussis, 6 échecs connus (xfail), 0 échec**.

Légende des statuts :

- ✅ **OK** : testé, passe.
- ❌ **Échec connu** : testé, le défaut existe. Le test est marqué `xfail(strict=True)` : la CI reste verte tant que le bug existe et devient rouge quand il est corrigé, pour penser à retirer le marqueur et à passer le statut à ✅.
- ⬜ **Non testé** : identifié, pas encore automatisé.

Lancer les tests :

    pip install -r requirements-dev.txt
    python -m pytest

La CI (`.github/workflows/tests.yml`) lance la suite à chaque push sur toutes les branches et sur chaque pull request, sous Python 3.10 et 3.13.

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
| NP-21 | Refuse un lieu qui ne contient aucune lettre ni chiffre | ❌ Échec connu (BUG-01) |
| NP-22 | Refuse un nombre de cartons négatif | ❌ Échec connu (BUG-02) |

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
| SU-12 | Un argument non numérique est ignoré avec un message, sans planter | ❌ Échec connu (BUG-03) |
| SU-13 | Dossier absent : message clair au lieu d'une trace d'erreur Python | ❌ Échec connu (BUG-04) |

## 3. Intégrité des données `parties/` (`tests/test_donnees.py`)

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

## 4. Cohérence des rapports Markdown (`tests/test_rapports.py`)

Les chiffres des rapports `*_AAAA-MM-JJ_lieu.md` sont recalculés à partir des données.

| ID | Point à tester | Statut |
|---|---|---|
| RA-01 | Chaque rapport correspond à un jeu présent dans `parties/` | ✅ OK |
| RA-02 | Nombre de parties et total de numéros tirés | ✅ OK |
| RA-03 | Tableau d'avancement : dossier, numéros tirés, dernier tiré, carton plein | ✅ OK |
| RA-04 | Cumul des cases cochées par carton, trié par ordre décroissant | ✅ OK |
| RA-05 | Statistiques par partie : nombre, dernier, pairs, ≤ 45, moyenne, cases cochées | ✅ OK |
| RA-06 | Répartition par dizaine | ❌ Échec connu (BUG-05) |
| RA-07 | Cases cochées par carton et par partie, avec total | ✅ OK |
| RA-08 | Listes « sortis dans N parties » | ✅ OK |
| RA-09 | Aucun rapport ne déclare périmé un fichier qui est à jour | ❌ Échec connu (BUG-06) sur `rapport_final` |

## 5. Points non automatisés

| ID | Point à tester | Statut |
|---|---|---|
| MA-01 | Simulation des chances de carton plein (rapport global) : pas de script dans le dépôt pour la refaire | ⬜ Non testé |
| MA-02 | Exactitude des cartons saisis par rapport aux cartons papier | ⬜ Non testé (vérification manuelle) |
| MA-03 | Exactitude du tirage saisi par rapport aux annonces en salle (cf. « points à vérifier » des rapports) | ⬜ Non testé (vérification manuelle) |
| MA-04 | Écriture concurrente du tirage (deux `suivi.py` en même temps) | ⬜ Non testé |

## Défauts connus

| ID | Fichier | Description | Test |
|---|---|---|---|
| BUG-01 | `nouvelle_partie.py` | Un lieu comme `"!!!"` donne un dossier `2026-11-20_` sans nom de lieu | NP-21 |
| BUG-02 | `nouvelle_partie.py` | `--cartons -3` est accepté et crée une partie sans carton | NP-22 |
| BUG-03 | `suivi.py` | `./suivi.py dossier douze` plante (`ValueError`) | SU-12 |
| BUG-04 | `suivi.py` | Dossier absent ou oublié : trace d'erreur Python au lieu d'un message d'usage | SU-13 |
| BUG-05 | `statistiques_2026-11-11_orange.md` | La répartition par dizaine compte 1-10, 11-20, …, 81-90 alors que les colonnes annoncent 1-9, 10s, …, 80-90 (ex. partie 1 : 7 dans « 1-9 » au lieu de 6) | RA-06 |
| BUG-06 | `rapport_final_2026-11-11_orange.md` | Dit que `statistiques_2026-11-11_orange.md` est périmé (parties 1 à 4) alors qu'il couvre maintenant les 10 parties | RA-09 |

## Mise à jour de cette mémoire

- Nouveau point à tester : lui donner l'identifiant suivant de sa section, écrire le test avec l'identifiant en commentaire, ajouter la ligne ici.
- Bug corrigé : retirer le `xfail` du test, passer le statut à ✅ et retirer la ligne de « Défauts connus ».
- Après chaque exécution, mettre à jour la ligne « Dernière exécution ».
