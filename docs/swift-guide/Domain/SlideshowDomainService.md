# SlideshowDomainService.swift を読み解く

**ソースファイル**: `Sources/Domain/Services/SlideshowDomainService.swift`

---

## このファイルの概要

スライドショーに関するビジネスロジック（作成・更新・削除・取得）を担う **Domain Service** の実装ファイルです。
「スライドショーを作るときは何をすべきか」「更新するときは存在確認が必要か」といった **アプリ固有の判断** を持つのがこのクラスの役割です。

ソースコード全体を先に示します。これを上から順に読みながら、登場する Swift の概念を解説していきます。

```swift
import Foundation

final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
    private let repository: any SlideshowRepositoryProtocol

    init(repository: any SlideshowRepositoryProtocol) {
        self.repository = repository
    }

    func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
        let slideshow = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
        try await repository.save(slideshow)
        return slideshow
    }

    func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
        try await repository.save(updated)
        return updated
    }

    func updateConfig(id: UUID, config: SlideshowConfig) async throws -> Slideshow {
        guard let existing = try await repository.fetch(id: id) else {
            throw DomainError.slideshowNotFound(id)
        }
        let updated = existing.applying(config: config)
        try await repository.save(updated)
        return updated
    }

    func delete(id: UUID) async throws {
        try await repository.delete(id: id)
    }

    func fetch(id: UUID) async throws -> Slideshow? {
        try await repository.fetch(id: id)
    }

    func fetchAll() async throws -> [Slideshow] {
        try await repository.fetchAll()
    }
}
```

---

## 概念 1 — `final class` ＋ プロトコル準拠 ＋ `Sendable`

### 該当コード

```swift
final class SlideshowDomainService: SlideshowDomainServiceProtocol, Sendable {
```

### `final class` とは？

`class` は **参照型** です。変数に代入するとき、値そのものではなく「どこにあるか（参照）」が渡されます。
`final` を付けると、このクラスを **継承できない** ことをコンパイラに宣言します。

### なぜ `final` を使うのか？

- **継承を禁止することで意図が明確になります。** 「このクラスをそのまま使え、サブクラスで改造するな」というメッセージです。
- **コンパイラの最適化が効きやすくなります。** `final` が付いていると、コンパイラはメソッド呼び出しを静的に解決できます。

### `final` がなかったら？

誰かが `class MySlideshowDomainService: SlideshowDomainService` と継承して、ビジネスロジックを勝手に上書きできてしまいます。予期しない動作の温床になります。

---

### プロトコル準拠（`: SlideshowDomainServiceProtocol`）とは？

`SlideshowDomainServiceProtocol` は「このクラスが持つべきメソッド一覧」を定義した **プロトコル**（= インターフェース）です。
`: SlideshowDomainServiceProtocol` と書くことで「このクラスはそのプロトコルを満たします」と宣言します。

### なぜプロトコルに準拠させるのか？

上位レイヤー（UseCase）はこの **プロトコル** だけを知っていればよく、`SlideshowDomainService` という具体的なクラスを知る必要がなくなります。
テスト時は「プロトコルを満たすフェイク実装」に差し替えられ、本物のデータベースなしでテストできます。

---

### `Sendable` とは？

Swift の並行処理（async/await）では、複数の処理が同時に走る場合があります。
`Sendable` は「この型は複数のスレッドや非同期処理の境界をまたいで安全に渡せる」ことを保証するマーカープロトコルです。

### なぜここで必要なのか？

`SlideshowDomainService` は `async` なメソッドを持ち、異なる非同期コンテキストをまたいで使われます。
`Sendable` を宣言することで、Swift 6 のコンパイラが「安全に渡せる型だ」と認識します。

### `Sendable` がなかったら？

Swift 6 のコンパイラが「この型は Sendable ではないので、非同期の境界をまたいで渡せない」とエラーを出します。

---

## 概念 2 — `private let repository: any SlideshowRepositoryProtocol`

### 該当コード

```swift
private let repository: any SlideshowRepositoryProtocol
```

### `any` キーワードと存在型とは？

