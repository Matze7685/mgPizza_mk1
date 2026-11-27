//
//  DoughCalculationTests.swift
//  mgPizza_mk1Tests
//
//  Prüft die Rechnungen, auf die es am Pizzaabend ankommt: Teigmengen, Hefe, Durchgänge, Belag.
//  Starten in Xcode: Product › Test (⌘U).
//

import Foundation
import Testing
@testable import mgPizza_mk1

@MainActor
struct DoughCalculationTests {
    private func recipe(balls: Double = 8, weight: Double = 250, water: Double = 65, salt: Double = 3) -> RecipeSetupData {
        RecipeSetupData(doughBallsCount: balls, doughWeight: weight, waterRatio: water, saltRatio: salt,
                        yeastSelection: 1, roomTemp: 20, roomTime: 4, coolTemp: 4, coolTime: 24)
    }

    @Test func ingredientsAddUpToTotalWeight() {
        let r = recipe()
        #expect(r.totalDoughWeight == 2000)
        let sum = r.flour + r.water + r.salt + r.oil + r.sugar
        #expect(abs(sum - 2000) < 0.001)
    }

    @Test func bakersPercentages() {
        let r = recipe()
        #expect(abs(r.flour - 2000 / 1.68) < 0.01)          // 1190,5 g
        #expect(abs(r.water / r.flour - 0.65) < 0.0001)
        #expect(abs(r.salt / r.flour - 0.03) < 0.0001)
    }

    @Test func oilAndSugarReduceFlour() {
        let plain = recipe()
        let rich = recipe()
        rich.oilRatio = 2
        rich.sugarRatio = 1
        #expect(rich.flour < plain.flour)
        #expect(abs(rich.oil - rich.flour * 0.02) < 0.0001)
    }

    @Test func yeastIsPositiveAndSmall() {
        let r = recipe()
        let yeast = r.yeast()
        #expect(yeast > 0)
        #expect(yeast < r.flour * 0.01)                      // Trockenhefe: deutlich unter 1 %
    }

    @Test func longerFridgeTimeNeedsLessYeast() {
        let short = recipe()
        short.coolTime = 12
        let long = recipe()
        long.coolTime = 48
        #expect(long.yeast() < short.yeast())
    }

    @Test func warmerRoomNeedsLessYeast() {
        let cool = recipe()
        let warm = recipe()
        warm.roomTemp = 26
        #expect(warm.yeast() < cool.yeast())
    }

    @Test func yeastCorrectionScalesLinearly() {
        let normal = recipe()
        let less = recipe()
        less.yeastCorrection = 80
        #expect(abs(less.yeast() - normal.yeast() * 0.8) < 0.0001)
    }

    @Test func freshYeastIsTwiceDryYeast() {
        let dry = recipe()
        let fresh = recipe()
        fresh.yeastSelection = 0
        #expect(abs(fresh.yeast() - dry.yeast() * 2) < 0.0001)   // Faktoren 3,0 (frisch) und 1,5 (trocken)
    }

    @Test func batchesFollowMixerCapacity() {
        let defaults = UserDefaults.standard
        let old = defaults.object(forKey: AppKeys.mixerCapacity)
        defer { defaults.set(old, forKey: AppKeys.mixerCapacity) }
        defaults.set(2500.0, forKey: AppKeys.mixerCapacity)

        let small = recipe(balls: 8, weight: 250)           // 2000 g
        #expect(small.batchCount == 1)

        let big = recipe(balls: 25, weight: 250)            // 6250 g -> 3 Durchgänge
        #expect(big.batchCount == 3)
        #expect([0, 1, 2].map(big.batchBalls) == [9, 8, 8])
        #expect(abs([0, 1, 2].map(big.batchFraction).reduce(0, +) - 1) < 0.0001)
    }

    @Test func detroitWeightFromPanSize() {
        let r = recipe(balls: 1, weight: 0)
        r.style = "detroit"
        r.panWidth = 25
        r.panLength = 35
        r.doughThickness = 5.5
        r.applyDetroitWeight()
        #expect(r.doughWeight == 481)                       // 25 × 35 × 0,55 cm ≈ 481 g
    }

    @Test func pizzaDiameterGrowsWithWeight() {
        #expect(recipe(weight: 230).pizzaDiameter < recipe(weight: 280).pizzaDiameter)
        #expect(abs(recipe(weight: 250).pizzaDiameter - 31) < 1)
    }

    @Test func kneadStepsSplitIngredientsCompletely() {
        // Jede Zutat wird über alle Knetschritte zusammen genau einmal (100 %) zugegeben
        for plan in [KneadStep.defaultPlan, KneadStep.detroitPlan] {
            var totals: [String: Double] = [:]
            for step in plan { for add in step.effectiveAdds { totals[add.key, default: 0] += add.fraction } }
            for key in ["flour", "water", "yeast", "salt", "oil", "sugar"] {
                #expect(abs((totals[key] ?? 0) - 1) < 0.0001, "\(key) in plan")
            }
        }
    }
}

@MainActor
struct MenuToppingTests {
    @Test func toppingsAreMultipliedByOrders() {
        let margherita = MenuPizza(name: "Margherita", toppings: [Topping(name: "Mozzarella", amount: 100)])
        margherita.orderCount = 3
        let totals = MenuPizza.aggregatedToppings(of: [margherita])
        #expect(totals.count == 1)
        #expect(totals.first?.amount == 300)
    }

    @Test func removedToppingsAreNotCounted() {
        let pizza = MenuPizza(name: "Salami", toppings: [Topping(name: "Salami", amount: 40), Topping(name: "Mozzarella", amount: 100)])
        pizza.orderCount = 4
        pizza.removedToppings = ["Salami": 1]
        let totals = Dictionary(uniqueKeysWithValues: MenuPizza.aggregatedToppings(of: [pizza]).map { ($0.name, $0.amount) })
        #expect(totals["Salami"] == 120)
        #expect(totals["Mozzarella"] == 400)
    }

    @Test func sameToppingOnDifferentPizzasIsCombined() {
        let a = MenuPizza(name: "A", toppings: [Topping(name: "Mozzarella", amount: 100)])
        let b = MenuPizza(name: "B", toppings: [Topping(name: "Mozzarella", amount: 80)])
        a.orderCount = 1
        b.orderCount = 2
        let totals = MenuPizza.aggregatedToppings(of: [a, b])
        #expect(totals.count == 1)
        #expect(totals.first?.amount == 260)
    }

    @Test func pizzasWithoutOrdersAreIgnored() {
        let pizza = MenuPizza(name: "Marinara", toppings: [Topping(name: "Knoblauch", amount: 1, unit: "pcs")])
        #expect(MenuPizza.aggregatedToppings(of: [pizza]).isEmpty)
    }
}

@MainActor
struct EventTests {
    @Test func pastEvents() {
        var evening = GuestEvening(id: "x", title: "Test", date: .now.addingTimeInterval(-2 * 86400))
        #expect(evening.isPast)
        evening.date = .now.addingTimeInterval(86400)
        #expect(!evening.isPast)
        evening.done = true
        #expect(evening.isPast)
    }

    @Test func fixedQuantities() {
        var evening = GuestEvening(id: "x", title: "Test", date: .now)
        #expect(!evening.isFixed)
        evening.fixedCounts = ["Salami": 5]
        #expect(evening.isFixed)
    }

    @Test func shapingTextMentionsCountAndWeight() {
        let r = RecipeSetupData(doughBallsCount: 6, doughWeight: 260)
        #expect(r.shapingText.contains("6"))
        #expect(r.shapingText.contains("260"))
    }
}
