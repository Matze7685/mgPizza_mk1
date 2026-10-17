//
//  SettingsView.swift
//  mgPizza_mk1
//
//  Created by Guderjahn Mathias on 29.07.26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("Oven") {
                NavigationLink {
                    BLEDebugView()
                } label: {
                    Label("Bluetooth Test (Ooni Hub)", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
}
