// Essai de bout en bout du détecteur de cartons (Vision), sans Xcode :
//   ./outils/essai_planche.sh [dossier de sortie]
//
// Dessine une planche de 4 cartons d'exemple, la « photographie » de biais et à l'envers avec un
// léger flou, puis vérifie que chaque carton est retrouvé sans aucun numéro faux.
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

let arguments = CommandLine.arguments
let dec = JSONDecoder()
dec.dateDecodingStrategy = .iso8601
let exemples = try dec.decode([Soiree].self, from: Data(contentsOf: URL(fileURLWithPath: arguments[1])))
let sortie = URL(fileURLWithPath: arguments[2])
let grilles = exemples[0].cartons.prefix(4).map(\.grille)

// MARK: Planche

let W = 2400, H = 1700
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
NSColor(white: 0.35, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

func dessiner(_ g: [[Int?]], x: CGFloat, y: CGFloat, numero: Int, retourne: Bool) {
    let cg = ctx.cgContext
    cg.saveGState()
    let cw: CGFloat = 100, ch: CGFloat = 110, larg = cw * 9 + 40, haut = ch * 3 + 110
    if retourne {
        cg.translateBy(x: x + larg, y: y + haut)
        cg.rotate(by: .pi)
    } else {
        cg.translateBy(x: x, y: y)
    }
    NSColor(calibratedRed: 1, green: 0.97, blue: 0.85, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: larg, height: haut).fill()
    NSColor.black.setStroke()
    let bord = NSBezierPath(rect: NSRect(x: 2, y: 2, width: larg - 4, height: haut - 4))
    bord.lineWidth = 4
    bord.stroke()
    // Le numéro du carton ne doit pas être pris pour un numéro de la grille.
    ("LOTO  N° 00\(numero)" as NSString).draw(at: NSPoint(x: 24, y: haut - 70),
                                              withAttributes: [.font: NSFont.systemFont(ofSize: 34)])
    let police: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 52)]
    for l in 0..<3 {
        for c in 0..<9 {
            let r = NSRect(x: 20 + CGFloat(c) * cw, y: 20 + CGFloat(2 - l) * ch, width: cw, height: ch)
            NSColor.darkGray.setStroke()
            NSBezierPath(rect: r).stroke()
            if let v = g[l][c] {
                let t = "\(v)" as NSString
                let s = t.size(withAttributes: police)
                t.draw(at: NSPoint(x: r.midX - s.width / 2, y: r.midY - s.height / 2), withAttributes: police)
            }
        }
    }
    cg.restoreGState()
}

dessiner(grilles[0], x: 120, y: 900, numero: 1, retourne: false)
dessiner(grilles[1], x: 1260, y: 900, numero: 2, retourne: false)
dessiner(grilles[2], x: 120, y: 300, numero: 3, retourne: false)
dessiner(grilles[3], x: 1260, y: 300, numero: 4, retourne: false)
NSGraphicsContext.current = nil

// Photo prise de biais et à l'envers, un peu floue, en JPEG.
let f = CIFilter.perspectiveTransform()
f.inputImage = CIImage(cgImage: rep.cgImage!).oriented(.down)
f.topLeft = CGPoint(x: 250, y: 1600)
f.topRight = CGPoint(x: 2250, y: 1650)
f.bottomLeft = CGPoint(x: 0, y: 0)
f.bottomRight = CGPoint(x: 2400, y: 120)
let photoCI = f.outputImage!.applyingGaussianBlur(sigma: 1.2).cropped(to: f.outputImage!.extent)
let photoCG = CIContext().createCGImage(photoCI, from: photoCI.extent)!
let jpeg = NSBitmapImageRep(cgImage: photoCG).representation(using: .jpeg, properties: [.compressionFactor: 0.8])!
try jpeg.write(to: sortie.appendingPathComponent("planche.jpg"))

// MARK: Détection

let debut = Date()
let photo = try await DetecteurCartons.analyser(try LecteurVision.image(depuis: jpeg))
let duree = Date().timeIntervalSince(debut)
print("\(photo.cartons.count) carton(s) trouvé(s) en \(String(format: "%.1f", duree)) s")

var echecs = 0
var retrouves = Set<Int>()
for (i, c) in photo.cartons.enumerated() {
    try NSBitmapImageRep(cgImage: c.image).representation(using: .png, properties: [:])!
        .write(to: sortie.appendingPathComponent("carton\(i + 1).png"))
    let lu = c.resultat.cases.map { $0.map(\.valeur) }
    // Le carton d'exemple correspondant : celui qui partage le plus de numéros.
    guard let k = grilles.indices.max(by: { a, b in
        Set(grilles[a].joined().compactMap { $0 }).intersection(lu.joined().compactMap { $0 }).count <
        Set(grilles[b].joined().compactMap { $0 }).intersection(lu.joined().compactMap { $0 }).count
    }) else { continue }
    var faux = 0, manquants = 0
    for l in 0..<3 { for col in 0..<9 {
        if let v = lu[l][col] { if v != grilles[k][l][col] { faux += 1 } } else if grilles[k][l][col] != nil { manquants += 1 }
    }}
    retrouves.insert(k)
    if faux > 0 {
        echecs += 1
        print("  ÉCHEC carton \(i + 1) : \(faux) numéro(s) faux")
    } else {
        print("  ok   carton \(i + 1) = carton d'exemple \(k + 1) : aucun faux, \(manquants) manquant(s), \(c.resultat.casesAVerifier) à vérifier")
    }
}
if !photo.cadresTrouves { echecs += 1; print("  ÉCHEC aucun carton reconnu") }
if retrouves.count != 4 { echecs += 1; print("  ÉCHEC \(retrouves.count) carton(s) sur 4 retrouvé(s)") }
print(echecs == 0 ? "\nLes 4 cartons sont retrouvés, sans numéro faux." : "\n\(echecs) échec(s). Images dans \(sortie.path)")
exit(echecs == 0 ? 0 : 1)
