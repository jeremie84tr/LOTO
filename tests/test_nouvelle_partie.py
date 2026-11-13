"""Tests de nouvelle_partie.py (slug, génération de cartons, CLI)."""
import json
import random

import pytest


# ---------- NP-01..NP-04 : slug() ----------

@pytest.mark.parametrize("texte, attendu", [
    ("Orange", "orange"),                              # NP-01 minuscules
    ("Salle des fêtes", "salle-des-fetes"),            # NP-02 accents + espaces
    ("  L'Isle--sur  la Sorgue! ", "l-isle-sur-la-sorgue"),  # NP-03 ponctuation, tirets en bord
    ("Château d'Œx 2026", "chateau-d-x-2026"),         # NP-04 caractères non décomposables
])
def test_slug(np_mod, texte, attendu):
    assert np_mod.slug(texte) == attendu


# ---------- NP-05..NP-11 : generer_carton() ----------

def _plage(col):
    if col == 0:
        return 1, 9
    if col == 8:
        return 80, 90
    return col * 10, col * 10 + 9


@pytest.fixture(scope="module")
def cartons(np_mod):
    rng = random.Random(1234)
    return [np_mod.generer_carton(rng) for _ in range(300)]


def test_carton_dimensions(cartons):  # NP-05
    for g in cartons:
        assert len(g) == 3 and all(len(l) == 9 for l in g)


def test_carton_cinq_numeros_par_ligne(cartons):  # NP-06
    for g in cartons:
        assert [sum(x is not None for x in l) for l in g] == [5, 5, 5]


def test_carton_quinze_numeros_uniques(cartons):  # NP-07
    for g in cartons:
        nums = [x for l in g for x in l if x is not None]
        assert len(nums) == 15 == len(set(nums))


def test_carton_au_moins_un_numero_par_colonne(cartons):  # NP-08
    for g in cartons:
        for c in range(9):
            assert 1 <= sum(g[l][c] is not None for l in range(3)) <= 3


def test_carton_plages_de_colonnes(cartons):  # NP-09
    for g in cartons:
        for c in range(9):
            lo, hi = _plage(c)
            for l in range(3):
                if g[l][c] is not None:
                    assert lo <= g[l][c] <= hi


def test_carton_colonnes_triees(cartons):  # NP-10
    for g in cartons:
        for c in range(9):
            vals = [g[l][c] for l in range(3) if g[l][c] is not None]
            assert vals == sorted(vals)


def test_carton_couvre_bornes_1_et_90(np_mod):  # NP-11 les extrêmes 1 et 90 sont atteignables
    rng = random.Random(0)
    vus = {x for _ in range(2000) for l in np_mod.generer_carton(rng) for x in l if x}
    assert vus == set(range(1, 91))


def test_carton_deterministe_avec_graine(np_mod):  # NP-12
    assert np_mod.generer_carton(random.Random(42)) == np_mod.generer_carton(random.Random(42))


# ---------- NP-13..NP-20 : CLI main() ----------

@pytest.fixture
def cli(np_mod, tmp_path, monkeypatch):
    """Exécute main() avec RACINE redirigée vers un dossier temporaire."""
    monkeypatch.setattr(np_mod, "RACINE", tmp_path)

    def _run(*args):
        monkeypatch.setattr("sys.argv", ["nouvelle_partie.py", *map(str, args)])
        np_mod.main()
    return _run


def test_cli_cree_arborescence(cli, tmp_path, capsys):  # NP-13
    cli("2026-11-20", "Salle des fêtes", "--cartons", 3)
    d = tmp_path / "2026-11-20_salle-des-fetes"
    assert (d / "partie.json").is_file()
    assert (d / "tirage" / "numeros.json").is_file()
    assert sorted(p.name for p in (d / "cartons").iterdir()) == [
        "carton_001.json", "carton_002.json", "carton_003.json"]
    assert "Créé" in capsys.readouterr().out


def test_cli_contenu_partie_json(cli, tmp_path):  # NP-14
    cli("2026-11-20", "Salle des fêtes", "--cartons", 2)
    p = json.loads((tmp_path / "2026-11-20_salle-des-fetes" / "partie.json").read_text())
    assert p == {"date": "2026-11-20", "lieu": "Salle des fêtes",
                 "cartons": ["001", "002"], "notes": ""}


def test_cli_contenu_carton_et_tirage(cli, tmp_path):  # NP-15
    cli("2026-11-20", "Orange", "--cartons", 1)
    d = tmp_path / "2026-11-20_orange"
    c = json.loads((d / "cartons" / "carton_001.json").read_text())
    assert c["id"] == "001" and c["joueur"] is None and len(c["grille"]) == 3
    assert json.loads((d / "tirage" / "numeros.json").read_text()) == []


def test_cli_sans_cartons(cli, tmp_path):  # NP-16
    cli("2026-11-20", "Orange")
    d = tmp_path / "2026-11-20_orange"
    assert list((d / "cartons").iterdir()) == []
    assert json.loads((d / "partie.json").read_text())["cartons"] == []


def test_cli_refuse_dossier_existant(cli, tmp_path):  # NP-17
    cli("2026-11-20", "Orange", "--cartons", 1)
    avant = (tmp_path / "2026-11-20_orange" / "cartons" / "carton_001.json").read_text()
    with pytest.raises(SystemExit) as e:
        cli("2026-11-20", "Orange", "--cartons", 5)
    assert "Existe déjà" in str(e.value.code)
    assert (tmp_path / "2026-11-20_orange" / "cartons" / "carton_001.json").read_text() == avant


@pytest.mark.parametrize("date_invalide", ["2026-13-01", "20-11-2026", "demain"])
def test_cli_refuse_date_invalide(cli, tmp_path, date_invalide):  # NP-18
    with pytest.raises(ValueError):
        cli(date_invalide, "Orange")
    assert list(tmp_path.iterdir()) == []


def test_cli_arguments_manquants(cli):  # NP-19
    with pytest.raises(SystemExit) as e:
        cli("2026-11-20")
    assert e.value.code == 2


def test_cli_script_executable(run_script, tmp_path):  # NP-20 lancement réel en sous-processus
    r = run_script("nouvelle_partie.py", "--help")
    assert r.returncode == 0 and "--cartons" in r.stdout


@pytest.mark.xfail(strict=True, reason="BUG-01 : un lieu sans caractère alphanumérique donne un dossier 'AAAA-MM-JJ_'")
def test_cli_refuse_lieu_vide(cli, tmp_path):  # NP-21
    with pytest.raises(SystemExit):
        cli("2026-11-20", "!!!")


@pytest.mark.xfail(strict=True, reason="BUG-02 : --cartons négatif accepté silencieusement")
def test_cli_refuse_cartons_negatif(cli):  # NP-22
    with pytest.raises(SystemExit):
        cli("2026-11-20", "Orange", "--cartons", -3)
