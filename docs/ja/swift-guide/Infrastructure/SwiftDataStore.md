# SwiftDataStore を読み解く

**ソースファイル**: `Sources/Infrastructure/SwiftData/SwiftDataStore.swift`

## このファイルは何をしているのか

`SwiftDataStore` は、アプリのデータをディスクに保存・取得・削除する「窓口」です。  
SwiftData というAppleのフレームワークを使い、複数のスレッドから安全に呼び出せるように設計されています。

```swift
import Foundation
import SwiftData

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

全部で22行のシンプルなファイルですが、Swiftの重要な概念が凝縮されています。順番に読み解いていきましょう。

---

## 1. `actor` — スレッド安全な「番人」

### 定義

`actor` は Swift 5.5 で導入されたキーワードで、`class` に似た参照型ですが、**同時に複数の処理が内部状態を書き換えられないよう自動的に守ってくれる**特別な型です。

### なぜここで使われているか

アプリは複数の処理（UIの描画、ネットワーク通信、データ保存など）を並行して実行しています。もし2つの処理が同時にデータベースを書き換えようとしたら、データが壊れてしまう可能性があります。`actor` はその窓口を「一度に一人しか通れない改札口」にしてくれます。

### もし使わなかったら

```swift
// NG: 普通のクラスでは複数スレッドが同時にアクセスすると破綻する
final class SwiftDataStore {
    var count = 0
    func increment() { count += 1 }  // 2つのスレッドが同時に呼ぶとカウントが壊れる
}
```

`class` では開発者が自分でロックの管理をしなければならず、ミスが起きやすいです。`actor` はコンパイラが自動で排他制御を保証してくれます。

```swift
// OK: actor にするだけで Swift コンパイラが安全性を保証する
actor SwiftDataStore { ... }
```

---

## 2. `@ModelActor` — SwiftData 専用のマクロ

### 定義

`@ModelActor` は SwiftData が提供する**マクロ**（コードを自動生成する仕組み）です。`actor` に付けると、SwiftData が必要とする初期化コード (`init(modelContainer:)`) と、データ操作の舞台となる `modelContext` プロパティを自動生成してくれます。

### なぜここで使われているか

SwiftData の `ModelContext`（後述）はスレッドに紐付いています。`@ModelActor` を使うと、そのアクターのスレッドに `ModelContext` を固定し、安全に使えるようになります。

### もし使わなかったら

```swift
// NG: Mutex で ModelContext を包んでも SwiftData はスレッド安全にならない
final class SwiftDataStore {
    private let context: Mutex<ModelContext>  // これは誤ったアプローチ
}
```

`ModelContext` は「1スレッドにつき1つ」という制約があるため、`Mutex` で囲んでも解決になりません。`@ModelActor` がそのアクターのスレッドに固定することで初めて安全になります。

```swift
// OK: @ModelActor が modelContext の生成・固定を自動化してくれる
@ModelActor
actor SwiftDataStore: SwiftDataStoreProtocol { ... }
```

---

## 3. ジェネリクス `<T: PersistentModel, R: Sendable>` — 型を「変数」にする

### 定義

`<T: PersistentModel, R: Sendable>` は**ジェネリクス（総称型）**の宣言です。`T` や `R` は「型の変数」で、呼び出し元が具体的な型を決めます。

- `T` は「何らかの PersistentModel（SwiftData で管理されるモデル型）」
- `R` は「何らかの Sendable な型（スレッド間で安全に渡せる型）」

### なぜここで使われているか

`fetch` 関数は「スライドを取得する」「設定を取得する」など、さまざまなモデルで使われます。ジェネリクスを使えば、型ごとに関数を書き直す必要がなくなります。

```swift
func fetch<T: PersistentModel, R: Sendable>(
    _ descriptor: FetchDescriptor<T>,
    transform: @Sendable (T) throws -> R
) throws -> [R]
```

### もし使わなかったら

```swift
// NG: 型ごとに関数を書かなければならない（コードの重複）
func fetchSlides(_ descriptor: FetchDescriptor<SlideModel>) throws -> [Slide] { ... }
func fetchConfigs(_ descriptor: FetchDescriptor<ConfigModel>) throws -> [Config] { ... }
// モデルが増えるたびに関数が増え続ける…
```

ジェネリクスを使えば1つの `fetch` 関数で全モデルに対応できます。

---

## 4. `where` 句 — ジェネリクスへの追加条件

### 定義

`where` 句はジェネリクスに**追加の制約**を付けるための構文です。

### このファイルでの使われ方

`delete` 関数をよく見てください。

```swift
func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws
```

ここでは引数ラベルに `where` が使われていますが、ジェネリクスの制約としての `where` 句の例も補足します。Swift では次のような書き方ができます。

```swift
// ジェネリクスの where 句の例（制約を後置きで書く）
func process<T>(_ items: [T]) where T: Equatable & Hashable {
    // T は Equatable かつ Hashable でなければならない
}
```

`<T: PersistentModel>` と `where T: PersistentModel` は同じ意味ですが、複数の条件を組み合わせるときに `where` 句が便利です。

---

## 5. `Predicate<T>` — 型安全な「絞り込み条件」

### 定義

`Predicate<T>` は SwiftData（および Swift 標準ライブラリ）が提供する、**コンパイル時に型チェックされる絞り込み条件**です。「〇〇のフィールドが××の値のものだけ」という条件をSwiftのコードで書けます。

### なぜここで使われているか

```swift
func delete<T: PersistentModel>(_ type: T.Type, where predicate: Predicate<T>) throws
```

`Predicate<T>` を使うことで、型が一致しない条件式はコンパイルエラーになります。たとえば `SlideModel` 用の述語を `ConfigModel` の削除に渡すことができません。

### もし使わなかったら

```swift
// NG: 文字列でクエリを書く古典的な方法
func deleteWhere(sql: String) throws { ... }
// 呼び出し元: deleteWhere(sql: "slideName = 'vacation'")
// → タイポや型の不一致がランタイム（実行時）まで気づけない
```

`Predicate<T>` ならコンパイラがチェックしてくれるため、実行前にバグを発見できます。

---

## 6. `@Sendable` クロージャ — 並行処理で安全なクロージャ

### 定義

`@Sendable` は、そのクロージャが**複数のスレッド間で安全に渡せる**ことを示す属性です。`Sendable` に準拠するとは「値をコピーしてどのスレッドに渡しても壊れない」ことを意味します。

### なぜここで使われているか

```swift
func fetch<T: PersistentModel, R: Sendable>(
    _ descriptor: FetchDescriptor<T>,
    transform: @Sendable (T) throws -> R   // ← @Sendable
) throws -> [R]
```

`fetch` は `actor` のメソッドなので、呼び出し元とは別のスレッド（アクターのスレッド）で実行されます。`transform` クロージャもそのスレッドで実行されるため、`@Sendable` が必要です。`@Sendable` でないクロージャが外部の変数を不安全にキャプチャしようとするとコンパイルエラーになります。

```swift
func write(_ work: @Sendable (ModelContext) throws -> Void) throws
```

`write` も同様です。`work` クロージャはアクターのスレッドで実行されるので `@Sendable` が必要です。

### もし使わなかったら

```swift
// NG: @Sendable なしだとコンパイラが警告・エラーを出す
func fetch<T: PersistentModel, R: Sendable>(
    _ descriptor: FetchDescriptor<T>,
    transform: (T) throws -> R   // @Sendable なし
) throws -> [R]
// → Sendable でないクロージャをアクター境界を越えて渡せないとエラーになる
```

---

## 7. `ModelContext` — SwiftData のデータ操作の「作業台」

### 定義

`ModelContext` は SwiftData でデータの読み書きを行う際の「作業台」です。データを取得・挿入・削除・保存するすべての操作はここを経由します。

### なぜここで使われているか

`@ModelActor` マクロが `modelContext` プロパティを自動生成してくれるので、`SwiftDataStore` のメソッド内でそのまま使えます。

```swift
func fetch<T: PersistentModel, R: Sendable>(...) throws -> [R] {
    try modelContext.fetch(descriptor).map(transform)  // ← modelContext を使ってデータ取得
}

