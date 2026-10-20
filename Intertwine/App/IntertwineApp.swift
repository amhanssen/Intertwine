import SwiftUI

@main
struct IntertwineApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var autoSync: Task<Void, Never>?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Palette.bgAccent)
        }
        // While the app is open, send any changes and bring in new RSVPs, questions and
        // gifts: right away, then every 30 seconds, so replies show up without pulling down.
        .onChange(of: scenePhase) { _, phase in
            autoSync?.cancel()
            guard phase == .active else { return }
            autoSync = Task {
                while !Task.isCancelled {
                    await store.sync()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
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
