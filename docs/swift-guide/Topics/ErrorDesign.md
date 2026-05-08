# エラー設計ガイド — レイヤードアーキテクチャにおけるエラーの扱い方

**種別:** 発展編（トピック横断ガイド）

レイヤードアーキテクチャでは「レイヤー間で型をリークさせない」のが原則です。しかしエラーは本質的にレイヤーを横断します。Domain で発生したエラーは最終的に Presentation でユーザーに表示しなければなりません。

このガイドでは、10slide が採用したエラー設計のパターンと、その背景にある判断を説明します。

---

## 概要

10slide のエラー設計は、当初「レイヤーごとにエラー型を定義し、境界でマッピングする」方式でした。しかし実運用で以下の問題が発生し、現在の「共有リーフ層」方式に移行しています。

| 方式 | メリット | デメリット |
|------|---------|----------|
| レイヤーごとのエラー型 | レイヤー境界が厳密 | 死んだコード、重複 case、`LocalizedError` 漏れ |
| 共有リーフ層（現在） | シンプル、`LocalizedError` 保証 | エラーがレイヤーを横断する（意図的な例外） |

---

## 1. Errors ディレクトリは「共有リーフ層」 — 全レイヤーから参照可能

### これは何か？

`Sources/Errors/` は、10slide のレイヤードアーキテクチャにおける **唯一の例外** です。通常、各レイヤーは隣接レイヤーとしか通信できませんが、`Errors/` は **全レイヤーから直接参照** できます。

```
Presentation → UseCases → Domain/Services → Repositories → Infrastructure
                              ↑                   ↑              ↑
                          Errors/ ←←←←←←←←←←←←←←←←←←←←←←←←←←←←←
                   （共有リーフ層：全レイヤーから参照可能）
```

### なぜこの設計なのか？

#### 問題 1：死んだコード

レイヤーごとにエラー型を作ると、使われない case が生まれます。

```swift
// ❌ UseCaseError が DomainError の全 case をミラーしているが、Presentation は一部しか使わない
enum UseCaseError: Error {
    case slideshowNotFound       // 使われている
    case invalidSlideOrder       // 使われている
    case databaseCorruption      // Presentation では使わない — 死んだコード
    case networkTimeout          // Presentation では使わない — 死んだコード
}
```

#### 問題 2：LocalizedError の漏れ

`DomainError` が `LocalizedError` に準拠していないと、Presentation でユーザーに表示するとき `error.localizedDescription` が `"The operation couldn\u{2019}t be completed."` という無意味な文字列になります。

```swift
// ❌ DomainError が LocalizedError に準拠していない
enum DomainError: Error {
    case slideshowNotFound
}
// Presentation 側：error.localizedDescription → 意味不明な汎用メッセージ
```

#### 問題 3：配置の混乱

エラー型をどのレイヤーに置くかで迷いが生じます。`UseCaseError` を `UseCases/Requests/` に置くのは意味的に不自然でした。

### 正しい例

```swift
// ✅ Sources/Errors/ に配置 — 全レイヤーから参照可能
// Sources/Errors/SlideshowError.swift
enum SlideshowError: LocalizedError {
    case notFound(id: UUID)
    case emptyName

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "スライドショーが見つかりません（ID: \(id)）"
        case .emptyName:
            return "スライドショー名を入力してください"
        }
    }
}
```

### 間違った例

```swift
// ❌ レイヤーごとにエラー型を作る — 重複と死んだコードの温床
// Sources/Domain/Services/DomainError.swift
enum DomainError: Error {
    case slideshowNotFound(id: UUID)
}

// Sources/UseCases/Requests/UseCaseError.swift
enum UseCaseError: Error {
    case slideshowNotFound(id: UUID)  // DomainError のコピー
}
```

### ルール

- エラー enum は全て `Sources/Errors/` に配置する
- 失敗ドメインごとに1つの enum を作る（`SlideshowError`、`ConfigError` など）
- モノリシックな `AppError` は作らない — 肥大化する
- `Sources/Errors/` にビジネスロジックやプロトコルを置かない — 純粋なエラー定義のみ

---

## 2. レイヤー境界でのエラー変換が不要な理由

### 以前の設計（レイヤーごとのエラー型）

以前は「Domain のエラーを UseCase の境界で `UseCaseError` に変換し、Presentation には `UseCaseError` だけを見せる」という方針でした。

```swift
// 以前の方式 — UseCase 内で DomainError → UseCaseError に変換
func execute(request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    do {
        try request.validate()
        let slideshow = try await slideshowService.create(name: request.name)
        return SlideshowResponse(from: slideshow)
    } catch let error as DomainError {
        switch error {
        case .slideshowNotFound(let id):
            throw UseCaseError.slideshowNotFound(id: id)  // 同じ case を再定義
        // ... 他の case も全てマッピング
        }
    }
}
```

