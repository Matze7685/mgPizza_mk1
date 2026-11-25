//
//  PizzaLiveActivity.swift
//  PizzaWidget (Widget Extension)
//
//  Anzeige in Dynamic Island und auf dem Sperrbildschirm.
//

import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PizzaWidgetBundle: WidgetBundle {
    var body: some Widget {
        PizzaLiveActivity()
    }
}

struct PizzaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PizzaActivityAttributes.self) { context in
            // Sperrbildschirm / Banner
            HStack(spacing: 12) {
                Image(systemName: context.state.symbol)
                    .font(.title)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(context.state.title).font(.headline)
                    Text(context.state.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                countdown(context.state.endDate)
                    .font(.system(.title, design: .rounded).weight(.semibold))
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.6))
            .activitySystemActionForegroundColor(.orange)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.symbol)
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state.endDate)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(context.state.title).font(.headline)
                        Text(context.state.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(.orange)
            } compactTrailing: {
                // Feste Breite: Ohne sie reserviert iOS zu wenig Platz, der Countdown bricht
                // senkrecht um bzw. wird zu „2:…“ abgeschnitten.
                countdown(context.state.endDate)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: compactWidth(context.state.endDate), alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.symbol)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func countdown(_ end: Date) -> some View {
        let now = Date()
        return Text(timerInterval: now...max(end, now), countsDown: true)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// Platz für „12:34“ bzw. „1:23:45“ (ab einer Stunde)
    private func compactWidth(_ end: Date) -> CGFloat {
        end.timeIntervalSinceNow >= 3600 ? 64 : 44
    }
}
