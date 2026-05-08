# Swift 入門ガイド — 10slide のコードで学ぶ Swift

> 対象: Swift を学び始めたばかりの人。実際のアプリのコードを読みながら「なぜこう書くのか？」を理解する。

このガイドは、macOS スライドショーアプリ **10slide** のソースコードを教材として、Swift の基礎概念からアーキテクチャパターンまでを解説します。各章は実際のソースファイルに対応しており、コードを読みながら学べる構成です。

さらに、開発中に実際に遭遇した **落とし穴（Pitfalls）** を各章に収録しています。「こう書くと動くように見えて壊れる」という実践知識は、教科書だけでは得られない内容です。

---

## 第1部: レイヤー別ガイド

10slide は以下のレイヤードアーキテクチャで構成されています。上から下へ、各レイヤーの役割とコード例を学びましょう。

```
Presentation → UseCases → Domain/Services → Repositories → Infrastructure
                              ↑
                         Domain/Entities
                         Errors (shared leaf layer)
```

### App — エントリポイント

| 章 | 学べること |
|----|-----------|
| [TenSlideApp](App/TenSlideApp.md) | `@main`、`App` プロトコル、`WindowGroup`、DI コンテナの起動 |

### Presentation — UI とユーザー操作

| 章 | 学べること |
|----|-----------|
| [SlideshowPlayerView](Presentation/SlideshowPlayerView.md) | SwiftUI ビュー構成、`ZStack`/`HStack`、`.task`、ジェスチャー処理、`@ViewBuilder`、トランジション |
| [SlideshowPlayerViewModel](Presentation/SlideshowPlayerViewModel.md) | `@Observable`、`@MainActor`、`async/await`、`Task` 管理 |

### UseCases — ユースケース

| 章 | 学べること |
|----|-----------|
| [CreateSlideshowUseCase](UseCases/CreateSlideshowUseCase.md) | UseCase パターン、Request/Response、`typealias` と `any`、ジェネリクス |

### Domain — ビジネスロジック

| 章 | 学べること |
|----|-----------|
| [Slide / Slideshow / SlideshowConfig / SlideDuration / TransitionType](Domain/Slide.md) | `struct`、`enum`、`Identifiable`、`Equatable`、`Sendable`、`CaseIterable`、ファクトリメソッド |
| [SlideshowDomainService](Domain/SlideshowDomainService.md) | Domain Service パターン、Repository プロトコル呼び出し |

### Repositories — データアクセス抽象

| 章 | 学べること |
|----|-----------|
| [SlideshowRepository](Repositories/SlideshowRepository.md) | Repository パターン、DTO 変換、SwiftData との橋渡し |

### DI — 依存性注入

| 章 | 学べること |
|----|-----------|
| [Container](DI/Container.md) | DI コンテナ、`final class`、レイヤーごとの依存関係の配線 |

### Infrastructure — 外部システム連携

| 章 | 学べること |
|----|-----------|
| [SwiftDataStore](Infrastructure/SwiftDataStore.md) | `@ModelActor`、ジェネリクス、`@Sendable` クロージャ、SwiftData 操作 |

---

## 第2部: トピック別 発展ガイド

レイヤーを横断するテーマを深掘りします。第1部を読んだあとに取り組むと効果的です。

| 章 | 学べること |
|----|-----------|
| [Swift Concurrency 実践ガイド](Topics/SwiftConcurrency.md) | `Sendable`、`@MainActor`、`Task.detached`、`@ModelActor`、`Mutex` |
| [SwiftData 実践ガイド](Topics/SwiftDataPractice.md) | 親子挿入順序、孤児レコード、マイグレーション、DTO パターン |
| [テスト実践ガイド](Topics/TestingPatterns.md) | 非同期テスト、`@Model` フィクスチャ、タイマーのパラメータ化 |
| [エラー設計ガイド](Topics/ErrorDesign.md) | 共有リーフ層、`LocalizedError`、エラー型の設計原則 |

---

## 読み方のおすすめ

1. **Swift 完全初心者** -- Domain/Slide.md から始める。`struct`、`enum`、プロトコル準拠の基本が学べる
2. **SwiftUI を学びたい** -- Presentation の2章を読む。ビューと ViewModel の関係がわかる
3. **アーキテクチャを理解したい** -- DI/Container.md → UseCases → Domain → Repositories → Infrastructure の順に読む
4. **実践的な落とし穴を知りたい** -- 各章末の「実践で学んだ落とし穴」セクション、および第2部のトピック別ガイド

各章の「落とし穴」セクションは、実際の開発で Claude が遭遇し、デバッグした事例をベースにしています。「なぜこの書き方ではダメなのか」を具体的なエラーメッセージや挙動とともに解説しているため、同じ問題に遭遇したときの解決の手がかりになります。
