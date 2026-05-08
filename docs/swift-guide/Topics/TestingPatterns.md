# テスト実践ガイド — XCTest で確実に動くテストを書く

**種別:** 発展編（トピック横断ガイド）

Swift の非同期処理や SwiftData を使ったコードのテストには、知らないとハマる落とし穴がいくつかあります。このガイドでは、10slide の開発で実際に遭遇した問題と、テストを確実に動かすためのパターンをまとめます。

---

## 概要

| テストの課題 | 症状 | 解決パターン |
|------------|------|------------|
| `XCTAssertThrowsError` が async で使えない | コンパイルエラー | `do/catch` + `XCTFail` パターン |
| `@Model` テストフィクスチャが重い | `ModelContainer` のセットアップが必要 | コンテキストなしで `@Model` を直接作成 |
| `@ModelActor` のテスト方法が不明 | 単体と統合の区別がつかない | プロトコルモックと in-memory コンテナの使い分け |
| タイマー付き ViewModel のテストが遅い | 本番の Duration で待つ必要がある | `Duration` をパラメータ化して短縮 |

---

## 1. 非同期テストで XCTAssertThrowsError が使えない問題と回避策

### 問題

`XCTAssertThrowsError` のクロージャは `async` に対応していません。非同期メソッドのエラーを検証しようとすると、コンパイルエラーになります。

### 間違った例

```swift
// ❌ コンパイルエラー：async call in an autoclosure that does not support concurrency
func testLoad_whenInvalidYAML_throws() async throws {
    await XCTAssertThrowsError(try await sut.load())
}
```

`XCTAssertThrowsError` の引数は `@autoclosure` であり、`async` クロージャを受け取る overload が存在しないためです。

### 正しい例

```swift
// ✅ do/catch + XCTFail パターン
func testLoad_whenInvalidYAML_throws() async {
    do {
        _ = try await sut.load()
        XCTFail("Expected load() to throw")  // ここに到達したらテスト失敗
    } catch {
        // 期待通りエラーが投げられた
    }
}
```

### エラーの種類まで検証したい場合

```swift
// ✅ 特定のエラー型を検証する
func testLoad_whenFileNotFound_throwsConfigError() async {
    do {
        _ = try await sut.load()
        XCTFail("Expected load() to throw ConfigError.fileNotFound")
    } catch let error as ConfigError {
        XCTAssertEqual(error, .fileNotFound)
    } catch {
        XCTFail("Unexpected error type: \(error)")
    }
}
```

### ルール

- 非同期のエラーテストには `do/catch` + `XCTFail` を使う
- `try?` でエラーを握りつぶす書き方はしない — エラーが投げられたかどうかが不明になる
- `XCTestExpectation` + `fulfill()` は不要 — `do/catch` の方がシンプル

---

## 2. @Model インスタンスは ModelContext なしで作れる — テストフィクスチャの軽量化

### 問題

`@Model` を使ったテストで毎回 `ModelContainer` + `ModelContext` をセットアップすると、テストが重くなります。しかし実は、`@Model` インスタンスは **コンテキストなしで** 作成・操作できます。

### なぜ動くのか？

`@Model` マクロは内部に `_$backingData` というバッキングストレージを生成します。これはコンテキストがなくてもインメモリで動作します。永続化（save/fetch）にはコンテキストが必要ですが、プロパティの読み書きやリレーションの代入はインメモリだけで完結します。

### 間違った例

```swift
// ❌ 単体テストなのに ModelContainer を毎回セットアップ — 過剰
func setUp() async throws {
    let schema = Schema([SlideshowModel.self, SlideModel.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])
    let context = ModelContext(container)

    let model = SlideshowModel(id: UUID(), name: "Test")
    context.insert(model)
    try context.save()
    // ... これは統合テストの準備
}
```

### 正しい例

```swift
// ✅ コンテキストなしで @Model フィクスチャを作成（単体テスト向け）
func setUp() {
    let model = SlideshowModel(id: UUID(), name: "Test")
    model.slides = [
        SlideModel(id: UUID(), localIdentifier: "slide-1", order: 0, duration: 3.0),
        SlideModel(id: UUID(), localIdentifier: "slide-2", order: 1, duration: 5.0),
    ]

    // モックのデータソースにそのまま渡せる
    mockDataSource.fetchAllResult = [model]
}
```

### いつ ModelContainer が必要か？

| テスト種別 | ModelContainer | 用途 |
|-----------|---------------|------|
| 単体テスト（Repository 等） | **不要** | モックにフィクスチャを渡すだけ |
| 統合テスト（DataSource 等） | **必要**（in-memory） | 実際の save/fetch を検証 |

### ルール

- 単体テストでは `@Model` をコンテキストなしで直接作成する
- リレーション配列の代入（`model.slides = [...]`）もコンテキストなしで動く
- ただし、逆方向リレーション（`slide.slideshow`）はコンテキスト内でのみ自動設定される — テストでは自分が設定した方向だけを検証する

---

## 3. @ModelActor のテスト戦略 — 単体テスト vs 統合テスト

### 問題

`@ModelActor` を使ったデータソースはどうテストすべきか？データソース自体のテストと、それを使う Repository のテストで戦略が異なります。

### 統合テスト：in-memory ModelContainer で実際の永続化を検証

データソース自体の正しさを検証するには、実際の `ModelContainer` が必要です。ただし、テスト間でデータが残らないよう **in-memory 構成** を使います。

```swift
// ✅ 統合テスト — データソースの実動作を検証
final class SlideshowDataSourceTests: XCTestCase {
    private var container: ModelContainer!
    private var sut: SlideshowDataSource!

    override func setUp() async throws {
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        sut = SlideshowDataSource(modelContainer: container)
    }

    func testSaveAndFetchAll() async throws {
        let dto = SlideshowDTO(id: UUID(), name: "Test", slides: [])
        try await sut.save(dto)

        let results = try await sut.fetchAll()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Test")
    }
}
```

