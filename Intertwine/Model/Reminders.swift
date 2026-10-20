import Foundation
import UserNotifications

/// Reminders on the couple's phone: the day before an event's RSVPs are due, and two hours
/// before each event starts. They're worked out again after every change and sync, so they
/// always match the latest events and replies. Demo weddings get none.
enum Reminders {
    private static let prefix = "intertwine.reminder."

    /// Asks once whether the app may show reminders. iOS remembers the answer.
    static func askPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func update(for data: AppData) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)

        guard data.isDemo == false else { return }
        let settings = await center.notificationSettings()
        guard [.authorized, .provisional].contains(settings.authorizationStatus) else { return }

        let now = Date()
        for event in data.events where event.status == .published {
            // RSVPs due tomorrow, at 9 in the morning.
            if event.rsvpRequired, let deadline = event.rsvpDeadline,
               let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: deadline),
               let at = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: dayBefore), at > now {
                let replied = Set(data.rsvps.filter { $0.eventID == event.id }.map(\.guestID))
                let waiting = data.guests.filter { !replied.contains($0.id) }.count
                let body = waiting == 0
                    ? "Everyone has replied."
                    : "\(waiting) \(waiting == 1 ? "guest hasn’t" : "guests haven’t") replied yet. You can send them their link again from Guests."
                await add(id: "rsvp.\(event.id)", title: "RSVPs for the \(event.name) are due tomorrow", body: body, at: at)
            }
            // Starting in two hours.
            if let start = event.startDate, let at = Calendar.current.date(byAdding: .hour, value: -2, to: start), at > now {
                let place = event.venue.isEmpty ? "" : " at \(event.venue)"
                await add(id: "start.\(event.id)", title: "\(event.name) starts at \(Format.time(start))",
                          body: "In two hours\(place).", at: at)
            }
        }
    }

    private static func add(id: String, title: String, body: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let request = UNNotificationRequest(identifier: prefix + id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
    }
}
