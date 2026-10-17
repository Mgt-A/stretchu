import SwiftUI

/// 4 pt, radius 2, 14 % white track, accent fill.
struct ProgressBar: View {
    let value: Double
    var color: Color = .accentColor

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.14))
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: geo.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: 4)
    }
}