### 現在の設計（共有リーフ層）

エラーは `Sources/Errors/` の enum を直接 `throw` します。レイヤー間のマッピングは不要です。

```swift
// ✅ 現在の方式 — エラーは Sources/Errors/ の型をそのまま使う
func execute(request: CreateSlideshowRequest) async throws -> SlideshowResponse {
    try request.validate()
    let slideshow = try await slideshowService.create(name: request.name)
    return SlideshowResponse(from: slideshow)
    // SlideshowError.notFound がそのまま呼び出し元に伝搬する
}
```

### なぜエラーは例外なのか？

「レイヤー間で型をリークさせない」原則が守りたいのは **Entity（ビジネスデータ）** です。Entity は構造と振る舞いを持ち、レイヤー依存を生みます。一方、エラーは **純粋なシグナル** です。

| 型の種類 | レイヤー横断 | 理由 |
|---------|-----------|------|
| Entity（Slideshow, Slide） | 禁止 | 構造と振る舞いを持ち、レイヤー結合を生む |
| Response DTO | UseCase → Presentation のみ | Presentation 専用の表示データ |
| Error enum | 全レイヤーで共有 | 純粋なシグナル、Foundation 以外の依存なし |

---

## 3. エラー型の設計原則

### 原則 1：全ての enum を LocalizedError に準拠させる

```swift
// ✅ LocalizedError に準拠 — ユーザーに意味のあるメッセージを表示できる
enum SlideshowError: LocalizedError {
    case notFound(id: UUID)

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "スライドショーが見つかりません（ID: \(id)）"
        }
    }
}
```

```swift
// ❌ Error のみに準拠 — localizedDescription が無意味な汎用メッセージになる
enum SlideshowError: Error {
    case notFound(id: UUID)
}
// error.localizedDescription → "The operation couldn't be completed."
```

### 原則 2：Foundation 以外の import 禁止

`Sources/Errors/` のファイルは **Foundation のみ** import できます。他のフレームワーク（SwiftUI, SwiftData など）や、他のレイヤーの型を import すると、「共有リーフ層」の前提が崩れます。

```swift
// ✅ Foundation のみ
import Foundation

enum ConfigError: LocalizedError {
    case fileNotFound(path: String)  // String は Foundation 型
    case invalidFormat
}
```

```swift
// ❌ SwiftData を import — Errors 層に Infrastructure 依存が入ってしまう
import SwiftData

enum DataError: LocalizedError {
    case modelNotFound(PersistentIdentifier)  // SwiftData の型を associated value に使用
}
```

### 原則 3：associated value に Entity や DTO を使わない

```swift
// ✅ プリミティブ型のみ
enum SlideshowError: LocalizedError {
    case notFound(id: UUID)           // UUID は Foundation 型
    case nameTooLong(maxLength: Int)  // Int はプリミティブ
}
```

```swift
// ❌ Entity を associated value に使用 — レイヤー結合が発生
enum SlideshowError: LocalizedError {
    case invalidSlideshow(Slideshow)  // Domain Entity への依存
}
```

### 原則 4：失敗ドメインごとに1つの enum

```swift
// ✅ ドメインごとに分割
enum SlideshowError: LocalizedError { /* スライドショー関連のエラー */ }
enum ConfigError: LocalizedError { /* 設定ファイル関連のエラー */ }
enum PhotoLibraryError: LocalizedError { /* 写真ライブラリ関連のエラー */ }
```

```swift
// ❌ 全てを1つに詰め込む — 肥大化して管理困難
enum AppError: LocalizedError {
    case slideshowNotFound
    case configFileNotFound
    case photoAccessDenied
    case networkTimeout
    // ... 際限なく増える
}
```

---

## まとめ

| 原則 | 内容 |
|------|------|
| 配置場所 | `Sources/Errors/` — 共有リーフ層 |
| 準拠プロトコル | 全 enum が `LocalizedError` に準拠 |
| import 制限 | `Foundation` のみ — 他のフレームワーク禁止 |
| associated value | プリミティブ型・Foundation 型のみ — Entity/DTO 禁止 |
| 粒度 | 失敗ドメインごとに1つの enum — モノリシック `AppError` は禁止 |
| レイヤー間マッピング | 不要 — エラーは共有リーフ層の型をそのまま使う |
| ビジネスロジック | `Sources/Errors/` に置かない — 純粋なエラー定義のみ |

### 「なぜ Entity はリークさせないのにエラーは許すのか？」

Entity は構造と振る舞いを持ち、それに依存するとレイヤー間の結合が強くなります。エラーは enum の case 名と `LocalizedError` のメッセージだけを持つ純粋なシグナルであり、レイヤー間の結合を増やしません。この区別が「共有リーフ層」設計の根拠です。
