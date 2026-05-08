# テスト実践ガイド — XCTest で確実に動くテストを書く

**種別:** 発展編（トピック横断ガイド）

Swift の非同期処理や SwiftData を使ったコードのテストには、知らないとハマる落とし穴がいくつかあります。このガイドでは、10slide の開発で実際に遭遇した問題と、テストを確実に動かすためのパターンをまとめます。

---

## 概要

| テストの課題 | 症状 | 解決パターン |
|------------|------|------------|
| `XCTAssertThrowsError` が async で使えない | コンパイルエラー | `do/catch` + `XCTFail` パターン |
| Repository テストに実際の SwiftData が必要 | `ModelContainer` のセットアップが必要 | in-memory `ModelContainer` + 実際の `SwiftDataStore` |
| `@ModelActor` のテスト方法が不明 | 単体と統合の区別がつかない | プロトコルモックと in-memory コンテナの使い分け |
| タイマー付き ViewModel のテストが遅い | 本番の `Duration` で待つ必要がある | `Duration` をパラメータ化して短縮 |

---

## 1. 非同期テストで XCTAssertThrowsError が使えない問題と回避策

### 問題

`XCTAssertThrowsError` のクロージャは `async` に対応していません。非同期メソッドのエラーを検証しようとすると、コンパイルエラーになります。

### 間違った例

```swift
// ❌ Compile error: async call in an autoclosure that does not support concurrency
func testLoad_whenInvalidYAML_throws() async throws {
    await XCTAssertThrowsError(try await sut.load())
}
```

`XCTAssertThrowsError` の引数は `@autoclosure` であり、`async` クロージャを受け取るオーバーロードが存在しないためです。

### 正しい例

```swift
// ✅ do/catch + XCTFail pattern
func testLoad_whenInvalidYAML_throws() async {
    do {
        _ = try await sut.load()
        XCTFail("Expected load() to throw")  // If we reach here, the test fails
    } catch {
        // Error was thrown as expected
    }
}
```

### エラーの種類まで検証したい場合

```swift
// ✅ Verify a specific error type (using actual error types from the codebase)
// SlideshowDomainService.update throws DomainError.slideshowNotFound when the ID doesn't exist
func testUpdate_whenNotFound_throwsDomainError() async {
    let unknownID = UUID()
    do {
        _ = try await sut.update(id: unknownID, name: "x", localIdentifiers: ["a"])
        XCTFail("Expected update() to throw DomainError.slideshowNotFound")
    } catch {
        guard case DomainError.slideshowNotFound(let id) = error else {
            return XCTFail("Unexpected error type: \(error)")
        }
        XCTAssertEqual(id, unknownID)
    }
}
```

### ルール

- 非同期のエラーテストには `do/catch` + `XCTFail` を使う
- `try?` でエラーを握りつぶす書き方はしない — エラーが投げられたかどうかが不明になる
- `XCTestExpectation` + `fulfill()` は不要 — `do/catch` の方がシンプル

---

## 2. Repository テストは in-memory コンテナで実際の SwiftDataStore を使う

### 問題

10slide では、Repository は `SwiftDataStoreProtocol`（`@ModelActor` アクター）に依存しています。これをどうテストすべきでしょうか？ Repository の中核ロジックは `FetchDescriptor` や `#Predicate` 式の構築にあり、これらは実際の SwiftData でしか動作しないため、**Repository テストは統合テスト**として、in-memory `ModelContainer` を使った実際の `SwiftDataStore` で実行します。

### 実際のテストパターン（`SlideshowRepositoryTests` より）

```swift
final class SlideshowRepositoryTests: XCTestCase {
    private var sut: SlideshowRepository!
    private var store: SwiftDataStore!
    private var container: ModelContainer!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([SlideshowModel.self, SlideModel.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        store = SwiftDataStore(modelContainer: container)
        sut = SlideshowRepository(store: store)
    }

    override func tearDown() async throws {
        sut = nil
        store = nil
        container = nil
        try await super.tearDown()
    }

    func testFetchAll_onEmpty_returnsEmptyArray() async throws {
        let result = try await sut.fetchAll()
        XCTAssertTrue(result.isEmpty)
    }
}
```

