# Domain エンティティのパターンと Swift 基礎概念

> 対象: Swift を学び始めたばかりの人。コードを読んで「なぜこう書くのか？」が分からない人。

---

## 対象ソースファイルと概要

| ファイル | 型の種類 | 役割 |
|---|---|---|
| `Sources/Domain/Entities/Slide.swift` | Entity（エンティティ） | スライドショーを構成する 1 枚のスライドを表す |
| `Sources/Domain/Entities/Slideshow.swift` | Entity（エンティティ） | スライドの集合＋設定を持つスライドショー全体を表す |
| `Sources/Domain/Entities/SlideshowConfig.swift` | Value Object（値オブジェクト） | スライドショーの再生設定（秒数・切り替え・ループ）を表す |
| `Sources/Domain/Entities/TransitionType.swift` | Enum Variant Set（列挙バリアントセット） | スライド切り替えアニメーションの種類を表す |

これらのファイルは **Domain 層** に属します。Domain 層はアプリのビジネスルールを純粋な Swift 型として表現する場所です。UI も I/O も依存しない、いわば「アプリの心臓部」です。

---

## ソースコード全文（参照用）

### Slide.swift

```swift
import Foundation

struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String
    var order: Int
    var duration: TimeInterval
    var title: String?
}
```

### Slideshow.swift

```swift
import Foundation

struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig
    var createdAt: Date

    static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
        Slideshow(
            id: UUID(),
            name: name,
            slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
            config: config,
            createdAt: Date()
        )
    }

    func applying(config: SlideshowConfig) -> Slideshow {
        var updated = self
        updated.config = config
        return updated
    }

    func updating(name: String, localIdentifiers: [String]) -> Slideshow {
        var updated = self
        updated.name = name
        updated.slides = Slideshow.makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0)
        return updated
    }

    private static func makeSlides(from localIdentifiers: [String], duration: TimeInterval) -> [Slide] {
        localIdentifiers.enumerated().map { index, id in
            Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
        }
    }
}
```

### SlideshowConfig.swift

```swift
import Foundation

struct SlideshowConfig: Equatable, Sendable, Codable {
    var duration: SlideDuration
    var transition: TransitionType
    var loop: Bool

    static let `default` = SlideshowConfig(
        duration: .five,
        transition: .fade,
        loop: true
    )
}
```

### TransitionType.swift

```swift
import Foundation

enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve

    static let `default` = TransitionType.fade
}
```

---

## 概念ごとの解説

---

### 1. `struct` vs `class` — 値型と参照型

#### 定義

Swift には型を定義する方法が 2 つあります。

- **`struct`（構造体）**: 「値型」。変数に代入したりメソッドに渡したりすると、**コピー**が作られる。
- **`class`（クラス）**: 「参照型」。変数に代入しても同じ実体を**参照**するだけ。コピーは作られない。

#### なぜここで使われているか

`Slide`・`Slideshow`・`SlideshowConfig` はすべて `struct` で定義されています。Domain 層のエンティティを `struct` にする理由は 3 つあります。

1. **予測しやすい**: コピーが作られるので、「どこかで変更したら別の場所にも影響する」という事故が起きない。
2. **スレッド安全**: `struct` の値は共有されないので、複数のスレッドが同時に触っても安全（後述の `Sendable` と連動）。
3. **テストしやすい**: 状態が外部から変わらないため、動作が純粋に入出力で決まる。

#### もし `class` を使ったら

```swift
// ❌ class だと参照を共有してしまう
class SlideClass {
    var order: Int
    init(order: Int) { self.order = order }
}

let a = SlideClass(order: 0)
let b = a          // コピーではなく、a と同じ実体を指す
b.order = 99
print(a.order)     // 99 ← a まで変わってしまった！
```

