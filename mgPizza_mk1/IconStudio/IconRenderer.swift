//
//  IconRenderer.swift
//  mgPizza_mk1
//
//  Rechnet aus einem Foto das App-Symbol: Gesicht finden (Vision), Ausschnitt wählen, Comic-Filter (Core Image),
//  Person freistellen, Hintergrund, Schnurrbart und Kochmütze zeichnen. Läuft im Hintergrund (nonisolated).
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit
import CoreVideo
import Foundation
import Vision

nonisolated enum IconRenderer {
    static let size: CGFloat = 1024

    enum Look: String, CaseIterable, Identifiable, Sendable {
        case cartoon, comic, poster
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .cartoon: "Cartoon"
            case .comic: "Comic (halftone)"
            case .poster: "Pop art"
            }
        }
    }

    enum Background: String, CaseIterable, Identifiable, Sendable {
        case tricolore, tomato, basil, cream
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .tricolore: "Italian flag"
            case .tomato: "Tomato red"
            case .basil: "Basil green"
            case .cream: "Mozzarella"
            }
        }
    }

    enum Mustache: String, CaseIterable, Identifiable, Sendable {
        case handlebar, chevron, curly
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .handlebar: "Handlebar"
            case .chevron: "Bushy"
            case .curly: "Extra curly"
            }
        }
    }

    enum HairColor: String, CaseIterable, Identifiable, Sendable {
        case black, brown, ginger, grey
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .black: "Black"
            case .brown: "Dark brown"
            case .ginger: "Ginger"
            case .grey: "Grey"
            }
        }
        var uiColor: UIColor {
            switch self {
            case .black: UIColor(red: 0.10, green: 0.08, blue: 0.07, alpha: 1)
            case .brown: UIColor(red: 0.30, green: 0.18, blue: 0.10, alpha: 1)
            case .ginger: UIColor(red: 0.72, green: 0.36, blue: 0.14, alpha: 1)
            case .grey: UIColor(red: 0.62, green: 0.62, blue: 0.62, alpha: 1)
            }
        }
    }

    struct Options: Equatable, Sendable {
        var look: Look = .cartoon
        var background: Background = .tricolore
        var mustache: Mustache = .handlebar
        var mustacheColor: HairColor = .black
        var chefHat = true
        var cutOut = true
        var mustacheScale = 1.0
        var mustacheOffsetX = 0.0
        var mustacheOffsetY = 0.0
        var zoom = 1.0
    }

    struct Output: Sendable {
        var image: UIImage
        var foundFace: Bool
    }

    /// Gefundenes Gesicht in Bildpunkten (Ursprung unten links, wie Core Image und Vision)
    private struct Face {
        var box: CGRect
        var mouthCenter: CGPoint
        var mouthWidth: CGFloat
        var noseBottom: CGFloat     // y-Wert der Nasenunterkante
        var upperLipTop: CGFloat    // y-Wert der Oberlippe
        var angle: CGFloat          // Neigung des Kopfes (Radiant)
    }

    nonisolated(unsafe) private static let context = CIContext()

    static func render(_ photo: UIImage, options: Options) -> Output? {
        guard let upright = normalized(photo) else { return nil }
        let imageSize = CGSize(width: upright.width, height: upright.height)
        let detected = detectFace(in: upright)
        let face = detected ?? fallbackFace(in: imageSize)

        // Quadratischer Ausschnitt um das Gesicht, mit Platz für die Mütze nach oben
        let side = face.box.height * (options.chefHat ? 2.7 : 2.1) / options.zoom
        let centerY = face.box.midY + face.box.height * (options.chefHat ? 0.42 : 0.08)
        let crop = CGRect(x: face.box.midX - side / 2, y: centerY - side / 2, width: side, height: side)
        let scale = size / side

        // Ausschnitt auf 1024 × 1024 bringen (außerhalb des Fotos bleibt es durchsichtig)
        let source = CIImage(cgImage: upright)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY).concatenating(CGAffineTransform(scaleX: scale, y: scale)))
            .cropped(to: CGRect(x: 0, y: 0, width: size, height: size))

        var styled = stylize(source, look: options.look)
        if options.cutOut, let mask = personMask(for: source) {
            let blend = CIFilter.blendWithMask()
            blend.inputImage = styled
            blend.backgroundImage = CIImage.empty()
            blend.maskImage = mask
            if let output = blend.outputImage { styled = output }
        }
        guard let person = context.createCGImage(styled, from: CGRect(x: 0, y: 0, width: size, height: size)) else { return nil }

        // Gesichtspunkte in Leinwand-Koordinaten (Ursprung oben links, für UIKit)
        func canvas(_ point: CGPoint) -> CGPoint {
            CGPoint(x: (point.x - crop.minX) * scale, y: size - (point.y - crop.minY) * scale)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { renderer in
            let cg = renderer.cgContext
            drawBackground(options.background, in: cg)
            // CGImage steht in UIKit-Koordinaten auf dem Kopf: kurz spiegeln
            cg.saveGState()
            cg.translateBy(x: 0, y: size)
            cg.scaleBy(x: 1, y: -1)
            cg.draw(person, in: CGRect(x: 0, y: 0, width: size, height: size))
            cg.restoreGState()

            // Schnurrbart zwischen Nase und Oberlippe
            let lipTop = canvas(CGPoint(x: face.mouthCenter.x, y: face.upperLipTop)).y
            let noseBottom = canvas(CGPoint(x: face.mouthCenter.x, y: face.noseBottom)).y
            let mouth = canvas(face.mouthCenter)
            let gap = max(lipTop - noseBottom, face.box.height * scale * 0.04)
            let width = face.mouthWidth * scale * 1.75 * options.mustacheScale
            let anchor = CGPoint(x: mouth.x + options.mustacheOffsetX * width,
                                 y: noseBottom + gap * 0.15 + options.mustacheOffsetY * width * 0.4)
            drawMustache(options.mustache, color: options.mustacheColor.uiColor, at: anchor, width: width,
                         angle: -face.angle, in: cg)

            if options.chefHat {
                let top = canvas(CGPoint(x: face.box.midX, y: face.box.maxY))
                drawChefHat(at: CGPoint(x: top.x, y: top.y - face.box.height * scale * 0.18),
                            width: face.box.width * scale * 1.15, angle: -face.angle, in: cg)
            }
        }
        return Output(image: image, foundFace: detected != nil)
    }

    // MARK: Foto vorbereiten

    /// Aufrecht drehen und auf höchstens 3000 Punkte verkleinern (mehr Details im Gesicht)
    private static func normalized(_ photo: UIImage) -> CGImage? {
        let longest = max(photo.size.width, photo.size.height)
        guard longest > 0 else { return nil }
        let factor = min(1, 3000 / longest)
        let target = CGSize(width: (photo.size.width * factor).rounded(), height: (photo.size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            photo.draw(in: CGRect(origin: .zero, size: target))
        }.cgImage
    }

    // MARK: Gesicht

    private static func detectFace(in image: CGImage) -> Face? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up)
        try? handler.perform([request])
        guard let observation = (request.results ?? []).max(by: { $0.boundingBox.width < $1.boundingBox.width }) else { return nil }
        let size = CGSize(width: image.width, height: image.height)
        let box = VNImageRectForNormalizedRect(observation.boundingBox, image.width, image.height)
        let lips = observation.landmarks?.outerLips?.pointsInImage(imageSize: size) ?? []
        let nose = observation.landmarks?.nose?.pointsInImage(imageSize: size) ?? []

        guard lips.count >= 4 else {
            var face = fallbackFace(in: size)
            face.box = box
            face.mouthCenter = CGPoint(x: box.midX, y: box.minY + box.height * 0.28)
            face.mouthWidth = box.width * 0.4
            face.upperLipTop = face.mouthCenter.y + box.height * 0.03
            face.noseBottom = face.mouthCenter.y + box.height * 0.12
            return face
        }
        let left = lips.min { $0.x < $1.x }!, right = lips.max { $0.x < $1.x }!
        let center = CGPoint(x: lips.map(\.x).reduce(0, +) / CGFloat(lips.count), y: lips.map(\.y).reduce(0, +) / CGFloat(lips.count))
        let upperLip = lips.map(\.y).max() ?? center.y          // y wächst nach oben
        let noseBottom = nose.map(\.y).min() ?? (upperLip + box.height * 0.1)
        let angle = atan2(right.y - left.y, right.x - left.x)
        return Face(box: box, mouthCenter: center, mouthWidth: hypot(right.x - left.x, right.y - left.y),
                    noseBottom: max(noseBottom, upperLip), upperLipTop: upperLip, angle: angle)
    }

    /// Kein Gesicht gefunden: Bildmitte annehmen
    private static func fallbackFace(in size: CGSize) -> Face {
        let w = min(size.width, size.height) * 0.45
        let box = CGRect(x: size.width / 2 - w / 2, y: size.height / 2 - w * 0.6, width: w, height: w * 1.2)
        let mouth = CGPoint(x: box.midX, y: box.minY + box.height * 0.28)
        return Face(box: box, mouthCenter: mouth, mouthWidth: w * 0.4, noseBottom: mouth.y + box.height * 0.12,
                    upperLipTop: mouth.y + box.height * 0.03, angle: 0)
    }

    // MARK: Comic-Look

    private static func stylize(_ image: CIImage, look: Look) -> CIImage {
        let smooth = CIFilter.noiseReduction()
        smooth.inputImage = image
        smooth.noiseLevel = 0.04
        smooth.sharpness = 0.5
        let base = smooth.outputImage ?? image

        let colors = CIFilter.colorControls()
        colors.inputImage = base
        colors.saturation = look == .poster ? 1.8 : 1.35
        colors.contrast = look == .poster ? 1.3 : 1.12
        colors.brightness = 0.03
        let vivid = colors.outputImage ?? base

        switch look {
        case .comic:
            let comic = CIFilter.comicEffect()
            comic.inputImage = vivid
            return comic.outputImage ?? vivid
        case .cartoon, .poster:
            let poster = CIFilter.colorPosterize()
            poster.inputImage = vivid
            poster.levels = look == .poster ? 4 : 7
            let flat = poster.outputImage ?? vivid

            let lines = CIFilter.lineOverlay()
            lines.inputImage = base
            lines.nrNoiseLevel = 0.07
            lines.nrSharpness = 0.71
            lines.edgeIntensity = 1.0
            lines.threshold = 0.12
            lines.contrast = 50
            guard let ink = lines.outputImage else { return flat }
            return ink.composited(over: flat)
        }
    }

    /// Maske der Person (weiß = Person), auf 1024 × 1024 gestreckt
    private static func personMask(for image: CIImage) -> CIImage? {
        guard let cg = context.createCGImage(image, from: CGRect(x: 0, y: 0, width: size, height: size)) else { return nil }
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        try? handler.perform([request])
        guard let buffer = request.results?.first?.pixelBuffer else { return nil }
        let mask = CIImage(cvPixelBuffer: buffer)
        return mask.transformed(by: CGAffineTransform(scaleX: size / mask.extent.width, y: size / mask.extent.height))
    }

    // MARK: Zeichnen

    private static func drawBackground(_ background: Background, in cg: CGContext) {
        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { UIColor(red: r, green: g, blue: b, alpha: 1).cgColor }
        let inner: CGColor, outer: CGColor
        switch background {
        case .tricolore:
            let third = size / 3
            cg.setFillColor(rgb(0.0, 0.57, 0.27))
            cg.fill(CGRect(x: 0, y: 0, width: third, height: size))
            cg.setFillColor(rgb(0.98, 0.97, 0.94))
            cg.fill(CGRect(x: third, y: 0, width: third, height: size))
            cg.setFillColor(rgb(0.81, 0.17, 0.22))
            cg.fill(CGRect(x: third * 2, y: 0, width: size - third * 2, height: size))
            return
        case .tomato: inner = rgb(0.95, 0.33, 0.24); outer = rgb(0.62, 0.10, 0.10)
        case .basil: inner = rgb(0.42, 0.75, 0.36); outer = rgb(0.10, 0.40, 0.18)
        case .cream: inner = rgb(1.0, 0.98, 0.92); outer = rgb(0.93, 0.85, 0.70)
        }
        cg.setFillColor(outer)
        cg.fill(CGRect(x: 0, y: 0, width: size, height: size))
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [inner, outer] as CFArray, locations: [0, 1]) {
            cg.drawRadialGradient(gradient, startCenter: CGPoint(x: size / 2, y: size * 0.45), startRadius: 0,
                                  endCenter: CGPoint(x: size / 2, y: size / 2), endRadius: size * 0.75,
                                  options: [.drawsAfterEndLocation])
        }
    }

    /// Schnurrbart: Mitte oben bei `anchor`, Breite `width`
    private static func drawMustache(_ shape: Mustache, color: UIColor, at anchor: CGPoint, width: CGFloat,
                                     angle: CGFloat, in cg: CGContext) {
        // Rechte Hälfte in Einheiten (x: 0 … 0.5, y nach unten), danach gespiegelt
        let half = CGMutablePath()
        func curve(_ x: CGFloat, _ y: CGFloat, _ c1x: CGFloat, _ c1y: CGFloat, _ c2x: CGFloat, _ c2y: CGFloat) {
            half.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: c1x, y: c1y), control2: CGPoint(x: c2x, y: c2y))
        }
        switch shape {
        case .handlebar:
            half.move(to: CGPoint(x: 0, y: 0.06))
            curve(0.36, 0.12, 0.10, -0.06, 0.26, -0.02)
            curve(0.47, 0.02, 0.42, 0.18, 0.49, 0.12)
            curve(0.43, -0.06, 0.46, -0.03, 0.43, -0.04)
            curve(0.53, 0.03, 0.48, -0.10, 0.54, -0.04)
            curve(0.34, 0.24, 0.52, 0.16, 0.44, 0.25)
            curve(0, 0.18, 0.22, 0.23, 0.10, 0.26)
        case .chevron:
            half.move(to: CGPoint(x: 0, y: 0.02))
            curve(0.42, 0.10, 0.16, -0.06, 0.34, -0.02)
            curve(0.46, 0.34, 0.50, 0.18, 0.52, 0.30)
            curve(0.24, 0.26, 0.38, 0.32, 0.32, 0.26)
            curve(0, 0.24, 0.14, 0.28, 0.06, 0.30)
        case .curly:
            half.move(to: CGPoint(x: 0, y: 0.06))
            curve(0.30, 0.10, 0.10, -0.06, 0.22, -0.02)
            curve(0.44, 0.10, 0.36, 0.18, 0.42, 0.16)
            curve(0.40, -0.02, 0.47, 0.04, 0.44, -0.02)
            curve(0.47, -0.12, 0.36, -0.03, 0.38, -0.12)
            curve(0.56, 0.02, 0.54, -0.12, 0.58, -0.06)
            curve(0.30, 0.24, 0.54, 0.16, 0.42, 0.25)
            curve(0, 0.18, 0.20, 0.23, 0.10, 0.25)
        }
        half.closeSubpath()
        var mirror = CGAffineTransform(scaleX: -1, y: 1)
        let path = CGMutablePath()
        path.addPath(half)
        if let mirrored = half.copy(using: &mirror) { path.addPath(mirrored) }

        cg.saveGState()
        cg.translateBy(x: anchor.x, y: anchor.y)
        cg.rotate(by: angle)
        cg.scaleBy(x: width, y: width)
        cg.setLineJoin(.round)
        cg.setLineCap(.round)
        cg.addPath(path)
        cg.setFillColor(color.cgColor)
        cg.setStrokeColor(UIColor.black.cgColor)
        cg.setLineWidth(0.012)
        cg.drawPath(using: .fillStroke)
        // Glanzlicht für den Comic-Look
        let shine = CGMutablePath()
        shine.move(to: CGPoint(x: 0.08, y: 0.06))
        shine.addCurve(to: CGPoint(x: 0.28, y: 0.06), control1: CGPoint(x: 0.14, y: 0.02), control2: CGPoint(x: 0.22, y: 0.02))
        if let mirrored = shine.copy(using: &mirror) { shine.addPath(mirrored) }
        cg.addPath(shine)
        cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        cg.setLineWidth(0.018)
        cg.strokePath()
        cg.restoreGState()
    }

    /// Kochmütze: Unterkante (Mitte) bei `bottom`
    private static func drawChefHat(at bottom: CGPoint, width: CGFloat, angle: CGFloat, in cg: CGContext) {
        cg.saveGState()
        cg.translateBy(x: bottom.x, y: bottom.y)
        cg.rotate(by: angle)
        cg.scaleBy(x: width, y: width)

        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-0.30, -0.42, 0.24), (0.30, -0.42, 0.24), (0.0, -0.58, 0.30),
                                                    (-0.14, -0.40, 0.22), (0.14, -0.40, 0.22)]
        // Erst alle Umrisse dick schwarz, dann weiß füllen: so bleibt nur die Außenlinie sichtbar
        cg.setStrokeColor(UIColor.black.cgColor)
        cg.setFillColor(UIColor.white.cgColor)
        cg.setLineWidth(0.035)
        for (x, y, r) in puffs {
            cg.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        cg.strokePath()
        for (x, y, r) in puffs {
            cg.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
        cg.fillPath()

        let band = CGPath(roundedRect: CGRect(x: -0.42, y: -0.26, width: 0.84, height: 0.26), cornerWidth: 0.05, cornerHeight: 0.05, transform: nil)
        cg.addPath(band)
        cg.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor)
        cg.setLineWidth(0.025)
        cg.drawPath(using: .fillStroke)
        // Falten im Band
        cg.setStrokeColor(UIColor(white: 0.75, alpha: 1).cgColor)
        cg.setLineWidth(0.015)
        cg.setLineCap(.round)
        for x in [-0.22, 0.0, 0.22] as [CGFloat] {
            cg.move(to: CGPoint(x: x, y: -0.22))
            cg.addLine(to: CGPoint(x: x, y: -0.04))
        }
        cg.strokePath()
        cg.restoreGState()
    }
}
