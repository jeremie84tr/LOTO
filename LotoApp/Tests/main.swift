// Tests de la logique (modèle, conseils, statistiques), sans Xcode :
//   ./Tests/lancer.sh
import Foundation

var echecs = 0
func verifier(_ condition: Bool, _ message: String, ligne: Int = #line) {
    if condition { print("  ok   \(message)") } else { echecs += 1; print("  ÉCHEC (l.\(ligne)) \(message)") }
}

// Carton 001 d'Orange.
let grille: [[Int?]] = [[7, nil, 28, 30, nil, 56, 65, nil, nil],
                        [6, 11, nil, nil, 45, nil, 68, nil, 90],
                        [nil, nil, nil, 35, 44, 54, nil, 78, 81]]
let carton = Carton(id: "001", planche: "A", grille: grille)

print("Saisie de carton")
let saisie = Carton.grille(depuis: Carton.extraireNumeros("7 28 30 56 65\n6, 11, 45, 68, 90\n35 44 54 78 81"))
verifier(saisie.erreurs.isEmpty, "15 numéros valides placés sans erreur")
verifier(saisie.grille == grille, "les numéros tombent dans les bonnes colonnes (90 → colonne 80)")
verifier(!Carton.grille(depuis: [1, 5, 20, 30, 40, 11, 12, 13, 14, 15, 60, 61, 62, 63, 64]).erreurs.isEmpty,
         "deux numéros de la même dizaine sur une ligne sont refusés")

print("Lecture d'un carton sur photo")
/// Simule la photo du carton 001 : colonne c ↔ x = 0.05 + c × 0.1, ligne l ↔ y = 0.3 + l × 0.15.
func lus(_ g: [[Int?]], confiance: Float = 0.99) -> [NumeroLu] {
    g.enumerated().flatMap { l, ligne in
        ligne.enumerated().compactMap { c, v in
            v.map { NumeroLu(valeur: $0, confiance: confiance,
                             cadre: CGRect(x: 0.03 + Double(c) * 0.1, y: 0.28 + Double(l) * 0.15, width: 0.04, height: 0.04)) }
        }
    }
}
let lecture = LectureCarton.analyser(lus(grille) + [NumeroLu(valeur: 9, confiance: 1, cadre: CGRect(x: 0.8, y: 0.05, width: 0.04, height: 0.04))])
verifier(lecture.cases.map { $0.map(\.valeur) } == grille && lecture.casesAVerifier == 0, "lecture nette : grille retrouvée, rien à vérifier")
verifier(lecture.remarques.contains { $0.contains("Ignoré") && $0.contains("9") }, "un nombre isolé hors grille est ignoré")
var mal = lus(grille)
mal[mal.firstIndex { $0.valeur == 78 }!].valeur = 18 // 78 lu « 18 », à droite du carton
let lectureFausse = LectureCarton.analyser(mal)
verifier(lectureFausse.cases[2][1].valeur == 18 && lectureFausse.cases[2][1].aVerifier,
         "un 18 lu à la place du 78 est signalé (position incohérente)")
verifier(LectureCarton.analyser(lus(grille, confiance: 0.5)).casesAVerifier == 15, "lecture peu nette : tout est à vérifier")
var incomplet = lus(grille); incomplet.removeAll { $0.valeur == 45 }
let lectureIncomplete = LectureCarton.analyser(incomplet)
verifier(lectureIncomplete.remarques.contains("Ligne 2 : 4 numéros lus au lieu de 5."), "numéro manquant signalé")
verifier(!LectureCarton.erreursBloquantes(lectureIncomplete.cases.map { $0.map(\.valeur) }).isEmpty, "grille incomplète refusée")
verifier(LectureCarton.erreursBloquantes(grille).isEmpty, "carton valide accepté (même si 7 est au-dessus de 6)")
var double = grille; double[2][0] = 7
verifier(LectureCarton.erreursBloquantes(double).contains("En double : 7."), "numéro en double refusé")

