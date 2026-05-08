# エラー設計ガイド — レイヤードアーキテクチャにおけるエラーの扱い方

**種別:** 発展編（トピック横断ガイド）

レイヤードアーキテクチャでは「レイヤー間で型をリークさせない」のが原則です。しかしエラーは本質的にレイヤーを横断します。Domain 層で発生したエラーは最終的に Presentation 層でユーザーに表示しなければなりません。

このガイドでは、10slide が採用したエラー設計のパターンと、その背景にある判断を説明します。

---

## 概要

10slide のエラー設計は、当初「レイヤーごとにエラー型を定義し、境界でマッピングする」方式でした。しかし実運用で以下の問題が発生し、現在の「共有リーフ層」方式に移行しています。

| 方式 | メリット | デメリット |
|------|---------|----------|
| レイヤーごとのエラー型 | レイヤー境界が厳密 | デッドコード、重複 case、`LocalizedError` 漏れ |
| 共有リーフ層（現在） | シンプル、`LocalizedError` 保証 | エラーがレイヤーを横断する（意図的な例外） |

---

## 1. Errors ディレクトリは「共有リーフ層」 — 全レイヤーから参照可能

### これは何か？

`Sources/Errors/` は、10slide のレイヤードアーキテクチャにおける **唯一の例外** です。通常、各レイヤーは隣接レイヤーとしか通信できませんが、`Errors/` は **全レイヤーから直接参照** できます。

```
Presentation → UseCases → Domain/Services → Repositories → Infrastructure
                              ↑                   ↑              ↑
                          Errors/ ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
                   (Shared leaf layer: accessible from all layers)
```

### なぜこの設計なのか？

#### 問題 1：デッドコード

レイヤーごとにエラー型を作ると、使われない case が生まれます。

```swift
// ❌ UseCaseError mirrors all DomainError cases, but Presentation only uses some
enum UseCaseError: Error {
    case slideshowNotFound       // Used
    case invalidSlideOrder       // Used
    case databaseCorruption      // Not used in Presentation — dead code
    case networkTimeout          // Not used in Presentation — dead code
}
```

#### 問題 2：LocalizedError 準拠の漏れ

`DomainError` が `LocalizedError` に準拠していないと、Presentation でユーザーに表示するとき `error.localizedDescription` が `"The operation couldn't be completed."` という無意味な文字列になります。

```swift
// ❌ DomainError does not conform to LocalizedError
enum DomainError: Error {
    case slideshowNotFound
}
// In Presentation: error.localizedDescription → meaningless generic message
```

#### 問題 3：配置の混乱

エラー型をどのレイヤーに置くかで迷いが生じます。`UseCaseError` を `UseCases/Requests/` に置くのは意味的に不自然でした。

### このプロジェクトの実際のエラー型

```swift
// Sources/Errors/DomainError.swift
enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .slideshowNotFound(let id):
            return String(localized: "Slideshow not found: \(id.uuidString)")
        }
    }
}

// Sources/Errors/ValidationError.swift
enum ValidationError: LocalizedError, Sendable {
    case emptyName
    case noIdentifiers
    case invalidIndex
    case noSlides

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return String(localized: "Name must not be empty")
        case .noIdentifiers:
            return String(localized: "At least one image must be selected")
        case .invalidIndex:
            return String(localized: "Slide index is out of range")
        case .noSlides:
            return String(localized: "Slideshow has no slides")
        }
    }
}
```

3つの規約に注目してください：
1. **`LocalizedError, Sendable`** — 両方とも必須です。`Sendable` は Swift 6 でエラーがアクター境界を越えるために必要です。
2. **`String(localized:)`** — ハードコードされた文字列ではなく、将来のローカライズに対応します。
3. **引数ラベルなし** — `case slideshowNotFound(id: UUID)` ではなく `case slideshowNotFound(UUID)` とします。

### 間違った例

```swift
// ❌ Creating error types per layer — a breeding ground for duplication and dead code
// Sources/Domain/Services/DomainError.swift
enum DomainError: Error {
    case slideshowNotFound(UUID)
}

// Sources/UseCases/Requests/UseCaseError.swift
enum UseCaseError: Error {
    case slideshowNotFound(UUID)  // Copy of DomainError
}
```

### ルール

- エラー enum は全て `Sources/Errors/` に配置する
- 失敗ドメインごとに1つの enum を作る（`DomainError`、`ValidationError` など）
- モノリシックな `AppError` は作らない — 時間とともに肥大化する
- `Sources/Errors/` にビジネスロジックやプロトコルを置かない — 純粋なエラー定義のみ

---

## 2. レイヤー境界でのエラー変換が不要な理由

### 以前の設計（レイヤーごとのエラー型）

以前は「Domain のエラーを UseCase の境界で `UseCaseError` に変換し、Presentation には `UseCaseError` だけを見せる」という方針でした。

```swift
// Previous approach — converting DomainError → UseCaseError within the UseCase
func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    do {
        let slideshow = try await domainService.create(name: request.name, localIdentifiers: request.localIdentifiers, config: ...)
        return SlideshowResponse(from: slideshow)
    } catch let error as DomainError {
        switch error {
        case .slideshowNotFound(let id):
            throw UseCaseError.slideshowNotFound(id)  // Re-defining the same case
        // ... mapping all other cases as well
        }
    }
}
```

