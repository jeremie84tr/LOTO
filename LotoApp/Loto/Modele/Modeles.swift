import Foundation

// MARK: - Phases

/// Ce que l'on joue : quine (1 ligne), double quine (2 lignes), carton plein (3 lignes).
enum TypePhase: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case quine, doubleQuine, cartonPlein

    var id: String { rawValue }

    var nom: String {
        switch self {
        case .quine: return "Quine"
        case .doubleQuine: return "Double quine"
        case .cartonPlein: return "Carton plein"
        }
    }

    var avecArticle: String {
        switch self {
        case .quine: return "la quine"
        case .doubleQuine: return "la double quine"
        case .cartonPlein: return "le carton plein"
        }
    }

    /// Nombre de lignes complètes nécessaires sur un même carton.
    var lignesRequises: Int {
        switch self {
        case .quine: return 1
        case .doubleQuine: return 2
        case .cartonPlein: return 3
        }
    }

    var icone: String {
        switch self {
        case .quine: return "1.square"
        case .doubleQuine: return "2.square"
        case .cartonPlein: return "square.grid.3x3.fill"
        }
    }
}

/// Modèles d'enchaînement des phases. L'ordre n'est jamais figé : chaque partie a le sien.
struct Deroulement: Identifiable, Hashable {
    let nom: String
    let phases: [TypePhase]
    var id: String { nom }

    static let modeles: [Deroulement] = [
        Deroulement(nom: "Classique", phases: [.quine, .doubleQuine, .cartonPlein]),
        Deroulement(nom: "Deux quines", phases: [.quine, .quine, .doubleQuine, .cartonPlein]),
        Deroulement(nom: "Quine puis carton plein", phases: [.quine, .cartonPlein]),
        Deroulement(nom: "Carton plein seul", phases: [.cartonPlein]),
    ]

    static func description(_ phases: [TypePhase]) -> String {
        phases.isEmpty ? "Aucune phase" : phases.map(\.nom).joined(separator: " → ")
    }
}

// MARK: - Carton

/// Carton français : 3 lignes × 9 colonnes, 5 numéros par ligne, `nil` = case vide.
struct Carton: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var serie: String?
    var planche: String?
    var joueur: String?
    var grille: [[Int?]]

    static let grilleVide: [[Int?]] = Array(repeating: Array(repeating: nil, count: 9), count: 3)

    init(id: String, serie: String? = nil, planche: String? = nil, joueur: String? = nil,
         grille: [[Int?]] = Carton.grilleVide) {
        self.id = id
        self.serie = serie
        self.planche = planche
        self.joueur = joueur
        self.grille = grille
    }

    var numeros: [Int] { grille.flatMap { $0.compactMap { $0 } } }

    func numeros(ligne i: Int) -> [Int] {
        grille.indices.contains(i) ? grille[i].compactMap { $0 } : []
    }

    func case_(_ ligne: Int, _ colonne: Int) -> Int? {
        guard grille.indices.contains(ligne), grille[ligne].indices.contains(colonne) else { return nil }
        return grille[ligne][colonne]
    }

    /// « carton 009 (planche B) », pour insérer dans une phrase.
    var libelle: String {
        if let p = planche, !p.isEmpty { return "carton \(id) (planche \(p))" }
        return "carton \(id)"
    }

    /// « Carton 009 · planche B », pour un titre.
    var titre: String {
        if let p = planche, !p.isEmpty { return "Carton \(id) · planche \(p)" }
        return "Carton \(id)"
    }

    /// Colonne d'un numéro : 1-9 → 0, 10-19 → 1, …, 80-90 → 8.
    static func colonne(pour n: Int) -> Int { n <= 9 ? 0 : min(n / 10, 8) }

    static func extraireNumeros(_ texte: String) -> [Int] {
        texte.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }

    /// Place 15 numéros donnés dans l'ordre de lecture (5 par ligne) dans leurs colonnes.
    static func grille(depuis numeros: [Int]) -> (grille: [[Int?]], erreurs: [String]) {
        var erreurs: [String] = []
        var g = grilleVide
        if numeros.count != 15 {
            erreurs.append("Il faut 15 numéros (\(numeros.count) saisi\(numeros.count > 1 ? "s" : "")).")
        }
        for (i, n) in numeros.prefix(15).enumerated() {
            guard (1...90).contains(n) else {
                erreurs.append("\(n) n'est pas entre 1 et 90.")
                continue
            }
            let l = i / 5, c = colonne(pour: n)
            if let existant = g[l][c] {
                erreurs.append("Ligne \(l + 1) : \(existant) et \(n) tombent dans la même colonne.")
                continue
            }
            g[l][c] = n
        }
        let doublons = Dictionary(grouping: numeros, by: { $0 }).filter { $1.count > 1 }.keys.sorted()
        if !doublons.isEmpty {
            erreurs.append("En double : \(doublons.map(String.init).joined(separator: ", ")).")
        }
        return (g, erreurs)
    }

    /// Les 15 numéros dans l'ordre de lecture, une ligne par ligne de texte.
    var texteSaisie: String {
        grille.map { $0.compactMap { $0 }.map(String.init).joined(separator: " ") }.joined(separator: "\n")
    }
}

