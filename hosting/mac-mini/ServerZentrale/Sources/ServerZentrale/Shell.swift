import Foundation

/// Führt Kommandozeilen-Befehle aus (launchctl, git).
enum Shell {
    struct Result: Sendable {
        let status: Int32
        let output: String
        var ok: Bool { status == 0 }
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String], in directory: URL? = nil) async -> Result {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            if let directory { process.currentDirectoryURL = directory }
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do { try process.run() } catch {
                return Result(status: -1, output: error.localizedDescription)
            }
            // Erst lesen, dann warten: sonst kann eine volle Pipe den Prozess blockieren.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return Result(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self))
        }.value
    }
}