```swift
// ✅ struct ならコピーされる
struct SlideStruct {
    var order: Int
}

let a = SlideStruct(order: 0)
var b = a          // 独立したコピーが作られる
b.order = 99
print(a.order)     // 0 ← a は影響を受けない
```

#### 該当コード

```swift
struct Slide: Identifiable, Equatable, Sendable { ... }
struct Slideshow: Identifiable, Equatable, Sendable { ... }
struct SlideshowConfig: Equatable, Sendable, Codable { ... }
```

---

### 2. `Identifiable` — 一意な識別子を持つ型

#### 定義

`Identifiable` は Apple 標準のプロトコルで、「このオブジェクトには `id` というプロパティがある」ことを宣言します。

```swift
// Apple の標準ライブラリの定義（イメージ）
protocol Identifiable {
    associatedtype ID: Hashable
    var id: ID { get }
}
```

#### なぜここで使われているか

`Slide` と `Slideshow` は `Identifiable` に準拠しています。これにより：

- SwiftUI の `List` や `ForEach` に直接渡せる（`id:` パラメータを省略できる）
- 「このスライドはあのスライドと同じか？」を `id` で判断できる

#### もし `Identifiable` を使わなかったら

```swift
// Identifiable なし
ForEach(slides, id: \.localIdentifier) { slide in ... }  // 毎回 id キーパスを書く必要がある

// Identifiable あり ✅
ForEach(slides) { slide in ... }  // id が自明なので省略できる
```

#### 該当コード

```swift
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID   // ← Identifiable が要求する id プロパティ
    ...
}
```

---

### 3. `Equatable` — 等値比較

#### 定義

`Equatable` は「`==` で比較できる」ことを宣言するプロトコルです。準拠すると `a == b` と書けるようになります。

`struct` のすべてのプロパティが `Equatable` であれば、Swift コンパイラが `==` の実装を**自動生成**してくれます。

#### なぜここで使われているか

- **テスト**: 「期待する `Slide` と実際の `Slide` が等しいか」を `XCTAssertEqual` で確かめられる。
- **差分検出**: 「設定が変わったか？」を `oldConfig == newConfig` で簡単に確認できる。
- **SwiftUI の最適化**: ViewModel が `Equatable` な値を持つと、変化のない部分のビューを再描画しない最適化が効く。

#### もし `Equatable` を使わなかったら

```swift
// ❌ Equatable なし
// let a: Slide = ...
// let b: Slide = ...
// if a == b { ... }  // コンパイルエラー: 比較できない

// 自前で比較ロジックを書く必要がある（面倒で漏れが生まれやすい）
func isEqual(_ a: Slide, _ b: Slide) -> Bool {
    a.id == b.id &&
    a.localIdentifier == b.localIdentifier &&
    a.order == b.order
    // ... プロパティが増えるたびに追加しなければいけない
}
```

#### 該当コード

```swift
struct Slide: Identifiable, Equatable, Sendable { ... }
//                          ^^^^^^^^^ コンパイラが == を自動生成
```

---

### 4. `Sendable` — スレッド安全性

#### 定義

`Sendable` は「この型の値を、異なるスレッド（アクター）間で安全に渡せる」ことを宣言するプロトコルです。Swift 6 以降では、スレッド間で渡す型が `Sendable` でない場合にコンパイルエラーになります。

#### なぜここで使われているか

現代の Swift アプリは非同期処理を多用します。たとえば「写真ライブラリから画像を取得しながら UI を更新する」場合、バックグラウンドスレッドとメインスレッドの間で `Slide` を渡します。`Sendable` を宣言することで「安全に渡せる」とコンパイラに伝えます。

`struct` のすべてのプロパティが `Sendable` であれば、コンパイラが自動的に安全性を検証してくれます。

#### もし `Sendable` を付けなかったら

```swift
// ❌ Sendable なし → Swift 6 の async コンテキストでコンパイルエラーになる可能性がある
func fetchSlides() async -> [Slide] { ... }
// "Sending 'result' risks causing data races" などのエラー
```

