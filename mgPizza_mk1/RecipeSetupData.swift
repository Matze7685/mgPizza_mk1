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
    var doughBallsCount: Double = 1.0
    var doughWeight: Double = 250.0
    var waterRatio: Double = 65.0
    var saltRatio: Double = 3.0
    var yeastSelection: Int = 0
    var fridgeTimeMode: String = "AUTO"
    var roomTemp: Double = 20.0
    var roomTime: Double = 4.0
    var coolTemp: Double = 4.0
    var coolTime: Double = 12.0
    var dateSelection: Date = Date()
    
    init(doughBallsCount: Double, doughWeight: Double, waterRatio: Double, saltRatio: Double, yeastSelection: Int, fridgeTimeMode: String, roomTemp: Double, roomTime: Double, coolTemp: Double, coolTime: Double, dateSelection: Date) {
        self.doughBallsCount = doughBallsCount
        self.doughWeight = doughWeight
        self.waterRatio = waterRatio
        self.saltRatio = saltRatio
        self.yeastSelection = yeastSelection
        self.fridgeTimeMode = fridgeTimeMode
        self.roomTemp = roomTemp
        self.roomTime = roomTime
        self.coolTemp = coolTemp
        self.coolTime = coolTime
        self.dateSelection = dateSelection
    }
}

enum RecipeSetupStep: Hashable {
    case fermentRoomTimeTemp
    case fermentFridgeTimeTemp
    case doughResult
}
