import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var previousNonCreateTab = 0
    @State private var showCreate = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "sportscourt")
                }
                .tag(0)

            MyGamesView()
                .tabItem {
                    Label("My Games", systemImage: "calendar")
                }
                .tag(1)

            Color.clear
                .tabItem {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
        }
        .tint(AppColor.gold)
        .onChange(of: appState.sessionDetailDeepLink) { _, id in
            guard id != nil else { return }
            switch appState.sessionDetailDeepLinkTarget {
            case .discover:
                selectedTab = 0
            case .myGames:
                selectedTab = 1
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 2 {
                showCreate = true
                selectedTab = previousNonCreateTab
            } else {
                previousNonCreateTab = newValue
            }
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateSessionView { session in
                    showCreate = false
                    appState.presentSessionDetail(id: session.id, on: .myGames)
                    appState.touchSessionFeedRefresh()
                    previousNonCreateTab = 1
                    selectedTab = 1
                }
            }
            .presentationDetents([.large])
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
