import SwiftUI

enum HoverZone {
    case none, left, right
}

struct NotchView: View {
    let message: String
    let pulseID: UUID
    var hasHardwareNotch: Bool = true
    var onLeft: (() -> Void)?
    var onRight: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?

    @State private var hoverZone: HoverZone = .none
    @State private var textOpacity: Double = 1.0
    @State private var shimmerOffset: CGFloat = -1.0
    @State private var leftFlowProgress: CGFloat = 0
    @State private var rightFlowProgress: CGFloat = 0

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
            let earInset = Config.outerCornerRadius
            ZStack {
                // Soft edge
                notchShape
                    .fill(.black.opacity(Config.softEdgeOpacity))
                    .padding(.horizontal, -Config.softEdgeExtent)

                // Main solid black
                notchShape
                    .fill(.black)

                // Green — soft ambient glow from bottom-left
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
                    .opacity(leftFlowProgress)

                // Green — glowing rim on the bottom-left edge
                notchShape
                    .stroke(
                        RadialGradient(
                            colors: [
                                Color(hex: Config.hoverGreenColor).opacity(0.9),
                                Color(hex: Config.hoverGreenColor).opacity(0)
                            ],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 28
                        ),
                        lineWidth: 1.5
                    )
                    .blendMode(.screen)
                    .opacity(leftFlowProgress)

                // Red — soft ambient glow from bottom-right
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
                    .opacity(rightFlowProgress)

                // Red — glowing rim on the bottom-right edge
                notchShape
                    .stroke(
                        RadialGradient(
                            colors: [
                                Color(hex: Config.hoverRedColor).opacity(0.9),
                                Color(hex: Config.hoverRedColor).opacity(0)
                            ],
                            center: .bottomTrailing,
                            startRadius: 0,
                            endRadius: 28
                        ),
                        lineWidth: 1.5
                    )
                    .blendMode(.screen)
                    .opacity(rightFlowProgress)

                // Shimmer + text — share single .id(pulseID)
                Group {
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

                    // Text morphs into button label while flowing to hovered side
                    VStack {
                        Spacer()
                        ZStack {
                            let flow = rightFlowProgress - leftFlowProgress
                            let flowOffset = flow * (geo.size.width / 2 - 30)

                            // Message — fades out and drifts with the flow
                            Text(message)
                                .foregroundStyle(.white)
                                .opacity((1.0 - max(leftFlowProgress, rightFlowProgress)) * textOpacity)
                                .offset(x: flowOffset)

                            // "Done" — fades in, same position as message → illusion of morphing
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                                Text("Done").font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(Color(hex: Config.hoverGreenColor))
                            .opacity(leftFlowProgress * 0.9)
                            .offset(x: flowOffset)

                            // "Later" — fades in, same position as message
                            HStack(spacing: 3) {
                                Text("Later").font(.system(size: 9, weight: .semibold))
                                Image(systemName: "clock").font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(Color(hex: Config.hoverRedColor))
                            .opacity(rightFlowProgress * 0.9)
                            .offset(x: flowOffset)
                        }
                        .font(.system(size: 10, weight: .regular))
                        .padding(.bottom, Config.labelsBottomInset - 7)
                    }
                }
                .id(pulseID)
                .onAppear {
                    shimmerOffset = -0.6
                    withAnimation(.easeInOut(duration: 0.9).delay(0.35)) {
                        shimmerOffset = 0.6
                    }
                    textOpacity = 1.0
                    withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                        textOpacity = 0.4
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
            .clipShape(notchShape)
            .animation(.easeOut(duration: 0.2), value: hoverZone)
            .onChange(of: hoverZone) { _, zone in
                withAnimation(.easeInOut(duration: 0.405)) {
                    switch zone {
                    case .left:  leftFlowProgress = 1; rightFlowProgress = 0
                    case .right: leftFlowProgress = 0; rightFlowProgress = 1
                    case .none:  leftFlowProgress = 0; rightFlowProgress = 0
                    }
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let bodyWidth = geo.size.width - 2 * earInset
                    let newZone: HoverZone = location.x < bodyWidth / 2 ? .left : .right
                    if hoverZone == .none { onHoverChanged?(true) }
                    hoverZone = newZone
                case .ended:
                    hoverZone = .none
                    onHoverChanged?(false)
                }
            }
            .padding(.horizontal, earInset)
            .overlay(alignment: .top) {
                let r = Config.outerCornerRadius
                HStack(spacing: 0) {
                    InvertedCorner(radius: r, isLeading: false)
                        .fill(.black)
                        .frame(width: r, height: r)
                    Spacer()
                    InvertedCorner(radius: r, isLeading: true)
                        .fill(.black)
                        .frame(width: r, height: r)
                }
            }
        }
    }
}

// MARK: - Inverted corner shape (concave ear for virtual notch)

struct InvertedCorner: Shape {
    var radius: CGFloat
    var isLeading: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if isLeading {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX, y: rect.maxY),
                        radius: radius,
                        startAngle: .degrees(270),
                        endAngle: .degrees(180),
                        clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.minX, y: rect.maxY),
                        radius: radius,
                        startAngle: .degrees(270),
                        endAngle: .degrees(360),
                        clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
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
