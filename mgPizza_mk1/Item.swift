//
//  Item.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 28.07.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
