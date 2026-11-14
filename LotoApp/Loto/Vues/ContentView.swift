import SwiftUI

enum Selection: Hashable {
    case soiree(UUID)
    case statistiquesGlobales
}

struct ContentView: View {
    @Environment(Magasin.self) private var magasin
    @State private var selection: Selection?
    @State private var chemin: [Route] = []
    @State private var nouvelleSoiree = false
    @State private var importer = false
    @State private var exporter = false
    @State private var documentExport: DocumentLoto?
    @State private var soireeASupprimer: Soiree?
    @State private var info: String?
    private var soireesTriees: [Soiree] { magasin.soirees.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Soirées") {
                    ForEach(soireesTriees) { s in
                        NavigationLink(value: Selection.soiree(s.id)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.lieu).font(.headline)
                                Text("\(s.date.formatted(date: .abbreviated, time: .omitted)) · \(s.parties.count) partie\(s.parties.count > 1 ? "s" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) { soireeASupprimer = s } label: { Label("Supprimer", systemImage: "trash") }
                        }
                        .swipeActions {
                            Button(role: .destructive) { soireeASupprimer = s } label: { Label("Supprimer", systemImage: "trash") }
                        }
                    }
                }
                Section("Analyse") {
                    NavigationLink(value: Selection.statistiquesGlobales) {
                        Label("Statistiques globales", systemImage: "chart.bar.xaxis")
                    }
                }
            }
            .navigationTitle("Loto")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { nouvelleSoiree = true } label: { Label("Nouvelle soirée", systemImage: "plus") }
                }
                ToolbarItem {
                    Menu {
                        Button { importer = true } label: { Label("Importer un fichier…", systemImage: "square.and.arrow.down") }
                        Button {
                            if let data = try? magasin.exporter() {
                                documentExport = DocumentLoto(data: data)
                                exporter = true
                            }
                        } label: { Label("Exporter toutes les données…", systemImage: "square.and.arrow.up") }
                        Divider()
                        Button { magasin.rechargerExemples() } label: {
                            Label("Recharger les exemples", systemImage: "clock.arrow.circlepath")
                        }
                    } label: {
                        Label("Plus", systemImage: "ellipsis.circle")
                    }
                }
            }
        } detail: {
            NavigationStack(path: $chemin) {
                Group {
                    switch selection {
                    case .soiree(let id):
                        SoireeView(soireeID: id, chemin: $chemin)
                    case .statistiquesGlobales:
                        StatistiquesView(titre: "Statistiques globales", stats: magasin.statistiquesGlobales)
                    case nil:
                        ContentUnavailableView("Choisissez une soirée", systemImage: "circle.grid.3x3.fill",
                                               description: Text("ou créez-en une avec le bouton +"))
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .partie(let s, let p):
                        PartieView(soireeID: s, partieID: p)
                    case .cartons(let s):
                        CartonsView(soireeID: s)
                    case .statistiques(let s):
                        StatistiquesView(titre: "Statistiques · \(magasin.soiree(s)?.lieu ?? "")",
                                         stats: Statistiques(parties: PartieJouee.depuis(magasin.soiree(s).map { [$0] } ?? [])))
                    }
                }
            }
            .id(selection)
        }
        .onChange(of: selection) { chemin = [] }
        #if DEBUG
        .modeCapture(selection: $selection, chemin: $chemin, soirees: soireesTriees)
        #endif
        .sheet(isPresented: $nouvelleSoiree) {
            NouvelleSoireeSheet { id in selection = .soiree(id) }
        }
        .fileImporter(isPresented: $importer, allowedContentTypes: [.json]) { resultat in
            do {
                let url = try resultat.get()
                let acces = url.startAccessingSecurityScopedResource()
                defer { if acces { url.stopAccessingSecurityScopedResource() } }
                let n = try magasin.importer(Data(contentsOf: url))
                info = "\(n) soirée\(n > 1 ? "s" : "") importée\(n > 1 ? "s" : "")."
            } catch {
                info = "Import impossible : \(error.localizedDescription)"
            }
        }
        .fileExporter(isPresented: $exporter, document: documentExport, contentType: .json,
                      defaultFilename: "loto-\(Date().formatted(.iso8601.year().month().day()))") { _ in }
        .confirmationDialog("Supprimer « \(soireeASupprimer?.titre ?? "") » ?",
                            isPresented: Binding(get: { soireeASupprimer != nil }, set: { if !$0 { soireeASupprimer = nil } }),
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let s = soireeASupprimer {
                    if selection == .soiree(s.id) { selection = nil }
                    magasin.supprimerSoiree(s.id)
                }
                soireeASupprimer = nil
            }
        } message: {
            Text("Cartons, tirages et résultats de cette soirée seront perdus. Pensez à exporter vos données avant.")
        }
        .alert("Loto", isPresented: Binding(get: { info != nil || magasin.erreur != nil },
                                            set: { if !$0 { info = nil; magasin.erreur = nil } })) {
            Button("OK") {}
        } message: {
            Text(info ?? magasin.erreur ?? "")
        }
    }
}
