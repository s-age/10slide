# Domain エンティティのパターンと Swift 基礎概念

> 対象: Swift を学び始めたばかりの人。コードを読んで「なぜこう書くのか？」が分からない人。

---

## 対象ソースファイルと概要

| ファイル | 型の種類 | 役割 |
|---|---|---|
| `Sources/Domain/Entities/Slide.swift` | Entity（エンティティ） | スライドショーを構成する 1 枚のスライドを表す |
| `Sources/Domain/Entities/Slideshow.swift` | Entity（エンティティ） | スライドの集合＋設定を持つスライドショー全体を表す |
| `Sources/Domain/Entities/SlideshowConfig.swift` | Value Object（値オブジェクト） | スライドショーの再生設定（秒数・切り替え・ループ）を表す |
| `Sources/Domain/Entities/SlideDuration.swift` | Enum Variant Set（列挙バリアントセット） | スライドの表示時間（5秒、10秒、…60秒、手動）を表す |
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

### SlideDuration.swift

```swift
import Foundation

enum SlideDuration: String, Equatable, Sendable, CaseIterable, Codable {
    case five = "5"
    case ten = "10"
    case fifteen = "15"
    case thirty = "30"
    case sixty = "60"
    case manual

    var seconds: TimeInterval? {
        switch self {
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .thirty: return 30
        case .sixty: return 60
        case .manual: return nil
        }
    }
}
```

> **注意**: `SlideDuration.seconds` は `TimeInterval?`（Optional）を返します。`manual` ケースは `nil` を返しますが、これは手動モードには固定の表示時間がなく、ユーザーが手動でスライドを進めるためです。そのため、`config.duration.seconds ?? 0` のように nil 合体演算子を使ったり、`guard let duration = config.duration.seconds else { return }` のようにオプショナルバインディングを使ったりするコードが存在します。

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
// ❌ With class, references are shared
class SlideClass {
    var order: Int
    init(order: Int) { self.order = order }
}

let a = SlideClass(order: 0)
let b = a          // Not a copy -- points to the same instance as a
b.order = 99
print(a.order)     // 99 ← a was changed too!
```

```swift
// ✅ With struct, a copy is made
struct SlideStruct {
    var order: Int
}

let a = SlideStruct(order: 0)
var b = a          // An independent copy is created
b.order = 99
print(a.order)     // 0 ← a is unaffected
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
// Conceptual definition from Apple's standard library
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
// Without Identifiable
ForEach(slides, id: \.localIdentifier) { slide in ... }  // Must specify the id key path every time

// With Identifiable ✅
ForEach(slides) { slide in ... }  // id is self-evident, so it can be omitted
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
// ❌ Without Equatable
// let a: Slide = ...
// let b: Slide = ...
// if a == b { ... }  // Compile error: cannot compare

// You would need to write comparison logic manually (tedious and error-prone)
func isEqual(_ a: Slide, _ b: Slide) -> Bool {
    a.id == b.id &&
    a.localIdentifier == b.localIdentifier &&
    a.order == b.order
    // ... must be updated every time a property is added
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
// ❌ Without Sendable → May cause compile errors in Swift 6 async contexts
func fetchSlides() async -> [Slide] { ... }
// Errors such as "Sending 'result' risks causing data races"
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
    let id: UUID           // ← let: The ID never changes after creation
    let localIdentifier: String  // ← let: The reference to the original photo never changes either
    var order: Int         // ← var: The slide's display order can be changed
    var duration: TimeInterval   // ← var: The display duration can be adjusted later
    var title: String?     // ← var: A title can be added later
}
```

`id` を `var` にしてしまうと「同じスライドに別の ID を付ける」操作が可能になり、アイデンティティの意味が崩れます。`let` にすることでコンパイラが誤った変更を防いでくれます。

#### もし全部 `var` にしたら

```swift
// ❌ If id were var
var slide = Slide(id: UUID(), localIdentifier: "abc", order: 0, duration: 5, title: nil)
slide.id = UUID()  // The ID can be overwritten! Data consistency is broken
```

#### 該当コード

```swift
let id: UUID                 // Immutable -- guarantees entity identity
let localIdentifier: String  // Immutable -- guarantees the reference to the original photo
var order: Int               // Mutable -- display order can be edited
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
// ❌ Sequential numbers can collide when created simultaneously in multiple places
var nextId = 0
let slide1 = Slide(id: nextId, ...)  // id: 0
nextId += 1
let slide2 = Slide(id: nextId, ...)  // id: 1
// Operating on the same counter from different threads causes a data race
```

#### 該当コード

```swift
let id: UUID
// ...
Slideshow(id: UUID(), ...)  // UUID() generates a new unique ID each time
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
// ❌ Trying to represent "no title" without Optional
var title: String = ""   // Empty string = no title? But you can't distinguish between an empty title and "not set"
var title: String = "(none)"  // Put a display string? Domain knowledge of UI leaks into the Domain layer

// ✅ With Optional, the meaning is clear
var title: String?  // nil = title not set, "Hello" = title exists
```

使う側では次のようにアンラップします：

```swift
// Safe unwrapping with if let
if let title = slide.title {
    print("Title: \(title)")
} else {
    print("No title")
}

// Default value with ??
let displayTitle = slide.title ?? "Untitled"
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
// ❌ With String, the compiler cannot detect typos
var transition: String = "fde"   // Typo goes unnoticed
var transition: String = "zoom"  // An undefined value can be assigned

