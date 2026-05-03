# 05 — Infrastructure

## Actor 一覧

| Actor / Class | パス | 責務 |
|---|---|---|
| `ConfigStore` (actor) | `Infrastructure/Config/ConfigStore.swift` | YAML ファイルの読み書き |
| `ImageDataSource` (既存) | `Infrastructure/Image/ImageDataSource.swift` | Photos フレームワークからの画像取得 |
| `SlideDataSource` (既存) | `Infrastructure/SwiftData/SlideDataSource.swift` | SwiftData — Slide の CRUD |
| `SlideshowDataSource` (新規) | `Infrastructure/SwiftData/SlideshowDataSource.swift` | SwiftData — Slideshow の CRUD |

---

## ConfigStore (actor)

YAML ファイルの読み書きを並行安全に行う。

### 依存ライブラリ

- **Yams** (SPM) — YAML パーサー。`Package.swift` / `project.yml` に追加が必要。

### DTO

```swift
// Sources/Infrastructure/Config/DTO/ConfigDTO.swift
import Foundation

struct ConfigDTO: Sendable, Codable {
    var defaultDuration: TimeInterval
    var transition: String    // TransitionType.rawValue
    var loop: Bool
}
```

### 実装シグニチャ

```swift
// Sources/Infrastructure/Config/ConfigStore.swift
import Foundation
import Yams

actor ConfigStore: ConfigDataSourceProtocol {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() async throws -> ConfigDTO {
        // 1. fileURL から Data を読み込み
        // 2. Yams.YAMLDecoder で ConfigDTO にデコード
        // 3. ファイル未存在時はデフォルト値を返す
        ...
    }

    func save(_ dto: ConfigDTO) async throws {
        // 1. Yams.YAMLEncoder で ConfigDTO をエンコード
        // 2. fileURL に書き込み
        ...
    }
}
```

### YAML フォーマット例

```yaml
defaultDuration: 5.0
transition: fade
loop: true
```

### ファイル保存先

```swift
// Application Support/10slide/config.yml
let configDir = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("10slide", isDirectory: true)
let configURL = configDir.appendingPathComponent("config.yml")
```

---

## SlideshowDataSource

SwiftData による Slideshow の CRUD。

### DTO（既存 SlideshowModel の変更）

`SlideshowModel` に config 関連フィールドを追加する。

```swift
// Sources/Infrastructure/SwiftData/DTO/SlideshowModel.swift（変更）
import SwiftData
import Foundation

@Model
final class SlideshowModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var defaultDuration: TimeInterval       // 追加
    var transitionRawValue: String           // 追加
    var loop: Bool                           // 追加
    @Relationship(deleteRule: .cascade, inverse: \SlideModel.slideshow)
    var slides: [SlideModel]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        defaultDuration: TimeInterval = 5.0,
        transitionRawValue: String = "fade",
        loop: Bool = true
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.defaultDuration = defaultDuration
        self.transitionRawValue = transitionRawValue
        self.loop = loop
        self.slides = []
    }
}
```

### 実装シグニチャ

```swift
// Sources/Infrastructure/SwiftData/SlideshowDataSource.swift
import Foundation
import SwiftData

final class SlideshowDataSource: SlideshowDataSourceProtocol {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func fetchAll() async throws -> [SlideshowModel] { ... }
    func fetch(id: UUID) async throws -> SlideshowModel? { ... }
    func save(_ model: SlideshowModel) async throws { ... }
    func delete(id: UUID) async throws { ... }
}
```

---

## ImageDataSource（既存 — 実装追加）

現在はスタブ。Photos フレームワークとの接続を実装する。

```swift
// Sources/Infrastructure/Image/ImageDataSource.swift（変更）
import Foundation
import Photos

final class ImageDataSource: ImageDataSourceProtocol {
    func fetchAllIdentifiers() async throws -> [String] {
        // 1. PHPhotoLibrary.authorizationStatus チェック
        // 2. PHAsset.fetchAssets で全画像取得
        // 3. localIdentifier の配列を返す
        ...
    }

    func fetchImage(localIdentifier: String) async throws -> ImageDTO {
        // 1. PHAsset.fetchAssets(withLocalIdentifiers:)
        // 2. PHImageManager.requestImageDataAndOrientation
        // 3. ImageDTO に変換して返す
        ...
    }
}
```

---

## DI 配線（InfrastructureContainer への変更）

```swift
// Sources/DI/InfrastructureContainer.swift
import SwiftData

final class InfrastructureContainer {
    let modelContainer: ModelContainer
    let imageDataSource: any ImageDataSourceProtocol
    let slideDataSource: any SlideDataSourceProtocol
    let slideshowDataSource: any SlideshowDataSourceProtocol    // 追加
    let configDataSource: any ConfigDataSourceProtocol           // 追加

    init() throws {
        modelContainer = try ModelContainer(for: SlideModel.self, SlideshowModel.self)
        imageDataSource = ImageDataSource()
        slideDataSource = SlideDataSource(container: modelContainer)
        slideshowDataSource = SlideshowDataSource(container: modelContainer)

        let configDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("10slide", isDirectory: true)
        let configURL = configDir.appendingPathComponent("config.yml")
        configDataSource = ConfigStore(fileURL: configURL)
    }
}
```

### RepositoryContainer への変更

```swift
// Sources/DI/RepositoryContainer.swift
final class RepositoryContainer {
    let slideRepository: any SlideRepositoryProtocol
    let slideshowRepository: any SlideshowRepositoryProtocol    // 追加
    let configRepository: any ConfigRepositoryProtocol           // 追加
    let imageRepository: any ImageRepositoryProtocol             // 追加

    init(infrastructure: InfrastructureContainer) {
        slideRepository = SlideRepository(
            slideDataSource: infrastructure.slideDataSource,
            imageDataSource: infrastructure.imageDataSource
        )
        slideshowRepository = SlideshowRepository(
            slideshowDataSource: infrastructure.slideshowDataSource,
            slideDataSource: infrastructure.slideDataSource
        )
        configRepository = ConfigRepository(
            configDataSource: infrastructure.configDataSource
        )
        imageRepository = ImageRepository(
            imageDataSource: infrastructure.imageDataSource
        )
    }
}
```

---

## SPM 依存追加

`project.yml` に Yams パッケージを追加する。

```yaml
packages:
  Yams:
    url: https://github.com/jpsim/Yams.git
    from: "5.0.0"
```

---

## ファイル構成（変更・追加分）

```
Sources/Infrastructure/
├── Config/                          // 新規ディレクトリ
│   ├── ConfigStore.swift            // 新規 (actor)
│   └── DTO/
│       └── ConfigDTO.swift          // 新規
├── Image/
│   ├── ImageDataSource.swift        // 変更（実装追加）
│   └── DTO/
│       └── ImageDTO.swift           // 変更なし
├── Protocols/
│   ├── ConfigDataSourceProtocol.swift     // 新規
│   ├── ImageDataSourceProtocol.swift      // 変更なし
│   ├── SlideDataSourceProtocol.swift      // 変更なし
│   └── SlideshowDataSourceProtocol.swift  // 新規
└── SwiftData/
    ├── SlideDataSource.swift        // 変更なし
    ├── SlideshowDataSource.swift    // 新規
    └── DTO/
        ├── SlideModel.swift         // 変更なし
        └── SlideshowModel.swift     // 変更（config フィールド追加）
```
