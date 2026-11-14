import SwiftUI

struct CartonsView: View {
    @Environment(Magasin.self) private var magasin
    let soireeID: UUID

    @State private var edition: Carton?
    @State private var estNouveau = false

    var body: some View {
        let s = magasin.soiree(soireeID)
        List {
            if let s, s.cartons.isEmpty {
                ContentUnavailableView {
                    Label("Aucun carton", systemImage: "square.grid.3x3")
                } description: {
                    Text("Ajoutez vos cartons : 15 numéros chacun, 5 par ligne.")
                } actions: {
                    Button("Ajouter un carton") { nouveau() }
                }
            }
            ForEach(s?.planches ?? []) { planche in
                Section(planche.nom) {
                    ForEach(planche.cartons) { c in
                        Button { estNouveau = false; edition = c } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(c.titre).font(.headline)
                                    if let serie = c.serie { Text("série \(serie)").font(.caption).foregroundStyle(.secondary) }
                                    if let j = c.joueur { Text("· \(j)").font(.caption).foregroundStyle(.secondary) }
                                }
                                CartonGrilleView(carton: c, compact: true)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { magasin.supprimerCarton(c.id, dans: soireeID) } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) { magasin.supprimerCarton(c.id, dans: soireeID) } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cartons")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: nouveau) { Label("Ajouter un carton", systemImage: "plus") }
            }
        }
        .sheet(item: $edition) { c in
            let autres = Set((s?.cartons ?? []).map(\.id)).subtracting(estNouveau ? [] : [c.id])
            CartonEditor(carton: c, idsPris: autres) { modifie in
                magasin.enregistrerCarton(modifie, ancienID: estNouveau ? nil : c.id, dans: soireeID)
            }
        }
    }

    private func nouveau() {
        guard let s = magasin.soiree(soireeID) else { return }
        let derniere = s.cartons.last?.planche
        estNouveau = true
        edition = Carton(id: s.prochainIDCarton, planche: derniere)
    }
}

struct CartonEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var carton: Carton
    @State private var texte: String
    let idsPris: Set<String>
    let enregistrer: (Carton) -> Void

    init(carton: Carton, idsPris: Set<String>, enregistrer: @escaping (Carton) -> Void) {
        _carton = State(initialValue: carton)
        _texte = State(initialValue: carton.texteSaisie.trimmingCharacters(in: .whitespacesAndNewlines))
        self.idsPris = idsPris
        self.enregistrer = enregistrer
    }

    var body: some View {
        let analyse = Carton.grille(depuis: Carton.extraireNumeros(texte))
        var erreurs = analyse.erreurs
        let id = carton.id.trimmingCharacters(in: .whitespaces)
        if id.isEmpty { erreurs.insert("Donnez un numéro au carton.", at: 0) }
        if idsPris.contains(id) { erreurs.insert("Le carton \(id) existe déjà.", at: 0) }

        return NavigationStack {
            Form {
                Section("Identification") {
                    TextField("Numéro du carton", text: $carton.id)
                    TextField("Planche (ex. : A)", text: $carton.planche.ouVide())
                    TextField("Série (facultatif)", text: $carton.serie.ouVide())
                    TextField("Joueur (facultatif)", text: $carton.joueur.ouVide())
                }
                Section {
                    TextField("7 28 30 56 65\n6 11 45 68 90\n35 44 54 78 81", text: $texte, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.body.monospacedDigit())
                        #if os(iOS)
                        .keyboardType(.numbersAndPunctuation)
                        #endif
                } header: {
                    Text("Les 15 numéros")
                } footer: {
                    Text("Tapez les numéros dans l'ordre de lecture, ligne par ligne (5 par ligne). Ils sont rangés automatiquement dans leur colonne.")
                }
                Section("Aperçu") {
                    CartonGrilleView(carton: Carton(id: id, grille: analyse.grille))
                    ForEach(erreurs, id: \.self) { e in
                        Label(e, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(carton.titre)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        var c = carton
                        c.id = id
                        c.grille = analyse.grille
                        enregistrer(c)
                        dismiss()
                    }
                    .disabled(!erreurs.isEmpty)
                }
            }
        }
        .tailleFeuille()
    }
}
