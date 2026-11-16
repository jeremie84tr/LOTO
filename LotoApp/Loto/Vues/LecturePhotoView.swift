import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
#endif

extension LectureCarton.Position: Identifiable {
    var id: Int { ligne * 9 + colonne }
}

// MARK: - Prise de la photo

/// Boutons « Photographier » et « Choisir une photo », puis détection et lecture des cartons.
struct BoutonsPhotoCarton: View {
    var titreCamera = "Photographier le carton"
    let lu: (PhotoAnalysee) -> Void

    @State private var element: PhotosPickerItem?
    @State private var cameraOuverte = false
    @State private var enCours = false
    @State private var erreur: String?

    var body: some View {
        if enCours {
            HStack(spacing: 10) {
                ProgressView()
                Text("Recherche et lecture des cartons…").foregroundStyle(.secondary)
            }
        } else {
            #if os(iOS)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button { cameraOuverte = true } label: {
                    Label(titreCamera, systemImage: "camera")
                }
                .fullScreenCover(isPresented: $cameraOuverte) {
                    AppareilPhoto { data in lire(data) }.ignoresSafeArea()
                }
            }
            #endif
            PhotosPicker(selection: $element, matching: .images) {
                Label("Choisir une photo", systemImage: "photo.on.rectangle")
            }
            .onChange(of: element) { _, nouvel in
                guard let nouvel else { return }
                element = nil
                Task {
                    if let data = try? await nouvel.loadTransferable(type: Data.self) {
                        lire(data)
                    } else {
                        erreur = "Impossible de charger cette photo."
                    }
                }
            }
            if let erreur {
                Label(erreur, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout)
            }
        }
    }

    private func lire(_ data: Data) {
        enCours = true
        erreur = nil
        Task {
            defer { enCours = false }
            do {
                let image = try LecteurVision.image(depuis: data)
                lu(try await DetecteurCartons.analyser(image))
            } catch let e as DetecteurCartons.Erreur {
                erreur = e.localizedDescription
            } catch {
                erreur = "Lecture impossible : \(error.localizedDescription)"
            }
        }
    }
}

#if os(iOS)
/// L'appareil photo du système.
struct AppareilPhoto: UIViewControllerRepresentable {
    let prise: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.cameraCaptureMode = .photo
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinateur { Coordinateur(self) }

