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
    /// The couple photo's web address when it was picked on another phone.
    var remotePhotoURL: String? = nil
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
    /// The cover photo's web address when it was picked on another phone (so this phone
    /// doesn't have the file). Kept so syncing from here doesn't remove it.
    var remotePhotoURL: String? = nil

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
    /// What the gift costs, or for a cash fund, the goal.
    var price: Int
    /// Marked bought by the couple (for example, a gift that came from another store).
    var purchased: Bool = false
    /// A cash fund guests put money toward, rather than one gift one guest buys.
    var isFund: Bool = false
    /// Where guests can buy it. Empty when there isn't one.
    var link: String = ""
    /// A line for guests, e.g. "Queen size, in oat."
    var note: String = ""

    init(id: UUID = UUID(), name: String, price: Int, purchased: Bool = false, isFund: Bool = false,
         link: String = "", note: String = "") {
        self.id = id
        self.name = name
        self.price = price
        self.purchased = purchased
        self.isFund = isFund
        self.link = link
        self.note = note
    }

    // Data saved before funds and links existed doesn't have them.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        price = try c.decode(Int.self, forKey: .price)
        purchased = try c.decodeIfPresent(Bool.self, forKey: .purchased) ?? false
        isFund = try c.decodeIfPresent(Bool.self, forKey: .isFund) ?? name.localizedCaseInsensitiveContains("fund")
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    /// The store link as a web address guests can open, if it is one.
    var linkURL: URL? {
        let text = link.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        let full = text.contains("://") ? text : "https://" + text
        guard let url = URL(string: full), url.host != nil, ["http", "https"].contains(url.scheme) else { return nil }
        return url
    }
}

/// One guest's gift: "I'll get this" for a gift, or an amount toward a cash fund.
/// Made on the website; the couple tracks thank-you notes (Figma: CR4 · Track gifts).
struct RegistryGift: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var itemID: UUID
    var guestID: UUID?
    var amount: Int
    var note: String = ""
    var givenAt: Date = Date()
    var thankYouSent: Bool = false
}

/// A registry the couple keeps at another store (Figma: CR3 · Link a registry).
struct RegistryLink: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var url: String
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
    /// Who gave what. Nil in data saved before gifts existed.
    var gifts: [RegistryGift]? = nil
    var registryLinks: [RegistryLink]? = nil
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
    var deletedRegistryIDs: [UUID]? = nil
    var deletedLinkIDs: [UUID]? = nil
    /// Gifts whose thank-you checkbox changed on the phone, still to send to the database.
    var changedGiftIDs: [UUID]? = nil
    /// Photos already copied to the database, so each one is uploaded only once.
    var uploadedPhotos: [String]? = nil
}

extension Calendar {
    /// Combines the calendar day of `day` with the clock time of `time`.
    func date(bySettingTime time: Date, on day: Date) -> Date? {
        let t = dateComponents([.hour, .minute], from: time)
        return date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: day)
    }
}
