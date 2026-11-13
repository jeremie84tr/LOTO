import SwiftUI

enum Route: Hashable {
    case partie(soiree: UUID, partie: UUID)
    case cartons(UUID)
    case statistiques(UUID)
}

struct SoireeView: View {
    @Environment(Magasin.self) private var magasin
    let soireeID: UUID
    @Binding var chemin: [Route]

    @State private var feuilleNouvellePartie = false
    @State private var feuilleDeroulement = false
    @State private var partieASupprimer: Partie?

    var body: some View {
        if let s = magasin.soiree(soireeID) {
            liste(s)
        } else {
            ContentUnavailableView("Soirée introuvable", systemImage: "questionmark.circle")
        }
    }

    private func liste(_ s: Soiree) -> some View {
        Form {
            Section("Soirée") {
                TextField("Lieu", text: Binding(get: { s.lieu },
                                                set: { v in magasin.modifierSoiree(soireeID) { $0.lieu = v } }))
                DatePicker("Date", selection: Binding(get: { s.date },
                                                      set: { v in magasin.modifierSoiree(soireeID) { $0.date = v } }),
                           displayedComponents: .date)
                Button { feuilleDeroulement = true } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Phases par défaut")
                        Text(Deroulement.description(s.deroulementParDefaut))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }

            Section {
                if s.parties.isEmpty {
                    Text("Aucune partie pour l'instant.").foregroundStyle(.secondary)
                }
                ForEach(s.parties.sorted { $0.numero > $1.numero }) { p in
                    NavigationLink(value: Route.partie(soiree: soireeID, partie: p.id)) {
                        ligne(p)
                    }
                    .contextMenu {
                        Button(role: .destructive) { partieASupprimer = p } label: { Label("Supprimer", systemImage: "trash") }
                    }
                    .swipeActions {
                        Button(role: .destructive) { partieASupprimer = p } label: { Label("Supprimer", systemImage: "trash") }
                    }
                }
            } header: {
                HStack {
                    Text("Parties")
                    Spacer()
                    Button { feuilleNouvellePartie = true } label: { Label("Nouvelle partie", systemImage: "plus.circle.fill") }
                        .buttonStyle(.borderless)
                        .textCase(nil)
                }
            }

            Section("Cartons") {
                NavigationLink(value: Route.cartons(soireeID)) {
                    LabeledContent("Mes cartons", value: "\(s.cartons.count) · \(s.planches.count) planche\(s.planches.count > 1 ? "s" : "")")
                }
            }

            Section("Analyse") {
                NavigationLink(value: Route.statistiques(soireeID)) {
                    Label("Statistiques de la soirée", systemImage: "chart.bar.xaxis")
                }
            }

            Section("Notes") {
                TextField("Notes", text: Binding(get: { s.notes },
                                                 set: { v in magasin.modifierSoiree(soireeID) { $0.notes = v } }),
                          axis: .vertical)
                    .lineLimit(2...6)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(s.lieu)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { feuilleNouvellePartie = true } label: { Label("Nouvelle partie", systemImage: "plus") }
            }
        }
        #if DEBUG
        .task {
            guard UserDefaults.standard.string(forKey: "feuille") == "nouvellePartie" else { return }
            try? await Task.sleep(for: .seconds(1.5))
            feuilleNouvellePartie = true
        }
        #endif
        .sheet(isPresented: $feuilleNouvellePartie) {
            DeroulementSheet(titre: "Partie \(s.prochainNumeroDePartie)", bouton: "Commencer",
                             phases: s.parties.max { $0.numero < $1.numero }.flatMap { $0.importee ? nil : $0.deroulement }
                                ?? s.deroulementParDefaut) { phases in
                if let id = magasin.nouvellePartie(dans: soireeID, deroulement: phases) {
                    chemin.append(.partie(soiree: soireeID, partie: id))
                }
            }
        }
        .sheet(isPresented: $feuilleDeroulement) {
            DeroulementSheet(titre: "Phases par défaut", bouton: "Enregistrer", phases: s.deroulementParDefaut) { phases in
                magasin.modifierSoiree(soireeID) { $0.deroulementParDefaut = phases }
            }
        }
        .confirmationDialog("Supprimer la partie \(partieASupprimer?.numero ?? 0) ?",
                            isPresented: Binding(get: { partieASupprimer != nil }, set: { if !$0 { partieASupprimer = nil } }),
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                if let p = partieASupprimer { magasin.supprimerPartie(p.id, dans: soireeID) }
                partieASupprimer = nil
            }
        } message: {
            Text("Le tirage et les résultats de cette partie seront perdus.")
        }
    }

    private func ligne(_ p: Partie) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Partie \(p.numero)").font(.headline)
                Spacer()
                if p.importee {
                    Text("historique").font(.caption).foregroundStyle(.secondary)
                } else if p.estTerminee {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Text("en cours").font(.caption.bold()).foregroundStyle(.orange)
                }
            }
            Text("\(p.tirage.count) numéros · \(Deroulement.description(p.deroulement))")
                .font(.caption).foregroundStyle(.secondary)
            let victoires = p.phases.indices.filter { p.phases[$0].gagnant?.parNous == true }
            if !victoires.isEmpty {
                Text("🎉 " + victoires.map { p.nomPhase($0) }.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.green)
            }
        }
    }
}

struct NouvelleSoireeSheet: View {
    @Environment(Magasin.self) private var magasin
    @Environment(\.dismiss) private var dismiss
    let creee: (UUID) -> Void

    @State private var lieu = ""
    @State private var date = Date()
    @State private var phases = Deroulement.modeles[0].phases
    @State private var source: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Soirée") {
                    TextField("Lieu (ex. : Salle des fêtes)", text: $lieu)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Cartons", selection: $source) {
                        Text("Nouveaux cartons (à saisir)").tag(UUID?.none)
                        ForEach(magasin.soirees.filter { !$0.cartons.isEmpty }) { s in
                            Text("Reprendre ceux de \(s.titre)").tag(Optional(s.id))
                        }
                    }
                }
                DeroulementEditor(phases: $phases)
            }
            .formStyle(.grouped)
            .navigationTitle("Nouvelle soirée")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        let id = magasin.ajouterSoiree(lieu: lieu.trimmingCharacters(in: .whitespaces), date: date,
                                                       deroulement: phases, cartonsDe: source)
                        creee(id)
                        dismiss()
                    }
                    .disabled(lieu.trimmingCharacters(in: .whitespaces).isEmpty || phases.isEmpty)
                }
            }
        }
        .tailleFeuille()
    }
}
