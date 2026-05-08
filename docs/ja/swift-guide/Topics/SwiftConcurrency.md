# Swift Concurrency 実践ガイド — Swift 6 の並行処理で失敗しないために

**種別:** 発展編（トピック横断ガイド）

Swift 6 では **Strict Concurrency**（厳格な並行性チェック）がデフォルトで有効になりました。コンパイラが「データ競合（data race）が起きうるコード」をビルドエラーとして弾くため、従来の書き方では通らないケースが多発します。

このガイドでは、10slide のコードベースで実際に遭遇した問題と、その解決パターンをまとめます。

---

## 概要

Swift Concurrency の中心概念は3つです。

| 概念 | 一言説明 |
|------|---------|
| **Sendable** | 「この型はスレッド間で安全に渡せます」というコンパイラへの約束 |
| **Actor** | 内部状態を一度に1つのタスクだけがアクセスできるよう保護する仕組み |
| **async/await** | 非同期処理をコールバックなしで直線的に書ける構文 |

Swift 6 ではこれらを **正しく組み合わせないとビルドが通りません**。以下、パターンごとに見ていきましょう。

---

## 1. Sendable とは何か、なぜ Swift 6 で必須なのか

### これは何か？

`Sendable` は「この値はスレッド（アクター）を越えて安全に渡せる」ことをコンパイラに伝えるプロトコルです。Swift 6 では、アクター境界を越える値は原則 `Sendable` でなければなりません。

### なぜ重要なのか？

並行プログラムで最も危険なバグは **データ競合** です。2つのスレッドが同じデータを同時に読み書きすると、クラッシュや不正なデータが生まれます。`Sendable` はコンパイラが「この型は安全だ」と確認するための仕組みです。

### 型ごとの Sendable 対応

| 型の種類 | Sendable になれるか？ | 条件 |
|---------|---------------------|------|
| `struct` | 自動で準拠 | 全プロパティが `Sendable` であれば |
| `enum` | 自動で準拠 | 全 associated value が `Sendable` であれば |
| `final class` | 手動で準拠 | 全プロパティが `let` かつ `Sendable` であれば |
| 非 final `class` | 不可 | サブクラスで可変状態を追加できるため |
| `actor` | 常に `Sendable` | アクター自体が保護機構を持つため |

### 正しい例

```swift
// ✅ struct — automatically Sendable if all properties are Sendable
// (from Sources/Infrastructure/Image/DTO/ImageDTO.swift)
struct ImageDTO: Sendable {
    let localIdentifier: String
    let data: Data
    let creationDate: Date?
}
```

```swift
// ✅ final class — Sendable with let-only properties
final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol  // typealias embeds `any`
    private let loadSlideImage: LoadSlideImageUseCaseProtocol
}
```

### 間違った例

```swift
// ❌ Non-final class cannot be Sendable
class UseCaseRequest: Sendable {  // Compile error
    func validate() throws { }
}
```

```swift
// ❌ final class with var cannot be Sendable
final class Cache: Sendable {
    var items: [String: Data] = [:]  // Compile error: var is incompatible with Sendable
}
```

```swift
// ❌ Silencing warnings with @unchecked Sendable (prohibited in this project)
final class Cache: @unchecked Sendable {
    var items: [String: Data] = [:]  // Compiles, but hides data race risks
}
```

### 10slide での実例

UseCase の Request 型は当初 `class` 継承で設計されていましたが、Swift 6 では `Sendable` にできないためコンパイルエラーになりました。`protocol UseCaseRequest: Sendable` + `struct` に変更して解決しています。

```swift
// ✅ protocol + struct pattern (current design)
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let localIdentifiers: [String]
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
```

---

## 2. @MainActor と非同期メソッドの注意点 — インデックススナップショットパターン

### これは何か？

`@MainActor` は「この型やメソッドはメインスレッドでのみ実行される」というマークです。SwiftUI の ViewModel は通常 `@MainActor` で隔離します。

### 問題：非同期メソッドで stale write（古いデータの上書き）が起きる

