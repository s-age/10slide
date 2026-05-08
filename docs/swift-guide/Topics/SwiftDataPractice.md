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

---

## 1. @Model の親子リレーションシップ — 挿入順序の罠

### 問題

親モデルの `@Relationship` プロパティに子モデルを代入してから `modelContext.insert()` すると、**子モデルがサイレントに失われます**。`save()` はエラーを投げず成功しますが、次に `fetch()` すると子が空配列になっています。

10slide では「ライブラリから読み込んだスライドショーに画像が表示されない」というバグとして発現しました。

### 間違った例

```swift
// ❌ 子を代入してから insert — 子が保存されない
let model = SlideshowModel(id: dto.id, name: dto.name)
model.slides = dto.slides.map { SlideModel(id: $0.id, ...) }  // 子がコンテキスト外
modelContext.insert(model)
try modelContext.save()
// → fetchAll() すると model.slides == []  （子が消えている！）
```

### 正しい例

```swift
// ✅ 親を insert → 子を insert → リレーションを代入
let model = SlideshowModel(id: dto.id, name: dto.name)
modelContext.insert(model)  // ① 親をまずコンテキストに登録

let slideModels = dto.slides.map { SlideModel(id: $0.id, ...) }
slideModels.forEach { modelContext.insert($0) }  // ② 子もコンテキストに登録

model.slides = slideModels  // ③ 両方がコンテキスト内にある状態で代入
try modelContext.save()
```

### ルール

- **親と子の両方を `insert` した後に** リレーションを設定する
- `save()` がエラーなしで返っても、リレーションが保存されたとは限らない
- テストでは `save()` → `fetch()` → 子の件数確認 まで検証する

---

## 2. リレーションシップ再代入で消えない孤児レコード

### 問題

`@Relationship` の配列を新しい配列で上書きすると、古い子オブジェクトは **データベースに残り続けます**。`deleteRule: .cascade` は **親が削除されたとき** にのみ発動し、リレーション配列の再代入では発動しません。

### 間違った例

```swift
// ❌ 古い子が DB に残り続ける（孤児レコード）
func update(_ dto: SlideshowDTO) throws {
    let existing = try fetchExisting(id: dto.id)
    existing.slides = dto.slides.map { SlideModel(...) }  // 古い SlideModel は削除されない
    try modelContext.save()
}
```

繰り返し保存するたびに古い `SlideModel` が蓄積し、データベースが肥大化します。

### 正しい例

```swift
// ✅ 古い子を明示的に削除してから新しい子を設定
func save(_ dto: SlideshowDTO) throws {
    let id = dto.id
    let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })

    if let existing = try modelContext.fetch(descriptor).first {
        // ① 古い子を全て削除
        existing.slides.forEach { modelContext.delete($0) }

        // ② 新しい子を insert
        let newSlides = dto.slides.map { SlideModel(id: $0.id, ...) }
        newSlides.forEach { modelContext.insert($0) }

        // ③ リレーションを再設定
        existing.slides = newSlides
    } else {
        // 新規作成パス
        let model = SlideshowModel(...)
        modelContext.insert(model)
        // ...（パターン 1 の正しい順序で子を設定）
    }
    try modelContext.save()
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
// ❌ プロパティ名を変更しただけ — 自動マイグレーションが失敗する
@Model
final class SlideshowModel {
    // var title: String  ← 旧名
    var name: String      // ← 新名（SwiftData は「title削除 + name追加」と解釈）
}
```

### 正しい例（開発中の回復）

```bash
# ✅ 開発中なら永続ストアを削除して再作成
rm ~/Library/Application\ Support/default.store
```

### 正しい例（本番リリース後）

```swift
// ✅ VersionedSchema でマイグレーションを定義する
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(1, 0, 0)
    static var models: [any PersistentModel.Type] = [SlideshowModelV1.self]

    @Model final class SlideshowModelV1 {
        var title: String  // 旧名
    }
}

enum AppSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = .init(2, 0, 0)
    static var models: [any PersistentModel.Type] = [SlideshowModel.self]
}

// MigrationStage で旧カラムから新カラムへの変換を定義
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
// ❌ Mutex は直列化するがスレッドを固定しない
final class SlideshowDataSource: Sendable {
    private let context: Mutex<ModelContext>

    func fetchAll() throws -> [SlideshowModel] {
        context.withLock { ctx in
            try ctx.fetch(FetchDescriptor<SlideshowModel>())
            // ⚠️ model.slides にアクセスすると遅延読み込みが発動
            // ⚠️ このスレッドが context のホームスレッドと違うとクラッシュ
        }
    }
}
```