`any SlideshowRepositoryProtocol` は **存在型（existential type）** と呼ばれます。
「`SlideshowRepositoryProtocol` を満たす、何らかの型」を表します。具体的な型名（例: `SwiftDataSlideshowRepository`）を書かずに済みます。

Swift 5.7 以降、こうした「プロトコルの存在型」には `any` を明示的に付けることが必要になりました。これにより「ここは具体的な型ではなくプロトコルの存在型を使っている」と読み手に伝わります。

### `private` とは？

`private` は **アクセス制御** のキーワードです。このプロパティはこのクラスの内部からしか読み書きできません。

### `let` とは？

`let` で宣言すると **定数** になります。一度セットされた `repository` は変更できません。

### なぜこのように書くのか？

```swift
// NG — 具体的な型に依存している
private let repository: SwiftDataSlideshowRepository

// OK — プロトコルに依存している
private let repository: any SlideshowRepositoryProtocol
```

具体的な型を直接書くと、テスト時や実装を変えたいときにこのファイルも変更しなければなりません。
`any SlideshowRepositoryProtocol` と書けば、「プロトコルを満たしていれば何でも受け入れる」になります。

---

## 概念 3 — プロトコルベースの依存注入

### 該当コード

```swift
init(repository: any SlideshowRepositoryProtocol) {
    self.repository = repository
}
```

### 依存注入（Dependency Injection）とは？

クラスが必要とするオブジェクト（= 依存）を、**外から渡してもらう** 設計パターンです。
`SlideshowDomainService` は自分で `SwiftDataSlideshowRepository()` を生成しません。
代わりに `init` の引数で「プロトコルを満たす何か」を受け取ります。

### なぜ依存注入を使うのか？

| 状況 | 渡すもの |
|------|---------|
| 本番環境 | `SwiftDataSlideshowRepository`（実際の DB） |
| テスト環境 | `MockSlideshowRepository`（メモリ上の偽実装） |

呼び出し側が「何を渡すか」を決めるので、`SlideshowDomainService` 自身を一切変更せずに動作を切り替えられます。

### 依存注入をしなかったら？

```swift
// NG — 内部で具体的な実装を生成している
init() {
    self.repository = SwiftDataSlideshowRepository()  // テストのときも本物のDBが動く
}
```

テスト時に本物のデータベースが動いてしまい、テストが遅くなったり、データが汚染されたりします。

---

## 概念 4 — `async throws` — 非同期で失敗可能な関数

### 該当コード

```swift
func create(name: String, localIdentifiers: [String], config: SlideshowConfig) async throws -> Slideshow {
    let slideshow = Slideshow.create(name: name, localIdentifiers: localIdentifiers, config: config)
    try await repository.save(slideshow)
    return slideshow
}
```

### `async` とは？

`async` は「この関数は **非同期** で実行される」という印です。
非同期とは、時間のかかる処理（データベースへの保存など）を待っている間に、他の処理を進められることを意味します。

### `throws` とは？

`throws` は「この関数は **エラーを投げる可能性がある**」という宣言です。
呼び出し側は `try` を付けてエラーに対処しなければなりません。

### `try await` とは？

```swift
try await repository.save(slideshow)
```

- `await` — 「この非同期処理が終わるまで待つ」
- `try`  — 「エラーが起きるかもしれないので、呼び出し元に伝える準備をする」

この 2 つをセットで使うことで「非同期 かつ 失敗するかもしれない処理」を安全に呼び出せます。

### `async throws` がなかったら？

```swift
// NG — 同期的にブロックする（UI が固まる）
func create(...) -> Slideshow {
    repository.saveSync(slideshow)  // 保存が終わるまでアプリ全体が止まる
    return slideshow
}
```

データベースへの保存は時間がかかるため、同期的に待つとアプリの UI が止まって（フリーズして）しまいます。

---

## 概念 5 — `guard let ... else { throw }` — Optional の安全なアンラップとエラー送出

### 該当コード

```swift
func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
    guard let existing = try await repository.fetch(id: id) else {
        throw DomainError.slideshowNotFound(id)
    }
    let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
    try await repository.save(updated)
    return updated
}
```

### `Optional` とは？

