# SwiftData 実践ガイド — データ永続化で踏みがちな地雷

**種別:** 発展編（トピック横断ガイド）

SwiftData は Apple が提供するデータ永続化フレームワークで、`@Model` マクロを付けた Swift クラスを自動的にデータベースに保存できます。しかし、Core Data の後継として登場したばかりのフレームワークには **暗黙の挙動** が多く、エラーも出ないのにデータが消えるケースがあります。

このガイドでは、10slide の開発中に実際に踏んだ地雷と、安全なパターンをまとめます。

---

## 概要

| 地雷 | 症状 | 被害度 |
|------|------|--------|
| 親子リレーションの挿入順序 | 子レコードがサイレントに消える | 高 |
| リレーション再代入の孤児レコード | 古い子レコードがDBに残り続ける | 中 |
| プロパティ名変更のマイグレーション | アプリが起動時にクラッシュ | 高 |
| `ModelContext` のスレッド安全性 | データ破壊・クラッシュ | 高 |
| `@Model` のアクター境界越え | コンパイルエラー | 中 |

> **アーキテクチャ上の注意**: 10slide では、単一の汎用 `SwiftDataStore` アクター（Infrastructure）がすべての SwiftData I/O を処理し、`@Model` 型と `FetchDescriptor` の構築は Repositories レイヤーに配置されています。

---

## 1. @Model の親子リレーションシップ — 挿入順序の罠

### 問題

親モデルの `@Relationship` プロパティに子モデルを代入してから `modelContext.insert()` すると、**子モデルがサイレントに失われます**。`save()` はエラーを投げず成功しますが、次に `fetch()` すると子が空配列になっています。

10slide では「ライブラリから読み込んだ画像がスライドショーに表示されない」というバグとして発現しました。

### 間違った例

```swift
// ❌ Assigning children before insert — children are not saved
let model = SlideshowModel(id: id, name: name, ...)
model.slides = slides.map { SlideModel(id: $0.id, ...) }  // Children are outside the context
modelContext.insert(model)
try modelContext.save()
// → fetchAll() returns model.slides == []  (children are gone!)
```

### 正しい例

```swift
// ✅ Insert parent → insert children → assign relationship
let model = SlideshowModel(id: id, name: name, ...)
modelContext.insert(model)  // ① Register parent in context first

let slideModels = slides.map { SlideModel(id: $0.id, ...) }
slideModels.forEach { modelContext.insert($0) }  // ② Register children in context too

model.slides = slideModels  // ③ Assign while both are in the context
try modelContext.save()
```

### ルール

- **親と子の両方を insert した後に** リレーションを設定する
- `save()` がエラーなしで返っても、リレーションが保存されたとは限らない
- テストでは `save()` → `fetch()` → 子の件数確認 まで検証する

---

## 2. リレーションシップ再代入で消えない孤児レコード

### 問題

`@Relationship` の配列を新しい配列で上書きすると、古い子オブジェクトは **データベースに残り続けます**。`deleteRule: .cascade` は **親が削除されたとき** にのみ発動し、リレーション配列の再代入では発動しません。

### 間違った例

```swift
// ❌ Old children remain in the DB (orphan records)
func update(_ slideshow: Slideshow, context: ModelContext) throws {
    let id = slideshow.id
    let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
    let existing = try context.fetch(descriptor).first!
    existing.slides = slideshow.slides.map { SlideModel(...) }  // Old SlideModels are not deleted
    try context.save()
}
```

繰り返し保存するたびに古い `SlideModel` が蓄積し、データベースが肥大化します。

### 正しい例

```swift
// ✅ Explicitly delete old children before setting new ones
// (actual pattern from SlideshowRepository.save)
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id
    let slides = slideshow.slides

    try await store.write { context in
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })

        if let existing = try context.fetch(descriptor).first {
            // ① Delete all old children
            existing.slides.forEach { context.delete($0) }

            // ② Insert new children
            let newSlides = slides.map { SlideModel(id: $0.id, ...) }
            newSlides.forEach { context.insert($0) }

            // ③ Reassign the relationship
            existing.slides = newSlides
        } else {
            // New creation path
            let model = SlideshowModel(...)
            context.insert(model)
            // ...(set up children in the correct order from Pattern 1)
        }
        try context.save()
    }
}
```

### ルール

