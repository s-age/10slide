# 02 — Repository Protocols

## 層構成

```
Infrastructure/Protocols/   ← DataSource プロトコル（I/O 境界）
Repositories/Protocols/     ← Repository プロトコル（UseCase が依存）
Repositories/Implementations/ ← DTO ↔ Entity 変換の実装
```

## Infrastructure DataSource プロトコル（追加）

### ConfigDataSourceProtocol

YAML ファイルの読み書き。Infrastructure 層の `ConfigStore` actor が実装する。

```swift
// Sources/Infrastructure/Protocols/ConfigDataSourceProtocol.swift
import Foundation

protocol ConfigDataSourceProtocol: Sendable {
    func load() async throws -> ConfigDTO
    func save(_ dto: ConfigDTO) async throws
}
```

### SlideshowDataSourceProtocol

SwiftData による Slideshow の CRUD。

```swift
// Sources/Infrastructure/Protocols/SlideshowDataSourceProtocol.swift
import Foundation

protocol SlideshowDataSourceProtocol: Sendable {
    func fetchAll() async throws -> [SlideshowModel]
    func fetch(id: UUID) async throws -> SlideshowModel?
    func save(_ model: SlideshowModel) async throws
    func delete(id: UUID) async throws
}
```

### 既存プロトコル — 変更なし

- `ImageDataSourceProtocol` — そのまま利用
- `SlideDataSourceProtocol` — そのまま利用

---

## Repository プロトコル（追加）

### ConfigRepositoryProtocol

Config の読み書き。DTO → Entity 変換を担う。

```swift
// Sources/Repositories/Protocols/ConfigRepositoryProtocol.swift
import Foundation

protocol ConfigRepositoryProtocol: Sendable {
    func load() async throws -> SlideshowConfig
    func save(_ config: SlideshowConfig) async throws
}
```

### SlideshowRepositoryProtocol

Slideshow 全体の CRUD。Slide の配列と Config を含む。

```swift
// Sources/Repositories/Protocols/SlideshowRepositoryProtocol.swift
import Foundation

protocol SlideshowRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slideshow]
    func fetch(id: UUID) async throws -> Slideshow?
    func save(_ slideshow: Slideshow) async throws
    func delete(id: UUID) async throws
}
```

### ImageRepositoryProtocol

画像読み込み。DTO → ドメイン向けデータ変換。

```swift
// Sources/Repositories/Protocols/ImageRepositoryProtocol.swift
import Foundation

protocol ImageRepositoryProtocol: Sendable {
    func fetchAllIdentifiers() async throws -> [String]
    func fetchImageData(localIdentifier: String) async throws -> Data
}
```

### 既存プロトコル

- `SlideRepositoryProtocol` — `SlideshowRepositoryProtocol` が Slideshow 単位で Slide を扱うため、単体の Slide CRUD は既存のままで良い。将来的に `SlideshowRepositoryProtocol` に統合する可能性あり。

---

## Repository 実装（追加）

### ConfigRepository

```swift
// Sources/Repositories/Implementations/ConfigRepository.swift
import Foundation

final class ConfigRepository: ConfigRepositoryProtocol {
    private let configDataSource: any ConfigDataSourceProtocol

    init(configDataSource: any ConfigDataSourceProtocol) {
        self.configDataSource = configDataSource
    }

    func load() async throws -> SlideshowConfig { ... }
    func save(_ config: SlideshowConfig) async throws { ... }
}
```

### SlideshowRepository

```swift
// Sources/Repositories/Implementations/SlideshowRepository.swift
import Foundation

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let slideshowDataSource: any SlideshowDataSourceProtocol
    private let slideDataSource: any SlideDataSourceProtocol

    init(
        slideshowDataSource: any SlideshowDataSourceProtocol,
        slideDataSource: any SlideDataSourceProtocol
    ) {
        self.slideshowDataSource = slideshowDataSource
        self.slideDataSource = slideDataSource
    }

    func fetchAll() async throws -> [Slideshow] { ... }
    func fetch(id: UUID) async throws -> Slideshow? { ... }
    func save(_ slideshow: Slideshow) async throws { ... }
    func delete(id: UUID) async throws { ... }
}
```

### ImageRepository

```swift
// Sources/Repositories/Implementations/ImageRepository.swift
import Foundation

final class ImageRepository: ImageRepositoryProtocol {
    private let imageDataSource: any ImageDataSourceProtocol

    init(imageDataSource: any ImageDataSourceProtocol) {
        self.imageDataSource = imageDataSource
    }

    func fetchAllIdentifiers() async throws -> [String] { ... }
    func fetchImageData(localIdentifier: String) async throws -> Data { ... }
}
```

---

## DTO（追加）

### ConfigDTO

YAML ↔ Swift のブリッジ用。Infrastructure 層内で使用。

```swift
// Sources/Infrastructure/Config/DTO/ConfigDTO.swift
import Foundation

struct ConfigDTO: Sendable, Codable {
    var defaultDuration: TimeInterval
    var transition: String
    var loop: Bool
}
```

---

## ファイル構成（追加分）

```
Sources/Infrastructure/Protocols/
├── ConfigDataSourceProtocol.swift       // 新規
└── SlideshowDataSourceProtocol.swift    // 新規

Sources/Infrastructure/Config/DTO/
└── ConfigDTO.swift                      // 新規

Sources/Repositories/Protocols/
├── ConfigRepositoryProtocol.swift       // 新規
├── SlideshowRepositoryProtocol.swift    // 新規
└── ImageRepositoryProtocol.swift        // 新規

Sources/Repositories/Implementations/
├── ConfigRepository.swift               // 新規
├── SlideshowRepository.swift            // 新規
└── ImageRepository.swift                // 新規
```
