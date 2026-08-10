//
//  PizzaDoughRecipe.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 21.08.26.
//


import Foundation

struct PizzaDoughRecipe: Identifiable {
    var id = UUID()
    
    // MARK: - Basisangaben
    var doughBallsCount: Int          // Stückzahl (Int ist passender als Double)
    var doughBallsWeight: Double       // Gewicht pro Teigling in Gramm
    
    // MARK: - Bäckerprozente (Hydratation & Salz)
    var waterRatio: Double             // z. B. 0.65 für 65%
    var saltRatio: Double              // z. B. 0.03 für 3%
    
    // MARK: - Hefe & Gärung
    var selectedYeast: YeastType
    var roomFermentation: FermentationStage
    var coolFermentation: FermentationStage? // Optional, falls keine Kühlung genutzt wird
    
    var targetDate: Date?              // Zieldatum / Fertigstellungszeitpunkt
    
    // MARK: - Berechnete Mengen (Computed Properties)
    
    /// Gesamtes Zielgewicht aller Teiglinge zusammen
    var totalWeight: Double {
        Double(doughBallsCount) * doughBallsWeight
    }
    
    /// Berechnete Mehlmenge in Gramm basierend auf den Prozenten
    var flourWeight: Double {
        let totalPercentage = 1.0 + waterRatio + saltRatio
        return totalWeight / totalPercentage
    }
    
    /// Exakte Wassermenge in Gramm / ml
    var waterWeight: Double {
        flourWeight * waterRatio
    }
    
    /// Exakte Salzmenge in Gramm
    var saltWeight: Double {
        flourWeight * saltRatio
    }
    
    /// Erforderliche Hefemenge in Gramm
//    var yeastWeight: Double {
//        // Beispielrechnung basierend auf Hefe-Typ und Gärdauer
//        let baseYeastRatio = 0.002 // 0.2% als Basis
//        return flourWeight * baseYeastRatio * selectedYeast.conversionFactor
//    }
    
    var yeastWeight: Double {
        let baseConstant = 27.42  //27.42
        let activityRoom = pow(1.304, roomFermentation.temperature - 10.0)  //1.304
        if let coolFermentation = coolFermentation {
            let activityCool = 1.465 * pow(1.146, coolFermentation.temperature - 1.0)
            let total = (roomFermentation.durationHours * activityRoom) + (coolFermentation.durationHours * activityCool)
            guard total > 0 else { return 0.0 }
            return ((baseConstant * flourWeight / total) * selectedYeast.conversionFactor)
        }
        let total = roomFermentation.durationHours * activityRoom
        
        guard total > 0 else { return 0.0 }
        return ((baseConstant * flourWeight / total) * selectedYeast.conversionFactor)
    }
}

struct FermentationStage: Codable, Hashable {
    var temperature: Double // in °C
    var durationHours: Double // in Stunden
}

enum YeastType: String, CaseIterable, Identifiable, Codable {
    case fresh = "Fresh Yeast"
    case dry = "Dry Yeast"
    case sourdough = "Sourdough"
    
    var id: String { rawValue }
    
    /// Umrechnungsfaktor relativ zu Frischehefe (Beispiel)
    var conversionFactor: Double {
        switch self {
        case .fresh: return 3.0
        case .dry: return 1.5
        case .sourdough: return 1.0
        }
    }
}
