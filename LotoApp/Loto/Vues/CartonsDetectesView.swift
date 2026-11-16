import SwiftUI

/// Les cartons trouvés sur une photo : on les vérifie un par un avant de les utiliser.
///
/// - `plusieurs == false` : on choisit le carton à reporter dans l'éditeur.
/// - `plusieurs == true` : on vérifie autant de cartons que l'on veut, puis on les ajoute
///   tous à la soirée (une planche entière en une photo).
struct CartonsDetectesView: View {
    @Environment(\.dismiss) private var dismiss
    let plusieurs: Bool
    /// Cartons déjà enregistrés, pour ne pas ajouter deux fois le même.
    var existants: [Carton] = []
    let terminer: (_ grilles: [[[Int?]]], _ planche: String?) -> Void

    @State private var photo: PhotoAnalysee?
    @State private var validees: [UUID: [[Int?]]] = [:]
    @State private var enValidation: CartonDetecte?
    @State private var choisie: [[Int?]]?
    @State private var planche: String

    init(plusieurs: Bool, photo: PhotoAnalysee? = nil, existants: [Carton] = [], planche: String? = nil,
         terminer: @escaping (_ grilles: [[[Int?]]], _ planche: String?) -> Void) {
        self.plusieurs = plusieurs
        self.existants = existants
        self.terminer = terminer
        _photo = State(initialValue: photo)
        _planche = State(initialValue: planche ?? "")
    }

    var body: some View {
        let aAjouter = grillesAAjouter
        NavigationStack {
            Form {
                if let photo {
                    Section {
                        PhotoCartons(photo: photo, validees: Set(validees.keys))
                            .frame(maxHeight: 280)
                            .frame(maxWidth: .infinity)
                        Button { self.photo = nil; validees = [:] } label: {
                            Label("Reprendre une photo", systemImage: "arrow.counterclockwise")
                        }
                    } footer: {
                        Text(!photo.cadresTrouves
                             ? "Aucun carton reconnu d'emblée : une grille a été estimée d'après la place des numéros, et seuls ceux qui sont à leur place ont été gardés. Vérifiez-la avec soin."
                             : "\(photo.cartons.count) carton\(photo.cartons.count > 1 ? "s" : "") repéré\(photo.cartons.count > 1 ? "s" : ""). Chaque case a été lue deux fois ; seuls les numéros lus pareil les deux fois sont considérés comme sûrs.")
                    }
                    Section(plusieurs ? "Vérifiez chaque carton à ajouter" : "Choisissez le carton") {
                        ForEach(Array(photo.cartons.enumerated()), id: \.element.id) { i, c in
                            ligne(i, c)
                        }
                    }
                    if plusieurs {
                        Section {
                            TextField("Planche (ex. : A)", text: $planche)
                        } footer: {
                            Text("Les cartons ajoutés reçoivent les numéros suivants de la soirée.")
                        }
                    }
                } else {
                    Section {
                        BoutonsPhotoCarton(titreCamera: plusieurs ? "Photographier les cartons" : "Photographier le carton") {
                            photo = $0
                            validees = [:]
                        }
                    } footer: {
                        Text("Photographiez la planche entière ou un carton, à plat et bien éclairé. Une photo de biais est redressée automatiquement.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(plusieurs ? "Cartons en photo" : "Cartons trouvés")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                if plusieurs {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(aAjouter.isEmpty ? "Ajouter" : "Ajouter (\(aAjouter.count))") {
                            let p = planche.trimmingCharacters(in: .whitespaces)
                            terminer(aAjouter, p.isEmpty ? nil : p)
                            dismiss()
                        }
                        .disabled(aAjouter.isEmpty)
                    }
                }
            }
            .sheet(item: $enValidation, onDismiss: {
                // Mode « un seul carton » : on referme tout une fois la vérification terminée.
                if let choisie { terminer([choisie], nil); dismiss() }
            }) { c in
                ValidationLectureView(lecture: c.lecture) { g in
                    if plusieurs { validees[c.id] = g } else { choisie = g }
                }
            }
        }
        .tailleFeuille()
    }

    @ViewBuilder
    private func ligne(_ i: Int, _ c: CartonDetecte) -> some View {
        let grille = validees[c.id]
        Button { enValidation = c } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(decorative: c.image, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Carton \(i + 1)").font(.headline)
                        Text(etat(c.resultat, valide: grille != nil)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: grille != nil ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(grille != nil ? AnyShapeStyle(.green) : AnyShapeStyle(.tertiary))
                }
                if let grille {
                    CartonGrilleView(carton: Carton(id: "", grille: grille), compact: true)
                    if let d = doublon(de: c.id, grille) {
                        Label(d, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func etat(_ r: LectureCarton.Resultat, valide: Bool) -> String {
        if valide { return "Vérifié" }
        let lus = "\(r.numerosLus)/15 lus"
        return r.casesAVerifier == 0 ? "\(lus), à vérifier d'un coup d'œil" : "\(lus) · \(r.casesAVerifier) à vérifier"
    }

    // MARK: - Doublons

    private func cle(_ g: [[Int?]]) -> Set<Int> { Set(g.joined().compactMap { $0 }) }

    /// Raison de ne pas ajouter ce carton (déjà enregistré, ou deux fois sur la photo).
    private func doublon(de id: UUID, _ g: [[Int?]]) -> String? {
        let k = cle(g)
        if let e = existants.first(where: { Set($0.numeros) == k }) {
            return "Identique au \(e.libelle) : il ne sera pas ajouté."
        }
        let ordre = photo?.cartons.map(\.id) ?? []
        let avant = ordre.prefix { $0 != id }
        if avant.contains(where: { validees[$0].map(cle) == k }) {
            return "Même carton qu'un autre de la photo : il ne sera ajouté qu'une fois."
        }
        return nil
    }

    private var grillesAAjouter: [[[Int?]]] {
        (photo?.cartons ?? []).compactMap { c in
            guard let g = validees[c.id], doublon(de: c.id, g) == nil else { return nil }
            return g
        }
    }
}

/// La photo d'origine avec le contour numéroté de chaque carton trouvé.
private struct PhotoCartons: View {
    let photo: PhotoAnalysee
    let validees: Set<UUID>

    var body: some View {
        Image(decorative: photo.image, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    ForEach(Array(photo.cartons.enumerated()), id: \.element.id) { i, c in
                        let pts = c.coins.map { CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height) }
                        let couleur: Color = validees.contains(c.id) ? .green : .orange
                        Path { p in p.addLines(pts); p.closeSubpath() }
                            .stroke(couleur, lineWidth: 3)
                        Text("\(i + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(couleur))
                            .position(x: c.centre.x * geo.size.width, y: c.centre.y * geo.size.height)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
