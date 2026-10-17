import SwiftUI

@main
struct IntertwineApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Palette.bgAccent)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            switch store.role {
            case .couple: CoupleTabView()
            case .guest: GuestTabView()
            case nil: RolePickerView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.role)
    }
}

/// First launch. There are no accounts yet, so this lets you try either side of the app.
struct RolePickerView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text("Intertwine")
                        .font(Typo.largeTitle)
                        .foregroundStyle(Palette.textPrimary)
                    Text("One wedding, in one place.")
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                }
                .padding(.top, Space.xxxl)

                roleCard(title: "I’m getting married",
                         detail: "Plan your events and share every detail with guests. Demo: Mia & Ryan.",
                         systemImage: "heart",
                         role: .couple)
                roleCard(title: "I’m a guest",
                         detail: "See where to be, what to wear, and RSVP. Demo: Rosa, mother of the bride.",
                         systemImage: "envelope.open",
                         role: .guest)

                Text("You can switch sides any time from the profile menu.")
                    .font(Typo.footnote)
                    .foregroundStyle(Palette.textTertiary)
            }
            .screenStyle()
        }
        .background(Palette.bgCanvas)
    }

    private func roleCard(title: String, detail: String, systemImage: String, role: Role) -> some View {
        Button {
            store.switchRole(to: role)
        } label: {
            HStack(alignment: .top, spacing: Space.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.iconPrimary)
                    .frame(width: 44, height: 44)
                    .background(Palette.bgAccentSubtle, in: Circle())
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(title)
                        .font(Typo.title3)
                        .foregroundStyle(Palette.textPrimary)
                    Text(detail)
                        .font(Typo.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
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

/// Shared tab bar styling for both sides of the app.
struct AppTabBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(Palette.bgSurface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
