import Foundation

/// Friendly date and time text, e.g. "Sat, Sep 25" and "6:00 – 8:00 PM".
enum Format {
    static func dayShort(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func dayLong(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func timeRange(_ event: WeddingEvent) -> String? {
        guard let start = event.startTime else { return nil }
        if let end = event.endTime { return "\(time(start)) – \(time(end))" }
        return time(start)
    }

    /// "Sat, Sep 25 · 6:00 – 8:00 PM", or "Time not set" when details are missing.
    static func when(_ event: WeddingEvent, includeYear: Bool = false) -> String {
        guard let day = event.day else { return "Date not set" }
        let dayText = includeYear ? dayLong(day) : dayShort(day)
        return "\(dayText) · \(timeRange(event) ?? "Time not set")"
    }

    static func venue(_ event: WeddingEvent) -> String {
        event.venue.isEmpty ? "Location not set" : event.venue
    }

    static func price(_ value: Int) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}
