//
//  ShoppingItem.swift
//  mgPizza_mk1
//

import Foundation
import SwiftData

@Model
class ShoppingItem {
    var name: String = ""
    var amount: String = ""
    var source: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date()

    init(name: String, amount: String = "", source: String = "") {
        self.name = name
        self.amount = amount
        self.source = source
    }

    static func add(_ items: [(String, String)], source: String, to context: ModelContext) {
        for (name, amount) in items {
            context.insert(ShoppingItem(name: name, amount: amount, source: source))
        }
    }
}
