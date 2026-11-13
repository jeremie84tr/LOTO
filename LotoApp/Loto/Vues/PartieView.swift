import SwiftUI

/// Suivi en direct d'une partie : saisie des numéros, phase en cours, conseils, cartons.
struct PartieView: View {
    @Environment(Magasin.self) private var magasin
    let soireeID: UUID
    let partieID: UUID

    @State private var saisie = ""
    @State private var message: String?
    @State private var feuillePhase = false
    @State private var feuilleDeroulement = false
    @State private var simulation: Simulation?
    @AppStorage("annonceVocale") private var annonceVocale = false
    @FocusState private var saisieActive: Bool

    var body: some View {
        if let soiree = magasin.soiree(soireeID),
           let partie = soiree.parties.first(where: { $0.id == partieID }) {
            contenu(soiree: soiree, partie: partie)
        } else {
            ContentUnavailableView("Partie introuvable", systemImage: "questionmark.circle")
        }
    }

    // MARK: Mise en page

    @ViewBuilder
    private func contenu(soiree: Soiree, partie: Partie) -> some View {
        let etat = Analyse.etat(partie: partie, cartons: soiree.cartons)
        let moyenne = etat.nomPhase.flatMap { magasin.statistiquesGlobales.moyenne(phase: $0) }
        let conseils = Analyse.conseils(etat: etat, simulation: simulation, moyenneHistorique: moyenne)

        GeometryReader { geo in
            if geo.size.width >= 820 {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            bandeauPhases(partie)
                            saisieView(partie)
                            tableau(partie, etat: etat)
                        }
                        .padding()
                    }
                    .frame(width: min(480, geo.size.width * 0.45))
                    Divider()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            alerte(etat: etat, partie: partie)
                            conseilsView(conseils)
                            cartonsView(partie, etat: etat)
                        }
                        .padding()
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        bandeauPhases(partie)
                        alerte(etat: etat, partie: partie)
                        saisieView(partie)
                        conseilsView(conseils)
                        tableau(partie, etat: etat)
                        cartonsView(partie, etat: etat)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Partie \(partie.numero)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { feuilleDeroulement = true } label: { Label("Modifier l'ordre des phases", systemImage: "list.number") }
                    Button { magasin.rouvrirDernierePhase(soiree: soireeID, partie: partieID) } label: {
                        Label("Rouvrir la dernière phase gagnée", systemImage: "arrow.uturn.backward.circle")
                    }
                    .disabled(!partie.phases.contains { $0.estTerminee })
                    Toggle(isOn: $annonceVocale) { Label("Annonces vocales", systemImage: "speaker.wave.2") }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $feuillePhase) {
            if let i = etat.phaseIndex {
                TerminerPhaseSheet(nomPhase: partie.nomPhase(i), nbTires: partie.tirage.count,
                                   cartons: soiree.cartons, objectifs: etat.objectifs) { gagnant, lot in
                    magasin.terminerPhase(soiree: soireeID, partie: partieID, gagnant: gagnant, lot: lot)
                }
            }
        }
        .sheet(isPresented: $feuilleDeroulement) {
            DeroulementSheet(titre: "Ordre des phases", bouton: "Appliquer", phases: partie.deroulement) { nouveau in
                magasin.modifierPartie(soireeID, partieID) { $0.changerDeroulement(nouveau) }
            }
        }
        .task(id: "\(partie.tirage.count)-\(etat.phaseIndex ?? -1)-\(soiree.cartons.count)") {
            simulation = nil
            let p = partie, c = soiree.cartons
            simulation = await Task.detached(priority: .utility) { Analyse.simulation(partie: p, cartons: c) }.value
        }
        .sensoryFeedback(.success, trigger: etat.gagnes.count) { avant, apres in apres > avant }
        .sensoryFeedback(.impact(weight: .light), trigger: partie.tirage.count) { avant, apres in apres > avant }
        .onChange(of: partie.tirage.count) { avant, apres in
            guard apres > avant, annonceVocale else { return }
            annoncer(etat: etat)
        }
        #if os(macOS)
        .onAppear { saisieActive = true }
        #endif
    }

    // MARK: Phases

    private func bandeauPhases(_ partie: Partie) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(partie.phases.enumerated()), id: \.element.id) { i, phase in
                        let courante = i == partie.indexPhaseCourante
                        VStack(alignment: .leading, spacing: 2) {
                            Label(partie.nomPhase(i),
                                  systemImage: phase.estTerminee ? "checkmark.circle.fill" : (courante ? "play.circle.fill" : "circle"))
                                .font(.subheadline.weight(courante ? .bold : .regular))
                            if let n = phase.gagneeApres {
                                Text("\(n) n° · \(phase.gagnant?.parNous == true ? "gagnée par nous 🎉" : "autre joueur")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            } else if courante {
                                Text("en jeu").font(.caption2).foregroundStyle(phase.type.couleur)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(courante ? phase.type.couleur.opacity(0.18) : Color.gray.opacity(0.1)))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(courante ? phase.type.couleur : .clear, lineWidth: 1.5))
                    }
                }
            }
            if let i = partie.indexPhaseCourante {
                Button { feuillePhase = true } label: {
                    Label("\(partie.nomPhase(i)) gagnée…", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(partie.phases[i].type.couleur)
            } else if !partie.importee {
                Label("Partie terminée", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func alerte(etat: EtatPartie, partie: Partie) -> some View {
        if let nom = etat.nomPhase, !etat.gagnes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(nom.uppercased()) !").font(.largeTitle.bold())
                Text("Sur le \(etat.gagnes.map(\.carton.libelle).joined(separator: " et le ")). Criez-le !")
                    .font(.headline)
                Button { feuillePhase = true } label: {
                    Label("Valider la victoire", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.green)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.gradient))
        }
    }

    // MARK: Saisie

    private func saisieView(_ partie: Partie) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Numéro tiré", text: $saisie)
                    .textFieldStyle(.roundedBorder)
                    .focused($saisieActive)
                    .onSubmit(valider)
                    #if os(iOS)
                    .keyboardType(.numbersAndPunctuation)
                    .autocorrectionDisabled()
                    #endif
                    .frame(maxWidth: 160)
                Button("Ajouter", action: valider)
                    .buttonStyle(.borderedProminent)
                    .disabled(saisie.trimmingCharacters(in: .whitespaces).isEmpty)
                Spacer()
                Button { magasin.annulerDernier(soiree: soireeID, partie: partieID) } label: {
                    Label("Annuler le dernier", systemImage: "arrow.uturn.backward")
                }
                .disabled(partie.tirage.isEmpty)
                .labelStyle(.iconOnly)
                .help("Retirer le dernier numéro saisi")
            }
            if let message {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            HStack(spacing: 6) {
                ForEach(Array(partie.tirage.suffix(8).reversed().enumerated()), id: \.element) { i, n in
                    BouleView(numero: n, taille: i == 0 ? 52 : 34, couleur: i == 0 ? .red : .accentColor)
                        .opacity(i == 0 ? 1 : 0.85)
                }
                if partie.tirage.isEmpty {
                    Text("Aucun numéro tiré pour l'instant.").foregroundStyle(.secondary)
                }
            }
            Text("\(partie.tirage.count) numéro\(partie.tirage.count > 1 ? "s" : "") tiré\(partie.tirage.count > 1 ? "s" : "") · \(90 - partie.tirage.count) dans le sac")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func valider() {
        let nums = Carton.extraireNumeros(saisie)
        var erreurs: [String] = []
        for n in nums {
            switch magasin.tirer(n, soiree: soireeID, partie: partieID) {
            case .ok: break
            case .dejaTire: erreurs.append("\(n) déjà tiré")
            case .horsLimites: erreurs.append("\(n) hors 1-90")
            }
        }
        message = erreurs.isEmpty ? nil : erreurs.joined(separator: " · ")
        saisie = ""
    }

    private func tableau(_ partie: Partie, etat: EtatPartie) -> some View {
        let tires = partie.tires
        let gagnants = Set(etat.numerosGagnants)
        let surveilles = etat.numerosSurveilles
        return VStack(alignment: .leading, spacing: 6) {
            Text("Tableau").font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 10), spacing: 3) {
                ForEach(1...90, id: \.self) { n in
                    let tire = tires.contains(n)
                    Button {
                        if !tire { magasin.tirer(n, soiree: soireeID, partie: partieID); message = nil }
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 14, weight: tire ? .bold : .regular, design: .rounded))
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .foregroundStyle(tire ? Color.white : Color.primary)
                            .background(RoundedRectangle(cornerRadius: 6)
                                .fill(tire ? (n == partie.tirage.last ? Color.red : Color.accentColor) : Color.gray.opacity(0.12)))
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(gagnants.contains(n) ? Color.orange : (surveilles.contains(n) ? Color.orange.opacity(0.5) : .clear),
                                              lineWidth: gagnants.contains(n) ? 2.5 : 1.5))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if tire {
                            Button(role: .destructive) { magasin.retirer(n, soiree: soireeID, partie: partieID) } label: {
                                Label("Retirer le \(n)", systemImage: "minus.circle")
                            }
                        }
                    }
                }
            }
            Text("Touchez un numéro pour le cocher, appui long (ou clic droit) pour le retirer. Entourés en orange : les numéros qui vous font gagner.")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Conseils & cartons

    private func conseilsView(_ conseils: [Conseil]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Conseils").font(.headline)
            ForEach(conseils) { c in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: c.niveau.icone).foregroundStyle(c.niveau.couleur).frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.texte)
                            .font(c.niveau == .info ? .callout : .callout.weight(.semibold))
                        if let d = c.detail {
                            Text(d).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(c.niveau == .info ? Color.gray.opacity(0.08) : c.niveau.couleur.opacity(0.12)))
            }
        }
    }

    private func cartonsView(_ partie: Partie, etat: EtatPartie) -> some View {
        let soiree = magasin.soiree(soireeID)
        let tires = partie.tires
        let objectifs = Dictionary(uniqueKeysWithValues: etat.objectifs.map { ($0.carton.id, $0) })
        let ordre = etat.objectifs.map(\.carton) + (soiree?.cartons ?? []).filter { objectifs[$0.id] == nil }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Vos cartons (\(ordre.count))").font(.headline)
            if ordre.isEmpty {
                Text("Aucun carton : ajoutez-les depuis la page de la soirée.").foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(ordre) { c in
                    let o = objectifs[c.id]
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(c.titre).font(.subheadline.bold())
                            Spacer()
                            if let o, let type = etat.type {
                                Text(o.reste == 0 ? "Gagné !" : "manque \(o.reste)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(o.reste == 0 ? Color.green : (o.reste == 1 ? Color.red : type.couleur.opacity(0.7))))
                                    .foregroundStyle(.white)
                            }
                        }
                        CartonGrilleView(carton: c, tires: tires,
                                         manquants: Set(o?.manquants ?? []),
                                         gagnants: Set(o?.gagnants ?? []),
                                         dernier: partie.tirage.last, compact: true)
                        Text("\(c.numeros.filter { tires.contains($0) }.count)/15 cochés")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func annoncer(etat: EtatPartie) {
        guard let type = etat.type else { return }
        if let g = etat.gagnes.first {
            Annonceur.partage.dire("\(type.nom) sur le carton \(g.carton.id) ! Criez !")
        } else if let o = etat.objectifs.first(where: { $0.reste == 1 }) {
            Annonceur.partage.dire("Plus qu'un numéro pour \(type.avecArticle) : le \(Analyse.liste(o.gagnants, "ou le")).")
        }
    }
}

// MARK: - Fin de phase

struct TerminerPhaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let nomPhase: String
    let nbTires: Int
    let cartons: [Carton]
    let objectifs: [Objectif]
    let valider: (Gagnant, String) -> Void

    @State private var parNous: Bool
    @State private var cartonID: String?
    @State private var lot = ""

    init(nomPhase: String, nbTires: Int, cartons: [Carton], objectifs: [Objectif],
         valider: @escaping (Gagnant, String) -> Void) {
        self.nomPhase = nomPhase
        self.nbTires = nbTires
        self.cartons = cartons
        self.objectifs = objectifs
        self.valider = valider
        let gagnes = objectifs.filter { $0.reste == 0 }
        _parNous = State(initialValue: !gagnes.isEmpty)
        _cartonID = State(initialValue: gagnes.first?.carton.id ?? cartons.first?.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Gagnée par", selection: $parNous) {
                        Text("Un autre joueur").tag(false)
                        Text("Nous !").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if parNous {
                        Picker("Carton", selection: $cartonID) {
                            ForEach(cartons) { c in
                                let ok = objectifs.first { $0.carton.id == c.id }?.reste == 0
                                Text(c.titre + (ok ? "  ✓" : "")).tag(Optional(c.id))
                            }
                        }
                    }
                } footer: {
                    Text("Phase tombée après \(nbTires) numéros.")
                }
                Section("Lot (facultatif)") {
                    TextField("Ex. : bon d'achat 50 €", text: $lot)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("\(nomPhase) gagnée")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        let lignes = parNous ? (objectifs.first { $0.carton.id == cartonID && $0.reste == 0 }?.lignes ?? []) : []
                        valider(Gagnant(parNous: parNous, cartonID: parNous ? cartonID : nil, lignes: lignes), lot)
                        dismiss()
                    }
                    .disabled(parNous && cartonID == nil)
                }
            }
        }
        .tailleFeuille()
    }
}
