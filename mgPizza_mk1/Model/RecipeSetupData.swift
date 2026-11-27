//
//  RecipeSetupData.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 04.08.26.
//

import Foundation
import SwiftData

@Model
class RecipeSetupData {
    var doughBallsCount: Double
    var doughWeight: Double
    var waterRatio: Double
    var saltRatio: Double
    var yeastSelection: Int
    var yeastTypes: [String]
    var yeastRatio: [Double]
    var fridgeTimeMode: String
    var roomTemp: Double
    var roomTime: Double
    var coolTemp: Double
    var coolTime: Double
    var dateSelection: Date

    // Neue Felder (mit Default-Werten, damit SwiftData bestehende Daten migrieren kann)
    var uid: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    var oilRatio: Double = 0.0
    var sugarRatio: Double = 0.0
    var yeastCorrection: Double = 100.0        // in %, zum Feintuning über das Feedback
    var kneadSteps: [KneadStep] = KneadStep.defaultPlan

    // Pizza-Stil: "round" (Teiglinge) oder "detroit" (Blech/Pfanne)
    var style: String = "round"
    var panWidth: Double = 25.0                // cm
    var panLength: Double = 35.0               // cm
    var doughThickness: Double = 5.5           // mm (roher Teig, ausgedrückt in der Pfanne)

    /// Gewählter Zeitpunkt "Teig aus dem Kühlschrank" (fridgeTimeMode == "OUT")
    var fridgeOutSelection: Date = Date().addingTimeInterval(24 * 3600)

    // Ablauf: Rezept ist "in Arbeit" (Zutaten abwiegen / kneten), bevor der Gärtimer läuft
    var isInProgress: Bool = false
    // Knet-Timer pro Rezept
    var kneadStepIndex: Int = 0
    var kneadStepEnd: Date?
    /// Aktueller Knet-Durchgang (Teig wird geteilt, wenn er größer als die Knetmaschine ist)
    var kneadBatch: Int = 0

    // Gärtimer (Kühlschrank -> Raum -> Servieren)
    var isStarted: Bool = false
    var startDate: Date?
    var fridgeOutDate: Date?
    var servingDate: Date?

    // Feedback
    var rating: Int = 0                        // 0 = noch nicht bewertet, 1...5 Sterne
    var notes: String = ""

    init(doughBallsCount: Double = 1.0,
         doughWeight: Double = 250.0,
         waterRatio: Double = 65.0,
         saltRatio: Double = 3.0,
         yeastSelection: Int = 0,
         yeastTypes: [String] = ["Frische Hefe", "Trockenhefe", "Instant Trockenhefe"],
         yeastRatio: [Double] = [3.0, 1.5, 1.0],
         fridgeTimeMode: String = "MAN",
         roomTemp: Double = 20.0,
         roomTime: Double = 4.0,
         coolTemp: Double = 4.0,
         coolTime: Double = 12.0,
         dateSelection: Date = Date(),
         oilRatio: Double = 0.0,
         sugarRatio: Double = 0.0,
         yeastCorrection: Double = 100.0,
         kneadSteps: [KneadStep] = KneadStep.defaultPlan,
         name: String = "") {
        self.doughBallsCount = doughBallsCount
        self.doughWeight = doughWeight
        self.waterRatio = waterRatio
        self.saltRatio = saltRatio
        self.yeastSelection = yeastSelection
        self.yeastTypes = yeastTypes
        self.yeastRatio = yeastRatio
        self.fridgeTimeMode = fridgeTimeMode
        self.roomTemp = roomTemp
        self.roomTime = roomTime
        self.coolTemp = coolTemp
        self.coolTime = coolTime
        self.dateSelection = dateSelection
        self.oilRatio = oilRatio
        self.sugarRatio = sugarRatio
        self.yeastCorrection = yeastCorrection
        self.kneadSteps = kneadSteps
        self.name = name
    }

