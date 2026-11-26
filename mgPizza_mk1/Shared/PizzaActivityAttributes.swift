//
//  PizzaActivityAttributes.swift
//  mgPizza_mk1
//
//  Wird von App UND Widget-Extension verwendet (Target Membership: beide).
//

import ActivityKit
import Foundation

/// `nonisolated`: ActivityKit nutzt die Konformität außerhalb des MainActors
/// (Projekt-Default ist MainActor-Isolation).
nonisolated struct PizzaActivityAttributes: ActivityAttributes {
    nonisolated public struct ContentState: Codable, Hashable {
        var title: String          // z. B. "Teig raus" oder Knetschritt
        var subtitle: String       // Rezeptname
        var endDate: Date
        var symbol: String         // SF Symbol
    }

    /// "knead-<Rezept-UUID>" oder Rezept-UUID
    var id: String
}
