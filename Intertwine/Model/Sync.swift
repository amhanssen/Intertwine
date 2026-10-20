import Foundation

/// Moves a couple's wedding between this phone and the database.
///
/// The phone saves every change first (so the app works offline), marks that it has
/// something to upload, and then syncs: upload the couple's rows, then download everything,
/// which brings in guests' RSVPs, questions and gifts from the website. Photos the couple
/// picks are copied to the "photos" storage bucket so the website can show them.
enum Sync {
    /// Uploads everything the couple owns. Adds or replaces rows by id; never deletes rows it
    /// doesn't know about, so a partner's new events on another phone are safe.
    /// Returns the photos it uploaded, so the next sync can skip them.
    static func upload(_ data: AppData, weddingID: UUID, as db: REST) async throws -> [String] {
        try await db.upsert("weddings", [WeddingRow(data.wedding, id: weddingID, owner: db.session.userID)])
        // Photos go up once the wedding exists (the storage rules check it), and before the
        // events that point to them.
        let uploaded = try await uploadPhotos(data, weddingID: weddingID, as: db)
        try await db.upsert("events", data.events.map { EventRow($0, wedding: weddingID) })
        try await db.upsert("guests", data.guests.map { GuestRow($0, wedding: weddingID) })
        try await db.upsert("registry_items", data.registry.map { RegistryRow($0, wedding: weddingID) })
        try await db.upsert("registry_links", (data.registryLinks ?? []).map { LinkRow($0, wedding: weddingID) })
        try await db.upsert("updates", data.updates.map { UpdateRow($0, wedding: weddingID) })
        // Questions come from guests; the couple only adds answers.
        try await db.upsert("questions", data.questions.filter { $0.answer != nil }.map { QuestionRow($0, wedding: weddingID) })
        // Gifts come from guests too; the couple only ticks off thank-you notes. Sent one by
        // one so a gift a guest took back in the meantime isn't brought back.
        for id in data.changedGiftIDs ?? [] {
            guard let gift = data.gifts?.first(where: { $0.id == id }) else { continue }
            try await db.update("registry_gifts", "id=eq.\(id.uuidString.lowercased())", ["thank_you_sent": gift.thankYouSent])
        }
        return uploaded
    }

    /// Copies photos picked on this phone to the database, skipping ones already there.
    private static func uploadPhotos(_ data: AppData, weddingID: UUID, as db: REST) async throws -> [String] {
        let done = Set(data.uploadedPhotos ?? [])
        let names = (data.events.compactMap(\.photoFileName) + [data.wedding.couplePhotoFileName].compactMap { $0 })
            .filter { !done.contains($0) }
        var uploaded: [String] = []
        for name in Set(names) {
            guard let jpeg = PhotoStore.data(named: name) else { continue }
            try await db.uploadPhoto(jpeg, path: Supabase.photoPath(name, wedding: weddingID))
            uploaded.append(name)
        }
        return uploaded
    }

    static func delete(_ data: AppData, as db: REST) async throws {
        let events = data.deletedEventIDs ?? [], guests = data.deletedGuestIDs ?? []
        let items = data.deletedRegistryIDs ?? [], links = data.deletedLinkIDs ?? []
        if !events.isEmpty { try await db.delete("events", "id=in.(\(list(events)))") }
        if !guests.isEmpty { try await db.delete("guests", "id=in.(\(list(guests)))") }
        if !items.isEmpty { try await db.delete("registry_items", "id=in.(\(list(items)))") }
        if !links.isEmpty { try await db.delete("registry_links", "id=in.(\(list(links)))") }
    }