print("Planche de plusieurs cartons")
/// Place un carton sur une planche : origine (x0, y0), case de 0,04 × 0,05, inclinaison éventuelle.
func surPlanche(_ g: [[Int?]], x0: Double, y0: Double, pente: Double = 0) -> [NumeroLu] {
    g.enumerated().flatMap { l, ligne in
        ligne.enumerated().compactMap { c, v in
            v.map { n -> NumeroLu in
                let x = x0 + Double(c) * 0.04
                return NumeroLu(valeur: n, confiance: 1,
                                cadre: CGRect(x: x, y: y0 + Double(l) * 0.05 + pente * (x - x0), width: 0.02, height: 0.02))
            }
        }
    }
}
let autre: [[Int?]] = [[nil, 16, nil, nil, 41, 50, nil, 76, 86], [nil, 10, 26, nil, nil, 51, 66, 73, nil], [8, nil, 22, 32, nil, nil, 62, nil, 82]]
// 2 colonnes de 2 cartons ; 0,2 d'écart vertical entre cartons (0,05 entre lignes).
let planche = surPlanche(grille, x0: 0.05, y0: 0.1) + surPlanche(autre, x0: 0.05, y0: 0.32)
    + surPlanche(autre, x0: 0.55, y0: 0.12, pente: 0.05) + surPlanche(grille, x0: 0.55, y0: 0.34, pente: 0.05)
let groupes = LectureCarton.regrouper(planche)
verifier(groupes.count == 4 && groupes.allSatisfy { $0.count == 15 }, "4 cartons de 15 numéros retrouvés sur la planche")
verifier(groupes.map { LectureCarton.analyser($0).cases.map { $0.map(\.valeur) } }.filter { $0 == grille }.count == 2,
         "chaque groupe redonne la bonne grille")
var troues = surPlanche(grille, x0: 0.05, y0: 0.1)
troues.removeAll { [6, 45, 68, 90].contains($0.valeur) } // ligne 2 : seul le 11 est lu
let geo = LectureCarton.analyser(troues, garderLignesIsolees: true).geometrie
verifier(geo != nil, "une ligne avec un seul numéro lu compte encore (géométrie retrouvée)")
let incline = LectureCarton.analyser(surPlanche(grille, x0: 0.05, y0: 0.1, pente: 0.05)).geometrie!
verifier(abs(incline.cellule(0, 8).midY - (0.11 + 0.05 * 0.32)) < 0.003, "la pente des lignes est prise en compte")
verifier(LectureCarton.sensDeLecture(planche) > 0, "planche à l'endroit : les numéros croissent vers la droite")
let renversee = planche.map { n -> NumeroLu in var m = n; m.cadre.origin.x = 1 - n.cadre.maxX; return m }
verifier(LectureCarton.sensDeLecture(renversee) < 0, "planche retournée : sens négatif")

print("Double lecture case par case")
let base = LectureCarton.analyser(lus(grille, confiance: 0.5))
var parCase = grille.map { $0.map { $0.map { [$0] } ?? [] } }
parCase[1][0] = [9]       // 6 relu « 9 »
parCase[2][7] = []        // 78 pas retrouvé
let fusion = LectureCarton.fusionner(base, parCase: parCase)
verifier(!fusion.cases[0][0].aVerifier, "lu pareil deux fois : sûr, même si la lecture était peu nette")
verifier(fusion.cases[1][0].valeur == 6 && fusion.cases[1][0].aVerifier && fusion.cases[1][0].alternatives.contains(9),
         "6 relu « 9 » : à vérifier, avec 9 en suggestion")
