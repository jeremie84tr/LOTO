# Fiche App Store Connect : prête à copier-coller

Chaque bloc correspond à un champ de App Store Connect. Les limites de caractères sont vérifiées.

> **À lire avant de soumettre**
> 1. **Nom de l'app.** « Loto » est une marque déposée de la Française des Jeux, et le nom est sans doute déjà pris sur l'App Store. Je propose **Carton Plein : suivi de loto**. Le nom affiché sous l'icône reste « Loto » (`CFBundleDisplayName`, modifiable dans Xcode).
> 2. **Site d'aide.** Les URL ci-dessous supposent que GitHub Pages est activé sur le dossier `docs/` de la branche `main` (GitHub › Settings › Pages › *Deploy from a branch* › `main` / `/docs`). Le dépôt doit être public, sinon il faut un compte GitHub payant.
> 3. **Identifiant.** Le bundle ID est `fr.loto.suivi`. Changez-le dans Xcode (*Signing & Capabilities*) s'il ne vous convient pas, **avant** de créer la fiche.

---

## Informations sur l'app

**Nom** (30 caractères max)
```
Carton Plein : suivi de loto
```

**Sous-titre** (30 max)
```
Quines, conseils, statistiques
```

**Catégorie principale :** Divertissement
**Catégorie secondaire :** Utilitaires

**Droits d'auteur**
```
2026 Jérémie Lohyer
```

---

## Version 1.0

**Texte promotionnel** (170 max, modifiable sans nouvelle version)
```
Plus qu'un numéro avant la quine ? L'app vous le dit. Saisissez le tirage, suivez tous vos cartons en direct et ne laissez plus jamais passer une quine.
```

**Description** (4 000 max)
```
Vous jouez au loto avec plusieurs cartons ? Carton Plein les surveille tous à votre place.

Cochez les numéros au fur et à mesure du tirage : l'app vérifie chaque carton, vous dit lesquels sont sur le point de gagner et vous prévient dès que vous avez une quine. Fini les numéros oubliés et les quines qu'on n'a pas criées à temps.

CONSEILS EN DIRECT
• « Plus qu'un numéro avant la quine : le 39 ou le 72 ! »
• « Plus que 2 numéros, 7 et 40, avant la quine ! »
• Le carton et la planche concernés sont toujours indiqués.
• Les numéros gagnants sont entourés sur le tableau.
• Vos chances qu'un numéro gagnant sorte au prochain tirage ou dans les 5 suivants.
• Une estimation du nombre de numéros avant votre quine ou votre carton plein.

QUINE ! VOUS ÊTES PRÉVENU
Dès qu'un de vos cartons gagne, un grand bandeau s'affiche, le téléphone vibre et, si vous le souhaitez, une voix vous l'annonce.

TOUTES LES FORMULES DE JEU
Quine, double quine, carton plein : choisissez l'ordre de chaque partie, comme dans votre salle. Deux quines puis une double quine puis un carton plein ? Aucun problème. L'ordre peut même être modifié en cours de partie.

VOS CARTONS ET VOS PLANCHES
Tapez simplement les 15 numéros de chaque carton : ils sont rangés automatiquement dans la bonne colonne et les erreurs de saisie sont signalées. Regroupez vos cartons par planche et réutilisez-les d'une soirée à l'autre.

SAISIE RAPIDE
Touchez le numéro annoncé sur le tableau de 1 à 90, ou tapez-le au clavier. Une erreur ? Annulez le dernier numéro en un geste.

STATISTIQUES
• Après combien de numéros tombent la quine, la double quine et le carton plein.
• Les numéros les plus et les moins sortis.
• La répartition des tirages par colonne.
• Le bilan de chacun de vos cartons et de vos victoires.

SUR IPHONE, IPAD ET MAC
Une seule app pour tous vos appareils, adaptée à chaque écran.

RESPECT DE VOTRE VIE PRIVÉE
Aucun compte, aucune publicité, aucune donnée collectée. Tout reste sur votre appareil. Vous pouvez exporter vos données à tout moment.

Remarque : Carton Plein est un outil de suivi pour les lotos traditionnels (associations, comités des fêtes, écoles…). L'app ne propose aucun jeu d'argent, aucune mise, et ne permet pas de jouer en ligne. Chaque tirage est dû au hasard : les statistiques décrivent les parties passées et ne prédisent pas les numéros à venir.
```

