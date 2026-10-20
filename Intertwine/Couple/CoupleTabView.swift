import PhotosUI
import SwiftUI

enum CoupleTab: Hashable {
    case home, events, guests, registry
}

/// Couple app — tabs: Home, Events, Guests, Registry (matches the Figma tab bar, Role = Couple).
struct CoupleTabView: View {
    @State private var tab: CoupleTab = .home

    var body: some View {
        TabView(selection: $tab) {
            CoupleHomeView(selectedTab: $tab)
                .modifier(AppTabBarStyle())
                .tabItem { Label("Home", systemImage: "house") }
                .tag(CoupleTab.home)
            EventsView()
                .modifier(AppTabBarStyle())
                .tabItem { Label("Events", systemImage: "calendar") }
                .tag(CoupleTab.events)
            GuestsView()
                .modifier(AppTabBarStyle())
                .tabItem { Label("Guests", systemImage: "person.2") }
                .tag(CoupleTab.guests)
            CoupleRegistryView()
                .modifier(AppTabBarStyle())
                .tabItem { Label("Registry", systemImage: "gift") }
                .tag(CoupleTab.registry)
        }
    }
}

// MARK: - Home

struct CoupleHomeView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedTab: CoupleTab
    @State private var editing: WeddingEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    header
                    SyncProblemBanner()
                    atAGlance
                    needsAttention
                    if let next = store.nextPublishedEvent {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("Next event")
                            NavigationLink(value: next.id) {
                                coupleCard(for: next)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("Preview as guest") { store.switchRole(to: .guest) }
                        .buttonStyle(.secondary)
                }
                .screenStyle()
            }
            // Pull down to bring in new RSVPs and questions from the website.
            .refreshable { await store.sync() }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { CoupleEventDetailView(eventID: $0) }
            .fullScreenCover(item: $editing) { CreateEventFlow(event: $0) }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            ScreenHeader(title: store.wedding.coupleNames,
                         eyebrow: ([Format.dayLong(store.wedding.date), store.wedding.venue]
                                   .filter { !$0.isEmpty }.joined(separator: " · ")))
            ProfileMenu(initials: store.coupleInitials, photo: store.wedding.photo)
        }
    }

    private var atAGlance: some View {
        HStack(spacing: Space.sm) {
            Group {
                if let photo = store.wedding.photo {
                    CountdownTile(days: store.daysUntilWedding, photo: photo)
                        .contextMenu {
                            Button("Remove photo", systemImage: "trash", role: .destructive) {
                                store.setCouplePhoto(nil)
                            }
                        }
                } else {
                    StatTile(value: "\(store.daysUntilWedding)", label: "days until “I do”", large: true)
                }
            }
            .overlay(alignment: .topTrailing) { CouplePhotoButton(hasPhoto: store.wedding.photo != nil) }
            VStack(spacing: Space.sm) {
                StatTile(value: "\(store.totalInvitedPeople)", label: "guests invited")
                StatTile(value: "\(store.totalReplies)", label: "RSVPs received")
            }
        }
        .frame(height: 176)
    }

    private var needsAttention: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            SectionTitle("Needs your attention")
            RowGroup {
                let drafts = store.draftEvents
                let questions = store.unansweredQuestions
                if store.data.events.isEmpty {
                    Button { editing = WeddingEvent() } label: {
                        ListRow(title: "Add your first event",
                                subtitle: "Start with the Welcome Party or the Wedding Day")
                    }
                    .buttonStyle(.plain)
                } else if drafts.isEmpty && questions.isEmpty {
                    ListRow(title: "You’re all caught up", subtitle: "Nothing needs you right now", showsChevron: false)
                }
                ForEach(Array(drafts.enumerated()), id: \.element.id) { index, event in
                    if index > 0 { RowDivider() }
                    Button { editing = event } label: {
                        ListRow(title: "Finish \(event.name)",
                                subtitle: event.isComplete
                                    ? "Ready to publish"
                                    : "Missing \(event.missingDetails.joined(separator: ", "))")
                    }
                    .buttonStyle(.plain)
                }
                if !questions.isEmpty {
                    if !drafts.isEmpty { RowDivider() }
                    Button { selectedTab = .guests } label: {
                        ListRow(title: questions.count == 1 ? "1 guest question" : "\(questions.count) guest questions",
                                subtitle: "Answer so guests don’t have to text you")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func coupleCard(for event: WeddingEvent) -> some View {
        let counts = store.rsvpCounts(for: event)
        return EventCard(title: event.name, date: Format.when(event), location: Format.venue(event),
                         badge: .published,
                         trailing: "\(counts.attending) attending · \(counts.pending) pending",
                         photo: event.coverPhoto)
    }
}

/// Small button on the countdown tile for adding or changing the photo of the couple.
/// Long-press the tile to remove it.
private struct CouplePhotoButton: View {
    @Environment(AppStore.self) private var store
    let hasPhoto: Bool
    @State private var picked: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $picked, matching: .images) {
            Image(systemName: hasPhoto ? "photo" : "photo.badge.plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.iconPrimary)
                .frame(width: 36, height: 36)
                .background(Palette.bgSurface.opacity(0.9), in: Circle())
        }
        .padding(Space.xs)
        .accessibilityLabel(hasPhoto ? "Change photo of you two" : "Add a photo of you two")
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let name = PhotoStore.save(data) {
                    store.setCouplePhoto(name)
                }
                picked = nil
            }
        }
    }
}

