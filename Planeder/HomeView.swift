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
                        SwipeableCardView(
                            card: card,
                            onSwipe: { c, liked, superLiked in vm.swipe(c, liked: liked, superLiked: superLiked) },
                            isTop: card.id == vm.cards.last?.id
                        )
                    }
                    if vm.loading && vm.cards.isEmpty { ProgressView().tint(.white).scaleEffect(1.4) }
                }
                .padding(.horizontal, 12)

                // Action bar
                HStack(spacing: 32) {
                    GlassCircle(tint: .red, icon: "xmark") {
                        nopeTop()
                    }
                    GlassCircle(tint: .blue, icon: "airplane.circle.fill") {
                        superLikeTop()
                    }
                    GlassCircle(tint: .green, icon: "heart.fill") {
                        likeTop()
                    }
                }
                .padding(.bottom, 12)
            }

            if let match = vm.matchPopup {
                MatchOverlay(match: match) { vm.matchPopup = nil }
            }
        }
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

    private func topCard() -> PlaneCard? { vm.cards.last }

    private func likeTop() {
        guard let c = topCard() else { return }
        vm.swipe(c, liked: true)
    }
    private func nopeTop() {
        guard let c = topCard() else { return }
        vm.swipe(c, liked: false)
    }
    private func superLikeTop() {
        guard let c = topCard() else { return }
        vm.swipe(c, liked: true, superLiked: true)
    }
}

struct MatchOverlay: View {
    let match: PlaneCard
    let dismiss: () -> Void

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.55)).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("It's a Match! ✈️❤️")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(match.reg)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                if let url = URL(string: match.jetPhotosLink) {
                    ShareLink("View on JetPhotos", item: url)
                        .buttonStyle(.bordered)
                }
                Button("Keep swiping", action: dismiss)
                    .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
            .padding(32)
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}