// MARK: - Partie

struct Gagnant: Codable, Hashable, Sendable {
    var parNous: Bool
    var cartonID: String?
    /// Lignes du carton utilisées pour gagner (pour ne pas les recompter à la quine suivante).
    var lignes: [Int]
}

struct Phase: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var type: TypePhase
    var lot: String
    /// Nombre de numéros tirés au moment où la phase a été gagnée.
    var gagneeApres: Int?
    var gagnant: Gagnant?

    init(type: TypePhase, lot: String = "") {
        self.id = UUID()
        self.type = type
        self.lot = lot
    }

    var estTerminee: Bool { gagneeApres != nil }
}

struct Partie: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var numero: Int
    var phases: [Phase]
    var tirage: [Int]
    var notes: String
    /// Partie reprise d'un historique, sans le détail des phases.
    var importee: Bool

    init(numero: Int, deroulement: [TypePhase]) {
        self.id = UUID()
        self.numero = numero
        self.phases = deroulement.map { Phase(type: $0) }
        self.tirage = []
        self.notes = ""
        self.importee = false
    }

    var tires: Set<Int> { Set(tirage) }
    var deroulement: [TypePhase] { phases.map(\.type) }

    var indexPhaseCourante: Int? {
        importee ? nil : phases.firstIndex { !$0.estTerminee }
    }

    var estTerminee: Bool { importee || indexPhaseCourante == nil }

    /// « Quine 2 » quand plusieurs phases du même type, sinon « Quine ».
    func nomPhase(_ index: Int) -> String {
        guard phases.indices.contains(index) else { return "" }
        let type = phases[index].type
        let total = phases.filter { $0.type == type }.count
        guard total > 1 else { return type.nom }
        let rang = phases[...index].filter { $0.type == type }.count
        return "\(type.nom) \(rang)"
    }

    /// Change l'enchaînement en conservant les résultats des phases qui ne bougent pas.
    mutating func changerDeroulement(_ nouveau: [TypePhase]) {
        phases = nouveau.enumerated().map { i, type in
            if phases.indices.contains(i), phases[i].type == type { return phases[i] }
            return Phase(type: type)
        }
    }
}

// MARK: - Soirée

struct Planche: Identifiable {
    let nom: String
    let cartons: [Carton]
    var id: String { nom }
}

/// Une soirée de loto : un lieu, une date, des cartons, plusieurs parties.
struct Soiree: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var date: Date
    var lieu: String
    var cartons: [Carton]
    var parties: [Partie]
    var deroulementParDefaut: [TypePhase]
    var notes: String

    init(lieu: String, date: Date, cartons: [Carton] = [], deroulement: [TypePhase]) {
        self.id = UUID()
        self.date = date
        self.lieu = lieu
        self.cartons = cartons
        self.parties = []
        self.deroulementParDefaut = deroulement
        self.notes = ""
    }

    var titre: String { "\(lieu) – \(date.formatted(date: .abbreviated, time: .omitted))" }

    var planches: [Planche] {
        let groupes = Dictionary(grouping: cartons) { c -> String in
            if let p = c.planche, !p.isEmpty { return "Planche \(p)" }
            return "Sans planche"
        }
        return groupes.keys.sorted().map { cle in
            Planche(nom: cle, cartons: groupes[cle]!.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending })
        }
    }

    var prochainNumeroDePartie: Int { (parties.map(\.numero).max() ?? 0) + 1 }

    var prochainIDCarton: String {
        let max = cartons.compactMap { Int($0.id) }.max() ?? 0
        return String(format: "%03d", max + 1)
    }
}
