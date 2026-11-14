// Compose un visuel App Store : fond aux couleurs de l'app, titre, capture dans un cadre d'appareil.
// Usage : swift composer.swift <capture.png> <sortie.png> <largeur> <hauteur> <titre> <sous-titre> <iphone|ipad|paysage|banniere>
// Le PNG produit fait exactement largeur × hauteur pixels, sans canal alpha.
//
// Proportions des cadres (en fraction de la largeur de l'écran), d'après les mesures publiées :
// • iPhone 17 Pro Max : boîtier 78,0 × 163,4 mm (Apple) ; écran 1320 × 2868 px à 460 ppi = 72,9 × 158,4 mm
//   → bordure ≈ 2,55 mm = 3,5 % ; coins de l'écran 62 pt sur 440 pt = 14,1 % ;
//   coins du boîtier = 62 pt + bordure (≈ 15 pt) = 17,5 %. La Dynamic Island est déjà dans la capture.
// • iPad Pro 13 pouces : boîtier 281,6 × 215,5 mm ; écran 2064 × 2752 px à 264 ppi = 198,6 × 264,8 mm
//   → bordure ≈ 8,45 mm = 4,25 % ; coins de l'écran 30 pt sur 1032 pt = 2,9 % ; coins du boîtier ≈ 7,2 %.
import AppKit

let a = CommandLine.arguments
let source = NSImage(contentsOfFile: a[1])!
let sortie = URL(fileURLWithPath: a[2])
let W = Int(a[3])!, H = Int(a[4])!
let titre = a[5], sousTitre = a[6]
let mode = a.count > 7 ? a[7] : "iphone"
let paysage = mode == "paysage" || mode == "banniere"   // bannière : texte en paysage, cadre iPhone
let w = CGFloat(W), h = CGFloat(H)

struct Cadre { let bordure: CGFloat; let rayonEcran: CGFloat; let rayonBoitier: CGFloat }
let cadreAppareil: Cadre? = switch mode {
case "iphone", "banniere": Cadre(bordure: 0.035, rayonEcran: 62.0 / 440, rayonBoitier: (62.0 + 15.4) / 440)
case "ipad":   Cadre(bordure: 0.0425, rayonEcran: 30.0 / 1032, rayonBoitier: (30.0 + 44) / 1032)
default:       nil
}

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// Fond : dégradé rouge de l'icône, quelques boules décoratives.
NSGradient(starting: NSColor(red: 0.86, green: 0.22, blue: 0.24, alpha: 1),
           ending: NSColor(red: 0.50, green: 0.07, blue: 0.13, alpha: 1))!
    .draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: -90)
for (x, y, r) in [(0.08, 0.93, 0.05), (0.93, 0.88, 0.035), (0.88, 0.97, 0.02), (0.04, 0.80, 0.02)] {
    let d = CGFloat(r) * w
    NSColor.white.withAlphaComponent(0.10).setFill()
    NSBezierPath(ovalIn: NSRect(x: CGFloat(x) * w - d / 2, y: CGFloat(y) * h - d / 2, width: d, height: d)).fill()
}

// Textes.
let base = min(w, h * 0.75)
let style = NSMutableParagraphStyle(); style.alignment = .center
let tailleTitre = base * (paysage ? 0.050 : 0.072)
let tailleSous = tailleTitre * 0.52
let attrTitre: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: tailleTitre, weight: .heavy), .foregroundColor: NSColor.white, .paragraphStyle: style]
let attrSous: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: tailleSous, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.88), .paragraphStyle: style]
let marge = w * 0.07
let zone = NSSize(width: w - 2 * marge, height: h)
let hTitre = (titre as NSString).boundingRect(with: zone, options: .usesLineFragmentOrigin, attributes: attrTitre).height
let hSous = (sousTitre as NSString).boundingRect(with: zone, options: .usesLineFragmentOrigin, attributes: attrSous).height
let haut = h - h * (paysage ? 0.06 : 0.045)
(titre as NSString).draw(with: NSRect(x: marge, y: haut - hTitre, width: zone.width, height: hTitre),
                         options: .usesLineFragmentOrigin, attributes: attrTitre)
(sousTitre as NSString).draw(with: NSRect(x: marge, y: haut - hTitre - tailleSous * 0.5 - hSous, width: zone.width, height: hSous),
                             options: .usesLineFragmentOrigin, attributes: attrSous)

// Place disponible pour l'appareil entier, sous le texte.
let basTexte = haut - hTitre - tailleSous * 0.5 - hSous - h * 0.03
let margeBas = h * (paysage ? 0.05 : 0.035)
let dispoH = basTexte - margeBas
let dispoW = w * (paysage ? 0.86 : 0.86)
let ratio = source.size.width / source.size.height

// Taille de l'écran telle que le boîtier entier tienne dans la place disponible.
let b = cadreAppareil?.bordure ?? 0
var ew = dispoW / (1 + 2 * b)
var eh = ew / ratio
if eh + 2 * b * ew > dispoH { ew = dispoH / (1 / ratio + 2 * b); eh = ew / ratio }
let bordure = b * ew
let boitier = NSRect(x: (w - ew - 2 * bordure) / 2, y: margeBas + (dispoH - eh - 2 * bordure) / 2,
                     width: ew + 2 * bordure, height: eh + 2 * bordure)
let ecran = boitier.insetBy(dx: bordure, dy: bordure)

// Ombre portée puis boîtier.
let rayonBoitier = (cadreAppareil?.rayonBoitier ?? 0.012) * ew
NSGraphicsContext.saveGraphicsState()
let ombre = NSShadow()
ombre.shadowColor = NSColor.black.withAlphaComponent(0.45)
ombre.shadowBlurRadius = w * 0.035
ombre.shadowOffset = NSSize(width: 0, height: -w * 0.012)
ombre.set()
NSColor(white: 0.12, alpha: 1).setFill()
NSBezierPath(roundedRect: boitier, xRadius: rayonBoitier, yRadius: rayonBoitier).fill()
NSGraphicsContext.restoreGraphicsState()
if cadreAppareil != nil {
    // Liseré métallique du boîtier.
    let lisere = NSBezierPath(roundedRect: boitier.insetBy(dx: bordure * 0.06, dy: bordure * 0.06),
                              xRadius: rayonBoitier - bordure * 0.06, yRadius: rayonBoitier - bordure * 0.06)
    lisere.lineWidth = bordure * 0.12
    NSColor(white: 0.42, alpha: 1).setStroke()
    lisere.stroke()
}

// Écran.
let rayonEcran = (cadreAppareil?.rayonEcran ?? 0.010) * ew
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: ecran, xRadius: rayonEcran, yRadius: rayonEcran).addClip()
source.draw(in: ecran)
NSGraphicsContext.restoreGraphicsState()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(sortie as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
