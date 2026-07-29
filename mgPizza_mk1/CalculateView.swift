//
//  CalculateView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftUI


struct CalculateView: View {
    // 1. EINGABEN (Veränderbar durch den Nutzer)
    @State private var teigGewicht: Double = 250.0
    @State private var wasserProzent: Double = 65.0
    @State private var salzProzent: Double = 3.0
    
    @State private var raumTemp: Double = 20.0
    @State private var raumZeit: Double = 4.0
    @State private var kuehlTemp: Double = 4.0
    @State private var kuehlZeit: Double = 12.0

    // 2. BERECHNETE ERGEBNISSE (Aktualisieren sich automatisch!)
    var mehl: Double {
        let gesamtFaktor = 1.0 + (wasserProzent / 100.0) + (salzProzent / 100.0)
        return teigGewicht / gesamtFaktor
    }
    
    var wasser: Double {
        return mehl * (wasserProzent / 100.0)
    }
    
    var salz: Double {
        return mehl * (salzProzent / 100.0)
    }
    
    var hefe: Double {
        let basisKonstante = 27.42  //27.42
        let aktivitaetRaum = pow(1.304, raumTemp - 10.0)
        let aktivitaetKuehl = 1.465 * pow(1.146, kuehlTemp - 1.0)
        let gesamtLeistung = (raumZeit * aktivitaetRaum) + (kuehlZeit * aktivitaetKuehl)
        
        guard gesamtLeistung > 0 else { return 0.0 }
        return (basisKonstante * (mehl / 100.0)) / gesamtLeistung
    }

    // 3. BENUTZEROBERFLÄCHE
    var body: some View {
        NavigationStack {
            Form {
                // --- BERECHNETE REZEPTUR ---
                Section(header: Text("Zutaten")) {
                    HStack {
                        Text("Mehl")
                        Spacer()
                        Text("\(mehl, specifier: "%.1f") g").bold()
                    }
                    HStack {
                        Text("Wasser")
                        Spacer()
                        Text("\(wasser, specifier: "%.1f") g").bold()
                    }
                    HStack {
                        Text("Salz")
                        Spacer()
                        Text("\(salz, specifier: "%.2f") g").bold()
                    }
                    HStack {
                        Text("Frischhefe")
                        Spacer()
                        Text("\(hefe, specifier: "%.2f") g").bold().foregroundColor(.orange)
                    }
                    HStack {
                        
                    }
                }
                
                // --- EINGABEN TEIG ---
                Section(header: Text("Teig-Einstellungen")) {
                    VStack(alignment: .leading) {
                        Text("Teiggewicht: \(Int(teigGewicht)) g")
                        Slider(value: $teigGewicht, in: 100...2000, step: 10)
                    }
                    VStack(alignment: .leading) {
                        Text("Hydration: \(Int(wasserProzent)) %")
                        Slider(value: $wasserProzent, in: 50...90, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Salz: \(salzProzent, specifier: "%.1f") %")
                        Slider(value: $salzProzent, in: 1.0...4.0, step: 0.1)
                    }
                }
                
                // --- EINGABEN REIFUNG ---
                Section(header: Text("Gärzeit & Temperatur")) {
                    Stepper("Raumzeit: \(Int(raumZeit)) Std.", value: $raumZeit, in: 0...48)
                    Stepper("Raumtemp: \(Int(raumTemp)) °C", value: $raumTemp, in: 10...30)
                    
                    Stepper("Kühlzeit: \(Int(kuehlZeit)) Std.", value: $kuehlZeit, in: 0...72)
                    Stepper("Kühltemp: \(Int(kuehlTemp)) °C", value: $kuehlTemp, in: 1...10)
                }
            }
            .navigationTitle("Teigrechner")
        }
    }
}

#Preview {
    CalculateView()
}
