import SwiftUI

struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel

    init(viewModel: SlideshowPlayerViewModel) {
        self._viewModel = State(initialValue: viewModel)
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
                    onSelect: { index in
                        Task { await viewModel.jumpTo(index: index) }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.currentIndex)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showFilmstrip)
        .onTapGesture {
            viewModel.userDidInteract()
        }
        .task {
            await viewModel.loadCurrentImage()
            viewModel.play()
        }
    }

    @ViewBuilder
    private var slideImage: some View {
        if let data = viewModel.currentImageData,
           let nsImage = NSImage(data: data) {
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
