import SwiftUI

@main
struct LotoApp: App {
    @State private var magasin: Magasin = {
        #if DEBUG
        if let chemin = UserDefaults.standard.string(forKey: "fichierDonnees") {
            return Magasin(fichier: URL(fileURLWithPath: chemin))
        }
        #endif
        return Magasin()
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(magasin)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
