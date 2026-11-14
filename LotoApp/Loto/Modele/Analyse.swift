import Foundation

/// Ce qu'il manque à un carton pour gagner la phase en cours.
struct Objectif: Identifiable, Hashable, Sendable {
    let carton: Carton
    let type: TypePhase
    /// Lignes visées (les plus avancées).
    let lignes: [Int]
    /// Numéros encore nécessaires, triés.
    let manquants: [Int]
    /// Numéros qui, à eux seuls, feraient gagner ce carton (quand il n'en manque qu'un).
    let gagnants: [Int]

    var reste: Int { manquants.count }
    var id: String { carton.id }
}

struct EtatPartie: Sendable {
    let phaseIndex: Int?
    let nomPhase: String?
    let type: TypePhase?
    /// Un objectif par carton, du plus proche au plus loin.
    let objectifs: [Objectif]
    /// Numéros restant dans le sac.
    let restantes: Int

    var gagnes: [Objectif] { objectifs.filter { $0.reste == 0 } }

    /// Numéros dont la sortie ferait gagner au moins un carton.
    var numerosGagnants: [Int] { Array(Set(objectifs.flatMap(\.gagnants))).sorted() }

    /// Numéros à surveiller : ceux qui manquent aux cartons à 2 numéros ou moins.
    var numerosSurveilles: Set<Int> { Set(objectifs.filter { $0.reste <= 2 }.flatMap(\.manquants)) }

    /// Probabilité qu'un numéro gagnant sorte dans les `k` prochains tirages.
    func proba(dansLes k: Int) -> Double {
        let w = numerosGagnants.count, r = restantes
        guard r > 0, w > 0 else { return 0 }
        var aucun = 1.0
        for i in 0..<min(k, r) {
            let perdants = r - w - i
            if perdants <= 0 { return 1 }
            aucun *= Double(perdants) / Double(r - i)
        }
        return 1 - aucun
    }

    /// Le numéro qui ferait avancer le plus de cartons, et combien.
    var numeroLePlusUtile: (numero: Int, cartons: Int)? {
        var compte: [Int: Int] = [:]
        for o in objectifs where o.reste > 0 {
            for n in o.manquants { compte[n, default: 0] += 1 }
        }
        return compte.max { ($0.value, -$0.key) < ($1.value, -$1.key) }.map { ($0.key, $0.value) }
    }
}

struct Conseil: Identifiable, Hashable, Sendable {
    enum Niveau: Int, Sendable { case gagne, unNumero, proche, info }
    let id: String
    let niveau: Niveau
    let texte: String
    let detail: String?
}

struct Simulation: Hashable, Sendable {
    /// Nombre de numéros à tirer (médiane) avant que l'un de nos cartons gagne la phase.
    let mediane: Int
    let moyenne: Double
    let dansLes5: Double
    let dansLes10: Double
}

enum Analyse {

    /// Lignes déjà utilisées par nos victoires précédentes du même type, sur ce carton.
    static func lignesExclues(partie: Partie, phaseIndex: Int, cartonID: String) -> Set<Int> {
        guard partie.phases.indices.contains(phaseIndex) else { return [] }
        let type = partie.phases[phaseIndex].type
        var exclues = Set<Int>()
        for p in partie.phases[..<phaseIndex] where p.type == type {
            if let g = p.gagnant, g.parNous, g.cartonID == cartonID { exclues.formUnion(g.lignes) }
        }
        return exclues
    }

