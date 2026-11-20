#!/usr/bin/env python3
"""Visuels de mise en avant App Store (en-tête, résultats de recherche).

Même style que composer.swift : dégradé rouge de l'icône, boules décoratives,
iPhone avec cadre. Pas de texte : l'App Store affiche lui-même le nom et l'icône.

Usage (depuis LotoApp/) : python3 AppStore/outils/visuels_promo.py
Résultat : AppStore/promo/entete-3840x1646.png, AppStore/promo/recherche-3840x2560.png
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

RACINE = Path(__file__).resolve().parent.parent
BRUTES = RACINE / "captures" / "brutes" / "iphone"
PROMO = RACINE / "promo"

HAUT, BAS = (219, 56, 61), (128, 18, 33)   # 0.86/0.22/0.24 → 0.50/0.07/0.13
BORDURE, R_ECRAN, R_BOITIER = 0.035, 62.0 / 440, (62.0 + 15.4) / 440


def fond(w, h, boules):
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(HAUT, BAS)))
    img = col.resize((w, h))
    calque = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(calque)
    for x, y, r in boules:
        r *= w
        d.ellipse((x * w - r, y * h - r, x * w + r, y * h + r), fill=(255, 255, 255, 26))
    img.paste(calque, (0, 0), calque)
    return img


def iphone(capture, largeur_ecran):
    """iPhone complet (boîtier + écran), en RGBA."""
    ecran = Image.open(capture).convert("RGB")
    ew = round(largeur_ecran)
    eh = round(ew * ecran.height / ecran.width)
    b = round(BORDURE * ew)
    W, H = ew + 2 * b, eh + 2 * b
    tel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(tel)
    d.rounded_rectangle((0, 0, W - 1, H - 1), radius=R_BOITIER * ew, fill=(31, 31, 31, 255))
    e = b * 0.06
    d.rounded_rectangle((e, e, W - 1 - e, H - 1 - e), radius=R_BOITIER * ew - e,
                        outline=(107, 107, 107, 255), width=max(1, round(b * 0.12)))
    masque = Image.new("L", (ew, eh), 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, ew - 1, eh - 1), radius=R_ECRAN * ew, fill=255)
    tel.paste(ecran.resize((ew, eh), Image.LANCZOS), (b, b), masque)
    return tel


def poser(img, tel, cx, cy):
    """Colle le téléphone centré en (cx, cy), avec une ombre portée."""
    w, _ = img.size
    x, y = round(cx - tel.width / 2), round(cy - tel.height / 2)
    flou = round(w * 0.012)
    ombre = Image.new("RGBA", img.size, (0, 0, 0, 0))
    a = tel.getchannel("A").point(lambda v: v * 115 // 255)
    noir = Image.new("RGBA", tel.size, (0, 0, 0, 255))
    noir.putalpha(a)
    ombre.paste(noir, (x, y + round(w * 0.006)), noir)
    ombre = ombre.filter(ImageFilter.GaussianBlur(flou))
    img.paste(ombre, (0, 0), ombre)
    img.paste(tel, (x, y), tel)


def composer(w, h, sortie, telephones, boules):
    """telephones : liste de (capture, hauteur relative à h, cx relatif, cy relatif)."""
    img = fond(w, h, boules)
    for nom, hr, cx, cy in telephones:
        brut = Image.open(BRUTES / f"{nom}.png")
        # largeur d'écran pour que le boîtier entier fasse hr × h de haut
        ew = hr * h / (brut.height / brut.width + 2 * BORDURE)
        poser(img, iphone(BRUTES / f"{nom}.png", ew), cx * w, cy * h)
    img.convert("RGB").save(sortie, optimize=True)
    print(f"  {sortie.relative_to(RACINE)} ({w} × {h})")


PROMO.mkdir(exist_ok=True)
BOULES = [(0.06, 0.18, 0.035), (0.95, 0.12, 0.022), (0.90, 0.80, 0.03), (0.12, 0.85, 0.018), (0.80, 0.30, 0.012)]

# En-tête 3840 × 1646 : cinq iPhone en éventail, le plus important au centre.
composer(3840, 1646, PROMO / "entete-3840x1646.png", [
    ("04-cartons", 0.70, 0.17, 0.55),
    ("06-statistiques", 0.70, 0.83, 0.55),
    ("01-partie", 0.80, 0.33, 0.53),
    ("05-phases", 0.80, 0.67, 0.53),
    ("02-victoire", 0.90, 0.50, 0.50),
], BOULES)

# Résultats de recherche 3840 × 2560 (= 1920 × 1280 en ×2) : trois iPhone.
composer(3840, 2560, PROMO / "recherche-3840x2560.png", [
    ("01-partie", 0.74, 0.25, 0.53),
    ("06-statistiques", 0.74, 0.75, 0.53),
    ("02-victoire", 0.86, 0.50, 0.50),
], BOULES)
