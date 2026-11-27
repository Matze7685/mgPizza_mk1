//
//  Theme.swift
//  mgPizza_mk1
//
//  Gemeinsame Farben der App, passend zur Gästeseite (Tomatenrot, Basilikumgrün, Mozzarella-Creme).
//  Die Akzentfarbe selbst liegt in Assets › AccentColor.
//

import SwiftUI

enum Theme {
    /// Teig/Timer: alles, was gerade läuft
    static let dough = Color.orange
    /// Hintergrund für laufende Rezepte in Listen
    static let doughBackground = Color.orange.opacity(0.12)
    /// Aktueller Schritt im Fortschritt
    static let doughHighlight = Color.orange.opacity(0.25)
    static let basil = Color(red: 0.18, green: 0.42, blue: 0.23)
    static let cream = Color(red: 0.98, green: 0.96, blue: 0.89)
    /// Papierfarbe der Speisekarte (PDF)
    static let paper = Color(red: 1, green: 0.98, blue: 0.94)
}
