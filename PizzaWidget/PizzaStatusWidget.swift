//
//  PizzaStatusWidget.swift
//  PizzaWidget (Widget Extension)
//
//  Homescreen- und Sperrbildschirm-Widget: nächster Teigschritt bzw. nächster Anlass.
//  Daten kommen aus der App (WidgetSnapshot in der App Group).
//

import SwiftUI
import WidgetKit

struct PizzaStatusEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
}

struct PizzaStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> PizzaStatusEntry {
        PizzaStatusEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (PizzaStatusEntry) -> Void) {
        completion(PizzaStatusEntry(date: .now, snapshot: context.isPreview ? .preview : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PizzaStatusEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let now = Date()
        // Ein Eintrag jetzt und einer zu jedem kommenden Teigschritt, damit das Widget von selbst weiterschaltet
        var dates = [now]
        dates += (snapshot?.doughs.flatMap(\.steps).map(\.date) ?? []).filter { $0 > now }.sorted()
        let entries = dates.map { PizzaStatusEntry(date: $0, snapshot: snapshot) }
        let refresh = min(dates.last.map { $0.addingTimeInterval(60) } ?? now, now.addingTimeInterval(3600 * 6))
        completion(Timeline(entries: entries, policy: .after(max(refresh, now.addingTimeInterval(900)))))
    }
}

struct PizzaStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PizzaStatusWidget", provider: PizzaStatusProvider()) { entry in
            PizzaStatusView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.99, green: 0.95, blue: 0.88), Color(red: 0.98, green: 0.88, blue: 0.78)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .configurationDisplayName("Pizza status")
        .description("Next dough step and your next pizza event.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct PizzaStatusView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PizzaStatusEntry

    private var dough: WidgetSnapshot.Dough? { entry.snapshot?.doughs.first }
    private var step: WidgetSnapshot.Step? {
        dough?.steps.first { $0.date > entry.date } ?? dough?.steps.last
    }
    private var event: WidgetSnapshot.Event? {
        guard let event = entry.snapshot?.event, event.date > entry.date.addingTimeInterval(-6 * 3600) else { return nil }
        return event
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
        case .systemMedium:
            HStack(alignment: .top, spacing: 16) {
                doughBlock.frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                eventBlock.frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            if dough != nil { doughBlock } else { eventBlock }
        }
    }

    // MARK: Bausteine

    private var doughBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Dough", systemImage: "timer").font(.caption.bold()).foregroundStyle(.orange)
            if let dough {
                Text(dough.name).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                if let step {
                    Label(step.title, systemImage: step.symbol).font(.caption).foregroundStyle(.secondary)
                    if step.date > entry.date {
                        Text(step.date, style: .timer).font(.title3.monospacedDigit().bold())
                    } else {
                        Text(step.date, style: .time).font(.title3.bold())
                    }
                } else if !dough.status.isEmpty {
                    Text(dough.status).font(.title3.bold())
                }
            } else {
                Text("No dough running").font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var eventBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Event", systemImage: "party.popper").font(.caption.bold()).foregroundStyle(.red)
            if let event {
                Text(event.title).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                Text(event.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
                Text(event.date, style: .relative).font(.caption.bold())
                Text(event.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            } else {
                Text("No event planned").font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let dough, let step, step.date > entry.date {
            VStack(alignment: .leading) {
                Text(dough.name).font(.headline).lineLimit(1)
                Text(step.title).font(.caption)
                Text(step.date, style: .timer).font(.caption.monospacedDigit())
            }
        } else if let event {
            VStack(alignment: .leading) {
                Text(event.title).font(.headline).lineLimit(1)
                Text(event.date, style: .relative).font(.caption)
                Text(event.detail).font(.caption).lineLimit(1)
            }
        } else {
            Text("🍕 Nothing planned")
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let step, step.date > entry.date {
            Text("🍕 \(step.title) \(step.date, style: .relative)")
        } else if let event {
            Text("🍕 \(event.title) \(event.date, style: .relative)")
        } else {
            Text("🍕 Pizza")
        }
    }
}

extension WidgetSnapshot {
    static var preview: WidgetSnapshot {
        WidgetSnapshot(doughs: [Dough(name: "8× 250 g", status: "",
                                      steps: [Step(title: "Out of the fridge", date: .now.addingTimeInterval(3 * 3600), symbol: "refrigerator")])],
                       event: Event(title: "Pizza night", date: .now.addingTimeInterval(2 * 86400), detail: "8 of 12 guests ordered"))
    }
}
