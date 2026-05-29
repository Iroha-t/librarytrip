import SwiftUI
import MapKit

struct LibraryMapView: View {
    @EnvironmentObject var appState: AppState
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )
    @State private var selectedLibrary: Library?
    @State private var showDetail = false
    @State private var searchText = ""
    @State private var filterStudy = false
    @State private var filterCafe = false

    var filteredLibraries: [Library] {
        appState.libraries.filter { lib in
            let matchesSearch = searchText.isEmpty ||
                lib.name.contains(searchText) ||
                lib.prefecture.contains(searchText) ||
                lib.city.contains(searchText)
            let matchesStudy = !filterStudy || lib.hasStudyRoom
            let matchesCafe = !filterCafe || lib.hasCafe
            return matchesSearch && matchesStudy && matchesCafe
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $cameraPosition) {
                ForEach(filteredLibraries) { library in
                    Annotation(library.name, coordinate: library.coordinate) {
                        LibraryMapPin(
                            library: library,
                            isSelected: selectedLibrary?.id == library.id,
                            isVisited: appState.visitedLibraryIds.contains(library.id)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedLibrary = library
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            VStack(spacing: 8) {
                searchAndFilterBar
                Spacer()
                if let lib = selectedLibrary {
                    libraryPreviewCard(lib)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let lib = selectedLibrary {
                LibraryDetailView(library: lib)
                    .environmentObject(appState)
            }
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.toshoSubtext)
                    TextField("図書館名・地名で検索", text: $searchText)
                        .font(.subheadline)
                }
                .padding(12)
                .background(Color.toshoCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(
                        label: "自習室あり",
                        icon: "pencil",
                        isOn: $filterStudy
                    )
                    filterChip(
                        label: "カフェあり",
                        icon: "cup.and.saucer",
                        isOn: $filterCafe
                    )
                    filterChip(
                        label: "電源あり",
                        icon: "bolt",
                        isOn: .constant(false)
                    )
                    filterChip(
                        label: "Wi-Fiあり",
                        icon: "wifi",
                        isOn: .constant(false)
                    )
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func libraryPreviewCard(_ library: Library) -> some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.toshoGreen.opacity(0.7), Color.toshoGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 70, height: 70)
                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(library.name)
                        .font(.headline)
                        .foregroundColor(.toshoText)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.toshoGreen)
                        Text(library.address)
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                            .lineLimit(1)
                    }

                    HStack(spacing: 6) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.toshoAmber)
                            Text(String(format: "%.1f", library.rating))
                                .font(.caption.bold())
                        }
                        Text("·")
                            .foregroundColor(.toshoSubtext)
                        Text(library.openingHours)
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                    }

                    HStack(spacing: 8) {
                        miniFeature(show: library.hasStudyRoom, icon: "pencil", label: "自習室")
                        miniFeature(show: library.hasPowerOutlets, icon: "bolt", label: "電源")
                        miniFeature(show: library.hasWifi, icon: "wifi", label: "Wi-Fi")
                        miniFeature(show: library.hasCafe, icon: "cup.and.saucer", label: "カフェ")
                    }
                }

                Spacer()

                VStack(spacing: 8) {
                    Button {
                        appState.toggleWishlist(library)
                    } label: {
                        Image(systemName: appState.wishlistLibraryIds.contains(library.id) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.toshoGreen)
                    }
                    Button {
                        showDetail = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.toshoSubtext)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.toshoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func filterChip(label: String, icon: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(isOn.wrappedValue ? .white : .toshoGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isOn.wrappedValue ? Color.toshoGreen : Color.toshoCard)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.07), radius: 4, y: 1)
        }
    }

    private func miniFeature(show: Bool, icon: String, label: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 9))
        }
        .foregroundColor(show ? .toshoGreen : Color.gray.opacity(0.3))
    }
}

struct LibraryMapPin: View {
    let library: Library
    let isSelected: Bool
    let isVisited: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isVisited ? Color.toshoAmber : Color.toshoGreen)
                    .frame(width: isSelected ? 44 : 34, height: isSelected ? 44 : 34)
                    .shadow(color: (isVisited ? Color.toshoAmber : Color.toshoGreen).opacity(0.4), radius: 4)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: isSelected ? 18 : 14))
                    .foregroundColor(.white)
            }
            Triangle()
                .fill(isVisited ? Color.toshoAmber : Color.toshoGreen)
                .frame(width: 10, height: 6)
        }
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.25), value: isSelected)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    LibraryMapView()
        .environmentObject(AppState())
}
