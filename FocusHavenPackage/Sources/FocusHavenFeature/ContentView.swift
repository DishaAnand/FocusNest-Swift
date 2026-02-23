import SwiftUI
import SwiftData

/// Wrapper to make String work with sheet(item:)
struct SessionIdWrapper: Identifiable {
    let id: String
    var sessionId: String { id }
}

@MainActor
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionService.self) private var sessionService
    @State private var selectedTab: AppTab = .timer
    @State private var pendingSession: SessionIdWrapper?

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(AppTab.home)

            TimerView()
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
                .tag(AppTab.timer)

            BuddyTabView()
                .tabItem {
                    Label("Buddy", systemImage: "person.2.fill")
                }
                .tag(AppTab.buddy)

            FocusProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.progress)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(AppTab.settings)
        }
        .tint(Theme.focusColor)
        .sheet(item: $pendingSession) { session in
            JoinSessionView(sessionId: session.sessionId) {
                pendingSession = nil
                // Switch to buddy tab after joining
                selectedTab = .buddy
            }
        }
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToTimerTab)) { _ in
            selectedTab = .timer
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "focushaven",
              url.host == "buddy",
              let sessionId = url.pathComponents.dropFirst().first else {
            return
        }
        // Don't open join sheet if user is already in a buddy session
        guard sessionService.currentSession == nil else { return }
        pendingSession = SessionIdWrapper(id: sessionId)
    }
}

enum AppTab: Hashable {
    case home, timer, buddy, progress, settings
}
