"""Tests de suivi.py (ajout de numéros tirés et affichage de l'état des cartons)."""
import json

import pytest


def _tirage(d):
    return json.loads((d / "tirage" / "numeros.json").read_text())


def _ligne(sortie, cid):
    return next(l for l in sortie.splitlines() if l.startswith(f"{cid}:"))


def test_affichage_sans_ajout(run_script, partie_tmp):  # SU-01
    d = partie_tmp()
    r = run_script("suivi.py", d)
    assert r.returncode == 0
    assert "0 numéros tirés, dernier: -" in r.stdout
    assert _tirage(d) == []


def test_ajout_numeros_dans_l_ordre(run_script, partie_tmp):  # SU-02
    d = partie_tmp(tirage=[5])
    r = run_script("suivi.py", d, 10, 1, 90)
    assert r.returncode == 0
    assert _tirage(d) == [5, 10, 1, 90]
    assert "4 numéros tirés, dernier: 90" in r.stdout


@pytest.mark.parametrize("hors", [0, 91, -4, 100])
def test_numero_hors_plage_ignore(run_script, partie_tmp, hors):  # SU-03
    d = partie_tmp()
    r = run_script("suivi.py", d, hors, 7)
    assert f"Ignoré (hors 1-90): {hors}" in r.stdout
    assert _tirage(d) == [7]


def test_numero_deja_tire_ignore(run_script, partie_tmp):  # SU-04
    d = partie_tmp(tirage=[7])
    r = run_script("suivi.py", d, 7, 8, 8)
    assert r.stdout.count("Déjà tiré") == 2
    assert _tirage(d) == [7, 8]


def test_bornes_1_et_90_acceptees(run_script, partie_tmp):  # SU-05
    d = partie_tmp()
    run_script("suivi.py", d, 1, 90)
    assert _tirage(d) == [1, 90]


def test_comptage_par_ligne_et_total(run_script, partie_tmp):  # SU-06
    d = partie_tmp()
    r = run_script("suivi.py", d, 1, 10, 50, 3)
    assert _ligne(r.stdout, "001") == "001:  3/15  lignes [2, 1, 0]  manque 3 pour quine, 12 pour carton plein"
    assert _ligne(r.stdout, "002") == "002:  1/15  lignes [1, 0, 0]  manque 4 pour quine, 14 pour carton plein"


def test_quine_detectee(run_script, partie_tmp):  # SU-07
    d = partie_tmp()
    r = run_script("suivi.py", d, 1, 10, 20, 30, 40)
    assert "manque 0 pour quine" in _ligne(r.stdout, "001")


def test_carton_plein(run_script, partie_tmp):  # SU-08
    d = partie_tmp()
    grille = json.loads((d / "cartons" / "carton_001.json").read_text())["grille"]
    nums = [x for l in grille for x in l if x]
    r = run_script("suivi.py", d, *nums)
    assert _ligne(r.stdout, "001").startswith("001: 15/15")
    assert "0 pour carton plein" in _ligne(r.stdout, "001")


def test_cartons_affiches_tries(run_script, partie_tmp):  # SU-09
    d = partie_tmp()
    ids = [l.split(":")[0] for l in run_script("suivi.py", d).stdout.splitlines()[1:]]
    assert ids == ["001", "002"]


def test_persistance_entre_appels(run_script, partie_tmp):  # SU-10
    d = partie_tmp()
    run_script("suivi.py", d, 12)
    run_script("suivi.py", d, 34)
    assert _tirage(d) == [12, 34]


def test_partie_reelle_lecture_seule(run_script, tmp_path):  # SU-11 état d'une vraie partie (copie)
    import shutil
    from conftest import PARTIES
    src = PARTIES / "2026-11-11_orange"
    d = tmp_path / src.name
    shutil.copytree(src, d)
    avant = _tirage(d)
    r = run_script("suivi.py", d)
    assert r.returncode == 0
    assert f"{len(avant)} numéros tirés, dernier: {avant[-1]}" in r.stdout
    assert len(r.stdout.splitlines()) == 1 + 12
    assert _tirage(d) == avant


@pytest.mark.xfail(strict=True, reason="BUG-03 : un argument non numérique fait planter suivi.py (ValueError)")
def test_argument_non_numerique(run_script, partie_tmp):  # SU-12
    d = partie_tmp()
    r = run_script("suivi.py", d, "douze", 5)
    assert r.returncode == 0 and _tirage(d) == [5]


@pytest.mark.xfail(strict=True, reason="BUG-04 : dossier absent ou sans argument -> traceback au lieu d'un message d'usage")
def test_dossier_absent(run_script, tmp_path):  # SU-13
    r = run_script("suivi.py", tmp_path / "inexistant")
    assert "Traceback" not in r.stderr
