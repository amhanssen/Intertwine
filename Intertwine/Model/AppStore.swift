import Foundation
import Observation

/// The app's single source of truth. Views read it from the environment and call its
/// methods to make changes; every change is saved to disk right away.
@MainActor
@Observable
final class AppStore {
    private(set) var data: AppData

    /// Which side of the app is showing. nil = show the role picker.
    private(set) var role: Role?

    private static let roleKey = "intertwine.role"
    @ObservationIgnored private let fileURL: URL

    func switchRole(to newRole: Role?) {
        role = newRole
        UserDefaults.standard.set(newRole?.rawValue, forKey: Self.roleKey)
    }

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Self.defaultFileURL
        self.fileURL = url
        if let saved = try? Data(contentsOf: url),
           var decoded = try? JSONDecoder().decode(AppData.self, from: saved) {
            if decoded.isDemo != false { Self.addSamplePhotos(to: &decoded) }
            data = decoded
        } else {
            data = SampleData.make()
        }
        role = UserDefaults.standard.string(forKey: Self.roleKey).flatMap(Role.init(rawValue:))
    }

    /// Demo data saved by builds before the sample photos existed doesn't name them; fill them in.
    private static func addSamplePhotos(to data: inout AppData) {
        if data.wedding.couplePhoto == nil { data.wedding.couplePhoto = Brand.couplePhoto }
        for index in data.events.indices
        where data.events[index].samplePhoto == nil && data.events[index].photoFileName == nil {
            data.events[index].samplePhoto = Brand.photo(for: data.events[index].name)
        }
    }

    private static var defaultFileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("intertwine.json")
    }

    private func change(_ edit: (inout AppData) -> Void) {
        edit(&data)
        editCount += 1
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            print("Couldn't save: \(error)")
        }
    }

    // MARK: - Reading

    var wedding: Wedding { data.wedding }

    var currentGuest: Guest {
        data.guests.first { $0.id == data.currentGuestID }
            ?? data.guests.first
            // A couple's own wedding has no demo guest; the guest view is then a preview.
            ?? Guest(id: data.currentGuestID, name: "Guest")
    }

    var isDemo: Bool { data.isDemo != false }

    /// "Mia & Ryan" → "M&R".
    var coupleInitials: String {
        data.wedding.coupleNames
            .components(separatedBy: "&")
            .compactMap { $0.trimmingCharacters(in: .whitespaces).first.map(String.init) }
            .joined(separator: "&")
    }

    func event(_ id: UUID) -> WeddingEvent? {
        data.events.first { $0.id == id }
    }

    /// Events sorted by date; events without a date go last.
    var eventsByDate: [WeddingEvent] {
        data.events.sorted { a, b in
            switch (a.startDate, b.startDate) {
            case let (x?, y?): return x < y
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return a.name < b.name
            }
        }
    }

    var draftEvents: [WeddingEvent] { eventsByDate.filter { $0.status == .draft } }
    var publishedEvents: [WeddingEvent] { eventsByDate.filter { $0.status == .published } }

    var nextPublishedEvent: WeddingEvent? {
        let now = Date()
        return publishedEvents.first { ($0.startDate ?? .distantPast) >= now } ?? publishedEvents.last
    }

    var daysUntilWedding: Int {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: data.wedding.date)
        return max(0, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    func rsvp(for eventID: UUID, guestID: UUID) -> RSVP? {
        data.rsvps.first { $0.eventID == eventID && $0.guestID == guestID }
    }

    func myRSVP(for eventID: UUID) -> RSVP? {
        rsvp(for: eventID, guestID: data.currentGuestID)
    }

    /// RSVP summary for the couple: attending people, declined guests, guests still to reply.
    func rsvpCounts(for event: WeddingEvent) -> (attending: Int, declined: Int, pending: Int) {
        let replies = data.rsvps.filter { $0.eventID == event.id }
        let attending = replies.filter(\.attending).reduce(0) { $0 + $1.partyCount }
        let declined = replies.filter { !$0.attending }.count
        let pending = max(0, data.guests.count - replies.count)
        return (attending, declined, pending)
    }

    var totalInvitedPeople: Int { data.guests.reduce(0) { $0 + $1.partySize } }
    var totalReplies: Int { data.rsvps.count }

    /// Published events where the current guest still owes a reply.
    var eventsNeedingMyReply: [WeddingEvent] {
        publishedEvents.filter { $0.rsvpRequired && myRSVP(for: $0.id) == nil }
    }

    var unansweredQuestions: [GuestQuestion] {
        data.questions.filter { $0.answer == nil }.sorted { $0.askedAt > $1.askedAt }
    }

    var myQuestions: [GuestQuestion] {
        data.questions.filter { $0.guestID == data.currentGuestID }.sorted { $0.askedAt > $1.askedAt }
    }

    func guestName(_ id: UUID) -> String {
        data.guests.first { $0.id == id }?.name ?? "A guest"
    }

    // MARK: - Couple actions

    /// Adds or replaces an event, keeping it as a draft.
    func saveDraft(_ event: WeddingEvent) {
        var draft = event
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { draft.name = draft.type }
        upsert(draft)
    }

    /// Adds or replaces an event and makes it visible to guests.
    func publish(_ event: WeddingEvent) {
        var live = event
        live.status = .published
        upsert(live)
        let isFirstPublish = event.status == .draft
        if isFirstPublish {
            coupleChange { data in
                data.updates.insert(
                    WeddingUpdate(title: "\(live.name) added", detail: live.day.map { Format.dayShort($0) } ?? "New event"),
                    at: 0)
            }
        }
    }

    private func upsert(_ event: WeddingEvent) {
        coupleChange { data in
            if let index = data.events.firstIndex(where: { $0.id == event.id }) {
                data.events[index] = event
            } else {
                data.events.append(event)
            }
        }
        removeUnusedPhotos()
    }

    func deleteEvent(_ id: UUID) {
        coupleChange { data in
            data.events.removeAll { $0.id == id }
            data.rsvps.removeAll { $0.eventID == id }
            if data.remoteWeddingID != nil { data.deletedEventIDs = (data.deletedEventIDs ?? []) + [id] }
        }
        removeUnusedPhotos()
    }

    private func removeUnusedPhotos() {
        var used = Set(data.events.compactMap(\.photoFileName))
        if let couple = data.wedding.couplePhotoFileName { used.insert(couple) }
        PhotoStore.removeUnused(keeping: used)
    }

    /// Sets (or with nil, removes) the photo of the couple on their Home.
    func setCouplePhoto(_ fileName: String?) {
        change { data in
            data.wedding.couplePhotoFileName = fileName
            if fileName == nil { data.wedding.couplePhoto = nil }
        }
        removeUnusedPhotos()
    }

    func addGuest(named name: String, partySize: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        coupleChange { $0.guests.append(Guest(name: trimmed, partySize: max(1, partySize), inviteCode: Supabase.makeInviteCode())) }
    }

    func answer(_ questionID: UUID, with text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        coupleChange { data in
            if let index = data.questions.firstIndex(where: { $0.id == questionID }) {
                data.questions[index].answer = trimmed
            }
        }
    }

    func togglePurchased(_ itemID: UUID) {
        coupleChange { data in
            if let index = data.registry.firstIndex(where: { $0.id == itemID }) {
                data.registry[index].purchased.toggle()
            }
        }
    }

    // MARK: - Guest actions

    func sendRSVP(eventID: UUID, attending: Bool, partyCount: Int, note: String) {
        let guestID = data.currentGuestID
        let reply = RSVP(eventID: eventID, guestID: guestID, attending: attending,
                         partyCount: attending ? max(1, partyCount) : 0, note: note)
        change { data in
            data.rsvps.removeAll { $0.eventID == eventID && $0.guestID == guestID }
            data.rsvps.append(reply)
        }
    }

    func ask(_ text: String, about eventID: UUID?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let question = GuestQuestion(guestID: data.currentGuestID, eventID: eventID, text: trimmed)
        change { $0.questions.append(question) }
    }

    // MARK: - Onboarding

    /// Replaces whatever is on the phone with the couple's own, empty wedding. When they're
    /// signed in, it's also created in the database.
    func setUpWedding(_ wedding: Wedding, account: CoupleAccount?) {
        coupleChange { data in
            data = SampleData.empty(wedding: wedding, account: account)
            if self.session != nil {
                data.remoteWeddingID = UUID()
                data.needsUpload = true
            }
        }
        removeUnusedPhotos()
    }

    func updateWedding(_ wedding: Wedding) {
        coupleChange { $0.wedding = wedding }
    }

    func addGuests(named names: [String]) {
        let existing = Set(data.guests.map(\.name))
        let new = names
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !existing.contains($0) }
        guard !new.isEmpty else { return }
        coupleChange { data in
            data.guests.append(contentsOf: new.map { Guest(name: $0, inviteCode: Supabase.makeInviteCode()) })
        }
    }

    // MARK: - Demo

    func resetDemo() {
        change { $0 = SampleData.make() }
        removeUnusedPhotos()
        signOutOfDatabase()
    }

    /// Loads Mia & Ryan's sample wedding and opens one side of it.
    func startDemo(as role: Role) {
        resetDemo()
        switchRole(to: role)
    }

    // MARK: - Account and syncing (see Sync.swift)

    /// The signed-in couple, if any. A wedding syncs only while they're signed in.
    private(set) var session: Session? = SessionStore.load()
    private(set) var syncState: SyncState = .idle
    private(set) var lastSynced: Date?

    enum SyncState: Equatable {
        case idle, syncing
        case failed(String)
    }

    var isSyncing: Bool { data.remoteWeddingID != nil && session != nil }
    var signedInEmail: String? { session?.email }

    @ObservationIgnored private var editCount = 0
    @ObservationIgnored private var syncRunning = false
    @ObservationIgnored private var syncAgain = false

    /// A couple's change: saved on the phone, then sent to the database.
    private func coupleChange(_ edit: (inout AppData) -> Void) {
        change { data in
            edit(&data)
            if data.remoteWeddingID != nil { data.needsUpload = true }
        }
        Task { await sync() }
    }

    func createAccount(email: String, password: String) async throws {
        setSession(try await Auth.signUp(email: email, password: password))
    }

    /// Signs in and loads the couple's wedding. Returns false when the account has no
    /// wedding yet, so onboarding can go on to set one up.
    func signIn(email: String, password: String) async throws -> Bool {
        let session = try await Auth.signIn(email: email, password: password)
        setSession(session)
        guard let weddingID = try await Sync.findWedding(as: REST(session: session)) else { return false }
        var fresh = SampleData.empty(
            wedding: Wedding(coupleNames: "", date: Date(), venue: "", hotelInfo: "", parkingInfo: ""), account: nil)
        fresh.remoteWeddingID = weddingID
        let downloaded = try await Sync.download(into: fresh, weddingID: weddingID, as: REST(session: session))
        change { $0 = downloaded }
        removeUnusedPhotos()
        lastSynced = Date()
        switchRole(to: .couple)
        return true
    }

    /// Signs in without loading the account's wedding, for putting this phone's wedding online.
    func signInKeepingWedding(email: String, password: String) async throws {
        setSession(try await Auth.signIn(email: email, password: password))
    }

    /// Puts a wedding that so far lived only on this phone into the signed-in couple's account,
    /// and gives every guest a personal website link.
    func moveWeddingOnline() {
        guard session != nil, data.remoteWeddingID == nil else { return }
        coupleChange { data in
            data.remoteWeddingID = UUID()
            data.isDemo = false
            for index in data.guests.indices where data.guests[index].inviteCode == nil {
                data.guests[index].inviteCode = Supabase.makeInviteCode()
            }
        }
    }

    /// Signs out and takes the wedding off this phone (it stays safe in the database).
    func signOut() {
        change { $0 = SampleData.make() }
        removeUnusedPhotos()
        signOutOfDatabase()
        switchRole(to: nil)
    }

    private func signOutOfDatabase() {
        setSession(nil)
        syncState = .idle
        lastSynced = nil
    }

    private func setSession(_ new: Session?) {
        session = new
        SessionStore.save(new)
    }

    /// Uploads the couple's changes, then downloads guests' RSVPs and questions.
    /// Safe to call any time; it does nothing for the demo or a phone-only wedding.
    func sync() async {
        guard let weddingID = data.remoteWeddingID, var session else { return }
        if syncRunning { syncAgain = true; return }
        syncRunning = true
        syncState = .syncing
        defer { syncRunning = false }
        do {
            if session.expiresAt < Date().addingTimeInterval(60) {
                session = try await Auth.refresh(session)
                setSession(session)
            }
            let db = REST(session: session)
            let snapshot = data
            let startCount = editCount
            try await Sync.delete(events: snapshot.deletedEventIDs ?? [], guests: snapshot.deletedGuestIDs ?? [], as: db)
            if snapshot.needsUpload == true {
                try await Sync.upload(snapshot, weddingID: weddingID, as: db)
            }
            let downloaded = try await Sync.download(into: snapshot, weddingID: weddingID, as: db)
            // Only take the download if nothing changed on the phone meanwhile; otherwise sync again.
            if editCount == startCount {
                change { data in
                    data = downloaded
                    data.needsUpload = false
                    data.deletedEventIDs = nil
                    data.deletedGuestIDs = nil
                }
                removeUnusedPhotos()
            } else {
                syncAgain = true
            }
            syncState = .idle
            lastSynced = Date()
        } catch SupabaseError.notSignedIn {
            setSession(nil)
            syncState = .failed(SupabaseError.notSignedIn.errorDescription!)
        } catch {
            syncState = .failed(error.localizedDescription)
        }
        if syncAgain {
            syncAgain = false
            syncRunning = false
            await sync()
        }
    }
}
