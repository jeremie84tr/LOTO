#!/usr/bin/env python3
"""Génère les données d'exemple embarquées dans l'app (entièrement fictives).

Usage : ./generer_exemples.py -o ../Loto/Ressources/exemples.json [--victoire]

Lieux inventés, cartons tirés au hasard, tirages simulés avec une salle de
200 cartons pour que les phases tombent à des moments réalistes. La dernière
partie de la première soirée est en cours : un carton à 1 numéro de la
deuxième quine, plusieurs à 2 numéros. Avec --victoire, le numéro gagnant
est ajouté (pour la capture « QUINE ! »).
"""
import argparse, json, random, uuid

ESPACE = uuid.UUID("0b7e1f3a-2c4d-4e5f-8a9b-0c1d2e3f4a5b")


def uid(*m):
    return str(uuid.uuid5(ESPACE, "/".join(map(str, m)))).upper()


def carton(rng):
    """Carton français : 3 lignes × 9 colonnes, 5 numéros par ligne."""
    while True:
        comptes = [1] * 9
        while sum(comptes) < 15:
            c = rng.randrange(9)
            if comptes[c] < 3:
                comptes[c] += 1
        lignes = [rng.sample(range(3), n) for n in comptes]
        if all(sum(l in r for r in lignes) == 5 for l in range(3)):
            break
    g = [[None] * 9 for _ in range(3)]
    for c, rows in enumerate(lignes):
        lo, hi = (1 if c == 0 else c * 10), (9 if c == 0 else 90 if c == 8 else c * 10 + 9)
        for l, n in zip(sorted(rows), sorted(rng.sample(range(lo, hi + 1), len(rows)))):
            g[l][c] = n
    return g


def lignes(g):
    return [[n for n in r if n] for r in g]


def evenements(cartons, tirage):
    """Pour chaque carton : index (1-based) de complétion de chaque ligne."""
    pos = {n: i + 1 for i, n in enumerate(tirage)}
    return [sorted(max(pos.get(n, 10**6) for n in l) for l in lignes(g)) for g in cartons]


def jouer(phases, nos_cartons, salle, rng):
    """Simule une partie complète ; renvoie tirage et résultats des phases."""
    tirage = rng.sample(range(1, 91), 90)
    tous = [(True, i, g) for i, g in enumerate(nos_cartons)] + [(False, None, g) for g in salle]
    pos = {n: i + 1 for i, n in enumerate(tirage)}
    temps = [[max(pos[n] for n in l) for l in lignes(g)] for _, _, g in tous]
    resultats, apres, utilisees = [], 0, set()
    for type_ in phases:
        k = {"quine": 1, "doubleQuine": 2, "cartonPlein": 3}[type_]
        meilleur = None
        for j, t in enumerate(temps):
            dispo = sorted((v, li) for li, v in enumerate(t) if not (type_ == "quine" and (j, li) in utilisees))
            if len(dispo) < k:
                continue
            quand = dispo[k - 1][0]
            if quand > apres and (meilleur is None or quand < meilleur[0]):
                meilleur = (quand, j, [li for _, li in dispo[:k]])
        quand, j, lis = meilleur
        if type_ == "quine":
            utilisees.update((j, li) for li in lis)
        nous, idx, _ = tous[j]
        resultats.append((type_, quand, nous, idx, lis))
        apres = quand
    return tirage[:apres], resultats


def phase_json(sid, num, i, type_, quand=None, nous=False, cid=None, lis=None, lot=""):
    p = {"id": uid(sid, num, i), "type": type_, "lot": lot}
    if quand is not None:
        p["gagneeApres"] = quand
        p["gagnant"] = {"parNous": nous, "lignes": sorted(lis) if nous else []}
        if nous:
            p["gagnant"]["cartonID"] = cid
    return p


LOTS = {"quine": ["Panier garni", "Bon d'achat 30 €", "Jambon sec", "Cafetière"],
        "doubleQuine": ["Bon d'achat 80 €", "Robot de cuisine", "Trottinette"],
        "cartonPlein": ["Téléviseur", "Week-end pour deux", "Tablette", "Vélo électrique"]}


