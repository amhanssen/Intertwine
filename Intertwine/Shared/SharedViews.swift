import SwiftUI

/// Profile button with demo actions, shown on both Home screens.
struct ProfileMenu: View {
    @Environment(AppStore.self) private var store
    let initials: String
    /// Shown in place of the initials when set.
    var photo: Image? = nil
    @State private var confirmReset = false
    @State private var confirmSignOut = false
    @State private var goingOnline = false

    var body: some View {
        Menu {
            if store.role == .couple {
                Button("Switch to guest view", systemImage: "person") { store.switchRole(to: .guest) }
            } else {
                Button("Switch to couple view", systemImage: "heart") { store.switchRole(to: .couple) }
            }
            if store.isSyncing, let email = store.signedInEmail {
                Section("Signed in as \(email)") {
                    Button("Sync now", systemImage: "arrow.triangle.2.circlepath") { Task { await store.sync() } }
                    Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) { confirmSignOut = true }
                }
            }
            if !store.isDemo && !store.isSyncing && store.role == .couple {
                Button("Share with guests online", systemImage: "globe") { goingOnline = true }
            }
            Button("Back to start", systemImage: "arrow.uturn.backward") { store.switchRole(to: nil) }
            if store.isDemo {
                Button("Reset demo data", systemImage: "arrow.counterclockwise", role: .destructive) { confirmReset = true }
            }
        } label: {
            if let photo {
                photo
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay { Circle().strokeBorder(Palette.borderSubtle, lineWidth: 2) }
            } else {
                Text(initials)
                    .font(Typo.footnote.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Palette.bgAccentSubtle, in: Circle())
            }
        }
        .accessibilityLabel("Profile and settings")
        .sheet(isPresented: $goingOnline) { GoOnlineSheet() }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { store.signOut() }
        } message: {
            Text("Your wedding stays saved in your account. Sign in again to open it on this phone.")
        }
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
            CoverPlaceholder(photo: event.coverPhoto, height: 150)
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

/// Shown on the couple's Home when the last sync didn't go through.
struct SyncProblemBanner: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if case .failed(let message) = store.syncState {
            Panel(background: Palette.bgWarning, bordered: false) {
                Text(message)
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textWarning)
                if store.session != nil {
                    Button("Try again") { Task { await store.sync() } }
                        .font(Typo.headline)
                        .foregroundStyle(Palette.textWarning)
                }
            }
        }
    }
}

/// For a wedding set up on this phone only: create an account (or sign in) and put the
/// wedding online, so guests can open it on the website.
struct GoOnlineSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var hasAccount = false
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var waitingForConfirmation = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ScreenHeader(title: "Share with guests online",
                                 subtitle: "Make an account so guests can see \(store.wedding.coupleNames)’s events and RSVP on the wedding website. Everything you’ve set up comes with you.")
                    Picker("Account", selection: $hasAccount) {
                        Text("New account").tag(false)
                        Text("I have an account").tag(true)
                    }
                    .pickerStyle(.segmented)
                    LabeledField(label: "Email", text: $email, placeholder: "mia@example.com")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                    LabeledField(label: "Password", text: $password, placeholder: hasAccount ? "" : "At least 8 characters",
                                 helper: hasAccount ? nil : "At least 8 characters", secure: true)
                        .textContentType(hasAccount ? .password : .newPassword)
                    if let message {
                        Panel(background: waitingForConfirmation ? Palette.bgAccentSubtle : Palette.bgWarning, bordered: false) {
                            Text(message)
                                .font(Typo.subheadline)
                                .foregroundStyle(waitingForConfirmation ? Palette.textPrimary : Palette.textWarning)
                        }
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .pinnedFooter {
                Button(buttonTitle) { Task { await go() } }
                    .buttonStyle(.primary)
                    .disabled(!email.contains("@") || password.count < (hasAccount ? 1 : 8) || working)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var buttonTitle: String {
        if working { return "One moment…" }
        if waitingForConfirmation { return "I’ve confirmed my email" }
        return hasAccount ? "Sign in and share" : "Create account and share"
    }

    private func go() async {
        working = true
        defer { working = false }
        let address = email.trimmingCharacters(in: .whitespaces)
        do {
            if hasAccount || waitingForConfirmation {
                // Signing in would replace this phone's wedding with the account's, if it has one,
                // so sign in without loading it: this wedding is the one going online.
                try await store.signInKeepingWedding(email: address, password: password)
            } else {
                try await store.createAccount(email: address, password: password)
            }
            store.moveWeddingOnline()
            dismiss()
        } catch SupabaseError.needsEmailConfirmation {
            waitingForConfirmation = true
            message = "We sent a link to \(address). Open it, then come back and tap “I’ve confirmed my email”."
        } catch {
            message = error.localizedDescription
        }
    }
}
