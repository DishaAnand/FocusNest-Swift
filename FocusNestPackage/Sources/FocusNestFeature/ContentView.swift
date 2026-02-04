import SwiftUI
import SwiftData

@MainActor
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .timer
    @State private var showBuddySession = false
    @State private var pendingSessionId: String?
    @State private var showJoinSession = false

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
        .sheet(isPresented: $showBuddySession) {
            BuddySessionView()
        }
        .sheet(isPresented: $showJoinSession) {
            if let sessionId = pendingSessionId {
                JoinSessionView(sessionId: sessionId) {
                    pendingSessionId = nil
                }
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
        guard url.scheme == "focusnest",
              url.host == "buddy",
              let sessionId = url.pathComponents.dropFirst().first else {
            return
        }
        pendingSessionId = sessionId
        showJoinSession = true
    }
}

enum AppTab: Hashable {
    case home, timer, progress, settings
}
