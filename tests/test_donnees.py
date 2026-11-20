"""Intégrité des données de parties/ (partie.json, cartons, tirage)."""
import json
import re

import pytest

from conftest import PARTIES

DOSSIERS = sorted(p for p in PARTIES.iterdir() if p.is_dir()) if PARTIES.exists() else []
IDS = [d.name for d in DOSSIERS]


def _plage(col):
    return (1, 9) if col == 0 else (80, 90) if col == 8 else (col * 10, col * 10 + 9)


def _cartons(d):
    return {f.stem.removeprefix("carton_"): json.loads(f.read_text())
            for f in sorted((d / "cartons").glob("carton_*.json"))}


def test_au_moins_une_partie():  # DO-01
    assert DOSSIERS


@pytest.mark.parametrize("d", DOSSIERS, ids=IDS)
def test_structure_dossier(d):  # DO-02
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}_[a-z0-9-]+(_\d+)?", d.name)
    assert (d / "partie.json").is_file()
    assert (d / "cartons").is_dir()
    assert (d / "tirage" / "numeros.json").is_file()


@pytest.mark.parametrize("d", DOSSIERS, ids=IDS)
def test_partie_json(d):  # DO-03
    p = json.loads((d / "partie.json").read_text())
    assert {"date", "lieu", "cartons", "notes"} <= p.keys()
    assert d.name.startswith(p["date"] + "_")
    assert isinstance(p["lieu"], str) and p["lieu"]
    assert len(p["cartons"]) == len(set(p["cartons"]))


@pytest.mark.parametrize("d", DOSSIERS, ids=IDS)
def test_cartons_declares_presents(d):  # DO-04
    p = json.loads((d / "partie.json").read_text())
    assert sorted(p["cartons"]) == sorted(_cartons(d))


@pytest.mark.parametrize("d", DOSSIERS, ids=IDS)
def test_cartons_valides(d):  # DO-05
    for cid, c in _cartons(d).items():
        assert c["id"] == cid
        g = c["grille"]
        assert len(g) == 3 and all(len(l) == 9 for l in g), cid
        assert [sum(x is not None for x in l) for l in g] == [5, 5, 5], cid
        nums = [x for l in g for x in l if x is not None]
        assert len(set(nums)) == 15, cid
        for col in range(9):
            vals = [g[l][col] for l in range(3) if g[l][col] is not None]
            assert vals, f"{cid} colonne {col} vide"
            lo, hi = _plage(col)
            assert all(lo <= v <= hi for v in vals), f"{cid} colonne {col}: {vals}"


@pytest.mark.parametrize("d", DOSSIERS, ids=IDS)
def test_tirage_valide(d):  # DO-06
    t = json.loads((d / "tirage" / "numeros.json").read_text())
    assert isinstance(t, list)
    assert all(isinstance(n, int) and 1 <= n <= 90 for n in t)
    assert len(t) == len(set(t)), "numéro tiré deux fois"


def test_numeros_de_partie_uniques():  # DO-07
    nums = {}
    for d in DOSSIERS:
        p = json.loads((d / "partie.json").read_text())
        if "partie" in p:
            cle = (p["date"], p["lieu"], p["partie"])
            assert cle not in nums, f"{d.name} et {nums.get(cle)}"
            nums[cle] = d.name


def test_series_de_cartons_uniques_par_partie():  # DO-08
    for d in DOSSIERS:
        series = [c["serie"] for c in _cartons(d).values() if "serie" in c]
        assert len(series) == len(set(series)), d.name
