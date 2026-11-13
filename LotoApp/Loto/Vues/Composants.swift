import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

extension TypePhase {
    var couleur: Color {
        switch self {
        case .quine: return .blue
        case .doubleQuine: return .purple
        case .cartonPlein: return .orange
        }
    }
}

extension Conseil.Niveau {
    var couleur: Color {
        switch self {
        case .gagne: return .green
        case .unNumero: return .red
        case .proche: return .orange
        case .info: return .secondary
        }
    }

    var icone: String {
        switch self {
        case .gagne: return "trophy.fill"
        case .unNumero: return "exclamationmark.circle.fill"
        case .proche: return "flame.fill"
        case .info: return "info.circle"
        }
    }
}

extension Binding where Value == String? {
    /// Lie un champ texte à une chaîne facultative (vide = nil).
    func ouVide() -> Binding<String> {
        Binding<String>(get: { wrappedValue ?? "" },
                        set: { wrappedValue = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 })
    }
}

struct BouleView: View {
    let numero: Int
    var taille: CGFloat = 36
    var couleur: Color = .accentColor

    var body: some View {
        Text("\(numero)")
            .font(.system(size: taille * 0.42, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: taille, height: taille)
            .background(Circle().fill(couleur.gradient))
            .accessibilityLabel("Numéro \(numero)")
    }
}

/// Un carton 3 × 9, avec les numéros tirés cochés et ceux qui manquent entourés.
struct CartonGrilleView: View {
    let carton: Carton
    var tires: Set<Int> = []
    var manquants: Set<Int> = []
    var gagnants: Set<Int> = []
    var dernier: Int? = nil
    var compact = false

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<3, id: \.self) { l in
                GridRow {
                    ForEach(0..<9, id: \.self) { c in
                        cellule(carton.case_(l, c))
                    }
                }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
    }

    @ViewBuilder
    private func cellule(_ n: Int?) -> some View {
        let hauteur: CGFloat = compact ? 22 : 30
        if let n {
            let tire = tires.contains(n)
            let gagnant = gagnants.contains(n)
            Text("\(n)")
                .font(.system(size: compact ? 11 : 14, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: hauteur)
                .foregroundStyle(tire ? Color.white : Color.primary)
                .background(RoundedRectangle(cornerRadius: 4)
                    .fill(tire ? (n == dernier ? Color.red : Color.accentColor) : Color.gray.opacity(0.15)))
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(gagnant ? Color.orange : (manquants.contains(n) ? Color.orange.opacity(0.6) : .clear),
                                  lineWidth: gagnant ? 3 : 1.5))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.04))
                .frame(maxWidth: .infinity, minHeight: hauteur)
        }
    }
}

/// Lit les alertes à voix haute (option).
@MainActor
final class Annonceur {
    static let partage = Annonceur()
    private let synthe = AVSpeechSynthesizer()

    func dire(_ texte: String) {
        synthe.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: texte)
        u.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        synthe.speak(u)
    }
}

struct DocumentLoto: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension View {
    /// Taille raisonnable pour les feuilles sur macOS.
    func tailleFeuille() -> some View {
        #if os(macOS)
        return self.frame(minWidth: 460, minHeight: 420)
        #else
        return self
        #endif
    }
}
