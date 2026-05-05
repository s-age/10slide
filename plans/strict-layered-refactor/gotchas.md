# Gotchas

## テストファースト

1. **テストを先に書く** — テストが期待する振る舞いを定義する
2. **プロトコル境界でモックする** — 各レイヤーは独立してテスト
3. **モックの呼び出し回数をアサートする** — 戻り値だけでなく、協調オブジェクトとのインタラクションを検証
4. **Domain → Repository → UseCase → ViewModel** — 最内層から外に向かってテスト

### テスト実装順序

| 順序 | 対象 | モック対象 | 検証ポイント |
|------|------|-----------|-------------|
| 1 | PlaybackDomainService | なし（純粋計算） | nextIndex/previousIndex の境界値 |
| 2 | SlideshowDomainService | MockSlideshowRepository | save呼び出し回数、fetch→update→save順序 |
| 3 | ImageDomainService | MockImageRepository | filterDroppedFiles の拡張子フィルタリング |
| 4 | ConfigDomainService | MockConfigRepository | load/save委譲 |
| 5 | CreateSlideshowUseCase | MockSlideshowDomainService | validate()失敗時にServiceが呼ばれないこと、Response変換の正確性 |
| 6 | AdvanceSlideUseCase | MockPlaybackDomainService | validate()失敗時のthrow、Request→Service引数の正確な伝播 |
| 7 | SlideshowPlayerViewModel | MockAdvanceSlideUseCase + MockLoadSlideImageUseCase | Request構築の正確性、状態遷移 |

---

## アーキテクチ��上の注意点

### Domain/Entities の `nextSlideIndex` / `previousSlideIndex` メソッド

`Slideshow` エンティティに残っているこれらのメソッドは、`PlaybackDomainService` に移行後は **使われなくなる**。削除するかdeprecatedとして残すか判断が必要。

**推奨**: 削除する。Domain Service がこのロジックを所有するため、エンティティ上の重複は混乱を招く。

### `UpdateSlideshowConfigUseCase` の永続化判断

現在の実装はconfig変更を永続化しない（インメモリ変換のみ）。新アーキテクチャでは：
- `SlideshowDomainService.fetch()` で取得 → `PlaybackService.applyConfig()` で変換 → Responseとして返す
- **永続化するかどうかは要検討**: 再生中のconfig変更を毎回DBに書き込むか、セッション終了時にまとめて保存するか

**推奨**: 現状維持（永���化しない）。再生中のconfig変更はインメモリのみ。ユーザーが明示的に保存するまでDBには書かない。ただし `domainService.fetch()` は毎回呼ぶ必要がなくなるため、Requestに現在のスライドショー状態を含める方向に変更する余地あり。

### Response型の `Codable` 非準拠

Response型には意図的に `Codable` を付けない。これはAPIレスポンスではなく、レイヤー間の受け渡し専用型。永続化が必要な場合はRequestとして明示的にUseCase経由でDomain→Repositoryに流す。

### `SlideDurationResponse.seconds` の重複

`SlideDuration`（Domain）と `SlideDurationResponse`（UseCase）の両方に `seconds` computed property がある。これは意図的な重複：
- Domain側: Domain Service内のロジックで使用
- Response側: Presentation内の表示・タイマーロジックで使用

両者は同じ値を返すが、コンパイル時に別型として扱われるため型安全。

### `toDomain` の可視性

`SlideDurationResponse.toDomain` / `TransitionTypeResponse.toDomain` / `SlideshowConfigResponse.toDomain` はUseCase層の内部実装。Presentationからは呼べないよう `internal` アクセスレベルで十分（Presentation と UseCases は同一モジュールのため、将来的にSwift Package化する場合は `package` or モジュール分離が必要）。

**当面の対応**: 同一ターゲット内では `internal` で見えてしまうが、SwiftLintルールで `toDomain` のPresentation内使用を禁止する。

### Swift 6 Sendable と DomainContainer

`DomainContainer` は全プロパティが `let` かつ `Sendable` プロトコル準拠のexistentialなので、`Sendable` を明示宣言できる。`PlaybackDomainService` はステートレスのため問題なし。
