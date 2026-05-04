# Presentation Layer

## `Sources/Presentation/ViewModels/SlideshowLibraryViewModel.swift` (new)

保存済みライブラリの一覧取得を担う ViewModel。

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SlideshowLibraryViewModel {
    private(set) var slideshows: [Slideshow] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let fetchSlideshowUseCase: any FetchSlideshowUseCaseProtocol

    init(fetchSlideshow: any FetchSlideshowUseCaseProtocol) {
        self.fetchSlideshowUseCase = fetchSlideshow
    }

    func loadLibrary() async {
        isLoading = true
        defer { isLoading = false }
        do {
            slideshows = try await fetchSlideshowUseCase.execute()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## `Sources/Presentation/Views/SlideshowLibraryPanel.swift` (new)

右パネル。保存済みスライドショーをリスト表示し、タップで再生モードに遷移する。

```swift
import SwiftUI

struct SlideshowLibraryPanel: View {
    @State private var viewModel: SlideshowLibraryViewModel
    let onSelect: (Slideshow) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Library")
                .font(.headline)
                .padding(.vertical, 8)

            Divider()

            if viewModel.isLoading {
                ProgressView().padding()
            } else if viewModel.slideshows.isEmpty {
                ContentUnavailableView(
                    "No Slideshows",
                    systemImage: "photo.on.rectangle",
                    description: Text("Create a slideshow to see it here.")
                )
            } else {
                List(viewModel.slideshows) { slideshow in
                    Button {
                        onSelect(slideshow)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(slideshow.name)
                                .fontWeight(.medium)
                            Text("\(slideshow.slides.count) slides · \(slideshow.config.duration.displayLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task { await viewModel.loadLibrary() }
    }
}
```

## `Sources/Presentation/Views/HomeView.swift` (new)

7:3 HSplitView で左ソースパネルと右ライブラリパネルを配置する。

```swift
import SwiftUI

struct HomeView: View {
    @State private var libraryViewModel: LibraryPickerViewModel
    @State private var createViewModel: CreateSlideshowViewModel
    @State private var slideshowLibraryViewModel: SlideshowLibraryViewModel
    let onSlideshowSelected: (Slideshow) -> Void

    var body: some View {
        HSplitView {
            // 左: ソースパネル（70%）
            LibraryPickerView(
                libraryViewModel: libraryViewModel,
                createViewModel: createViewModel,
                onSlideshowCreated: { slideshow in
                    // ライブラリを再読み込みして右パネルに反映
                    Task { await slideshowLibraryViewModel.loadLibrary() }
                    onSlideshowSelected(slideshow)
                }
            )
            .frame(minWidth: 400)

            // 右: ライブラリパネル（30%）
            SlideshowLibraryPanel(
                viewModel: slideshowLibraryViewModel,
                onSelect: onSlideshowSelected
            )
            .frame(minWidth: 200, idealWidth: 260)
        }
    }
}
```

## `Sources/Presentation/Views/ContentView.swift` (modified)

`LibraryPickerView` の直接参照を `HomeView` に差し替える。

```swift
var body: some View {
    if let slideshow = selectedSlideshow {
        SlideshowPlayerView(
            viewModel: makeSlideshowPlayerViewModel(slideshow),
            onBack: { selectedSlideshow = nil }
        )
    } else {
        HomeView(
            libraryViewModel: libraryViewModel,
            createViewModel: createViewModel,
            slideshowLibraryViewModel: makeSlideshowLibraryViewModel(),
            onSlideshowSelected: { selectedSlideshow = $0 }
        )
    }
}
```

### 注意点

- `HSplitView` は割合指定ができないため、`frame(minWidth:idealWidth:)` で擬似的に 7:3 を誘導する。SwiftUI が割り振りを調整するため厳密な 7:3 にはならないが実用上は問題ない。
- `SlideshowLibraryPanel` でスライドショーを選択した場合も `onSlideshowSelected` 経由でプレーヤーに遷移するため、`ContentView` の状態管理は変わらない。
- ライブラリ一覧は Create 後に手動で `loadLibrary()` を呼んで更新する。SwiftData のリアルタイム監視（`@Query`）に切り替えると自動更新できるが、ViewModel パターンとの兼ね合いで判断する。
