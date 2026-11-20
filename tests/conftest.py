"""Fixtures communes aux tests de l'application LOTO."""
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import pytest

RACINE = Path(__file__).resolve().parent.parent
PARTIES = RACINE / "parties"


def _charger_module(nom):
    spec = importlib.util.spec_from_file_location(nom, RACINE / f"{nom}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture(scope="session")
def np_mod():
    """Module nouvelle_partie.py importé sans exécuter main()."""
    return _charger_module("nouvelle_partie")


@pytest.fixture
def run_script():
    """Lance un script de la racine comme en ligne de commande."""
    def _run(script, *args, cwd=None):
        return subprocess.run(
            [sys.executable, str(RACINE / script), *map(str, args)],
            capture_output=True, text=True, cwd=cwd or RACINE,
        )
    return _run


@pytest.fixture
def partie_tmp(tmp_path):
    """Crée une petite partie isolée (2 cartons connus, tirage vide)."""
    def _creer(tirage=(), cartons=None):
        d = tmp_path / "2026-01-01_test"
        (d / "cartons").mkdir(parents=True)
        (d / "tirage").mkdir()
        cartons = cartons or {
            "001": [[1, 10, 20, 30, 40, None, None, None, None],
                    [None, None, None, 33, None, 50, 60, 70, 80],
                    [2, None, 21, None, 41, None, 61, None, 90]],
            "002": [[3, None, 22, None, 42, None, 62, None, 81],
                    [None, 11, None, 31, None, 51, None, 71, 82],
                    [4, 12, 23, 32, 43, None, None, None, None]],
        }
        for cid, grille in cartons.items():
            (d / "cartons" / f"carton_{cid}.json").write_text(
                json.dumps({"id": cid, "joueur": None, "grille": grille}))
        (d / "partie.json").write_text(json.dumps(
            {"date": "2026-01-01", "lieu": "Test", "cartons": list(cartons), "notes": ""}))
        (d / "tirage" / "numeros.json").write_text(json.dumps(list(tirage)))
        return d
    return _creer
