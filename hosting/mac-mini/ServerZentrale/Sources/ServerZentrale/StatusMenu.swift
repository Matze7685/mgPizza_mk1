import SwiftUI
import AppKit

struct StatusMenu: View {
    let model: ServerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Server-Zentrale").font(.headline)
                Spacer()
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Jetzt prüfen")
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.checks) { check in
                    CheckRow(check: check)
                }
                if model.checks.isEmpty {
                    ProgressView().controlSize(.small)
                }
            }

            if let date = model.lastUpdate {
                Text("Geprüft: \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            Button("Pizzaseite aktualisieren", systemImage: "arrow.down.circle") {
                Task { await model.updatePizzaPage() }
            }
            Button("Webserver neu starten", systemImage: "arrow.triangle.2.circlepath") {
                Task { await model.restartWebserver() }
            }
            Button("Protokolle anzeigen", systemImage: "doc.text.magnifyingglass") {
                NSWorkspace.shared.open(ServerModel.logsDir)
            }
            Button("Einstellungsordner öffnen", systemImage: "folder") {
                NSWorkspace.shared.open(ServerModel.stateDir)
            }

            if let message = model.message {
                Text(message).font(.caption).foregroundStyle(.secondary).lineLimit(4)
            }

            Divider()

            Button("Beenden", systemImage: "power") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .disabled(model.isBusy)
        .padding(14)
        .frame(width: 300)
    }
}

private struct CheckRow: View {
    let check: ServerModel.Check

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: check.health.symbol)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                if let url = check.url {
                    Link(check.title, destination: url)
                } else {
                    Text(check.title)
                }
                if let detail = check.health.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var color: Color {
        switch check.health {
        case .ok: .green
        case .warning: .orange
        case .down: .red
        case .unknown: .secondary
        }
    }
}
