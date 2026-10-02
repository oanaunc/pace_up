import SwiftUI

struct EditorialImageCard: View {
    let image: String
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            FillImage(image: Image(image))
                .frame(maxWidth: .infinity)
                .frame(height: 178)
                .clipped()

            LinearGradient(
                colors: [.clear, Color.paceInk.opacity(0.35), Color.paceInk.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow.uppercased())
                    .font(.caption2.bold())
                    .tracking(1.5)
                    .foregroundStyle(.paceLime)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.paceTextSecondary)
                    .lineLimit(2)
            }
            .padding(PaceSpacing.l)
        }
        .frame(height: 178)
        .clipShape(.rect(cornerRadius: PaceRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: PaceRadius.card)
                .stroke(Color.white.opacity(0.1))
        }
        .accessibilityElement(children: .combine)
    }
}

/// An image that fills exactly the space it is offered and no more.
///
/// `Image.resizable().scaledToFill()` reports the *filled* size back to its
/// parent, so a landscape photo in a full-width card asks for more width than
/// the screen has and pushes the card — and its text — off the edge.
/// `Color.clear` takes the proposed size exactly; the image fills it as an
/// overlay and is clipped to it.
struct FillImage: View {
    var image: Image

    var body: some View {
        Color.clear
            .overlay { image.resizable().scaledToFill() }
            .clipped()
    }
}