#### 該当コード

```swift
struct Slide: Identifiable, Equatable, Sendable { ... }
//                                     ^^^^^^^^ スレッド間転送が安全
```

---

### 5. `let` vs `var` — 不変と可変のフィールド

#### 定義

- **`let`**: 一度値を設定したら変更できない（定数）
- **`var`**: あとから値を変更できる（変数）

#### なぜここで使われているか

`Slide` のフィールドをよく見ると、使い分けに意図があります：

```swift
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID           // ← let: ID は作成後に絶対変わらない
    let localIdentifier: String  // ← let: 元の写真への参照も変わらない
    var order: Int         // ← var: スライドの並び順は変更される
    var duration: TimeInterval   // ← var: 表示時間はあとで調整できる
    var title: String?     // ← var: タイトルはあとで付けることができる
}
```

`id` を `var` にしてしまうと「同じスライドに別の ID を付ける」操作が可能になり、アイデンティティの意味が崩れます。`let` にすることでコンパイラが誤った変更を防いでくれます。

#### もし全部 `var` にしたら

```swift
// ❌ id を var にすると
var slide = Slide(id: UUID(), localIdentifier: "abc", order: 0, duration: 5, title: nil)
slide.id = UUID()  // ID を書き換えられてしまう！ データの一貫性が壊れる
```

#### 該当コード

```swift
let id: UUID                 // 変更不可 — エンティティの同一性を保証
let localIdentifier: String  // 変更不可 — 元写真への参照を保証
var order: Int               // 変更可能 — 並び順は編集できる
```

---

### 6. `UUID` — 一意な識別子

#### 定義

`UUID`（Universally Unique Identifier）は、世界中で重複しない 128 bit のランダムな値です。`Foundation` フレームワークに含まれており、`UUID()` と書くだけで新しい ID を生成できます。

例: `550e8400-e29b-41d4-a716-446655440000`

#### なぜここで使われているか

スライドやスライドショーを区別するには「唯一の番号」が必要です。UUID を使う理由：

- **衝突しない**: 連番（1, 2, 3…）と違い、複数デバイスで同時に生成しても同じ値になる確率が事実上ゼロ
- **推測されない**: 1, 2, 3… のような連番は予測できてしまうが、UUID はランダム
- **外部システムと相性がいい**: データベースやネットワーク越しに交換する際に番号の衝突を気にしなくてよい

#### もし連番を使ったら

```swift
// ❌ 連番だと複数箇所で同時に作ると衝突する
var nextId = 0
let slide1 = Slide(id: nextId, ...)  // id: 0
nextId += 1
let slide2 = Slide(id: nextId, ...)  // id: 1
// 別スレッドで同じカウンタを操作するとデータ競合が発生する
```

#### 該当コード

```swift
let id: UUID
// ...
Slideshow(id: UUID(), ...)  // UUID() で毎回新しい一意な ID を生成
```

---

### 7. `Optional` (`?`) — 値があるかもしれない型

#### 定義

`Optional` は「値がある場合と、値がない（`nil`）場合の両方を表せる型」です。`String?` は「String か nil のどちらか」を意味します。

#### なぜここで使われているか

`title: String?` は「スライドにタイトルが付いていない場合もある」ことを表しています。写真を追加した直後はタイトルがない状態が自然です。

Optional を使うことで、コンパイラが「nilの可能性を考慮したか？」を強制チェックしてくれます。

#### もし Optional を使わなかったら

```swift
// ❌ Optional なしで「タイトルなし」を表現しようとする
var title: String = ""   // 空文字 = タイトルなし？ でも空文字のタイトルなのか、未設定なのか区別できない
var title: String = "（なし）"  // 表示用文字列を入れる？ ドメイン層にUI知識が混入する

// ✅ Optional なら意味が明確
var title: String?  // nil = タイトル未設定、"Hello" = タイトルあり
```