func delete<T: PersistentModel>(...) throws {
    try modelContext.delete(model: type, where: predicate)  // 削除
    try modelContext.save()  // 保存（忘れると変更がディスクに書き込まれない）
}

func write(_ work: @Sendable (ModelContext) throws -> Void) throws {
    try work(modelContext)  // ModelContext を外部に渡して柔軟な書き込みを許可
}
```

`delete` 後の `modelContext.save()` は重要です。SwiftData は変更を「保留」として持ち、`save()` を呼んで初めてディスクに確定します。

### もし使わなかったら

SwiftData なしでデータを永続化しようとすると、自分でファイルの読み書きやSQLの管理を行う必要があり、非常に複雑になります。`ModelContext` はその複雑さを隠蔽してくれる抽象化レイヤーです。

---

## 8. `throws` — エラーを呼び出し元に伝える

### 定義

`throws` はその関数が**エラーを投げる可能性がある**ことを示します。`throws` 付きの関数を呼ぶには `try` キーワードが必要です。

### なぜここで使われているか

データベースの操作は失敗することがあります（ディスクがいっぱい、データが壊れているなど）。`throws` を使うと、エラーが起きたことを呼び出し元に確実に伝えられます。

```swift
func fetch<T: PersistentModel, R: Sendable>(...) throws -> [R] {
    try modelContext.fetch(descriptor).map(transform)
    // ↑ fetch が失敗したら Error が投げられ、この関数も自動的に throws する
}
```

### もし使わなかったら

```swift
// NG: エラーを無視して nil や空配列を返すと、呼び出し元が失敗を検知できない
func fetch(...) -> [R]? {
    return try? modelContext.fetch(descriptor).map(transform)
    // 失敗してもただ nil が返るだけ — なぜ失敗したか分からない
}
```

`throws` + `try` の組み合わせはエラーを**明示的に**扱うことを強制します。

---

## 9. 実践で学んだ落とし穴

SwiftData と Photos フレームワークを使った開発で実際に遭遇した問題を紹介します。どれも「コンパイルは通るのに実行時に壊れる」タイプのバグなので、事前に知っておくことが重要です。

---

### 落とし穴 1: SwiftData の親子挿入順序

#### 何が起きるか

`@ModelActor` の中で、親モデルの `@Relationship` プロパティに子モデルを代入してから `modelContext.insert()` すると、**子モデルがデータベースに保存されません**。`modelContext.save()` はエラーを投げず成功するのに、後で取得すると子のリレーションシップが空になっています。

このプロジェクトでは、ライブラリから読み込んだスライドショーの画像が全く表示されないバグとして発覚しました。新規作成したスライドショーは正常に動いていたため、発見が遅れました。

#### 正しい書き方

```swift
// ✅ 親を insert → 子を insert → リレーションシップを設定 → save
let model = SlideshowModel(...)
modelContext.insert(model)                          // 1. 親を先にコンテキストに登録
let slideModels = dto.slides.map { SlideModel(...) }
slideModels.forEach { modelContext.insert($0) }     // 2. 子も個別にコンテキストに登録
model.slides = slideModels                          // 3. 両方がコンテキストに入った状態で関連付け
try modelContext.save()                             // 4. 保存
```

#### やってはいけない書き方

```swift
// ❌ 子がコンテキストに入る前にリレーションシップを設定 — 子が消失する
let model = SlideshowModel(...)
model.slides = dto.slides.map { SlideModel(...) }   // 子はまだコンテキスト未登録！
modelContext.insert(model)                           // 親だけ登録される
try modelContext.save()
// → save() は成功するが、後で取得すると model.slides == []
```

**ポイント**: `save()` がエラーなく成功しても、リレーションシップが正しく保存されたとは限りません。「親を insert → 子を insert → 関連付け」の順序を必ず守りましょう。

---

### 落とし穴 2: リレーションシップ再代入時の孤児レコード

#### 何が起きるか

`@Relationship` の配列プロパティに新しい子オブジェクトの配列を代入すると、**古い子オブジェクトがデータベースに残り続けます**。`deleteRule: .cascade` は親モデル自体が削除されたときにしか発動せず、配列の上書きでは機能しません。

更新を繰り返すたびにデータベースに孤児レコードが蓄積し、ストレージを圧迫します。

#### 正しい書き方

```swift
// ✅ 古い子を明示的に削除してから、新しい子を挿入・関連付け
func save(_ dto: SlideshowDTO) throws {
    let id = dto.id
    let descriptor = FetchDescriptor<SlideshowModel>(
        predicate: #Predicate { $0.id == id }
    )
    if let existing = try modelContext.fetch(descriptor).first {
        existing.slides.forEach { modelContext.delete($0) }     // 古い子を削除
        let newSlides = makeSlideModels(from: dto.slides)
        newSlides.forEach { modelContext.insert($0) }           // 新しい子を挿入
        existing.slides = newSlides                              // 関連付け
    } else {
        // 新規作成パス
    }
    try modelContext.save()
}
```

#### やってはいけない書き方

```swift
// ❌ 配列をそのまま上書き — 古い子レコードが孤児として残る
existing.slides = newSlides
try modelContext.save()
// → 古い SlideModel が DB に残り続け、ストレージが肥大化する
```

**ポイント**: `deleteRule: .cascade` はあくまで「親が消えたとき」に子を道連れにする機能です。「子の入れ替え」は開発者が明示的に古い子を `delete()` する必要があります。

---

### 落とし穴 3: PHImageManager の deliveryMode に `.opportunistic` を使わない

#### 何が起きるか

`PHImageManager` を Swift Concurrency の `withCheckedThrowingContinuation` でラップするとき、`deliveryMode = .opportunistic` を使うと**コールバックが2回呼ばれます**（1回目は低品質プレビュー、2回目が本画像）。`continuation.resume()` が2回実行されるため、Swift ランタイムがクラッシュを引き起こします。

かといって、1回目のコールバックを `if isDegraded { return }` でスキップすると、2回目が失敗した場合に `resume()` が永久に呼ばれず、タスクがハングしてメモリリークします。

#### 正しい書き方

```swift
// ✅ .highQualityFormat を使えばコールバックは必ず1回だけ
let options = PHImageRequestOptions()
options.deliveryMode = .highQualityFormat  // 1回だけコールバックが呼ばれることが保証される

