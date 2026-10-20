import PhotosUI
import SwiftUI

/// The 5-step create-event flow from the couple's happy path:
/// Basics → Date & place → Dress code & RSVP → Guest preview → Publish.
/// Also used to finish drafts and edit published events.
struct CreateEventFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var event: WeddingEvent
    @State private var step = 1
    @State private var showErrors = false
    @State private var didPublish = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var loadingPhoto = false
    private let wasPublished: Bool
    private let isNew: Bool

    private let stepNames = ["Basics", "Date & place", "Dress code & RSVP", "Guest preview", "Publish"]
    private let eventTypes = ["Welcome Party", "Rehearsal Dinner", "Ceremony & Reception", "Engagement Party",
                              "Bridal Shower", "Bachelor/ette Party", "Farewell Brunch", "Other"]
    private let dressCodes = ["Casual", "Smart casual", "Garden party", "Cocktail attire", "Formal",
                              "Black tie optional", "Black tie"]

    init(event: WeddingEvent) {
        _event = State(initialValue: event)
        wasPublished = event.status == .published
        isNew = event.name.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if didPublish {
                    publishedView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.xl) {
                            VStack(alignment: .leading, spacing: Space.sm) {
                                Text(stepTitle)
                                    .font(Typo.title1)
                                    .foregroundStyle(Palette.textPrimary)
                                StepProgress(step: step, total: stepNames.count, name: stepNames[step - 1])
                            }
                            stepContent
                        }
                        .screenStyle()
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .pinnedFooter { footer }
                }
            }
            .background(Palette.bgCanvas)
            .navigationTitle(didPublish ? "" : (isNew ? "New event" : event.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !didPublish {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(step == 1 ? "Cancel" : "Back") {
                            if step == 1 { dismiss() } else { step -= 1; showErrors = false }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        StatusBadge(kind: wasPublished ? .published : .draft)
                    }
                }
            }
            .onChange(of: event.type) { oldType, newType in
                if event.name.isEmpty || event.name == oldType { event.name = newType }
            }
        }
        .interactiveDismissDisabled()
    }

    private var stepTitle: String {
        switch step {
        case 1: "Event basics"
        case 2: "Date & place"
        case 3: "Dress code & RSVP"
        case 4: "Preview your event"
        default: wasPublished ? "Save changes?" : "Ready to publish?"
        }
    }

    // MARK: Steps

    @ViewBuilder private var stepContent: some View {
        switch step {
        case 1: basics
        case 2: dateAndPlace
        case 3: dressAndRSVP
        case 4: preview
        default: review
        }
    }

    private var basics: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text("Start with a name and a short welcome. You’ll add the time, place and dress code next.")
                .font(Typo.subheadline)
                .foregroundStyle(Palette.textSecondary)
            FieldBox(label: "Event type") {
                Picker("Event type", selection: $event.type) {
                    ForEach(eventTypes, id: \.self) { Text($0).tag($0) }
                    if !eventTypes.contains(event.type) { Text(event.type).tag(event.type) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
            }
            LabeledField(label: "Event name", text: $event.name, placeholder: "e.g. Welcome Party",
                         error: showErrors && trimmed(event.name).isEmpty ? "Add a name so guests know what this event is" : nil)
            LabeledField(label: "Welcome message (optional)", text: $event.welcomeMessage,
                         placeholder: "Join us for drinks before the big day.", multiline: true)
            coverPhotoField
        }
    }

    /// Figma: O5.1 · Event basics "Cover photo". The picker runs outside the app,
    /// so it needs no photo library permission.
    private var coverPhotoField: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("Cover photo (optional)")
                .font(Typo.footnote)
                .foregroundStyle(Palette.textSecondary)
            if let photo = event.coverPhoto {
                CoverPlaceholder(photo: photo, height: 150)
                HStack(spacing: Space.md) {
                    PhotosPicker(selection: $pickedPhoto, matching: .images) {
                        Label("Change photo", systemImage: "photo")
                    }
                    Button("Remove", role: .destructive) {
                        event.photoFileName = nil
                        event.samplePhoto = nil
                        event.remotePhotoURL = nil
                    }
                }
                .font(Typo.subheadline.weight(.semibold))
            } else {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    Label("Add photo", systemImage: "plus")
                        .font(Typo.headline)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .background(Palette.bgAccentSubtle,
                                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                .strokeBorder(Palette.borderDefault, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        }
                }
            }
            if loadingPhoto {
                ProgressView("Adding photo…")
                    .font(Typo.footnote)
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            loadingPhoto = true
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let name = PhotoStore.save(data) {
                    event.photoFileName = name
                    event.remotePhotoURL = nil
                }
                loadingPhoto = false
                pickedPhoto = nil
            }
        }
    }

    private var dateAndPlace: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            OptionalDateField(label: "Date", date: $event.day, components: .date,
                              defaultValue: Calendar.current.date(byAdding: .day, value: -1, to: store.wedding.date) ?? Date(),
                              addTitle: "Add a date",
                              error: showErrors && event.day == nil ? "Add the date of the event" : nil)
            HStack(alignment: .top, spacing: Space.sm) {
                OptionalDateField(label: "Start time", date: $event.startTime, components: .hourAndMinute,
                                  defaultValue: Self.time(18), addTitle: "Add",
                                  error: showErrors && event.startTime == nil ? "Add a start time" : nil,
                                  clearable: false)
                OptionalDateField(label: "End time (optional)", date: $event.endTime, components: .hourAndMinute,
                                  defaultValue: Self.time(20), addTitle: "Add")
            }
            LabeledField(label: "Venue", text: $event.venue, placeholder: "e.g. Seaport Hotel",
                         error: showErrors && trimmed(event.venue).isEmpty ? "Add where the event is" : nil)
            LabeledField(label: "Directions for guests (optional)", text: $event.directions,
                         placeholder: "Use the main entrance and follow the signs.",
                         helper: "Tell guests which door or room to look for", multiline: true)
        }
    }

    private var dressAndRSVP: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.md) {
                SectionTitle("What to wear")
                FieldBox(label: "Dress code") {
                    Picker("Dress code", selection: $event.dressCode) {
                        ForEach(dressCodes, id: \.self) { Text($0).tag($0) }
                        if !dressCodes.contains(event.dressCode) { Text(event.dressCode).tag(event.dressCode) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    Spacer(minLength: 0)
                }
                LabeledField(label: "Guidance for guests", text: $event.dressGuidance,
                             placeholder: "Dresses or suits; comfortable shoes welcome.", multiline: true)
            }
            VStack(alignment: .leading, spacing: Space.md) {
                SectionTitle("RSVP")
                Picker("RSVP", selection: $event.rsvpRequired) {
                    Text("RSVP required").tag(true)
                    Text("No RSVP").tag(false)
                }
                .pickerStyle(.segmented)
                if event.rsvpRequired {
                    OptionalDateField(label: "Reply by", date: $event.rsvpDeadline, components: .date,
                                      defaultValue: Calendar.current.date(byAdding: .day, value: -14,
                                                                          to: event.day ?? store.wedding.date) ?? Date(),
                                      addTitle: "Add a reply-by date")
                }
                FieldBox(label: "Who’s invited",
                         helper: event.rsvpRequired ? "RSVPs open when you publish" : "Guests will see the event without an RSVP button") {
                    Text("All wedding guests")
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Panel(background: Palette.bgAccentSubtle, bordered: false) {
                Text("This is exactly what guests will see. RSVP is off while you preview.")
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textPrimary)
            }
            EventHeader(event: event)
            if event.rsvpRequired {
                Panel {
                    Text(event.rsvpDeadline.map { "Please reply by \(Format.dayShort($0))" } ?? "Please reply")
                        .font(Typo.title3)
                        .foregroundStyle(Palette.textPrimary)
                    Button("RSVP") {}
                        .buttonStyle(.primary)
                        .disabled(true)
                }
            }
            WherePanel(event: event, linksEnabled: false)
            DressCodePanel(event: event)
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            Text(wasPublished
                 ? "Guests will see these changes right away."
                 : "Check the details once more. You can still edit the event after it’s live.")
                .font(Typo.subheadline)
                .foregroundStyle(Palette.textSecondary)
            Panel {
                Text(event.name)
                    .font(Typo.title3)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.bottom, Space.xxs)
                VStack(alignment: .leading, spacing: Space.sm) {
                    InfoLine(label: "When", value: Format.when(event, includeYear: true))
                    InfoLine(label: "Where", value: Format.venue(event))
                    InfoLine(label: "What to wear", value: event.dressCode)
                    InfoLine(label: "RSVP", value: rsvpSummary)
                    InfoLine(label: "Who can see it", value: "All \(store.data.guests.count) invited guests")
                }
            }
            if !event.isComplete {
                Panel(background: Palette.bgWarning, bordered: false) {
                    Text("Add the \(event.missingDetails.joined(separator: ", ")) before publishing.")
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textWarning)
                }
            }
        }
    }

    private var rsvpSummary: String {
        guard event.rsvpRequired else { return "No RSVP needed" }
        if let deadline = event.rsvpDeadline { return "Required · reply by \(Format.dayShort(deadline))" }
        return "Required"
    }

    // MARK: Footer

    @ViewBuilder private var footer: some View {
        switch step {
        case 1, 2, 3:
            Button(step == 3 ? "Preview as guest" : "Continue") { next() }
                .buttonStyle(.primary)
            if !wasPublished {
                Button("Save draft") { store.saveDraft(event); dismiss() }
                    .buttonStyle(.tertiary)
            }
        case 4:
            Button("Looks good, continue") { step = 5 }
                .buttonStyle(.primary)
            Button("Edit event") { step = 1 }
                .buttonStyle(.tertiary)
        default:
            Button(wasPublished ? "Save changes" : "Publish event") {
                store.publish(event)
                withAnimation { didPublish = true }
            }
            .buttonStyle(.primary)
            .disabled(!event.isComplete)
            Button("Back to preview") { step = 4 }
                .buttonStyle(.tertiary)
        }
    }

    private func next() {
        let blocked: Bool
        switch step {
        case 1: blocked = trimmed(event.name).isEmpty
        case 2: blocked = event.day == nil || event.startTime == nil || trimmed(event.venue).isEmpty
        default: blocked = false
        }
        if blocked {
            showErrors = true
        } else {
            showErrors = false
            step += 1
        }
    }

    // MARK: Published

    private var publishedView: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                SuccessMark()
                    .padding(.top, Space.xxl)
                Text(wasPublished ? "Changes saved" : "\(event.name) is live")
                    .font(Typo.title1)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                Text(publishedMessage)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                EventCard(title: event.name, date: Format.when(event), location: Format.venue(event),
                          badge: .published, trailing: event.rsvpRequired ? "RSVPs are open" : "No RSVP needed",
                          photo: event.coverPhoto)
            }
            .screenStyle()
        }
        .pinnedFooter {
            Button("Done") { dismiss() }
                .buttonStyle(.primary)
        }
    }

    private var publishedMessage: String {
        let guests = "All \(store.data.guests.count) invited guests can now see it in their Schedule."
        guard event.rsvpRequired, let deadline = event.rsvpDeadline else { return guests }
        return "\(guests) RSVPs close \(Format.dayShort(deadline))."
    }

    // MARK: Helpers

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func time(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }
}