### 現在の設計（共有リーフ層）

エラーは `Sources/Errors/` の enum を直接 throw します。レイヤー間のマッピングは不要です。

```swift
// ✅ Current approach — errors use the Sources/Errors/ types as-is
func execute(_ request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    // Note: validate() is handled by ValidationAsyncUseCaseDecorator in the DI layer
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
    // DomainError (e.g. .slideshowNotFound) propagates directly without conversion
}
```

### なぜエラーは例外なのか？

「レイヤー間で型をリークさせない」原則が守りたいのは **Entity（ビジネスデータ）** です。Entity は構造と振る舞いを持ち、レイヤー依存を生みます。一方、エラーは **純粋なシグナル** です。

| 型の種類 | レイヤー横断の共有 | 理由 |
|---------|-----------------|------|
| Entity（Slideshow, Slide） | 禁止 | 構造と振る舞いを持ち、レイヤー結合を生む |
| Response DTO | UseCase → Presentation のみ | Presentation 専用の表示データ |
| Error enum | 全レイヤーで共有 | 純粋なシグナル、Foundation 以外の依存なし |

---

## 3. エラー型の設計原則

### 原則 1：`LocalizedError` と `Sendable` の両方に準拠させる

```swift
// ✅ Both conformances required
enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .slideshowNotFound(let id):
            return String(localized: "Slideshow not found: \(id.uuidString)")
        }
    }
}
```

```swift
// ❌ Missing Sendable — compile error when thrown across actor boundaries in Swift 6
enum DomainError: LocalizedError {
    case slideshowNotFound(UUID)
}

// ❌ Missing LocalizedError — localizedDescription returns a meaningless generic message
enum DomainError: Error, Sendable {
    case slideshowNotFound(UUID)
}
// error.localizedDescription → "The operation couldn't be completed."
```

### 原則 2：エラーメッセージに `String(localized:)` を使う

```swift
// ✅ Enables future localization
var errorDescription: String? {
    switch self {
    case .slideshowNotFound(let id):
        return String(localized: "Slideshow not found: \(id.uuidString)")
    }
}
```

```swift
// ❌ Hardcoded strings — no localization support
var errorDescription: String? {
    switch self {
    case .slideshowNotFound(let id):
        return "Slideshow not found (ID: \(id))"
    }
}
```

### 原則 3：Foundation 以外の import 禁止

`Sources/Errors/` のファイルは **Foundation のみ** import できます。他のフレームワーク（SwiftUI, SwiftData など）や、他のレイヤーの型を import すると、「共有リーフ層」の前提が崩れます。

```swift
// ✅ Foundation only
import Foundation

enum ValidationError: LocalizedError, Sendable {
    case emptyName           // No associated value needed
    case invalidIndex        // Primitive case
}
```

```swift
// ❌ Importing SwiftData — introduces an Infrastructure dependency into the Errors layer
import SwiftData

enum DataError: LocalizedError, Sendable {
    case modelNotFound(PersistentIdentifier)  // Using a SwiftData type as an associated value
}
```

### 原則 4：associated value に Entity や DTO を使わない

```swift
// ✅ Primitive/Foundation types only
enum DomainError: LocalizedError, Sendable {
    case slideshowNotFound(UUID)    // UUID is a Foundation type
}
```

```swift
// ❌ Using an Entity as an associated value — creates layer coupling
enum DomainError: LocalizedError, Sendable {
    case invalidSlideshow(Slideshow)  // Dependency on a Domain Entity
}
```

### 原則 5：失敗ドメインごとに1つの enum

```swift
// ✅ Split by domain — this project uses:
enum DomainError: LocalizedError, Sendable { /* Business-rule violations */ }
enum ValidationError: LocalizedError, Sendable { /* Request validation failures */ }
```

```swift
// ❌ Cramming everything into one — bloats and becomes unmanageable
enum AppError: LocalizedError, Sendable {
    case slideshowNotFound
    case emptyName
    case photoAccessDenied
    case networkTimeout
    // ... grows without end
}
```

---

## まとめ

| 原則 | 内容 |
|------|------|
| 配置場所 | `Sources/Errors/` — 共有リーフ層 |
| プロトコル準拠 | 全 enum が `LocalizedError, Sendable` に準拠 |
| エラーメッセージ | ローカライズ対応のため `String(localized:)` を使用 |
| import 制限 | `Foundation` のみ — 他のフレームワーク禁止 |
| associated value | プリミティブ型・Foundation 型のみ — Entity/DTO 禁止 |
| 粒度 | 失敗ドメインごとに1つの enum（`DomainError`、`ValidationError`）— モノリシック `AppError` は禁止 |
| レイヤー間マッピング | 不要 — エラーは共有リーフ層の型をそのまま使う |
| ビジネスロジック | `Sources/Errors/` に置かない — 純粋なエラー定義のみ |

### 「なぜ Entity はリークさせないのにエラーは許すのか？」

Entity は構造と振る舞いを持ち、それに依存するとレイヤー間の結合が強くなります。エラーは enum の case 名と `LocalizedError` のメッセージだけを持つ純粋なシグナルであり、レイヤー間の結合を増やしません。この区別が「共有リーフ層」設計の根拠です。