    /// Downloads the wedding and merges it into what's on the phone, keeping phone-only
    /// things like picked photos.
    static func download(into local: AppData, weddingID: UUID, as db: REST) async throws -> AppData {
        let id = "eq.\(weddingID.uuidString.lowercased())"
        let weddings: [WeddingRow] = try await db.select("weddings", "id=\(id)")
        guard let weddingRow = weddings.first else { throw SupabaseError.server("Couldn’t find your wedding.") }
        let events: [EventRow] = try await db.select("events", "wedding_id=\(id)")
        let guests: [GuestRow] = try await db.select("guests", "wedding_id=\(id)&order=created_at")
        let questions: [QuestionRow] = try await db.select("questions", "wedding_id=\(id)")
        let updates: [UpdateRow] = try await db.select("updates", "wedding_id=\(id)&order=posted_at.desc")
        let registry: [RegistryRow] = try await db.select("registry_items", "wedding_id=\(id)&order=created_at")
        let rsvps: [RSVPRow] = events.isEmpty ? [] : try await db.select("rsvps", "event_id=in.(\(list(events.map(\.id))))")
        let gifts: [GiftRow] = registry.isEmpty ? [] :
            try await db.select("registry_gifts", "item_id=in.(\(list(registry.map(\.id))))&order=given_at.desc")
        let links: [LinkRow] = try await db.select("registry_links", "wedding_id=\(id)&order=created_at")

        var data = local
        data.wedding = weddingRow.wedding(keeping: local.wedding, weddingID: weddingID)
        let localEvents = Dictionary(local.events.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        data.events = events.map { $0.event(keeping: localEvents[$0.id], weddingID: weddingID) }
        data.guests = guests.map(\.guest)
        data.rsvps = rsvps.map(\.rsvp)
        data.questions = questions.map(\.question)
        data.updates = updates.map(\.update)
        data.registry = registry.map(\.item)
        // Keep thank-you ticks the database doesn't have yet.
        let pending = Dictionary((local.gifts ?? []).filter { (local.changedGiftIDs ?? []).contains($0.id) }.map { ($0.id, $0) },
                                 uniquingKeysWith: { a, _ in a })
        data.gifts = gifts.map { pending[$0.id] ?? $0.gift }
        data.registryLinks = links.map(\.link)
        return data
    }

    /// Finds the wedding this couple already set up, for signing in on a new phone.
    static func findWedding(as db: REST) async throws -> UUID? {
        let rows: [WeddingRow] = try await db.select("weddings", "owner_id=eq.\(db.session.userID.uuidString.lowercased())&order=created_at.desc&limit=1")
        return rows.first?.id
    }

    private static func list(_ ids: [UUID]) -> String {
        ids.map { $0.uuidString.lowercased() }.joined(separator: ",")
    }
}

// MARK: - Rows, as stored in supabase/schema.sql

/// Dates and times the way the database writes them, in the phone's calendar.
private enum DB {
    static func day(_ date: Date?) -> String? {
        guard let date else { return nil }
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func day(_ text: String?) -> Date? {
        guard let parts = text?.split(separator: "-").compactMap({ Int($0) }), parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func time(_ date: Date?) -> String? {
        guard let date else { return nil }
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d:00", c.hour!, c.minute!)
    }

    static func time(_ text: String?) -> Date? {
        guard let parts = text?.split(separator: ":").compactMap({ Int($0) }), parts.count >= 2 else { return nil }
        return Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: parts[0], minute: parts[1]))
    }

    static let timestamp = ISO8601DateFormatter()
}

private struct WeddingRow: Codable {
    var id: UUID
    var owner_id: UUID?
    var couple_names: String
    var date: String
    var venue: String
    var hotel_info: String
    var parking_info: String
    var photo_url: String?

    init(_ w: Wedding, id: UUID, owner: UUID) {
        self.id = id
        owner_id = owner
        couple_names = w.coupleNames
        date = DB.day(w.date)!
        venue = w.venue
        hotel_info = w.hotelInfo
        parking_info = w.parkingInfo
        photo_url = w.couplePhotoFileName.map { Supabase.photoURL($0, wedding: id) } ?? w.remotePhotoURL
    }

    // Written out so a removed photo is sent as null rather than left unchanged.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(owner_id, forKey: .owner_id)
        try c.encode(couple_names, forKey: .couple_names)
        try c.encode(date, forKey: .date)
        try c.encode(venue, forKey: .venue)
        try c.encode(hotel_info, forKey: .hotel_info)
        try c.encode(parking_info, forKey: .parking_info)
        try c.encode(photo_url, forKey: .photo_url)
    }

    func wedding(keeping local: Wedding, weddingID: UUID) -> Wedding {
        var w = local
        w.coupleNames = couple_names
        w.date = DB.day(date) ?? local.date
        w.venue = venue
        w.hotelInfo = hotel_info
        w.parkingInfo = parking_info
        w.remotePhotoURL = remotePhoto(photo_url, localFile: local.couplePhotoFileName, weddingID: weddingID)
        return w
    }
}

/// A photo address from the database, unless it's the photo this phone already has.
private func remotePhoto(_ url: String?, localFile: String?, weddingID: UUID) -> String? {
    guard let url else { return nil }
    if let localFile, url == Supabase.photoURL(localFile, wedding: weddingID) { return nil }
    return url
}

private struct EventRow: Codable {
    var id: UUID
    var wedding_id: UUID
    var type: String
    var name: String
    var welcome_message: String
    var day: String?
    var start_time: String?
    var end_time: String?
    var venue: String
    var directions: String
    var dress_code: String
    var dress_guidance: String
    var rsvp_required: Bool
    var rsvp_deadline: String?
    var status: String
    var photo_url: String?

    init(_ e: WeddingEvent, wedding: UUID) {
        id = e.id
        wedding_id = wedding
        type = e.type
        name = e.name
        welcome_message = e.welcomeMessage
        day = DB.day(e.day)
        start_time = DB.time(e.startTime)
        end_time = DB.time(e.endTime)
        venue = e.venue
        directions = e.directions
        dress_code = e.dressCode
        dress_guidance = e.dressGuidance
        rsvp_required = e.rsvpRequired
        rsvp_deadline = DB.day(e.rsvpDeadline)
        status = e.status.rawValue
        photo_url = e.photoFileName.map { Supabase.photoURL($0, wedding: wedding) } ?? e.remotePhotoURL
    }

