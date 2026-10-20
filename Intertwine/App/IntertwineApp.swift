import SwiftUI

@main
struct IntertwineApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Palette.bgAccent)
        }
        // Each time the app opens, send any changes and bring in new RSVPs.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.sync() } }
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
            case nil: OnboardingFlow()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.role)
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
