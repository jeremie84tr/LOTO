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

print(echecs == 0 ? "\nTous les tests passent." : "\n\(echecs) échec(s).")
exit(echecs == 0 ? 0 : 1)
