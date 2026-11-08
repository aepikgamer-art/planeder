import SwiftUI

struct SwipeableCardView: View {
    let card: PlaneCard
    var onSwipe: (PlaneCard, _ liked: Bool, _ superLiked: Bool) -> Void
    var isTop: Bool
    var queuedAction: SwipeAction?

    @State private var offset: CGSize = .zero
    @State private var fired = false

    private let threshold: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            let dragProgress = offset.width / threshold
            ZStack {
                cardBody(width: geo.size.width - 24, height: geo.size.height - 24)

                // LIKE / NOPE stamps
                Text("LIKE")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(-12))
                    .overlay(Capsule().stroke(.green, lineWidth: 6).padding(-8))
                    .opacity(Double(max(0, min(dragProgress, 1))) * (dragProgress > 0.25 ? 1 : 0))
                    .padding(.top, 60)
                    .padding(.leading, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Text("NOPE")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.red)
                    .rotationEffect(.degrees(12))
                    .overlay(Capsule().stroke(.red, lineWidth: 6).padding(-8))
                    .opacity(Double(max(0, min(-dragProgress, 1))) * (dragProgress < -0.25 ? 1 : 0))
                    .padding(.top, 60)
                    .padding(.trailing, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 20)), anchor: .bottom)
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard isTop else { return }
                    offset = value.translation
                }
                .onEnded { value in
                    guard isTop, !fired else { return }
                    if value.translation.width > threshold {
                        fire(liked: true, superLiked: false)
                    } else if value.translation.width < -threshold {
                        fire(liked: false, superLiked: false)
                    } else if value.translation.height < -threshold * 1.4 {
                        fire(liked: true, superLiked: true) // swipe up = super like
                    } else {
                        offset = .zero
                    }
                }
        )
        .onChange(of: queuedAction) { _, action in
            guard isTop, let action, !fired else { return }
            switch action {
            case .like: fire(liked: true, superLiked: false)
            case .nope: fire(liked: false, superLiked: false)
            case .superLike: fire(liked: true, superLiked: true)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: offset)
    }

    private func fire(liked: Bool, superLiked: Bool) {
        guard !fired else { return }
        fired = true
        let direction: CGSize = superLiked
            ? CGSize(width: 0, height: -900)
            : CGSize(width: liked ? 900 : -900, height: -80)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = direction
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onSwipe(card, liked, superLiked)
        }
    }

    @ViewBuilder
    private func cardBody(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            // Photo cropped to fill the whole card
            AsyncImage(url: URL(string: card.imageURL)!) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                case .failure:
                    ZStack {
                        Rectangle().fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                        Image(systemName: "airplane").font(.system(size: 60)).foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: width, height: height)
                default:
                    Rectangle().fill(.ultraThinMaterial)
                        .frame(width: width, height: height)
                        .overlay(ProgressView().tint(.white))
                }
            }

            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                .frame(height: height * 0.55)
                .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: 10) {
                (Text(card.reg).font(.system(size: 40, weight: .heavy, design: .rounded))
                 + Text("  \(card.airline)").font(.system(size: 22, weight: .medium)).foregroundColor(.white.opacity(0.9)))
                    .shadow(radius: 8)

                HStack(spacing: 8) {
                    if !card.aircraft.isEmpty { GlassChip(text: card.aircraft, icon: "airplane") }
                    if !card.serial.isEmpty { GlassChip(text: "S/N \(card.serial)", icon: "number") }
                }
                if !card.location.isEmpty {
                    Label(card.location, systemImage: "mappin.and.ellipse")
                        .font(.footnote).foregroundStyle(.white.opacity(0.8))
                }
                if !card.photographer.isEmpty {
                    Text("📷 \(card.photographer) · via JetPhotos")
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(.white.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
    }
}

struct GlassChip: View {
    let text: String
    let icon: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text).font(.caption).fontWeight(.semibold).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
    }
}