### 単体テスト：プロトコルモックで SwiftData を排除

Repository のテストでは、データソースのプロトコルをモックし、SwiftData への依存を完全に排除します。

```swift
// ✅ 単体テスト — データソースをモック
final class MockSlideshowDataSource: SlideshowDataSourceProtocol, @unchecked Sendable {
    var fetchAllResult: [SlideshowDTO] = []
    var saveCallCount = 0

    func fetchAll() async throws -> [SlideshowDTO] {
        fetchAllResult
    }

    func save(_ dto: SlideshowDTO) async throws {
        saveCallCount += 1
    }
}

final class SlideshowRepositoryTests: XCTestCase {
    private var mockDataSource: MockSlideshowDataSource!
    private var sut: SlideshowRepository!

    override func setUp() {
        mockDataSource = MockSlideshowDataSource()
        sut = SlideshowRepository(dataSource: mockDataSource)
    }

    func testFetchAll_returnsConvertedEntities() async throws {
        mockDataSource.fetchAllResult = [
            SlideshowDTO(id: UUID(), name: "Test", slides: [])
        ]

        let results = try await sut.fetchAll()
        XCTAssertEqual(results.count, 1)
    }
}
```

### テスト戦略の使い分け

| テスト対象 | テスト種別 | SwiftData 依存 | モック対象 |
|-----------|----------|---------------|----------|
| DataSource（Infrastructure） | 統合テスト | in-memory ModelContainer | なし |
| Repository | 単体テスト | なし | DataSource プロトコル |
| UseCase | 単体テスト | なし | Repository プロトコル |
| ViewModel | 単体テスト | なし | UseCase プロトコル |

### ルール

- 統合テストでは `isStoredInMemoryOnly: true` を必ず使う — ディスク上のストアはテスト間で状態が残る
- `@Model` クラスを直接モックしない — DTO プロトコルレベルでモックする
- 同じ `ModelContainer` をテストメソッド間で共有する場合は、各テストの先頭でデータをリセットする

---

## 4. タイマー付き ViewModel のテスト — Duration をパラメータ化する

### 問題

ViewModel にタイマー制御の機能（自動非表示、自動送り など）がある場合、本番の `Duration`（例: 3秒）でテストすると遅すぎます。かといって `Duration` をハードコードすると、テストで短縮できません。

### 間違った例

```swift
// ❌ Duration がハードコードされていてテストで変更できない
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    var showFilmstrip = true

    func startAutoHide() {
        Task {
            try await Task.sleep(for: .seconds(3))  // テストで 3 秒待つことになる
            showFilmstrip = false
        }
    }
}
```

```swift
// ❌ テストが遅い
func testAutoHide() async throws {
    sut.startAutoHide()
    try await Task.sleep(for: .seconds(4))  // 4 秒も待つ...
    XCTAssertFalse(sut.showFilmstrip)
}
```

### 正しい例

```swift
// ✅ Duration を init パラメータにしてデフォルト値で本番動作を維持
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    var showFilmstrip = true
    private let filmstripHideDuration: Duration

    init(
        ...,
        filmstripHideDuration: Duration = .seconds(3)  // 本番デフォルト
    ) {
        self.filmstripHideDuration = filmstripHideDuration
    }

    func startAutoHide() {
        Task {
            try await Task.sleep(for: filmstripHideDuration)
            showFilmstrip = false
        }
    }
}
```

```swift
// ✅ テストでは短い Duration を注入 — 高速に完了
func testAutoHide() async throws {
    sut = SlideshowPlayerViewModel(
        ...,
        filmstripHideDuration: .milliseconds(50)  // 50ms で完了
    )

    sut.startAutoHide()
    try await Task.sleep(for: .milliseconds(100))  // 十分な待ち時間
    XCTAssertFalse(sut.showFilmstrip)
}
```

### パラメータ化の判断基準

| 対象 | パラメータ化する？ | 理由 |
|------|-----------------|------|
| タイマーで状態を変更する Duration | する | テストで観測する必要がある |
| アニメーションの Duration | **しない** | テストで状態変化を観測しない |
| デバウンスの Duration | する | テストでデバウンス後の状態を検証する |

### ルール

- テストで観測する必要がある `Duration` は `init` のパラメータにする
- 本番のデフォルト値は `init` のデフォルト引数で指定 — 呼び出し側は変更不要
- `XCTestExpectation` + `fulfill()` ではなく `async throws` テスト + `Task.sleep` を使う

---

## まとめ

| パターン | 問題 | 解決策 |
|---------|------|--------|
| `do/catch` + `XCTFail` | `XCTAssertThrowsError` が async 未対応 | `do { try await ...; XCTFail() } catch { }` |
| コンテキストなし `@Model` | テストフィクスチャのセットアップが重い | `@Model` はコンテキストなしで作成可能 |
| プロトコルモック | `@ModelActor` の単体テスト方法 | DTO プロトコルレベルでモック |
| in-memory ModelContainer | `@ModelActor` の統合テスト方法 | `isStoredInMemoryOnly: true` |
| Duration パラメータ化 | タイマー付き ViewModel のテストが遅い | `init` パラメータ + デフォルト値 |

### 原則

1. **単体テストでは SwiftData に触らない** — プロトコルモックで依存を排除する
2. **統合テストは in-memory で行う** — ディスクの状態がテストを汚染しない
3. **時間に依存するテストは Duration を注入する** — テストの速度と信頼性を両立させる