### 正しい例

```swift
// ✅ @ModelActor で全アクセスを同一スレッドに固定
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    // modelContext はマクロが自動生成

    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))
    }

    private func dto(from model: SlideshowModel) -> SlideshowDTO {
        // @Relationship の遅延読み込みもこの actor のスレッドで安全に行われる
        SlideshowDTO(
            id: model.id,
            name: model.name,
            slides: model.slides.map { slide in
                SlideDTO(id: slide.id, localIdentifier: slide.localIdentifier, ...)
            }
        )
    }
}
```

### ルール

- SwiftData のデータソースは `@ModelActor actor` で宣言する
- `init(modelContainer:)` はマクロが生成する — 自前で書かない
- DI コンテナでの初期化：`SlideshowDataSource(modelContainer: modelContainer)`

---

## 5. DTO パターン — @Model をアクター境界の外に出さない

### 問題

`@Model` クラスは `Sendable` ではないため、`@ModelActor` の外に直接返すとコンパイルエラーになります。また、仮にコンパイルが通ったとしても、`@Relationship` プロパティへのアクセスが actor 外のスレッドで発生し、クラッシュの原因になります。

### 間違った例

```swift
// ❌ @Model を actor の外に返す — コンパイルエラー
@ModelActor
actor SlideshowDataSource {
    func fetchAll() throws -> [SlideshowModel] {  // SlideshowModel は non-Sendable
        try modelContext.fetch(FetchDescriptor<SlideshowModel>())
    }
}
```

```swift
// ❌ @unchecked Sendable で無理やり通す — クラッシュの危険
extension SlideshowModel: @unchecked Sendable { }
```

### 正しい例

```swift
// ✅ Sendable な DTO struct を定義
struct SlideshowDTO: Sendable {
    let id: UUID
    let name: String
    let slides: [SlideDTO]
}

struct SlideDTO: Sendable {
    let id: UUID
    let localIdentifier: String
    let order: Int
    let duration: Double
}
```

```swift
// ✅ actor 内で @Model → DTO に変換してから返す
@ModelActor
actor SlideshowDataSource: SlideshowDataSourceProtocol {
    func fetchAll() throws -> [SlideshowDTO] {
        let models = try modelContext.fetch(FetchDescriptor<SlideshowModel>())
        return models.map(dto(from:))  // actor 内で変換
    }

    func save(_ dto: SlideshowDTO) throws {
        // DTO → @Model への変換も actor 内で行う
        let model = SlideshowModel(id: dto.id, name: dto.name)
        modelContext.insert(model)
        let slideModels = dto.slides.map { SlideModel(id: $0.id, ...) }
        slideModels.forEach { modelContext.insert($0) }
        model.slides = slideModels
        try modelContext.save()
    }
}
```

### ディレクトリ構成

```
Infrastructure/SwiftData/
├── DTO/
│   ├── SlideDTO.swift          # Sendable struct
│   └── SlideshowDTO.swift      # Sendable struct
├── SlideshowDataSource.swift   # @ModelActor actor（@Model を内部に閉じ込める）
└── SlideDataSource.swift       # @ModelActor actor
```

### ルール

- `@Model` はプロトコルのシグネチャに現れてはならない — DTO のみ公開する
- DTO は `Infrastructure/SwiftData/DTO/` に配置する
- 変換ロジック（`dto(from:)` / `model(from:)`）は `@ModelActor` 内に書く
- `@Relationship` のトラバーサル（`model.slides` へのアクセス）は必ず actor 内で完了させる

---

## まとめ

| 地雷 | 原因 | 対策 |
|------|------|------|
| 子レコードが消える | insert 前にリレーションを代入 | 親 insert → 子 insert → リレーション代入 の順序を守る |
| 孤児レコードが残る | `deleteRule: .cascade` の誤解 | 再代入前に古い子を `modelContext.delete()` |
| プロパティ名変更でクラッシュ | Lightweight Migration の限界 | `VersionedSchema` + `MigrationStage` を使う |
| `ModelContext` のスレッド違反 | `Mutex` はスレッドを固定しない | `@ModelActor actor` を使う |
| `@Model` がコンパイルエラー | non-Sendable がアクター境界を越える | DTO に変換してから返す |

### 原則

1. **SwiftData のサイレント失敗に注意** — `save()` が成功してもデータが保存されていない場合がある
2. **`@Model` は actor の中に閉じ込める** — 外に出すのは常に `Sendable` な DTO
3. **挿入順序を守る** — 親 → 子 → リレーション設定 の3ステップ
