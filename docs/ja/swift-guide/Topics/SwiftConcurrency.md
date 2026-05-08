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
// ✅ struct — プロパティが全て Sendable なら自動的に Sendable
struct SlideDTO: Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
}
```

```swift
// ✅ final class — let プロパティのみで Sendable
final class PresentationContainer: Sendable {
    private let createSlideshow: any CreateSlideshowUseCaseProtocol  // Sendable なプロトコル
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol
}
```

### 間違った例

```swift
// ❌ 非 final class は Sendable にできない
class UseCaseRequest: Sendable {  // コンパイルエラー
    func validate() throws { }
}
```

```swift
// ❌ var がある final class は Sendable にできない
final class Cache: Sendable {
    var items: [String: Data] = [:]  // コンパイルエラー：var は Sendable と両立しない
}
```

```swift
// ❌ @unchecked Sendable で警告を黙らせる（プロジェクトで禁止）
final class Cache: @unchecked Sendable {
    var items: [String: Data] = [:]  // コンパイラは通るが、データ競合のリスクを隠している
}
```

### 10slide での実例

UseCase の Request 型は当初 `class` 継承で設計されていましたが、Swift 6 では `Sendable` にできないためコンパイルエラーになりました。`protocol UseCaseRequest: Sendable` + `struct` に変更して解決しています。

```swift
// ✅ protocol + struct パターン（現在の設計）
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let slides: [SlideInfo]
    func validate() throws { /* ... */ }
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
// ❌ await の間にインデックスが変わると古い画像で上書きされる
@MainActor
func loadCurrentImage() async {
    guard let slide = currentSlide else { return }
    do {
        let data = try await loadSlideImageUseCase.execute(slide: slide)
        // ⚠️ この時点で currentIndex は変わっているかもしれない
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        // ⚠️ ここでも currentIndex は変わっているかもしれない
        currentNSImage = image  // 古い画像で上書きしてしまう！
    } catch {
        currentNSImage = nil
    }
}
```

### 正しい例：インデックススナップショットパターン

```swift
// ✅ await の前にインデックスをスナップショットし、await の後で毎回検証する
@MainActor
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex  // ① スナップショットを取る

    do {
        let data = try await loadSlideImageUseCase.execute(slide: slide)
        guard currentIndex == expectedIndex else { return }  // ② fetch 後にガード

        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        guard currentIndex == expectedIndex else { return }  // ③ decode 後にもガード

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
// ✅ ファイル I/O をバックグラウンドで実行
func load() async throws -> ConfigDTO {
    let fileURL = self.fileURL  // Sendable な値をローカルにコピー
    return try await Task.detached(priority: .utility) {
        let data = try Data(contentsOf: fileURL)
        return try YAMLDecoder().decode(ConfigDTO.self, from: data)
    }.value
}
```

```swift
// ✅ 画像デコードをバックグラウンドで実行（デコーダーを注入）
private let imageDecoder: @Sendable (Data) -> NSImage?

func loadCurrentImage() async {
    let data = try await loadSlideImageUseCase.execute(...)
    let decode = imageDecoder  // ローカルにコピー（Sendable）
    currentImage = await Task.detached(priority: .userInitiated) {
        decode(data)
    }.value
}
```

### 間違った例

```swift
// ❌ @MainActor メソッド内で直接画像デコード — UI がカクつく
@MainActor
func loadCurrentImage() async {
    let data = try await loadSlideImageUseCase.execute(...)
    currentImage = NSImage(data: data)  // メインスレッドで重い処理
}
```

```swift
// ❌ self が Sendable でないのに Task.detached 内でキャプチャ
Task.detached {
    let data = try Data(contentsOf: self.fileURL)  // コンパイルエラー
}
```

### priority の使い分け

| 処理の種類 | priority |
|-----------|----------|
| ユーザー操作に直結する画像読み込み | `.userInitiated` |
| バックグラウンドのファイル I/O | `.utility` |
| サムネイルのプリフェッチ | `.background` |

### テストでの工夫：デコーダーを注入する

`NSImage(data:)` をテストで呼ぶと実際の画像データが必要になります。デコーダーを `@Sendable` クロージャとして `init` に注入すれば、テストではスタブに差し替えられます。

```swift
// プロダクションコード
init(..., imageDecoder: @Sendable @escaping (Data) -> NSImage? = { NSImage(data: $0) }) {
    self.imageDecoder = imageDecoder
}

// テストコード
sut = SlideshowPlayerViewModel(
    ...,
    imageDecoder: { _ in NSImage(size: .init(width: 1, height: 1)) }
)
```

---

## 4. @ModelActor パターン — SwiftData をスレッドセーフに扱う

### これは何か？

`@ModelActor` は SwiftData が提供するマクロで、付けた `actor` に `modelContext` と `modelExecutor` を自動生成します。すべてのデータ操作がそのアクターのスレッド上で実行されるため、スレッドセーフが保証されます。

### なぜ actor が必要なのか？

`ModelContext` は **スレッドセーフではありません**。別のスレッドからアクセスすると、リレーションシップの遅延読み込み（lazy loading）がクラッシュやデータ破壊を引き起こします。`Mutex<ModelContext>` はアクセスを直列化しますが、**同じスレッドで実行される保証がない** ため問題が残ります。

### 正しい例

```swift
// ✅ @ModelActor で全アクセスを同一スレッドに固定
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    // modelContext と modelExecutor はマクロが自動生成する

    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))  // actor 内で DTO に変換してから返す
    }

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        SlideshowDTO(id: model.id, name: model.name, slides: model.slides.map { ... })
    }
}
```

### 間違った例

```swift
// ❌ Mutex<ModelContext> — スレッドは固定されない
final class SlideshowDataSource: Sendable {
    private let context: Mutex<ModelContext>

