import SwiftUI

struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(slides.indices, id: \.self) { index in
                    thumbnailCell(index: index)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 80)
        .background(.ultraThinMaterial)
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
