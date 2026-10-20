import SwiftUI
import EventKit
import EventKitUI

// MARK: - RSVP sheet + confirmation

struct RSVPSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let event: WeddingEvent

    @State private var attending = true
    @State private var partyCount = 1
    @State private var note = ""
    @State private var sent = false
    @State private var addingToCalendar = false

    var body: some View {
        NavigationStack {
            Group {
                if sent { confirmation } else { form }
            }
            .background(Palette.bgCanvas)
            .navigationTitle(sent ? "" : "RSVP")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !sent {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                }
            }
        }
        .onAppear(perform: loadExistingReply)
        .sheet(isPresented: $addingToCalendar) {
            AddToCalendarView(event: event)
                .ignoresSafeArea()
        }
    }

    private var guest: Guest { store.currentGuest }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Will you be at the \(event.name)?")
                        .font(Typo.title1)
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(Format.when(event)) · \(Format.venue(event))")
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Picker("Your reply", selection: $attending) {
                    Text("Yes, I’ll be there").tag(true)
                    Text("Can’t make it").tag(false)
                }
                .pickerStyle(.segmented)

                FieldBox(label: "Your name") {
                    Text(guest.name)
                    Spacer(minLength: 0)
                }
                if attending {
                    if guest.partySize > 1 {
                        FieldBox(label: "Who’s coming?", helper: "Your invitation is for up to \(guest.partySize) people") {
                            Stepper(partyCount == 1 ? "Just me" : "\(partyCount) people",
                                    value: $partyCount, in: 1...guest.partySize)
                        }
                    } else {
                        FieldBox(label: "Who’s coming with you?", helper: "Your invitation is for 1 guest") {
                            Text("Just me")
                            Spacer(minLength: 0)
                        }
                    }
                }
                LabeledField(label: "Note for \(store.wedding.coupleNames) (optional)", text: $note,
                             placeholder: "Can’t wait to celebrate!", multiline: true)
                if attending {
                    Panel(background: Palette.bgAccentSubtle, bordered: false) {
                        Text("Dress code: \(event.dressCode)\(event.dressGuidance.isEmpty ? "" : " — \(event.dressGuidance)")")
                            .font(Typo.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
            .screenStyle()
        }
        .scrollDismissesKeyboard(.interactively)
        .pinnedFooter {
            Button("Send RSVP") {
                store.sendRSVP(eventID: event.id, attending: attending, partyCount: partyCount, note: note)
                withAnimation { sent = true }
            }
            .buttonStyle(.primary)
        }
    }

    private var confirmation: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                SuccessMark()
                    .padding(.top, Space.xxl)
                Text(attending ? "You’re going, \(store.firstName)!" : "Thanks for letting them know, \(store.firstName)")
                    .font(Typo.title1)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(confirmationMessage)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                EventCard(title: event.name, date: Format.when(event), location: Format.venue(event),
                          badge: attending ? .attending : .declined, trailing: event.dressCode,
                          photo: event.coverPhoto)
                if attending {
                    RowGroup {
                        Button { addingToCalendar = true } label: {
                            ListRow(title: "Add to calendar", subtitle: Format.when(event), systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.plain)
                        .disabled(event.startDate == nil)
                        if let url = mapsURL {
                            RowDivider()
                            Link(destination: url) {
                                ListRow(title: "Get directions", subtitle: Format.venue(event), systemImage: "map")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .screenStyle()
        }
        .pinnedFooter {
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
        }
    }

    private var confirmationMessage: String {
        let couple = store.wedding.coupleNames
        guard let deadline = event.rsvpDeadline else { return "\(couple) can see your reply. You can change it any time." }
        return "\(couple) can see your reply. You can change it until \(Format.dayShort(deadline))."
    }

    private var mapsURL: URL? {
        guard !event.venue.isEmpty else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: event.venue)]
        return components?.url
    }

    private func loadExistingReply() {
        if let reply = store.myRSVP(for: event.id) {
            attending = reply.attending
            partyCount = max(1, reply.partyCount)
            note = reply.note
        }
    }
}

/// Opens the system "New Event" screen pre-filled with the wedding event.
/// On iOS 17+ this needs no calendar permission.
struct AddToCalendarView: UIViewControllerRepresentable {
    let event: WeddingEvent
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let calendarEvent = EKEvent(eventStore: eventStore)
        calendarEvent.title = event.name
        let start = event.startDate ?? Date()
        calendarEvent.startDate = start
        calendarEvent.endDate = event.endDate ?? start.addingTimeInterval(2 * 60 * 60)
        calendarEvent.location = event.venue
        calendarEvent.notes = [event.welcomeMessage, "Dress code: \(event.dressCode)", event.directions]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = calendarEvent
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }

        func eventEditViewController(_ controller: EKEventEditViewController,
                                     didCompleteWith action: EKEventEditViewAction) {
            dismiss()
        }
    }
}

// MARK: - Ask the couple

