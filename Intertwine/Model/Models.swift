import Foundation

enum Role: String, Codable {
    case couple, guest
}

enum EventStatus: String, Codable {
    case draft, published
}

struct Wedding: Codable, Hashable {
    var coupleNames: String
    var date: Date
    var venue: String
    var hotelInfo: String
    var parkingInfo: String
}

struct WeddingEvent: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var type: String = "Welcome Party"
    var name: String = ""
    var welcomeMessage: String = ""
    var day: Date? = nil
    var startTime: Date? = nil
    var endTime: Date? = nil
    var venue: String = ""
    var directions: String = ""
    var dressCode: String = "Cocktail attire"
    var dressGuidance: String = ""
    var rsvpRequired: Bool = true
    var rsvpDeadline: Date? = nil
    var status: EventStatus = .draft

    /// Everything a guest needs before the event can be published.
    var missingDetails: [String] {
        var missing: [String] = []
        if name.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("name") }
        if day == nil { missing.append("date") }
        if startTime == nil { missing.append("start time") }
        if venue.trimmingCharacters(in: .whitespaces).isEmpty { missing.append("venue") }
        return missing
    }

    var isComplete: Bool { missingDetails.isEmpty }

    /// The moment the event starts, used for sorting and "next event".
    var startDate: Date? {
        guard let day else { return nil }
        guard let startTime else { return day }
        return Calendar.current.date(bySettingTime: startTime, on: day)
    }

    var endDate: Date? {
        guard let day, let endTime else { return nil }
        return Calendar.current.date(bySettingTime: endTime, on: day)
    }
}

struct Guest: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    /// How many people this invitation covers, including the guest.
    var partySize: Int = 1
}

struct RSVP: Codable, Hashable {
    var eventID: UUID
    var guestID: UUID
    var attending: Bool
    var partyCount: Int
    var note: String
    var updatedAt: Date = Date()
}

struct GuestQuestion: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var guestID: UUID
    var eventID: UUID?
    var text: String
    var askedAt: Date = Date()
    var answer: String? = nil
}

struct WeddingUpdate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var postedAt: Date = Date()
}

struct RegistryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var price: Int
    var purchased: Bool = false
}

/// Everything the app stores. Saved as one JSON file on the device.
struct AppData: Codable {
    var wedding: Wedding
    var events: [WeddingEvent]
    var guests: [Guest]
    var rsvps: [RSVP]
    var questions: [GuestQuestion]
    var updates: [WeddingUpdate]
    var registry: [RegistryItem]
    /// The guest whose view the app shows in guest mode (demo: Rosa).
    var currentGuestID: UUID
}

extension Calendar {
    /// Combines the calendar day of `day` with the clock time of `time`.
    func date(bySettingTime time: Date, on day: Date) -> Date? {
        let t = dateComponents([.hour, .minute], from: time)
        return date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day)
    }
}
