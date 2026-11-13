// Génère l'icône de l'app (boule de loto) : swift outils/generer_icone.swift <sortie.png>
import AppKit
let taille = 1024.0
let image = NSImage(size: NSSize(width: taille, height: taille))
image.lockFocus()
let fond = NSGradient(starting: NSColor(red: 0.85, green: 0.20, blue: 0.22, alpha: 1),
                      ending: NSColor(red: 0.55, green: 0.08, blue: 0.14, alpha: 1))!
fond.draw(in: NSRect(x: 0, y: 0, width: taille, height: taille), angle: -90)
let boule = NSBezierPath(ovalIn: NSRect(x: 172, y: 172, width: 680, height: 680))
NSColor.white.setFill(); boule.fill()
NSColor(red: 0.95, green: 0.75, blue: 0.20, alpha: 1).setStroke(); boule.lineWidth = 36; boule.stroke()
let style = NSMutableParagraphStyle(); style.alignment = .center
let attributs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 400, weight: .heavy),
    .foregroundColor: NSColor(red: 0.70, green: 0.12, blue: 0.18, alpha: 1),
    .paragraphStyle: style]
("90" as NSString).draw(in: NSRect(x: 0, y: 300, width: taille, height: 460), withAttributes: attributs)
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
