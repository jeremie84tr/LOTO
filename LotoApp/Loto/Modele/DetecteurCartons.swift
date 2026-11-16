import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import Vision

/// Un carton (découpé et redressé) et ce que Vision y a lu.
struct LecturePhoto: Identifiable {
    let id = UUID()
    let image: CGImage
    let resultat: LectureCarton.Resultat
}

/// Un carton repéré sur une photo, découpé puis lu.
struct CartonDetecte: Identifiable, @unchecked Sendable {
    let id = UUID()
    /// Coins du carton sur l'image de la photo analysée (normalisés, origine en haut à gauche) :
    /// haut gauche, haut droit, bas droit, bas gauche.
    let coins: [CGPoint]
    /// Le carton seul : c'est sur cette image que les numéros sont vérifiés.
    let image: CGImage
    let resultat: LectureCarton.Resultat

    var lecture: LecturePhoto { LecturePhoto(image: image, resultat: resultat) }
    var centre: CGPoint {
        CGPoint(x: coins.map(\.x).reduce(0, +) / 4, y: coins.map(\.y).reduce(0, +) / 4)
    }
}

/// Une photo (redressée) et les cartons qu'on y a trouvés, dans l'ordre de lecture.
struct PhotoAnalysee: Identifiable, @unchecked Sendable {
    let id = UUID()
    /// La feuille remise à plat et à l'endroit ; les coins des cartons s'y rapportent.
    let image: CGImage
    let cartons: [CartonDetecte]
    /// Faux si aucun carton n'a été reconnu : le seul carton proposé est alors une grille estimée
    /// d'après la place des numéros (`LectureCarton.estimerGrille`). Sans aucun numéro valide,
    /// `DetecteurCartons.analyser` lève `Erreur.aucunNumero` au lieu de renvoyer une photo.
    let cadresTrouves: Bool
}

/// Trouve tous les cartons d'une photo (un seul ou une planche entière) et les lit.
///
/// Les cadres des cartons sont trop variables (coins arrondis, cartons accolés, papier de couleur)
/// pour être détectés de façon fiable ; on s'appuie plutôt sur la structure des numéros :
/// 1. la feuille est repérée et remise à plat (correction de perspective), puis tournée dans le
///    bon sens : celui où les numéros croissent de gauche à droite ;
/// 2. une lecture de toute la feuille donne la position d'une bonne partie des numéros, que l'on
///    regroupe en cartons de 3 lignes × 9 colonnes (`LectureCarton.regrouper`) ;
/// 3. chaque carton est découpé, et chacune de ses 27 cases est relue seule ;
/// 4. les deux lectures sont croisées : seul un numéro lu pareil par les deux est considéré comme sûr.
enum DetecteurCartons {
    enum Erreur: LocalizedError {
        /// Rien d'utilisable sur la photo : aucun numéro valide n'a pu être placé sur un carton.
        case aucunNumero
        var errorDescription: String? {
            "Aucun numéro n'a été détecté sur cette photo. Reprenez-la de plus près, à plat et bien éclairée, ou saisissez le carton à la main."
        }
    }

    private static let contexte = CIContext()

    static func analyser(_ image: CGImage) async throws -> PhotoAnalysee {
        let feuille = try await orienter(try await redresserFeuille(image))
        let lus = try await LecteurVision.lireNumeros(feuille)

        var cartons: [CartonDetecte] = []
        for groupe in LectureCarton.regrouper(lus) where groupe.count >= 5 {
            if let c = try await lireCarton(feuille, groupe: groupe) { cartons.append(c) }
        }
        let structureTrouvee = !cartons.isEmpty

        if cartons.isEmpty {
            // Aucun carton reconnu : on estime une grille d'après la place des numéros lus, en ne
            // gardant que ceux qui sont là où un carton les attend. Si rien ne s'accorde, la grille
            // reste vide (saisie à la main) plutôt que remplie de numéros sans rapport.
            let estimee = LectureCarton.estimerGrille(lus)
            let resultat = try await relire(feuille, estimee)
            var zone = CGRect(x: 0, y: 0, width: 1, height: 1)
            if let geo = estimee.geometrie {
                let cadre = geo.cadreCarton.intersection(zone)
                if !cadre.isNull { zone = cadre }
            }
            let coins = [CGPoint(x: zone.minX, y: zone.minY), CGPoint(x: zone.maxX, y: zone.minY),
                         CGPoint(x: zone.maxX, y: zone.maxY), CGPoint(x: zone.minX, y: zone.maxY)]
            // Même la relecture case par case n'a rien donné : inutile de proposer une grille vide.
            guard resultat.numerosLus > 0 else { throw Erreur.aucunNumero }
            cartons = [CartonDetecte(coins: coins, image: feuille, resultat: resultat)]
        }
        // Ordre de lecture : par rangée de haut en bas, puis de gauche à droite.
        let hauteur = cartons.map { $0.coins[3].y - $0.coins[0].y }.min() ?? 0.1
        cartons.sort { a, b in
            abs(a.centre.y - b.centre.y) < hauteur / 2 ? a.centre.x < b.centre.x : a.centre.y < b.centre.y
        }
        return PhotoAnalysee(image: feuille, cartons: cartons, cadresTrouves: structureTrouvee)
    }

    // MARK: - Étapes

