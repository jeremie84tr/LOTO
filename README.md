# LOTO

Chaque partie a son espace : `parties/AAAA-MM-JJ_lieu/`

- `partie.json` : date, lieu, liste des cartons, notes
- `cartons/carton_NNN.json` : un carton (3 lignes x 9 colonnes, 15 numéros, `null` = case vide)
- `tirage/numeros.json` : numéros tirés, dans l'ordre

Créer une partie :

    ./nouvelle_partie.py 2026-11-20 "Salle des fêtes" --cartons 20

Tests :

    pip install -r requirements-dev.txt
    python -m pytest

Liste des points testés et leur statut : `MEMOIRE_TESTS.md`.
