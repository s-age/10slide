import SwiftUI

struct FilmstripView: View {
    let slides: [Slide]
    let currentIndex: Int
    let duration: SlideDuration
    let transition: TransitionType
    let onSelect: (Int) -> Void
    let onDurationChange: (SlideDuration) -> Void
    let onTransitionChange: (TransitionType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            infoBar
            thumbnailStrip
        }
        .frame(height: 100)
        .background(.ultraThinMaterial)
    }

    private var infoBar: some View {
        HStack(spacing: 8) {
            Picker("Duration", selection: Binding(get: { duration }, set: { onDurationChange($0) })) {
                ForEach(SlideDuration.allCases, id: \.self) { d in
                    Text(d.displayLabel).tag(d)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Picker("Transition", selection: Binding(get: { transition }, set: { onTransitionChange($0) })) {
                ForEach(TransitionType.allCases, id: \.self) { t in
                    Text(t.rawValue.capitalized).tag(t)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Spacer()
        }
        .font(.caption)
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