    /// Ce qu'il manque à `carton` pour gagner une phase de type `type`.
    ///
    /// Une victoire ne se réclame qu'au tirage même qui complète la dernière ligne nécessaire :
    /// `dernier` est le dernier numéro tiré. Si le carton a déjà assez de lignes complètes mais
    /// qu'aucune ne vient d'être complétée par `dernier`, il est trop tard pour elles : il lui faut
    /// compléter une nouvelle ligne (les lignes complètes restent utilisables pour une double quine).
    /// Sans `dernier` (nil), toute ligne complète compte, comme avant.
    static func objectif(carton: Carton, type: TypePhase, tires: Set<Int>,
                         exclues: Set<Int> = [], dernier: Int? = nil) -> Objectif? {
        let k = type.lignesRequises
        let dispo = carton.grille.indices.filter { !exclues.contains($0) }
        guard dispo.count >= k else { return nil }
        let parLigne = dispo
            .map { i in (ligne: i, manquants: carton.numeros(ligne: i).filter { !tires.contains($0) }) }
            .sorted { ($0.manquants.count, $0.ligne) < ($1.manquants.count, $1.ligne) }
        let completes = parLigne.filter { $0.manquants.isEmpty }

        var choisies = Array(parLigne.prefix(k))
        var candidates = parLigne
        if completes.count >= k, let dernier {
            if let juste = completes.first(where: { carton.numeros(ligne: $0.ligne).contains(dernier) }) {
                // Victoire au tirage même : la ligne qui vient d'être complétée en fait partie.
                choisies = [juste] + completes.filter { $0.ligne != juste.ligne }.prefix(k - 1)
            } else {
                // Trop tard pour les lignes déjà complètes : il faut en compléter une nouvelle.
                let incompletes = parLigne.filter { !$0.manquants.isEmpty }
                guard let suivante = incompletes.first else { return nil }
                choisies = Array(completes.prefix(k - 1)) + [suivante]
                candidates = incompletes
            }
        }
        let manquants = choisies.flatMap(\.manquants).sorted()

        var gagnants: [Int] = []
        if manquants.count == 1 {
            // k-1 lignes déjà complètes : toute ligne à qui il manque un seul numéro fait gagner.
            gagnants = candidates.filter { $0.manquants.count == 1 }.map { $0.manquants[0] }.sorted()
        }
        return Objectif(carton: carton, type: type, lignes: choisies.map(\.ligne).sorted(),
                        manquants: manquants, gagnants: gagnants)
    }

    static func etat(partie: Partie, cartons: [Carton]) -> EtatPartie {
        let restantes = 90 - Set(partie.tirage).count
        guard let i = partie.indexPhaseCourante else {
            return EtatPartie(phaseIndex: nil, nomPhase: nil, type: nil, objectifs: [], restantes: restantes)
        }
        let type = partie.phases[i].type
        let tires = partie.tires
        let objectifs = cartons
            .compactMap { c in
                objectif(carton: c, type: type, tires: tires,
                         exclues: lignesExclues(partie: partie, phaseIndex: i, cartonID: c.id),
                         dernier: partie.tirage.last)
            }
            .sorted { a, b in
                if a.reste != b.reste { return a.reste < b.reste }
                return a.carton.id.localizedStandardCompare(b.carton.id) == .orderedAscending
            }
        return EtatPartie(phaseIndex: i, nomPhase: partie.nomPhase(i), type: type,
                          objectifs: objectifs, restantes: restantes)
    }

    // MARK: Simulation

    /// Tire au hasard le reste du sac `essais` fois et mesure quand l'un de nos cartons gagne
    /// la phase en cours (en supposant que personne d'autre ne la gagne avant).
    static func simulation(partie: Partie, cartons: [Carton], essais: Int = 3000) -> Simulation? {
        guard let i = partie.indexPhaseCourante else { return nil }
        let k = partie.phases[i].type.lignesRequises
        let tires = partie.tires
        let restants = (1...90).filter { !tires.contains($0) }
        guard !restants.isEmpty else { return nil }

        let preparations: [[[Int]]] = cartons.compactMap { c in
            let exclues = lignesExclues(partie: partie, phaseIndex: i, cartonID: c.id)
            let dispo = c.grille.indices.filter { !exclues.contains($0) }
            guard dispo.count >= k else { return nil }
            return dispo.map { c.numeros(ligne: $0).filter { !tires.contains($0) } }
        }
        guard !preparations.isEmpty else { return nil }

        var position = [Int](repeating: 0, count: 91)
        var resultats: [Int] = []
        resultats.reserveCapacity(essais)
        var sac = restants
        for _ in 0..<essais {
            sac.shuffle()
            for (j, n) in sac.enumerated() { position[n] = j + 1 }
            var meilleur = Int.max
            for lignes in preparations {
                var temps = lignes.map { l in l.reduce(0) { max($0, position[$1]) } }
                temps.sort()
                // Les lignes déjà complètes (temps 0) ne suffisent pas : il est trop tard pour elles,
                // la victoire viendra au premier tirage qui complète une nouvelle ligne.
                let t = temps[k - 1] > 0 ? temps[k - 1] : (temps.first { $0 > 0 } ?? 0)
                if t == 0 { continue }
                meilleur = min(meilleur, t)
            }
            if meilleur < Int.max { resultats.append(meilleur) }
        }
        guard !resultats.isEmpty else { return nil }
        resultats.sort()
        let n = Double(resultats.count)
        return Simulation(
            mediane: resultats[resultats.count / 2],
            moyenne: Double(resultats.reduce(0, +)) / n,
            dansLes5: Double(resultats.filter { $0 <= 5 }.count) / n,
            dansLes10: Double(resultats.filter { $0 <= 10 }.count) / n
        )
    }

