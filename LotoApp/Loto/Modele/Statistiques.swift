import Foundation

struct PartieJouee: Sendable {
    let partie: Partie
    let cartons: [Carton]
    let date: Date
    let lieu: String

    static func depuis(_ soirees: [Soiree]) -> [PartieJouee] {
        soirees.flatMap { s in
            s.parties.map { PartieJouee(partie: $0, cartons: s.cartons, date: s.date, lieu: s.lieu) }
        }
    }
}

struct StatPhase: Identifiable, Sendable {
    let id: String          // « Quine 1 », « Double quine »…
    let ordre: Int
    let valeurs: [Int]      // nombre de numéros tirés quand la phase est tombée
    let gagneesParNous: Int
    var moyenne: Double { Double(valeurs.reduce(0, +)) / Double(max(valeurs.count, 1)) }
    var minimum: Int { valeurs.min() ?? 0 }
    var maximum: Int { valeurs.max() ?? 0 }
}

struct StatCarton: Identifiable, Sendable {
    let id: String
    let titre: String
    let casesCochees: Int
    let parties: Int
    let victoires: Int
    var moyenne: Double { Double(casesCochees) / Double(max(parties, 1)) }
}

struct StatNumero: Identifiable, Sendable {
    let numero: Int
    let sorties: Int
    let retard: Int     // parties depuis la dernière sortie
    var id: Int { numero }
}

struct StatDizaine: Identifiable, Sendable {
    let libelle: String
    let observe: Double     // part des numéros tirés
    let attendu: Double     // part théorique (taille de la colonne / 90)
    var id: String { libelle }
}

struct Statistiques: Sendable {
    let parties: [PartieJouee]
    let numeros: [StatNumero]
    let phases: [StatPhase]
    let cartons: [StatCarton]
    let dizaines: [StatDizaine]
    let nbNumeros: Int
    let pairs: Int

    init(parties brutes: [PartieJouee]) {
        let parties = brutes
            .filter { !$0.partie.tirage.isEmpty }
            .sorted { ($0.date, $0.partie.numero) < ($1.date, $1.partie.numero) }
        self.parties = parties

        let tous = parties.flatMap(\.partie.tirage)
        nbNumeros = tous.count
        pairs = tous.filter { $0 % 2 == 0 }.count

        var sorties = [Int](repeating: 0, count: 91)
        var derniere = [Int](repeating: -1, count: 91)
        for (i, p) in parties.enumerated() {
            for n in Set(p.partie.tirage) where (1...90).contains(n) {
                sorties[n] += 1
                derniere[n] = i
            }
        }
        numeros = (1...90).map { n in
            StatNumero(numero: n, sorties: sorties[n],
                       retard: derniere[n] < 0 ? parties.count : parties.count - 1 - derniere[n])
        }

        let bornes = [(1, 9)] + (1...7).map { ($0 * 10, $0 * 10 + 9) } + [(80, 90)]
        dizaines = bornes.map { lo, hi in
            let compte = tous.filter { (lo...hi).contains($0) }.count
            return StatDizaine(libelle: lo == 1 ? "1-9" : "\(lo)-\(hi)",
                               observe: tous.isEmpty ? 0 : Double(compte) / Double(tous.count),
                               attendu: Double(hi - lo + 1) / 90)
        }

        var valeurs: [String: (ordre: Int, v: [Int], nous: Int)] = [:]
        for p in parties {
            for (i, phase) in p.partie.phases.enumerated() {
                guard let n = phase.gagneeApres else { continue }
                let cle = p.partie.nomPhase(i)
                var e = valeurs[cle] ?? (ordre: i, v: [], nous: 0)
                e.v.append(n)
                e.ordre = min(e.ordre, i)
                if phase.gagnant?.parNous == true { e.nous += 1 }
                valeurs[cle] = e
            }
        }
        phases = valeurs
            .map { StatPhase(id: $0.key, ordre: $0.value.ordre, valeurs: $0.value.v, gagneesParNous: $0.value.nous) }
            .sorted { ($0.ordre, $0.id) < ($1.ordre, $1.id) }

        var parCarton: [String: (titre: String, cases: Int, parties: Int, victoires: Int)] = [:]
        for p in parties {
            let tires = p.partie.tires
            for c in p.cartons {
                let cle = c.serie ?? "\(p.lieu)-\(c.id)"
                var e = parCarton[cle] ?? (titre: c.titre, cases: 0, parties: 0, victoires: 0)
                e.cases += c.numeros.filter { tires.contains($0) }.count
                e.parties += 1
                e.victoires += p.partie.phases.filter { $0.gagnant?.parNous == true && $0.gagnant?.cartonID == c.id }.count
                parCarton[cle] = e
            }
        }
        cartons = parCarton
            .map { StatCarton(id: $0.key, titre: $0.value.titre, casesCochees: $0.value.cases,
                              parties: $0.value.parties, victoires: $0.value.victoires) }
            .sorted { $0.moyenne > $1.moyenne }
    }

    var nbParties: Int { parties.count }
    var moyenneParPartie: Double { nbParties == 0 ? 0 : Double(nbNumeros) / Double(nbParties) }
    var moyenneDesNumeros: Double { nbNumeros == 0 ? 0 : Double(parties.flatMap(\.partie.tirage).reduce(0, +)) / Double(nbNumeros) }
    var victoiresParNous: Int { phases.reduce(0) { $0 + $1.gagneesParNous } }

    var plusSortis: [StatNumero] { Array(numeros.sorted { ($0.sorties, -$0.numero) > ($1.sorties, -$1.numero) }.prefix(10)) }
    var moinsSortis: [StatNumero] { Array(numeros.sorted { ($0.sorties, $0.numero) < ($1.sorties, $1.numero) }.prefix(10)) }
    var plusEnRetard: [StatNumero] { Array(numeros.sorted { ($0.retard, -$0.numero) > ($1.retard, -$1.numero) }.prefix(10)) }

    func moyenne(phase nom: String) -> Double? {
        phases.first { $0.id == nom }.map(\.moyenne)
    }
}
