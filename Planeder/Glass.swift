import SwiftUI

// MARK: - Glass helpers: true Liquid Glass on iOS 26+, ultraThinMaterial fallback below

struct GlassCapsule<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 26.0, *) {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }
}

struct GlassCircle: View {
    var tint: Color
    var icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 68, height: 68)
        }
        .ifAvailableGlass()
        .buttonStyle(.plain)
    }
}

extension View {
    @ViewBuilder
    func ifAvailableGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: Circle())
        } else {
            self.background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
        }
    }
}
