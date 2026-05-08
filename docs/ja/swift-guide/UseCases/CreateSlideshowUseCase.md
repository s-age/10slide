# UseCase パターンと Swift の概念を学ぶ

## 対象ファイル

| ファイル | 役割 |
|---|---|
| `Sources/UseCases/Protocols/ExecutableUseCase.swift` | UseCase の「型の形」を定義するプロトコル |
| `Sources/UseCases/Requests/CreateSlideshowRequest.swift` | UseCase への入力（何をしたいか） |
| `Sources/UseCases/Responses/SlideshowResponse.swift` | UseCase からの出力（結果の型） |
| `Sources/UseCases/CreateSlideshowUseCase.swift` | スライドショーを作る処理の実装 |

### このガイドで学べること

「スライドショーを新しく作る」という一つの操作が、どのように Swift のコードで表現されているかを追いながら、UseCase パターンの考え方と Swift の言語機能を一緒に学びます。

---

## 1. プロトコルと `associatedtype` -- 「型の形」を決める

### ファイル: `ExecutableUseCase.swift`

```swift
protocol AsyncUseCase<Request, Response>: Sendable {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) async throws -> Response
}
```

### `protocol` とは

プロトコルは「このメソッドを持っていること」を約束させる仕組みです。クラスや構造体に対して「最低限これを実装してね」と要求します。

**使わなかったら？**  
それぞれの UseCase が好き勝手に `run()` や `start()` などバラバラなメソッド名を使うことになります。呼び出す側（Presentation 層）が、UseCase ごとに違うコードを書かなければならず、統一感がなくなります。

### `associatedtype` とは

プロトコルの「型のプレースホルダー」です。「このプロトコルに準拠するときに、具体的な型を決めてね」という意味です。

```swift
// Protocol side: Request and Response are "to be determined later"
protocol AsyncUseCase<Request, Response> {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) async throws -> Response
}

// Implementation side: Here "Request = CreateSlideshowRequest" is finalized
final class CreateSlideshowUseCase: AsyncUseCase {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        // ...
    }
}
```

**使わなかったら？**  
`execute` の引数を `Any` 型にするしかなく、呼び出す側で毎回キャスト（型変換）が必要になります。コンパイル時に型の誤りを検出できなくなり、バグが実行時まで気づかれません。

`associatedtype` のおかげで、Swift コンパイラが「`CreateSlideshowUseCase` には `CreateSlideshowRequest` を渡さないといけない」を事前にチェックできます。

---

## 2. `typealias` -- 型に「別名」をつける

このプロジェクトでは、UseCase の公開インターフェースを `Protocols/` フォルダに `typealias` として定義します。

```swift
// Protocols/CreateSlideshowUseCaseProtocol.swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>
```

### `typealias` とは

既存の型に「別名」をつける機能です。長い型名を短くしたり、意味のある名前を与えたりするために使います。

### なぜここで使うのか

`any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>` という型は、毎回書くには長すぎます。`CreateSlideshowUseCaseProtocol` という名前にすることで、コードを読む人が「これはスライドショー作成の UseCase だ」とすぐに分かります。

**使わなかったら？**  
DI（依存性注入）のコードや ViewModel のコードに、長い型名が何度も登場します。型を変更するときも、すべての箇所を書き直す必要があります。

```swift
// Without an alias (hard to read)
init(useCase: any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>) { ... }

// With an alias (conveys intent)
init(useCase: CreateSlideshowUseCaseProtocol) { ... }
```

---

## 3. `final class` とプロトコル準拠 -- 「約束を守る具体的な実装」

### ファイル: `CreateSlideshowUseCase.swift`

```swift
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

    init(domainService: any SlideshowDomainServiceProtocol) {
        self.domainService = domainService
    }

    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        // ...
    }
}
```

### `class` と `struct` の違い

Swift には値型（`struct`）と参照型（`class`）があります。