使う側では次のようにアンラップします：

```swift
// if let による安全なアンラップ
if let title = slide.title {
    print("タイトル: \(title)")
} else {
    print("タイトルなし")
}

// ?? によるデフォルト値
let displayTitle = slide.title ?? "無題"
```

#### 該当コード

```swift
var title: String?   // ← タイトルがない状態を nil で表現
```

---

### 8. `enum` と `rawValue` — 列挙型と原始値

#### 定義

`enum`（列挙型）は「決まった選択肢の中から 1 つを選ぶ」型です。`rawValue` を持つ `enum` は、各ケースに文字列や数値を対応付けられます。

#### なぜここで使われているか

`TransitionType` はスライドの切り替えアニメーション種類を表します。`String` の `rawValue` を付けることで：

1. コード中では `case fade` のように読みやすい名前で扱える
2. 保存や通信では `"fade"` という文字列として扱える（`Codable` と組み合わせることで自動変換）

```swift
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none      // rawValue = "none"
    case fade      // rawValue = "fade"
    case slide     // rawValue = "slide"
    case dissolve  // rawValue = "dissolve"
}
```

#### もし `String` で管理したら

```swift
// ❌ String だと誤入力をコンパイラが検出できない
var transition: String = "fde"   // タイポに気づかない
var transition: String = "zoom"  // 未定義の値を渡せてしまう

// ✅ enum なら存在するケースしか代入できない
var transition: TransitionType = .fade  // コンパイラが補完・検証してくれる
```

#### 該当コード

```swift
enum TransitionType: String, ... {
    case none
    case fade      // TransitionType.fade.rawValue == "fade"
    case slide
    case dissolve
}
```

---

### 9. `CaseIterable` — 全ケースの列挙

#### 定義

`CaseIterable` に準拠した `enum` は、`TransitionType.allCases` というプロパティが自動生成され、すべてのケースを配列として取得できます。

#### なぜここで使われているか

UI のピッカー（選択コントロール）でアニメーション種類の一覧を表示する場合、`allCases` を使って全選択肢を動的に取得できます。新しいケースを追加しても、UI 側のコードを変更する必要がありません。

```swift
// allCases を使ったピッカーの例（Presentation 層での利用イメージ）
ForEach(TransitionType.allCases, id: \.self) { type in
    Text(type.rawValue)
}
```

#### もし `CaseIterable` を使わなかったら

```swift
// ❌ 手動で配列を管理する
let allTransitions: [TransitionType] = [.none, .fade, .slide, .dissolve]
// ケースを追加するたびにこの配列も更新し忘れないよう気をつける必要がある
```

#### 該当コード

```swift
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
//                                                ^^^^^^^^^^^^
    case none
    case fade
    case slide
    case dissolve
}
// TransitionType.allCases → [.none, .fade, .slide, .dissolve]
```

---

### 10. `Codable` — エンコード/デコード

#### 定義

`Codable` は `Encodable & Decodable` の別名です。準拠すると、型を JSON などの外部形式に**変換（encode）**したり、外部形式から**復元（decode）**したりするコードをコンパイラが自動生成します。

#### なぜここで使われているか

`SlideshowConfig` と `TransitionType` は `Codable` に準拠しています。スライドショーの設定をディスクに保存したり、サーバーと通信したりする際に使われます。

```swift
let config = SlideshowConfig(duration: .five, transition: .fade, loop: true)

// エンコード: Swift 型 → JSON
let data = try JSONEncoder().encode(config)
// {"duration":"five","transition":"fade","loop":true}

// デコード: JSON → Swift 型
let restored = try JSONDecoder().decode(SlideshowConfig.self, from: data)
```

`TransitionType` が `String` を rawValue に持つため、JSON では `"fade"` という人間が読める文字列として保存されます。

#### もし `Codable` を使わなかったら

