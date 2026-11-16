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

    /// Tous les nombres de 1 ou 2 chiffres visibles sur l'image, avec leur position et leur fiabilité.
    static func lireNumeros(_ image: CGImage) async throws -> [NumeroLu] {
        try await Task.detached(priority: .userInitiated) {
            let requete = VNRecognizeTextRequest()
            requete.recognitionLevel = .accurate
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
        }.value
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
