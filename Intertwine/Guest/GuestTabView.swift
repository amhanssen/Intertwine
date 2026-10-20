import SwiftUI

enum GuestTab: Hashable {
    case home, schedule, wear, details
}

/// Navigation value for the "What to wear" page of one event.
struct WearRoute: Hashable {
    let eventID: UUID
}

/// Target for the "Ask Mia & Ryan" sheet.
struct AskTarget: Identifiable {
    let id = UUID()
    let eventID: UUID?
}

extension AppStore {
    /// The badge a guest sees on an event: Attending, Can't go, Reply needed or No RSVP needed.
    func guestBadge(for event: WeddingEvent) -> BadgeKind {
        guard event.rsvpRequired else { return .noRSVP }
        guard let reply = myRSVP(for: event.id) else { return .replyNeeded }
        return reply.attending ? .attending : .declined
    }

    var firstName: String {
        currentGuest.name.components(separatedBy: " ").first ?? currentGuest.name
    }
}

extension View {
    /// Pages a guest can push to from any tab.
    func guestDestinations() -> some View {
        self
            .navigationDestination(for: UUID.self) { GuestEventView(eventID: $0) }
            .navigationDestination(for: WearRoute.self) { WhatToWearDetail(eventID: $0.eventID) }
    }
}

/// Guest app — tabs: Home, Schedule, What to Wear, Details (matches the Figma tab bar, Role = Guest).
struct GuestTabView: View {
    @State private var tab: GuestTab = .home

    var body: some View {
        TabView(selection: $tab) {
            GuestHomeView(selectedTab: $tab)
                .modifier(AppTabBarStyle())
                .tabItem { Label("Home", systemImage: "house") }
                .tag(GuestTab.home)
            ScheduleView()
                .modifier(AppTabBarStyle())
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(GuestTab.schedule)
            WhatToWearView()
                .modifier(AppTabBarStyle())
                .tabItem { Label("What to Wear", systemImage: "hanger") }
                .tag(GuestTab.wear)
            DetailsView()
                .modifier(AppTabBarStyle())
                .tabItem { Label("Details", systemImage: "info.circle") }
                .tag(GuestTab.details)
        }
    }
}

// MARK: - Home

struct GuestHomeView: View {
    @Environment(AppStore.self) private var store
    @Binding var selectedTab: GuestTab
    @State private var rsvpEvent: WeddingEvent?
    @State private var asking: AskTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    HStack(alignment: .center, spacing: Space.sm) {
                        ScreenHeader(title: "Welcome, \(store.firstName)",
                                     eyebrow: "\(store.wedding.coupleNames) · \(Format.dayLong(store.wedding.date))")
                        ProfileMenu(initials: String(store.firstName.prefix(1)))
                    }

