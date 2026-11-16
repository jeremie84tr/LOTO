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
        /// Lignes de numéros trouvées (plus de 3 : la photo contient plusieurs cartons).
        var lignesTrouvees = 0
        /// Le plus de numéros trouvés sur une même ligne (plus de 5 : cartons côte à côte).
        var maxParLigne = 0
        /// Où se trouvent les 27 cases sur l'image, déduit des numéros lus (nil si impossible).
        var geometrie: Geometrie?

        var numerosLus: Int { cases.joined().filter { $0.valeur != nil }.count }
        var casesAVerifier: Int { cases.joined().filter(\.aVerifier).count }
        /// Qualité de la lecture, de 0 à 30 : un point par numéro lu, un de plus s'il est sans doute.
        var score: Int { numerosLus * 2 - casesAVerifier }
        /// Ce que l'on a lu ressemble à un carton et un seul.
        var ressembleAUnCarton: Bool { lignesTrouvees == 3 && maxParLigne <= 6 && numerosLus >= 10 }
    }

    /// Position des cases sur l'image (coordonnées normalisées, origine en haut à gauche) :
    /// le centre de la colonne c est en x = a × c + b, celui de la ligne l en y = lignes[l].
    struct Geometrie: Hashable, Sendable {
        var a: CGFloat
        var b: CGFloat
        var lignes: [CGFloat]
        /// Écart entre deux lignes.
        var pas: CGFloat
        /// Inclinaison des lignes (photo de biais, papier courbé) : y monte de `pente` par unité de x,
        /// à partir de `xReference`, où se mesurent les `lignes`.
        var pente: CGFloat = 0
        var xReference: CGFloat = 0

        /// Zone d'une case, un peu élargie pour ne pas couper un numéro décalé.
        func cellule(_ l: Int, _ c: Int, marge: CGFloat = 0.15) -> CGRect {
            let largeur = a * (1 + 2 * marge), hauteur = pas * 0.95
            let x = a * CGFloat(c) + b
            let y = lignes[l] + pente * (x - xReference)
            return CGRect(x: x - largeur / 2, y: y - hauteur / 2, width: largeur, height: hauteur)
        }

        /// Le carton entier, avec une petite marge autour de la grille.
        var cadreCarton: CGRect {
            let decalage = abs(pente) * a * 4.5 // les extrémités d'une ligne inclinée
            let haut = lignes[0] - pas * 0.8 - decalage, bas = lignes[2] + pas * 0.8 + decalage
            return CGRect(x: b - a * 0.8, y: haut, width: a * 9.6, height: bas - haut)
        }
    }

    /// `garderLignesIsolees` : pour un groupe déjà reconnu comme un carton (`regrouper`), une ligne
    /// dont un seul numéro a été lu reste une ligne du carton ; sinon, un nombre seul sur sa ligne
    /// (numéro du carton, prix…) est écarté.
    static func analyser(_ lus: [NumeroLu], garderLignesIsolees: Bool = false) -> Resultat {
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
        let minimum = garderLignesIsolees ? 1 : 2
        let isoles = lignes.filter { $0.count < minimum }.joined().map(\.valeur)
        lignes.removeAll { $0.count < minimum }
        if !isoles.isEmpty {
            remarques.append("Ignoré hors de la grille : \(isoles.map(String.init).joined(separator: ", ")).")
        }
        let lignesTrouvees = lignes.count
        let maxParLigne = lignes.map(\.count).max() ?? 0
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
        var geometrie: Geometrie?
        if let m = modele, lignes.count == 3 {
            // Pente commune, mesurée sur les lignes d'au moins 2 numéros.
            var num: CGFloat = 0, den: CGFloat = 0
            for ligne in lignes where ligne.count >= 2 {
                let mx = moyenne(ligne.map(\.cadre.midX)), my = moyenne(ligne.map(\.cadre.midY))
                for n in ligne {
                    num += (n.cadre.midX - mx) * (n.cadre.midY - my)
                    den += (n.cadre.midX - mx) * (n.cadre.midX - mx)
                }
            }
            let pente = den > 0 ? num / den : 0
            let xRef = moyenne(lignes.joined().map(\.cadre.midX))
            // Hauteur de chaque ligne ramenée à x = xRef.
            let ys = lignes.map { ligne in
                moyenne(ligne.map(\.cadre.midY)) - pente * (moyenne(ligne.map(\.cadre.midX)) - xRef)
            }
            geometrie = Geometrie(a: CGFloat(m.a), b: CGFloat(m.b), lignes: ys, pas: (ys[2] - ys[0]) / 2,
                                  pente: pente, xReference: xRef)
        }
        return Resultat(cases: cases, remarques: remarques, lignesTrouvees: lignesTrouvees, maxParLigne: maxParLigne,
                        geometrie: geometrie)
    }

    // MARK: - Plusieurs cartons sur une même image

    /// Répartit les numéros lus sur une planche entre les cartons, d'après la structure d'un carton :
    /// dans un carton, la position horizontale d'un numéro vaut a × colonne + b, avec le même « b »
    /// pour tous ses numéros ; les cartons d'une même colonne de la planche se suivent par groupes
    /// de 3 lignes, séparés par un écart plus grand qu'entre deux lignes d'un même carton.
    static func regrouper(_ lus: [NumeroLu]) -> [[NumeroLu]] {
        let candidats = lus.filter { (1...90).contains($0.valeur) && $0.cadre.height > 0 }
        guard candidats.count >= 2 else { return candidats.isEmpty ? [] : [candidats] }
        let hauteurType = mediane(candidats.map(\.cadre.height))

        // 1. Largeur d'une case : entre deux numéros voisins d'une même ligne, écart / colonnes d'écart.
        var estimations: [CGFloat] = []
        for ligne in enLignes(candidats, tolerance: hauteurType * 0.6) {
            let triee = ligne.sorted { $0.cadre.midX < $1.cadre.midX }
            for (g, d) in zip(triee, triee.dropFirst()) {
                let dc = Carton.colonne(pour: d.valeur) - Carton.colonne(pour: g.valeur)
                if dc > 0 { estimations.append((d.cadre.midX - g.cadre.midX) / CGFloat(dc)) }
            }
        }
        guard !estimations.isEmpty else { return [candidats] }
        let a = mediane(estimations)

        // 2. Colonnes de cartons : même « b » = x − a × colonne.
        let parB = candidats.sorted { origine($0, a) < origine($1, a) }
        var colonnesDeCartons: [[NumeroLu]] = [[parB[0]]]
        for (prec, n) in zip(parB, parB.dropFirst()) {
            if origine(n, a) - origine(prec, a) > a * 2 { colonnesDeCartons.append([]) }
            colonnesDeCartons[colonnesDeCartons.count - 1].append(n)
        }

        // 3. Dans chaque colonne de cartons, découpage des lignes en cartons de 3 lignes.
        var cartons: [[NumeroLu]] = []
        for groupe in colonnesDeCartons {
            let lignes = enLignes(groupe, tolerance: hauteurType * 0.6)
            guard lignes.count > 1 else { cartons.append(groupe); continue }
            let ys = lignes.map { moyenne($0.map(\.cadre.midY)) }
            let ecarts = zip(ys, ys.dropFirst()).map { $1 - $0 }
            // Seuil entre « même carton » et « carton suivant » : le plus grand saut entre écarts triés.
            let tries = ecarts.sorted()
            var seuil = CGFloat.infinity
            if let i = (0..<(tries.count - 1)).max(by: { tries[$0 + 1] / tries[$0] < tries[$1 + 1] / tries[$1] }),
               tries[i + 1] / tries[i] > 1.15 {
                seuil = (tries[i] + tries[i + 1]) / 2
            }
            var blocs: [[[NumeroLu]]] = [[lignes[0]]]
            for (i, ligne) in lignes.dropFirst().enumerated() {
                if ecarts[i] > seuil || blocs[blocs.count - 1].count == 3 { blocs.append([]) }
                blocs[blocs.count - 1].append(ligne)
            }
            cartons += blocs.map { Array($0.joined()) }
        }
        return cartons
    }

    /// Fusionne la lecture d'ensemble avec une seconde lecture faite case par case.
    ///
    /// Une case n'est sûre que si les deux lectures concordent. Un numéro vu par une seule des deux,
    /// ou lu différemment, est à vérifier.
    static func fusionner(_ resultat: Resultat, parCase: [[[Int]]]) -> Resultat {
        var r = resultat
        for l in 0..<3 {
            for c in 0..<9 {
                let relus = l < parCase.count && c < parCase[l].count ? parCase[l][c] : []
                // Dans une case, on retient le nombre qui appartient à sa colonne.
                let relu = relus.first { Carton.colonne(pour: $0) == c }
                let autres = relus.filter { $0 != relu && Carton.colonne(pour: $0) == c }
                var k = r.cases[l][c]
                switch (k.valeur, relu) {
                case let (v?, w?) where v == w:
                    // Deux lectures indépendantes concordent : le manque de netteté n'est plus un doute.
                    k.doutes.removeAll { $0 == "Lecture peu nette." }
                case let (v?, w?):
                    k.doutes.append("Relu « \(w) » en lisant la case seule, au lieu de \(v).")
                    k.alternatives = Array(Set(k.alternatives + [w])).sorted()
                case (_?, nil):
                    k.doutes.append("Pas retrouvé en lisant la case seule.")
                case let (nil, w?):
                    k.valeur = w
                    k.doutes = ["Vu seulement en lisant la case seule."]
                    k.alternatives = autres
                    k.cadre = r.geometrie?.cellule(l, c, marge: 0)
                case (nil, nil):
                    break
                }
                r.cases[l][c] = k
            }
        }
        recalculer(&r)
        return r
    }

    /// Les doublons et le compte des lignes, recalculés sur la grille complétée.
    private static func recalculer(_ r: inout Resultat) {
        let valeurs = r.cases.joined().compactMap(\.valeur)
        for l in 0..<3 {
            for c in 0..<9 {
                if let v = r.cases[l][c].valeur, valeurs.filter({ $0 == v }).count > 1,
                   !r.cases[l][c].doutes.contains("Le \(v) a été lu deux fois.") {
                    r.cases[l][c].doutes.append("Le \(v) a été lu deux fois.")
                }
            }
        }
        r.remarques.removeAll { $0.hasPrefix("Ligne ") }
        for l in 0..<3 {
            let nb = r.cases[l].filter { $0.valeur != nil }.count
            if nb != 5 { r.remarques.append("Ligne \(l + 1) : \(nb) numéro\(nb > 1 ? "s" : "") lu\(nb > 1 ? "s" : "") au lieu de 5.") }
        }
        r.maxParLigne = max(r.maxParLigne, r.cases.map { $0.filter { $0.valeur != nil }.count }.max() ?? 0)
    }

    // MARK: - Aucun carton reconnu

    /// Estime la grille d'un carton à partir de numéros épars, quand aucun carton n'a été reconnu.
    ///
    /// Seuls les numéros placés comme sur un vrai carton sont gardés :
    /// 1. on cherche la règle x = a × colonne + b que respectent le plus de numéros (chaque paire
    ///    de numéros de colonnes différentes en propose une ; on garde celle qui en explique le plus) ;
    /// 2. on cherche de même 3 lignes régulièrement espacées ;
    /// 3. les deux règles sont réajustées sur les numéros retenus (correction du tableau estimé),
    ///    puis chaque numéro est confronté à sa place théorique :
    ///    - à sa place : il est gardé (avec les doutes habituels) ;
    ///    - pas à sa place, mais une autre lecture proposée par Vision y correspond : celle-ci est
    ///      proposée, à vérifier ;
    ///    - pas à sa place du tout : il n'est pas mis dans la grille, la case est seulement signalée ;
    ///    - hors du carton estimé : il est ignoré.
    /// Si trop peu de numéros s'accordent, la grille reste vide : mieux vaut une saisie à la main
    /// que des numéros sans rapport avec le carton.
    static func estimerGrille(_ lus: [NumeroLu]) -> Resultat {
        let vide = Array(repeating: Array(repeating: CaseLue(), count: 9), count: 3)
        let introuvable = Resultat(cases: vide, remarques: [
            "Aucun carton reconnu : les numéros lus ne sont pas disposés comme sur un carton. Reprenez la photo (à plat, bien cadrée) ou saisissez le carton à la main.",
        ])
        let candidats = lus.filter { (1...90).contains($0.valeur) && $0.cadre.height > 0 }
        guard candidats.count >= 4 else { return introuvable }
        let hauteurType = mediane(candidats.map(\.cadre.height))
        func col(_ n: NumeroLu) -> Double { Double(Carton.colonne(pour: n.valeur)) }
        func x(_ n: NumeroLu) -> Double { Double(n.cadre.midX) }

        // 1. Règle horizontale qui explique le plus de numéros.
        func accordes(_ d: Droite, tolerance: Double) -> [NumeroLu] {
            candidats.filter { abs(d.colonne(x($0)) - col($0)) < tolerance }
        }
        var meilleure: (droite: Droite, nb: Int)?
        for (i, p) in candidats.enumerated() {
            for q in candidats[(i + 1)...] where col(q) != col(p) {
                let a = (x(q) - x(p)) / (col(q) - col(p))
                // Une case est plus large qu'un chiffre n'est haut, et les 9 colonnes tiennent dans l'image.
                guard a > Double(hauteurType) * 0.9, a * 8 < 1.05 else { continue }
                let d = Droite(a: a, b: x(p) - a * col(p))
                let nb = accordes(d, tolerance: 0.3).count
                if nb > meilleure?.nb ?? 0 { meilleure = (d, nb) }
            }
        }
        guard var droite = meilleure?.droite else { return introuvable }
        for _ in 0..<2 { // correction : réajustement sur les numéros qui s'accordent
            let points = accordes(droite, tolerance: 0.35).map { (col($0), x($0)) }
            if let d = ajuster(points), d.a * 8 < 1.05 { droite = d }
        }
        let alignesEnX = accordes(droite, tolerance: 0.35)
        guard alignesEnX.count >= 4 else { return introuvable }

        // 2. Inclinaison, mesurée sur les lignes des numéros bien placés en x.
        let rangees = enLignes(alignesEnX, tolerance: hauteurType * 0.6)
        var num: CGFloat = 0, den: CGFloat = 0
        for r in rangees where r.count >= 2 {
            let mx = moyenne(r.map(\.cadre.midX)), my = moyenne(r.map(\.cadre.midY))
            for n in r {
                num += (n.cadre.midX - mx) * (n.cadre.midY - my)
                den += (n.cadre.midX - mx) * (n.cadre.midX - mx)
            }
        }
        let pente = den > 0 ? num / den : 0
        let xRef = moyenne(alignesEnX.map(\.cadre.midX))
        func yc(_ n: NumeroLu) -> CGFloat { n.cadre.midY - pente * (n.cadre.midX - xRef) }

        // 3. Trois lignes régulièrement espacées qui expliquent le plus de numéros.
        func ligneDe(_ n: NumeroLu, _ y0: CGFloat, _ pas: CGFloat) -> Int? {
            let l = (yc(n) - y0) / pas, li = Int(l.rounded())
            return (0...2).contains(li) && abs(l - CGFloat(li)) < 0.3 ? li : nil
        }
        let ys = rangees.map { r in moyenne(r.map { yc($0) }) }
        var meilleures: (y0: CGFloat, pas: CGFloat, nb: Int)?
        for (i, yp) in ys.enumerated() {
            for yq in ys[(i + 1)...] {
                for (kp, kq) in [(0, 1), (1, 2), (0, 2)] {
                    let pas = (yq - yp) / CGFloat(kq - kp)
                    guard pas > hauteurType * 1.2 else { continue }
                    let y0 = yp - CGFloat(kp) * pas
                    let nb = alignesEnX.filter { ligneDe($0, y0, pas) != nil }.count
                    if nb > meilleures?.nb ?? 0 { meilleures = (y0, pas, nb) }
                }
            }
        }
        guard let lignesTrouvees = meilleures else { return introuvable }
        var y0 = lignesTrouvees.y0, pas = lignesTrouvees.pas
        // Correction : y0 et pas réajustés sur les numéros retenus (y = y0 + pas × ligne).
        let retenus = alignesEnX.compactMap { n in ligneDe(n, y0, pas).map { (Double($0), Double(yc(n))) } }
        if let d = ajuster(retenus), CGFloat(d.a) > hauteurType * 1.2 { y0 = CGFloat(d.b); pas = CGFloat(d.a) }
        if let d = ajuster(alignesEnX.filter { ligneDe($0, y0, pas) != nil }.map { (col($0), x($0)) }), d.a * 8 < 1.05 {
            droite = d
        }

        // Assez de numéros bien placés, sur plusieurs colonnes et plusieurs lignes ?
        let places = alignesEnX.filter { abs(droite.colonne(x($0)) - col($0)) < 0.35 && ligneDe($0, y0, pas) != nil }
        guard places.count >= 5, Set(places.map(col)).count >= 3,
              Set(places.compactMap { ligneDe($0, y0, pas) }).count >= 2 else { return introuvable }

        // 4. Chaque numéro confronté à sa place théorique.
        var cases = vide
        var remarques = ["Aucun carton reconnu d'emblée : la grille a été estimée d'après la place des numéros lus. Vérifiez-la avec soin."]
        var horsCarton: [Int] = [], ecartes: [Int] = []
        for n in candidats.sorted(by: { $0.confiance > $1.confiance }) {
            let ce = droite.colonne(x(n)), c = Int(ce.rounded())
            guard (0...8).contains(c), abs(ce - Double(c)) < 0.4, let l = ligneDe(n, y0, pas) else {
                horsCarton.append(n.valeur); continue
            }
            var k: CaseLue
            if Carton.colonne(pour: n.valeur) == c {
                var doutes: [String] = []
                if n.confiance < confianceMinimale { doutes.append("Lecture peu nette.") }
                let alternatives = n.alternatives.filter { $0 != n.valeur && Carton.colonne(pour: $0) == c }
                if !alternatives.isEmpty {
                    doutes.append("Peut aussi se lire \(alternatives.map(String.init).joined(separator: " ou ")).")
                }
                k = CaseLue(valeur: n.valeur, doutes: doutes, alternatives: alternatives, confiance: n.confiance, cadre: n.cadre)
            } else if let w = n.alternatives.first(where: { Carton.colonne(pour: $0) == c && (1...90).contains($0) }) {
                k = CaseLue(valeur: w, doutes: ["Lu « \(n.valeur) », qui ne va pas dans cette colonne (\(libelleColonne(c))) : sans doute \(w)."],
                            alternatives: [], confiance: n.confiance, cadre: n.cadre)
            } else {
                // Même chiffre des unités, dans la dizaine de la colonne : simple suggestion.
                let u = c * 10 + n.valeur % 10
                let suggestion = (1...90).contains(u) && Carton.colonne(pour: u) == c ? [u] : []
                ecartes.append(n.valeur)
                k = CaseLue(valeur: nil,
                            doutes: ["Lu « \(n.valeur) » à cet endroit, ce qui ne correspond pas à la colonne \(libelleColonne(c)) : numéro écarté."],
                            alternatives: suggestion, confiance: n.confiance, cadre: n.cadre)
            }
            let existante = cases[l][c]
            if existante.valeur == nil && existante.doutes.isEmpty {
                cases[l][c] = k
            } else if existante.valeur == nil, k.valeur != nil {
                // Un numéro écarté occupait la case : le numéro à sa place le remplace, à vérifier.
                k.doutes += existante.doutes
                cases[l][c] = k
            } else if let v = k.valeur {
                // Case déjà prise (lecture plus sûre, triée en premier) : le second numéro est écarté.
                cases[l][c].doutes.append("Le \(v) a aussi été lu dans cette case et a été écarté.")
                cases[l][c].alternatives = Array(Set(cases[l][c].alternatives + [v])).sorted()
            }
        }
        if !ecartes.isEmpty {
            remarques.append("Écarté car pas à sa place sur le carton : \(ecartes.map(String.init).joined(separator: ", ")).")
        }
        if !horsCarton.isEmpty {
            remarques.append("Ignoré hors du carton : \(horsCarton.map(String.init).joined(separator: ", ")).")
        }

        let lignes = (0...2).map { y0 + pas * CGFloat($0) }
        var r = Resultat(cases: cases, remarques: remarques, lignesTrouvees: 3, maxParLigne: 0,
                         geometrie: Geometrie(a: CGFloat(droite.a), b: CGFloat(droite.b), lignes: lignes, pas: pas,
                                              pente: pente, xReference: xRef))
        recalculer(&r)
        return r
    }

    /// Sens de lecture : sur un carton à l'endroit, les numéros croissent de gauche à droite.
    /// Positif si l'image est à l'endroit, négatif si elle est à l'envers, proche de 0 si elle est de côté.
    static func sensDeLecture(_ lus: [NumeroLu]) -> Int {
        let candidats = lus.filter { (1...90).contains($0.valeur) && $0.cadre.height > 0 }
        guard !candidats.isEmpty else { return 0 }
        var total = 0
        for ligne in enLignes(candidats, tolerance: mediane(candidats.map(\.cadre.height)) * 0.6) {
            let triee = ligne.sorted { $0.cadre.midX < $1.cadre.midX }
            for (g, d) in zip(triee, triee.dropFirst()) where d.valeur != g.valeur {
                total += d.valeur > g.valeur ? 1 : -1
            }
        }
        return total
    }

    private static func origine(_ n: NumeroLu, _ a: CGFloat) -> CGFloat {
        n.cadre.midX - a * CGFloat(Carton.colonne(pour: n.valeur))
    }

    private static func enLignes(_ nombres: [NumeroLu], tolerance: CGFloat) -> [[NumeroLu]] {
        var lignes: [[NumeroLu]] = []
        for n in nombres.sorted(by: { $0.cadre.midY < $1.cadre.midY }) {
            if let derniere = lignes.last, abs(n.cadre.midY - moyenne(derniere.map(\.cadre.midY))) < tolerance {
                lignes[lignes.count - 1].append(n)
            } else {
                lignes.append([n])
            }
        }
        return lignes
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
