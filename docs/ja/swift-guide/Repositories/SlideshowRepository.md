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

### 1. Repository パターン — データアクセスを抽象化する理由

#### 定義

**Repository パターン**とは、「データの読み書きをどうやって行うか」という技術的な詳細を、アプリのビジネスロジックから切り離す設計パターンです。

このアプリでは `SlideshowRepositoryProtocol` というプロトコルが「何ができるか（インターフェース）」を定義し、`SlideshowRepository` がその実装を担当します。

```swift
// プロトコル（Protocols/ 層に定義）― 「何ができるか」だけを宣言
protocol SlideshowRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Slideshow]
    func fetch(id: UUID) async throws -> Slideshow?
    func save(_ slideshow: Slideshow) async throws
    func delete(id: UUID) async throws
}

// 実装（Implementations/ 層）― 「どうやってやるか」を定義
final class SlideshowRepository: SlideshowRepositoryProtocol { ... }
```

#### なぜここで使われているか

Domain 層・UseCases 層は「スライドショーを取得してほしい」とだけ伝えます。データがどこに保存されているか（SwiftData なのか、ファイルなのか、ネットワークなのか）を知る必要はありません。Repository がその橋渡しをします。

#### もし Repository パターンを使わなかったら

```swift
// ❌ UseCase が SwiftData を直接操作する
final class FetchSlideshowsUseCase {
    private let context: ModelContext  // ← SwiftData の知識が UseCase に漏れる

    func execute() throws -> [Slideshow] {
        let models = try context.fetch(FetchDescriptor<SlideshowModel>())
        // ... 変換ロジックも UseCase 内に書かれてしまう
    }
}
```

- テストのときに「本物の DB を用意しないといけない」
- SwiftData を別の DB に変えたら UseCase も書き直しになる
- 関心の分離ができず、コードが複雑になる

#### 該当コード

```swift
final class SlideshowRepository: SlideshowRepositoryProtocol {
    // ← プロトコルに準拠することで、上位層はプロトコル越しにしか触れない
```

---

### 2. `import SwiftData` — SwiftData フレームワーク

#### 定義

`import SwiftData` は Apple が提供するデータ永続化フレームワークを読み込む宣言です。SwiftData を使うと、Swift の `class` に `@Model` アノテーションを付けるだけでデータベース（SQLite）への保存・取得が行えます。

#### なぜここで使われているか

`SlideshowRepository` は `SlideshowModel`（SwiftData の `@Model` クラス）を使ってデータを読み書きするため、SwiftData のフレームワークが必要です。

#### もし import しなかったら

```swift
// ❌ import なしだと FetchDescriptor や #Predicate がコンパイルエラーになる
FetchDescriptor<SlideshowModel>()  // error: cannot find type 'FetchDescriptor'
```

#### 該当コード

```swift
import Foundation
import SwiftData   // ← SlideshowModel, FetchDescriptor, #Predicate を使うために必要
```

> **ポイント**: SwiftData の `import` は Repository 層にのみ許可されています。Domain や UseCase では禁止されています。これにより「上位層は永続化の詳細を知らなくていい」というルールが守られます。

---

### 3. `FetchDescriptor<T>` — ジェネリクスを使ったフェッチ記述子

#### 定義

`FetchDescriptor<T>` は「どのモデルを、どんな条件で取得するか」を表す型です。`<T>` の部分が**ジェネリクス（Generics）**で、`T` に具体的な型（ここでは `SlideshowModel`）を当てはめて使います。

ジェネリクスとは「型を変数のように扱う仕組み」です。`FetchDescriptor` 自体は「取得の記述子」という汎用的な概念であり、`<SlideshowModel>` と書くことで「`SlideshowModel` を取得する記述子」という具体的な型になります。

#### なぜここで使われているか

SwiftData はどのモデルを取得するかをコンパイル時に知る必要があります。`FetchDescriptor<SlideshowModel>` と書くことで「`SlideshowModel` を取り出すためのクエリ設定」を型安全に作れます。

```swift
// 引数なし ― すべてのスライドショーを取得
FetchDescriptor<SlideshowModel>()

// predicate 付き ― 条件に一致するものだけ取得
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
```

#### もし型引数（`<T>`）がなかったら

```swift
// ❌ ジェネリクスなし（架空の例）
FetchDescriptor(modelType: SlideshowModel.self)
// → 戻り値が [Any] になるため、コンパイラが型を検証できない
//   実行時エラーになるまで間違いに気づけない
```

#### 該当コード

