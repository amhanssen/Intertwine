import ContactsUI
import SwiftUI

/// First-time setup (Figma: Onboarding · First-time setup).
/// O1 Welcome → O2 Choose your role → O3 Create account → O4 Wedding info → O6 Invite guests → Home.
/// There are no accounts yet, so a couple's details stay on this phone, and a guest sees the
/// sample wedding until invites can be sent.
struct OnboardingFlow: View {
    @Environment(AppStore.self) private var store
    @State private var path: [Step] = []
    @State private var draft = OnboardingDraft()
    @State private var confirmDemo = false
    @State private var confirmStartOver = false
    @State private var signingIn = false

    enum Step: Hashable {
        case role, account, wedding, invite
    }

    var body: some View {
        NavigationStack(path: $path) {
            welcome
                .navigationDestination(for: Step.self) { step in
                    // Each step is its own view reading `draft`, so it redraws as the draft changes.
                    Group {
                        switch step {
                        case .role:
                            RoleStep(draft: draft) {
                                if draft.role == .couple { path.append(.account) } else { store.startDemo(as: .guest) }
                            }
                        case .account:
                            AccountStep(draft: draft) {
                                if !draft.weddingCreated { draft.wedding.coupleNames = draft.defaultCoupleNames }
                                path.append(.wedding)
                            }
                        case .wedding:
                            WeddingStep(draft: draft) {
                                draft.save(to: store)
                                path.append(.invite)
                            }
                        case .invite:
                            InviteGuestsStep { store.switchRole(to: .couple) }
                        }
                    }
                    .background(Palette.bgCanvas)
                }
        }
        .tint(Palette.bgAccent)
    }

    // MARK: O1 · Welcome

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                MonogramCover(height: 320)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Intertwine")
                        .font(Typo.largeTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text("One wedding in one place")
                        .font(Typo.title3)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Plan every wedding event with your guests: RSVPs, schedules and what to wear, in one shared place.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .screenStyle()
        }
        .background(Palette.bgCanvas)
        .pinnedFooter {
            if store.isDemo {
                Button("Get started") { path.append(.role) }
                    .buttonStyle(.primary)
            } else {
                // Someone came back here with their own wedding set up: don't lose it by accident.
                Button("Back to \(store.wedding.coupleNames)") { store.switchRole(to: .couple) }
                    .buttonStyle(.primary)
                Button("Set up a new wedding") { confirmStartOver = true }
                    .buttonStyle(.secondary)
            }
            if store.isDemo {
                Button("I already have an account") { signingIn = true }
                    .buttonStyle(.tertiary)
            }
            Button("Try the demo") { confirmDemo = true }
                .buttonStyle(.tertiary)
        }
        .sheet(isPresented: $signingIn) {
            // Signed in, but no wedding on this account yet: set one up.
            SignInSheet { path = [.role, .wedding] }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Set up a new wedding?", isPresented: $confirmStartOver, titleVisibility: .visible) {
            Button("Start over", role: .destructive) {
                draft = OnboardingDraft()
                path.append(.role)
            }
        } message: {
            Text("When you finish, it replaces \(store.wedding.coupleNames)’s wedding on this phone.")
        }
        .confirmationDialog("Try Mia & Ryan’s sample wedding", isPresented: $confirmDemo, titleVisibility: .visible) {
            Button("As the couple") { store.startDemo(as: .couple) }
            Button("As a guest (Rosa)") { store.startDemo(as: .guest) }
        } message: {
            Text(store.isDemo
                 ? "You can switch sides any time from the profile menu."
                 : "This replaces the wedding on this phone with the sample wedding.")
        }
    }
}

/// What the couple has entered so far.
@MainActor
@Observable
final class OnboardingDraft {
    var role: Role = .couple
    var name = ""
    var partnerName = ""
    var email = ""
    var wedding = Wedding(
        coupleNames: "", date: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date(),
        venue: "", hotelInfo: "", parkingInfo: "")
    /// Set once the wedding is saved, so going back and continuing again only updates it and
    /// guests added on the next step aren't lost.
    private(set) var weddingCreated = false

    var defaultCoupleNames: String { "\(name.trimmed) & \(partnerName.trimmed)" }

