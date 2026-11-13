import SwiftUI

/// Choix de l'ordre des phases (quines, double quines, carton plein…), librement.
struct DeroulementEditor: View {
    @Binding var phases: [TypePhase]

    var body: some View {
        Section {
            ForEach(Array(phases.enumerated()), id: \.offset) { i, type in
                HStack {
                    Text("\(i + 1).").monospacedDigit().foregroundStyle(.secondary)
                    Label(nom(i), systemImage: type.icone).foregroundStyle(type.couleur)
                    Spacer()
                    Button { deplacer(i, -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(i == 0)
                    Button { deplacer(i, 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(i == phases.count - 1)
                    Button(role: .destructive) { phases.remove(at: i) } label: { Image(systemName: "trash") }
                }
                .buttonStyle(.borderless)
            }
            Menu {
                ForEach(TypePhase.allCases) { t in
                    Button { phases.append(t) } label: { Label(t.nom, systemImage: t.icone) }
                }
            } label: {
                Label("Ajouter une phase", systemImage: "plus.circle")
            }
        } header: {
            Text("Ordre des phases")
        } footer: {
            Text(Deroulement.description(phases))
        }

        Section("Modèles") {
            ForEach(Deroulement.modeles) { d in
                Button { phases = d.phases } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.nom)
                        Text(Deroulement.description(d.phases)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func nom(_ i: Int) -> String {
        let p = Partie(numero: 0, deroulement: phases)
        return p.nomPhase(i)
    }

    private func deplacer(_ i: Int, _ d: Int) {
        let j = i + d
        guard phases.indices.contains(j) else { return }
        phases.swapAt(i, j)
    }
}

struct DeroulementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let titre: String
    let bouton: String
    @State var phases: [TypePhase]
    let valider: ([TypePhase]) -> Void

    var body: some View {
        NavigationStack {
            Form { DeroulementEditor(phases: $phases) }
                .formStyle(.grouped)
                .navigationTitle(titre)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(bouton) { valider(phases); dismiss() }.disabled(phases.isEmpty)
                    }
                }
        }
        .tailleFeuille()
    }
}