```swift
// fetchAll: 全件取得
try await store.fetch(FetchDescriptor<SlideshowModel>()) { ... }
//                               ^^^^^^^^^^^^^^^^
//                         ジェネリクスで取得対象の型を指定

// fetch(id:): 条件付き取得
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
```

---

### 4. `#Predicate { }` — マクロによる述語式

#### 定義

`#Predicate` は Swift のマクロ（コードを生成する仕組み）です。クロージャの中に「条件式」を Swift で書くと、コンパイラがそれをデータベースのクエリに変換してくれます。

#### なぜここで使われているか

特定の `id` を持つスライドショーだけを取得したいときに使います。`#Predicate { $0.id == id }` は「`id` プロパティが変数 `id` と等しいレコード」という条件を表します。

```swift
// id が一致するスライドショーだけを取得する条件
#Predicate { $0.id == id }
```

このマクロは Swift コードとして書けるため、IDE の補完が効き、コンパイル時に型チェックも行われます。

#### もし `#Predicate` を使わなかったら

```swift
// ❌ 文字列で SQL を書く（古い CoreData の書き方）
NSPredicate(format: "id == %@", id as CVarArg)
// → 文字列なので IDE の補完が効かない
// → タイポしても実行時まで気づけない
// → "id" が実際のプロパティ名かどうかコンパイラが検証できない
```

#### 該当コード

```swift
// fetch(id:) — 特定 ID だけ取得
FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
//                                         ^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                         Swift コードとして書かれた型安全なクエリ

// delete(id:) — 特定 ID だけ削除
store.delete(SlideshowModel.self, where: #Predicate { $0.id == id })
```

---

### 5. `$0` — クロージャの省略引数名

#### 定義

クロージャ（無名関数）の引数には名前を付けることができますが、`$0`・`$1`・`$2`… という**省略形**でも参照できます。`$0` は「1 番目の引数」を意味します。

```swift
// 名前あり（冗長だが分かりやすい）
{ model in slideshow(from: model) }

// $0 を使った省略形（コンパクト）
{ slideshow(from: $0) }
```

#### なぜここで使われているか

`#Predicate { }` や `.map { }` などでは、クロージャの引数が明らかなため、`$0` で簡潔に書けます。

```swift
// $0 = FetchDescriptor が返す SlideshowModel の各要素
{ [self] in slideshow(from: $0) }

// $0 = slides 配列の各 Slide 要素
slides.map {
    SlideModel(
        id: $0.id,              // Slide の id
        localIdentifier: $0.localIdentifier,
        order: $0.order,
        duration: $0.duration,
        title: $0.title
    )
}
```

#### もし `$0` を使わなかったら

```swift
// ❌ 引数名を明示するとやや冗長になる
slides.map { slide in
    SlideModel(
        id: slide.id,
        localIdentifier: slide.localIdentifier,
        order: slide.order,
        duration: slide.duration,
        title: slide.title
    )
}
// 動作は同じ。引数名 slide の方が文脈によっては読みやすい場合もある
```

#### 該当コード

```swift
// #Predicate 内
#Predicate { $0.id == id }
//           ^^ 取得対象の SlideshowModel インスタンス

// map 内（save）
slides.map {
    SlideModel(id: $0.id, ...)
//             ^^ slides 配列の各 Slide 要素

// sorted 内（slideshow(from:)）
model.slides.sorted { $0.order < $1.order }
//                    ^^         ^^ 比較する 2 つの SlideModel
```

---

### 6. `[self]` キャプチャリスト — クロージャのキャプチャ

#### 定義

クロージャはその外側の変数を「キャプチャ（捕捉）」して使えます。**キャプチャリスト**（`[self]`・`[weak self]` など）は、「何をどうキャプチャするか」を明示的に宣言する構文です。

```swift
{ [self] in slideshow(from: $0) }
//^^^^^^^
// "self（このクラスのインスタンス）を値としてキャプチャする"
```

#### なぜここで使われているか

`store.fetch(...)` のトランスフォームクロージャは **SwiftData のアクター境界を越えて実行**されます。このとき Swift 6 コンパイラは「`self` をどう扱うか」を明示するよう求めます。

`[self]` と書くことで「クロージャが実行される時点の `self` を使う」と宣言でき、コンパイルエラーを防げます。

#### もし `[self]` を書かなかったら

```swift
// ❌ [self] なし
try await store.fetch(FetchDescriptor<SlideshowModel>()) { in slideshow(from: $0) }
// Swift 6 では "Capture of 'self' with non-sendable type" などのエラーが出る場合がある
```