verifier(fusion.cases[2][7].aVerifier, "numéro non retrouvé en relisant : à vérifier")
var manque = lus(grille); manque.removeAll { $0.valeur == 30 }
let completee = LectureCarton.fusionner(LectureCarton.analyser(manque), parCase: grille.map { $0.map { $0.map { [$0] } ?? [] } })
verifier(completee.cases[0][3].valeur == 30 && completee.cases[0][3].aVerifier && completee.numerosLus == 15,
         "numéro vu seulement case par case : ajouté, mais à vérifier")

print("Aucun carton reconnu : grille estimée")
func nombre(_ v: Int, _ x: Double, _ y: Double, alternatives: [Int] = []) -> NumeroLu {
    NumeroLu(valeur: v, confiance: 0.99, cadre: CGRect(x: x, y: y, width: 0.04, height: 0.04), alternatives: alternatives)
}
let bruit = [nombre(12, 0.5, 0.05), nombre(45, 0.1, 0.9), nombre(3, 0.92, 0.75), nombre(27, 0.33, 0.62)]
verifier(LectureCarton.estimerGrille(bruit).numerosLus == 0 && LectureCarton.estimerGrille(bruit).geometrie == nil,
         "des nombres épars sans structure : grille vide, aucun numéro proposé")
let estimee = LectureCarton.estimerGrille(lus(grille) + bruit)
verifier(estimee.cases.map { $0.map(\.valeur) } == grille, "carton + nombres parasites : seuls les numéros du carton sont gardés")
verifier(estimee.remarques.contains { $0.hasPrefix("Ignoré hors du carton") }, "les nombres hors du carton sont signalés")
verifier(estimee.geometrie.map { abs($0.a - 0.1) < 0.01 && abs($0.pas - 0.15) < 0.01 } == true, "grille théorique retrouvée")
var deplace = lus(grille)
deplace[deplace.firstIndex { $0.valeur == 78 }!].valeur = 18 // 78 lu « 18 », sans autre lecture
let sansAutre = LectureCarton.estimerGrille(deplace)
verifier(sansAutre.cases[2][7].valeur == nil && sansAutre.cases[2][7].aVerifier && sansAutre.cases[2][7].alternatives == [78]
         && sansAutre.cases[2][1].valeur == nil, "un 18 à la place du 78 n'est pas gardé : case à vérifier, 78 suggéré")
deplace[deplace.firstIndex { $0.valeur == 18 }!].alternatives = [78]
verifier(LectureCarton.estimerGrille(deplace).cases[2][7].valeur == 78 && LectureCarton.estimerGrille(deplace).cases[2][7].aVerifier,
         "si Vision propose aussi 78, c'est lui qui est retenu, à vérifier")

print("Objectifs")
let tires: Set<Int> = [7, 28, 30, 56, 6, 11, 45]
let q = Analyse.objectif(carton: carton, type: .quine, tires: tires)!
verifier(q.reste == 1 && q.manquants == [65] && q.gagnants == [65], "quine : il ne manque que le 65")
let dq = Analyse.objectif(carton: carton, type: .doubleQuine, tires: tires)!
verifier(dq.reste == 3 && dq.manquants == [65, 68, 90], "double quine : 65, 68, 90")
let cp = Analyse.objectif(carton: carton, type: .cartonPlein, tires: tires)!
verifier(cp.reste == 8, "carton plein : 8 manquants")
let quineFaite = Analyse.objectif(carton: carton, type: .quine, tires: tires.union([65]))!
verifier(quineFaite.reste == 0 && quineFaite.lignes == [0], "quine détectée sur la ligne 1")
let deuxGagnants = Analyse.objectif(carton: carton, type: .quine, tires: [7, 28, 30, 56, 6, 11, 45, 68])!
verifier(deuxGagnants.gagnants == [65, 90], "deux lignes à 1 numéro : le 65 ou le 90")

print("Enchaînement 2 quines → double quine → carton plein")
var partie = Partie(numero: 1, deroulement: [.quine, .quine, .doubleQuine, .cartonPlein])
partie.tirage = [7, 28, 30, 56, 65]
verifier(partie.nomPhase(0) == "Quine 1" && partie.nomPhase(1) == "Quine 2" && partie.nomPhase(2) == "Double quine",
         "noms des phases numérotés")