let data: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(
        for: asset, options: options
    ) { data, _, _, _ in
        if let data {
            continuation.resume(returning: data)
        } else {
            continuation.resume(throwing: ImageDataSourceError.dataUnavailable)
        }
    }
}
```

#### やってはいけない書き方

```swift
// ❌ .opportunistic はコールバックが2回来る → continuation が2回 resume されてクラッシュ
let options = PHImageRequestOptions()
options.deliveryMode = .opportunistic

let data: Data = try await withCheckedThrowingContinuation { continuation in
    PHImageManager.default().requestImageDataAndOrientation(
        for: asset, options: options
    ) { data, _, _, _ in
        if let data {
            continuation.resume(returning: data)  // 2回目でクラッシュ！
        }
    }
}
```

**ポイント**: `withCheckedThrowingContinuation` は `resume()` が**正確に1回**呼ばれることを前提としています。コールバックが複数回呼ばれる API をラップするときは、1回だけ呼ばれるオプションを選ぶか、`AsyncStream` を使いましょう。

---

## このファイルで学べること まとめ

| 概念 | 一言まとめ |
|------|-----------|
| `actor` | 複数スレッドからの同時アクセスを防ぐ「番人」型 |
| `@ModelActor` | SwiftData 用の初期化と `modelContext` を自動生成するマクロ |
| ジェネリクス `<T, R>` | 型を「変数」にして再利用性を高める仕組み |
| 型制約 `: PersistentModel` | ジェネリクス型に条件をつける書き方 |
| `Predicate<T>` | コンパイル時に型チェックされる絞り込み条件 |
| `@Sendable` | スレッド間で安全に渡せることをコンパイラが保証するクロージャ属性 |
| `ModelContext` | SwiftData の読み書きをすべて担う「作業台」 |
| `throws` | 関数のエラーを呼び出し元に伝える仕組み |

このファイルはたった22行ですが、「スレッド安全性」「型の汎用化」「エラー伝播」という現代のSwiftプログラミングの核心が詰まっています。これらの概念を押さえると、Swiftで書かれたデータ永続化コードの多くが読めるようになります。
