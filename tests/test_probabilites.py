"""Tests de probabilites.py (chances de carton plein)."""
import importlib.util
import random
from itertools import combinations
from math import comb

import pytest

from conftest import PARTIES, RACINE

spec = importlib.util.spec_from_file_location("probabilites", RACINE / "probabilites.py")
pr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pr)

ORANGE = PARTIES / "2026-11-11_orange"


def _brute(cartons, n, total):
    """Énumère tous les tirages possibles (petits cas uniquement)."""
    cas = list(combinations(range(1, total + 1), n))
    return sum(any(c <= set(t) for c in cartons) for t in cas) / len(cas)


def test_bornes_un_carton():  # PR-01
    assert pr.proba_un_carton(14) == 0
    assert pr.proba_un_carton(15) == pytest.approx(1 / comb(90, 15))
    assert pr.proba_un_carton(90) == 1


@pytest.mark.parametrize("n", [-1, 91])
def test_n_invalide(n):  # PR-02
    with pytest.raises(ValueError):
        pr.proba_un_carton(n)
    with pytest.raises(ValueError):
        pr.proba_au_moins_un([{1}], n)


def test_croissante_avec_n():  # PR-03
    valeurs = [pr.proba_un_carton(n) for n in range(15, 91)]
    assert valeurs == sorted(valeurs)


@pytest.mark.parametrize("cartons, n", [
    ([{1, 2, 3}], 5),
    ([{1, 2, 3}, {4, 5, 6}], 6),          # cartons disjoints
    ([{1, 2, 3}, {3, 4, 5}], 6),          # cartons avec un numéro commun
    ([{1, 2}, {2, 3}, {1, 3}, {5, 6}], 4),
])
def test_exact_contre_enumeration(cartons, n):  # PR-04
    assert pr.proba_au_moins_un(cartons, n, total=10) == pytest.approx(_brute(cartons, n, 10))
    if len(cartons) == 1:
        assert pr.proba_un_carton(n, taille=3, total=10) == pytest.approx(_brute(cartons, n, 10))


def test_un_seul_carton_identique_a_formule():  # PR-05
    c = pr.charger_cartons(ORANGE)[0]
    for n in (20, 48, 70):
        assert pr.proba_au_moins_un([c], n) == pytest.approx(pr.proba_un_carton(n))


def test_simulation_proche_du_calcul():  # PR-06
    cartons = [{1, 2, 3}, {3, 4, 5}, {7, 8, 9}]
    exact = pr.proba_au_moins_un(cartons, 8, total=20)
    sim = pr.simuler(cartons, 8, 20000, random.Random(1), total=20)
    assert sim == pytest.approx(exact, abs=0.01)


def test_cartons_orange():  # PR-07
    cartons = pr.charger_cartons(ORANGE)
    assert len(cartons) == 12 and all(len(c) == 15 for c in cartons)
    p48 = pr.proba_au_moins_un(cartons, 48)
    assert p48 == pytest.approx(0.000286, rel=0.01)
    assert p48 <= 12 * pr.proba_un_carton(48)  # borne de l'union


def test_cli(run_script):  # PR-08
    r = run_script("probabilites.py", ORANGE, 48)
    assert r.returncode == 0
    assert "| 48 | 0.0024 % | 0.0286 % |" in r.stdout
    r = run_script("probabilites.py")
    assert r.returncode != 0 and "Usage" in r.stderr