var etat = Analyse.etat(partie: partie, cartons: [carton])
verifier(etat.gagnes.count == 1, "quine 1 gagnée par le carton 001")
partie.phases[0].gagneeApres = 5
partie.phases[0].gagnant = Gagnant(parNous: true, cartonID: "001", lignes: [0])
etat = Analyse.etat(partie: partie, cartons: [carton])
verifier(etat.nomPhase == "Quine 2" && etat.gagnes.isEmpty, "quine 2 : la ligne déjà gagnée ne compte plus")
partie.tirage += [6, 11, 45, 68]
etat = Analyse.etat(partie: partie, cartons: [carton])
verifier(etat.objectifs.first?.gagnants == [90], "quine 2 : il manque le 90 (ligne 2)")
let conseils = Analyse.conseils(etat: etat)
verifier(conseils.contains { $0.niveau == .unNumero && $0.texte.contains("le 90") }, "conseil « Plus qu'un numéro… le 90 »")
verifier(conseils.first?.detail == "Carton 001 · planche A", "le conseil indique la planche")
partie.phases[1].gagneeApres = 9
partie.phases[1].gagnant = Gagnant(parNous: false, cartonID: nil, lignes: [])
etat = Analyse.etat(partie: partie, cartons: [carton])
verifier(etat.type == .doubleQuine && etat.objectifs.first?.manquants == [90], "double quine : il manque le 90")

print("Conseil à 2 numéros")
var p2 = Partie(numero: 2, deroulement: [.quine])
p2.tirage = [7, 28, 30]
let c2 = Analyse.conseils(etat: Analyse.etat(partie: p2, cartons: [carton]))
verifier(c2.contains { $0.texte == "Plus que 2 numéros, 56 et 65, avant la quine !" }, "« Plus que 2 numéros, 56 et 65, avant la quine ! »")

print("Victoire à réclamer au tirage même")
// Lignes du carton 001 : [7 28 30 56 65] · [6 11 45 68 90] · [35 44 54 78 81]
func etatApres(_ tirage: [Int], _ deroulement: [TypePhase] = [.quine]) -> EtatPartie {
    var p = Partie(numero: 9, deroulement: deroulement)
    p.tirage = tirage
    return Analyse.etat(partie: p, cartons: [carton])
}
let ligne1 = [7, 28, 30, 56, 65], ligne2 = [6, 11, 45, 68, 90], ligne3 = [35, 44, 54, 78, 81]
verifier(etatApres([65, 7, 28, 30, 56]).gagnes.count == 1,
         "quine proposée au tirage qui complète la ligne, quel que soit l'ordre des numéros")
let rate = etatApres(ligne1 + [12])
verifier(rate.gagnes.isEmpty, "quine plus proposée au tirage suivant (trop tard)")
verifier(rate.objectifs.first?.reste == 5 && rate.objectifs.first?.lignes == [1],
         "après une quine ratée, l'objectif devient la ligne suivante")
verifier(!Analyse.conseils(etat: rate).contains { $0.niveau == .gagne }, "aucun conseil « Criez-le ! » après le tirage")
let presque = etatApres(ligne1 + [12] + ligne2.dropLast())
verifier(presque.objectifs.first?.reste == 1 && presque.objectifs.first?.gagnants == [90],
         "quine ratée sur la ligne 1 : le 90 (ligne 2) fait gagner")