    func save(to store: AppStore) {
        if wedding.coupleNames.trimmed.isEmpty { wedding.coupleNames = defaultCoupleNames }
        if weddingCreated {
            store.updateWedding(wedding)
        } else {
            store.setUpWedding(wedding, account: CoupleAccount(name: name.trimmed, partnerName: partnerName.trimmed,
                                                               email: email.trimmed))
            weddingCreated = true
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - O2 · Choose your role

struct RoleStep: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ScreenHeader(title: "How will you use Intertwine?", subtitle: "We’ll set up the right app for you.")
                VStack(spacing: Space.sm) {
                    roleCard(.couple, title: "I’m getting married",
                             detail: "Create events, invite guests and track RSVPs.")
                    roleCard(.guest, title: "I’m a guest",
                             detail: "See the schedule and what to wear, and RSVP. You’ll need an invite from the couple.")
                }
                if draft.role == .guest {
                    Panel(background: Palette.bgAccentSubtle, bordered: false) {
                        Text("Invites can’t be sent between phones yet, so you’ll see Mia & Ryan’s sample wedding as their guest Rosa.")
                            .font(Typo.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
            }
            .screenStyle()
        }
        .pinnedFooter {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
        }
    }

    private func roleCard(_ option: Role, title: String, detail: String) -> some View {
        let selected = draft.role == option
        return Button { draft.role = option } label: {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(title)
                    .font(Typo.title3)
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Typo.subheadline)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .background(Palette.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Palette.borderFocus : Palette.borderSubtle, lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - O3 · Create account

struct AccountStep: View {
    @Environment(AppStore.self) private var store
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void
    @State private var password = ""
    @State private var working = false
    @State private var message: String?
    @State private var waitingForConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                ScreenHeader(title: "Create your account",
                             subtitle: "You and your partner can both sign in to manage the wedding.")
                LabeledField(label: "Your name", text: $draft.name, placeholder: "Mia")
                LabeledField(label: "Your partner’s name", text: $draft.partnerName, placeholder: "Ryan")
                LabeledField(label: "Email", text: $draft.email, placeholder: "mia@example.com")
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                LabeledField(label: "Password", text: $password, placeholder: "At least 8 characters",
                             helper: "At least 8 characters", secure: true)
                    .textContentType(.newPassword)
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
        .scrollDismissesKeyboard(.interactively)
        .pinnedFooter {
            Button(waitingForConfirmation ? "I’ve confirmed my email" : (working ? "Creating account…" : "Create account")) {
                Task { await createAccount() }
            }
            .buttonStyle(.primary)
            .disabled(!canCreate || working)
            Button("Set up on this phone only") { onContinue() }
                .buttonStyle(.tertiary)
                .disabled(draft.name.trimmed.isEmpty || draft.partnerName.trimmed.isEmpty || working)
        }
    }

    private var canCreate: Bool {
        !draft.name.trimmed.isEmpty && !draft.partnerName.trimmed.isEmpty
            && draft.email.contains("@") && password.count >= 8
    }

    /// Creates the account, or after an email confirmation, signs in with it.
    private func createAccount() async {
        working = true
        defer { working = false }
        do {
            if waitingForConfirmation {
                if try await store.signIn(email: draft.email.trimmed, password: password) {
                    return // This account already had a wedding; it's now open.
                }
            } else {
                try await store.createAccount(email: draft.email.trimmed, password: password)
            }
            message = nil
            onContinue()
        } catch SupabaseError.needsEmailConfirmation {
            waitingForConfirmation = true
            message = "We sent a link to \(draft.email.trimmed). Open it on this phone or your computer, then come back and tap “I’ve confirmed my email”."
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Sign in (O1 · "I already have an account")

struct SignInSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Called when the account signed in but has no wedding yet.
    let onNoWedding: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    ScreenHeader(title: "Welcome back", subtitle: "Sign in to open your wedding on this phone.")
                    LabeledField(label: "Email", text: $email, placeholder: "mia@example.com")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                    LabeledField(label: "Password", text: $password, secure: true)
                        .textContentType(.password)
                    if let message {
                        Panel(background: Palette.bgWarning, bordered: false) {
                            Text(message)
                                .font(Typo.subheadline)
                                .foregroundStyle(Palette.textWarning)
                        }
                    }
                }
                .screenStyle()
            }
            .background(Palette.bgCanvas)
            .pinnedFooter {
                Button(working ? "Signing in…" : "Sign in") { Task { await signIn() } }
                    .buttonStyle(.primary)
                    .disabled(!email.contains("@") || password.isEmpty || working)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func signIn() async {
        working = true
        defer { working = false }
        do {
            let found = try await store.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            dismiss()
            if !found { onNoWedding() }
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - O4 · Wedding info

struct WeddingStep: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.lg) {
                ScreenHeader(title: "Tell us about the wedding",
                             subtitle: "Guests see this on every invite. You can change it later.")
                LabeledField(label: "Names shown to guests", text: $draft.wedding.coupleNames, placeholder: "Mia & Ryan")
                FieldBox(label: "Wedding date") {
                    DatePicker("Wedding date", selection: $draft.wedding.date, in: Date()..., displayedComponents: .date)
                        .labelsHidden()
                    Spacer(minLength: 0)
                }
                LabeledField(label: "Venue", text: $draft.wedding.venue, placeholder: "Seaport Hotel")
                FieldBox(label: "Expected guests", helper: "Used to suggest registry price ranges") {
                    Stepper("About \(draft.wedding.expectedGuests ?? 100)",
                            value: Binding(get: { draft.wedding.expectedGuests ?? 100 },
                                           set: { draft.wedding.expectedGuests = $0 }),
                            in: 10...500, step: 10)
                }
            }
            .screenStyle()
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: onContinue)
            }
        }
        .pinnedFooter {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary)
                .disabled(draft.wedding.coupleNames.trimmed.isEmpty)
            Button("Skip for now", action: onContinue)
                .buttonStyle(.tertiary)
        }
    }
}

// MARK: - O6 · Invite guests

struct InviteGuestsStep: View {
    @Environment(AppStore.self) private var store
    let onFinish: () -> Void
    @State private var addingGuest = false
    @State private var pickingContacts = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                ScreenHeader(title: "Invite your guests",
                             subtitle: "Add guests now or later. They see an event once you publish it.")
                RowGroup {
                    Button { pickingContacts = true } label: {
                        ListRow(title: "Import from contacts", subtitle: "Pick guests from your phone",
                                systemImage: "person.2")
                    }
                    .buttonStyle(.plain)
                    RowDivider()
                    Button { addingGuest = true } label: {
                        ListRow(title: "Add guests one by one", subtitle: "Name and how many people",
                                systemImage: "plus")
                    }
                    .buttonStyle(.plain)
                    RowDivider()
                    ListRow(title: "Share an invite link", subtitle: "Coming with accounts",
                            systemImage: "bubble.left", showsChevron: false)
                        .opacity(0.5)
                        .accessibilityHint("Not available yet")
                }
                if !store.data.guests.isEmpty {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        SectionTitle(store.data.guests.count == 1 ? "1 guest added" : "\(store.data.guests.count) guests added")
                        Text(store.data.guests.map(\.name).joined(separator: ", "))
                            .font(Typo.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .screenStyle()
        }
        .background { ContactPicker(isPresented: $pickingContacts) { store.addGuests(named: $0) } }
        .sheet(isPresented: $addingGuest) { AddGuestSheet() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") { onFinish() }
            }
        }
        .pinnedFooter {
            Button("Go to Home") { onFinish() }
                .buttonStyle(.primary)
            if store.data.guests.isEmpty {
                Button("Skip for now") { onFinish() }
                    .buttonStyle(.tertiary)
            }
        }
    }
}

/// The system contact picker, which needs no Contacts permission. It has to be presented from
/// UIKit directly; SwiftUI sheets show it blank.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onPick: ([String]) -> Void

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        guard isPresented, host.presentedViewController == nil else { return }
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        DispatchQueue.main.async { host.present(picker, animated: true) }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        init(parent: ContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onPick(contacts.compactMap { CNContactFormatter.string(from: $0, style: .fullName) })
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}