- **struct（値型）**: コピーされる。シンプルなデータのかたまりに向いている。
- **class（参照型）**: 同じインスタンスを複数箇所から参照できる。依存関係を持つオブジェクトに向いている。

UseCase は `domainService` という依存オブジェクトを保持するため、`class` を使います。

### `final` とは

「このクラスを継承できない」という宣言です。

**使わなかったら？**  
他のクラスが `CreateSlideshowUseCase` を継承して `execute` を上書きできてしまいます。UseCase は 1 操作 = 1 クラスの設計なので、`final` によって継承による複雑さを防ぎます。また、コンパイラが最適化しやすくなります。

### プロトコル準拠（`: AsyncUseCase`）

クラス名の後に `: プロトコル名` と書くことで、「このクラスはそのプロトコルを実装します」と宣言します。コンパイラは `execute` メソッドが実装されているかを確認し、なければエラーを出します。

---

## 4. `Sendable` -- 並行処理でも安全に使える

```swift
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
```

### `Sendable` とは

Swift の並行処理（async/await）では、複数のタスクが同時に動きます。`Sendable` は「この型は複数のタスクやスレッド間で安全にやり取りできる」という保証です。

**使わなかったら？**  
Swift 6 のコンパイラが「この型を非同期タスクに渡すのは危険かもしれない」と警告・エラーを出します。async な関数の中で UseCase を使うためには `Sendable` への準拠が必要です。

### なぜ `CreateSlideshowUseCase` は `Sendable` になれるのか

このクラスが持つ `domainService` は `any SlideshowDomainServiceProtocol` 型で、そのプロトコル自体が `Sendable` に準拠しています。すべてのプロパティが `Sendable` なら、クラス全体も `Sendable` になれます。

---

## 5. Request / Response パターン -- 入出力を型で表現する

### ファイル: `CreateSlideshowRequest.swift`

