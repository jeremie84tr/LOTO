import Foundation
import CoreGraphics

/// Un nombre reconnu sur la photo, avant toute interprétation.
struct NumeroLu: Hashable, Sendable {
    var valeur: Int
    /// Confiance donnée par la reconnaissance (0…1).
    var confiance: Float
    /// Position dans l'image, normalisée (0…1), origine en haut à gauche.
    var cadre: CGRect
    /// Autres lectures possibles proposées par la reconnaissance (ex. 18 pour 78).
    var alternatives: [Int] = []
}

/// Une case du carton telle que lue sur la photo.
struct CaseLue: Hashable, Sendable {
    var valeur: Int?
    /// Raisons de douter de la lecture : la case doit être confirmée à la main.
    var doutes: [String] = []
    var alternatives: [Int] = []
    var confiance: Float = 0
    var cadre: CGRect?

    var aVerifier: Bool { !doutes.isEmpty }
}

/// Transforme les nombres lus sur une photo en grille 3 × 9, en signalant tout ce qui est douteux.
///
/// Un carton a une structure très contrainte, que l'on utilise pour repérer les erreurs de lecture :
/// 3 lignes de 5 numéros, chaque numéro dans la colonne de sa dizaine, aucun doublon.
/// (L'ordre dans une colonne n'est pas contrôlé : il n'est pas garanti sur tous les cartons.) La position de chaque numéro sur la
/// photo doit aussi correspondre à sa colonne : un 18 lu tout à droite du carton est sans doute un 78.
enum LectureCarton {
    /// En dessous, la lecture d'un numéro est à confirmer.
    static let confianceMinimale: Float = 0.9

    struct Resultat: Sendable {
        var cases: [[CaseLue]]
        /// Problèmes généraux (lignes incomplètes, nombres ignorés…).
        var remarques: [String]

        var numerosLus: Int { cases.joined().filter { $0.valeur != nil }.count }
        var casesAVerifier: Int { cases.joined().filter(\.aVerifier).count }
    }

    static func analyser(_ lus: [NumeroLu]) -> Resultat {
        var remarques: [String] = []
        var cases = Array(repeating: Array(repeating: CaseLue(), count: 9), count: 3)

        let candidats = lus.filter { (1...90).contains($0.valeur) && $0.cadre.height > 0 }
        guard !candidats.isEmpty else {
            return Resultat(cases: cases, remarques: ["Aucun numéro lu. Reprenez la photo de plus près, bien à plat et éclairée."])
        }

        // 1. Regroupement en lignes selon la hauteur.
        let hauteurType = mediane(candidats.map(\.cadre.height))
        var lignes: [[NumeroLu]] = []
        for n in candidats.sorted(by: { $0.cadre.midY < $1.cadre.midY }) {
            if let derniere = lignes.last,
               abs(n.cadre.midY - moyenne(derniere.map(\.cadre.midY))) < hauteurType * 0.6 {
                lignes[lignes.count - 1].append(n)
            } else {
                lignes.append([n])
            }
        }
        // Un nombre isolé sur sa ligne (numéro du carton, prix…) n'appartient pas à la grille.
        let isoles = lignes.filter { $0.count < 2 }.joined().map(\.valeur)
        lignes.removeAll { $0.count < 2 }
        if !isoles.isEmpty {
            remarques.append("Ignoré hors de la grille : \(isoles.map(String.init).joined(separator: ", ")).")
        }
        if lignes.count > 3 {
            // On garde les 3 lignes consécutives les plus remplies.
            func remplissage(_ i: Int) -> Int { lignes[i].count + lignes[i + 1].count + lignes[i + 2].count }
            let debut = Array(0...(lignes.count - 3)).max { remplissage($0) < remplissage($1) } ?? 0
            lignes = Array(lignes[debut..<debut + 3])
            remarques.append("Plus de 3 lignes de numéros sur la photo : vérifiez que c'est bien le bon carton (cadrez-en un seul).")
        }
        if lignes.count < 3 {
            remarques.append("Seulement \(lignes.count) ligne\(lignes.count > 1 ? "s" : "") lue\(lignes.count > 1 ? "s" : "") sur 3 : complétez à la main ou reprenez la photo.")
        }

        // 2. Correspondance position horizontale ↔ colonne (x ≈ a × colonne + b).
        let tous = lignes.joined().map { $0 }
        var modele = ajuster(tous.map { (Double(Carton.colonne(pour: $0.valeur)), Double($0.cadre.midX)) })
        if let m = modele {
            // Second ajustement sans les points aberrants (lectures probablement fausses).
            let fiables = tous.filter { abs(m.colonne(Double($0.cadre.midX)) - Double(Carton.colonne(pour: $0.valeur))) < 0.5 }
            if let m2 = ajuster(fiables.map { (Double(Carton.colonne(pour: $0.valeur)), Double($0.cadre.midX)) }) { modele = m2 }
        }

        // 3. Placement dans la grille.
        for (l, ligne) in lignes.enumerated() {
            for n in ligne.sorted(by: { $0.cadre.minX < $1.cadre.minX }) {
                let c = Carton.colonne(pour: n.valeur)
                var doutes: [String] = []
                if n.confiance < confianceMinimale { doutes.append("Lecture peu nette.") }
                let alternatives = n.alternatives.filter { $0 != n.valeur && (1...90).contains($0) }
                if !alternatives.isEmpty {
                    doutes.append("Peut aussi se lire \(alternatives.map(String.init).joined(separator: " ou ")).")
                }
                if let m = modele {
                    let attendue = Int(m.colonne(Double(n.cadre.midX)).rounded())
                    if attendue != c {
                        doutes.append("Sa place sur le carton correspond à la colonne \(libelleColonne(attendue)), pas à celle du \(n.valeur).")
                    }
                } else {
                    doutes.append("Position sur le carton impossible à contrôler.")
                }
                let nouvelle = CaseLue(valeur: n.valeur, doutes: doutes, alternatives: alternatives,
                                       confiance: n.confiance, cadre: n.cadre)
                if let existant = cases[l][c].valeur {
                    // Deux numéros de la même dizaine sur une ligne : impossible sur un vrai carton.
                    var garde = n.confiance > cases[l][c].confiance ? nouvelle : cases[l][c]
                    let ecarte = garde.valeur == n.valeur ? existant : n.valeur
                    garde.doutes.append("Le \(ecarte) a aussi été lu dans cette colonne et a été écarté.")
                    garde.alternatives = Array(Set(garde.alternatives + [ecarte])).sorted()
                    cases[l][c] = garde
                } else {
                    cases[l][c] = nouvelle
                }
            }
        }

        // 4. Doublons (ils restent bloquants tant qu'ils ne sont pas corrigés).
        let valeurs = cases.joined().compactMap(\.valeur)
        for l in 0..<3 {
            for c in 0..<9 {
                if let v = cases[l][c].valeur, valeurs.filter({ $0 == v }).count > 1 {
                    cases[l][c].doutes.append("Le \(v) a été lu deux fois.")
                }
            }
        }
        for l in 0..<3 {
            let nb = cases[l].filter { $0.valeur != nil }.count
            if nb != 5, l < lignes.count {
                remarques.append("Ligne \(l + 1) : \(nb) numéro\(nb > 1 ? "s" : "") lu\(nb > 1 ? "s" : "") au lieu de 5.")
            }
        }
        return Resultat(cases: cases, remarques: remarques)
    }