`[weak self]` ではなく `[self]` を使っているのは、Repository クラスが長期間生きており、クロージャ実行中に破棄されることがないためです。

#### 該当コード

```swift
func fetchAll() async throws -> [Slideshow] {
    try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
    //                                                         ^^^^^^
    //                    self（SlideshowRepository）を明示的にキャプチャ
}
```

---

### 7. トレイリングクロージャ構文 — 関数の最後の引数がクロージャの場合

#### 定義

Swift では、関数の**最後の引数がクロージャ**の場合、`()` の外にクロージャを書ける「トレイリングクロージャ構文」が使えます。

```swift
// 通常の呼び出し（ラベルあり）
store.fetch(FetchDescriptor<SlideshowModel>(), transform: { [self] in slideshow(from: $0) })

// トレイリングクロージャ構文（最後の引数を () の外に書く）
store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
```

#### なぜここで使われているか

クロージャが長くなるとき、`()` の外に書くとコードの構造が読みやすくなります。

```swift
// store.write のトレイリングクロージャ（複数行）
try await store.write { context in
    // ... 複数行のコード ...
    try context.save()
}
// ↑ { } が "store.write の引数" であることを示しつつ、インデントも自然
```

#### もしトレイリングクロージャ構文を使わなかったら

```swift
// ❌ 引数ラベルあり（ネストが深くなると読みにくい）
try await store.write(body: { context in
    // ...
    try context.save()
})
```

#### 該当コード

```swift
// 1 行で収まる場合
try await store.fetch(FetchDescriptor<SlideshowModel>()) { [self] in slideshow(from: $0) }
//                                                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//                                                      () の外にクロージャを書いている

// 複数行にまたがる場合
try await store.write { context in
    // ...
}
```

---

### 8. `.map { }`, `.sorted { }`, `.first` — コレクション操作

#### 定義

Swift の配列（`Array`）には、要素を変換・絞り込み・集計するための便利なメソッドが標準で用意されています。

| メソッド | 意味 |
|---|---|
| `.map { }` | 各要素を変換して新しい配列を作る |
| `.sorted { }` | 条件に従って並べ替えた新しい配列を作る |
| `.first` | 最初の要素を返す（なければ `nil`） |
| `.forEach { }` | 各要素に対して処理を実行する（戻り値なし） |

#### なぜここで使われているか

**`.map { }`** — `Slide`（エンティティ）を `SlideModel`（SwiftData モデル）に変換、またはその逆の変換をするとき。

```swift
// Slide エンティティ → SlideModel へ変換（save 時）
let newSlides = slides.map {
    SlideModel(id: $0.id, localIdentifier: $0.localIdentifier, ...)
}

// SlideModel → Slide エンティティへ変換（slideshow(from:) 内）
.map { Slide(id: $0.id, localIdentifier: $0.localIdentifier, ...) }
```

**`.sorted { }`** — スライドを `order` 順（表示順）で並べ替えるとき。データベースは取り出し順を保証しないため、明示的に並べます。

```swift
model.slides.sorted { $0.order < $1.order }
//           ^^^^^^^ order が小さい順（昇順）に並べ替え
```

**`.first`** — `FetchDescriptor` の結果から最初の 1 件だけ取得するとき。`fetch` の戻り値は配列なので、`.first` で Optional（`nil` の可能性あり）の単一要素を取り出します。

```swift
try await store.fetch(...) { ... }.first
//                               ^^^^^^ 配列の先頭要素。見つからなければ nil
```

#### もし `.map { }` を使わなかったら

```swift
// ❌ for ループで手動変換
var newSlides: [SlideModel] = []
for slide in slides {
    let model = SlideModel(id: slide.id, localIdentifier: slide.localIdentifier, ...)
    newSlides.append(model)
}
// 動作は同じだが、「配列を別の型の配列に変換する」意図が .map より読み取りにくい
```

#### 該当コード

```swift
// slideshow(from:) 内 — .sorted と .map をチェーン
let slides = model.slides
    .sorted { $0.order < $1.order }   // 1. order 順に並べ替え
    .map { Slide(id: $0.id, ...) }    // 2. SlideModel → Slide エンティティへ変換

// fetch(id:) — .first で Optional の 1 件を取得
} { [self] in slideshow(from: $0) }.first

// save 内 — .forEach で各要素に対して insert/delete
existing.slides.forEach { context.delete($0) }
newSlides.forEach { context.insert($0) }
```

---

