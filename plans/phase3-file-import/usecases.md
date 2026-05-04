# UseCases Layer

## `Sources/UseCases/FetchLibraryUseCase.swift` (modified)

`execute()` にデフォルト引数としてディレクトリ URL を受け取れるようにしても良いが、現状の `FileSystemImageDataSource` はデータソース側でディレクトリを保持するため UseCase の変更は最小限でよい。

変更なし。`FileSystemImageDataSource.setDirectory(_:)` は ViewModel から DI コンテナ経由で直接呼ぶ。

## `Sources/UseCases/Protocols/FetchLibraryUseCaseProtocol.swift` (変更なし)

プロトコルは変更しない。

## 新規 UseCase は不要

ディレクトリ選択は UI イベント（NSOpenPanel の結果）を Infrastructure 層に直接反映するため、UseCase を経由するほどのビジネスロジックがない。`LibraryPickerViewModel` が `FileSystemImageDataSource` を直接参照して `setDirectory(_:)` を呼ぶ方が素直。