### 使い分けの基準

| テスト対象 | 戦略 | SwiftData 依存 |
|-----------|------|---------------|
| `SwiftDataStore`（Infrastructure） | 統合テスト — in-memory `ModelContainer` | あり |
| Repository | 統合テスト — 実際の `SwiftDataStore` + in-memory コンテナ | あり |
| UseCase | 単体テスト — Repository プロトコルをモック | なし |
| ViewModel | 単体テスト — UseCase プロトコルをモック | なし |

### ルール

- Repository テストは**統合テスト**である — `FetchDescriptor` と `#Predicate` は実際の SwiftData でしか動作しないため、実際の `SwiftDataStore` を使う
- 必ず `isStoredInMemoryOnly: true` を使う — ディスク上のストアはテスト間で状態が残る
- `tearDown()` で `sut`、`store`、`container` を `nil` に設定し、状態のリークを防ぐ

---

## 3. UseCase と ViewModel のテスト — プロトコルモック

### 問題

UseCase は Domain Service に依存し、ViewModel は UseCase に依存しています。依存チェーン全体を引き込まずにテストするにはどうすればよいでしょうか？

### パターン：プロトコル境界でモックする

各レイヤーは依存先のプロトコルを定義しています。テストでは、そのプロトコルを実装した `Mock*` クラスを作成し、戻り値の設定や呼び出し回数のカウントを行います。

```swift
// ✅ Mock for an async use case (from SlideshowPlayerViewModelTests)
final class MockLoadSlideImageUseCase: AsyncUseCase, @unchecked Sendable {
    // Minimal valid 1x1 pixel PNG
    var executeResult: Data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUg...")!
    var executeCallCount = 0
    var throwOnExecute = false

    func execute(_ request: LoadSlideImageRequest) async throws -> Data {
        executeCallCount += 1
        if throwOnExecute { throw SlideshowPlayerTestError.intentional }
        return executeResult
    }
}
```

```swift
// ✅ Mock for a sync use case — contains real navigation logic (from SlideshowPlayerViewModelTests)
final class MockAdvanceSlideUseCase: SyncUseCase, @unchecked Sendable {
    func execute(_ request: AdvanceSlideRequest) throws -> Int? {
        let next = request.currentIndex + 1
        if next < request.totalSlides {
            return next
        } else if request.loop {
            return 0
        }
        return nil
    }
}
```

### ViewModel テストには `@MainActor` が必要

ViewModel は `@MainActor` で注釈されているため、それを生成・操作するテストクラスも `@MainActor` でなければなりません。

```swift
@MainActor
final class SlideshowPlayerViewModelTests: XCTestCase {
    private var mockLoadSlideImage: MockLoadSlideImageUseCase!
    private var sut: SlideshowPlayerViewModel!

    override func setUp() {
        mockLoadSlideImage = MockLoadSlideImageUseCase()
        // ... (other mocks initialized here)
        sut = SlideshowPlayerViewModel(
            slideshow: Self.makeSlideshow(
                slides: [
                    Self.makeSlide(identifier: "a", order: 0),
                    Self.makeSlide(identifier: "b", order: 1),
                    Self.makeSlide(identifier: "c", order: 2)
                ],
                loop: false
            ),
            loadSlideImage: mockLoadSlideImage,
            updateSlideshowConfig: mockUpdateSlideshowConfig,
            advanceSlide: mockAdvanceSlide,
            previousSlide: mockPreviousSlide,
            filmstripHideDuration: .milliseconds(50)  // Short duration for fast tests
        )
    }
}
```

### テスト戦略の選び方