// ✅ With enum, only existing cases can be assigned
var transition: TransitionType = .fade  // The compiler provides completion and validation
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
// Example of a picker using allCases (how it would look in the Presentation layer)
ForEach(TransitionType.allCases, id: \.self) { type in
    Text(type.rawValue)
}
```

#### もし `CaseIterable` を使わなかったら

```swift
// ❌ Managing the array manually
let allTransitions: [TransitionType] = [.none, .fade, .slide, .dissolve]
// You must be careful to update this array every time a case is added
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
// {"duration":"5","transition":"fade","loop":true}
// ↑ SlideDuration.five の rawValue は "5" なので、JSON には "five" ではなく "5" が入る

// デコード: JSON → Swift 型
let restored = try JSONDecoder().decode(SlideshowConfig.self, from: data)
```

`TransitionType` が `String` を rawValue に持つため、JSON では `"fade"` という人間が読める文字列として保存されます。

#### もし `Codable` を使わなかったら

```swift
// ❌ Writing encode/decode manually (can run to dozens of lines)
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
    duration: .five,       // Display for 5 seconds
    transition: .fade,     // Transition with a fade
    loop: true             // Loop playback
)
```

呼び出し側では `SlideshowConfig.default` と書くだけで取得できます。

#### もし `static let default` を使わなかったら

```swift
// ❌ Scattering default values across multiple locations
// Both in the View and UseCase, you write the same values every time
// → When one is changed, others may be missed
let config1 = SlideshowConfig(duration: .five, transition: .fade, loop: true)
let config2 = SlideshowConfig(duration: .five, transition: .fade, loop: true)  // Duplication
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
// The same pattern in TransitionType
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
// ❌ The caller handles all initialization every time
let slideshow = Slideshow(
    id: UUID(),           // ← Caller must write UUID()
    name: name,
    slides: localIdentifiers.enumerated().map { index, id in
        Slide(id: UUID(), localIdentifier: id, order: index, duration: duration, title: nil)
    },
    config: config,
    createdAt: Date()    // ← Caller must write the creation date too
)
// This creation logic gets duplicated across UseCases, Views, etc.
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
    var updated = self         // 1. Create a copy of self (it's a struct, so it's copied)
    updated.config = config    // 2. Modify the config on the copy
    return updated             // 3. Return the modified copy (the original self is unchanged)
}
```

#### もしこのパターンを使わなかったら

```swift
// ❌ Mutating directly (this works, but the intent is less clear)
var slideshow = Slideshow.create(...)
slideshow.config = newConfig   // Harder to track where and what changed

// ❌ If the UseCase layer directly mutates properties,
//    domain logic ("what should be updated together") leaks into the UseCase
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

## 実践で学んだ落とし穴

このプロジェクトの開発中に実際に起きた問題から、2 つの落とし穴を紹介します。

---

### 落とし穴 1: エンティティにビジネスロジックを詰め込まない

#### 何が起きるか

エンティティに「便利だから」とメソッドを追加していくと、データの器であるべき型がビジネスロジックの塊になります。
実際に `Slideshow` にはスライドナビゲーション用のメソッドがありましたが、これらは引数だけで計算でき、エンティティ自身の状態（`self`）に依存していませんでした。こうしたメソッドは Domain Service に属するべきです。

#### 判断基準

- メソッドが `self` のストアドプロパティを使っている --> エンティティに置いてよい（例: `applying(config:)`）
- メソッドが引数だけで結果を計算できる --> Domain Service に移すべき

```swift
// ❌ A method that should not be in the entity (does not use self's state)
struct Slideshow {
    func nextSlideIndex(from currentIndex: Int) -> Int {
        // Can be computed from just currentIndex and slides.count,
        // but playback logic is the responsibility of PlaybackDomainService
        (currentIndex + 1) % slides.count
    }
}

// ✅ Move to a Domain Service (actual code from PlaybackDomainService.swift)
final class PlaybackDomainService: PlaybackDomainServiceProtocol, Sendable {
    func nextIndex(totalSlides: Int, currentIndex: Int, loop: Bool) -> Int? {
        guard totalSlides > 0 else { return nil }
        if currentIndex < totalSlides - 1 { return currentIndex + 1 }
        return loop ? 0 : nil
    }
}
```

エンティティは **純粋なデータの器** に保ち、振る舞いは Domain Service に置くことで、責務が明確になりテストもしやすくなります。

---

### 落とし穴 2: 固定の選択肢は `enum` で表現する

#### 何が起きるか

「Domain 層は `struct` で書く」というルールを厳密に解釈しすぎて、固定の選択肢まで `struct` + `static let` で書いてしまうことがあります。しかし Swift の `enum` も値型なので、Domain 層のルール（値型であること）に違反しません。

```swift
// ❌ Expressed with struct + static let (switch exhaustiveness checking does not work)
struct TransitionType: Equatable, Sendable {
    let rawValue: String
    static let none = TransitionType(rawValue: "none")
    static let fade = TransitionType(rawValue: "fade")
    static let slide = TransitionType(rawValue: "slide")
    static let dissolve = TransitionType(rawValue: "dissolve")
}

// With this approach, even if you list all cases in a switch statement,
// the compiler cannot detect missing cases
switch transition {
case .none: ...
case .fade: ...
// Forgetting .slide and .dissolve still compiles
default: break  // ← default is required, and you can't notice omissions
}
```

```swift
// ✅ With enum, switch exhaustiveness checking works
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve
}

switch transition {
case .none: ...
case .fade: ...
// Not writing .slide and .dissolve causes a compile error ← Safe!
}
```

**選び方の目安:**
- **選択肢が固定で増減しない** --> `enum`（コンパイラの網羅チェックが使える）
- **将来的に拡張される可能性がある** --> `struct` またはプロトコル

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
