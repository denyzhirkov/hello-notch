import SwiftUI

struct NotchView: View {
    let message: String
    let height: CGFloat

    var body: some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: Config.cornerRadius,
                bottomTrailingRadius: Config.cornerRadius,
                topTrailingRadius: 0
            )
            .fill(.black)

            if height >= Config.expandedHeight * 0.6 {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
        .frame(width: Config.panelWidth, height: height)
    }
}
