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
         dateSelection: Date = Date()) {
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
    }
}

enum RecipeSetupStep: Hashable {
    case fermentRoomTimeTemp
    case fermentFridgeTimeTemp
    case doughResult
}