| テスト対象 | テスト種別 | SwiftData 依存 | モック対象 |
|-----------|----------|---------------|----------|
| `SwiftDataStore`（Infrastructure） | 統合テスト | in-memory `ModelContainer` | なし |
| Repository | 統合テスト | in-memory `ModelContainer` + 実際のストア | なし |
| UseCase | 単体テスト | なし | Domain Service プロトコル |
| ViewModel | 単体テスト | なし | UseCase プロトコル |

### ルール

- プロトコル境界でモックする — 具象クラスをモックしない
- `@unchecked Sendable` はテストのセットアップでミューテーションが制御されるモック型にのみ使う
- ViewModel のテストクラスには `@MainActor` を付ける
- `AsyncUseCase` と `SyncUseCase` の両方のモックが必要（コードベースでは両方を使用）

---

## 4. タイマー付き ViewModel のテスト — Duration をパラメータ化する

### 問題

ViewModel にタイマー制御の機能（自動非表示、自動送りなど）がある場合、本番の `Duration`（例: 3秒）でテストすると遅すぎます。かといって `Duration` をハードコードすると、テストで短縮できません。

### 間違った例

```swift
// ❌ Duration is hardcoded and cannot be changed in tests
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private(set) var showFilmstrip = true

    private func scheduleHideFilmstrip() {
        hideFilmstripTask = Task {
            try? await Task.sleep(for: .seconds(3))  // Test has to wait 3 seconds
            guard !Task.isCancelled else { return }
            showFilmstrip = false
        }
    }
}
```

```swift
// ❌ Test is slow
func testPlay_hidesFilmstripAfterDuration() async throws {
    sut.play()
    try await Task.sleep(for: .seconds(4))  // Waiting 4 seconds...
    XCTAssertFalse(sut.showFilmstrip)
}
```

### 正しい例

```swift
// ✅ Make Duration an init parameter with a default value to preserve production behavior
// (actual pattern from SlideshowPlayerViewModel)
@Observable
@MainActor
final class SlideshowPlayerViewModel {
    private(set) var showFilmstrip = true
    private let filmstripHideDuration: Duration

    init(
        ...,
        filmstripHideDuration: Duration = .seconds(3)  // Production default
    ) {
        self.filmstripHideDuration = filmstripHideDuration
    }

    private func scheduleHideFilmstrip() {
        hideFilmstripTask = Task {
            try? await Task.sleep(for: filmstripHideDuration)
            guard !Task.isCancelled else { return }
            showFilmstrip = false
        }
    }
}
```

```swift
// ✅ Inject a short Duration in tests — completes quickly
// (actual pattern from SlideshowPlayerViewModelTests)
func testPlay_hidesFilmstripAfterDuration() async throws {
    sut = SlideshowPlayerViewModel(
        ...,
        filmstripHideDuration: .milliseconds(50)  // Completes in 50ms
    )

    sut.play()
    try await Task.sleep(for: .milliseconds(100))  // Sufficient wait time
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
| in-memory `ModelContainer` | Repository テストに実際の SwiftData が必要 | `isStoredInMemoryOnly: true` + 実際の `SwiftDataStore` |
| プロトコルモック | UseCase/ViewModel の単体テスト | プロトコル境界でモック + 呼び出しカウンター |
| `@MainActor` テストクラス | ViewModel テストにメインアクターが必要 | テストクラスに `@MainActor` を付与 |
| Duration パラメータ化 | タイマー付き ViewModel のテストが遅い | `init` パラメータ + デフォルト値 |

### 原則

1. **Repository テストは統合テスト**である — `FetchDescriptor` と `#Predicate` は実際の SwiftData でしか動作しないため
2. **UseCase と ViewModel のテストは単体テスト**である — プロトコルモックで依存を排除する
3. **統合テストは in-memory で行う** — ディスクの状態がテストを汚染しない
4. **時間に依存するテストは Duration を注入する** — テストの速度と信頼性を両立させる
