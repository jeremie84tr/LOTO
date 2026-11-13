import Foundation
import Observation

/// Données de l'app, enregistrées en JSON après chaque modification.
@MainActor @Observable
final class Magasin {
    var soirees: [Soiree] = [] {
        didSet { sauvegarder() }
    }
    var erreur: String?

    @ObservationIgnored private let fichier: URL
    @ObservationIgnored private var lectureSeule = false

    init(fichier: URL? = nil) {
        if let fichier {
            self.fichier = fichier
        } else {
            let dossier = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Loto", isDirectory: true)
            try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
            self.fichier = dossier.appendingPathComponent("loto.json")
        }
        charger()
    }

    // MARK: Fichiers

    static func encodeur() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func decodeur() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    private func charger() {
        guard let data = try? Data(contentsOf: fichier) else {
            soirees = Self.historiqueEmbarque()
            return
        }
        do {
            soirees = try Self.decodeur().decode([Soiree].self, from: data)
        } catch {
            // On garde une copie plutôt que d'écraser des données illisibles.
            let copie = fichier.deletingPathExtension().appendingPathExtension("illisible.json")
            try? FileManager.default.removeItem(at: copie)
            try? FileManager.default.copyItem(at: fichier, to: copie)
            erreur = "Impossible de lire les données (\(error.localizedDescription)). Une copie a été gardée : \(copie.lastPathComponent)."
        }
    }

    private func sauvegarder() {
        guard !lectureSeule else { return }
        do {
            try Self.encodeur().encode(soirees).write(to: fichier, options: .atomic)
        } catch {
            erreur = "Enregistrement impossible : \(error.localizedDescription)"
        }
    }

    static func historiqueEmbarque() -> [Soiree] {
        guard let url = Bundle.main.url(forResource: "historique_orange", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decodeur().decode([Soiree].self, from: data)) ?? []
    }

    func exporter() throws -> Data { try Self.encodeur().encode(soirees) }

    /// Importe un fichier JSON (une liste de soirées ou une seule). Les soirées déjà présentes sont remplacées.
    @discardableResult
    func importer(_ data: Data) throws -> Int {
        let nouvelles: [Soiree]
        if let liste = try? Self.decodeur().decode([Soiree].self, from: data) {
            nouvelles = liste
        } else {
            nouvelles = [try Self.decodeur().decode(Soiree.self, from: data)]
        }
        var copie = soirees
        for s in nouvelles {
            if let i = copie.firstIndex(where: { $0.id == s.id }) { copie[i] = s } else { copie.append(s) }
        }
        soirees = copie
        return nouvelles.count
    }

    func rechargerHistorique() {
        var copie = soirees
        for s in Self.historiqueEmbarque() {
            if let i = copie.firstIndex(where: { $0.id == s.id }) { copie[i] = s } else { copie.append(s) }
        }
        soirees = copie
    }

    // MARK: Accès

    func soiree(_ id: UUID) -> Soiree? { soirees.first { $0.id == id } }

    func modifierSoiree(_ id: UUID, _ f: (inout Soiree) -> Void) {
        guard let i = soirees.firstIndex(where: { $0.id == id }) else { return }
        f(&soirees[i])
    }

    func modifierPartie(_ soireeID: UUID, _ partieID: UUID, _ f: (inout Partie) -> Void) {
        modifierSoiree(soireeID) { s in
            guard let j = s.parties.firstIndex(where: { $0.id == partieID }) else { return }
            f(&s.parties[j])
        }
    }

    var statistiquesGlobales: Statistiques { Statistiques(parties: PartieJouee.depuis(soirees)) }

    // MARK: Soirées

    @discardableResult
    func ajouterSoiree(lieu: String, date: Date, deroulement: [TypePhase], cartonsDe source: UUID?) -> UUID {
        let cartons = source.flatMap { soiree($0)?.cartons } ?? []
        let s = Soiree(lieu: lieu, date: date, cartons: cartons, deroulement: deroulement)
        soirees.append(s)
        return s.id
    }

    func supprimerSoiree(_ id: UUID) { soirees.removeAll { $0.id == id } }

    // MARK: Cartons

    func enregistrerCarton(_ carton: Carton, ancienID: String?, dans soireeID: UUID) {
        modifierSoiree(soireeID) { s in
            if let ancienID, let i = s.cartons.firstIndex(where: { $0.id == ancienID }) {
                s.cartons[i] = carton
            } else {
                s.cartons.append(carton)
            }
        }
    }

    func supprimerCarton(_ id: String, dans soireeID: UUID) {
        modifierSoiree(soireeID) { $0.cartons.removeAll { $0.id == id } }
    }

    // MARK: Parties

    @discardableResult
    func nouvellePartie(dans soireeID: UUID, deroulement: [TypePhase]) -> UUID? {
        var id: UUID?
        modifierSoiree(soireeID) { s in
            let p = Partie(numero: s.prochainNumeroDePartie, deroulement: deroulement)
            s.parties.append(p)
            id = p.id
        }
        return id
    }

    func supprimerPartie(_ partieID: UUID, dans soireeID: UUID) {
        modifierSoiree(soireeID) { $0.parties.removeAll { $0.id == partieID } }
    }

    enum ResultatTirage: Equatable { case ok, horsLimites, dejaTire }

    @discardableResult
    func tirer(_ n: Int, soiree: UUID, partie: UUID) -> ResultatTirage {
        guard (1...90).contains(n) else { return .horsLimites }
        var resultat = ResultatTirage.ok
        modifierPartie(soiree, partie) { p in
            if p.tirage.contains(n) { resultat = .dejaTire } else { p.tirage.append(n) }
        }
        return resultat
    }

    func retirer(_ n: Int, soiree: UUID, partie: UUID) {
        modifierPartie(soiree, partie) { p in
            p.tirage.removeAll { $0 == n }
            // Une phase gagnée « après » plus de numéros qu'il n'en reste n'a plus de sens : on la rouvre.
            for i in p.phases.indices where (p.phases[i].gagneeApres ?? 0) > p.tirage.count {
                p.phases[i].gagneeApres = nil
                p.phases[i].gagnant = nil
            }
        }
    }

    func annulerDernier(soiree: UUID, partie: UUID) {
        guard let dernier = self.soiree(soiree)?.parties.first(where: { $0.id == partie })?.tirage.last else { return }
        retirer(dernier, soiree: soiree, partie: partie)
    }

    func terminerPhase(soiree: UUID, partie: UUID, gagnant: Gagnant, lot: String) {
        modifierPartie(soiree, partie) { p in
            guard let i = p.indexPhaseCourante else { return }
            p.phases[i].gagneeApres = p.tirage.count
            p.phases[i].gagnant = gagnant
            if !lot.isEmpty { p.phases[i].lot = lot }
        }
    }

    func rouvrirDernierePhase(soiree: UUID, partie: UUID) {
        modifierPartie(soiree, partie) { p in
            guard let i = p.phases.lastIndex(where: { $0.estTerminee }) else { return }
            p.phases[i].gagneeApres = nil
            p.phases[i].gagnant = nil
        }
    }
}
