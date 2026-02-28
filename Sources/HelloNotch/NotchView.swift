import SwiftUI

enum HoverZone {
    case none, left, right
}

struct NotchView: View {
    let message: String
    let pulseID: UUID
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    @State private var hoverZone: HoverZone = .none
    @State private var textOpacity: Double = 1.0
    @State private var shimmerOffset: CGFloat = -1.0

    private var isHovering: Bool { hoverZone != .none }

    private var notchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: Config.cornerRadius,
            bottomTrailingRadius: Config.cornerRadius,
            topTrailingRadius: 0
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Soft edge
                notchShape
                    .fill(.black.opacity(Config.softEdgeOpacity))
                    .padding(.horizontal, -Config.softEdgeExtent)

                // Main solid black
                notchShape
                    .fill(.black)

                // Green highlight — radial glow from bottom-left
                notchShape
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: Config.hoverGreenColor).opacity(Config.hoverOpacity),
                                Color(hex: Config.hoverGreenColor).opacity(0)
                            ],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: min(geo.size.width, geo.size.height) * 0.9
                        )
                    )
                    .opacity(hoverZone == .left ? 1 : 0)

                // Red highlight — radial glow from bottom-right
                notchShape
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: Config.hoverRedColor).opacity(Config.hoverOpacity),
                                Color(hex: Config.hoverRedColor).opacity(0)
                            ],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: min(geo.size.width, geo.size.height) * 0.9
                        )
                    )
                    .opacity(hoverZone == .right ? 1 : 0)

                // Edge shimmer — light sweep along bottom edge
                VStack {
                    Spacer()
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.5),
                                    .white.opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 2)
                        .offset(x: shimmerOffset * geo.size.width)
                        .padding(.bottom, 1)
                }
                .clipShape(notchShape)
                .id(pulseID)
                .onAppear {
                    shimmerOffset = -0.6
                    withAnimation(.easeInOut(duration: 0.9).delay(0.35)) {
                        shimmerOffset = 0.6
                    }
                }

                // Reminder text — fades on hover
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white)
                        .opacity(isHovering ? 0.1 : textOpacity)
                        .padding(.bottom, 4)
                }
                .id(pulseID)
                .onAppear {
                    textOpacity = 1.0
                    withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                        textOpacity = 0.25
                    }
                }

                // Action labels — appear on hover
                HStack {
                    // Done label (left)
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Done")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(Color(hex: Config.hoverGreenColor))
                    .opacity(isHovering ? (hoverZone == .left ? 0.8 : 0.25) : 0)

                    Spacer()

                    // Later label (right)
                    HStack(spacing: 3) {
                        Text("Later")
                            .font(.system(size: 9, weight: .semibold))
                        Image(systemName: "clock")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Color(hex: Config.hoverRedColor))
                    .opacity(isHovering ? (hoverZone == .right ? 0.8 : 0.25) : 0)
                }
                .padding(.horizontal, 12)
                .padding(.top, 32)

                // Invisible click zones
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onLeft?() }

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onRight?() }
                }
            }
            .animation(.easeOut(duration: 0.2), value: hoverZone)
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let newZone: HoverZone = location.x < geo.size.width / 2 ? .left : .right
                    if hoverZone == .none { onHoverChanged?(true) }
                    hoverZone = newZone
                case .ended:
                    hoverZone = .none
                    onHoverChanged?(false)
                }
            }
        }
    }
}

// MARK: - Color hex init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
