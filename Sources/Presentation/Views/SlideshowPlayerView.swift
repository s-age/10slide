import SwiftUI

struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel
    @State private var decodedImage: NSImage?
    let onBack: () -> Void

    init(viewModel: SlideshowPlayerViewModel, onBack: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
                .ignoresSafeArea()

            slideImage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(viewModel.currentIndex)
                .transition(slideTransition)

            if viewModel.showFilmstrip {
                FilmstripView(
                    slides: viewModel.slideshow.slides,
                    currentIndex: viewModel.currentIndex,
                    duration: viewModel.slideshow.config.duration,
                    transition: viewModel.slideshow.config.transition,
                    onSelect: { index in Task { await viewModel.jumpTo(index: index) } },
                    onDurationChange: { viewModel.updateDuration($0) },
                    onTransitionChange: { viewModel.updateTransition($0) },
                    isPlaying: viewModel.isPlaying,
                    onPrevious: { Task { await viewModel.previous() } },
                    onPlayPause: {
                        if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
                    },
                    onNext: { Task { await viewModel.next() } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.showFilmstrip {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(16)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentIndex)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showFilmstrip)
        .focusable()
        .onKeyPress(.space) {
            if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
            return .handled
        }
        .onKeyPress(.leftArrow) {
            Task { await viewModel.previous() }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            Task { await viewModel.next() }
            return .handled
        }
        .onTapGesture {
            viewModel.userDidInteract()
        }
        .task {
            await viewModel.loadCurrentImage()
            viewModel.play()
        }
        .task(id: viewModel.currentImage) {
            guard let data = viewModel.currentImage else { decodedImage = nil; return }
            decodedImage = await Task.detached(priority: .userInitiated) {
                NSImage(data: data)
            }.value
        }
    }

    @ViewBuilder
    private var slideImage: some View {
        if let nsImage = decodedImage {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
        } else {
            Color.black
        }
    }

    private var slideTransition: AnyTransition {
        switch viewModel.slideshow.config.transition {
        case .none:
            return .identity
        case .fade, .dissolve:
            return .opacity
        case .slide:
            return .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        }
    }
}