- リレーション配列を上書きする前に、古い子を `modelContext.delete()` で削除する
- `deleteRule: .cascade` はリレーション再代入では発動しない — **親の削除時のみ**
- upsert（存在すれば更新、なければ作成）パターンでは常にこの手順を踏む

---

## 3. プロパティ名変更とマイグレーションの落とし穴

### 問題

`@Model` のプロパティ名を変更（リネーム）すると、SwiftData の自動マイグレーション（Lightweight Migration）が **失敗** します。アプリ起動時にクラッシュします。

```
Fatal error: DI initialization failed: SwiftDataError(_error: loadIssueModelContainer)
Validation error missing attribute values on mandatory destination attribute
```

SwiftData はリネームを「旧カラムの削除 + 新カラムの追加」と解釈します。新カラムは既存行に値がないため、non-optional なら必ずエラーになります。

### 安全な変更 vs 危険な変更

| 変更内容 | 自動マイグレーション | 結果 |
|---------|------------------|------|
| 新プロパティの追加（デフォルト値あり） | 成功 | 既存行にはデフォルト値が入る |
| プロパティの削除 | 成功 | カラムが無視される |
| プロパティ名の変更 | **失敗** | クラッシュ |
| 型の変更（String → Int など） | **失敗** | クラッシュ |
| Optional → Non-optional | **失敗** | 既存行に nil があるとクラッシュ |

### 間違った例

```swift
// ❌ Simply renaming a property — automatic migration fails
@Model
final class SlideshowModel {
    // var title: String  ← old name
    var name: String      // ← new name (SwiftData interprets as "delete title + add name")
}
```

### 正しい例（開発中の回復）

```bash
# ✅ During development, delete the persistent store and recreate it
# The actual path includes the app's bundle ID subdirectory, e.g.:
rm -rf ~/Library/Application\ Support/com.example.TenSlide/default.store
# Check your actual path in Console.app or by searching ~/Library/Application\ Support/
```

### 正しい例（本番リリース後）

```swift
// ✅ Define migration using VersionedSchema
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] = [SlideshowModelV1.self]

    @Model final class SlideshowModelV1 {
        var title: String  // old name
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    static var models: [any PersistentModel.Type] = [SlideshowModel.self]
}

// Define the conversion from the old column to the new column using MigrationStage
```

### ルール

- 開発中のプロパティ名変更は永続ストア削除で対処可能
- 本番リリース後は `VersionedSchema` + `MigrationStage` が必須
- 新プロパティ追加（デフォルト値あり）は安全

---

## 4. @ModelActor パターン — スレッドセーフなデータアクセス

### 問題

`ModelContext` はスレッドセーフではありません。`Mutex<ModelContext>` でアクセスを直列化しても、**実行スレッドは毎回異なる可能性** があります。`@Relationship` の遅延読み込みが別スレッドで発動すると、データ破壊やクラッシュが起きます。

### 間違った例

```swift
// ❌ Mutex serializes access but does not pin to a thread
final class UnsafeStore: Sendable {
    private let context: Mutex<ModelContext>

    func fetchAll() throws -> [SlideshowModel] {
        context.withLock { ctx in
            try ctx.fetch(FetchDescriptor<SlideshowModel>())
            // ⚠️ Accessing model.slides triggers lazy loading
            // ⚠️ Crashes if this thread differs from the context's home thread
        }
    }
}
```

### 正しい例 — 汎用 `SwiftDataStore`

