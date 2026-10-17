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

    // Timer (gesetzt beim START)
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
                        kneadSteps: kneadSteps, name: name)
    }
}

// MARK: - Berechnung
extension RecipeSetupData {
    var displayName: String {
        name.isEmpty ? String(localized: "Dough \(createdAt.formatted(date: .abbreviated, time: .omitted))") : name
    }

    var safeYeastSelection: Int {
        min(max(yeastSelection, 0), yeastTypes.count - 1, yeastRatio.count - 1)
    }

    var yeastName: String { yeastTypes[safeYeastSelection] }

    var totalDoughWeight: Double { doughWeight * doughBallsCount }

    var flour: Double {
        let totalFactor = 1.0 + (waterRatio + saltRatio + oilRatio + sugarRatio) / 100.0
        return totalDoughWeight / totalFactor
    }

    var water: Double { flour * waterRatio / 100.0 }
    var salt: Double { flour * saltRatio / 100.0 }
    var oil: Double { flour * oilRatio / 100.0 }
    var sugar: Double { flour * sugarRatio / 100.0 }

    /// Kühlschrankzeit in Stunden. Im AUTO-Modus wird sie aus dem Servierzeitpunkt berechnet.
    func effectiveCoolTime(now: Date = Date()) -> Double {
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
    }

    func stopTimers() {
        isStarted = false
        DoughNotifications.cancel(for: self)
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

enum RecipeSetupStep: Hashable {
    case fermentRoomTimeTemp
    case fermentFridgeTimeTemp
    case doughResult
}