    final class Coordinateur: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AppareilPhoto
        init(_ parent: AppareilPhoto) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let photo = info[.originalImage] as? UIImage {
                // On redessine la photo à l'endroit pour que les positions lues correspondent à l'affichage.
                let format = UIGraphicsImageRendererFormat()
                format.scale = 1
                let droite = UIGraphicsImageRenderer(size: photo.size, format: format).image { _ in
                    photo.draw(in: CGRect(origin: .zero, size: photo.size))
                }
                if let data = droite.jpegData(compressionQuality: 0.9) { parent.prise(data) }
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif

// MARK: - Vérification

/// Vérification obligatoire des numéros lus avant de les reporter sur le carton.
///
/// Chaque case douteuse doit être confirmée ou corrigée une à une (avec un zoom sur la photo),
/// la grille doit former un carton possible, et l'utilisateur doit attester l'avoir comparée
/// au carton papier.
struct ValidationLectureView: View {
    typealias Position = LectureCarton.Position

    @Environment(\.dismiss) private var dismiss
    let lecture: LecturePhoto
    let utiliser: ([[Int?]]) -> Void

    @State private var cases: [[CaseLue]]
    @State private var confirmees: Set<Position> = []
    @State private var edition: Position?
    @State private var comparee = false

    init(lecture: LecturePhoto, utiliser: @escaping ([[Int?]]) -> Void) {
        self.lecture = lecture
        self.utiliser = utiliser
        _cases = State(initialValue: lecture.resultat.cases)
    }

    private var grille: [[Int?]] { cases.map { $0.map(\.valeur) } }

    private func doutes(_ p: Position) -> [String] { cases[p.ligne][p.colonne].doutes }

    private var aVerifier: [Position] {
        (0..<3).flatMap { l in (0..<9).map { Position(ligne: l, colonne: $0) } }
            .filter { !confirmees.contains($0) && !doutes($0).isEmpty }
    }

    var body: some View {
        let enAttente = aVerifier
        let bloquantes = LectureCarton.erreursBloquantes(grille)
        let pret = enAttente.isEmpty && bloquantes.isEmpty && comparee

        return NavigationStack {
            Form {
                Section {
                    PhotoAnnotee(image: lecture.image, cases: cases, aVerifier: Set(enAttente), selection: edition)
                        .frame(maxHeight: 260)
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Vert : lu sans hésitation. Orange : à vérifier.")
                }

                Section {
                    grilleEditable(aVerifier: Set(enAttente))
                } header: {
                    Text("Numéros lus")
                } footer: {
                    Text("Touchez une case pour la corriger, la vider ou ajouter un numéro manquant.")
                }

                if !lecture.resultat.remarques.isEmpty {
                    Section("Remarques") {
                        ForEach(lecture.resultat.remarques, id: \.self) { r in
                            Label(r, systemImage: "info.circle").font(.callout)
                        }
                    }
                }

                if !enAttente.isEmpty {
                    Section {
                        ForEach(enAttente) { p in
                            Button { edition = p } label: {
                                HStack(alignment: .top) {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(titre(p)).font(.headline)
                                        ForEach(doutes(p), id: \.self) { Text($0).font(.caption) }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("À vérifier (\(enAttente.count))")
                    } footer: {
                        Text("Confirmez ou corrigez chacun de ces numéros en le comparant au carton.")
                    }
                }

                Section {
                    ForEach(bloquantes, id: \.self) { e in
                        Label(e, systemImage: "xmark.octagon").foregroundStyle(.red).font(.callout)
                    }
                    Toggle("J'ai comparé chaque numéro avec mon carton", isOn: $comparee)
                } footer: {
                    Text("La lecture automatique peut se tromper (6 et 8, 1 et 7…). Un numéro faux fausserait toutes les alertes de la partie.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Vérifier la lecture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Utiliser") {
                        utiliser(grille)
                        dismiss()
                    }
                    .disabled(!pret)
                }
            }
            .sheet(item: $edition) { p in
                EditeurCaseLue(image: lecture.image, position: p, case_: cases[p.ligne][p.colonne],
                               doutes: doutes(p)) { valeur in
                    cases[p.ligne][p.colonne].valeur = valeur
                    confirmees.insert(p)
                    comparee = false // la grille a changé : il faut la revoir
                }
            }
        }
        .tailleFeuille()
    }

    private func titre(_ p: Position) -> String {
        let v = cases[p.ligne][p.colonne].valeur.map { "le \($0)" } ?? "case vide"
        return "Ligne \(p.ligne + 1), colonne \(LectureCarton.libelleColonne(p.colonne)) : \(v)"
    }

    private func grilleEditable(aVerifier: Set<Position>) -> some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            ForEach(0..<3, id: \.self) { l in
                GridRow {
                    ForEach(0..<9, id: \.self) { c in
                        let p = Position(ligne: l, colonne: c)
                        let v = cases[l][c].valeur
                        let douteuse = aVerifier.contains(p)
                        Button { edition = p } label: {
                            Text(v.map(String.init) ?? "")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, minHeight: 32)
                                .background(RoundedRectangle(cornerRadius: 4).fill(
                                    douteuse ? Color.orange.opacity(0.3)
                                    : v == nil ? Color.gray.opacity(0.05)
                                    : confirmees.contains(p) ? Color.green.opacity(0.25) : Color.gray.opacity(0.15)))
                                .overlay(RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(douteuse ? Color.orange : .clear, lineWidth: 2))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(v.map { "Numéro \($0)\(douteuse ? ", à vérifier" : "")" } ?? "Case vide")
                    }
                }
            }
        }
        .padding(3)
    }
}

/// La photo avec un cadre autour de chaque numéro lu.
private struct PhotoAnnotee: View {
    let image: CGImage
    let cases: [[CaseLue]]
    let aVerifier: Set<LectureCarton.Position>
    let selection: LectureCarton.Position?

    var body: some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { geo in
                    ForEach(0..<3, id: \.self) { l in
                        ForEach(0..<9, id: \.self) { c in
                            if let cadre = cases[l][c].cadre {
                                let p = LectureCarton.Position(ligne: l, colonne: c)
                                let couleur: Color = aVerifier.contains(p) ? .orange : .green
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(couleur, lineWidth: p == selection ? 4 : 2)
                                    .frame(width: cadre.width * geo.size.width + 6, height: cadre.height * geo.size.height + 6)
                                    .position(x: cadre.midX * geo.size.width, y: cadre.midY * geo.size.height)
                            }
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// Confirmation ou correction d'une case, avec un zoom sur la photo.
private struct EditeurCaseLue: View {
    @Environment(\.dismiss) private var dismiss
    let image: CGImage
    let position: LectureCarton.Position
    let case_: CaseLue
    let doutes: [String]
    let enregistrer: (Int?) -> Void

    @State private var texte: String

    init(image: CGImage, position: LectureCarton.Position, case_: CaseLue, doutes: [String],
         enregistrer: @escaping (Int?) -> Void) {
        self.image = image
        self.position = position
        self.case_ = case_
        self.doutes = doutes
        self.enregistrer = enregistrer
        _texte = State(initialValue: case_.valeur.map(String.init) ?? "")
    }

    private var plage: String { LectureCarton.libelleColonne(position.colonne) }

    /// nil si la saisie est vide ; sinon le numéro s'il est valable pour cette colonne.
    private var saisie: (valeur: Int?, erreur: String?) {
        let t = texte.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return (nil, nil) }
        guard let n = Int(t), (1...90).contains(n) else { return (nil, "Tapez un numéro entre 1 et 90.") }
        guard Carton.colonne(pour: n) == position.colonne else {
            return (nil, "Cette colonne contient les numéros \(plage) : le \(n) va dans la colonne \(LectureCarton.libelleColonne(Carton.colonne(pour: n))).")
        }
        return (n, nil)
    }

    var body: some View {
        let s = saisie
        NavigationStack {
            Form {
                if let zoom = zoom() {
                    Section {
                        Image(decorative: zoom, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 140)
                            .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Comparez avec le carton papier plutôt qu'avec la photo en cas de doute.")
                    }
                }
                if !doutes.isEmpty {
                    Section {
                        ForEach(doutes, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.callout) }
                    }
                }
                Section {
                    TextField("Numéro (\(plage))", text: $texte)
                        .font(.title2.monospacedDigit())
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    let suggestions = case_.alternatives.filter { Carton.colonne(pour: $0) == position.colonne && String($0) != texte }
                    if !suggestions.isEmpty {
                        HStack {
                            Text("Lu aussi :").foregroundStyle(.secondary)
                            ForEach(suggestions, id: \.self) { n in
                                Button("\(n)") { texte = String(n) }.buttonStyle(.bordered)
                            }
                        }
                    }
                    if let e = s.erreur {
                        Label(e, systemImage: "xmark.octagon").foregroundStyle(.red).font(.callout)
                    }
                } header: {
                    Text("Ligne \(position.ligne + 1), colonne \(plage)")
                } footer: {
                    Text("Laissez vide si cette case est vide sur le carton.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(case_.valeur == nil ? "Case vide" : "Vérifier le \(case_.valeur!)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(boutonValider(s.valeur)) {
                        enregistrer(s.valeur)
                        dismiss()
                    }
                    .disabled(s.erreur != nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tailleFeuille()
    }

    private func boutonValider(_ v: Int?) -> String {
        if v == case_.valeur { return v == nil ? "Confirmer vide" : "Confirmer le \(v!)" }
        return "Corriger"
    }

    /// Le morceau de photo autour du numéro lu.
    private func zoom() -> CGImage? {
        guard let c = case_.cadre else { return nil }
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let marge = c.height * h * 1.2 // en pixels, identique dans les deux sens
        let zone = CGRect(x: c.minX * w - marge, y: c.minY * h - marge,
                          width: c.width * w + 2 * marge, height: c.height * h + 2 * marge)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        return zone.isEmpty ? nil : image.cropping(to: zone.integral)
    }
}
