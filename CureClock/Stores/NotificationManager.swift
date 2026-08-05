//
//  NotificationManager.swift
//  CureClock
//
//  Real local-notification scheduling for cure reminders: keep-the-surface-wet
//  nudges for the first days, and an alert at each strength milestone (walk-on,
//  strip formwork, remove props, 28-day full cure). UNUserNotificationCenter
//  only (iOS 10+, fully iOS 14 safe). No remote push.
//

import UserNotifications

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()
    private let reminderHour = 9
    /// Upper bound of the keep-wet slider — also the range of ids we clear on reschedule.
    private let maxKeepWetDays = 14

    init() { refreshStatus() }

    func refreshStatus() {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized
                                     || settings.authorizationStatus == .provisional)
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
        }
    }

    // MARK: - Scheduling

    private func prefix(_ pour: Pour) -> String { "cure.\(pour.id.uuidString)." }

    /// Every identifier this pour can ever own. Because they are deterministic we can
    /// clear them synchronously before adding the new ones — asking the centre for its
    /// pending requests first would race with the `add` calls below and, since the new
    /// requests share the same prefix, could delete the ones we just scheduled.
    private func allIdentifiers(for pour: Pour) -> [String] {
        let p = prefix(pour)
        var ids = CureMilestoneType.allCases.map { p + $0.rawValue }
        ids.append(contentsOf: (1...maxKeepWetDays).map { p + "wet.\($0)" })
        return ids
    }

    /// Schedules keep-wet nudges + milestone alerts for one pour. Safe to call at any
    /// time: the previous set for this pour is removed first, and past dates are skipped.
    func scheduleCureReminders(for pour: Pour, milestones: [MilestoneStatus], keepWetDays: Int) {
        cancel(for: pour)

        // Keep-wet daily reminders for the first N days.
        for day in 1...min(max(keepWetDays, 1), maxKeepWetDays) {
            let date = pour.pourDate.addingTimeInterval(Double(day) * 86_400)
            schedule(id: prefix(pour) + "wet.\(day)",
                     title: "Keep \(pour.name) damp",
                     body: "Day \(day): mist or cover the surface so it cures without cracking.",
                     fireDate: date)
        }

        // Milestone alerts. A milestone with no date (cure stalled by cold) is skipped.
        for m in milestones {
            guard let est = m.estDate else { continue }
            schedule(id: prefix(pour) + m.type.rawValue,
                     title: "\(pour.name): \(m.type.displayName)",
                     body: "\(m.type.detail) (≈\(Int(m.type.gatePercent))% strength). Estimate only — verify before loading.",
                     fireDate: est)
        }
    }

    /// Reminders are delivered at `reminderHour` on the day they fall due. If that
    /// moment has already passed we must not schedule it — the original code checked
    /// the raw due date, so anything due later *today* was silently moved back to 09:00
    /// this morning and never fired.
    private func schedule(id: String, title: String, body: String, fireDate: Date) {
        let cal = Calendar.current
        let now = Date()
        guard let fireMoment = deliveryMoment(for: fireDate, calendar: cal, now: now) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireMoment)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger),
                   withCompletionHandler: nil)
    }

    /// The morning of the due date, or the due date itself if that morning has gone but
    /// the milestone has not, or the next morning if both have. `nil` once the whole
    /// day is in the past — there is nothing useful left to deliver.
    func deliveryMoment(for dueDate: Date, calendar cal: Calendar = .current, now: Date = Date()) -> Date? {
        if let morning = cal.date(bySettingHour: reminderHour, minute: 0, second: 0, of: dueDate),
           morning > now {
            return morning
        }
        if dueDate > now { return dueDate }              // due later today, after 09:00
        return nil                                       // already past
    }

    func cancel(for pour: Pour) {
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers(for: pour))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Fires a one-off confirmation so the user immediately sees it working. A fixed
    /// identifier means tapping the button repeatedly replaces the pending test rather
    /// than queueing up a stack of them with no way to cancel.
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Builder Clock"
        content.body = "Reminders are on — you'll be nudged to cure and when each milestone is due."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [Self.testIdentifier])
        center.add(UNNotificationRequest(identifier: Self.testIdentifier, content: content, trigger: trigger),
                   withCompletionHandler: nil)
    }

    private static let testIdentifier = "cure.test"
}
