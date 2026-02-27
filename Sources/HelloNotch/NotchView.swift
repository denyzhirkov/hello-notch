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
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 3)

                // Green highlight — radial glow from bottom-left corner
                if hoverZone == .left {
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
                }

                // Red highlight — radial glow from bottom-right corner
                if hoverZone == .right {
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
                }

                // Text label
                VStack {
                    Spacer()
                    Text(message)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(textOpacity))
                        .padding(.bottom, 4)
                }
                .id(pulseID)
                .onAppear {
                    textOpacity = 1.0
                    withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                        textOpacity = 0.25
                    }
                }

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