struct AskSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let eventID: UUID?
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.lg) {
                LabeledField(label: aboutLabel, text: $text, placeholder: "Is there parking at the hotel?",
                             helper: "\(store.wedding.coupleNames) will answer here, under Details.", multiline: true)
                Spacer()
            }
            .screenStyle()
            .background(Palette.bgCanvas)
            .navigationTitle("Ask \(store.wedding.coupleNames)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        store.ask(text, about: eventID)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var aboutLabel: String {
        guard let eventID, let event = store.event(eventID) else { return "Your question" }
        return "Your question about the \(event.name)"
    }
}

// MARK: - What to wear

struct WhatToWearView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "What to wear", subtitle: "The dress code for every event you’re invited to.")
                    ForEach(store.publishedEvents) { event in
                        NavigationLink(value: WearRoute(eventID: event.id)) {
                            HStack(alignment: .top, spacing: Space.sm) {
                                Image(systemName: "hanger")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Palette.iconPrimary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.name)
                                        .font(Typo.footnote)
                                        .foregroundStyle(Palette.textSecondary)
                                    Text(event.dressCode)
                                        .font(Typo.title3)
                                        .foregroundStyle(Palette.textPrimary)
                                    Text(event.day.map(Format.dayShort) ?? "Date to be announced")
                                        .font(Typo.subheadline)
                                        .foregroundStyle(Palette.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Palette.iconInactive)
                            }
                            .padding(Space.md)
                            .background(Palette.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                    .strokeBorder(Palette.borderSubtle, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .guestDestinations()
        }
    }
}

struct WhatToWearDetail: View {
    @Environment(AppStore.self) private var store
    let eventID: UUID
    @State private var rsvpEvent: WeddingEvent?

    var body: some View {
        Group {
            if let event = store.event(eventID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.xl) {
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text("What to wear")
                                .font(Typo.title1)
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(event.name) · \(event.day.map(Format.dayShort) ?? "Date to be announced")")
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Panel {
                            Text("Dress code")
                                .font(Typo.footnote)
                                .foregroundStyle(Palette.textSecondary)
                            Text(event.dressCode)
                                .font(Typo.title3)
                                .foregroundStyle(Palette.textPrimary)
                            if !event.dressGuidance.isEmpty {
                                Text(event.dressGuidance)
                                    .font(Typo.body)
                                    .foregroundStyle(Palette.textPrimary)
                            }
                        }
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("Outfit ideas from \(store.wedding.coupleNames)")
                            HStack(spacing: Space.sm) {
                                outfitIdea("Dress idea")
                                outfitIdea("Suit idea")
                            }
                            Text("Outfit photos are coming soon.")
                                .font(Typo.footnote)
                                .foregroundStyle(Palette.textTertiary)
                        }
                        if store.guestBadge(for: event) == .replyNeeded {
                            Button("RSVP to the \(event.name)") { rsvpEvent = event }
                                .buttonStyle(.primary)
                        }
                    }
                    .screenStyle()
                }
            } else {
                ContentUnavailableView("This event isn’t available", systemImage: "hanger")
            }
        }
        .background(Palette.bgCanvas)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $rsvpEvent) { RSVPSheet(event: $0) }
    }

    private func outfitIdea(_ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverPlaceholder(height: 200, cornerRadius: Radius.md)
            Text(caption)
                .font(Typo.subheadline)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Details

struct DetailsView: View {
    @Environment(AppStore.self) private var store
    @State private var asking: AskTarget?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "Details", subtitle: "\(store.wedding.coupleNames) · \(Format.dayLong(store.wedding.date))")

                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle("Travel")
                        Panel {
                            Label("Where to stay", systemImage: "bed.double")
                                .font(Typo.headline)
                                .foregroundStyle(Palette.textPrimary)
                            Text(store.wedding.hotelInfo)
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Panel {
                            Label("Parking", systemImage: "car")
                                .font(Typo.headline)
                                .foregroundStyle(Palette.textPrimary)
                            Text(store.wedding.parkingInfo)
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle("Registry")
                        RowGroup {
                            ForEach(Array(store.data.registry.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { RowDivider() }
                                HStack {
                                    ListRow(title: item.name, subtitle: Format.price(item.price), systemImage: "gift",
                                            showsChevron: false)
                                    if item.purchased {
                                        StatusBadge(kind: .bought)
                                            .padding(.trailing, Space.md)
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle("Your questions")
                        if store.myQuestions.isEmpty {
                            Text("Not sure about something? Ask \(store.wedding.coupleNames) — the answer will show up here.")
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        ForEach(store.myQuestions) { question in
                            Panel {
                                Text(question.text)
                                    .font(Typo.headline)
                                    .foregroundStyle(Palette.textPrimary)
                                Text(question.answer ?? "Waiting for an answer")
                                    .font(Typo.subheadline)
                                    .foregroundStyle(question.answer == nil ? Palette.textTertiary : Palette.textSecondary)
                            }
                        }
                        Button("Ask \(store.wedding.coupleNames)") { asking = AskTarget(eventID: nil) }
                            .buttonStyle(.secondary)
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .guestDestinations()
            .sheet(item: $asking) { AskSheet(eventID: $0.eventID) }
        }
    }
}