`@MainActor` なメソッドでも、`await` を書いた時点で **メインスレッドは一旦解放** されます。その間に別の操作（次のスライドへの移動など）が割り込むと、古い結果が新しい結果を上書きしてしまいます。

SwiftUI の `.task(id:)` 修飾子は `id` が変わると自動で前のタスクをキャンセルしますが、ViewModel のメソッドに移した場合はこの自動キャンセルが失われます。

### 間違った例

```swift
// ❌ If the index changes during await, an old image overwrites the current one
@MainActor
func loadCurrentImage() async {
    guard let slide = currentSlide else { return }
    do {
        let request = LoadSlideImageRequest(localIdentifier: slide.localIdentifier)
        let data = try await loadSlideImage.execute(request)
        // ⚠️ currentIndex may have changed by this point
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        // ⚠️ currentIndex may have changed here too
        currentNSImage = image  // Overwrites with a stale image!
    } catch {
        currentNSImage = nil
    }
}
```

### 正しい例：インデックススナップショットパターン

```swift
// ✅ Snapshot the index before await, then verify after every await
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex  // ① Take a snapshot

    do {
        let request = LoadSlideImageRequest(localIdentifier: slide.localIdentifier)
        let data = try await loadSlideImage.execute(request)
        guard currentIndex == expectedIndex else { return }  // ② Guard after fetch

        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        guard currentIndex == expectedIndex else { return }  // ③ Guard after decode too

        currentNSImage = image
    } catch {
        currentNSImage = nil
    }
}
```

### ルール

- `await` の **前** にインデックスや ID をローカル変数にコピー（スナップショット）する
- `await` の **後** には毎回ガード条件を入れる
- `.task(id:)` を ViewModel メソッドに移すと自動キャンセルが失われることを意識する

---

## 3. Task.detached の正しい使い方 — CPU 負荷の高い処理をメインスレッドから逃がす

### これは何か？

`Task.detached` は **呼び出し元のアクターから完全に切り離された** 新しいタスクを作ります。`@MainActor` メソッドの中で `Task.detached` を使うと、そのクロージャはメインスレッドではなくバックグラウンドスレッドで実行されます。

### なぜ必要なのか？

画像のデコード（`NSImage(data:)`）やファイル I/O（`Data(contentsOf:)`）は CPU を長時間ブロックします。これをメインスレッドで実行すると UI がカクつきます（フレームドロップ）。

### 正しい例

```swift
// ✅ Run file I/O on a background thread (from ConfigStore.swift)
func load() async throws -> ConfigDTO? {
    let fileURL = self.fileURL  // Copy Sendable value to local
    return try await Task.detached(priority: .utility) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let yaml = String(decoding: data, as: UTF8.self)
        return try YAMLDecoder().decode(ConfigDTO.self, from: yaml)
    }.value
}
```

```swift
// ✅ Run image decoding on a background thread (actual pattern from SlideshowPlayerViewModel)
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex
    do {
        let request = LoadSlideImageRequest(localIdentifier: slide.localIdentifier)
        let data = try await loadSlideImage.execute(request)
        guard currentIndex == expectedIndex else { return }
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)   // Heavy decode on background thread
        }.value
        guard currentIndex == expectedIndex else { return }
        currentNSImage = image
    } catch {
        currentNSImage = nil
    }
}
```

### 間違った例

```swift
// ❌ Decoding images directly in a @MainActor method — UI stutters
@MainActor
func loadCurrentImage() async {
    let data = try await loadSlideImageUseCase.execute(...)
    currentImage = NSImage(data: data)  // Heavy work on the main thread
}
```

```swift
// ❌ Capturing self in Task.detached when self is not Sendable
Task.detached {
    let data = try Data(contentsOf: self.fileURL)  // Compile error
}
```

### priority の使い分け

| 処理の種類 | priority |
|-----------|----------|
| ユーザー操作に直結する画像読み込み | `.userInitiated` |
| バックグラウンドのファイル I/O | `.utility` |
| サムネイル生成 | `.userInitiated` |

---

## 4. @ModelActor パターン — SwiftData をスレッドセーフに扱う

### これは何か？

