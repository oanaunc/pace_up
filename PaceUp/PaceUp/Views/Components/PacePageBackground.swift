import SwiftUI

struct PacePageBackground: View {
    let image: String
    var imageHeight: CGFloat = 440
    var opacity: Double = 0.36

    var body: some View {
        ZStack(alignment: .top) {
            Color.paceInk
            Image(image).resizable().scaledToFill().frame(height: imageHeight).clipped().opacity(opacity)
            LinearGradient(
                stops: [.init(color: .paceInk.opacity(0.12), location: 0), .init(color: .paceInk.opacity(0.76), location: 0.58), .init(color: .paceInk, location: 1)],
                startPoint: .top, endPoint: .bottom
            ).frame(height: imageHeight + 90)
        }.ignoresSafeArea()
    }
}
