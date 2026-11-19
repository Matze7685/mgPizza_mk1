import Foundation
import Observation

/// Speichert die Weiterleitungen in ~/.mgpizza/weiterleitungen.json und erzeugt daraus
/// ~/.mgpizza/sites/weiterleitungen.caddy, das der Webserver über "import" einliest.
@MainActor
@Observable
final class ForwardStore {
    static let jsonFile = ServerModel.stateDir.appending(path: "weiterleitungen.json")
    static let caddySnippet = ServerModel.stateDir.appending(path: "sites/weiterleitungen.caddy")
    static let caddyfile = ServerModel.stateDir.appending(path: "Caddyfile")

    private(set) var forwards: [Forward] = []
    var lastError: String?
    var isApplying = false

    init() { load() }

    static var caddyBinary: String? {
        ["/opt/homebrew/bin/caddy", "/usr/local/bin/caddy"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func load() {
        guard let data = try? Data(contentsOf: Self.jsonFile) else { forwards = []; return }
        forwards = (try? JSONDecoder().decode([Forward].self, from: data)) ?? []
    }

    // MARK: Ändern (jede Änderung wird geprüft und sofort angewendet)

    func save(_ forward: Forward) async -> Bool {
        var list = forwards
        if let i = list.firstIndex(where: { $0.id == forward.id }) { list[i] = forward } else { list.append(forward) }
        return await apply(list)
    }

    func delete(_ forward: Forward) async -> Bool {
        await apply(forwards.filter { $0.id != forward.id })
    }

    func add(_ new: [Forward]) async -> Bool {
        var list = forwards
        for f in new {
            if let i = list.firstIndex(where: { $0.host == f.host }) { list[i] = f } else { list.append(f) }
        }
        return await apply(list)
    }

    /// Schreibt die neue Konfiguration, prüft sie mit "caddy validate" und startet den Webserver neu.
    /// Ist sie ungültig, bleibt die alte Konfiguration erhalten.
    private func apply(_ list: [Forward]) async -> Bool {
        lastError = nil
        let hosts = list.map(\.host)
        if Set(hosts).count != hosts.count { lastError = "Eine Adresse ist doppelt."; return false }
        if let bad = list.first(where: { !$0.problems.isEmpty }) {
            lastError = "\(bad.host): " + bad.problems.joined(separator: ", "); return false
        }
        guard let caddy = Self.caddyBinary else { lastError = "Caddy ist nicht installiert (einrichten.sh ausführen)."; return false }
        guard FileManager.default.fileExists(atPath: Self.caddyfile.path) else {
            lastError = "Noch nicht eingerichtet. Bitte zuerst einrichten.sh --domain … ausführen."; return false
        }

        isApplying = true
        defer { isApplying = false }

        let fm = FileManager.default
        try? fm.createDirectory(at: Self.caddySnippet.deletingLastPathComponent(), withIntermediateDirectories: true)
        let oldSnippet = try? Data(contentsOf: Self.caddySnippet)
        do {
            try Forward.caddyFile(for: list).write(to: Self.caddySnippet, atomically: true, encoding: .utf8)
        } catch {
            lastError = error.localizedDescription; return false
        }

        let check = await Shell.run(caddy, ["validate", "--config", Self.caddyfile.path, "--adapter", "caddyfile"])
        if !check.ok {
            if let oldSnippet { try? oldSnippet.write(to: Self.caddySnippet) } else { try? fm.removeItem(at: Self.caddySnippet) }
            let reason = check.output.split(separator: "\n").last.map(String.init) ?? check.output
            lastError = "Caddy lehnt die Einstellung ab: \(reason)"
            return false
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(list).write(to: Self.jsonFile, options: .atomic)
        } catch {
            lastError = error.localizedDescription; return false
        }
        forwards = list

        let restart = await Shell.run("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/\(ServerModel.webLabel)"])
        if !restart.ok { lastError = "Gespeichert, aber Neustart fehlgeschlagen: \(restart.output)" }
        return restart.ok
    }

    /// Erzeugt den Passwort-Hash für basic_auth.
    static func hashPassword(_ password: String) async -> String? {
        guard let caddy = caddyBinary else { return nil }
        let result = await Shell.run(caddy, ["hash-password", "--plaintext", password])
        let hash = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n").last.map(String.init) ?? ""
        return result.ok && Forward.validHash(hash) ? hash : nil
    }
}