                    let owed = store.eventsNeedingMyReply
                    if let first = owed.first {
                        Panel(background: Palette.bgAccentSubtle, bordered: false) {
                            Text(first.rsvpDeadline.map { "Please reply by \(Format.dayShort($0))" } ?? "Please reply")
                                .font(Typo.title3)
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(store.wedding.coupleNames) are waiting on your RSVP for the \(first.name).")
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textPrimary)
                            Button("RSVP now") { rsvpEvent = first }
                                .buttonStyle(.primary)
                                .padding(.top, Space.xxs)
                            if owed.count > 1 {
                                Text("\(owed.count - 1) more on your Schedule")
                                    .font(Typo.footnote)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                    }

                    if let next = store.nextPublishedEvent {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("Your next event")
                            NavigationLink(value: next.id) {
                                EventCard(title: next.name, date: Format.when(next), location: Format.venue(next),
                                          badge: store.guestBadge(for: next), trailing: next.dressCode,
                                          photo: next.coverPhoto)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !store.data.updates.isEmpty {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("Updates from \(store.wedding.coupleNames)")
                            RowGroup {
                                ForEach(Array(store.data.updates.prefix(4).enumerated()), id: \.element.id) { index, update in
                                    if index > 0 { RowDivider() }
                                    ListRow(title: update.title, subtitle: update.detail, systemImage: "bell",
                                            showsChevron: false)
                                }
                            }
                        }
                    }

                    RowGroup {
                        Button { selectedTab = .details } label: {
                            ListRow(title: "Registry", subtitle: "Browse \(store.wedding.coupleNames)’s gift list",
                                    systemImage: "gift")
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                        Button { asking = AskTarget(eventID: nil) } label: {
                            ListRow(title: "Have a question?", subtitle: "Ask \(store.wedding.coupleNames) directly",
                                    systemImage: "bubble.left")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .guestDestinations()
            .sheet(item: $rsvpEvent) { RSVPSheet(event: $0) }
            .sheet(item: $asking) { AskSheet(eventID: $0.eventID) }
        }
    }
}

// MARK: - Schedule

struct ScheduleView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "Schedule", subtitle: "Every event you’re invited to, in order.")
                    if store.publishedEvents.isEmpty {
                        ContentUnavailableView("No events yet", systemImage: "calendar",
                                               description: Text("Events appear here once \(store.wedding.coupleNames) share them."))
                    }
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle(Format.dayLong(day))
                            ForEach(events(on: day)) { event in
                                NavigationLink(value: event.id) {
                                    EventCard(title: event.name, date: Format.timeRange(event) ?? "Time to be announced",
                                              location: Format.venue(event), badge: store.guestBadge(for: event),
                                              trailing: event.dressCode, photo: event.coverPhoto)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .guestDestinations()
        }
    }

    private var days: [Date] {
        let starts = store.publishedEvents.compactMap(\.day).map { Calendar.current.startOfDay(for: $0) }
        return Array(Set(starts)).sorted()
    }

    private func events(on day: Date) -> [WeddingEvent] {
        store.publishedEvents.filter { event in
            guard let eventDay = event.day else { return false }
            return Calendar.current.isDate(eventDay, inSameDayAs: day)
        }
    }
}

// MARK: - Event (guest)

struct GuestEventView: View {
    @Environment(AppStore.self) private var store
    let eventID: UUID
    @State private var rsvpEvent: WeddingEvent?
    @State private var asking: AskTarget?

    var body: some View {
        Group {
            if let event = store.event(eventID), event.status == .published {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        EventHeader(event: event)
                        rsvpPanel(event)
                        WherePanel(event: event)
                        RowGroup {
                            NavigationLink(value: WearRoute(eventID: event.id)) {
                                ListRow(title: "What to wear", subtitle: "\(event.dressCode) · see outfit ideas",
                                        systemImage: "hanger")
                            }
                            .buttonStyle(.plain)
                            RowDivider()
                            Button { asking = AskTarget(eventID: event.id) } label: {
                                ListRow(title: "Have a question?", subtitle: "Ask \(store.wedding.coupleNames)",
                                        systemImage: "bubble.left")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .screenStyle()
                }
            } else {
                ContentUnavailableView("This event isn’t available", systemImage: "calendar.badge.exclamationmark",
                                       description: Text("The couple may have changed or removed it."))
            }
        }
        .background(Palette.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $rsvpEvent) { RSVPSheet(event: $0) }
        .sheet(item: $asking) { AskSheet(eventID: $0.eventID) }
    }

    @ViewBuilder
    private func rsvpPanel(_ event: WeddingEvent) -> some View {
        if !event.rsvpRequired {
            Panel {
                Text("No RSVP needed")
                    .font(Typo.title3)
                    .foregroundStyle(Palette.textPrimary)
                Text("All wedding guests are welcome — just come!")
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        } else if let reply = store.myRSVP(for: event.id) {
            Panel {
                HStack(alignment: .firstTextBaseline) {
                    Text(reply.attending ? "You’re going · \(partyText(reply.partyCount))" : "You can’t make it")
                        .font(Typo.title3)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    StatusBadge(kind: reply.attending ? .attending : .declined)
                }
                Text(event.rsvpDeadline.map { "You can change your reply until \(Format.dayShort($0))." }
                     ?? "You can change your reply any time.")
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                Button("Change response") { rsvpEvent = event }
                    .buttonStyle(.secondary)
                    .padding(.top, Space.xxs)
            }
        } else {
            Panel {
                Text(event.rsvpDeadline.map { "Please reply by \(Format.dayShort($0))" } ?? "Please reply")
                    .font(Typo.title3)
                    .foregroundStyle(Palette.textPrimary)
                Text("You’re invited · RSVP required")
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                Button("RSVP") { rsvpEvent = event }
                    .buttonStyle(.primary)
                    .padding(.top, Space.xxs)
            }
        }
    }

    private func partyText(_ count: Int) -> String {
        count <= 1 ? "Just you" : "Party of \(count)"
    }
}