```swift
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

### なぜ Request を `struct` にするのか

Request は「この操作に必要な情報のかたまり」です。ただのデータなので、コピーされても問題ありません。`struct`（値型）が適しています。

**使わなかったら？**  
`execute(name: String, identifiers: [String], duration: ..., transition: ..., loop: Bool)` のように、引数が 5 個以上の長いメソッドになります。引数の順番を間違えやすく、後から項目を追加するたびに呼び出し側のコードをすべて変更する必要があります。

Request 型にまとめることで：
- 項目の追加・変更が型の定義変更だけで済む
- `validate()` で入力チェックを一箇所にまとめて書ける
- コードを読む人が「この操作に何が必要か」を一目で把握できる

> **重要**: `validate()` は `execute()` の内部では呼び出されて**いません**。DI コンテナで UseCase をラップする `ValidationAsyncUseCaseDecorator` によって呼び出されます。これにより、UseCase が明示的に `validate()` を呼ぶ必要なく、すべての UseCase にバリデーションが自動的に適用されます。このデコレータのラップの仕組みについては [DI/Container.md](../DI/Container.md) を参照してください。

### ファイル: `SlideshowResponse.swift`

```swift
struct SlideshowResponse: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let slides: [SlideResponse]
    let config: SlideshowConfigResponse
    let createdAt: Date
}
```

### なぜ Response を別の型にするのか

Domain 層（ビジネスロジック）には `Slideshow` というエンティティ型があります。しかし、画面表示に使う Presentation 層にドメインの内部型を直接渡してしまうと、ドメインの変更が即座に画面のコードに影響します。

Response 型を「緩衝材」として挟むことで：
- ドメイン層を変更しても、Response 型が同じならば画面のコードは変更不要
- 画面に必要な情報だけを選んで渡せる（不要な内部情報を隠せる）

`Identifiable` は `id` プロパティを持つことを要求するプロトコルで、SwiftUI の `List` やループ処理で各要素を一意に識別するために使います。`Equatable` は `==` で比較できることを保証します。

---

## 6. `async throws -> Response` -- 非同期で失敗できる関数

```swift
func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    let config = SlideshowConfig(
        duration: request.duration.toDomain,
        transition: request.transition.toDomain,
        loop: request.loop
    )
    let slideshow = try await domainService.create(
        name: request.name,
        localIdentifiers: request.localIdentifiers,
        config: config
    )
    return SlideshowResponse(from: slideshow)
}
```

### `async` -- 非同期処理

`async` をつけた関数は「途中で他のタスクに処理を譲れる」関数です。スライドショーの作成はディスクや写真ライブラリへのアクセスを伴うので、完了まで時間がかかります。その間、アプリが固まらないよう `async` を使います。

```swift
// The calling side uses await
let response = try await useCase.execute(request)
// Execution pauses here and resumes on the next line when complete
```

**使わなかったら？**  
同期処理（`async` なし）にすると、保存が完了するまでアプリ全体が固まります。ユーザーはその間、画面操作ができなくなります。

### `throws` -- 失敗を通知できる

`throws` をつけた関数はエラーを「投げる（throw）」ことができます。呼び出す側は `try` をつけて呼び出し、エラーを `catch` で受け取れます。

```swift
// Example calling code
do {
    let response = try await useCase.execute(request)
    // Handle success
} catch ValidationError.emptyName {
    // Handle empty name
} catch {
    // Handle other errors
}
```

**使わなかったら？**  
戻り値に `Result<SlideshowResponse, Error>` 型を使う方法もありますが、ネストが深くなりやすくコードが読みにくくなります。`throws` は Swift 標準のエラー伝搬の仕組みで、より自然に書けます。

---

## 7. `.toDomain` -- 計算プロパティによる型変換

```swift
let config = SlideshowConfig(
    duration: request.duration.toDomain,  // Response type -> Domain type
    transition: request.transition.toDomain,
    loop: request.loop
)
```

### 計算プロパティとは

`var` で定義し、呼び出されるたびに値を計算して返すプロパティです。引数を取らないメソッドの代わりに、「この型をある型に変換した値」を自然な書き方で取得できます。

```swift
// From ResponseMapping.swift
extension SlideDurationResponse {
    var toDomain: SlideDuration {
        switch self {
        case .five: .five
        case .ten: .ten
        case .fifteen: .fifteen
        case .thirty: .thirty
        case .sixty: .sixty
        case .manual: .manual
        }
    }
}
```

### なぜ `.toDomain` が必要なのか

`SlideDurationResponse`（Response 層の型）と `SlideDuration`（Domain 層の型）は別物です。同じ「5秒」という概念でも、層ごとに独立した型として定義されています。UseCase はその「翻訳係」として、Response 型を Domain 型に変換してから Domain Service に渡します。

**使わなかったら？**  
Presentation 層が Domain 層の型を直接使うことになり、層の分離が崩れます。Domain の型を変更したとき、画面のコードまで変更が波及してしまいます。

### `init(from:)` -- 逆方向の変換

Domain -> Response の変換は `init(from:)` で行います。

```swift
// From ResponseMapping.swift
extension SlideshowResponse {
    init(from entity: Slideshow) {
        self.init(
            id: entity.id,
            name: entity.name,
            slides: entity.slides.map { SlideResponse(from: $0) },
            config: SlideshowConfigResponse(from: entity.config),
            createdAt: entity.createdAt
        )
    }
}
```

UseCase の最後の行 `return SlideshowResponse(from: slideshow)` がこれを呼び出しています。Domain エンティティ（`Slideshow`）を Response 型（`SlideshowResponse`）に変換して、Presentation 層に返しています。

---

## まとめ: このコードで学べること

| 概念 | ポイント |
|---|---|
| `protocol` + `associatedtype` | 「型の形」を抽象化し、異なる UseCase を統一したインターフェースで扱える |
| `typealias` | 長い型名に意味のある別名をつけ、コードの可読性と保守性を高める |
| `final class` + プロトコル準拠 | 継承を禁止した具体的な実装クラスが、プロトコルの約束を果たす |
| `Sendable` | Swift 6 の並行処理でも安全に型を受け渡せることをコンパイラに保証する |
| `async throws -> Response` | 時間のかかる処理を非同期に、失敗を明示的に扱える関数シグネチャ |
| Request / Response パターン | 入力・出力を専用の型でカプセル化し、層間の依存を最小限に抑える |
| `.toDomain` / `init(from:)` | 層をまたぐ型変換を計算プロパティとイニシャライザで整理する |

---

## 実践で学んだ落とし穴

このプロジェクトの開発中に実際に起きた問題から、UseCase 層の落とし穴を紹介します。

---

### 落とし穴 1: Swift 6 では Request を `protocol + struct` で定義する

#### 何が起きるか

オブジェクト指向の経験がある人は、共通の `validate()` メソッドを基底クラスで定義し、各 Request をサブクラスとして実装したくなります。しかし Swift 6 の Strict Concurrency では、非 `final` クラスは `Sendable` に準拠できません。`@unchecked Sendable` はこのプロジェクトのルールで禁止されています。

```swift
// Bad: Defining a common interface with a base class (compile error in Swift 6)
class UseCaseRequest: Sendable {  // Error: non-final class cannot be Sendable
    func validate() throws { }
}

