import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)

            LibraryMapView()
                .tabItem {
                    Label("マップ", systemImage: "map.fill")
                }
                .tag(1)

            MyTripView()
                .tabItem {
                    Label("きろく", systemImage: "checkmark.seal.fill")
                }
                .tag(2)

            BookRecordsView()
                .tabItem {
                    Label("本の記録", systemImage: "books.vertical.fill")
                }
                .tag(3)
        }
        .tint(.toshoGreen)
        .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
