//
//  TimerStatusView.swift
//  mgPizza_mk1
//

import ActivityKit
import SwiftData
import SwiftUI
import UserNotifications

/// Kontrolle: Welche Erinnerungen sind geplant, laufen Live Activities, sind Berechtigungen erteilt?
struct TimerStatusView: View {
    struct PendingReminder: Identifiable {
        let id: String
        let title: String
        let body: String
        let date: Date?
    }

    @EnvironmentObject var ovenMonitor: OvenMonitor
    @AppStorage("doughSpeak") private var doughSpeak = false
    @Query(filter: #Predicate<RecipeSetupData> { $0.kneadStepEnd != nil }) private var kneading: [RecipeSetupData]

    @State private var authorization: UNAuthorizationStatus = .notDetermined
    @State private var timeSensitive: UNNotificationSetting = .notSupported
    @State private var reminders: [PendingReminder] = []
    @State private var activities: [(title: String, subtitle: String, end: Date)] = []
    @State private var liveActivitiesEnabled = false

    var body: some View {
        List {
            Section("Permissions") {
                statusRow("Notifications", ok: authorization == .authorized || authorization == .provisional,
                          detail: authorizationText)
                statusRow("Time Sensitive", ok: timeSensitive == .enabled,
                          detail: timeSensitive == .enabled ? String(localized: "On") : String(localized: "Off – alarms may be delayed in Focus mode"))
                statusRow("Live Activities", ok: liveActivitiesEnabled,
                          detail: liveActivitiesEnabled ? String(localized: "On") : String(localized: "Off – enable in iOS Settings → mgPizza"))
                if authorization == .denied || !liveActivitiesEnabled {
                    Button("Open iOS Settings", systemImage: "gear") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Section {
                if reminders.isEmpty {
                    Label("No reminders scheduled", systemImage: "bell.slash")
                        .foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 0) {
                        ForEach(reminders) { reminder in
                            reminderRow(reminder, now: context.date)
                            if reminder.id != reminders.last?.id { Divider().padding(.vertical, 6) }
                        }
                    }
                }
            } header: {
                Text("Scheduled reminders (\(reminders.count))")
            } footer: {
                Text("These are stored by iOS and arrive even when the app is closed.")
            }

            Section("Dynamic Island") {
                if activities.isEmpty {
                    Label("No Live Activity running", systemImage: "circle.dashed")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(activities.enumerated()), id: \.offset) { _, activity in
                    let now = Date()
                    HStack {
                        VStack(alignment: .leading) {
                            Text(activity.title).font(.headline)
                            Text(activity.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(timerInterval: now...max(activity.end, now), countsDown: true)
                            .monospacedDigit()
                            .frame(maxWidth: 90, alignment: .trailing)
                    }
                }
            }

            Section("App") {
                if kneading.isEmpty {
                    statusRow("Knead timer", ok: false, detail: String(localized: "Not running"))
                }
                ForEach(kneading) { recipe in
                    statusRow("Knead timer", ok: true,
                              detail: "\(recipe.displayName): " + String(localized: "Running until \((recipe.kneadStepEnd ?? Date()).formatted(date: .omitted, time: .shortened))"))
                }
                statusRow("Speaker announcements", ok: doughSpeak,
                          detail: doughSpeak ? String(localized: "On – only while the app is running") : String(localized: "Off"))
                statusRow("Oven probe", ok: ovenMonitor.lastUpdate.map { Date().timeIntervalSince($0) < 10 } == true,
                          detail: ovenMonitor.isActive ? ovenMonitor.status : String(localized: "Off"))
            }
        }
        .navigationTitle("Timer Status")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var authorizationText: String {
        switch authorization {
        case .authorized: return String(localized: "Allowed")
        case .denied: return String(localized: "Denied – no reminders will appear!")
        case .provisional: return String(localized: "Provisional (silent)")
        case .ephemeral: return String(localized: "Temporary")
        default: return String(localized: "Not asked yet")
        }
    }

    private func statusRow(_ title: LocalizedStringKey, ok: Bool, detail: String) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ok ? .green : .orange)
            VStack(alignment: .leading) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func reminderRow(_ reminder: PendingReminder, now: Date) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "bell.fill").foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title).font(.subheadline).bold()
                Text(reminder.body).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if let date = reminder.date {
                VStack(alignment: .trailing) {
                    Text(date, format: .dateTime.weekday().hour().minute()).font(.caption)
                    Text(remaining(date.timeIntervalSince(now))).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func remaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private func load() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        let items = pending.map { request -> PendingReminder in
            let date = (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            return PendingReminder(id: request.identifier, title: request.content.title,
                                   body: request.content.body, date: date)
        }
        .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }

        await MainActor.run {
            authorization = settings.authorizationStatus
            timeSensitive = settings.timeSensitiveSetting
            reminders = items
            liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            activities = Activity<PizzaActivityAttributes>.activities.map {
                ($0.content.state.title, $0.content.state.subtitle, $0.content.state.endDate)
            }
        }
    }
}

#Preview {
    NavigationStack { TimerStatusView() }
        .environmentObject(OvenMonitor())
}

/// Kurzanzeige im Activity-Tab: Anzahl geplanter Erinnerungen + Berechtigung
struct TimerStatusBadge: View {
    @State private var count = 0
    @State private var allowed = true

    var body: some View {
        HStack {
            Label("Timer Status", systemImage: allowed ? "checkmark.shield" : "exclamationmark.shield")
                .foregroundStyle(allowed ? Color.primary : Color.orange)
            Spacer()
            Text(allowed ? String(localized: "\(count) reminders scheduled") : String(localized: "Notifications off!"))
                .font(.caption)
                .foregroundStyle(allowed ? Color.secondary : Color.orange)
        }
        .task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            let pending = await center.pendingNotificationRequests()
            await MainActor.run {
                allowed = settings.authorizationStatus != .denied
                count = pending.count
            }
        }
    }
}
