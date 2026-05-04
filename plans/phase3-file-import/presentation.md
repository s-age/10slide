# Presentation Layer

## `Sources/Presentation/ViewModels/LibraryPickerViewModel.swift` (modified)

`currentDirectoryName` 表示用プロパティと `selectDirectory()` / `addDroppedFiles(_:)` を追加する。`FileSystemImageDataSource` を直接保持する（プロトコル経由ではなく）。

```swift
@Observable
@MainActor
final class LibraryPickerViewModel {
    // 既存プロパティは変更なし
    private(set) var currentDirectoryName: String = "Desktop"

    private let imageDataSource: FileSystemImageDataSource  // ← 型を具体型に変更
    private let fetchLibraryUseCase: any FetchLibraryUseCaseProtocol
    private let loadThumbnailUseCase: any LoadThumbnailUseCaseProtocol

    // selectDirectory: NSOpenPanel でディレクトリ選択
    func selectDirectory() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard await panel.beginSheetModal(for: NSApp.mainWindow!) == .OK,
              let url = panel.url else { return }
        imageDataSource.setDirectory(url)
        currentDirectoryName = url.lastPathComponent
        await loadLibrary()
    }

    // addDroppedFiles: D&D で受け取ったファイルパスを identifiers に追加
    func addDroppedFiles(_ urls: [URL]) {
        let paths = urls
            .filter { FileSystemImageDataSource.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.path)
        let existing = Set(identifiers)
        let new = paths.filter { !existing.contains($0) }
        identifiers.append(contentsOf: new)
    }
}
```

## `Sources/Presentation/Views/LibraryPickerView.swift` (modified)

ヘッダにディレクトリ名とフォルダ選択ボタンを追加。グリッドに `.dropDestination` を追加。

```swift
// ヘッダバー（libraryStatusBanner の上に追加）
private var directoryBar: some View {
    HStack {
        Label(libraryViewModel.currentDirectoryName, systemImage: "folder")
            .font(.subheadline)
        Spacer()
        Button("Select Folder…") {
            Task { await libraryViewModel.selectDirectory() }
        }
    }
    .padding(.horizontal)
    .padding(.vertical, 6)
    .background(.bar)
}

// グリッドに D&D を追加
LazyVGrid(columns: columns, spacing: 8) { ... }
.dropDestination(for: URL.self) { urls, _ in
    libraryViewModel.addDroppedFiles(urls)
    return !urls.isEmpty
}
```

### 注意点

- `NSOpenPanel.beginSheetModal` は macOS 14 以降で `async` バリアントが利用可能。それ以前は `begin(completionHandler:)` + `withCheckedContinuation` で対応。ターゲットが macOS 26 であるため問題なし。
- D&D の `dropDestination(for: URL.self)` は macOS 13+ で利用可能。
- `FileSystemImageDataSource.supportedExtensions` は `internal` にして ViewModel からもアクセスできるようにする（または `addDroppedFiles` 内でフィルタリングをデータソース側に委譲する）。
- サンドボックス: `NSOpenPanel` で選択したディレクトリはアクセス権が自動付与される。D&D の場合も `NSItemProvider` / `URL` 経由で権限が付与されるが、スコープ付きブックマークで永続化が必要な場合は Phase 4 で対応する。