    // Written out so cleared fields are sent as null rather than left unchanged.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(wedding_id, forKey: .wedding_id)
        try c.encode(type, forKey: .type)
        try c.encode(name, forKey: .name)
        try c.encode(welcome_message, forKey: .welcome_message)
        try c.encode(day, forKey: .day)
        try c.encode(start_time, forKey: .start_time)
        try c.encode(end_time, forKey: .end_time)
        try c.encode(venue, forKey: .venue)
        try c.encode(directions, forKey: .directions)
        try c.encode(dress_code, forKey: .dress_code)
        try c.encode(dress_guidance, forKey: .dress_guidance)
        try c.encode(rsvp_required, forKey: .rsvp_required)
        try c.encode(rsvp_deadline, forKey: .rsvp_deadline)
        try c.encode(status, forKey: .status)
        try c.encode(photo_url, forKey: .photo_url)
    }

    func event(keeping local: WeddingEvent?, weddingID: UUID) -> WeddingEvent {
        var e = local ?? WeddingEvent(id: id)
        e.type = type
        e.name = name
        e.welcomeMessage = welcome_message
        e.day = DB.day(day)
        e.startTime = DB.time(start_time)
        e.endTime = DB.time(end_time)
        e.venue = venue
        e.directions = directions
        e.dressCode = dress_code
        e.dressGuidance = dress_guidance
        e.rsvpRequired = rsvp_required
        e.rsvpDeadline = DB.day(rsvp_deadline)
        e.status = EventStatus(rawValue: status) ?? .draft
        e.remotePhotoURL = remotePhoto(photo_url, localFile: local?.photoFileName, weddingID: weddingID)
        return e
    }
}

private struct GuestRow: Codable {
    var id: UUID
    var wedding_id: UUID
    var name: String
    var party_size: Int
    var invite_code: String

    init(_ g: Guest, wedding: UUID) {
        id = g.id
        wedding_id = wedding
        name = g.name
        party_size = g.partySize
        invite_code = g.inviteCode ?? Supabase.makeInviteCode()
    }

    var guest: Guest { Guest(id: id, name: name, partySize: party_size, inviteCode: invite_code) }
}

private struct RSVPRow: Codable {
    var event_id: UUID
    var guest_id: UUID
    var attending: Bool
    var party_count: Int
    var note: String
    var updated_at: String

    var rsvp: RSVP {
        RSVP(eventID: event_id, guestID: guest_id, attending: attending, partyCount: party_count, note: note,
             updatedAt: DB.timestamp.date(from: String(updated_at.prefix(19)) + "Z") ?? Date())
    }
}

private struct QuestionRow: Codable {
    var id: UUID
    var wedding_id: UUID
    var guest_id: UUID?
    var event_id: UUID?
    var text: String
    var answer: String?
    var asked_at: String

    init(_ q: GuestQuestion, wedding: UUID) {
        id = q.id
        wedding_id = wedding
        guest_id = q.guestID
        event_id = q.eventID
        text = q.text
        answer = q.answer
        asked_at = DB.timestamp.string(from: q.askedAt)
    }

    var question: GuestQuestion {
        GuestQuestion(id: id, guestID: guest_id ?? UUID(), eventID: event_id, text: text,
                      askedAt: DB.timestamp.date(from: String(asked_at.prefix(19)) + "Z") ?? Date(), answer: answer)
    }
}

private struct UpdateRow: Codable {
    var id: UUID
    var wedding_id: UUID
    var title: String
    var detail: String
    var posted_at: String

    init(_ u: WeddingUpdate, wedding: UUID) {
        id = u.id
        wedding_id = wedding
        title = u.title
        detail = u.detail
        posted_at = DB.timestamp.string(from: u.postedAt)
    }

    var update: WeddingUpdate {
        WeddingUpdate(id: id, title: title, detail: detail,
                      postedAt: DB.timestamp.date(from: String(posted_at.prefix(19)) + "Z") ?? Date())
    }
}

private struct RegistryRow: Codable {
    var id: UUID
    var wedding_id: UUID
    var name: String
    var price: Int
    var is_fund: Bool
    var purchased: Bool
    var link: String
    var note: String

    init(_ i: RegistryItem, wedding: UUID) {
        id = i.id
        wedding_id = wedding
        name = i.name
        price = i.price
        is_fund = i.isFund
        purchased = i.purchased
        link = i.link
        note = i.note
    }

    var item: RegistryItem {
        RegistryItem(id: id, name: name, price: price, purchased: purchased, isFund: is_fund, link: link, note: note)
    }
}

private struct GiftRow: Codable {
    var id: UUID
    var item_id: UUID
    var guest_id: UUID?
    var amount: Int
    var note: String
    var thank_you_sent: Bool
    var given_at: String

    var gift: RegistryGift {
        RegistryGift(id: id, itemID: item_id, guestID: guest_id, amount: amount, note: note,
                     givenAt: DB.timestamp.date(from: String(given_at.prefix(19)) + "Z") ?? Date(),
                     thankYouSent: thank_you_sent)
    }
}

private struct LinkRow: Codable {
    var id: UUID
    var wedding_id: UUID
    var name: String
    var url: String

    init(_ l: RegistryLink, wedding: UUID) {
        id = l.id
        wedding_id = wedding
        name = l.name
        url = l.url
    }

    var link: RegistryLink { RegistryLink(id: id, name: name, url: url) }
}