    struct Position: Hashable, Sendable { var ligne: Int; var colonne: Int }

    /// Ce qui empêche d'utiliser la grille (vide = utilisable) : il faut un carton possible.
    static func erreursBloquantes(_ grille: [[Int?]]) -> [String] {
        var erreurs: [String] = []
        for (l, ligne) in grille.enumerated() {
            let nb = ligne.compactMap { $0 }.count
            if nb != 5 { erreurs.append("Ligne \(l + 1) : \(nb) numéro\(nb > 1 ? "s" : "") au lieu de 5.") }
            for (c, v) in ligne.enumerated() {
                if let v, !(1...90).contains(v) || Carton.colonne(pour: v) != c {
                    erreurs.append("Le \(v) n'est pas dans sa colonne.")
                }
            }
        }
        let doublons = Dictionary(grouping: grille.joined().compactMap { $0 }, by: { $0 }).filter { $1.count > 1 }.keys.sorted()
        if !doublons.isEmpty {
            erreurs.append("En double : \(doublons.map(String.init).joined(separator: ", ")).")
        }
        return erreurs
    }

    static func libelleColonne(_ c: Int) -> String {
        switch c {
        case ..<1: return "1–9"
        case 8...: return "80–90"
        default: return "\(c * 10)–\(c * 10 + 9)"
        }
    }

    // MARK: - Outils

    private struct Droite {
        var a: Double, b: Double
        func colonne(_ x: Double) -> Double { (x - b) / a }
    }

    /// Moindres carrés x = a × colonne + b ; nil si on ne peut pas conclure.
    private static func ajuster(_ points: [(Double, Double)]) -> Droite? {
        guard Set(points.map(\.0)).count >= 2 else { return nil }
        let n = Double(points.count)
        let mc = points.map(\.0).reduce(0, +) / n, mx = points.map(\.1).reduce(0, +) / n
        let cov = points.map { ($0.0 - mc) * ($0.1 - mx) }.reduce(0, +)
        let varc = points.map { ($0.0 - mc) * ($0.0 - mc) }.reduce(0, +)
        guard varc > 0, cov / varc > 0.01 else { return nil }
        let a = cov / varc
        return Droite(a: a, b: mx - a * mc)
    }

    private static func mediane(_ v: [CGFloat]) -> CGFloat {
        let t = v.sorted()
        return t.isEmpty ? 0 : t[t.count / 2]
    }

    private static func moyenne(_ v: [CGFloat]) -> CGFloat {
        v.isEmpty ? 0 : v.reduce(0, +) / CGFloat(v.count)
    }
}
