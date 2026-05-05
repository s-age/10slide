import SwiftUI

struct SlideshowPlayerView: View {
    let viewModel: SlideshowPlayerViewModel
    let thumbnailViewModel: ThumbnailViewModel
    let onBack: () -> Void

    init(viewModel: SlideshowPlayerViewModel, thumbnailViewModel: ThumbnailViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.thumbnailViewModel = thumbnailViewModel
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
                    thumbnailViewModel: thumbnailViewModel,
                    onSelect: { index in Task { await viewModel.jumpTo(index: index) } },
                    onDurationChange: { duration in Task { await viewModel.updateDuration(duration) } },
                    onTransitionChange: { transition in Task { await viewModel.updateTransition(transition) } },
                    isPlaying: viewModel.isPlaying,
                    onPrevious: { Task { await viewModel.previous() } },
                    onPlayPause: {
                        if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
                    },
                    onNext: { Task { await viewModel.userDidNext() } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onHover { hovering in
                    if hovering { viewModel.overlayHoverBegan() } else { viewModel.overlayHoverEnded() }
                }
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
                .onHover { hovering in
                    if hovering { viewModel.overlayHoverBegan() } else { viewModel.overlayHoverEnded() }
                }
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
            Task { await viewModel.userDidNext() }
            return .handled
        }
        .onTapGesture {
            viewModel.userDidInteract()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        if dx < -50 {
                            Task { await viewModel.userDidNext() }
                        } else if dx > 50 {
                            Task { await viewModel.previous() }
                        }
                    } else {
                        viewModel.userDidInteract()
                    }
                }
        )
        .onHover { hovering in
            if hovering { viewModel.userDidInteract() }
        }
        .task {
            await viewModel.loadCurrentImage()
            viewModel.play()
        }
    }

    @ViewBuilder
    private var slideImage: some View {
        if let nsImage = viewModel.currentNSImage {
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
