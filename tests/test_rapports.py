"""Cohérence des rapports Markdown avec les données de parties/."""
import json
import re
from collections import Counter

import pytest

from conftest import PARTIES, RACINE


def _tableaux(md):
    """Renvoie la liste des tableaux Markdown : [(entetes, [lignes])]."""
    tableaux, courant = [], None
    for l in md.splitlines():
        if l.startswith("|"):
            cells = [c.strip() for c in l.strip().strip("|").split("|")]
            if courant is None:
                courant = (cells, [])
                tableaux.append(courant)
            elif not set("".join(cells)) <= set("-: "):
                courant[1].append(cells)
        else:
            courant = None
    return tableaux


def _tableau(md, *entetes):
    for t in _tableaux(md):
        if list(entetes) == t[0][:len(entetes)]:
            return t
    raise AssertionError(f"tableau {entetes} introuvable")


def _jeux():
    """{(date, lieu_slug): {numero_partie: dossier}} pour les dossiers numérotés."""
    jeux = {}
    for d in sorted(PARTIES.iterdir()):
        p = json.loads((d / "partie.json").read_text())
        if "partie" in p:
            base = re.sub(r"_\d+$", "", d.name)
            jeux.setdefault(base, {})[p["partie"]] = d
    return jeux


JEUX = _jeux()
RAPPORTS = sorted(RACINE.glob("*_[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_*.md"))


def _donnees(base):
    out = {}
    for num, d in sorted(JEUX[base].items()):
        tirage = json.loads((d / "tirage" / "numeros.json").read_text())
        cartons = {f.stem[7:]: json.loads(f.read_text())["grille"]
                   for f in sorted((d / "cartons").glob("*.json"))}
        coches = {cid: sum(x in tirage for l in g for x in l if x) for cid, g in cartons.items()}
        out[num] = {"dossier": d.name, "tirage": tirage, "coches": coches}
    return out


def _base(rapport):
    return re.search(r"(\d{4}-\d{2}-\d{2}_[a-z0-9-]+)\.md$", rapport.name).group(1)


@pytest.mark.parametrize("rapport", RAPPORTS, ids=[r.name for r in RAPPORTS])
def test_rapport_reference_un_jeu_existant(rapport):  # RA-01
    assert _base(rapport) in JEUX


@pytest.mark.parametrize("rapport", RAPPORTS, ids=[r.name for r in RAPPORTS])
def test_total_numeros_tires(rapport):  # RA-02
    data = _donnees(_base(rapport))
    total = sum(len(v["tirage"]) for v in data.values())
    md = rapport.read_text()
    assert f"{len(data)} parties, {total} numéros tirés au total" in md


@pytest.mark.parametrize("rapport", [r for r in RAPPORTS if not r.name.startswith("statistiques")],
                         ids=lambda r: r.name)
def test_tableau_avancement(rapport):  # RA-03
    base = _base(rapport)
    data = _donnees(base)
    entetes, lignes = _tableau(rapport.read_text(), "Partie", "Dossier")
    assert len(lignes) == len(data)
    for l in lignes:
        v = data[int(l[0])]
        assert v["dossier"].removeprefix(base.split("_")[0] + "_") == l[1]
        assert int(l[2]) == len(v["tirage"])
        assert int(l[3]) == v["tirage"][-1]
        if len(l) > 4:  # colonne "Carton plein"
            assert l[4] == ("oui" if 15 in v["coches"].values() else "non")


@pytest.mark.parametrize("rapport", [r for r in RAPPORTS if not r.name.startswith("statistiques")],
                         ids=lambda r: r.name)
def test_cumul_cases_par_carton(rapport):  # RA-04
    data = _donnees(_base(rapport))
    cumul = Counter()
    for v in data.values():
        cumul.update(v["coches"])
    _, lignes = _tableau(rapport.read_text(), "Carton", "Cases cochées")
    assert {l[0]: int(l[1]) for l in lignes} == dict(cumul)
    valeurs = [int(l[1]) for l in lignes]
    assert valeurs == sorted(valeurs, reverse=True), "tableau non trié"


STATS = [r for r in RAPPORTS if r.name.startswith("statistiques")]



@pytest.mark.parametrize("rapport", STATS, ids=lambda r: r.name)
def test_statistiques_par_partie(rapport):  # RA-05
    data = _donnees(_base(rapport))
    _, lignes = _tableau(rapport.read_text(), "Partie", "Numéros tirés")
    assert len(lignes) == len(data), "statistiques périmées"
    for l in lignes:
        t = data[int(l[0])]["tirage"]
        assert int(l[1]) == len(t)
        assert int(l[2]) == t[-1]
        assert int(l[3]) == sum(n % 2 == 0 for n in t)
        assert int(l[4]) == sum(n <= 45 for n in t)
        assert float(l[5].replace(",", ".")) == pytest.approx(sum(t) / len(t), abs=0.05)
        assert int(l[6]) == sum(data[int(l[0])]["coches"].values())


@pytest.mark.parametrize("rapport", STATS, ids=lambda r: r.name)
def test_statistiques_dizaines(rapport):  # RA-06
    data = _donnees(_base(rapport))
    _, lignes = _tableau(rapport.read_text(), "Partie", "1-9")
    for l in lignes:
        dz = Counter(min(n // 10, 8) for n in data[int(l[0])]["tirage"])
        assert [int(x) for x in l[1:]] == [dz[i] for i in range(9)]


@pytest.mark.parametrize("rapport", STATS, ids=lambda r: r.name)
def test_statistiques_cases_par_carton_et_partie(rapport):  # RA-07
    data = _donnees(_base(rapport))
    _, lignes = _tableau(rapport.read_text(), "Carton", "Partie 1")
    for l in lignes:
        par_partie = [data[i]["coches"][l[0]] for i in sorted(data)]
        assert [int(x) for x in l[1:-1]] == par_partie
        assert int(l[-1]) == sum(par_partie)


@pytest.mark.parametrize("rapport", RAPPORTS, ids=[r.name for r in RAPPORTS])
def test_frequence_des_numeros(rapport):  # RA-08
    data = _donnees(_base(rapport))
    freq = Counter(n for v in data.values() for n in set(v["tirage"]))
    md = rapport.read_text()
    for m in re.finditer(r"Sortis dans (\d+) parties(?: \(\d+\))? : ([\d, ]+)$", md, re.M):
        attendu = sorted(n for n in range(1, 91) if freq[n] == int(m.group(1)))
        assert [int(x) for x in m.group(2).split(",")] == attendu, m.group(0)
    try:
        _, lignes = _tableau(md, "Parties", "Nb de numéros")
    except AssertionError:
        return
    for l in lignes:
        attendu = sorted(n for n in range(1, 91) if freq[n] == int(l[0]))
        assert int(l[1]) == len(attendu)
        assert [int(x) for x in l[2].split(",")] == attendu


@pytest.mark.parametrize("rapport", RAPPORTS, ids=[r.name for r in RAPPORTS])
def test_pas_de_mention_de_fichier_perime(rapport):  # RA-09
    """Un rapport ne doit pas déclarer périmé un fichier qui est désormais à jour."""
    md = rapport.read_text()
    for m in re.finditer(r"`(statistiques_[^`]+\.md)` est périmé", md):
        stats = RACINE / m.group(1)
        data = _donnees(_base(stats))
        _, lignes = _tableau(stats.read_text(), "Partie", "Numéros tirés")
        assert len(lignes) != len(data), f"{rapport.name} dit {m.group(1)} périmé alors qu'il est à jour"
