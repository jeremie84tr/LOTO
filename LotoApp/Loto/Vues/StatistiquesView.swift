import SwiftUI
import Charts

struct StatistiquesView: View {
    let titre: String
    let stats: Statistiques

    var body: some View {
        Group {
            if stats.nbParties == 0 {
                ContentUnavailableView("Pas encore de données", systemImage: "chart.bar",
                                       description: Text("Les statistiques apparaîtront après la première partie."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        resume
                        phases
                        frequences
                        numeros
                        dizaines
                        cartons
                        Text("Chaque tirage est indépendant : un numéro « en retard » n'a pas plus de chances de sortir. Ces chiffres décrivent le passé ; les conseils de jeu reposent, eux, sur vos cartons et les numéros restant dans le sac.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: 1000, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(titre)
    }

    // MARK: Sections

    private var resume: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            tuile("Parties", "\(stats.nbParties)")
            tuile("Numéros tirés", "\(stats.nbNumeros)")
            tuile("Par partie", String(format: "%.1f", stats.moyenneParPartie))
            tuile("Moyenne des numéros", String(format: "%.1f", stats.moyenneDesNumeros), detail: "théorie : 45,5")
            tuile("Pairs", Analyse.pourcent(Double(stats.pairs) / Double(max(stats.nbNumeros, 1))))
            tuile("Phases gagnées par nous", "\(stats.victoiresParNous)")
        }
    }

    private func tuile(_ titre: String, _ valeur: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titre).font(.caption).foregroundStyle(.secondary)
            Text(valeur).font(.title2.bold()).monospacedDigit()
            if let detail { Text(detail).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
    }

    @ViewBuilder
    private var phases: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quand tombent les phases").font(.title3.bold())
            if stats.phases.isEmpty {
                Text("Pas encore de phase enregistrée. Validez les quines et cartons pleins pendant les parties pour savoir après combien de numéros ils tombent.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Chart(stats.phases) { p in
                    BarMark(x: .value("Numéros tirés", p.moyenne), y: .value("Phase", p.id))
                        .annotation(position: .trailing) {
                            Text("\(Int(p.moyenne.rounded())) (\(p.minimum)–\(p.maximum))").font(.caption2)
                        }
                }
                .chartXAxisLabel("Nombre moyen de numéros tirés")
                .frame(height: CGFloat(stats.phases.count) * 44 + 40)
                ForEach(stats.phases) { p in
                    Text("\(p.id) : \(p.valeurs.count) fois, gagnée \(p.gagneesParNous) fois par nous.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Barre explicite (début, fin, base) : `width: .ratio` ne marche pas sur un axe numérique continu.
    private func barre(_ n: StatNumero) -> some ChartContent {
        let x = Double(n.numero)
        return RectangleMark(xStart: .value("Numéro", x - 0.4), xEnd: .value("Numéro", x + 0.4),
                             yStart: .value("Sorties", 0.0), yEnd: .value("Sorties", Double(n.sorties)))
            .foregroundStyle(Color.accentColor.gradient)
    }

    private var frequences: some View {
        let moyenne = Double(stats.nbNumeros) / 90
        return VStack(alignment: .leading, spacing: 8) {
            Text("Sorties par numéro").font(.title3.bold())
            Chart {
                ForEach(stats.numeros) { n in barre(n) }
                RuleMark(y: .value("Moyenne", moyenne))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("moyenne").font(.caption2).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: 0...91)
            .chartXAxis { AxisMarks(values: [1, 10, 20, 30, 40, 50, 60, 70, 80, 90]) }
            .frame(height: 200)
        }
    }

    private var numeros: some View {
        VStack(alignment: .leading, spacing: 12) {
            ligneNumeros("Les plus sortis", stats.plusSortis.map { ($0.numero, "\($0.sorties)×") }, .red)
            ligneNumeros("Les moins sortis", stats.moinsSortis.map { ($0.numero, "\($0.sorties)×") }, .blue)
            if stats.nbParties > 1 {
                ligneNumeros("Absents depuis le plus de parties", stats.plusEnRetard.map { ($0.numero, "\($0.retard) p.") }, .gray)
            }
        }
    }

    private func ligneNumeros(_ titre: String, _ items: [(Int, String)], _ couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre).font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.0) { n, legende in
                        VStack(spacing: 2) {
                            BouleView(numero: n, taille: 34, couleur: couleur)
                            Text(legende).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var dizaines: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Répartition par colonne").font(.title3.bold())
            Chart(stats.dizaines) { d in
                BarMark(x: .value("Colonne", d.libelle), y: .value("Part", d.observe))
                    .foregroundStyle(Color.accentColor.gradient)
                PointMark(x: .value("Colonne", d.libelle), y: .value("Attendu", d.attendu))
                    .symbol(.diamond)
                    .foregroundStyle(.orange)
            }
            .chartYAxis { AxisMarks(format: FloatingPointFormatStyle<Double>.Percent().precision(.fractionLength(0))) }
            .frame(height: 180)
            Text("Barres : part réelle des numéros tirés. Losanges : part attendue (la colonne 80-90 a 11 numéros, la 1-9 en a 9).")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var cartons: some View {
        if !stats.cartons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Vos cartons").font(.title3.bold())
                Chart(stats.cartons) { c in
                    BarMark(x: .value("Cases cochées par partie", c.moyenne), y: .value("Carton", c.titre))
                        .annotation(position: .trailing) {
                            Text(String(format: "%.1f", c.moyenne) + (c.victoires > 0 ? " · \(c.victoires) 🏆" : ""))
                                .font(.caption2)
                        }
                }
                .chartXScale(domain: 0...15)
                .frame(height: CGFloat(stats.cartons.count) * 26 + 40)
                Text("Moyenne de cases cochées par partie (sur 15). Un carton n'a pas plus de chances qu'un autre : c'est le hasard des tirages.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