def soiree(nom, lieu, date, phases, cartons, nb_parties, rng, en_cours=None):
    sid = uid(nom)
    salle = [carton(rng) for _ in range(200)]
    ids = [f"{i + 1:03d}" for i in range(len(cartons))]
    parties = []
    for num in range(1, nb_parties + 1):
        tirage, res = jouer(phases, cartons, salle, rng)
        parties.append({
            "id": uid(sid, num), "numero": num, "tirage": tirage, "notes": "", "importee": False,
            "phases": [phase_json(sid, num, i, t, q, nous, ids[idx] if nous else None, lis, rng.choice(LOTS[t]))
                       for i, (t, q, nous, idx, lis) in enumerate(res)],
        })
    if en_cours:
        parties.append(en_cours(sid, nb_parties + 1, salle))
    return {
        "id": sid, "date": f"{date}T18:00:00Z", "lieu": lieu, "notes": "Données d'exemple : vous pouvez supprimer cette soirée.",
        "deroulementParDefaut": phases,
        "cartons": [{"id": ids[i], "planche": "AB"[i // 6], "grille": g} for i, g in enumerate(cartons)],
        "parties": parties,
    }


def partie_en_cours(cartons, rng, victoire):
    """Partie à 28 numéros : quine 1 gagnée ailleurs, un carton à 1 numéro de la quine 2."""
    ids = [f"{i + 1:03d}" for i in range(len(cartons))]

    def fabrique(sid, num, salle):
        while True:
            tirage = rng.sample(range(1, 91), 28)
            tires = set(tirage)
            manque = [sorted(len([n for n in l if n not in tires]) for l in lignes(g)) for g in cartons]
            if any(m[0] == 0 for m in manque):
                continue
            uns = [i for i, m in enumerate(manque) if m[0] == 1]
            deux = [i for i, m in enumerate(manque) if m[0] == 2]
            if len(uns) != 1 or len(deux) < 3 or manque[uns[0]][1] != 1:
                continue
            ev = sorted(e for g in salle for e in evenements([g], tirage)[0])
            if not (8 <= ev[0] <= 20 and ev[1] > 28):
                continue
            break
        phases = [phase_json(sid, num, 0, "quine", ev[0], False, lot="Panier garni"),
                  phase_json(sid, num, 1, "quine", lot="Bon d'achat 30 €"),
                  phase_json(sid, num, 2, "doubleQuine", lot="Robot de cuisine"),
                  phase_json(sid, num, 3, "cartonPlein", lot="Téléviseur")]
        if victoire:
            g = cartons[uns[0]]
            gagnant = next(n for l in lignes(g) for n in l if n not in tires
                           and len([x for x in l if x not in tires]) == 1)
            tirage.append(gagnant)
        return {"id": uid(sid, num), "numero": num, "tirage": tirage, "notes": "", "importee": False, "phases": phases}
    return fabrique


def main():
    p = argparse.ArgumentParser()
    p.add_argument("-o", "--sortie", default="exemples.json")
    p.add_argument("--victoire", action="store_true")
    a = p.parse_args()
    rng = random.Random(2026)
    cartons = [carton(rng) for _ in range(12)]
    q2 = ["quine", "quine", "doubleQuine", "cartonPlein"]
    classique = ["quine", "doubleQuine", "cartonPlein"]
    donnees = [
        soiree("salle", "Salle des fêtes", "2026-12-05", q2, cartons, 5, rng,
               en_cours=partie_en_cours(cartons, rng, a.victoire)),
        soiree("foyer", "Foyer rural", "2026-11-21", q2, cartons, 8, rng),
        soiree("ecole", "Loto de l'école", "2026-10-17", classique, [carton(rng) for _ in range(6)], 6, rng),
    ]
    with open(a.sortie, "w") as f:
        json.dump(donnees, f, ensure_ascii=False, indent=1)
    print(f"{a.sortie} : {len(donnees)} soirées, {sum(len(s['parties']) for s in donnees)} parties")


if __name__ == "__main__":
    main()