`@ModelActor` は SwiftData が提供するマクロで、付けた `actor` に `modelContext` と `modelExecutor` を自動生成します。すべてのデータ操作がそのアクターのスレッド上で実行されるため、スレッドセーフが保証されます。

### なぜ actor が必要なのか？

`ModelContext` は **スレッドセーフではありません**。別のスレッドからアクセスすると、リレーションシップの遅延読み込み（lazy loading）がクラッシュやデータ破壊を引き起こします。`Mutex<ModelContext>` はアクセスを直列化しますが、**同じスレッドで実行される保証がない** ため問題が残ります。

### 正しい例 — 汎用 `SwiftDataStore`

10slide では、単一の汎用 `@ModelActor` アクターがすべての SwiftData アクセスを処理します。リポジトリが `transform` クロージャを渡し、アクター境界の **内側で** `@Model` からドメインエンティティへの変換を行います。

```swift
// Sources/Infrastructure/SwiftData/SwiftDataStore.swift
@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol {
    func fetch<T: PersistentModel, R: Sendable>(
        _ descriptor: FetchDescriptor<T>,
        transform: @Sendable (T) throws -> R
    ) throws -> [R] {
        try modelContext.fetch(descriptor).map(transform)
    }

    func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
        try work(modelContext)
    }
}
```

```swift
// Caller (SlideshowRepository) — transform runs inside the actor
func fetchAll() async throws -> [Slideshow] {
    try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in
        slideshow(from: $0)  // @Model → Entity conversion inside actor boundary
    }
}
```

### 間違った例

```swift
// ❌ Mutex<ModelContext> — thread is not pinned
final class UnsafeStore: Sendable {
    private let context: Mutex<ModelContext>

    func fetchAll() throws -> [SlideshowModel] {
        context.withLock { ctx in  // May execute on a different thread each time
            try ctx.fetch(FetchDescriptor<SlideshowModel>())  // Lazy loading causes corruption
        }
    }
}
```

```swift
// ❌ Returning @Model from the actor — @Model is not Sendable
@ModelActor
actor UnsafeStore {
    func fetchAll() throws -> [SlideshowModel] {
        try modelContext.fetch(FetchDescriptor<SlideshowModel>())
    }
}
```

### ルール

- 汎用の `@ModelActor actor` を使う — エンティティごとにデータソースアクターを作る必要はない
- `init(modelContainer:)` はマクロが生成するので自分で書かない
- `@Model` オブジェクトは actor の外に出さず、必ず `transform` クロージャで変換してから返す
- `@Model` 型は `Repositories/Models/` に置く（Infrastructure ではなく）

---

## 5. Mutex<T> による状態の保護

### これは何か？

Swift 6 の `Synchronization` モジュールに含まれる `Mutex<T>` は、ラップした値へのアクセスをロックで保護する型です。`final class` を `@unchecked Sendable` なしで正しく `Sendable` にできます。

### いつ使うのか？

- 複数のアクターやスレッドから同じ値を読み書きする必要があるとき
- ただし `@ModelActor` が使えるケース（SwiftData）や `@MainActor` で足りるケースでは不要

### 正しい例

```swift
// ✅ Protect a cache with Mutex
import Synchronization

final class ImageCache: Sendable {
    private let storage: Mutex<[String: Data]> = Mutex([:])

    func store(_ data: Data, for key: String) {
        storage.withLock { $0[key] = data }
    }

    func retrieve(for key: String) -> Data? {
        storage.withLock { $0[key] }
    }
}
```

### 間違った例

```swift
// ❌ Calling await inside withLock — compile error
storage.withLock { cache in
    let data = try await fetchData()  // await cannot be used inside withLock
    cache[key] = data
}
```

```swift
// ❌ Mutex is unnecessary for values used only with @MainActor
@MainActor
final class ViewModel {
    private let count: Mutex<Int> = Mutex(0)  // Overkill — @MainActor is sufficient
}
```

```swift
// ❌ Mutex is unnecessary for values that never change after init
final class Config: Sendable {
    private let settings: Mutex<[String: String]>  // Overkill — let is sufficient
    init(settings: [String: String]) {
        self.settings = Mutex(settings)  // If it never changes, a let property is fine
    }
}
```

