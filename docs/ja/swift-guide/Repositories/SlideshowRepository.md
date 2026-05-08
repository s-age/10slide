# Repository パターンと SwiftData の Swift 基礎概念

> 対象: Swift を学び始めたばかりの人。コードを読んで「なぜこう書くのか？」が分からない人。

---

## 対象ソースファイルと概要

| ファイル | 型の種類 | 役割 |
|---|---|---|
| `Sources/Repositories/Implementations/SlideshowRepository.swift` | Repository（実装クラス） | スライドショーの永続化・取得・削除を担当する |

このファイルは **Repository 層** に属します。Repository 層の仕事は「データをどこに・どうやって保存するか」という技術的な詳細を隠蔽し、上位レイヤー（Domain / UseCases）にはシンプルな Swift 型（エンティティ）だけを渡すことです。

---

## ソースコード全文（参照用）

```swift
import Foundation
import SwiftData

final class SlideshowRepository: SlideshowRepositoryProtocol {
    private let store: any SwiftDataStoreProtocol

    init(store: any SwiftDataStoreProtocol) {
        self.store = store
    }

    func fetchAll() async throws -> [Slideshow] {
        try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await store.fetch(
            FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        ) { [self] in slideshow(from: $0) }.first
    }

    func save(_ slideshow: Slideshow) async throws {
        let id = slideshow.id
        let name = slideshow.name
        let createdAt = slideshow.createdAt
        let durationRawValue = slideshow.config.duration.rawValue
        let transitionRawValue = slideshow.config.transition.rawValue
        let loop = slideshow.config.loop
        let slides = slideshow.slides

        try await store.write { context in
            let newSlides = slides.map {
                SlideModel(
                    id: $0.id,
                    localIdentifier: $0.localIdentifier,
                    order: $0.order,
                    duration: $0.duration,
                    title: $0.title
                )
            }
            let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
            if let existing = try context.fetch(descriptor).first {
                existing.name = name
                existing.durationRawValue = durationRawValue
                existing.transitionRawValue = transitionRawValue
                existing.loop = loop
                existing.slides.forEach { context.delete($0) }
                newSlides.forEach { context.insert($0) }
                existing.slides = newSlides
            } else {
                let model = SlideshowModel(
                    id: id,
                    name: name,
                    createdAt: createdAt,
                    durationRawValue: durationRawValue,
                    transitionRawValue: transitionRawValue,
                    loop: loop
                )
                context.insert(model)
                newSlides.forEach { context.insert($0) }
                model.slides = newSlides
            }
            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
    }

    // MARK: - Private

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

---

## 概念ごとの解説

---

### 1. Repository パターン -- データアクセスを抽象化する理由

#### 定義

**Repository パターン**とは、「データの読み書きをどうやって行うか」という技術的な詳細を、アプリのビジネスロジックから切り離す設計パターンです。

このアプリでは `SlideshowRepositoryProtocol` というプロトコルが「何ができるか（インターフェース）」を定義し、`SlideshowRepository` がその実装を担当します。

```swift
// Protocol (defined in the Protocols/ layer) -- declares only "what can be done"
protocol SlideshowRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slideshow]
    func fetch(id: UUID) async throws -> Slideshow?
    func save(_ slideshow: Slideshow) async throws
    func delete(id: UUID) async throws
}

