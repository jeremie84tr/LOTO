#if DEBUG
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Navigation automatique pour les captures App Store (compilation Debug uniquement).
///
/// Arguments de lancement :
///   -ecran accueil|soiree|partie|cartons|statistiques
///   -feuille nouvellePartie        (ouvre le choix des phases sur la page soirée)
///   -defiler tableau|cartons       (fait défiler la partie jusqu'à cette section)
///   -fichierDonnees /chemin.json   (utilise ce fichier de données)
///   (macOS : la fenêtre passe en 1440 × 900 au premier plan, capturée ensuite par screencapture)
struct ModeCapture: ViewModifier {
    @Binding var selection: Selection?
    @Binding var chemin: [Route]
    let soirees: [Soiree]

    func body(content: Content) -> some View {
        content.task {
            let d = UserDefaults.standard
            guard let ecran = d.string(forKey: "ecran"), let s = soirees.first else { return }
            #if os(macOS)
            if let w = NSApp.windows.first {
                // Une fenêtre masquée n'est pas redessinée : on la place au premier plan.
                w.setFrame(NSRect(x: 40, y: 40, width: 1440, height: 900), display: true)
                w.level = .floating
                w.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
            }
            #endif
            try? await Task.sleep(for: .seconds(1))
            switch ecran {
            case "statistiques": selection = .statistiquesGlobales
            case "accueil": break
            default: selection = .soiree(s.id)
            }
            try? await Task.sleep(for: .seconds(1))
            switch ecran {
            case "partie":
                if let p = s.parties.last { chemin = [.partie(soiree: s.id, partie: p.id)] }
            case "cartons":
                chemin = [.cartons(s.id)]
            default: break
            }
        }
    }
}

extension View {
    func modeCapture(selection: Binding<Selection?>, chemin: Binding<[Route]>, soirees: [Soiree]) -> some View {
        modifier(ModeCapture(selection: selection, chemin: chemin, soirees: soirees))
    }

    /// Fait défiler jusqu'à la section demandée par « -defiler ».
    func defilementCapture(_ proxy: ScrollViewProxy) -> some View {
        task {
            guard let cible = UserDefaults.standard.string(forKey: "defiler") else { return }
            try? await Task.sleep(for: .seconds(2))
            proxy.scrollTo(cible, anchor: .top)
        }
    }
}

#endif
