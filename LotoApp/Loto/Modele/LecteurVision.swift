import Foundation
import CoreGraphics
import ImageIO
import Vision

/// Lecture des numéros d'un carton sur une photo, avec le framework Vision.
enum LecteurVision {
    enum Erreur: LocalizedError {
        case imageIllisible
        var errorDescription: String? { "Impossible d'ouvrir cette image." }
    }

    /// Décode une photo (JPEG, HEIC, PNG…) en la remettant à l'endroit, réduite à une taille raisonnable.
    static func image(depuis data: Data, coteMax: Int = 3000) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { throw Erreur.imageIllisible }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // applique l'orientation EXIF
            kCGImageSourceThumbnailMaxPixelSize: coteMax,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Erreur.imageIllisible
        }
        return image
    }

    /// File réservée à Vision. Ses appels sont bloquants : lancés dans la réserve de fils de Swift
    /// Concurrency (Task.detached), plusieurs à la fois peuvent l'épuiser et tout bloquer.
    private static let file = DispatchQueue(label: "loto.vision", qos: .userInitiated)

    /// Exécute un travail Vision sur sa file, sans bloquer la réserve de fils de Swift Concurrency.
    static func executer<T>(_ travail: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { suite in
            file.async { suite.resume(with: Result { try travail() }) }
        }
    }

    /// Tous les nombres de 1 ou 2 chiffres visibles sur l'image, avec leur position et leur fiabilité.
    /// `precis == false` : lecture rapide, pour repérer les cartons et leur sens, jamais pour les numéros retenus.
    static func lireNumeros(_ image: CGImage, precis: Bool = true) async throws -> [NumeroLu] {
        try await executer {
            let requete = VNRecognizeTextRequest()
            requete.recognitionLevel = precis ? .accurate : .fast
            requete.usesLanguageCorrection = false // pas de « correction » des nombres en mots
            requete.recognitionLanguages = ["fr-FR"]
            requete.minimumTextHeight = 0.015
            try VNImageRequestHandler(cgImage: image, orientation: .up).perform([requete])

            var resultat: [NumeroLu] = []
            for observation in requete.results ?? [] {
                let candidats = observation.topCandidates(3)
                guard let meilleur = candidats.first else { continue }
                let morceaux = nombres(dans: meilleur.string)
                // Lectures concurrentes du même texte, nombre par nombre (si elles en contiennent autant).
                let autres = candidats.dropFirst()
                    .filter { $0.confidence >= meilleur.confidence * 0.5 }
                    .map { nombres(dans: $0.string).map(\.texte) }
                    .filter { $0.count == morceaux.count }

                for (i, m) in morceaux.enumerated() {
                    // Pour un carton : 1 ou 2 chiffres, sans zéro devant (« 009 » est un numéro de carton).
                    guard m.texte.count <= 2, !m.texte.hasPrefix("0"), let valeur = Int(m.texte) else { continue }
                    let boite = (try? meilleur.boundingBox(for: m.plage))?.boundingBox ?? observation.boundingBox
                    // Vision : origine en bas à gauche → on passe en haut à gauche.
                    let cadre = CGRect(x: boite.minX, y: 1 - boite.maxY, width: boite.width, height: boite.height)
                    let alternatives = autres.compactMap { Int($0[i]) }.filter { $0 != valeur }
                    resultat.append(NumeroLu(valeur: valeur, confiance: meilleur.confidence, cadre: cadre,
                                             alternatives: Array(Set(alternatives)).sorted()))
                }
            }
            return resultat
        }
    }

    /// Relit chaque zone (case du carton) séparément, en mode rapide : sur un nombre isolé, il se
    /// trompe moins que le mode précis, conçu pour des lignes de texte. Zones normalisées, origine
    /// en haut à gauche ; renvoie les nombres de 1 ou 2 chiffres lus dans chacune.
    static func lireCases(_ image: CGImage, zones: [CGRect]) async throws -> [[Int]] {
        try await executer {
            let w = CGFloat(image.width), h = CGFloat(image.height)
            let sequence = VNSequenceRequestHandler()
            return try zones.map { zone in
                let px = CGRect(x: zone.minX * w, y: zone.minY * h, width: zone.width * w, height: zone.height * h)
                    .integral.intersection(CGRect(x: 0, y: 0, width: w, height: h))
                guard !px.isNull, px.width >= 4, px.height >= 4, let decoupe = image.cropping(to: px) else { return [] }
                let requete = VNRecognizeTextRequest()
                requete.recognitionLevel = .fast
                requete.usesLanguageCorrection = false
                try sequence.perform([requete], on: agrandie(decoupe, hauteurMin: 160))
                return (requete.results ?? []).flatMap { o in
                    nombres(dans: o.topCandidates(1).first?.string ?? "").compactMap { m in
                        m.texte.count <= 2 && !m.texte.hasPrefix("0") ? Int(m.texte) : nil
                    }
                }
            }
        }
    }

    /// Les petites cases sont agrandies : les chiffres trop petits se lisent mal.
    private static func agrandie(_ image: CGImage, hauteurMin: Int) -> CGImage {
        guard image.height < hauteurMin else { return image }
        let k = CGFloat(hauteurMin) / CGFloat(image.height)
        let w = Int(CGFloat(image.width) * k), h = hauteurMin
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    private static func nombres(dans texte: String) -> [(texte: String, plage: Range<String.Index>)] {
        var morceaux: [(String, Range<String.Index>)] = []
        var debut: String.Index?
        for i in texte.indices {
            if texte[i].isASCII, texte[i].isNumber {
                if debut == nil { debut = i }
            } else if let d = debut {
                morceaux.append((String(texte[d..<i]), d..<i))
                debut = nil
            }
        }
        if let d = debut { morceaux.append((String(texte[d...]), d..<texte.endIndex)) }
        return morceaux
    }
}
