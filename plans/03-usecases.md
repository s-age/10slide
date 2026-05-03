# 03 — UseCases

## 方針

- UseCase は 1 クラス 1 操作。`execute()` メソッドのみ。
- Repository プロトコルに依存し、Infrastructure を直接触らない。
- `Sendable` 準拠。

---

## UseCase 一覧

### CreateSlideshowUseCase

ライブラリから選択した写真で新規スライドショーを作成する。

```swift
// Sources/UseCases/CreateSlideshowUseCase.swift
import Foundation

final class CreateSlideshowUseCase: Sendable {
    private let slideshowRepository: any SlideshowRepositoryProtocol
    private let configRepository: any ConfigRepositoryProtocol

    init(
        slideshowRepository: any SlideshowRepositoryProtocol,
        configRepository: any ConfigRepositoryProtocol
    ) {
        self.slideshowRepository = slideshowRepository
        self.configRepository = configRepository
    }

    /// localIdentifiers: Photos ライブラリから選択された画像の identifier 配列
    /// name: スライドショー名
    func execute(name: String, localIdentifiers: [String]) async throws -> Slideshow {
        let config = try await configRepository.load()
        let slides = localIdentifiers.enumerated().map { index, id in
            Slide(
                id: UUID(),
                localIdentifier: id,
                order: index,
                duration: config.defaultDuration,
                title: nil
            )
        }
        let slideshow = Slideshow(
            id: UUID(),
            name: name,
            slides: slides,
            config: config,
            createdAt: Date()
        )
        try await slideshowRepository.save(slideshow)
        return slideshow
    }
}
```

### FetchSlideshowUseCase

ID 指定でスライドショーを取得する。

```swift
// Sources/UseCases/FetchSlideshowUseCase.swift
import Foundation

final class FetchSlideshowUseCase: Sendable {
    private let slideshowRepository: any SlideshowRepositoryProtocol

    init(slideshowRepository: any SlideshowRepositoryProtocol) {
        self.slideshowRepository = slideshowRepository
    }

    func execute(id: UUID) async throws -> Slideshow? {
        try await slideshowRepository.fetch(id: id)
    }
}
```

### FetchLibraryUseCase

Photos ライブラリから利用可能な画像 identifier 一覧を取得する。

```swift
// Sources/UseCases/FetchLibraryUseCase.swift
import Foundation

final class FetchLibraryUseCase: Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute() async throws -> [String] {
        try await imageRepository.fetchAllIdentifiers()
    }
}
```

### LoadSlideImageUseCase

スライドの画像データを読み込む。

```swift
// Sources/UseCases/LoadSlideImageUseCase.swift
import Foundation

final class LoadSlideImageUseCase: Sendable {
    private let imageRepository: any ImageRepositoryProtocol

    init(imageRepository: any ImageRepositoryProtocol) {
        self.imageRepository = imageRepository
    }

    func execute(localIdentifier: String) async throws -> Data {
        try await imageRepository.fetchImageData(localIdentifier: localIdentifier)
    }
}
```

### LoadConfigUseCase

YAML から設定を読み込む。

```swift
// Sources/UseCases/LoadConfigUseCase.swift
import Foundation

final class LoadConfigUseCase: Sendable {
    private let configRepository: any ConfigRepositoryProtocol

    init(configRepository: any ConfigRepositoryProtocol) {
        self.configRepository = configRepository
    }

    func execute() async throws -> SlideshowConfig {
        try await configRepository.load()
    }
}
```

### SaveConfigUseCase

設定を YAML に保存する。

```swift
// Sources/UseCases/SaveConfigUseCase.swift
import Foundation

final class SaveConfigUseCase: Sendable {
    private let configRepository: any ConfigRepositoryProtocol

    init(configRepository: any ConfigRepositoryProtocol) {
        self.configRepository = configRepository
    }

    func execute(_ config: SlideshowConfig) async throws {
        try await configRepository.save(config)
    }
}
```

---

## 再生タイマーについて

スライドの自動送りタイマー（秒数カウント・次スライドへの遷移）は **Presentation 層の ViewModel** で管理する。理由:

- タイマーは UI ライフサイクルと密結合（画面遷移で停止・復帰で再開）
- ビジネスルール（ループ判定・トランジション種別の適用）は `SlideshowConfig` の値参照のみで、複雑なドメインロジックではない

---

## DI 配線（UseCaseContainer への追加）

```swift
// Sources/DI/UseCaseContainer.swift
final class UseCaseContainer {
    let createSlideshow: CreateSlideshowUseCase
    let fetchSlideshow: FetchSlideshowUseCase
    let fetchLibrary: FetchLibraryUseCase
    let loadSlideImage: LoadSlideImageUseCase
    let loadConfig: LoadConfigUseCase
    let saveConfig: SaveConfigUseCase

    init(repositories: RepositoryContainer) {
        createSlideshow = CreateSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository,
            configRepository: repositories.configRepository
        )
        fetchSlideshow = FetchSlideshowUseCase(
            slideshowRepository: repositories.slideshowRepository
        )
        fetchLibrary = FetchLibraryUseCase(
            imageRepository: repositories.imageRepository
        )
        loadSlideImage = LoadSlideImageUseCase(
            imageRepository: repositories.imageRepository
        )
        loadConfig = LoadConfigUseCase(
            configRepository: repositories.configRepository
        )
        saveConfig = SaveConfigUseCase(
            configRepository: repositories.configRepository
        )
    }
}
```

---

## ファイル構成

```
Sources/UseCases/
├── CreateSlideshowUseCase.swift
├── FetchSlideshowUseCase.swift
├── FetchLibraryUseCase.swift
├── LoadSlideImageUseCase.swift
├── LoadConfigUseCase.swift
└── SaveConfigUseCase.swift
```
