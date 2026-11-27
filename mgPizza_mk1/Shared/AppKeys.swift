//
//  AppKeys.swift
//  mgPizza_mk1
//

import Foundation

/// Namen der Einstellungen (UserDefaults / @AppStorage) an einer Stelle, damit sich kein Tippfehler einschleicht.
/// Die Texte selbst dürfen sich nicht ändern, sonst wären gespeicherte Werte weg.
nonisolated enum AppKeys {
    // Aktueller Anlass
    static let menuEventID = "menuEventID"
    static let menuTitle = "menuTitle"
    static let menuDate = "menuDate"
    static let menuHiddenPizzas = "menuHiddenPizzas"
    static let menuEventDone = "menuEventDone"
    static let menuFixedMode = "menuFixedMode"
    static let menuFixedExtras = "menuFixedExtras"
    static let guestNames = "guestNames"
    static let guestIntro = "guestIntro"
    static let guestOrdersClosed = "guestOrdersClosed"

    // Gästeseite / Firebase
    static let fbProject = "fbProject"
    static let fbKey = "fbKey"
    static let guestPageURL = "guestPageURL"

    // Teig & Ansicht
    static let doughSpeak = "doughSpeak"
    static let showDoughStatus = "showDoughStatus"
    static let mixerCapacity = "mixerCapacity"
    static let foldColumns = "foldColumns"
    static let foldShowNext = "foldShowNext"
    /// Intro-Animation (Ofen) beim App-Start
    static let showIntro = "showIntro"
}

/// Der Anlass, der gerade in der App offen ist (Werte liegen in den Einstellungen, siehe `AppKeys.menu…`/`guest…`)
nonisolated enum CurrentEvent {
    private static let keys = [AppKeys.menuEventID, AppKeys.menuTitle, AppKeys.guestNames, AppKeys.guestIntro,
                               AppKeys.guestOrdersClosed, AppKeys.menuHiddenPizzas, AppKeys.menuEventDone,
                               AppKeys.menuFixedMode, AppKeys.menuFixedExtras]

    static var id: String { UserDefaults.standard.string(forKey: AppKeys.menuEventID) ?? "" }

    /// Aktuellen Anlass leeren (nach dem Löschen); die Bestellzahlen setzt die Ansicht selbst zurück
    static func clear() {
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
    }
}
