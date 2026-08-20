import SwiftUI

// Shared visual language for the app. Both the dashboard and the
// Connections screen pull from here so they read as one app rather than a
// custom screen plus a stock iOS Settings list.

/// Solid accent fill with white text. The explicit `foregroundStyle`
/// matters: `.borderedProminent` keeps a white label regardless of tint, so
/// tinting it white silently produces an invisible white-on-white button.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.dashboardAccent, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension View {
    /// The frosted card surface used for every panel in the app.
    ///
    /// Dark-mode `.ultraThinMaterial` is heavier than its name suggests —
    /// at full strength it reads as a solid gray card. Knocking its opacity
    /// down lets the backdrop come through while keeping the blur, which is
    /// what actually makes it look like glass.
    func glassSurface(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.55)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    /// Pill-shaped variant of `glassSurface`, for controls that float above
    /// the content rather than sitting in the layout. Lighter still, since
    /// it sits over the cards themselves.
    func glassCapsule() -> some View {
        self
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    // Slightly stronger than a card: this floats over text,
                    // so it needs enough body to stay readable without
                    // going back to a solid disc.
                    .opacity(0.68)
            )
            .overlay(
                Capsule().stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }
}

/// Same three-glow palette as the web dashboard's CSS radial gradients,
/// slowly drifting so the app doesn't feel like a static screenshot.
/// Deliberately subtle — it's a backdrop, not the subject.
struct AmbientGlow: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.dashboardPage
            RadialGradient(colors: [Color(hex: "3987E5").opacity(0.38), .clear], center: UnitPoint(x: drift ? 0.18 : 0.06, y: drift ? -0.02 : -0.14), startRadius: 1, endRadius: 460)
            RadialGradient(colors: [Color(hex: "D55181").opacity(0.30), .clear], center: UnitPoint(x: drift ? 0.84 : 0.96, y: drift ? 0.14 : 0.02), startRadius: 1, endRadius: 430)
            RadialGradient(colors: [Color(hex: "199E70").opacity(0.24), .clear], center: UnitPoint(x: drift ? 0.38 : 0.62, y: drift ? 0.94 : 1.06), startRadius: 1, endRadius: 500)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

/// Section wrapper matching the dashboard's cards: small uppercase label
/// above a glass panel.
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(Color.dashboardTextMuted)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                content
            }
            .glassSurface()

            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.dashboardTextMuted)
                    .lineSpacing(2)
                    .padding(.horizontal, 2)
            }
        }
    }
}

/// Hairline divider between rows inside a glass panel.
struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.dashboardGridline)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}