10slide では、単一の **汎用** `@ModelActor` アクターである `SwiftDataStore` がすべての SwiftData アクセスを処理します。3つのオペレーション（`fetch`、`delete`、`write`）がジェネリック型パラメータを受け取るため、エンティティごとのデータソースを作成する必要がありません。

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

    func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws {
        try modelContext.delete(model: type, where: predicate)
        try modelContext.save()
    }

    func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
        try work(modelContext)
    }
}
```

`fetch` の `transform` クロージャは **アクター内部** で実行されるため、`@Relationship` のトラバーサルは安全です。呼び出し元（Repository）が `FetchDescriptor` と変換ロジックを提供します。

### ルール

- すべての SwiftData アクセスには `@ModelActor actor` を使用する — `Mutex<ModelContext>` は使わない
- `init(modelContainer:)` はマクロが自動生成する — 自前で書かない
- 汎用ストア1つでアプリ全体に対応する — エンティティごとのデータソースアクターは不要

---

## 5. Transform パターン — @Model をアクター境界の内側で変換する

### 問題

`@Model` クラスは `Sendable` ではないため、`@ModelActor` の外に直接返すとコンパイルエラーになります。また、仮にコンパイルが通ったとしても、`@Relationship` プロパティへのアクセスが actor 外のスレッドで発生し、クラッシュの原因になります。

### 間違った例

```swift
// ❌ Returning @Model from the actor — compile error
func fetchAll() throws -> [SlideshowModel] {  // SlideshowModel is non-Sendable
    try modelContext.fetch(FetchDescriptor<SlideshowModel>())
}
```

```swift
// ❌ Forcing it through with @unchecked Sendable — crash risk
extension SlideshowModel: @unchecked Sendable { }
```

### 正しい例 — Repository が transform クロージャ付きで `fetch` を呼ぶ

10slide では、`@Model` 型は `Repositories/Models/` に配置されています（Infrastructure ではありません）。Repository が `SwiftDataStore.fetch()` に transform クロージャを渡し、**アクター境界の内側で** `@Model` → ドメインエンティティへの変換を行います。

```swift
// Sources/Repositories/Implementations/SlideshowRepository.swift
final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    func fetchAll() async throws -> [Slideshow] {
        try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in
            slideshow(from: $0)  // @Model → Entity inside the actor
        }
    }

    private func slideshow(from model: SlideshowModel) -> Slideshow {
        let config = SlideshowConfig(
            duration: SlideDuration(rawValue: model.durationRawValue) ?? .five,
            transition: TransitionType(rawValue: model.transitionRawValue) ?? .default,
            loop: model.loop
        )
        let slides = model.slides
            .sorted { $0.order < $1.order }
            .map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, order: $0.order, duration: $0.duration, title: $0.title) }
        return Slideshow(id: model.id, name: model.name, slides: slides, config: config, createdAt: model.createdAt)
    }
}
```

変更操作には `store.write(_:)` を使用して、アクター内部で複数ステップの操作をアトミックに実行します。

```swift
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id
    try await store.write { context in
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.slides.forEach { context.delete($0) }   // Delete old children
            // ... insert new children, assign relationship
        } else {
            // ... create new parent and children
        }
        try context.save()
    }
}
```

### ディレクトリ構成（実際の構成）

```
Infrastructure/SwiftData/
└── SwiftDataStore.swift         # Generic @ModelActor — the only SwiftData actor

Repositories/
├── Models/
│   ├── SlideshowModel.swift     # @Model class
│   └── SlideModel.swift         # @Model class
├── Implementations/
│   └── SlideshowRepository.swift  # Builds FetchDescriptor, supplies transform closure
└── Protocols/
    └── SlideshowRepositoryProtocol.swift
```

### ルール

- `@Model` 型は `Repositories/Models/` に配置する（Infrastructure ではない）
- `store.fetch()` に渡す `transform` クロージャで `@Model` → ドメインエンティティに変換する
- 複数ステップの変更操作は `store.write(_:)` でアクター内部でアトミックに実行する
- `@Model` はプロトコルのシグネチャに現れてはならない — 境界を越えるのはドメインエンティティのみ

---

## まとめ

| 地雷 | 原因 | 対策 |
|------|------|------|
| 子レコードが消える | insert 前にリレーションを代入 | 親 insert → 子 insert → リレーション代入 の順序を守る |
| 孤児レコードが残る | `deleteRule: .cascade` の誤解 | 再代入前に古い子を `modelContext.delete()` で削除する |
| プロパティ名変更でクラッシュ | Lightweight Migration の限界 | `VersionedSchema` + `MigrationStage` を使う |
| `ModelContext` のスレッド違反 | `Mutex` はスレッドを固定しない | 汎用 `@ModelActor actor`（`SwiftDataStore`）を使う |
| `@Model` がコンパイルエラー | non-Sendable がアクター境界を越える | アクター内部で `transform` クロージャを使いドメインエンティティに変換する |

### 原則

1. **SwiftData のサイレント失敗に注意** — `save()` が成功してもデータが実際には保存されていない場合がある
2. **`@Model` は actor の中に閉じ込める** — `store.fetch()` の `transform` クロージャでドメインエンティティに変換するか、`store.write()` の内部で変更操作を行う
3. **挿入順序を守る** — 親 → 子 → リレーション設定 の3ステップ
