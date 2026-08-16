import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var previousNonCreateTab = 0
    @State private var showCreate = false
    @State private var createPrefill: CreateSessionPrefill?
    @State private var createBounceToken = 0

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
                    Label {
                        Text("Create")
                    } icon: {
                        Image(systemName: "plus.circle.fill")
                            .symbolEffect(.bounce, value: createBounceToken)
                    }
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
                createBounceToken += 1
                TabBarItemBounce.bounceItem(at: 2)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                createPrefill = nil
                showCreate = true
                selectedTab = previousNonCreateTab
            } else {
                previousNonCreateTab = newValue
            }
        }
        .onChange(of: appState.createSessionRequestNonce) { _, _ in
            createPrefill = appState.consumePendingCreateSessionPrefill()
            showCreate = true
        }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                CreateSessionView(prefill: createPrefill) { session in
                    showCreate = false
                    createPrefill = nil
                    appState.presentSessionDetail(id: session.id, on: .myGames)
                    appState.touchSessionFeedRefresh()
                    previousNonCreateTab = 1
                    selectedTab = 1
                }
            }
            .appSheetChrome()
        }
    }
}

#Preview {
    MainTabView()
        .environment(AppState())
}