    /// Repère la feuille (planche ou carton) et la remet à plat ; renvoie l'image telle quelle sinon.
    static func redresserFeuille(_ image: CGImage) async throws -> CGImage {
        let coins: [CGPoint]? = try await LecteurVision.executer {
            let requete = VNDetectDocumentSegmentationRequest()
            try VNImageRequestHandler(cgImage: image, orientation: .up).perform([requete])
            guard let doc = requete.results?.first, doc.confidence > 0.5 else { return nil }
            return [doc.topLeft, doc.topRight, doc.bottomRight, doc.bottomLeft].map { CGPoint(x: $0.x, y: 1 - $0.y) }
        }
        // Une « feuille » minuscule est sans doute un détail de la photo : on garde l'image entière.
        guard let coins, aire(coins) > 0.2, let plat = redresser(image, coins: coins), let cg = rendre(plat) else {
            return image
        }
        return cg
    }

    /// Tourne la feuille dans le sens où les numéros croissent de gauche à droite.
    static func orienter(_ feuille: CGImage) async throws -> CGImage {
        // Lecture rapide sur une version réduite : il ne s'agit que de comparer les sens.
        let k = min(1, 1600 / CGFloat(max(feuille.width, feuille.height)))
        let reduite = CIImage(cgImage: feuille).transformed(by: CGAffineTransform(scaleX: k, y: k))
        var meilleur: (sens: CGImagePropertyOrientation, score: Int) = (.up, Int.min)
        for sens in [CGImagePropertyOrientation.up, .down, .right, .left] {
            guard let cg = rendre(reduite.oriented(sens)) else { continue }
            let score = LectureCarton.sensDeLecture(try await LecteurVision.lireNumeros(cg, precis: false))
            if score > meilleur.score { meilleur = (sens, score) }
            if sens == .up, score >= 8 { break } // clairement à l'endroit : inutile de tourner
        }
        guard meilleur.sens != .up, let tournee = rendre(CIImage(cgImage: feuille).oriented(meilleur.sens)) else {
            return feuille
        }
        return tournee
    }

    /// Découpe le carton d'un groupe de numéros, puis le lit avec la relecture case par case.
    private static func lireCarton(_ feuille: CGImage, groupe: [NumeroLu]) async throws -> CartonDetecte? {
        guard let geo = LectureCarton.analyser(groupe, garderLignesIsolees: true).geometrie else { return nil }
        let zone = geo.cadreCarton.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !zone.isNull, zone.width > 0.05, zone.height > 0.02 else { return nil }
        let w = CGFloat(feuille.width), h = CGFloat(feuille.height)
        let px = CGRect(x: zone.minX * w, y: zone.minY * h, width: zone.width * w, height: zone.height * h).integral
        guard let decoupe = feuille.cropping(to: px) else { return nil }

        // Positions exprimées dans le carton découpé.
        let reel = CGRect(x: px.minX / w, y: px.minY / h, width: px.width / w, height: px.height / h)
        let local = groupe.map { n -> NumeroLu in
            var m = n
            m.cadre = CGRect(x: (n.cadre.minX - reel.minX) / reel.width, y: (n.cadre.minY - reel.minY) / reel.height,
                             width: n.cadre.width / reel.width, height: n.cadre.height / reel.height)
            return m
        }
        let resultat = try await relire(decoupe, LectureCarton.analyser(local, garderLignesIsolees: true))
        guard resultat.ressembleAUnCarton else { return nil }
        let coins = [CGPoint(x: reel.minX, y: reel.minY), CGPoint(x: reel.maxX, y: reel.minY),
                     CGPoint(x: reel.maxX, y: reel.maxY), CGPoint(x: reel.minX, y: reel.maxY)]
        return CartonDetecte(coins: coins, image: decoupe, resultat: resultat)
    }

    /// Seconde lecture, case par case, croisée avec la première.
    private static func relire(_ image: CGImage, _ resultat: LectureCarton.Resultat) async throws -> LectureCarton.Resultat {
        guard let geo = resultat.geometrie else { return resultat }
        let zones = (0..<3).flatMap { l in (0..<9).map { geo.cellule(l, $0) } }
        let lus = try await LecteurVision.lireCases(image, zones: zones)
        let parCase = (0..<3).map { l in Array(lus[(l * 9)..<(l * 9 + 9)]) }
        return LectureCarton.fusionner(resultat, parCase: parCase)
    }

    /// Correction de perspective : le quadrilatère devient un rectangle.
    static func redresser(_ image: CGImage, coins: [CGPoint]) -> CIImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        // Core Image : pixels, origine en bas à gauche.
        func p(_ c: CGPoint) -> CGPoint { CGPoint(x: c.x * w, y: (1 - c.y) * h) }
        let f = CIFilter.perspectiveCorrection()
        f.inputImage = CIImage(cgImage: image)
        f.topLeft = p(coins[0])
        f.topRight = p(coins[1])
        f.bottomRight = p(coins[2])
        f.bottomLeft = p(coins[3])
        return f.outputImage
    }

    private static func rendre(_ image: CIImage) -> CGImage? {
        let e = image.extent.integral
        guard e.width >= 1, e.height >= 1 else { return nil }
        return contexte.createCGImage(image, from: e)
    }

    /// Aire d'un quadrilatère (formule du lacet), en fraction de l'image.
    private static func aire(_ q: [CGPoint]) -> CGFloat {
        var somme: CGFloat = 0
        for i in q.indices {
            let p = q[i], s = q[(i + 1) % q.count]
            somme += p.x * s.y - s.x * p.y
        }
        return abs(somme) / 2
    }
}