```swift
// ❌ 手動でエンコード/デコードを書く（数十行になる）
func encode() -> [String: Any] {
    return [
        "duration": duration.rawValue,
        "transition": transition.rawValue,
        "loop": loop
    ]
}
static func decode(from dict: [String: Any]) throws -> SlideshowConfig {
    guard let durationRaw = dict["duration"] as? String,
          let duration = SlideDuration(rawValue: durationRaw),
          ...
    else { throw DecodingError.dataCorrupted(...) }
    return SlideshowConfig(...)
}
```

#### 該当コード

```swift
struct SlideshowConfig: Equatable, Sendable, Codable { ... }
//                                           ^^^^^^^ 自動生成された encode/decode
```

---

### 11. `static let default` — 型のデフォルト値

#### 定義

`static let` は「インスタンスではなく型そのものに属する定数」です。`default` はバッククォート（`` ` ``）で囲まれていますが、これは `default` が Swift の予約語（`switch` 文の `default:` ラベル）だからです。

#### なぜここで使われているか

新しいスライドショーを作る際や、設定をリセットする際に使う「おすすめの初期値」を一箇所で定義します。

```swift
static let `default` = SlideshowConfig(
    duration: .five,       // 5 秒表示
    transition: .fade,     // フェードで切り替え
    loop: true             // ループ再生
)
```

呼び出し側では `SlideshowConfig.default` と書くだけで取得できます。

#### もし `static let default` を使わなかったら

```swift
// ❌ デフォルト値をあちこちに散らばせてしまう
// View でも UseCase でも毎回同じ値を書く → 一箇所変えたときに漏れが起きる
let config1 = SlideshowConfig(duration: .five, transition: .fade, loop: true)
let config2 = SlideshowConfig(duration: .five, transition: .fade, loop: true)  // 重複
```

#### 該当コード

```swift
static let `default` = SlideshowConfig(
    duration: .five,
    transition: .fade,
    loop: true
)
```

```swift
// TransitionType にも同様のパターン
static let `default` = TransitionType.fade
```

---

### 12. ファクトリメソッド `static func create(...)` — エンティティの生成パターン

#### 定義

ファクトリメソッドとは、「オブジェクトの生成ルールをカプセル化した静的メソッド」です。`Slideshow` は直接 `init` を呼ぶ代わりに `Slideshow.create(...)` を使って生成します。

#### なぜここで使われているか

`Slideshow` を作るには「ID の採番」「スライドリストの生成」「作成日時の設定」といった複数のステップが必要です。これをファクトリメソッドに閉じ込めることで：

1. 呼び出し側は複雑な初期化ロジックを知る必要がない
2. 生成ルールが変わっても、変更箇所は `create` メソッド内だけで済む
3. `id: UUID()` の採番が必ずここで行われるため、ID の二重管理が起きない

```swift
static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
    Slideshow(
        id: UUID(),                            // ID は必ずここで採番
        name: name,
        slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
        config: config,
        createdAt: Date()                      // 作成日時も必ずここで設定
    )
}
```

#### もしファクトリメソッドを使わなかったら

```swift
// ❌ 呼び出し側が毎回すべての初期化を担当する
let slideshow = Slideshow(
    id: UUID(),           // ← 呼び出し側で UUID() を書く必要がある
    name: name,
    slides: localIdentifiers.enumerated().map { index, id in
        Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
    },
    config: config,
    createdAt: Date()    // ← 作成日時も呼び出し側で書く
)
// この生成ロジックが UseCase や View など複数の場所に重複する
```

#### 該当コード

```swift
static func create(name: String, localIdentifiers: [String], config: SlideshowConfig) -> Slideshow {
    Slideshow(
        id: UUID(),
        name: name,
        slides: makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0),
        config: config,
        createdAt: Date()
    )
}
```

---

### 13. `func applying(...) -> Self` — イミュータブル更新パターン

#### 定義

「イミュータブル（immutable）更新パターン」とは、元のオブジェクトを変更せず、**変更を加えたコピーを新しく返す**手法です。`func applying(...) -> Slideshow` や `func updating(...) -> Slideshow` がこのパターンを実装しています。

#### なぜここで使われているか

`Slideshow` は `struct`（値型）なので、直接プロパティを書き換えることもできます。しかしこのパターンを使う利点があります：

1. **変更の意図が明確**: `slideshow.config = newConfig` より `slideshow.applying(config: newConfig)` の方が「更新して新しい値を得る」という意図が読みやすい
2. **元の値は安全**: `applying` を呼んでも元の `slideshow` 変数は変わらない
3. **連鎖できる**: 複数の変更を `.applying(...).updating(...)` と chain できる

内部の実装を見てみましょう：

```swift
func applying(config: SlideshowConfig) -> Slideshow {
    var updated = self         // 1. 自分のコピーを作る（struct なのでコピー）
    updated.config = config    // 2. コピーの設定を変更する
    return updated             // 3. 変更済みコピーを返す（元の self は変わらない）
}
```

#### もしこのパターンを使わなかったら

```swift
// ❌ 直接 mutate する（これ自体は動くが、意図が見えにくい）
var slideshow = Slideshow.create(...)
slideshow.config = newConfig   // どこで何が変わったか追跡しにくくなる