    /// Kopie als neue Vorlage (ohne Timer und Feedback)
    func copyAsTemplate() -> RecipeSetupData {
        RecipeSetupData(doughBallsCount: doughBallsCount, doughWeight: doughWeight, waterRatio: waterRatio,
                        saltRatio: saltRatio, yeastSelection: yeastSelection, fridgeTimeMode: fridgeTimeMode,
                        roomTemp: roomTemp, roomTime: roomTime, coolTemp: coolTemp, coolTime: coolTime,
                        dateSelection: Date().addingTimeInterval((roomTime + coolTime) * 3600),
                        oilRatio: oilRatio, sugarRatio: sugarRatio, yeastCorrection: yeastCorrection,
                        kneadSteps: kneadSteps, name: "")   // leer -> automatischer Name passend zu den neuen Einstellungen
            .withPan(style: style, width: panWidth, length: panLength, thickness: doughThickness)
    }

    private func withPan(style: String, width: Double, length: Double, thickness: Double) -> RecipeSetupData {
        self.style = style
        panWidth = width
        panLength = length
        doughThickness = thickness
        return self
    }
}

// MARK: - Berechnung
extension RecipeSetupData {
    var displayName: String {
        name.isEmpty ? autoName : name
    }

    /// z. B. "05.11.26 · 8× 330 g" – passt sich an Anzahl und Gewicht an
    var autoName: String {
        let date = createdAt.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year(.twoDigits))
        return "\(date) · \(Int(doughBallsCount))× \(Int(doughWeight)) g" + (isDetroit ? " · Detroit" : "")
    }

    /// Nach Namensänderung: Erinnerungen und Live Activities mit dem neuen Namen neu planen
    func refreshScheduledTexts() {
        if isStarted {
            DoughNotifications.schedule(for: self)
            LiveActivityManager.shared.refreshDough([self])
        }
        if let end = kneadStepEnd, let step = currentKneadStep {
            DoughNotifications.scheduleKneadStep(id: uid.uuidString, title: kneadTitle(step), recipe: displayName, at: end)
            LiveActivityManager.shared.startKnead(self, title: kneadTitle(step), end: end)
        }
    }

    var safeYeastSelection: Int {
        min(max(yeastSelection, 0), yeastTypes.count - 1, yeastRatio.count - 1)
    }

    var yeastName: String {
        [String(localized: "Fresh Yeast"), String(localized: "Dry Yeast"), String(localized: "Instant Dry Yeast")][safeYeastSelection]
    }

    var isDetroit: Bool { style == "detroit" }

    /// Teiggewicht pro Pfanne: Fläche × Dicke × Dichte (roher Teig ≈ 1 g/cm³).
    /// 25 × 35 cm bei 5,5 mm ≈ 480 g – entspricht dem klassischen 10" × 14" Detroit-Blech.
    var detroitDoughWeight: Double {
        panWidth * panLength * (doughThickness / 10.0) * 1.0
    }

    /// Detroit-Werte übernehmen (Gewicht aus der Pfannengröße)
    func applyDetroitWeight() {
        if isDetroit { doughWeight = detroitDoughWeight.rounded() }
    }

    var totalDoughWeight: Double { doughWeight * doughBallsCount }

    /// Ungefährer Pizza-Durchmesser in cm für einen Teigling (Neapolitanisch, ≈ 0,33 g Teig pro cm²):
    /// 230 g ≈ 30 cm, 250 g ≈ 31 cm, 280 g ≈ 33 cm
    var pizzaDiameter: Double {
        2 * (doughWeight / 0.33 / .pi).squareRoot()
    }

    var flour: Double {
        let totalFactor = 1.0 + (waterRatio + saltRatio + oilRatio + sugarRatio) / 100.0
        return totalDoughWeight / totalFactor
    }

    var water: Double { flour * waterRatio / 100.0 }
    var salt: Double { flour * saltRatio / 100.0 }
    var oil: Double { flour * oilRatio / 100.0 }
    var sugar: Double { flour * sugarRatio / 100.0 }

    /// Kühlschrankzeit in Stunden. Im AUTO-Modus wird sie aus dem Servierzeitpunkt berechnet.
    /// Modi: "MAN" = Stunden, "AUTO" = aus Servierzeit, "OUT" = aus gewähltem Rausnehm-Zeitpunkt
    func effectiveCoolTime(now: Date = Date()) -> Double {
        if fridgeTimeMode == "OUT" {
            return max(0, fridgeOutSelection.timeIntervalSince(now) / 3600.0)
        }
        if fridgeTimeMode == "AUTO" {
            return max(0, dateSelection.timeIntervalSince(now) / 3600.0 - roomTime)
        }
        return coolTime
    }

    func yeast(now: Date = Date()) -> Double {
        let baseConstant = 27.42
        let activityRoom = pow(1.304, roomTemp - 10.0)
        let activityCool = 1.465 * pow(1.146, coolTemp - 1.0)
        let coolHours = isStarted ? coolTime : effectiveCoolTime(now: now)
        let total = (roomTime * activityRoom) + (coolHours * activityCool)

        guard total > 0 else { return 0.0 }
        return ((baseConstant * (flour / 100.0)) / total) * yeastRatio[safeYeastSelection] * (yeastCorrection / 100.0)
    }

    /// Ablauf: kneten -> Kühlschrank -> raus & portionieren -> Raumgare -> Servieren
    func startTimers(now: Date = Date()) {
        let cool = effectiveCoolTime(now: now)
        coolTime = cool
        fridgeTimeMode = "MAN"
        startDate = now
        fridgeOutDate = now.addingTimeInterval(cool * 3600)
        servingDate = now.addingTimeInterval((cool + roomTime) * 3600)
        dateSelection = servingDate ?? dateSelection
        isStarted = true
        DoughNotifications.schedule(for: self)
        LiveActivityManager.shared.refreshDough([self], now: now)
        persist()
    }

    func stopTimers() {
        isStarted = false
        DoughNotifications.cancel(for: self)
        LiveActivityManager.shared.endDough(self)
        persist()
    }

    /// Sofort speichern: Wird die App im Hintergrund von iOS beendet, bevor SwiftData automatisch speichert,
    /// wäre die Endzeit des Timers sonst weg und der Timer stünde beim nächsten Öffnen wieder am Anfang.
    func persist() {
        try? modelContext?.save()
    }

    // MARK: Ablauf / Phase

    enum Phase: Int, CaseIterable {
        case ingredients, knead, fridge, room, serve
    }

    func phase(now: Date = Date()) -> Phase? {
        if isStarted {
            if let out = fridgeOutDate, coolTime > 0, now < out { return .fridge }
            if let serving = servingDate, now < serving { return .room }
            return .serve
        }
        guard isInProgress else { return nil }
        return (kneadStepIndex > 0 || kneadStepEnd != nil || kneadBatch > 0) ? .knead : .ingredients
    }

    var isActive: Bool { isInProgress || isStarted }

    /// Rezept beginnen (nach START im Setup oder "Jetzt backen")
    func beginSession() {
        isInProgress = true
        resetKnead()
    }

    /// Fertig gebacken / abbrechen
    func finishSession() {
        stopTimers()
        resetKnead()
        isInProgress = false
    }

    // MARK: Knet-Timer

    // MARK: Durchgänge (Knetmaschinen-Kapazität)

    /// Max. Teigmenge der Knetmaschine in g (Einstellungen)
    static var mixerCapacity: Double {
        let value = UserDefaults.standard.double(forKey: AppKeys.mixerCapacity)
        return value > 0 ? value : 2500
    }

    var batchCount: Int {
        let needed = Int((totalDoughWeight / Self.mixerCapacity).rounded(.up))
        return max(1, min(needed, Int(doughBallsCount)))
    }

    /// Teiglinge pro Durchgang, gleichmäßig verteilt (z. B. 25 -> 9 / 8 / 8)
    func batchBalls(_ batch: Int) -> Int {
        let balls = Int(doughBallsCount), n = batchCount
        return balls / n + (batch < balls % n ? 1 : 0)
    }

    func batchFraction(_ batch: Int) -> Double {
        doughBallsCount > 0 ? Double(batchBalls(batch)) / doughBallsCount : 1
    }

    var currentBatch: Int { min(kneadBatch, batchCount - 1) }

    /// "Durchgang 2/3" – leer, wenn nicht geteilt wird
    var batchLabel: String {
        batchCount > 1 ? String(localized: "Batch \(currentBatch + 1)/\(batchCount)") : ""
    }

    var isBatchKneaded: Bool { kneadStepIndex >= kneadSteps.count }
    var hasMoreBatches: Bool { currentBatch < batchCount - 1 }
    var isKneadFinished: Bool { isBatchKneaded && !hasMoreBatches }
    var currentKneadStep: KneadStep? { isBatchKneaded ? nil : kneadSteps[kneadStepIndex] }

    func startNextBatch() {
        cancelKneadTimer()
        kneadBatch = min(currentBatch + 1, batchCount - 1)
        kneadStepIndex = 0
    }

    func startKneadStep(now: Date = Date()) {
        guard let step = currentKneadStep else { return }
        isInProgress = true
        let end = now.addingTimeInterval(step.minutes * 60)
        kneadStepEnd = end
        DoughNotifications.scheduleKneadStep(id: uid.uuidString, title: kneadTitle(step), recipe: displayName, at: end)
        LiveActivityManager.shared.startKnead(self, title: kneadTitle(step), end: end)
        persist()
    }

    func nextKneadStep() {
        cancelKneadTimer()
        kneadStepIndex = min(kneadStepIndex + 1, kneadSteps.count)
    }

    /// Einen Schritt zurück (Sprachbefehl „zurück“)
    func previousKneadStep() {
        cancelKneadTimer()
        kneadStepIndex = max(kneadStepIndex - 1, 0)
    }

    /// Aktuellen Schritt von vorn (Timer verwerfen)
    func restartKneadStep() {
        cancelKneadTimer()
    }

    func resetKnead() {
        cancelKneadTimer()
        kneadStepIndex = 0
        kneadBatch = 0
    }

    /// Schritt-Titel inkl. Durchgang, z. B. "Mischen (Durchgang 2/3)"
    func kneadTitle(_ step: KneadStep) -> String {
        batchLabel.isEmpty ? step.title : "\(step.title) (\(batchLabel))"
    }

    private func cancelKneadTimer() {
        kneadStepEnd = nil
        DoughNotifications.cancelKneadStep(id: uid.uuidString)
        LiveActivityManager.shared.endKnead(self)
        persist()
    }

    /// Menge einer Zutat in Gramm (für die Knet-Infos)
    func amount(of key: String) -> (name: String, grams: Double)? {
        switch key {
        case "flour": return (String(localized: "Flour"), flour)
        case "water": return (String(localized: "Water"), water)
        case "yeast": return (yeastName, yeast())
        case "salt": return (String(localized: "Salt"), salt)
        case "oil": return oil > 0 ? (String(localized: "Olive Oil"), oil) : nil
        case "sugar": return sugar > 0 ? (String(localized: "Sugar"), sugar) : nil
        default: return nil
        }
    }

    /// z. B. "434 g Wasser · 781 g Mehl · 0,38 g Trockenhefe"
    /// Mengen für den aktuellen Durchgang
    func addsText(for step: KneadStep) -> String {
        let batch = batchFraction(currentBatch)
        return step.effectiveAdds.compactMap { add -> String? in
            guard let item = amount(of: add.key) else { return nil }
            let grams = item.grams * add.fraction * batch
            let value = grams < 10 ? grams.formatted(.number.precision(.fractionLength(0...2)))
                                   : grams.formatted(.number.precision(.fractionLength(0)))
            return "\(value) g \(item.name)"
        }
        .joined(separator: " · ")
    }

    /// Was beim Herausnehmen zu tun ist, z. B. „Teig aus dem Kühlschrank nehmen und 8 Teiglinge à 250 g formen.“
    var shapingText: String {
        let count = Int(doughBallsCount), grams = Int(doughWeight.rounded())
        return isDetroit
            ? String(localized: "Take the dough out of the fridge and spread it into \(count) pans (\(grams) g each).")
            : String(localized: "Take the dough out of the fridge and shape \(count) dough balls of \(grams) g.")
    }

    /// Zutaten für die Einkaufsliste (Wasser wird ausgelassen)
    var shoppingItems: [(String, String)] {
        var items: [(String, String)] = [
            (String(localized: "Flour"), String(format: "%.0f g", flour)),
            (String(localized: "Salt"), String(format: "%.0f g", salt)),
            (yeastName, String(format: "%.1f g", yeast())),
        ]
        if oil > 0 { items.append((String(localized: "Olive Oil"), String(format: "%.0f g", oil))) }
        if sugar > 0 { items.append((String(localized: "Sugar"), String(format: "%.0f g", sugar))) }
        return items
    }
}
