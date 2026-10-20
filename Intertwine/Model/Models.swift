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
    /// Built-in photo of the demo couple (an image in Assets.xcassets/Brand).
    var couplePhoto: String? = nil
    /// Photo of the two of them that the couple picked, saved by `PhotoStore`. Shown instead of
    /// `couplePhoto`.
    var couplePhotoFileName: String? = nil
    /// Rough guest count from onboarding, for registry price suggestions.
    var expectedGuests: Int? = nil
}

/// Who set up the wedding (Figma: O3 · Create account).
struct CoupleAccount: Codable, Hashable {
    var name: String
    var partnerName: String
    var email: String
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
    /// Cover photo the couple picked, saved by `PhotoStore`.
    var photoFileName: String? = nil
    /// Built-in photo for the demo events (an image in Assets.xcassets/Brand), shown until
    /// the couple picks their own.
    var samplePhoto: String? = nil

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
    /// The private part of the guest's website link. Set when the guest is added.
    var inviteCode: String? = nil

    var inviteLink: URL? { inviteCode.map(Supabase.inviteLink(for:)) }
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
    var account: CoupleAccount? = nil
    /// False once a couple sets up their own wedding. Nil in data saved before onboarding existed,
    /// which was always the demo.
    var isDemo: Bool? = nil

    // Syncing with the database (see Sync.swift). Only for a signed-in couple's own wedding.
    /// The wedding's id in the database. Nil when it lives only on this phone.
    var remoteWeddingID: UUID? = nil
    /// True when there are changes on the phone the database doesn't have yet.
    var needsUpload: Bool? = nil
    var deletedEventIDs: [UUID]? = nil
    var deletedGuestIDs: [UUID]? = nil
}

extension Calendar {
    /// Combines the calendar day of `day` with the clock time of `time`.
    func date(bySettingTime time: Date, on day: Date) -> Date? {
        let t = dateComponents([.hour, .minute], from: time)
        return date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day)
    }
}
