# LOTO

- Tests : `python -m pytest` (dépendances : `pip install -r requirements-dev.txt`). La CI GitHub Actions (`.github/workflows/tests.yml`) les lance à chaque push.
- `MEMOIRE_TESTS.md` liste tout ce qui doit être testé avec son statut (✅ OK, ❌ échec connu, ⬜ non testé) et les défauts connus. La tenir à jour à chaque ajout de fonctionnalité, de test ou de correction de bug.
- Les bugs connus sont des tests `xfail(strict=True)` : quand un bug est corrigé, retirer le marqueur et mettre la mémoire à jour.
- Après modification d'une partie ou d'un rapport, relancer les tests : ils vérifient l'intégrité des données et les chiffres des rapports.