// Implementation (in the Implementations/ layer) -- defines "how it's done"
final class SlideshowRepository: SlideshowRepositoryProtocol { ... }
```

#### なぜここで使われているか

Domain 層・UseCases 層は「スライドショーを取得してほしい」とだけ伝えます。データがどこに保存されているか -- SwiftData なのか、ファイルなのか、ネットワークなのか -- を知る必要はありません。Repository がその橋渡しをします。

#### `any SwiftDataStoreProtocol` について

```swift
private let store: any SwiftDataStoreProtocol
```

`any` キーワードはこれが **存在型（existential type）** であることを示します。つまり「`SwiftDataStoreProtocol` に準拠する任意の型を入れられる箱」です。これにより、Repository は具体的な型を知らなくても、ストアのどんな実装（本番の `SwiftDataStore` やテスト用のモックなど）とも連携できます。

#### `@Relationship(deleteRule: .cascade)` について

`SlideshowModel`（`Repositories/Models/` に定義）は以下を使用しています:

```swift
@Relationship(deleteRule: .cascade, inverse: \SlideModel.slideshow) var slides: [SlideModel]
```

これは、`SlideshowModel` が**削除**されると、その子である `SlideModel` もすべて自動的に削除されることを意味します。そのため `delete(id:)` メソッドは子を手動で削除せずに `store.delete(SlideshowModel.self, ...)` を呼ぶだけで済みます。ただし、`cascade` はリレーションの**再代入**時には発動しません。そのため `save()` では新しいスライドを代入する前に `context.delete($0)` で古いスライドを明示的に削除しています。

#### もし Repository パターンを使わなかったら

```swift
// Bad: UseCase directly manipulates SwiftData
final class FetchSlideshowsUseCase {
    private let context: ModelContext  // SwiftData knowledge leaks into the UseCase

