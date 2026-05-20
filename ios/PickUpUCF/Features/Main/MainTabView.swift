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
                CreateSessionView { _ in
                    showCreate = false
                    appState.touchSessionFeedRefresh()
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
