# DI Layer

## `Sources/DI/InfrastructureContainer.swift` (modified)

`imageDataSource` の型を `ImageDataSource`（Photos）から `FileSystemImageDataSource` に差し替える。プロトコル型で持っていた箇所を具体型に変更し、ViewModel からディレクトリ変更ができるようにする。

```swift
final class InfrastructureContainer {
    let modelContainer: ModelContainer
    let imageDataSource: FileSystemImageDataSource  // ← 具体型で保持
    // ... 他は変更なし ...

    init() throws {
        // ...
        imageDataSource = FileSystemImageDataSource()  // デフォルト: ~/Desktop
        // ...
    }
}
```

## `Sources/DI/PresentationContainer.swift` (modified)

`makeLibraryPickerViewModel()` の引数に `imageDataSource: FileSystemImageDataSource` を渡す。

```swift
@MainActor
func makeLibraryPickerViewModel() -> LibraryPickerViewModel {
    LibraryPickerViewModel(
        imageDataSource: infrastructure.imageDataSource,  // ← 追加
        fetchLibrary: useCases.fetchLibrary,
        loadThumbnail: useCases.loadThumbnail
    )
}
```