    func execute() throws -> [Slideshow] {
        let models = try context.fetch(FetchDescriptor<SlideshowModel>())
        // ... conversion logic ends up inside the UseCase too
    }
}
```

- テストのときに「本物の DB を用意しないといけない」
- SwiftData を別の DB に変えたら UseCase も書き直しになる
- 関心の分離ができず、コードが複雑になる

#### 該当コード

```swift
final class SlideshowRepository: SlideshowRepositoryProtocol {
    // By conforming to the protocol, upper layers can only access it through the protocol
```

---

### 2. `import SwiftData` -- SwiftData フレームワーク

#### 定義

`import SwiftData` は Apple が提供するデータ永続化フレームワークを読み込む宣言です。SwiftData を使うと、Swift の `class` に `@Model` アノテーションを付けるだけでデータベース（SQLite）への保存・取得が行えます。

#### なぜここで使われているか

`SlideshowRepository` は `SlideshowModel`（SwiftData の `@Model` クラス）を使ってデータを読み書きするため、SwiftData のフレームワークが必要です。

#### もし import しなかったら

```swift
// Bad: Without the import, FetchDescriptor and #Predicate cause compile errors
FetchDescriptor<SlideshowModel>()  // error: cannot find type 'FetchDescriptor'
```

#### 該当コード

```swift
import Foundation
import SwiftData   // Needed to use SlideshowModel, FetchDescriptor, and #Predicate
```

> **ポイント**: SwiftData の `import` は Repository 層にのみ許可されています。Domain や UseCase では禁止されています。これにより「上位層は永続化の詳細を知らなくていい」というルールが守られます。

---

### 3. `FetchDescriptor<T>` -- ジェネリクスを使ったフェッチ記述子

#### 定義

`FetchDescriptor<T>` は「どのモデルを、どんな条件で取得するか」を表す型です。`<T>` の部分が**ジェネリクス（Generics）**で、`T` に具体的な型（ここでは `SlideshowModel`）を当てはめて使います。

ジェネリクスとは「型を変数のように扱う仕組み」です。`FetchDescriptor` 自体は「取得の記述子」という汎用的な概念であり、`<SlideshowModel>` と書くことで「`SlideshowModel` を取得する記述子」という具体的な型になります。

#### なぜここで使われているか

SwiftData はどのモデルを取得するかをコンパイル時に知る必要があります。`FetchDescriptor<SlideshowModel>` と書くことで「`SlideshowModel` を取り出すためのクエリ設定」を型安全に作れます。

```swift
// No arguments -- fetch all slideshows
FetchDescriptor<SlideshowModel>()

// With a predicate -- fetch only those matching the condition
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
```

#### もし型引数（`<T>`）がなかったら

```swift
// Bad: Without generics (hypothetical example)
FetchDescriptor(modelType: SlideshowModel.self)
// The return type would be [Any], so the compiler can't verify types
// You wouldn't notice mistakes until a runtime error occurs
```

#### 該当コード

```swift
// fetchAll: Fetch all records
try await store.fetch(FetchDescriptor<SlideshowModel>()) { ... }
//                               ^^^^^^^^^^^^^^^^
//                         Generics specifies the type to fetch

// fetch(id:): Conditional fetch
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
```

---

### 4. `#Predicate { }` -- マクロによる述語式

#### 定義

`#Predicate` は Swift のマクロ（コードを生成する仕組み）です。クロージャの中に「条件式」を Swift で書くと、コンパイラがそれをデータベースのクエリに変換してくれます。

#### なぜここで使われているか

特定の `id` を持つスライドショーだけを取得したいときに使います。`#Predicate { $0.id == id }` は「`id` プロパティが変数 `id` と等しいレコード」という条件を表します。

```swift
// Condition to fetch only slideshows with a matching id
#Predicate { $0.id == id }
```

このマクロは Swift コードとして書けるため、IDE の補完が効き、コンパイル時に型チェックも行われます。

#### もし `#Predicate` を使わなかったら

```swift
// Bad: Writing SQL as a string (the old CoreData approach)
NSPredicate(format: "id == %@", id as CVarArg)
// IDE autocompletion doesn't work because it's a string
// Typos aren't caught until runtime
// The compiler can't verify whether "id" is an actual property name
```

#### 該当コード

```swift
// fetch(id:) -- fetch only a specific ID
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
//                                         ^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                         A type-safe query written as Swift code

// delete(id:) -- delete only a specific ID
store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
```

---

### 5. `$0` -- クロージャの省略引数名

#### 定義

クロージャ（無名関数）の引数には名前を付けることができますが、`$0`・`$1`・`$2`... という**省略形**でも参照できます。`$0` は「1 番目の引数」を意味します。

```swift
// With a named parameter (verbose but clear)
{ model in slideshow(from: model) }

// Using $0 shorthand (compact)
{ slideshow(from: $0) }
```

#### なぜここで使われているか

`#Predicate { }` や `.map { }` などでは、クロージャの引数が明らかなため、`$0` で簡潔に書けます。

```swift
// $0 = each SlideshowModel element returned by FetchDescriptor
{ [self] in slideshow(from: $0) }

// $0 = each Slide element in the slides array
slides.map {
    SlideModel(
        id: $0.id,              // Slide's id
        localIdentifier: $0.localIdentifier,
        order: $0.order,
        duration: $0.duration,
        title: $0.title
    )
}
```

#### もし `$0` を使わなかったら

```swift
// Explicit argument name is slightly more verbose
slides.map { slide in
    SlideModel(
        id: slide.id,
        localIdentifier: slide.localIdentifier,
        order: slide.order,
        duration: slide.duration,
        title: slide.title
    )
}
// The behavior is the same. The named argument slide may be more readable depending on context
```

#### 該当コード

```swift
// Inside #Predicate
#Predicate { $0.id == id }
//           ^^ The SlideshowModel instance being fetched

// Inside map (save)
slides.map {
    SlideModel(id: $0.id, ...)
//             ^^ Each Slide element in the slides array

// Inside sorted (slideshow(from:))
model.slides.sorted { $0.order < $1.order }
//                    ^^         ^^ The two SlideModel instances being compared
```

---

### 6. `[self]` キャプチャリスト -- クロージャのキャプチャ

#### 定義

クロージャはその外側の変数を「キャプチャ（捕捉）」して使えます。**キャプチャリスト**（`[self]`・`[weak self]` など）は、「何をどうキャプチャするか」を明示的に宣言する構文です。

```swift
{ [self] in slideshow(from: $0) }
//^^^^^^^
// "Capture self (this class's instance) by value"
```

#### なぜここで使われているか

`store.fetch(...)` のトランスフォームクロージャは **SwiftData のアクター境界を越えて実行**されます。このとき Swift 6 コンパイラは「`self` をどう扱うか」を明示するよう求めます。

`[self]` と書くことで「クロージャが実行される時点の `self` を使う」と宣言でき、コンパイルエラーを防げます。

#### もし `[self]` を書かなかったら

```swift
// Bad: Without [self]
try await store.fetch(FetchDescriptor<SlideshowModel>()) { slideshow(from: $0) }
// In Swift 6, you may get errors like "Capture of 'self' with non-sendable type"
```

`[weak self]` ではなく `[self]` を使っているのは、Repository クラスが長期間生きており、クロージャ実行中に破棄されることがないためです。

#### 該当コード

```swift
func fetchAll() async throws -> [Slideshow] {
    try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
    //                                                         ^^^^^^
    //                    Explicitly captures self (SlideshowRepository)
}
```

---

### 7. トレイリングクロージャ構文 -- 関数の最後の引数がクロージャの場合

#### 定義

Swift では、関数の**最後の引数がクロージャ**の場合、`()` の外にクロージャを書ける「トレイリングクロージャ構文」が使えます。

```swift
// Standard call (with label)
store.fetch(FetchDescriptor<SlideshowModel>(), transform: { [self] in slideshow(from: $0) })

// Trailing closure syntax (write the last argument outside the ())
store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
```

#### なぜここで使われているか

クロージャが長くなるとき、`()` の外に書くとコードの構造が読みやすくなります。

```swift
// Trailing closure for store.write (multi-line)
try await store.write { context in
    // ... multiple lines of code ...
    try context.save()
}
// The { } indicates "this is the argument to store.write" while keeping indentation natural
```

#### もしトレイリングクロージャ構文を使わなかったら

```swift
// Without trailing closure (deeper nesting makes it harder to read)
try await store.write({ context in
    // ...
    try context.save()
})
```

#### 該当コード

```swift
// When it fits on a single line
try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
//                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                                      The closure is written outside the ()

// When it spans multiple lines
try await store.write { context in
    // ...
}
```

---

### 8. `.map { }`, `.sorted { }`, `.first` -- コレクション操作

#### 定義

Swift の配列（`Array`）には、要素を変換・絞り込み・集計するための便利なメソッドが標準で用意されています。

| メソッド | 意味 |
|---|---|
| `.map { }` | 各要素を変換して新しい配列を作る |
| `.sorted { }` | 条件に従って並べ替えた新しい配列を作る |
| `.first` | 最初の要素を返す（なければ `nil`） |
| `.forEach { }` | 各要素に対して処理を実行する（戻り値なし） |

#### なぜここで使われているか

**`.map { }`** -- `Slide`（エンティティ）を `SlideModel`（SwiftData モデル）に変換、またはその逆の変換をするとき。

```swift
// Slide entity -> SlideModel conversion (during save)
let newSlides = slides.map {
    SlideModel(id: $0.id, localIdentifier: $0.localIdentifier, ...)
}

// SlideModel -> Slide entity conversion (inside slideshow(from:))
.map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, ...) }
```

**`.sorted { }`** -- スライドを `order` 順（表示順）で並べ替えるとき。データベースは取り出し順を保証しないため、明示的に並べます。

```swift
model.slides.sorted { $0.order < $1.order }
//           ^^^^^^^ Sort in ascending order by order
```

**`.first`** -- `FetchDescriptor` の結果から最初の 1 件だけ取得するとき。`fetch` の戻り値は配列なので、`.first` で Optional（`nil` の可能性あり）の単一要素を取り出します。

```swift
try await store.fetch(...) { ... }.first
//                               ^^^^^^ The first element of the array. nil if not found
```

#### もし `.map { }` を使わなかったら

```swift
// Manual conversion with a for loop
var newSlides: [SlideModel] = []
for slide in slides {
    let model = SlideModel(id: slide.id, localIdentifier: slide.localIdentifier, ...)
    newSlides.append(model)
}
// The behavior is the same, but the intent of "converting an array to an array of another type" is less clear than with .map
```

#### 該当コード

```swift
// Inside slideshow(from:) -- chaining .sorted and .map
let slides = model.slides
    .sorted { $0.order < $1.order }   // 1. Sort by order
    .map { Slide(id: $0.id, ...) }    // 2. Convert SlideModel -> Slide entity

// fetch(id:) -- get a single Optional result with .first
} { [self] in slideshow(from: $0) }.first

// Inside save -- .forEach for batch insert/delete
existing.slides.forEach { context.delete($0) }
newSlides.forEach { context.insert($0) }
```

---

### 9. `context.insert()`, `context.delete()`, `context.save()` -- SwiftData の CRUD

#### 定義

SwiftData の `ModelContext`（変数名 `context`）は「データベースへの変更を一時的に記録する作業机」です。変更をすぐにディスクに書き込むのではなく、まず `context` 上で操作し、最後に `save()` を呼んでまとめて確定します。

| メソッド | 役割 |
|---|---|
| `context.insert(model)` | モデルをデータベースに追加する（Create） |
| `context.fetch(descriptor)` | 条件に合うモデルを取得する（Read） |
| `context.delete(model)` | モデルをデータベースから削除する（Delete） |
| `context.save()` | すべての変更をディスクに確定する |

#### なぜここで使われているか

`save()` を一番最後に呼ぶことで、途中でエラーが起きた場合にすべての変更が取り消されます。これを**アトミック操作**（「全部成功か、全部失敗か」）と呼びます。

```swift
try await store.write { context in
    // If an existing record is found, update it; otherwise, create a new one (Upsert pattern)
    if let existing = try context.fetch(descriptor).first {
        existing.name = name          // 1. Update properties
        existing.slides.forEach { context.delete($0) }   // 2. Delete old slides
        newSlides.forEach { context.insert($0) }         // 3. Add new slides
        existing.slides = newSlides
    } else {
        let model = SlideshowModel(...)
        context.insert(model)         // 1. Add a new record
        newSlides.forEach { context.insert($0) }
        model.slides = newSlides
    }
    try context.save()               // This is where data is actually written to disk
}
```

#### もし `save()` を呼ばなかったら

```swift
// Bad: If you forget save(), changes aren't persisted to disk
try await store.write { context in
    context.insert(model)
    // try context.save() -- forgot!
    // Data disappears when the app is restarted
}
```

#### 該当コード

```swift
try await store.write { context in
    // ...
    existing.slides.forEach { context.delete($0) }  // Delete old slides
    newSlides.forEach { context.insert($0) }         // Add new slides
    // ...
    try context.save()  // Commit changes to disk. Throws on error
}
```

---

### 10. `save()` 前の変数コピー -- クロージャへの安全な値の渡し方

#### 定義

`store.write { context in ... }` のクロージャは **SwiftData のアクター境界を越えて実行**されます。Swift 6 では、アクター境界を越えるクロージャは `Sendable` でなければならず、クロージャ内で `self` のプロパティを直接参照するとコンパイルエラーになる場合があります。

そのため `save()` メソッドの冒頭で、必要な値をすべてローカル変数にコピーしています。

```swift
func save(_ slideshow: Slideshow) async throws {
    // Copy values before passing to the closure
    let id = slideshow.id
    let name = slideshow.name
    let createdAt = slideshow.createdAt
    let durationRawValue = slideshow.config.duration.rawValue
    let transitionRawValue = slideshow.config.transition.rawValue
    let loop = slideshow.config.loop
    let slides = slideshow.slides    // Everything above is a copy

    try await store.write { context in
        // Inside the closure, use the copied values instead of self
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        // ...
    }
}
```

#### なぜここで使われているか

`Slideshow` は `Sendable` に準拠しているので、クロージャに直接渡せます。しかし SwiftData のアクター境界では、`self`（`SlideshowRepository`）を通じたアクセスよりも「生の値」を渡した方が安全かつシンプルです。特に `#Predicate` マクロは変数をキャプチャするため、`Sendable` な値型を渡すのが確実です。

#### もしコピーせずに関数パラメータを直接使おうとしたら

```swift
// Bad: Trying to capture the function parameter directly in the @Sendable closure
func save(_ slideshow: Slideshow) async throws {
    try await store.write { context in
        // #Predicate captures variables — referencing the function parameter directly
        // may cause issues with @Sendable closure requirements
        let descriptor = FetchDescriptor<SlideshowModel>(
            predicate: #Predicate { $0.id == slideshow.id }  // Possible compile error
        )
    }
}
```

#### 該当コード

```swift
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id                            // Copy a value type (UUID)
    let name = slideshow.name                        // Copy a value type (String)
    let durationRawValue = slideshow.config.duration.rawValue   // Copy a value type
    // ... copy all properties

    try await store.write { context in
        // Inside the closure, all copied value types are used
        #Predicate { $0.id == id }                   // Uses the copied id
    }
}
```

---

## まとめ: このファイルで学べること

### Swift 言語の基礎

| 概念 | 学んだこと |
|---|---|
| `import SwiftData` | フレームワークの読み込み。Repository 層だけに許可された import |
| ジェネリクス `<T>` | 型を変数のように扱う仕組み。`FetchDescriptor<SlideshowModel>` で取得対象を型安全に指定 |
| `$0` | クロージャの省略引数名。配列操作や `#Predicate` でよく使う |
| `[self]` キャプチャリスト | アクター境界を越えるクロージャで `self` をどう扱うか明示する |
| トレイリングクロージャ | 最後の引数がクロージャなら `()` の外に書ける。長い処理を読みやすくする |

### コレクション操作

| メソッド | 用途 |
|---|---|
| `.map { }` | 型変換。`SlideModel` と `Slide` の変換に使用 |
| `.sorted { }` | 並べ替え。`order` プロパティ順にスライドを整列 |
| `.first` | 先頭要素を Optional で取得。ID 検索の結果 1 件取り出しに使用 |
| `.forEach { }` | 副作用を伴う繰り返し。`insert` / `delete` の一括適用に使用 |

### SwiftData の CRUD

| 操作 | メソッド | 特徴 |
|---|---|---|
| 作成 (Create) | `context.insert(model)` | モデルを DB に追加 |
| 読み取り (Read) | `context.fetch(descriptor)` | 条件付き取得 |
| 更新 (Update) | プロパティへの代入 | `@Model` クラスは参照型なので直接変更可能 |
| 削除 (Delete) | `context.delete(model)` | モデルを DB から削除 |
| 確定 | `context.save()` | 変更をディスクに書き込む。最後に必ず呼ぶ |

### Repository パターンの 3 原則

1. **上位層はエンティティしか知らない** -- `SlideshowModel`（SwiftData の内部型）は Repository の外に一切出さない
2. **変換はすべて Repository の中** -- `@Model <-> Entity` の変換ロジックを一箇所に集約する
3. **実装はプロトコルで隠す** -- 呼び出し側は `SlideshowRepositoryProtocol` を通じてのみ操作し、SwiftData の詳細を知らなくていい

### アーキテクチャ上の位置づけ

```
Presentation
    |
UseCases  <- Requests "save the slideshow" through the Repository protocol
    |
Domain/Services
    |
Repositories  <- <- <- <- This is where SlideshowRepository lives
    |
Infrastructure (SwiftData's ModelContext)
```

Repository 層は「上への約束（エンティティを返す）」と「下への依頼（SwiftData で保存する）」の橋渡し役です。
