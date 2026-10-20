import SwiftUI

// MARK: - Guests (couple)

struct GuestsView: View {
    @Environment(AppStore.self) private var store
    @State private var addingGuest = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "Guests",
                                 subtitle: "\(store.data.guests.count) invitations · \(store.totalInvitedPeople) people")

                    if !store.unansweredQuestions.isEmpty {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("Questions from guests")
                            ForEach(store.unansweredQuestions) { question in
                                QuestionAnswerCard(question: question)
                            }
                        }
                    }

                    if !store.publishedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            SectionTitle("RSVPs by event")
                            RowGroup {
                                ForEach(Array(store.publishedEvents.enumerated()), id: \.element.id) { index, event in
                                    if index > 0 { RowDivider() }
                                    let counts = store.rsvpCounts(for: event)
                                    NavigationLink(value: event.id) {
                                        ListRow(title: event.name,
                                                subtitle: "\(counts.attending) attending · \(counts.declined) can’t go · \(counts.pending) waiting",
                                                systemImage: "calendar")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        HStack {
                            SectionTitle("Guest list")
                            Button {
                                addingGuest = true
                            } label: {
                                Label("Add guest", systemImage: "plus")
                                    .font(Typo.headline)
                            }
                            .fixedSize()
                        }
                        if store.isSyncing && !store.data.guests.isEmpty {
                            Text("Tap \(Image(systemName: "square.and.arrow.up")) to send a guest their personal link to the wedding website.")
                                .font(Typo.footnote)
                                .foregroundStyle(Palette.textTertiary)
                        }
                        RowGroup {
                            ForEach(Array(store.data.guests.enumerated()), id: \.element.id) { index, guest in
                                if index > 0 { RowDivider() }
                                HStack(spacing: 0) {
                                    ListRow(title: guest.name,
                                            subtitle: guest.partySize == 1 ? "Invitation for 1" : "Invitation for \(guest.partySize)",
                                            showsChevron: false)
                                    if store.isSyncing, let link = guest.inviteLink {
                                        ShareLink(item: link,
                                                  message: Text("Here’s your invite to \(store.wedding.coupleNames)’s wedding. RSVP and see every event here:")) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 17, weight: .medium))
                                                .foregroundStyle(Palette.iconPrimary)
                                                .frame(width: 44, height: 44)
                                        }
                                        .accessibilityLabel("Send \(guest.name) their invite link")
                                        .padding(.trailing, Space.xs)
                                    }
                                }
                            }
                        }
                    }
                }
                .screenStyle()
            }
            .refreshable { await store.sync() }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { CoupleEventDetailView(eventID: $0) }
            .sheet(isPresented: $addingGuest) { AddGuestSheet() }
        }
    }
}

/// A guest's question with a reply box. Answers show up for the guest under Details.
struct QuestionAnswerCard: View {
    @Environment(AppStore.self) private var store
    let question: GuestQuestion
    @State private var reply = ""

    var body: some View {
        Panel {
            Text(store.guestName(question.guestID) + aboutText)
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
            Text(question.text)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
            HStack(spacing: Space.xs) {
                TextField("Write a reply", text: $reply, axis: .vertical)
                    .font(Typo.body)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs)
                    .background(Palette.bgSunken, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
                Button("Send") {
                    store.answer(question.id, with: reply)
                    reply = ""
                }
                .font(Typo.headline)
                .disabled(reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var aboutText: String {
        guard let id = question.eventID, let event = store.event(id) else { return " asked" }
        return " asked about the \(event.name)"
    }
}

struct AddGuestSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var partySize = 1

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.lg) {
                LabeledField(label: "Name", text: $name, placeholder: "e.g. Jessica Avery")
                FieldBox(label: "Invitation covers") {
                    Stepper(partySize == 1 ? "1 person" : "\(partySize) people", value: $partySize, in: 1...8)
                }
                Spacer()
            }
            .screenStyle()
            .background(Palette.bgCanvas)
            .navigationTitle("Add guest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addGuest(named: name, partySize: partySize)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Registry (couple)

struct CoupleRegistryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    ScreenHeader(title: "Registry", subtitle: "Shop · Manage · Track")
                    Panel(background: Palette.bgAccentSubtle, bordered: false) {
                        Text("Gift advisor")
                            .font(Typo.title3)
                            .foregroundStyle(Palette.textPrimary)
                        Text("You’ve invited \(store.totalInvitedPeople) people. Include gifts at a range of prices so every guest can find something in their budget.")
                            .font(Typo.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle("Your gifts")
                        RowGroup {
                            ForEach(Array(store.data.registry.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { RowDivider() }
                                Button {
                                    store.togglePurchased(item.id)
                                } label: {
                                    HStack {
                                        ListRow(title: item.name, subtitle: Format.price(item.price), showsChevron: false)
                                        if item.purchased {
                                            StatusBadge(kind: .bought)
                                                .padding(.trailing, Space.md)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Marks the gift as bought or not bought")
                            }
                        }
                        Text("Tap a gift to mark it as bought.")
                            .font(Typo.footnote)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Button("Link a registry from another store") {}
                        .buttonStyle(.secondary)
                        .disabled(true)
                    Text("Coming soon.")
                        .font(Typo.footnote)
                        .foregroundStyle(Palette.textTertiary)
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
