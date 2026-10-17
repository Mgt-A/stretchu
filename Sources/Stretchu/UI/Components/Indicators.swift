import SwiftUI

/// Two segments "step 1 of 2 / 2 of 2" at the top of the break panels.
struct StepsIndicator: View {
    /// 1 or 2.
    let step: Int
    var width: CGFloat = 14
    var inactive: Double = 0.25

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...2, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index == step ? Color.accentColor : Color.white.opacity(inactive))
                    .frame(width: width, height: 4)
            }
        }
    }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 12
    var opacity = 0.07

    func body(content: Content) -> some View {
        content.background(RoundedRectangle(cornerRadius: radius).fill(Color.white.opacity(opacity)))
    }
}

extension View {
    func card(radius: CGFloat = 12, opacity: Double = 0.07) -> some View {
        modifier(CardBackground(radius: radius, opacity: opacity))
    }
}
