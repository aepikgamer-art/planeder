import SwiftUI

struct HomeView: View {
    @StateObject private var vm = DeckViewModel()
    @StateObject private var store = MatchStore.shared
    @State private var showMatches = false

    var body: some View {
        ZStack {
            // Glass-y ambient background
            LinearGradient(colors: [Color(hue: 0.6, saturation: 0.5, brightness: 0.15),
                                   Color(hue: 0.75, saturation: 0.4, brightness: 0.1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Text("Planeder")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                    Spacer()
                    Button {
                        showMatches = true
                    } label: {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white)
                    }
                    .ifAvailableGlass()
                    .frame(width: 52, height: 52)
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        if !store.matches.isEmpty {
                            Text("\(store.matches.count)")
                                .font(.caption2.bold()).foregroundStyle(.white)
                                .padding(5).background(Circle().fill(.red))
                                .offset(x: 6, y: -6)
                        }
                    }
                }
                .padding(.horizontal, 20)

                ZStack {
                    if vm.cards.isEmpty && !vm.loading {
                        emptyState
                    }
                    ForEach(Array(vm.cards.suffix(3).enumerated().reversed()), id: \.element.id) { _, card in
                        let isTop = card.id == vm.cards.last?.id
                        SwipeableCardView(
                            card: card,
                            onSwipe: { c, liked, superLiked in vm.swipe(c, liked: liked, superLiked: superLiked) },
                            isTop: isTop,
                            queuedAction: isTop ? vm.queuedAction : nil
                        )
                        // Tinder-style depth stack: back cards shrink + lift
                        .scaleEffect(isTop ? 1 : 0.94)
                        .offset(y: isTop ? 0 : -12)
                        .zIndex(isTop ? 2 : 1)
                    }
                    if vm.loading && vm.cards.isEmpty { ProgressView().tint(.white).scaleEffect(1.4) }
                }
                .padding(.horizontal, 12)

                // Action bar: buttons animate the top card out, Tinder-style
                HStack(spacing: 32) {
                    GlassCircle(tint: .red, icon: "xmark") {
                        vm.queuedAction = .nope
                    }
                    GlassCircle(tint: .blue, icon: "airplane.circle.fill") {
                        vm.queuedAction = .superLike
                    }
                    GlassCircle(tint: .green, icon: "heart.fill") {
                        vm.queuedAction = .like
                    }
                }
                .padding(.bottom, 12)
            }
        }
        // Notification-style match banner, drops in from the top
        .overlay(alignment: .top) {
            if let match = vm.matchPopup {
                MatchBanner(match: match) { vm.matchPopup = nil }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(3)
                    .padding(.horizontal, 12)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.matchPopup?.id)
        .task { vm.startDeck() }
        .onAppear { vm.loadMoreIfNeeded() }
        .sheet(isPresented: $showMatches) {
            MatchesView(store: store)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.circle").font(.system(size: 64)).foregroundStyle(.white.opacity(0.5))
            Text(vm.queueEmpty ? "That's every plane in the pool 💔" : "Loading planes…")
                .font(.headline).foregroundStyle(.white.opacity(0.8))
            if vm.queueEmpty {
                Button("Reshuffle") {
                    vm.startDeck()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - iOS notification-style match banner

struct MatchBanner: View {
    let match: PlaneCard
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // App-icon-style thumbnail
            AsyncImage(url: URL(string: match.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Color(hue: 0.6, saturation: 0.5, brightness: 0.2)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("It's a Match! ✈️")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("\(match.reg) · \(match.airline)")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            // Tap the whole banner to open the plane on JetPhotos
            if let url = URL(string: match.jetPhotosLink) {
                Link(destination: url) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .onTapGesture(perform: dismiss)
        .gesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    if value.translation.height < -40 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dismiss() }
                    }
                }
        )
        // Auto-dismiss after ~4s, like a real notification
        .task(id: match.id) {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dismiss() }
        }
    }
}