// ❌ UseCase 層が直接プロパティを書き換えると、
//    ドメインロジック（「何を同時に更新すべきか」）が UseCase に漏れ出す
```

`updating(name:localIdentifiers:)` が `name` と `slides` を**同時に**更新する点に注目してください。「名前を変えるときはスライドリストも必ず再生成する」というビジネスルールが、このメソッドに閉じ込められています。

#### 該当コード

```swift
func applying(config: SlideshowConfig) -> Slideshow {
    var updated = self
    updated.config = config
    return updated
}

func updating(name: String, localIdentifiers: [String]) -> Slideshow {
    var updated = self
    updated.name = name
    updated.slides = Slideshow.makeSlides(from: localIdentifiers, duration: config.duration.seconds ?? 0)
    return updated
}
```

---

## まとめ: このファイル群で学べること

### Swift 言語の基礎

| 概念 | 学んだこと |
|---|---|
| `struct` vs `class` | 値型はコピーされる。Domain 層は値型で安全・シンプルに |
| `let` vs `var` | 変えてはいけないものは `let` でコンパイラに守らせる |
| `Optional` (`?`) | 「ない」を `nil` で表す。コンパイラが nil 忘れを検出してくれる |
| `UUID` | 衝突しない一意な識別子 |
| `enum` + `rawValue` | 決まった選択肢を型安全に扱う |

### プロトコル

| プロトコル | 効果 |
|---|---|
| `Identifiable` | SwiftUI の `ForEach` に直接渡せる |
| `Equatable` | `==` で比較できる。コンパイラが自動生成 |
| `Sendable` | Swift 6 でスレッド間を安全に渡せる |
| `Codable` | JSON への変換/復元をコンパイラが自動生成 |
| `CaseIterable` | `allCases` で全ケースを列挙できる |

### ドメイン設計パターン

| パターン | 目的 |
|---|---|
| `static let default` | デフォルト値を一箇所に集約する |
| `static func create(...)` | 生成ロジックをエンティティ内に閉じ込める（ファクトリメソッド） |
| `func applying(...) -> Self` | 元の値を壊さず変更済みコピーを返す（イミュータブル更新） |

### Domain 層のルール

- **`Foundation` 以外の import は禁止**: `SwiftData`・`SwiftUI`・`Photos` は入れない
- **`class` は禁止**: すべて `struct` か `enum`（値型）で書く
- **UI 知識は持たない**: 表示用フォーマッターなどを Domain に入れない
- `Optional` は「本当にドメイン上で存在しない場合がある」フィールドにだけ使う
