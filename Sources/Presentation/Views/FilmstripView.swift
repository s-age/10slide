import SwiftUI

struct FilmstripView: View {
    let slides: [SlideResponse]
    let currentIndex: Int
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let thumbnailViewModel: ThumbnailViewModel
    let onSelect: (Int) -> Void
    let onDurationChange: (SlideDurationResponse) -> Void
    let onTransitionChange: (TransitionTypeResponse) -> Void
    let isPlaying: Bool
    let isShuffled: Bool
    let onPrevious: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onToggleShuffle: () -> Void

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
                ForEach(SlideDurationResponse.allCases, id: \.self) { d in
                    Text(d.displayLabel).tag(d)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            Spacer()

            HStack(spacing: 16) {
                Button(action: onPrevious) {
                    Image(systemName: "backward.fill")
                }
                Button(action: onPlayPause) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                Button(action: onNext) {
                    Image(systemName: "forward.fill")
                }
                Button(action: onToggleShuffle) {
                    Image(systemName: "shuffle")
                        .foregroundStyle(isShuffled ? Color.accentColor : .primary)
                }
            }
            .buttonStyle(.plain)
            .font(.callout)
            .foregroundStyle(.primary)

            Spacer()

            Picker("Transition", selection: Binding(get: { transition }, set: { onTransitionChange($0) })) {
                ForEach(TransitionTypeResponse.allCases, id: \.self) { t in
                    Text(t.rawValue.capitalized).tag(t)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
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
        let id = slides[index].localIdentifier
        ZStack {
            Color.gray.opacity(0.15)
            if let nsImage = thumbnailViewModel.images[id] {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    index == currentIndex ? Color.white : Color.clear,
                    lineWidth: 2
                )
        )
        .task(id: id) {
            await thumbnailViewModel.load(identifier: id)
        }
        .onTapGesture {
            onSelect(index)
        }
    }
}