class CreateSlideshowRequest: UseCaseRequest {
    let name: String
    // ...
    override func validate() throws {
        guard !name.isEmpty else { throw ValidationError.emptyName }
    }
}
```

```swift
// Good: Define with protocol + struct (Sendable is automatically synthesized)
protocol UseCaseRequest: Sendable {
    func validate() throws
}

struct CreateSlideshowRequest: UseCaseRequest {
    let name: String
    let localIdentifiers: [String]
    // ... if all properties are Sendable, the struct is automatically Sendable

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }
    }
}
```

`struct` はすべてのストアドプロパティが `Sendable` であれば、コンパイラが自動的に `Sendable` を合成してくれます。クラス継承に頼らず、プロトコルで共通インターフェースを定義するのが Swift 6 の正しいアプローチです。

---

### 落とし穴 2: `typealias` に `any` が埋め込まれているのに二重に書かない

#### 何が起きるか

このプロジェクトでは UseCase のプロトコル型を `typealias` で定義しています。

```swift
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>
//                                         ^^^ any is embedded here
```

Swift では通常、プロトコル型を使うときに `any` を付けます。しかしこの `typealias` はすでに `any` を含んでいるため、使用箇所でさらに `any` を付けるとコンパイルエラーになります。

```swift
// Bad: Adding any even though the typealias already contains any
let createSlideshow: any CreateSlideshowUseCaseProtocol
// Compile error: redundant 'any' in type

// Bad: Trying to conform a concrete class to the typealias (an existential type)
final class CreateSlideshowUseCase: CreateSlideshowUseCaseProtocol { ... }
// Compile error: cannot conform to an existential type
```

```swift
// Good: Use the typealias as-is (no any needed)
let createSlideshow: CreateSlideshowUseCaseProtocol

// Good: Conform the concrete class to the original protocol (AsyncUseCase)
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        // ...
    }
}
```

**覚えておくこと:** `typealias` の定義を確認してから使うこと。`any` が含まれている `typealias` は、そのまま型として使えます。

---

### UseCase が担う役割のまとめ

```
Presentation Layer       UseCase Layer             Domain Layer
-------------------------------------------------------------
CreateSlideshowRequest --> execute() --> SlideshowConfig
(input received from UI)    | toDomain conversion      |
                         Calls domainService.create()
                              |
SlideshowResponse <-------- SlideshowResponse(from:)
(output returned to UI)      ^ Converts the Domain entity
```

UseCase は「入力の翻訳 -> Domain への委譲 -> 出力の翻訳」だけを担当します。ビジネスロジック（「スライドショーをどう作るか」）は Domain Service が持ちます。UseCase はその橋渡しにすぎません。