`Slideshow?`（末尾に `?`）は「`Slideshow` が存在するか、存在しないか（`nil`）のどちらか」を表す型です。
`repository.fetch(id:)` はその ID のスライドショーがデータベースに存在しない場合 `nil` を返します。

### `guard let` とは？

`guard let existing = ... else { ... }` は：
- 値が存在すれば `existing` に取り出して続きを実行する
- `nil` だった場合は `else` ブロックに入り、そこで処理を抜ける

通常の `if let` との違いは、`guard let` は「条件を満たさない場合は早期リターンする」という意図を明確にします。
条件を満たしたときのメイン処理がインデントなしで続くため、読みやすくなります。

### `throw DomainError.slideshowNotFound(id)` とは？

存在しない ID を更新しようとしたとき、`nil` をそのまま無視して続けるのは危険です。
`throw` でエラーを投げることで「このIDのスライドショーは見つからなかった」を呼び出し元に明示的に伝えます。

### `guard let` を使わなかったら？

```swift
// NG — Optional を強制アンラップ（クラッシュの危険）
let existing = try await repository.fetch(id: id)!
```

`!` で強制アンラップすると、`nil` だったときにアプリがクラッシュします。
`guard let` を使えば、クラッシュの代わりに意味のあるエラーを返せます。

---

## 概念 6 — ドメインサービスの役割

### ドメインサービスとは何か？

**「アプリ固有の判断（ビジネスロジック）をまとめる場所」** です。

たとえば `update` メソッドを見てみます。

```swift
func update(id: UUID, name: String, localIdentifiers: [String]) async throws -> Slideshow {
    guard let existing = try await repository.fetch(id: id) else {
        throw DomainError.slideshowNotFound(id)  // ← ビジネスルール: 存在しないものは更新できない
    }
    let updated = existing.updating(name: name, localIdentifiers: localIdentifiers)
    try await repository.save(updated)
    return updated
}
```

「更新する前に必ず存在確認をする」というのは、データベースの話ではなくアプリの **ルール** です。
この判断をドメインサービスに書くことで、「なぜそう動くのか」が一箇所で分かります。

### もしドメインサービスがなかったら？

ビジネスロジックが画面のコード（View）やデータ保存のコード（Repository）に散らばってしまい、「どこで何を決めているのか」が分からなくなります。同じ判断が複数の場所に重複して書かれ、変更のたびに漏れが生じます。

### このサービスの処理の流れ（`update` の例）

```
1. repository.fetch(id:)   → DBから既存データを取得する
2. guard let existing      → 存在しなければエラーを投げて終了
3. existing.updating(...)  → Entityの純粋な変換（ビジネスルール）
4. repository.save(updated)→ 変換後のデータをDBに保存する
5. return updated          → 呼び出し元に結果を返す
```

「取得 → 判断 → 変換 → 保存 → 返却」という一連の流れを **1 つのメソッドが責任を持つ** のがドメインサービスの特徴です。

---

## このファイルで学べること まとめ

| 概念 | 要点 |
|------|------|
| `final class` | 継承を禁止し、意図とパフォーマンスを改善する |
| プロトコル準拠 | 上位レイヤーは具体型を知らずに済み、差し替えが容易になる |
| `Sendable` | 非同期の境界をまたいで安全に渡せる型であることを宣言する |
| `any SlideshowRepositoryProtocol` | 存在型。具体的な型ではなくプロトコルを型として扱う |
| `private let` | カプセル化。外から変更できないようにして不変性を守る |
| 依存注入 (`init` 経由) | 本番とテストで依存を差し替えられる設計にする |
| `async throws` | 非同期かつ失敗可能な処理を型安全に表現する |
| `try await` | 非同期＋失敗可能な処理を呼び出すセット構文 |
| `guard let ... else { throw }` | Optionalを安全にアンラップし、nilならエラーで早期リターンする |
| ドメインサービス | ビジネスルールを一箇所に集め、「なぜそう動くのか」を明確にする |

これらの概念は、Swift で **安全で・変更しやすく・テストしやすい** コードを書くための基本パターンです。
このファイルは 46 行と短いですが、そのすべての行に「なぜそう書くのか」という理由があります。
