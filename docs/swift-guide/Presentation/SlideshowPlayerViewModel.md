# SlideshowPlayerViewModel — Swift 概念ガイド

**対象ファイル**: `Sources/Presentation/ViewModels/SlideshowPlayerViewModel.swift`

**概要**: スライドショーの再生状態を管理する ViewModel。再生・一時停止・次へ・前へといった操作を受け付け、画像の非同期ロード、シャッフル、スライド時間やトランジションの更新、フィルムストリップ（サムネイル一覧）の表示/非表示、フルスクリーンヒントの表示をすべてこのクラスが調整する。

---

## 目次

1. [`import Observation` — Observation フレームワーク](#1-import-observation--observation-フレームワーク)
2. [`@Observable` — 監視可能なクラス](#2-observable--監視可能なクラス)
3. [`@MainActor` — メインアクター](#3-mainactor--メインアクター)
4. [`final class` — 継承禁止のクラス](#4-final-class--継承禁止のクラス)
5. [`private(set)` — 外部読み取り専用プロパティ](#5-privateset--外部読み取り専用プロパティ)
6. [ネストされた `enum`（FullscreenHintType）](#6-ネストされた-enumfullscreenhinttype)
7. [`any Protocol` — 存在型（Existential type）](#7-any-protocol--存在型existential-type)
8. [`async` / `await` — 非同期処理](#8-async--await--非同期処理)
9. [`Task { }` / `Task.isCancelled` — 構造化された並行処理](#9-task---taskiscancelled--構造化された並行処理)
10. [`Task.sleep(for:)` — 非同期スリープ](#10-tasksleepfor--非同期スリープ)
11. [`Task.detached(priority:)` — デタッチドタスク](#11-taskdetachedpriority--デタッチドタスク)
12. [`guard` 文 — 早期リターン](#12-guard-文--早期リターン)
13. [`defer { }` — 遅延実行](#13-defer---遅延実行)
14. [`try` / `do-catch` — エラーハンドリング](#14-try--do-catch--エラーハンドリング)
15. [Task ベースのタイマーパターン](#15-task-ベースのタイマーパターン)
16. [実践で学んだ落とし穴](#16-実践で学んだ落とし穴)
17. [このファイルで学べること — まとめ](#17-このファイルで学べること--まとめ)

---

## 1. `import Observation` — Observation フレームワーク

### 何であるか

`import Observation` は Apple が Swift 5.9 で導入した **Observation フレームワーク**を取り込む宣言です。このフレームワークは「あるオブジェクトのプロパティが変わったとき、それを見ている側（SwiftUI の View など）に自動で通知する」仕組みを提供します。

### なぜここで使われているか

ViewModel のプロパティ（`isPlaying`、`currentNSImage` など）が変わったとき、SwiftUI の画面を自動で再描画させるためです。`import Observation` なしでは次に出てくる `@Observable` マクロが使えません。

### もし使わなかったら

古い `ObservableObject` + `@Published` の組み合わせを使うことになります（後述）。

```swift
import Observation  // ← これがないと @Observable が使えない
```

---

## 2. `@Observable` — 監視可能なクラス

### 何であるか

`@Observable` は Swift マクロ（コンパイル時にコードを自動生成する仕組み）です。クラスに付けると、**全ての `var` プロパティへのアクセスを自動で追跡**し、値が変わったとき SwiftUI の View に「再描画してください」と伝えます。

### なぜここで使われているか

`SlideshowPlayerViewModel` は `isPlaying` や `currentNSImage` など View が表示に使うプロパティを多数持っています。これらが変わるたびに View が自動更新されるよう、`@Observable` でクラス全体を「監視対象」にしています。

### `ObservableObject` との違い

| 比較項目 | `@Observable`（新） | `ObservableObject`（旧） |
|---------|-------------------|------------------------|
| 導入バージョン | Swift 5.9 / iOS 17 | iOS 13 |
| 宣言の手間 | クラスに `@Observable` だけ | `@Published` を各プロパティに付ける必要あり |
| 追跡の精度 | **アクセスしたプロパティだけ**再描画 | `@Published` があるプロパティが変わると View 全体を再描画 |
| View 側の記述 | `let` や `@Bindable var` で受け取るだけ | `@ObservedObject` や `@StateObject` が必要 |

### もし使わなかったら

```swift
// 旧スタイル（ObservableObject）
class SlideshowPlayerViewModel: ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentNSImage: NSImage?
    // ... 全プロパティに @Published が必要
}
```

```swift
// 新スタイル（@Observable）— このファイルの書き方
@Observable
final class SlideshowPlayerViewModel {
    private(set) var isPlaying: Bool = false
    private(set) var currentNSImage: NSImage?
    // @Published は不要
}
```

```swift
// ファイル内の該当部分
@Observable
@MainActor
final class SlideshowPlayerViewModel {
```

---

## 3. `@MainActor` — メインアクター

### 何であるか

`@MainActor` は「このクラスのすべてのコードをメインスレッド（UI スレッド）で実行することを保証する」という宣言です。Swift の **アクター**（actor）は「一度に一つのコードしか実行しない安全な実行コンテキスト」で、`MainActor` はその中でも特別な「メインスレッド専用のアクター」です。

### なぜここで使われているか

SwiftUI の View は**必ずメインスレッドから更新しなければなりません**。`@Observable` でプロパティが変わると View が更新されるため、プロパティへの書き込みもメインスレッドで行う必要があります。`@MainActor` をクラス全体に付けることで、「このクラスのどのメソッドを呼んでもメインスレッドで動く」が保証されます。

### もし使わなかったら

非同期処理の中でうっかりバックグラウンドスレッドからプロパティを書き換えると、クラッシュや予期しない描画バグが発生します。Swift 6 のコンパイラはこれをエラーとして検出するため、`@MainActor` なしでは多くの箇所でコンパイルエラーが出ます。

```swift
@Observable
@MainActor  // ← クラス全体をメインスレッドに縛る
final class SlideshowPlayerViewModel {
```

---

## 4. `final class` — 継承禁止のクラス

### 何であるか

`final` を付けたクラスは**サブクラス（継承）を作れない**クラスです。`class SlideshowPlayerViewModel` だと他のクラスが `class MyVM: SlideshowPlayerViewModel { }` のように継承できますが、`final class` にするとコンパイルエラーになります。

### なぜここで使われているか

理由は二つあります。

1. **設計の意図を伝える**: ViewModel はこのクラス単体で完結する設計であり、継承して拡張することを想定していない。
2. **パフォーマンスの最適化**: `final` が付いていると、コンパイラがメソッド呼び出しを静的ディスパッチ（直接関数アドレスにジャンプ）で解決でき、わずかに速くなります。

### もし使わなかったら

`final` なし (`class SlideshowPlayerViewModel`) でも動作しますが、「このクラスを継承してはいけない」という設計上のルールがコードから見えなくなります。

```swift
final class SlideshowPlayerViewModel {  // final = 継承禁止
```

---

## 5. `private(set)` — 外部読み取り専用プロパティ

### 何であるか

`private(set)` は「**読み取りは外部から OK、書き込みはクラス内部からのみ**」というアクセス制御です。

| 修飾子 | クラス内から | クラス外から |
|--------|------------|------------|
| `var` | 読み書き可 | 読み書き可 |
| `private var` | 読み書き可 | 読めない・書けない |
| `private(set) var` | 読み書き可 | **読める・書けない** |

### なぜここで使われているか

View は `isPlaying` や `currentNSImage` の値を**表示のために読む**必要がありますが、**直接書き換えてはいけません**（書き換えは `play()` や `pause()` などのメソッド経由で行う）。`private(set)` によってこのルールをコンパイラに強制させています。

### もし使わなかったら

`var isPlaying: Bool = false` にすると、View から `viewModel.isPlaying = true` と書けてしまい、ViewModel のロジックをバイパスしたバグが生まれやすくなります。

```swift
private(set) var slideshow: SlideshowResponse   // 外から読める・外から書けない
private(set) var currentIndex: Int = 0
private(set) var isPlaying: Bool = false
private var shuffledSlides: [SlideResponse]?    // 外から読めない・書けない
```

---

## 6. ネストされた `enum`（FullscreenHintType）

### 何であるか

`enum`（列挙型）は「取り得る値の種類をあらかじめ列挙した型」です。このファイルでは `FullscreenHintType` というクラス**内部**に `enum` を定義しています。これを**ネストされた型**（Nested Type）と呼びます。

```swift
enum FullscreenHintType: Equatable {
    case enter   // フルスクリーンに入るヒント
    case exit    // フルスクリーンから出るヒント
}
```

### `Equatable` の意味

`: Equatable` は「`==` 演算子で比較できる」という約束です。`FullscreenHintType` は `case` が二つしかないので Swift が自動で `==` を実装してくれます。

### なぜクラスの内部に定義するか

`FullscreenHintType` は `SlideshowPlayerViewModel` だけが使う型なので、外部に公開する必要がありません。クラスの内部に書くことで「この型はこのクラス専用」という意図を示します。外から参照したい場合は `SlideshowPlayerViewModel.FullscreenHintType` と書きます。

### もし enum を使わなかったら

```swift
// Bad: 文字列で種類を表すと、タイポが実行時エラーになる
var fullscreenHint: String? = "enter"   // "entter" と書いても気づけない

// Good: enum なら存在しない値はコンパイルエラー
var fullscreenHint: FullscreenHintType? = .enter
```

```swift
// クラス内にネストされた enum
enum FullscreenHintType: Equatable {
    case enter
    case exit
}

private(set) var fullscreenHint: FullscreenHintType? = nil
```

---

## 7. `any Protocol` — 存在型（Existential type）

### 何であるか

`any LoadSlideImageUseCaseProtocol` の `any` は「このプロトコルに準拠する**何らかの型**を入れられる箱」を意味します。これを**存在型**（Existential type）と呼びます。Swift 5.7 以降、存在型には `any` を明示的に書く必要があります。

### なぜここで使われているか

ViewModel は「画像をロードする処理」が必要ですが、その**具体的な実装は知らなくてよい**という設計です。テスト時にはモック（偽物）を、本番時には実際の実装を渡せるよう、具体的な型ではなくプロトコル（約束事）に依存しています。これを**依存性注入**（Dependency Injection）と言います。

### `any` なしとの違い

Swift 5.6 以前は `any` を書かなくてもエラーになりませんでしたが、Swift 5.7 以降は存在型に `any` を付けることが推奨（将来は必須）になりました。明示的に書くことで「ここは具体型ではなく存在型を使っている」と読み手に伝わります。

```swift
// ViewModel は具体的な実装クラスを知らない
private let loadSlideImage: any LoadSlideImageUseCaseProtocol
private let updateSlideshowConfig: any UpdateSlideshowConfigUseCaseProtocol
private let advanceSlide: any AdvanceSlideUseCaseProtocol
private let previousSlide: any PreviousSlideUseCaseProtocol
```

```swift
// init で外から「何らかの実装」を受け取る
init(
    slideshow: SlideshowResponse,
    loadSlideImage: any LoadSlideImageUseCaseProtocol,  // ← 存在型
    ...
) {
    self.loadSlideImage = loadSlideImage
```

> **注**: このプロジェクトでは UseCase プロトコルの型エイリアスが `any` を内包しているため、実際のコード上では `any` を省略して書いている箇所があります。コンパイラが自動で解決します。

---

## 8. `async` / `await` — 非同期処理

### 何であるか

`async` は「この関数は非同期処理を含む（完了まで時間がかかることがある）」という印で、`await` は「ここで非同期処理の完了を待ちます」という印です。

処理が完了するまでの間、スレッドをブロック（占有）せずに他の処理を進めることができます。

### なぜここで使われているか

写真の画像データをディスクやフォトライブラリから読み込む処理は時間がかかります。`await` を使うと「読み込み中も UI がフリーズしない」状態を保てます。

### もし使わなかったら

昔ながらのコールバック（クロージャ）で書くと：

```swift
// 旧スタイル（コールバック）
func loadCurrentImage(completion: @escaping (NSImage?) -> Void) {
    loadSlideImage.execute(request) { result in
        switch result {
        case .success(let data):
            completion(NSImage(data: data))
        case .failure:
            completion(nil)
        }
    }
}
```

`async/await` を使うと：

```swift
// 新スタイル — このファイルの書き方
func loadCurrentImage() async {
    let data = try await loadSlideImage.execute(request)
    currentNSImage = NSImage(data: data)
}
```

コールバックのネスト（いわゆる「コールバック地獄」）がなくなり、上から下へ読める直線的なコードになります。

```swift
// async 関数の例
func toggleShuffle() async { ... }
func next() async { ... }
func loadCurrentImage() async { ... }
```

---

## 9. `Task { }` / `Task.isCancelled` — 構造化された並行処理

### 何であるか

`Task { }` は**非同期処理の単位**を作るコンテナです。`async` 関数を呼び出したいが、今いるコードが `async` でない（同期関数の中）という場合に `Task { }` でくるんで非同期文脈を作ります。

`Task.isCancelled` は「このタスクがキャンセルされたかどうか」を確認する Bool プロパティです。

### なぜここで使われているか

`play()` メソッドは同期関数ですが、スライドを一定間隔で切り替えるループを非同期で回し続ける必要があります。そのループを `Task { ... }` の中に書き、タスクへの参照を `timerTask` に保存しておくことで「後からキャンセルできるタイマー」を実現しています。

```swift
func play() {
    ...
    timerTask?.cancel()       // 前のタイマーがあればキャンセル
    timerTask = Task {        // 新しいタイマータスクを作成・保存
        while !Task.isCancelled, isPlaying {   // キャンセルされていない間ループ
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                break         // sleep がキャンセルされたら抜ける
            }
            guard !Task.isCancelled, isPlaying else { break }
            await next()
        }
    }
}
```

### `Task.isCancelled` が必要な理由

`timerTask?.cancel()` を呼んでも「タスク内で今まさに実行中のコード」はすぐには止まりません。キャンセル要求を受け取るのはタスク自身の責任です。`Task.isCancelled` を確認することで「キャンセルされたならループを終了する」を自分で実装しています。

### Task を変数に保存する意味

```swift
private var timerTask: Task<Void, Never>?
```

`Task<Void, Never>` は「戻り値なし（Void）、エラーなし（Never）のタスク」を意味します。変数に保存することで `timerTask?.cancel()` と呼び出してタスクをキャンセルできます。保存しなければキャンセルできない「放置タスク」になります。

---

## 10. `Task.sleep(for:)` — 非同期スリープ

### 何であるか

`Task.sleep(for:)` は「指定した時間だけ非同期に待つ」メソッドです。`Thread.sleep()` や `sleep()` などの**同期的スリープ**と違い、待っている間もスレッドをブロックしません（他の処理が動ける）。また、タスクがキャンセルされると `CancellationError` をスローして即座に終わります。

### なぜここで使われているか

スライドを一定間隔で自動切り替えする「タイマー」として使っています。

```swift
try await Task.sleep(for: .seconds(duration))
```

`.seconds(duration)` は `Duration` 型の値を作るメソッドです。`duration` は `Double` 型のスライド表示秒数です。

### `try` が必要な理由

`Task.sleep(for:)` はタスクがキャンセルされると `CancellationError` をスローします（例外を投げます）。`throw`（投げる）可能な関数を呼ぶには `try` が必要です。

```swift
do {
    try await Task.sleep(for: .seconds(duration))  // キャンセルで CancellationError
} catch {
    break   // エラー（キャンセル）をキャッチして while ループを抜ける
}
```

---

## 11. `Task.detached(priority:)` — デタッチドタスク

### 何であるか

`Task.detached` は現在のアクター（実行コンテキスト）から**切り離された（detached）独立したタスク**を作ります。通常の `Task { }` は呼び出し元と同じアクター（ここでは `@MainActor`）で動きますが、`Task.detached` はどのアクターにも属しません。

### なぜここで使われているか

`NSImage(data: data)` は画像データをデコードする処理で、データサイズによっては時間がかかります。この重い処理をメインスレッドで行うと UI がカクつきます。`Task.detached(priority: .userInitiated)` を使うことでバックグラウンドで画像をデコードし、完了したら `.value` で結果を受け取っています。

```swift
let image = await Task.detached(priority: .userInitiated) {
    NSImage(data: data)   // バックグラウンドで重い処理
}.value                   // 完了を await で待ち、結果を取り出す
```

### `priority: .userInitiated` の意味

タスクの優先度です。ユーザーが操作した直後に実行される処理（`.userInitiated`）は高い優先度で動き、システムから CPU 時間を多く割り当てられます。

### 通常の `Task` との比較

```swift
// 通常の Task — MainActor 内で呼ぶと MainActor のまま動く（UI スレッド占有）
Task { NSImage(data: data) }

// Task.detached — MainActor から切り離してバックグラウンドで動く
Task.detached(priority: .userInitiated) { NSImage(data: data) }
```

---

## 12. `guard` 文 — 早期リターン

### 何であるか

`guard` は「条件を満たさなければ今すぐ抜けろ」という構文です。`if` と逆で、条件が**偽（false）**のときに `else` ブロックが実行されます。`else` の中には `return`、`break`、`continue`、`throw` のいずれかを書く必要があります。

### なぜここで使われているか

「前提条件を満たしていなければ処理を続けない」という早期リターンパターンを書くためです。

```swift
// guard を使った書き方（このファイル）
func play() {
    guard !displayedSlides.isEmpty else { return }
    guard let duration = slideshow.config.duration.seconds else { return }
    // ここに来たら: スライドがある & duration が取れた、が保証されている
    isPlaying = true
    ...
}
```

```swift
// if を使った書き方（比較）
func play() {
    if !displayedSlides.isEmpty {
        if let duration = slideshow.config.duration.seconds {
            isPlaying = true
            ...  // ← ネストが深くなる
        }
    }
}
```

`guard` を使うとネストが浅くなり、「正常系のコード」が左端に揃って読みやすくなります。また、`guard let` でアンラップした変数（`duration`）は `else` ブロックの外でそのまま使えます。

```swift
// guard let — Optional のアンラップと早期リターンを同時に
guard let slide = currentSlide else {
    currentNSImage = nil
    return
}
// ここから下は slide が nil でないことが保証されている
```

---

## 13. `defer { }` — 遅延実行

### 何であるか

`defer { }` ブロックに書いたコードは「この関数が**どんな理由で終了しても**必ず最後に実行される」ことが保証されます。`return`、`throw`、正常終了、どれで終わっても実行されます。

### なぜここで使われているか

このファイルでは `loadCurrentImage()` 内で参照されるパターンが応用されていますが、典型的な使い方として `isLoading` フラグのリセットがあります（アーキテクチャルールのサンプルに記載）。

```swift
// defer の典型的な使い方（参考）
func load() async {
    isLoading = true
    defer { isLoading = false }  // どんな理由で return されても必ず false に戻る
    do {
        slideshows = try await fetchSlideshows.execute(...)
    } catch {
        // ここで return しても defer が実行される
        return
    }
    // 正常終了でも defer が実行される
}
```

### もし defer を使わなかったら

```swift
func load() async {
    isLoading = true
    do {
        slideshows = try await fetchSlideshows.execute(...)
    } catch {
        isLoading = false   // ← catch にも書く必要がある（書き忘れリスク）
        return
    }
    isLoading = false       // ← 正常終了にも書く必要がある（重複・漏れリスク）
}
```

`defer` を使えばリセット処理を一か所に書くだけで済み、書き忘れが起きません。

---

## 14. `try` / `do-catch` — エラーハンドリング

### 何であるか

Swift のエラーハンドリングは「エラーを投げる（`throw`）・受け取る（`catch`）」という仕組みです。

- `throws` 付きの関数はエラーを投げることがある
- `try` を付けて呼び出すと「エラーが来るかもしれない」と明示できる
- `do { } catch { }` でエラーをキャッチして対処する

### なぜここで使われているか

UseCase の `execute()` は `throws`（エラーを投げる可能性がある）と宣言されています。通信エラー、データ破損、バリデーション失敗などが起きた場合に `catch` で拾い、ユーザーに `errorMessage` として表示します。

```swift
func updateDuration(_ duration: SlideDurationResponse) async {
    let request = UpdateSlideshowConfigRequest(...)
    do {
        slideshow = try await updateSlideshowConfig.execute(request)  // エラーが投げられるかも
    } catch {
        errorMessage = error.localizedDescription  // エラーをユーザーに表示
    }
    if isPlaying { play() }
}
```

### `try?` — エラーを無視して Optional に変換

`try?` を使うと、エラーが発生した場合に `nil` を返し、エラーを無視します。

```swift
// Validation failure は「UI がこの状態を防ぐべきだったバグ」なので
// エラー詳細は不要 → try? で Optional にして if let でアンラップ
if let nextIndex = try? advanceSlide.execute(request) {
    currentIndex = nextIndex
    await loadCurrentImage()
} else {
    pause()
}
```

また `showHint` 内では `try?` をさらに簡潔に使っています：

```swift
try? await Task.sleep(for: .seconds(3))
// ↑ キャンセルエラーは無視していい（タスクが終わればよい）ので try? で簡略化
```

---

## 15. Task ベースのタイマーパターン

### 何であるか

このファイルは `Timer` クラスを使わず、`Task` と `Task.sleep` を組み合わせた**純粋に Swift Concurrency だけで作るタイマー**を採用しています。

### パターンの全体像

```swift
// 1. タスクへの参照を保持する変数
private var timerTask: Task<Void, Never>?
private var hideFilmstripTask: Task<Void, Never>?
private var hideHintTask: Task<Void, Never>?

// 2. タイマーを開始する（古いタスクがあればキャンセルしてから）
func play() {
    timerTask?.cancel()
    timerTask = Task {
        while !Task.isCancelled, isPlaying {
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch { break }
            guard !Task.isCancelled, isPlaying else { break }
            await next()
        }
    }
}

// 3. タイマーを止める
func pause() {
    timerTask?.cancel()
    timerTask = nil
}
```

```swift
// 単発の遅延実行タイマー（フィルムストリップを N 秒後に隠す）
private func scheduleHideFilmstrip() {
    hideFilmstripTask = Task {
        try? await Task.sleep(for: filmstripHideDuration)
        guard !Task.isCancelled else { return }
        showFilmstrip = false
    }
}
```

### `Timer` クラスとの比較

| 比較項目 | `Timer`（旧） | Task ベース（このファイル） |
|---------|-------------|--------------------------|
| スレッド | RunLoop に登録（メインスレッドに注意が必要） | `@MainActor` クラスで自然にメインスレッド |
| キャンセル | `timer.invalidate()` | `task.cancel()` |
| `async` との相性 | 悪い（コールバックが必要） | 完璧（`await` がそのまま使える） |
| メモリ管理 | RunLoop が保持するため循環参照のリスク | ARC の通常ルールに従う |

### 「古いタスクをキャンセルしてから新しいタスクを作る」パターン

```swift
// showHint の例
private func showHint(_ type: FullscreenHintType) {
    hideHintTask?.cancel()       // 前のヒント非表示タスクをキャンセル
    fullscreenHint = type        // すぐにヒントを表示
    hideHintTask = Task {        // 3秒後に非表示にする新タスクを作成
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        fullscreenHint = nil
    }
}
```

`showHint(.exit)` が呼ばれた後すぐに `showHint(.enter)` が呼ばれた場合、前の「3秒後に隠す」タスクはキャンセルされ、新しい「3秒後に隠す」タスクが動き始めます。タスクを変数に保存する設計はこの「重複タスクの防止」に不可欠です。

---

## 16. 実践で学んだ落とし穴

このファイルに関連する実際の開発で遭遇した落とし穴を紹介します。

### 落とし穴 1: @Observable ViewModel を @State で注入するアンチパターン

`@Observable` クラスを View に渡すとき、`@State(initialValue:)` で受け取ると**初回の値だけが保存され、以降 DI コンテナが新しいインスタンスを渡しても無視されます**。`@State` は「この View が所有する値」を意味するため、SwiftUI が内部でキャッシュしてしまうのです。

```swift
// ❌ BAD — 2回目以降に渡されたインスタンスが無視される
struct SlideshowPlayerView: View {
    @State private var viewModel: SlideshowPlayerViewModel
    init(viewModel: SlideshowPlayerViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }
}
```

`@Observable` はプロパティへのアクセスを自動追跡するので、`@State` なしでも View は再描画されます。外部から注入する場合は `let`（読み取り専用）か `@Bindable`（双方向バインディング `$vm.prop` が必要な場合）を使います。

```swift
// ✅ GOOD — 読み取り専用ならシンプルに let
struct SlideshowPlayerView: View {
    let viewModel: SlideshowPlayerViewModel
    init(viewModel: SlideshowPlayerViewModel) {
        self.viewModel = viewModel
    }
}

// ✅ GOOD — $viewModel.prop のようなバインディングが必要なら @Bindable
struct LibraryPickerView: View {
    @Bindable var viewModel: CreateSlideshowViewModel
}
```

**覚え方**: `@State` = View が自分で作って所有する値。外から注入する `@Observable` には使わない。

---

### 落とし穴 2: 非同期メソッドのインデックス競合

View の `.task(id:)` は `id` が変わると**前のタスクを自動キャンセル**します。しかし、同じ処理を ViewModel のメソッドに移すと、この自動キャンセルは失われます。ユーザーが素早く「次へ」を連打すると、古い画像ロードが新しいものより後に完了し、**表示が1枚前のスライドに巻き戻る**ことがあります。

```swift
// ❌ BAD — 2回の await の間に currentIndex が変わると古い画像で上書きされる
func loadCurrentImage() async {
    guard let slide = currentSlide else { return }
    do {
        let data = try await loadSlideImage.execute(...)
        // ↑ この await 中に next() が呼ばれて currentIndex が進んでいるかもしれない
        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        currentNSImage = image  // ← 古いスライドの画像で上書き！
    } catch { ... }
}
```

対策は、**await の前にインデックスをスナップショット**し、**各 await の後でインデックスが変わっていないか確認**することです。

```swift
// ✅ GOOD — スナップショットとガードで「最新の呼び出しだけが勝つ」を保証
func loadCurrentImage() async {
    guard let slide = currentSlide else { currentNSImage = nil; return }
    let expectedIndex = currentIndex                        // スナップショット

    do {
        let data = try await loadSlideImage.execute(...)
        guard currentIndex == expectedIndex else { return } // ガード①

        let image = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
        guard currentIndex == expectedIndex else { return } // ガード②

        currentNSImage = image
    } catch {
        currentNSImage = nil
    }
}
```

**ポイント**: `await` のたびに「まだ自分が最新か？」を確認する。`.task(id:)` の自動キャンセルに頼れない場面では、このスナップショット＋ガードパターンが必須です。

---

### 落とし穴 3: ViewModel で NSImage を直接保持しない

ViewModel に `NSImage?` プロパティを持たせたくなりますが、`NSImage` は `AppKit` の型です。このプロジェクトのアーキテクチャルールでは **ViewModel に `import AppKit` を許可していない**ため、SwiftLint エラーになります。

かといって View の `body` 内で `NSImage(data:)` を同期的に呼ぶと、画像デコードでメインスレッドがブロックされ、スライドショー再生中にカクつきます。

```swift
// ❌ BAD — ViewModel に AppKit の型を持たせるとアーキテクチャ違反
@Observable
final class SlideshowPlayerViewModel {
    import AppKit  // ← SwiftLint エラー！
    private(set) var currentNSImage: NSImage?
}

// ❌ BAD — View の body 内で同期デコードするとメインスレッドがブロックされる
var body: some View {
    if let data = viewModel.currentImage {
        Image(nsImage: NSImage(data: data)!)  // ← UI がカクつく
    }
}
```

正解は、**ViewModel は `Data?` を保持し、View 側で `.task(id:)` + `Task.detached` を使って非同期デコード**する方法です。

```swift
// ✅ GOOD — ViewModel は Data だけを保持（AppKit 不要）
@Observable
final class SlideshowPlayerViewModel {
    private(set) var currentImage: Data?
}

// ✅ GOOD — View 側で非同期デコード
struct SlideshowPlayerView: View {
    @State private var decodedImage: NSImage?

    var body: some View {
        // decodedImage を使って表示
    }
    .task(id: viewModel.currentImage) {
        guard let data = viewModel.currentImage else {
            decodedImage = nil; return
        }
        decodedImage = await Task.detached(priority: .userInitiated) {
            NSImage(data: data)
        }.value
    }
}
```

**メリット**: ViewModel は AppKit に依存しない。デコードはバックグラウンドで行われるため UI がカクつかない。`.task(id:)` により `data` が変わると前のデコードが自動キャンセルされる。

---

## 17. このファイルで学べること — まとめ

`SlideshowPlayerViewModel.swift` は、現代の Swift が持つ機能を組み合わせて「安全で読みやすい非同期 UI コントローラー」を作る手本です。

| 概念 | このファイルでの役割 |
|------|-------------------|
| `@Observable` | プロパティ変更を View に自動通知 |
| `@MainActor` | UI 更新を常にメインスレッドで行う保証 |
| `final class` | 継承を禁止し設計の意図を明示 |
| `private(set)` | 外部からの不正な書き換えをコンパイラが防止 |
| ネスト `enum` | 型をスコープ内に閉じ込め意図を明確化 |
| `any Protocol` | 具体実装に依存せず差し替え可能な設計 |
| `async / await` | 非同期処理を同期的な見た目で記述 |
| `Task { }` | 非同期文脈の作成とタスクのキャンセル管理 |
| `Task.sleep(for:)` | スレッドをブロックしない待機 |
| `Task.detached` | 重い処理をメインスレッドから切り離す |
| `guard` | 前提条件チェックと早期リターン |
| `defer` | 終了時の後片付けを一か所で保証 |
| `try / do-catch` | エラーを型安全に伝播・処理 |
| Task ベースタイマー | キャンセル可能な遅延処理・繰り返し処理 |

### この設計が教えてくれること

- **状態は ViewModel が一元管理する**: `isPlaying`、`currentIndex`、`showFilmstrip` などすべての UI 状態がここに集まっている。View は状態を読むだけで、書き換えはメソッド経由。
- **非同期処理はキャンセルを考える**: `Task` を変数に保持し、新しい処理を始める前に `cancel()` するパターンは「タスクの二重起動」を防ぐ。
- **エラーは上に伝える**: UseCase のエラーは `catch` して `errorMessage` に変換し、View が表示する。ViewModel はエラーを握り潰さない。
- **スレッド境界を明示する**: `@MainActor` と `Task.detached` の使い分けで「どの処理がどのスレッドで動くか」がコードから読み取れる。
