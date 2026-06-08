import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    @State private var selectedTab = 0
    @State private var showRecordPicker = false
    @AppStorage("username") private var username = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            tabContent
                .ignoresSafeArea(edges: .bottom)
                .animation(.easeInOut(duration: 0.2), value: appState.isPresentingDetailSheet)

            // Floating "+" record button — shown on ホーム and 探す tabs only
            if selectedTab != 2 && !appState.isPresentingDetailSheet {
                HStack {
                    Spacer()
                    Button {
                        showRecordPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.toshoRed)
                                .frame(width: 52, height: 52)
                                .shadow(color: Color.toshoRed.opacity(0.38), radius: 14, y: 5)
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 24)
                }
                .padding(.bottom, 84)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3), value: selectedTab)
            }

            if !appState.isPresentingDetailSheet {
                floatingTabBar
                    .padding(.bottom, 10)
                    .transition(.opacity)
            }
        }
        .environmentObject(appState)
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await appState.loadVisitedLibraries() }
                group.addTask { await appState.fetchAllLibraries() }
            }
        }
        .sheet(isPresented: $showRecordPicker) {
            LibraryRecordPickerView()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: Binding(
            get: { username.isEmpty },
            set: { _ in }
        )) {
            OnboardingView()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:  HomeView()
        case 1:  LibrarySearchView(selectedTab: $selectedTab)
        default: LibraryMapView()
        }
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "house.fill",      label: "ホーム", tag: 0)
            tabItem(icon: "magnifyingglass", label: "探す",   tag: 1)
            tabItem(icon: "map.fill",        label: "マップ", tag: 2)
        }
        .frame(height: 60)
        .padding(.horizontal, 16)
        .background(
            Capsule()
                .fill(Color.toshoCard)
                .shadow(color: .black.opacity(0.13), radius: 20, y: 6)
        )
        .padding(.horizontal, 36)
    }

    private func tabItem(icon: String, label: String, tag: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tag
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selectedTab == tag ? .bold : .regular))
                    .foregroundColor(selectedTab == tag ? .toshoRed : .toshoSubtext)
                Text(label)
                    .font(.system(size: 9, weight: selectedTab == tag ? .semibold : .regular))
                    .foregroundColor(selectedTab == tag ? .toshoRed : .toshoSubtext)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