**Mots-clés** (100 max, séparés par des virgules sans espace)
```
loto,quine,double quine,carton plein,bingo,cartons,planche,tirage,boules,kermesse,association,salle
```

**URL d'assistance**
```
https://jeremie84tr.github.io/LOTO/
```

**URL marketing** (facultatif)
```
https://jeremie84tr.github.io/LOTO/
```

**Nouveautés de cette version**
```
Première version : suivi des cartons en direct, conseils, détection des quines, phases dans l'ordre de votre choix et statistiques.
```

---

## Confidentialité de l'app

**URL de la politique de confidentialité**
```
https://jeremie84tr.github.io/LOTO/confidentialite.html
```

**Collecte de données :** répondre **« Non, nous ne collectons pas de données à partir de cette app »**.
L'app n'a ni serveur, ni analytique, ni publicité, ni SDK tiers. Les données restent sur l'appareil.

---

## Classification par âge (questionnaire)

Répondre **Aucun / Non** partout. En particulier :
- Jeux d'argent simulés : **Aucun**. L'app ne simule aucun jeu d'argent : elle aide à suivre un loto réel joué en salle, sans mise ni gain dans l'app.
- Concours : **Non**.
- Jeux d'argent réels : **Non**.
- Contenu généré par les utilisateurs, accès web libre, messagerie : **Non**.

Résultat attendu : **4+**.

---

## Informations pour la vérification (App Review)

**Connexion requise :** non (décocher « Connexion requise »)

**Remarques**
```
Carton Plein aide les joueurs de loto traditionnel (loto associatif joué en salle avec des cartons papier) à suivre leurs cartons pendant le tirage. Aucun jeu d'argent, aucune mise, aucun achat : l'app ne fait que comparer les numéros annoncés aux cartons saisis par l'utilisateur.

Pour tester rapidement : des données d'exemple fictives sont chargées au premier lancement.
1. Ouvrez la soirée « Salle des fêtes », puis « Partie 6 » (en cours).
2. Les conseils indiquent qu'un carton n'a plus besoin que d'un numéro pour la quine.
3. Touchez un des numéros entourés en orange sur le tableau : le bandeau « QUINE 2 ! » apparaît.
4. Le bouton « Quine 2 gagnée… » enregistre la phase et passe à la suivante.
5. « Statistiques globales » dans la barre latérale présente les graphiques.

Aucune donnée n'est collectée ni envoyée sur Internet.
```

**Coordonnées :** vos nom, téléphone et e-mail (non publiés).

---

## Visuels

| Emplacement App Store Connect | Fichiers | Taille |
|---|---|---|
| iPhone 6,9 pouces | `captures/iphone-6.9/*.png` | 1320 × 2868 |
| iPad 13 pouces | `captures/ipad-13/*.png` | 2064 × 2752 |
| Icône | fournie par Xcode depuis `Assets.xcassets` (1024 × 1024, sans transparence) | — |

Les dossiers `captures/brutes/` contiennent les mêmes écrans sans habillage, aux dimensions exactes de l'appareil : vous pouvez les envoyer tels quels si vous préférez.
`promo/` contient l'icône 1024 × 1024 et une bannière 1920 × 1080 pour un site ou les réseaux sociaux.

Pour régénérer : `AppStore/outils/captures.sh` puis `AppStore/outils/composer.sh` (depuis `LotoApp/`, Xcode requis).

---

## Avant d'envoyer le build

1. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` (une seule fois).
2. Dans Xcode : *Signing & Capabilities* › choisir votre équipe.
3. *Product › Archive* (destination « Any iOS Device »), puis *Distribute App › App Store Connect*.
5. Version Mac : l'app fonctionne sur Mac, mais aucune capture Mac n'est fournie. Pour la publier sur le Mac App Store, il faudra des captures 2880 × 1800 (ou 1440 × 900). Sinon, publiez seulement la version iPhone/iPad.
4. Chiffrement : l'app n'utilise aucun chiffrement propre. Répondre « Aucun des algorithmes mentionnés » (ou ajouter `ITSAppUsesNonExemptEncryption = NO`).