### 9. `context.insert()`, `context.delete()`, `context.save()` — SwiftData の CRUD

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
    // 既存レコードがあれば更新、なければ新規作成（Upsert パターン）
    if let existing = try context.fetch(descriptor).first {
        existing.name = name          // 1. プロパティを更新
        existing.slides.forEach { context.delete($0) }   // 2. 古いスライドを削除
        newSlides.forEach { context.insert($0) }         // 3. 新しいスライドを追加
        existing.slides = newSlides
    } else {
        let model = SlideshowModel(...)
        context.insert(model)         // 1. 新規レコードを追加
        newSlides.forEach { context.insert($0) }
        model.slides = newSlides
    }
    try context.save()               // ← ここで初めてディスクに書き込む
}
```

#### もし `save()` を呼ばなかったら

```swift
// ❌ save() を忘れると変更がディスクに反映されない
try await store.write { context in
    context.insert(model)
    // try context.save() ← 忘れた！
    // アプリを再起動するとデータが消える
}
```

#### 該当コード

```swift
try await store.write { context in
    // ...
    existing.slides.forEach { context.delete($0) }  // 古いスライドを削除
    newSlides.forEach { context.insert($0) }         // 新しいスライドを追加
    // ...
    try context.save()  // ← 変更をディスクに確定。エラーなら throw
}
```

---

### 10. `save()` 前の変数コピー — クロージャへの安全な値の渡し方

#### 定義

`store.write { context in ... }` のクロージャは **SwiftData のアクター境界を越えて実行**されます。Swift 6 では、アクター境界を越えるクロージャは `Sendable` でなければならず、クロージャ内で `self` のプロパティを直接参照するとコンパイルエラーになる場合があります。

そのため `save()` メソッドの冒頭で、必要な値をすべてローカル変数にコピーしています。

```swift
func save(_ slideshow: Slideshow) async throws {
    // クロージャに渡す前に値をコピー
    let id = slideshow.id
    let name = slideshow.name
    let createdAt = slideshow.createdAt
    let durationRawValue = slideshow.config.duration.rawValue
    let transitionRawValue = slideshow.config.transition.rawValue
    let loop = slideshow.config.loop
    let slides = slideshow.slides    // ← ここまでがコピー

    try await store.write { context in
        // クロージャ内では self ではなくコピーした値を使う
        let descriptor = FetchDescriptor<SlideshowModel>(predicate: #Predicate { $0.id == id })
        // ...
    }
}
```

#### なぜここで使われているか

`Slideshow` は `Sendable` に準拠しているので、クロージャに直接渡せます。しかし SwiftData のアクター境界では、`self`（`SlideshowRepository`）を通じたアクセスよりも「生の値」を渡した方が安全かつシンプルです。特に `#Predicate` マクロは変数をキャプチャするため、`Sendable` な値型を渡すのが確実です。

#### もしコピーせずに `self.slideshow` を直接使おうとしたら

```swift
// ❌ クロージャ内で self を使おうとする
try await store.write { context in
    // #Predicate は self.slideshow.id をキャプチャできない場合がある
    let descriptor = FetchDescriptor<SlideshowModel>(
        predicate: #Predicate { $0.id == self.slideshow.id }  // コンパイルエラーの可能性
    )
}
```

#### 該当コード

```swift
func save(_ slideshow: Slideshow) async throws {
    let id = slideshow.id                            // ← 値型（UUID）をコピー
    let name = slideshow.name                        // ← 値型（String）をコピー
    let durationRawValue = slideshow.config.duration.rawValue   // ← 値型をコピー
    // ... 全プロパティをコピー

    try await store.write { context in
        // クロージャ内では全てコピーした値型を使用
        #Predicate { $0.id == id }                   // ← コピーした id を使用
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
| `.map { }` | 型変換。`SlideModel` ↔ `Slide` の変換に使用 |
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

1. **上位層はエンティティしか知らない** — `SlideshowModel`（SwiftData の内部型）は Repository の外に一切出さない
2. **変換はすべて Repository の中** — `@Model ↔ Entity` の変換ロジックを一箇所に集約する
3. **実装はプロトコルで隠す** — 呼び出し側は `SlideshowRepositoryProtocol` を通じてのみ操作し、SwiftData の詳細を知らなくていい

### アーキテクチャ上の位置づけ

```
Presentation
    ↓
UseCases  ← "スライドショーを保存して" と Repository プロトコルに依頼
    ↓
Domain/Services
    ↓
Repositories  ← ← ← ← ここが SlideshowRepository の場所
    ↓
Infrastructure（SwiftData の ModelContext）
```

Repository 層は「上への約束（エンティティを返す）」と「下への依頼（SwiftData で保存する）」の橋渡し役です。
