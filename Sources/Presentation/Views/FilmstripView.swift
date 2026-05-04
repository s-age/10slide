import SwiftUI

struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let duration: Double
    let transition: TransitionType
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            infoBar
            thumbnailStrip
        }
        .frame(height: 100)
        .background(.ultraThinMaterial)
    }

    private var infoBar: some View {
        HStack(spacing: 16) {
            Label(durationLabel, systemImage: "clock")
            Label(transition.rawValue.capitalized, systemImage: "photo.on.rectangle.angled")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 6) {
                ForEach(slides.indices, id: \.self) { index in
                    thumbnailCell(index: index)
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var durationLabel: String {
        duration > 0 ? "\(Int(duration)) sec" : "Manual"
    }

    @ViewBuilder
    private func thumbnailCell(index: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.gray.opacity(0.4))
            .frame(width: 60, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(
                        index == currentIndex ? Color.white : Color.clear,
                        lineWidth: 2
                    )
            )
            .onTapGesture {
                onSelect(index)
            }
    }
}
