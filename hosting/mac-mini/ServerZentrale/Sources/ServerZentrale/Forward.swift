import Foundation

/// Eine Weiterleitung: eine Adresse (z. B. ha.guderjahn.homeip.net) wird an ein Gerät im Heimnetz weitergereicht.
struct Forward: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Vollständige Adresse ohne https://, z. B. "ha.guderjahn.homeip.net"
    var host: String
    /// Ziel im Heimnetz, z. B. "192.168.96.90:8123" oder "https://192.168.96.202:8006"
    var target: String
    /// Optionaler Passwortschutz (Benutzername + bcrypt-Hash, wie von "caddy hash-password" erzeugt)
    var user: String = ""
    var passwordHash: String = ""
    /// Für Geräte mit selbst ausgestelltem Zertifikat (z. B. Proxmox)
    var skipTLSVerify: Bool = false

    var isProtected: Bool { !user.isEmpty && !passwordHash.isEmpty }
    var url: URL? { URL(string: "https://\(host)/") }

    // MARK: Prüfen der Eingaben (verhindert kaputte Caddy-Dateien)

    static func validHost(_ s: String) -> Bool {
        s.range(of: #"^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$"#, options: .regularExpression) != nil
    }
    static func validTarget(_ s: String) -> Bool {
        s.range(of: #"^(https?://)?[A-Za-z0-9.\-]+(:[0-9]{1,5})?$"#, options: .regularExpression) != nil
    }
    static func validUser(_ s: String) -> Bool {
        s.range(of: #"^[A-Za-z0-9._\-]+$"#, options: .regularExpression) != nil
    }
    static func validHash(_ s: String) -> Bool {
        s.range(of: #"^\$2[aby]?\$[0-9]{2}\$[./A-Za-z0-9]{53}$"#, options: .regularExpression) != nil
    }

    var problems: [String] {
        var p: [String] = []
        if !Self.validHost(host) { p.append("Adresse ungültig (nur Kleinbuchstaben, Ziffern, Punkte, Bindestriche)") }
        if !Self.validTarget(target) { p.append("Ziel ungültig (z. B. 192.168.96.90:8123)") }
        if !user.isEmpty || !passwordHash.isEmpty {
            if !Self.validUser(user) { p.append("Benutzername ungültig") }
            if !Self.validHash(passwordHash) { p.append("Passwort fehlt") }
        }
        return p
    }

    /// Caddy-Block für diese Weiterleitung
    var caddyBlock: String {
        var lines = ["\(host) {"]
        if isProtected {
            lines += ["\tbasic_auth {", "\t\t\(user) \(passwordHash)", "\t}"]
        }
        if skipTLSVerify {
            lines += ["\treverse_proxy \(target) {", "\t\ttransport http {", "\t\t\ttls_insecure_skip_verify", "\t\t}", "\t}"]
        } else {
            lines.append("\treverse_proxy \(target)")
        }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func caddyFile(for forwards: [Forward]) -> String {
        "# Wird von der App „Server-Zentrale“ erzeugt. Bitte nicht von Hand ändern.\n\n"
            + forwards.map(\.caddyBlock).joined(separator: "\n\n") + "\n"
    }
}

/// Liest ein bestehendes Caddyfile (z. B. vom Raspberry) und macht daraus Weiterleitungen.
/// Versteht: Adresszeile, basicauth/basic_auth mit einem Benutzer, reverse_proxy, tls_insecure_skip_verify.
enum CaddyImporter {
    struct Result {
        var forwards: [Forward] = []
        var skipped: [String] = []
    }

    static func parse(_ text: String, replaceLocalhostWith localIP: String) -> Result {
        var result = Result()
        var depth = 0
        var current: Forward?
        var inAuth = false

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            let opens = line.filter { $0 == "{" }.count
            let closes = line.filter { $0 == "}" }.count
            let words = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

            if depth == 0, opens > 0, let first = words.first, first != "{" {
                // Neue Seite, z. B. "https://ha.guderjahn.homeip.net {"
                var host = first.lowercased()
                for prefix in ["https://", "http://"] where host.hasPrefix(prefix) { host.removeFirst(prefix.count) }
                if let colon = host.firstIndex(of: ":") { host = String(host[..<colon]) }
                current = Forward(host: host, target: "")
            } else if depth >= 1, current != nil {
                if words.first == "basicauth" || words.first == "basic_auth" {
                    inAuth = true
                } else if inAuth, words.count == 2, words[0] != "}" {
                    current?.user = words[0]
                    current?.passwordHash = words[1]
                } else if words.first == "reverse_proxy", words.count >= 2 {
                    var target = words[1]
                    for local in ["127.0.0.1", "localhost"] where target.contains(local) {
                        // Ziel lag auf dem Raspberry selbst: ohne dessen IP nicht übernehmbar
                        target = localIP.isEmpty ? "" : target.replacingOccurrences(of: local, with: localIP)
                    }
                    current?.target = target
                } else if words.first == "tls_insecure_skip_verify" {
                    current?.skipTLSVerify = true
                }
            }

            depth += opens - closes
            if inAuth, closes > 0, depth <= 1 { inAuth = false }
            if depth == 0, let finished = current {
                if finished.problems.isEmpty {
                    result.forwards.append(finished)
                } else {
                    result.skipped.append(finished.host.isEmpty ? "(unbekannt)" : finished.host)
                }
                current = nil
            }
        }
        return result
    }
}
