//
//  IntroAnimationView.swift
//  mgPizza_mk1
//
//  Intro beim App-Start (gut 5 s): Der Ofen erscheint, heizt mit Flammen ein, die rohe Pizza wird
//  mit der Schaufel hineingeschoben, bäckt kurz und kommt fertig wieder heraus.
//  Komplett im Code gezeichnet (Canvas), kein Video. Antippen überspringt.
//  Abschaltbar in den Einstellungen; entfällt bei „Bewegung reduzieren“ und beim Öffnen über
//  eine Schnellaktion oder Mitteilung (dann will man direkt los).
//
//  Alle Maße liegen in einem 300 × 300 großen Feld, das auf den Bildschirm skaliert wird.
//

import SwiftUI

// MARK: - Einbindung

extension View {
    /// Zeigt einmal pro App-Start das Intro über dieser Ansicht
    func introAnimation() -> some View { modifier(IntroOverlay()) }
}

private struct IntroOverlay: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var router = AppRouter.shared
    /// Beim Start einmal entschieden, damit das Umschalten in den Einstellungen nichts einblendet
    @State private var playing = UserDefaults.standard.object(forKey: AppKeys.showIntro) as? Bool ?? true

    func body(content: Content) -> some View {
        content.overlay {
            if playing && !reduceMotion && !router.skipIntro {
                IntroAnimationView {
                    withAnimation(.easeOut(duration: 0.4)) { playing = false }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: router.skipIntro)
    }
}

// MARK: - Ansicht

struct IntroAnimationView: View {
    var onFinish: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var start: Date? = nil
    @State private var finished = false

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            TimelineView(.animation(paused: start == nil)) { timeline in
                let t = start.map { timeline.date.timeIntervalSince($0) } ?? 0
                Canvas { context, size in
                    IntroScene.draw(&context, size: size, t: t)
                }
            }
            .ignoresSafeArea()
            VStack {
                Spacer()
                Text("Tap to skip")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 8)
            }
        }
        .background(IntroPalette.backgroundOuter.color().ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .statusBarHidden()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Intro: the pizza oven heats up and bakes a pizza")
        .accessibilityHint("Double-tap to skip")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
        .onAppear { startIfActive() }
        .onChange(of: scenePhase) { startIfActive() }
        .task(id: start) {
            guard start != nil else { return }
            try? await Task.sleep(for: .seconds(IntroScene.duration))
            if !Task.isCancelled { finish() }
        }
    }

    /// Erst loslegen, wenn die App wirklich sichtbar ist (nicht beim Start im Hintergrund)
    private func startIfActive() {
        if start == nil && scenePhase == .active { start = .now }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

// MARK: - Farben

private struct RGB {
    var r: Double, g: Double, b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mix(_ other: RGB, _ f: Double) -> RGB {
        RGB(r + (other.r - r) * f, g + (other.g - g) * f, b + (other.b - b) * f)
    }

    func color(_ opacity: Double = 1) -> Color {
        Color(red: r, green: g, blue: b, opacity: min(max(opacity, 0), 1))
    }
}

private enum IntroPalette {
    static let backgroundInner = RGB(0.24, 0.12, 0.07)
    static let backgroundOuter = RGB(0.06, 0.03, 0.02)
    static let domeTop = RGB(0.80, 0.42, 0.25)
    static let domeBottom = RGB(0.55, 0.24, 0.13)
    static let mortar = RGB(0.35, 0.15, 0.08)
    static let archA = RGB(0.86, 0.56, 0.37)
    static let archB = RGB(0.76, 0.46, 0.29)
    static let mouthDark = RGB(0.10, 0.05, 0.03)
    static let stand = RGB(0.42, 0.36, 0.33)
    static let standTop = RGB(0.55, 0.48, 0.44)
    static let chimney = RGB(0.30, 0.25, 0.23)
    static let chimneyCap = RGB(0.22, 0.18, 0.17)
    static let flameRed = RGB(0.89, 0.25, 0.10)
    static let flameOrange = RGB(1.00, 0.55, 0.12)
    static let flameYellow = RGB(1.00, 0.86, 0.35)
    static let doughRaw = RGB(0.96, 0.89, 0.72)
    static let doughBaked = RGB(0.86, 0.58, 0.28)
    static let doughSide = RGB(0.35, 0.20, 0.10)
    static let sauceRaw = RGB(0.87, 0.23, 0.15)
    static let sauceBaked = RGB(0.72, 0.17, 0.10)
    static let cheeseRaw = RGB(1.00, 0.99, 0.95)
    static let cheeseBaked = RGB(1.00, 0.90, 0.62)
    static let basil = RGB(0.18, 0.48, 0.22)
    static let char = RGB(0.22, 0.11, 0.05)
    static let woodLight = RGB(0.80, 0.62, 0.40)
    static let woodDark = RGB(0.55, 0.36, 0.20)
    static let cream = RGB(0.98, 0.96, 0.89)
}

// MARK: - Zeichnung

private enum IntroScene {
    /// Gesamtlänge; danach blendet das Intro aus
    static let duration = 5.2

    // Ablauf in Sekunden
    static let ovenIn = (0.0, 0.45)
    static let heatUp = (0.45, 1.35)
    static let pushIn = (1.35, 2.05)
    static let peelAway = (2.05, 2.4)
    static let bake = (2.4, 3.3)
    static let peelBack = (3.3, 3.55)
    static let takeOut = (3.55, 4.35)
    static let title = (4.15, 4.6)

    /// Lage der Pizza im Ofen (Mitte, Halbachsen)
    static let pizzaInOven = (x: 150.0, y: 197.0, rx: 38.0, ry: 13.0)
    /// Fertige Pizza, von oben gesehen
    static let pizzaServed = (y: 138.0, r: 86.0)

    static func draw(_ ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let base = ctx
        let screen = Path(CGRect(origin: .zero, size: size))
        let background = Gradient(colors: [IntroPalette.backgroundInner.color(), IntroPalette.backgroundOuter.color()])
        let backgroundShading = GraphicsContext.Shading.radialGradient(
            background, center: pt(size.width / 2, size.height * 0.45),
            startRadius: 0, endRadius: max(size.width, size.height) * 0.65)
        ctx.fill(screen, with: backgroundShading)

        let s = min(size.width / 300, size.height / 400)
        ctx.translateBy(x: size.width / 2 - 150 * s, y: size.height * 0.46 - 150 * s)
        ctx.scaleBy(x: s, y: s)

        let appear = easeOut(ramp(t, ovenIn))
        // Beim Backen lodert das Feuer kurz stärker
        let heat = smooth(ramp(t, heatUp)) * (1 + 0.12 * sin(ramp(t, bake) * .pi))
        let out = smooth(ramp(t, takeOut))

        // Wärmeschein hinter dem Ofen
        ctx.fill(circle(150, 185, 170), with: .radialGradient(
            Gradient(colors: [IntroPalette.flameOrange.color(0.22 * heat), IntroPalette.flameOrange.color(0)]),
            center: pt(150, 185), startRadius: 0, endRadius: 170))

        var oven = ctx
        let grow = 0.9 + 0.1 * appear
        oven.translateBy(x: 150, y: 234)
        oven.scaleBy(x: grow, y: grow)
        oven.translateBy(x: -150, y: -234)
        drawOven(&oven, t: t, heat: heat)

        // Schleier im Hintergrundton: blendet den Ofen ein und dunkelt ihn ab, wenn die Pizza vorn liegt
        let veilOpacity = max(1 - appear, 0.7 * out)
        if veilOpacity > 0.001 {
            var veil = base
            veil.opacity = veilOpacity
            veil.fill(screen, with: backgroundShading)
        }

        drawPizzaScene(&ctx, t: t)
        drawTitle(&ctx, t: t)
    }

    // MARK: Ofen

    static var dome: Path {
        var p = Path()
        p.move(to: pt(32, 212))
        p.addCurve(to: pt(150, 54), control1: pt(32, 118), control2: pt(88, 54))
        p.addCurve(to: pt(268, 212), control1: pt(212, 54), control2: pt(268, 118))
        p.closeSubpath()
        return p
    }

    /// Ofenöffnung: Rundbogen (Radius 55 um 150/172) auf zwei geraden Seiten
    static var mouth: Path {
        var p = Path()
        p.move(to: pt(95, 211))
        p.addLine(to: pt(95, 172))
        arc(&p, cx: 150, cy: 172, r: 55, from: 180, to: 360)
        p.addLine(to: pt(205, 211))
        p.closeSubpath()
        return p
    }

    static func drawOven(_ ctx: inout GraphicsContext, t: Double, heat: Double) {
        // Schatten am Boden
        ctx.fill(ellipse(pt(150, 240), 128, 9), with: .color(.black.opacity(0.4)))

        // Rauch aus dem Kamin, sobald eingeheizt ist
        for k in 0..<4 {
            let d = Double(k)
            let p = frac(t * 0.42 + d / 4)
            let x = 190 + p * 20 + 3 * sin(t * 2 + d * 1.7)
            ctx.fill(circle(x, 36 - p * 50, 5 + p * 14), with: .color(.white.opacity(0.2 * (1 - p) * min(heat, 1))))
        }
        // Kamin
        ctx.fill(Path(roundedRect: CGRect(x: 178, y: 44, width: 24, height: 52), cornerRadius: 3),
                 with: .color(IntroPalette.chimney.color()))
        ctx.fill(Path(roundedRect: CGRect(x: 173, y: 38, width: 34, height: 9), cornerRadius: 3),
                 with: .color(IntroPalette.chimneyCap.color()))

        // Kuppel mit Ziegelfugen
        let domePath = dome
        ctx.fill(domePath, with: .linearGradient(
            Gradient(colors: [IntroPalette.domeTop.color(), IntroPalette.domeBottom.color()]),
            startPoint: pt(150, 54), endPoint: pt(150, 212)))
        var bricks = ctx
        bricks.clip(to: domePath)
        var joints = Path()
        for row in 0..<9 {
            let y = 63 + Double(row) * 17
            joints.move(to: pt(20, y))
            joints.addLine(to: pt(280, y))
            var x = 20 + Double(row % 2) * 12
            while x < 280 {
                joints.move(to: pt(x, y))
                joints.addLine(to: pt(x, y + 17))
                x += 24
            }
        }
        bricks.stroke(joints, with: .color(IntroPalette.mortar.color(0.25)), lineWidth: 1)
        // Feuerschein auf der Kuppel
        bricks.fill(domePath, with: .radialGradient(
            Gradient(colors: [IntroPalette.flameOrange.color(0.35 * heat), IntroPalette.flameOrange.color(0)]),
            center: pt(150, 190), startRadius: 40, endRadius: 120))
        // Glanzlicht
        var shine = Path()
        arc(&shine, cx: 150, cy: 160, r: 80, from: 200, to: 245, steps: 12)
        ctx.stroke(shine, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

        // Thermometer: Zeiger wandert beim Einheizen nach rechts
        let hot = min(heat, 1)
        ctx.fill(circle(150, 82, 12), with: .color(IntroPalette.chimneyCap.color()))
        ctx.fill(circle(150, 82, 10), with: .color(IntroPalette.cream.color()))
        var dialScale = Path()
        arc(&dialScale, cx: 150, cy: 82, r: 7.5, from: 150, to: 390, steps: 24)
        ctx.stroke(dialScale, with: .color(IntroPalette.mortar.color(0.3)), lineWidth: 1.2)
        if hot > 0.01 {
            var dialHot = Path()
            arc(&dialHot, cx: 150, cy: 82, r: 7.5, from: 150, to: 150 + 240 * hot, steps: 24)
            ctx.stroke(dialHot, with: .color(IntroPalette.flameOrange.color()), lineWidth: 1.6)
        }
        let needle = (150 + 240 * hot) * .pi / 180
        var hand = Path()
        hand.move(to: pt(150, 82))
        hand.addLine(to: pt(150 + 8 * cos(needle), 82 + 8 * sin(needle)))
        ctx.stroke(hand, with: .color(IntroPalette.flameRed.color()), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        ctx.fill(circle(150, 82, 1.8), with: .color(IntroPalette.chimneyCap.color()))

        // Ofenöffnung mit Glut und Flammen
        let mouthPath = mouth
        ctx.fill(mouthPath, with: .color(IntroPalette.mouthDark.color()))
        let flicker = 0.9 + 0.1 * sin(t * 11)
        ctx.fill(mouthPath, with: .radialGradient(
            Gradient(colors: [IntroPalette.flameOrange.color(0.85 * heat * flicker),
                              IntroPalette.flameRed.color(0.45 * heat), IntroPalette.flameRed.color(0)]),
            center: pt(150, 205), startRadius: 0, endRadius: 80))
        var inside = ctx
        inside.clip(to: mouthPath)
        drawFlames(&inside, t: t, heat: heat)

        // Ziegelbogen um die Öffnung
        let segments = 9
        for k in 0..<segments {
            let a0 = 180 + 180 * Double(k) / Double(segments)
            let a1 = 180 + 180 * Double(k + 1) / Double(segments)
            var brick = Path()
            arc(&brick, cx: 150, cy: 172, r: 68, from: a0, to: a1, steps: 6)
            arc(&brick, cx: 150, cy: 172, r: 55, from: a1, to: a0, steps: 6)
            brick.closeSubpath()
            ctx.fill(brick, with: .color((k % 2 == 0 ? IntroPalette.archA : IntroPalette.archB).color()))
            ctx.stroke(brick, with: .color(IntroPalette.mortar.color(0.8)), lineWidth: 1.2)
        }
        for (side, x) in [82.0, 205.0].enumerated() {
            for (row, y) in [172.0, 191.5].enumerated() {
                let brick = Path(CGRect(x: x, y: y, width: 13, height: 19.5))
                ctx.fill(brick, with: .color(((side + row) % 2 == 0 ? IntroPalette.archB : IntroPalette.archA).color()))
                ctx.stroke(brick, with: .color(IntroPalette.mortar.color(0.8)), lineWidth: 1.2)
            }
        }
        // Glühende Innenkante
        var rim = Path()
        rim.move(to: pt(95, 211))
        rim.addLine(to: pt(95, 172))
        arc(&rim, cx: 150, cy: 172, r: 55, from: 180, to: 360)
        rim.addLine(to: pt(205, 211))
        ctx.stroke(rim, with: .color(IntroPalette.flameOrange.color(0.55 * heat)), lineWidth: 2)

        // Sockel
        ctx.fill(Path(roundedRect: CGRect(x: 22, y: 211, width: 256, height: 23), cornerRadius: 3),
                 with: .color(IntroPalette.stand.color()))
        ctx.fill(Path(CGRect(x: 22, y: 211, width: 256, height: 4)), with: .color(IntroPalette.standTop.color()))
    }

    /// Flammenhöhen von links nach rechts (links liegt das Holz)
    static let flameHeights: [Double] = [0.95, 1.0, 0.82, 0.62, 0.5, 0.42, 0.36]

    static func flame(x: Double, base: Double, width w: Double, height h: Double, sway: Double) -> Path {
        var p = Path()
        p.move(to: pt(x - w / 2, base))
        p.addCurve(to: pt(x + sway, base - h),
                   control1: pt(x - w / 2, base - h * 0.5), control2: pt(x - w * 0.15 + sway, base - h * 0.75))
        p.addCurve(to: pt(x + w / 2, base),
                   control1: pt(x + w * 0.15 + sway, base - h * 0.75), control2: pt(x + w / 2, base - h * 0.5))
        p.closeSubpath()
        return p
    }

    static func drawFlames(_ ctx: inout GraphicsContext, t: Double, heat: Double) {
        guard heat > 0.001 else { return }
        var outer = Path(), middle = Path(), inner = Path()
        for (i, f) in flameHeights.enumerated() {
            let d = Double(i)
            let x = 106 + d * 14.5
            let flick = 0.82 + 0.12 * sin(t * 13 + d * 1.9) + 0.06 * sin(t * 29 + d * 0.7)
            let h = 64 * heat * f * flick
            let w = 20 + 3 * sin(d * 1.3)
            let sway = 4 * sin(t * 7 + d * 1.3) * min(heat, 1)
            outer.addPath(flame(x: x, base: 213, width: w, height: h, sway: sway))
            middle.addPath(flame(x: x, base: 213, width: w * 0.66, height: h * 0.72, sway: sway * 0.8))
            inner.addPath(flame(x: x, base: 213, width: w * 0.34, height: h * 0.45, sway: sway * 0.6))
        }
        ctx.drawLayer { glow in
            glow.addFilter(.blur(radius: 7))
            glow.fill(outer, with: .color(IntroPalette.flameOrange.color(0.8)))
        }
        ctx.fill(outer, with: .color(IntroPalette.flameRed.color(0.92)))
        ctx.fill(middle, with: .color(IntroPalette.flameOrange.color()))
        ctx.fill(inner, with: .color(IntroPalette.flameYellow.color()))
        // Funken
        for k in 0..<10 {
            let d = Double(k)
            let p = frac(t * 0.9 + d * 0.137)
            let x = 104 + d * 9.5 + 5 * sin(t * 3 + d)
            ctx.fill(circle(x, 206 - p * 82, 0.5 + 1.5 * (1 - p)),
                     with: .color(IntroPalette.flameYellow.color((1 - p) * min(heat, 1))))
        }
    }

    // MARK: Pizza und Schaufel

    static func drawPizzaScene(_ ctx: inout GraphicsContext, t: Double) {
        guard t > pushIn.0 else { return }
        let push = smooth(ramp(t, pushIn))
        let away = smooth(ramp(t, peelAway))
        let back = smooth(ramp(t, peelBack))
        let out = smooth(ramp(t, takeOut))
        let baked = smooth(ramp(t, bake))
        let fadeIn = ramp(t, pushIn.0, pushIn.0 + 0.25)

        // Von vorn in die Öffnung, beim Herausholen nach vorn in die Mitte und flach von oben
        let oven = pizzaInOven
        var center = pt(oven.x, mix(325, oven.y, push))
        var rx = oven.rx * mix(1.7, 1, push)
        var ry = oven.ry * mix(1.7, 1, push)
        if out > 0 {
            center = pt(oven.x, mix(oven.y, pizzaServed.y, out))
            rx = mix(oven.rx, pizzaServed.r, out)
            ry = mix(oven.ry, pizzaServed.r, out)
        }

        // Schaufel liegt unter der Pizza: nach dem Einschieben heraus, zum Holen wieder hinein
        let gone = away * (1 - back)
        let peelOpacity = fadeIn * (1 - gone) * (1 - ramp(t, 3.75, 4.1))
        if peelOpacity > 0.01 {
            var peel = ctx
            peel.opacity = peelOpacity
            drawPeel(&peel, center: pt(center.x, center.y + 120 * gone), rx: rx, ry: ry)
        }

        var pizza = ctx
        pizza.opacity = fadeIn
        drawPizza(&pizza, center: center, rx: rx, ry: ry, baked: baked)

        // Dampf über der fertigen Pizza
        let steam = ramp(t, 4.2, 4.7)
        if steam > 0 {
            for k in 0..<3 {
                let d = Double(k)
                var wisp = Path()
                for j in 0...13 {
                    let y = center.y - ry - 6 - Double(j) * 3
                    let x = 150 + (d - 1) * 28 + 4 * sin(Double(j) * 0.55 - t * 5 + d * 2)
                    if j == 0 { wisp.move(to: pt(x, y)) } else { wisp.addLine(to: pt(x, y)) }
                }
                ctx.stroke(wisp, with: .color(.white.opacity(0.3 * steam)),
                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    static func drawPeel(_ ctx: inout GraphicsContext, center c: CGPoint, rx: Double, ry: Double) {
        let k = rx / pizzaInOven.rx
        let bladeRX = rx * 1.2, bladeRY = ry * 1.2
        var handle = Path()
        handle.move(to: pt(c.x + 1 * k, c.y + bladeRY - 3 * k))
        handle.addLine(to: pt(c.x + 11 * k, c.y + bladeRY - 3 * k))
        handle.addLine(to: pt(c.x + 58 * k, c.y + bladeRY + 175 * k))
        handle.addLine(to: pt(c.x + 38 * k, c.y + bladeRY + 175 * k))
        handle.closeSubpath()
        ctx.fill(handle, with: .color(IntroPalette.woodDark.color()))
        let blade = ellipse(c, bladeRX, bladeRY)
        ctx.fill(blade, with: .color(IntroPalette.woodLight.color()))
        ctx.stroke(blade, with: .color(IntroPalette.woodDark.color()), lineWidth: 1.2)
    }

    /// Lage in Einheiten des Pizzaradius (u nach rechts, v nach unten)
    static let cheeseSpots: [(Double, Double)] = [(-0.38, -0.22), (0.12, -0.45), (0.44, -0.05), (0.02, 0.1),
                                                  (-0.32, 0.32), (0.28, 0.38), (-0.08, -0.12)]
    static let basilLeaves: [(Double, Double, Double)] = [(-0.15, -0.3, 30), (0.3, 0.14, -40), (-0.34, 0.06, 80), (0.06, 0.4, 10)]

    static func drawPizza(_ ctx: inout GraphicsContext, center c: CGPoint, rx: Double, ry: Double, baked b: Double) {
        let p: (Double, Double) -> CGPoint = { u, v in pt(c.x + u * rx, c.y + v * ry) }
        func spot(_ u: Double, _ v: Double, _ r: Double) -> Path { ellipse(p(u, v), r * rx, r * ry) }

        let dough = IntroPalette.doughRaw.mix(IntroPalette.doughBaked, b)
        // Dicke des Teigs, nur von der Seite sichtbar
        let thickness = 0.09 * rx * (1 - ry / rx)
        ctx.fill(ellipse(pt(c.x, c.y + thickness), rx, ry), with: .color(dough.mix(IntroPalette.doughSide, 0.45).color()))
        ctx.fill(ellipse(c, rx, ry), with: .color(dough.color()))
        ctx.stroke(ellipse(c, rx * 0.97, ry * 0.97), with: .color(IntroPalette.char.color(0.18 * b)), lineWidth: max(0.8, rx * 0.04))

        // Tomatensauce
        ctx.fill(spot(0, 0, 0.8), with: .color(IntroPalette.sauceRaw.mix(IntroPalette.sauceBaked, b).color()))
        // Mozzarella: roh in Stücken, gebacken zerlaufen und leicht gebräunt
        let cheese = IntroPalette.cheeseRaw.mix(IntroPalette.cheeseBaked, b)
        for (u, v) in cheeseSpots {
            ctx.fill(spot(u, v, mix(0.1, 0.17, b)), with: .color(cheese.color()))
        }
        for (u, v) in cheeseSpots.prefix(4) {
            ctx.fill(spot(u + 0.04, v - 0.03, 0.035), with: .color(IntroPalette.doughBaked.color(0.7 * b)))
        }
        // Leopardenflecken am Rand
        for k in 0..<14 {
            let d = Double(k)
            let a = (d * 25.7 + Double(k % 3) * 6) * .pi / 180
            let r = 0.89 + 0.03 * sin(d * 2.1)
            ctx.fill(spot(r * cos(a), r * sin(a), 0.028 + 0.012 * Double(k % 2)), with: .color(IntroPalette.char.color(0.75 * b)))
        }
        // Basilikum kommt frisch drauf
        let leaf = ramp(b, 0.55, 1)
        if leaf > 0 {
            for (u, v, angle) in basilLeaves {
                ctx.fill(leafPath(p, u: u, v: v, angle: angle, size: leaf), with: .color(IntroPalette.basil.color(leaf)))
            }
        }
    }

    static func leafPath(_ p: (Double, Double) -> CGPoint, u: Double, v: Double, angle: Double, size: Double) -> Path {
        let a = angle * .pi / 180
        let length = 0.24 * size, width = 0.11 * size
        let dx = cos(a) * length / 2, dy = sin(a) * length / 2
        let nx = -sin(a) * width, ny = cos(a) * width
        var path = Path()
        path.move(to: p(u - dx, v - dy))
        path.addQuadCurve(to: p(u + dx, v + dy), control: p(u + nx, v + ny))
        path.addQuadCurve(to: p(u - dx, v - dy), control: p(u - nx, v - ny))
        path.closeSubpath()
        return path
    }

    // MARK: Titel

    static func drawTitle(_ ctx: inout GraphicsContext, t: Double) {
        let shown = easeOut(ramp(t, title))
        guard shown > 0 else { return }
        var text = ctx.resolve(Text("Buon appetito!").font(.system(size: 28, weight: .bold, design: .serif)).italic())
        text.shading = .color(IntroPalette.cream.color())
        var layer = ctx
        layer.opacity = shown
        layer.draw(text, at: pt(150, 262 + 10 * (1 - shown)))
    }

    // MARK: Hilfen

    static func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double { min(max((t - a) / (b - a), 0), 1) }
    static func ramp(_ t: Double, _ span: (Double, Double)) -> Double { ramp(t, span.0, span.1) }
    static func smooth(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func mix(_ a: Double, _ b: Double, _ f: Double) -> Double { a + (b - a) * f }
    static func frac(_ x: Double) -> Double { x - x.rounded(.down) }
    static func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    static func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }

    static func ellipse(_ c: CGPoint, _ rx: Double, _ ry: Double) -> Path {
        Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
    }

    /// Kreisbogen als Linienzug (Winkel in Grad, 0° rechts, 90° unten), hängt an den Pfad an
    static func arc(_ path: inout Path, cx: Double, cy: Double, r: Double, from a0: Double, to a1: Double, steps: Int = 36) {
        for k in 0...steps {
            let a = (a0 + (a1 - a0) * Double(k) / Double(steps)) * .pi / 180
            let point = pt(cx + r * cos(a), cy + r * sin(a))
            if k == 0 && path.isEmpty { path.move(to: point) } else { path.addLine(to: point) }
        }
    }
}

#Preview {
    IntroAnimationView {}
}