### Mutex vs actor の使い分け

| 特徴 | `Mutex<T>` | `actor` |
|------|-----------|---------|
| アクセス | 同期（`withLock`） | 非同期（`await`） |
| 内部で `await` を使えるか | 不可 | 可能 |
| 主な用途 | 単純なキャッシュ、カウンタ | データソース、複雑な状態管理 |

---

## 6. DI コンテナや Request 型を Sendable にする実践パターン

### DI コンテナを Sendable にする

DI コンテナのメソッド参照を `@Sendable` クロージャとして渡すと、コンテナ自体が `Sendable` でなければコンパイルエラーになります。

```
warning: converting non-Sendable function value to
'@MainActor @Sendable (Slideshow) -> SlideshowPlayerViewModel' may introduce data races
```

### 正しい例

```swift
// ✅ final class + let-only properties → Sendable
// UseCase protocol typealiases already embed `any` — do not add `any` prefix
final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol  // typealias embeds `any`
    private let loadSlideImage: LoadSlideImageUseCaseProtocol

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: SlideshowResponse) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(slideshow: slideshow, loadSlideImage: loadSlideImage, ...)
    }
}
```

### 間違った例

```swift
// ❌ Having var causes a compile error
final class PresentationContainer: Sendable {
    var loadSlideImage: any LoadSlideImageUseCaseProtocol  // var is incompatible with Sendable
}
```

```swift
// ❌ Passing a method reference from a non-Sendable container
class PresentationContainer {  // Not Sendable
    func makePlayer(slideshow: Slideshow) -> SlideshowPlayerViewModel { ... }
}

// In ContentView
ContentView(makePlayer: container.makePlayer)  // ⚠️ non-Sendable function value
```

### Request 型を Sendable にする

UseCase に渡す Request は actor 境界を越えるため `Sendable` が必要です。

```swift
// ✅ protocol + struct — automatically Sendable
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String              // String is Sendable
    let localIdentifiers: [String]  // [String] is Sendable
    let duration: SlideDurationResponse
    let transition: TransitionTypeResponse
    let loop: Bool
    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
        guard !localIdentifiers.isEmpty else {
            throw ValidationError.noIdentifiers
        }
    }
}
```

```swift
// ❌ class inheritance — cannot be Sendable
class UseCaseRequest {               // Non-final class cannot be Sendable
    func validate() throws { }
}
class CreateSlideshowRequest: UseCaseRequest {  // Subclass could add var
    let name: String
}
```

---

## まとめ

| パターン | いつ使うか | キーポイント |
|---------|----------|------------|
| `Sendable` struct/enum | actor 境界を越えるデータ型 | 全プロパティが `Sendable` なら自動準拠 |
| `Sendable` final class | DI コンテナなど参照型が必要なとき | `let` プロパティのみ、`@unchecked` は禁止 |
| インデックススナップショット | `@MainActor` async メソッドで複数 `await` | `await` 前にスナップショット、`await` 後に毎回ガード |
| `Task.detached` | CPU 負荷の高い処理（画像デコード、I/O） | Sendable な値のみキャプチャ、priority を適切に設定 |
| `@ModelActor` | SwiftData アクセス（汎用 `SwiftDataStore`） | `@Model` を外に出さず `transform` クロージャでアクター内部で変換して返す |
| `Mutex<T>` | 複数アクターから共有する単純な可変状態 | `withLock` 内で `await` 不可、`@MainActor` で足りるなら不要 |
| `protocol + struct` Request | UseCase の入力型 | class 継承ではなく protocol で `Sendable` を確保 |

### 原則

1. **`@unchecked Sendable` は使わない** — コンパイラの保護を無効化するだけで、バグは隠れたまま残る
2. **`await` は中断ポイント** — その前後で状態が変わっている可能性を常に意識する
3. **型の選択で安全性が決まる** — `struct` / `final class` / `actor` の選択がそのまま `Sendable` 対応の容易さに直結する
