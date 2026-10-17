import SwiftUI

/// Profile button with demo actions, shown on both Home screens.
struct ProfileMenu: View {
    @Environment(AppStore.self) private var store
    let initials: String
    @State private var confirmReset = false

    var body: some View {
        Menu {
            if store.role == .couple {
                Button("Switch to guest view", systemImage: "person") { store.switchRole(to: .guest) }
            } else {
                Button("Switch to couple view", systemImage: "heart") { store.switchRole(to: .couple) }
            }
            Button("Back to start", systemImage: "arrow.uturn.backward") { store.switchRole(to: nil) }
            Button("Reset demo data", systemImage: "arrow.counterclockwise", role: .destructive) { confirmReset = true }
        } label: {
            Text(initials)
                .font(Typo.footnote.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 44, height: 44)
                .background(Palette.bgAccentSubtle, in: Circle())
        }
        .accessibilityLabel("Profile and settings")
        .confirmationDialog("Reset the demo?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset demo data", role: .destructive) { store.resetDemo() }
        } message: {
            Text("This puts back Mia & Ryan’s sample events, guests and RSVPs.")
        }
    }
}

/// Cover photo, title, date and welcome message at the top of an event.
struct EventHeader: View {
    let event: WeddingEvent

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            CoverPlaceholder(height: 150)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(event.name)
                    .font(Typo.title1)
                    .foregroundStyle(Palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text(Format.when(event))
                    .font(Typo.headline)
                    .foregroundStyle(Palette.textSecondary)
                if !event.welcomeMessage.isEmpty {
                    Text(event.welcomeMessage)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, Space.xxs)
                }
            }
        }
    }
}

/// "Where" panel with a link to Apple Maps.
struct WherePanel: View {
    let event: WeddingEvent
    var linksEnabled: Bool = true

    var body: some View {
        Panel {
            Text("Where")
                .font(Typo.title3)
                .foregroundStyle(Palette.textPrimary)
            Text(Format.venue(event))
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
            if !event.directions.isEmpty {
                Text(event.directions)
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
            if !event.venue.isEmpty, let url = mapsURL {
                Link(destination: url) {
                    Label("Get directions", systemImage: "map")
                }
                .buttonStyle(.tertiary)
                .disabled(!linksEnabled)
            }
        }
    }

    private var mapsURL: URL? {
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [URLQueryItem(name: "q", value: event.venue)]
        return components?.url
    }
}

/// Dress code summary panel.
struct DressCodePanel: View {
    let event: WeddingEvent

    var body: some View {
        Panel {
            Text("What to wear")
                .font(Typo.title3)
                .foregroundStyle(Palette.textPrimary)
            Text(event.dressCode)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
            if !event.dressGuidance.isEmpty {
                Text(event.dressGuidance)
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

/// Shows "Time not set" style placeholders until a value is chosen (Figma: Text Field, filled state).
struct OptionalDateField: View {
    let label: String
    @Binding var date: Date?
    var components: DatePickerComponents = .date
    let defaultValue: Date
    var addTitle: String = "Add"
    var error: String? = nil
    var clearable: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            FieldBox(label: label) {
                if let value = date {
                    DatePicker(label, selection: Binding(get: { value }, set: { date = $0 }),
                               displayedComponents: components)
                        .labelsHidden()
                    Spacer(minLength: 0)
                    if clearable {
                        Button {
                            date = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Palette.iconInactive)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear \(label)")
                    }
                } else {
                    Button(addTitle) { date = defaultValue }
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 0)
                }
            }
            if let error {
                Text(error)
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textError)
            }
        }
    }
}