    func fetchAll() throws -> [SlideshowDTO] {
        context.withLock { ctx in  // 毎回違うスレッドで実行される可能性がある
            try ctx.fetch(FetchDescriptor<SlideshowModel>())  // リレーション遅延読み込みで破壊
        }
    }
}
```

```swift
// ❌ @Model を actor の外に返す
@ModelActor
actor SlideshowDataSource {
    func fetchAll() throws -> [SlideshowModel] {  // @Model は Sendable ではない！
        try modelContext.fetch(FetchDescriptor<SlideshowModel>())
    }
}
```

### ルール

- `@ModelActor actor` として宣言する（`final class` ではなく）
- `init(modelContainer:)` はマクロが生成するので自分で書かない
- `@Model` オブジェクトは actor の外に出さず、必ず DTO に変換してから返す
- プロトコルは `async throws` で宣言する（actor のメソッドは自動的に async になる）

---

## 5. Mutex<T> による状態の保護

### これは何か？

Swift 6 の `Synchronization` モジュールに含まれる `Mutex<T>` は、ラップした値へのアクセスをロックで保護する型です。`final class` を `@unchecked Sendable` なしで正しく `Sendable` にできます。

### いつ使うのか？

- 複数のアクターやスレッドから同じ値を読み書きする必要があるとき
- ただし `@ModelActor` が使えるケース（SwiftData）や `@MainActor` で足りるケースでは不要

### 正しい例

```swift
// ✅ キャッシュを Mutex で保護
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
// ❌ withLock 内で await を呼ぶ — コンパイルエラー
storage.withLock { cache in
    let data = try await fetchData()  // await は withLock 内で使えない
    cache[key] = data
}
```

```swift
// ❌ @MainActor のみで使う値に Mutex は不要
@MainActor
final class ViewModel {
    private let count: Mutex<Int> = Mutex(0)  // 過剰 — @MainActor で十分
}
```

```swift
// ❌ init 後に変更しない値に Mutex は不要
final class Config: Sendable {
    private let settings: Mutex<[String: String]>  // 過剰 — let で十分
    init(settings: [String: String]) {
        self.settings = Mutex(settings)  // 変更しないなら let プロパティでよい
    }
}
```

### Mutex vs actor の使い分け

| 特徴 | `Mutex<T>` | `actor` |
|------|-----------|---------|
| アクセス | 同期（`withLock`） | 非同期（`await`） |
| `await` 内で使えるか | 不可 | 可能 |
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
// ✅ final class + let プロパティのみ → Sendable
final class PresentationContainer: Sendable {
    private let createSlideshow: any CreateSlideshowUseCaseProtocol
    private let loadSlideImage: any LoadSlideImageUseCaseProtocol

    init(createSlideshow: any CreateSlideshowUseCaseProtocol,
         loadSlideImage: any LoadSlideImageUseCaseProtocol) {
        self.createSlideshow = createSlideshow
        self.loadSlideImage = loadSlideImage
    }

    func makeSlideshowPlayerViewModel(slideshow: Slideshow) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(slideshow: slideshow, loadSlideImage: loadSlideImage)
    }
}
```

### 間違った例

```swift
// ❌ var があるとコンパイルエラー
final class PresentationContainer: Sendable {
    var loadSlideImage: any LoadSlideImageUseCaseProtocol  // var は Sendable と両立しない
}
```

```swift
// ❌ Sendable でないコンテナからメソッド参照を渡す
class PresentationContainer {  // Sendable でない
    func makePlayer(slideshow: Slideshow) -> SlideshowPlayerViewModel { ... }
}

// ContentView で
ContentView(makePlayer: container.makePlayer)  // ⚠️ non-Sendable function value
```

### Request 型を Sendable にする

UseCase に渡す Request は actor 境界を越えるため `Sendable` が必要です。

```swift
// ✅ protocol + struct — 自動で Sendable
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String      // String は Sendable
    let slides: [SlideInfo]  // SlideInfo が Sendable なら OK
    func validate() throws {
        guard !name.isEmpty else { throw ValidationError.emptyName }
    }
}
```

```swift
// ❌ class 継承 — Sendable にできない
class UseCaseRequest {               // 非 final class は Sendable 不可
    func validate() throws { }
}
class CreateSlideshowRequest: UseCaseRequest {  // サブクラスで var を追加できてしまう
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
| `@ModelActor` | SwiftData のデータソース | `@Model` を外に出さず DTO に変換して返す |
| `Mutex<T>` | 複数アクターから共有する単純な可変状態 | `withLock` 内で `await` 不可、`@MainActor` で足りるなら不要 |
| `protocol + struct` Request | UseCase の入力型 | class 継承ではなく protocol で `Sendable` を確保 |

### 原則

1. **`@unchecked Sendable` は使わない** — コンパイラの保護を無効化するだけで、バグは隠れたまま残る
2. **`await` は中断ポイント** — その前後で状態が変わっている可能性を常に意識する
3. **型の選択で安全性が決まる** — `struct` / `final class` / `actor` の選択がそのまま `Sendable` 対応の容易さに直結する