let rattrape = etatApres(ligne1 + [12] + ligne2)
verifier(rattrape.gagnes.first?.lignes == [1], "quine sur une nouvelle ligne proposée à son tirage")
verifier(etatApres(ligne1 + ligne2 + [12]).gagnes.isEmpty, "deux lignes ratées : rien à réclamer")
verifier(etatApres(ligne1 + ligne2, [.doubleQuine]).gagnes.first?.lignes == [0, 1], "double quine proposée à son tirage")
let dqRatee = etatApres(ligne1 + ligne2 + [12], [.doubleQuine])
verifier(dqRatee.gagnes.isEmpty && dqRatee.objectifs.first?.lignes == [0, 2] && dqRatee.objectifs.first?.reste == 5,
         "double quine ratée : une ligne déjà complète + une nouvelle ligne à compléter")
verifier(etatApres(ligne1 + ligne2 + [12] + ligne3, [.doubleQuine]).gagnes.first?.lignes == [0, 2],
         "double quine réclamable quand une nouvelle ligne se complète")
verifier(Analyse.objectif(carton: carton, type: .quine, tires: Set(ligne1 + [12]))?.reste == 0,
         "sans dernier numéro connu, une ligne complète compte toujours")
var pRatee = Partie(numero: 10, deroulement: [.quine])
pRatee.tirage = ligne1 + [12]
let simuRatee = Analyse.simulation(partie: pRatee, cartons: [carton], essais: 300)!
verifier(simuRatee.mediane >= 1, "simulation après quine ratée : il faut encore des numéros (\(simuRatee.mediane))")
pRatee.tirage = ligne1 + ligne2 + ligne3 + [12]
verifier(Analyse.etat(partie: pRatee, cartons: [carton]).objectifs.isEmpty
         && Analyse.simulation(partie: pRatee, cartons: [carton], essais: 50) == nil,
         "carton complet sans victoire réclamée : il ne peut plus gagner la quine")

print("Probabilités et simulation")
verifier(abs(etat.proba(dansLes: 1) - 1.0 / 81) < 1e-9, "1 gagnant sur 81 restants")
let simu = Analyse.simulation(partie: partie, cartons: [carton], essais: 500)!
verifier(simu.mediane >= 1 && simu.mediane <= 81, "simulation : médiane cohérente (\(simu.mediane))")

print("Historique d'Orange")
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
let soirees = try! dec.decode([Soiree].self, from: Data(contentsOf: url))
verifier(soirees.count == 1 && soirees[0].parties.count == 10 && soirees[0].cartons.count == 12, "1 soirée, 10 parties, 12 cartons")
verifier(soirees[0].parties.allSatisfy(\.estTerminee), "parties importées considérées terminées")
let stats = Statistiques(parties: PartieJouee.depuis(soirees))
verifier(stats.nbNumeros == 500, "500 numéros tirés")
verifier(stats.numeros.first { $0.numero == 80 }?.sorties == 10, "le 80 est sorti dans les 10 parties")
verifier(stats.cartons.first?.titre == "Carton 009 · planche B" && stats.cartons.first?.casesCochees == 97,
         "meilleur carton : 009 avec 97 cases")
let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
let relu = try! dec.decode([Soiree].self, from: enc.encode(soirees))
verifier(relu == soirees, "aller-retour JSON sans perte")

print("Données d'exemple embarquées")
let exemples = try! dec.decode([Soiree].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
verifier(exemples.count == 3 && !exemples.contains { $0.lieu.contains("Orange") }, "3 soirées fictives, aucune référence à Orange")
verifier(exemples.allSatisfy { $0.cartons.allSatisfy { $0.serie == nil && $0.grille.allSatisfy { $0.compactMap { $0 }.count == 5 } } },
         "cartons valides, sans numéro de série")
let enCours = exemples[0].parties.last!
let etatDemo = Analyse.etat(partie: enCours, cartons: exemples[0].cartons)
verifier(etatDemo.nomPhase == "Quine 2" && etatDemo.gagnes.isEmpty && etatDemo.objectifs.first?.reste == 1,
         "partie d'exemple en cours : un carton à 1 numéro de la quine 2")

print(echecs == 0 ? "\nTous les tests passent." : "\n\(echecs) échec(s).")
exit(echecs == 0 ? 0 : 1)