    // MARK: Conseils

    static func conseils(etat: EtatPartie, simulation: Simulation? = nil,
                         moyenneHistorique: Double? = nil, limiteProches: Int = 5) -> [Conseil] {
        guard let type = etat.type, let nom = etat.nomPhase else {
            return [Conseil(id: "fin", niveau: .info, texte: "Partie terminée.", detail: nil)]
        }
        if etat.objectifs.isEmpty {
            return [Conseil(id: "vide", niveau: .info,
                            texte: "Aucun carton ne peut gagner \(type.avecArticle).",
                            detail: "Ajoutez vos cartons à la soirée.")]
        }
        var r: [Conseil] = []

        for o in etat.objectifs where o.reste == 0 {
            r.append(Conseil(id: "g-\(o.carton.id)", niveau: .gagne,
                             texte: "\(nom.uppercased()) sur le \(o.carton.libelle) ! Criez-le !",
                             detail: "Ligne\(o.lignes.count > 1 ? "s" : "") \(o.lignes.map { String($0 + 1) }.joined(separator: " et "))"))
        }
        for o in etat.objectifs where o.reste == 1 {
            r.append(Conseil(id: "1-\(o.carton.id)", niveau: .unNumero,
                             texte: "Plus qu'un numéro avant \(type.avecArticle) : le \(liste(o.gagnants, "ou le")) !",
                             detail: o.carton.titre))
        }
        let proches = etat.objectifs.filter { (2...3).contains($0.reste) }.prefix(limiteProches)
        for o in proches {
            r.append(Conseil(id: "p-\(o.carton.id)", niveau: .proche,
                             texte: "Plus que \(o.reste) numéros, \(liste(o.manquants, "et")), avant \(type.avecArticle) !",
                             detail: o.carton.titre))
        }
        if r.isEmpty, let o = etat.objectifs.first {
            r.append(Conseil(id: "p-\(o.carton.id)", niveau: .proche,
                             texte: "Le plus avancé : \(o.carton.libelle), il manque \(o.reste) numéros pour \(type.avecArticle).",
                             detail: liste(o.manquants, "et")))
        }

        let w = etat.numerosGagnants.count
        if w > 0, etat.gagnes.isEmpty {
            r.append(Conseil(id: "proba", niveau: .info,
                             texte: "\(w) numéro\(w > 1 ? "s" : "") gagnant\(w > 1 ? "s" : "") sur \(etat.restantes) dans le sac : \(pourcent(etat.proba(dansLes: 1))) de chances au prochain tirage, \(pourcent(etat.proba(dansLes: 5))) dans les 5 prochains.",
                             detail: etat.numerosGagnants.map(String.init).joined(separator: " · ")))
        }
        if let u = etat.numeroLePlusUtile, u.cartons >= 2, etat.gagnes.isEmpty {
            r.append(Conseil(id: "utile", niveau: .info,
                             texte: "Le \(u.numero) ferait avancer \(u.cartons) de vos cartons.", detail: nil))
        }
        if let s = simulation, etat.gagnes.isEmpty {
            r.append(Conseil(id: "simu", niveau: .info,
                             texte: "Si personne ne gagne avant, vous auriez \(type.avecArticle) dans environ \(s.mediane) numéros (\(pourcent(s.dansLes10)) de chances dans les 10 prochains).",
                             detail: "Estimation par simulation de 3 000 tirages"))
        }
        if let m = moyenneHistorique {
            r.append(Conseil(id: "histo", niveau: .info,
                             texte: "D'habitude, \(nom == type.nom ? type.avecArticle : "« \(nom) »") tombe après \(Int(m.rounded())) numéros.",
                             detail: "Moyenne de vos parties enregistrées"))
        }
        return r
    }

    static func pourcent(_ x: Double) -> String {
        let p = x * 100
        if p > 0 && p < 1 { return "moins de 1 %" }
        return "\(Int(p.rounded())) %"
    }

    /// [34] → « 34 » ; [34, 57] → « 34 et 57 » ; [12, 34, 57] → « 12, 34 et 57 ».
    static func liste(_ nombres: [Int], _ conjonction: String) -> String {
        let s = nombres.map(String.init)
        guard s.count > 1 else { return s.first ?? "" }
        return s.dropLast().joined(separator: ", ") + " \(conjonction) " + s.last!
    }
}
