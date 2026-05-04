# Goal

画像の取り込み元を Photos ライブラリからファイルシステムに切り替える。

1. デフォルトはデスクトップ（`~/Desktop`）
2. ディレクトリ選択パネル（`NSOpenPanel`）でユーザーが変更可能
3. ドラッグ＆ドロップで画像ファイルを取り込み可能

# Key Design Decisions

- `ImageDataSourceProtocol` のインターフェースは変更しない。新しい `FileSystemImageDataSource` が同プロトコルを実装することで上位層への影響を最小化する。
- `localIdentifier` は Photos 固有の概念だが、**ファイルの絶対パス文字列**をそのまま渡す形で流用する。型名は変えずに用途を転用する（将来的な identifier 型の抽象化は Phase 4 以降）。
- `fetchAllIdentifiers()` はディレクトリ内の対象拡張子（jpg / jpeg / png / heic / webp）のファイルパスを返す。
- D&D はファイルパスを `identifiers` に直接追加する形で実装し、ディレクトリ内走査とは独立させる。
- `NSOpenPanel` はメインスレッドから呼ぶ必要があるため、ViewModel の `selectDirectory()` は `@MainActor` で実装する。

# Affected Layers

| Layer | 変更 |
|---|---|
| Infrastructure | `FileSystemImageDataSource` 新規作成、`ImageDataSource`（Photos）は残す |
| DI | `InfrastructureContainer` で差し替え |
| UseCases | `FetchLibraryUseCase` にディレクトリ URL パラメータを追加 |
| Presentation | `LibraryPickerViewModel` にディレクトリ管理を追加、View に UI 追加 |
| Domain | 変更なし |
| Repositories | 変更なし |
