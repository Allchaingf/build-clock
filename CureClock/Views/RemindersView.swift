//
//  RemindersView.swift
//  CureClock
//
//  Feature 13: real local reminders via UNUserNotificationCenter — keep the
//  surface wet, walk-on, strip formwork, remove props and the 28-day mark.
//  iOS 14 safe.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    @AppStorage("remindersEnabled") private var remindersEnabled = false
    @State private var keepWetDays: Double = Double(MixConstants.defaultKeepWetDays)
    @State private var loaded = false

    var body: some View {
        ScreenScaffold("Reminders", subtitle: "Cure & milestone alerts") {
            statusCard
            keepWetCard
            scheduledCard
            CardView {
                ActionButton(title: "Send Test Notification", systemImage: "bell.fill", kind: .secondary) {
                    if notifications.isAuthorized { notifications.sendTestNotification() }
                    else { requestThen { notifications.sendTestNotification() } }
                }
            }
        }
        .navigationBarTitle("Reminders", displayMode: .inline)
        .onAppear {
            if !loaded { keepWetDays = Double(store.settings.keepWetDays); loaded = true }
            notifications.refreshStatus()
        }
    }

    private var statusCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionHeader(title: "Cure reminders",
                                  subtitle: notifications.isAuthorized ? "Notifications allowed" : "Permission needed",
                                  systemImage: "bell.badge.fill")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { remindersEnabled },
                        set: { newValue in setEnabled(newValue) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                }
                Text(remindersEnabled
                     ? "You'll be nudged to keep pours damp and alerted at each strength milestone."
                     : "Turn on to schedule keep-wet nudges and milestone alerts for every saved pour.")
                    .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var keepWetCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("KEEP-WET DAYS").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                    Spacer()
                    Text("\(Int(keepWetDays)) days").font(Theme.mono(14)).foregroundColor(Theme.accentHi)
                }
                Slider(value: $keepWetDays, in: 1...14, step: 1, onEditingChanged: { editing in
                    if !editing { persistKeepWet() }
                })
                .accentColor(Theme.accent)
                Text("Daily reminder to mist or cover the surface for the first \(Int(keepWetDays)) days.")
                    .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            }
        }
    }

    private var scheduledCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Upcoming alerts", systemImage: "calendar.badge.clock")
                if let pour = store.primaryPour {
                    Text(pour.name).font(Theme.caption(12)).foregroundColor(Theme.accent)
                    ForEach(store.milestones(for: pour)) { m in
                        HStack {
                            Image(systemName: m.type.icon).foregroundColor(m.type.color).font(.system(size: 13))
                            Text(m.type.displayName).font(Theme.body(14)).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Text(m.estDate.map { Formatters.dayMonth($0) } ?? "stalled")
                                .font(Theme.mono(12))
                                .foregroundColor(m.reached ? Theme.success : Theme.textSecondary)
                        }
                        .padding(.vertical, 2)
                    }
                } else {
                    Text("No pours to schedule yet.").font(Theme.caption(12)).foregroundColor(Theme.textDisabled)
                }
            }
        }
    }

    // MARK: - Actions

    private func setEnabled(_ on: Bool) {
        if on {
            requestThen {
                remindersEnabled = true
                rescheduleAll()
            }
        } else {
            remindersEnabled = false
            notifications.cancelAll()
        }
    }

    private func requestThen(_ action: @escaping () -> Void) {
        if notifications.isAuthorized { action(); return }
        notifications.requestAuthorization { granted in
            if granted { action() } else { remindersEnabled = false }
        }
    }

    private func rescheduleAll() {
        for pour in store.pours {
            notifications.scheduleCureReminders(for: pour,
                                                milestones: store.milestones(for: pour),
                                                keepWetDays: store.settings.keepWetDays)
        }
    }

    private func persistKeepWet() {
        var s = store.settings
        s.keepWetDays = Int(keepWetDays)
        store.updateSettings(s)
        if remindersEnabled { rescheduleAll() }
    }
}
