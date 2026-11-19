import Foundation
import Network

/// Prüft, ob ein Gerät im Heimnetz auf seinem Port antwortet (nur Verbindungsaufbau, keine Anmeldung).
enum TCPProbe {
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func run(_ block: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true
            block()
        }
    }

    static func reachable(target: String, timeout: TimeInterval = 3) async -> Bool {
        var text = target
        var defaultPort = 80
        if text.hasPrefix("https://") { text.removeFirst(8); defaultPort = 443 }
        else if text.hasPrefix("http://") { text.removeFirst(7) }
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        guard let host = parts.first, !host.isEmpty else { return false }
        let portNumber = parts.count > 1 ? Int(parts[1]) ?? defaultPort : defaultPort
        guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: portNumber)) else { return false }

        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
            let once = Once()
            let finish: @Sendable (Bool) -> Void = { value in
                once.run {
                    connection.cancel()
                    continuation.resume(returning: value)
                }
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: finish(true)
                case .failed, .cancelled: finish(false)
                default: break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }
}