// MARK: - Events

struct EventsView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: WeddingEvent?
    @State private var toDelete: WeddingEvent?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "Events", subtitle: "Only published events are visible to guests.")
                    Button {
                        editing = WeddingEvent()
                    } label: {
                        Label("Add event", systemImage: "plus")
                    }
                    .buttonStyle(.primary)

                    if !store.draftEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("In progress")
                            ForEach(store.draftEvents) { event in
                                Button { editing = event } label: {
                                    EventCard(title: event.name, date: Format.when(event),
                                              location: Format.venue(event),
                                              badge: event.isComplete ? .draft : .needsInfo,
                                              trailing: "RSVPs open when published", photo: event.coverPhoto)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { deleteButton(event) }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle("Published")
                        if store.publishedEvents.isEmpty {
                            Text("Nothing published yet. Guests only see events after you publish them.")
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        ForEach(store.publishedEvents) { event in
                            let counts = store.rsvpCounts(for: event)
                            NavigationLink(value: event.id) {
                                EventCard(title: event.name, date: Format.when(event),
                                          location: Format.venue(event), badge: .published,
                                          trailing: "\(counts.attending) attending · \(counts.pending) pending",
                                          photo: event.coverPhoto)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { deleteButton(event) }
                        }
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { CoupleEventDetailView(eventID: $0) }
            .fullScreenCover(item: $editing) { CreateEventFlow(event: $0) }
            .confirmationDialog("Delete this event?", isPresented: Binding(
                get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }), titleVisibility: .visible) {
                Button("Delete \(toDelete?.name ?? "event")", role: .destructive) {
                    if let id = toDelete?.id { store.deleteEvent(id) }
                    toDelete = nil
                }
            } message: {
                Text("Guests will no longer see it, and its RSVPs will be removed.")
            }
        }
    }

    private func deleteButton(_ event: WeddingEvent) -> some View {
        Button("Delete", systemImage: "trash", role: .destructive) { toDelete = event }
    }
}

// MARK: - Event detail (couple)

struct CoupleEventDetailView: View {
    @Environment(AppStore.self) private var store
    let eventID: UUID
    @State private var editing: WeddingEvent?

    var body: some View {
        Group {
            if let event = store.event(eventID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        EventHeader(event: event)
                        rsvpPanel(event)
                        WherePanel(event: event)
                        DressCodePanel(event: event)
                        Button("Edit event") { editing = event }
                            .buttonStyle(.secondary)
                    }
                    .screenStyle()
                }
            } else {
                ContentUnavailableView("Event deleted", systemImage: "calendar.badge.exclamationmark")
            }
        }
        .background(Palette.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $editing) { CreateEventFlow(event: $0) }
    }

    private func rsvpPanel(_ event: WeddingEvent) -> some View {
        let counts = store.rsvpCounts(for: event)
        let replies = store.data.rsvps.filter { $0.eventID == event.id }
            .sorted { store.guestName($0.guestID) < store.guestName($1.guestID) }
        return VStack(alignment: .leading, spacing: Space.xs) {
            SectionTitle("RSVPs")
            HStack(spacing: Space.sm) {
                StatTile(value: "\(counts.attending)", label: "attending")
                StatTile(value: "\(counts.declined)", label: "can’t go")
                StatTile(value: "\(counts.pending)", label: "waiting")
            }
            .frame(height: 96)
            if !replies.isEmpty {
                RowGroup {
                    ForEach(Array(replies.enumerated()), id: \.offset) { index, reply in
                        if index > 0 { RowDivider() }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.guestName(reply.guestID))
                                    .font(Typo.headline)
                                    .foregroundStyle(Palette.textPrimary)
                                if !reply.note.isEmpty {
                                    Text("“\(reply.note)”")
                                        .font(Typo.subheadline)
                                        .foregroundStyle(Palette.textSecondary)
                                }
                            }
                            Spacer()
                            StatusBadge(kind: reply.attending ? .attending : .declined)
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm)
                    }
                }
            }
        }
    }
}
