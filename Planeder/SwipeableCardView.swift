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
            // dragProgress > 0 = dragged right (nope), < 0 = dragged left (like)
            let dragProgress = offset.width / threshold
            ZStack {
                cardBody(width: geo.size.width - 24, height: geo.size.height - 24)

                // LIKE stamp (swipe left)
                Text("LIKE")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(-12))
                    .overlay(Capsule().stroke(.green, lineWidth: 6).padding(-8))
                    .opacity(Double(max(0, min(-dragProgress, 1))) * (dragProgress < -0.25 ? 1 : 0))
                    .padding(.top, 60)
                    .padding(.leading, 30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // NOPE stamp (swipe right)
                Text("NOPE")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.red)
                    .rotationEffect(.degrees(12))
                    .overlay(Capsule().stroke(.red, lineWidth: 6).padding(-8))
                    .opacity(Double(max(0, min(dragProgress, 1))) * (dragProgress > 0.25 ? 1 : 0))
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
                    if value.translation.width < -threshold {
                        fire(liked: true, superLiked: false)   // left = like
                    } else if value.translation.width > threshold {
                        fire(liked: false, superLiked: false)  // right = nope
                    } else if value.translation.height < -threshold * 1.4 {
                        fire(liked: true, superLiked: true)    // up = super like
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
            : CGSize(width: liked ? -900 : 900, height: -80) // like flies left, nope flies right
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = direction
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onSwipe(card, liked, superLiked)
        }
    }

    // MARK: - Landscape-cropped photo on top, info panel below

    @ViewBuilder
    private func cardBody(width: CGFloat, height: CGFloat) -> some View {
        let photoHeight = width * 0.62 // landscape crop box, 16:10-ish

        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: card.imageURL)!) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: photoHeight)
                            .clipped()
                    case .failure:
                        ZStack {
                            Rectangle().fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                            Image(systemName: "airplane").font(.system(size: 60)).foregroundStyle(.white.opacity(0.5))
                        }
                        .frame(width: width, height: photoHeight)
                    default:
                        Rectangle().fill(.ultraThinMaterial)
                            .frame(width: width, height: photoHeight)
                            .overlay(ProgressView().tint(.white))
                    }
                }

                // soft gradient into the info panel
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .frame(height: photoHeight)
                    .allowsHitTesting(false)
            }
            .frame(width: width, height: photoHeight)
            .clipped()

            // Info panel
            VStack(alignment: .leading, spacing: 10) {
                (Text(card.reg).font(.system(size: 34, weight: .heavy, design: .rounded))
                 + Text("  \(card.airline)").font(.system(size: 20, weight: .medium)).foregroundColor(.white.opacity(0.9)))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)

                HStack(spacing: 8) {
                    if !card.aircraft.isEmpty { GlassChip(text: card.aircraft, icon: "airplane") }
                    if !card.serial.isEmpty { GlassChip(text: "S/N \(card.serial)", icon: "number") }
                }
                if !card.location.isEmpty {
                    Label(card.location, systemImage: "mappin.and.ellipse")
                        .font(.footnote).foregroundStyle(.white.opacity(0.75))
                }
                if !card.photographer.isEmpty {
                    Text("📷 \(card.photographer) · via JetPhotos")
                        .font(.caption2).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(18)
            .frame(width: width, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(
                LinearGradient(colors: [.black.opacity(0.75), .black.opacity(0.95)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(width: width, height: height)
        .background(Color(hue: 0.65, saturation: 0.4, brightness: 0.12))
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
