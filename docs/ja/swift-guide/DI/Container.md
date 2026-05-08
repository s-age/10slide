# DI コンテナを読み解く — 依存性注入パターンの完全ガイド

> 対象読者: Swiftを学び始めたばかりの人。コードを読んで「なぜこう書くのか？」が分からない人。

---

## 対象ファイル

| ファイル | 役割 |
|---------|------|
| `Sources/DI/Container.swift` | アプリ全体の「配線図」。全レイヤーのコンテナを決まった順序で生成する |
| `Sources/DI/InfrastructureContainer.swift` | インフラストラクチャ層のコンテナ。`ModelContainer`、データストア、データソースを保持する |
| `Sources/DI/RepositoryContainer.swift` | リポジトリ層のコンテナ。インフラストラクチャプロトコルを注入されたリポジトリインスタンスを保持する |
| `Sources/DI/DomainContainer.swift` | ドメイン層のコンテナ。リポジトリプロトコルを注入されたドメインサービスインスタンスを保持する |
| `Sources/DI/UseCaseContainer.swift` | ユースケース層のコンテナ。各ユースケースをバリデーションデコレータで包んで保持する |
| `Sources/DI/PresentationContainer.swift` | 表示層のコンテナ。ViewModelを組み立てるファクトリメソッドを提供する |

---

## 1. DI（依存性注入）パターンとは何か — なぜ直接 `new` しないのか

### 定義

DI（Dependency Injection＝依存性注入）とは、あるオブジェクトが「必要とする別のオブジェクト（依存）」を**自分で作らず、外から受け取る**設計パターンです。

### なぜここで使われているか

たとえば `SlideshowPlayerViewModel` は「スライド画像を読み込む機能」が必要です。これを自分で作ろうとすると、こうなります。

```swift
// ❌ Without DI — ViewModel creates its own dependencies
class SlideshowPlayerViewModel {
    private let loader = LoadSlideImageUseCase(
        domainService: ImageDomainService(
            repository: ImageRepository(
                imageDataSource: ImageDataSource()
            )
        )
    )
}
```

これには深刻な問題があります。

- **テストできない** — `ImageDataSource` は実際のデータベースに繋がるため、テスト時に差し替えられない
- **変更が伝染する** — `ImageDataSource` の初期化方法が変わると、使っているすべての場所を直す必要がある
- **責任が混在する** — ViewModel が「どう作るか」まで知りすぎている

DI を使うと、ViewModel は「外から渡された機能を使う」だけになります。

```swift
// ✅ With DI — ViewModel just uses the dependency it receives
class SlideshowPlayerViewModel {
    private let loadSlideImage: LoadSlideImageUseCaseProtocol

    init(loadSlideImage: LoadSlideImageUseCaseProtocol) {
        self.loadSlideImage = loadSlideImage
    }
}
```

「誰がどの実装を渡すか」を一手に引き受けるのが、今回学ぶ **DI コンテナ** です。

---

## 2. `Container.swift` を読む

```swift
final class Container {
    let infrastructure: InfrastructureContainer
    let repositories: RepositoryContainer
    let domain: DomainContainer
    let useCases: UseCaseContainer
    let presentation: PresentationContainer

    init() throws {
        infrastructure = try InfrastructureContainer()
        repositories = RepositoryContainer(infrastructure: infrastructure)
        domain = DomainContainer(repositories: repositories)
        useCases = UseCaseContainer(domain: domain)
        presentation = PresentationContainer(useCases: useCases)
    }
}
```

このファイルはたった15行ですが、アプリ全体の「配線図」として機能しています。

---

### 2-1. `final class` — 継承を禁止する理由

#### 定義

`final` をクラスにつけると、そのクラスを**継承できなくなります**。

```swift
final class Container { ... }

// ❌ Compile error — cannot inherit from a final class
class SpecialContainer: Container { }
```

#### なぜここで使われているか

DI コンテナは「全オブジェクトの配線を管理する責任者」です。継承によって一部だけ書き換えられると、配線の整合性が崩れます。`final` をつけることで「このクラスはこれ以上特殊化しない」という意思を明示しています。

また、`final class` はコンパイラが**メソッド呼び出しを最適化**できるため、わずかにパフォーマンスも向上します。

#### もし `final` を使わなかったら

`class Container` と書いた場合、誰かがサブクラスを作って一部の初期化を変更し、予期しない依存関係を混入させる危険があります。

---

### 2-2. `let` プロパティ — 不変な依存関係

#### 定義

`let` で宣言したプロパティは、**初期化後に変更できません**。

```swift
let infrastructure: InfrastructureContainer
// infrastructure = other  // ❌ Compile error
```

#### なぜここで使われているか

DI コンテナが保持するオブジェクトは、アプリ起動時に一度だけ組み立てられ、その後は変わりません。`let` にすることで「この依存は途中で差し替わらない」という保証をコンパイラに宣言できます。

#### もし `var` を使ったら

```swift
var infrastructure: InfrastructureContainer  // ❌ Can be replaced later
```

`var` にすると、どこかのコードが `container.infrastructure = anotherInfrastructure` と書いて配線を破壊できてしまいます。

---

### 2-3. `init() throws` — 失敗を許容するイニシャライザ

#### 定義

通常のイニシャライザ `init()` は必ず成功します。`throws` をつけると、**初期化に失敗してエラーを投げることができます**。

```swift
init() throws {
    infrastructure = try InfrastructureContainer()  // Might fail
    ...
}
```

呼び出し側では `try` と `catch` で失敗に備えます。

```swift
do {
    let container = try Container()
} catch {
    // Database initialization failure, etc.
    print("Startup failed: \(error)")
}
```

#### なぜここで使われているか

`InfrastructureContainer` の内部では SwiftData（データベース）の初期化が行われます。ディスクへのアクセスに失敗したり、スキーマの移行でエラーが起きたりと、現実的に失敗しうる処理です。`throws` を使うことで、その失敗を握りつぶさず呼び出し元に伝えられます。

#### もし `throws` を使わなかったら

失敗をエラーとして伝える手段がなくなります。よく見られる悪い代替手段は `fatalError()` ですが、これはユーザーにクラッシュを見せるだけで、回復の余地がありません。

---

### 2-4. 依存の初期化順序 — infrastructure → repositories → domain → useCases → presentation

```swift
infrastructure = try InfrastructureContainer()         // 1. Bottom layer
repositories = RepositoryContainer(infrastructure: infrastructure)  // 2.
domain = DomainContainer(repositories: repositories)               // 3.
useCases = UseCaseContainer(domain: domain)                        // 4.
presentation = PresentationContainer(useCases: useCases)           // 5. Top layer
```

#### 定義

この順序は、アプリのアーキテクチャ（層構造）に対応しています。

```
Presentation (UI)
    ↓ uses
UseCases (feature units)
    ↓ uses
Domain (business logic)
    ↓ uses
Repositories (data conversion)
    ↓ uses
Infrastructure (actual DB, files, network)
```

#### なぜこの順序か

上の層は下の層に依存しているため、先に下の層を作らないと上の層を初期化できません。たとえば `RepositoryContainer` は `infrastructure` を受け取って初期化されるため、`infrastructure` が完成していないと生成できません。

#### もし順序を逆にしたら

```swift
// ❌ This is a compile error — infrastructure doesn't exist yet
repositories = RepositoryContainer(infrastructure: infrastructure)
infrastructure = try InfrastructureContainer()
```

Swift の `let` プロパティは使う前に初期化されていなければならないため、コンパイラがエラーを出します。

---

## 3. `UseCaseContainer.swift` を読む

```swift
final class UseCaseContainer: Sendable {
    let createSlideshow: CreateSlideshowUseCaseProtocol
    let fetchSlideshow: FetchSlideshowUseCaseProtocol
    // ... (15 use case properties total, all following the same pattern)

    init(domain: DomainContainer) {
        createSlideshow = ValidationAsyncUseCaseDecorator(
            decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
        )

        // Sync use cases use ValidationSyncUseCaseDecorator:
        advanceSlide = ValidationSyncUseCaseDecorator(
            decoratee: AdvanceSlideUseCase(domainService: domain.playbackService)
        )
        // ...
    }
}
```

---

### 3-1. `Sendable` プロトコル — スレッドセーフな型

#### 定義

`Sendable` は Swift の**並行処理安全性**を保証するプロトコルです。このプロトコルに準拠した型は「複数のスレッドやアクター（並行実行コンテキスト）の間でも安全に渡せる」ことをコンパイラに宣言します。

```swift
final class UseCaseContainer: Sendable { ... }
```

#### なぜここで使われているか

現代の iOS/macOS アプリは `async/await` を使って並行処理を行います。ユースケースは画面（`@MainActor`）からバックグラウンドスレッドで呼び出されることがあります。`Sendable` を宣言することで「この型を別アクターに渡しても安全だ」とコンパイラに証明します。

`Sendable` が成立する条件：

1. `final class` であること（サブクラスが状態を追加できない）
2. 全プロパティが `let` であること（変更されない）
3. 全プロパティの型が `Sendable` であること（連鎖して安全）

```swift
// ✅ All conditions met, so Sendable conformance holds
final class UseCaseContainer: Sendable {
    let createSlideshow: CreateSlideshowUseCaseProtocol  // Protocol is also declared Sendable
}
```

#### もし `Sendable` がなかったら

Swift 6 の厳格な並行性チェックが有効なこのコードベースでは、`Sendable` でない型を `@MainActor` のコードから非同期コンテキストに渡すとコンパイルエラーになります。

---

### 3-2. `any Protocol` 型 — プロトコル存在型でコンテナに格納

#### 定義

Swiftのプロトコルを型として使うとき、`any` キーワードをつけると**プロトコル存在型**（existential type）になります。「このプロトコルに準拠した何らかの型」を格納できる箱です。

```swift
// Base protocol with generics (in ExecutableUseCase.swift)
protocol AsyncUseCase<Request, Response>: Sendable {
    associatedtype Request
    associatedtype Response
    func execute(_ request: Request) async throws -> Response
}

// Typealias pins the generic parameters (in Protocols/CreateSlideshowUseCaseProtocol.swift)
typealias CreateSlideshowUseCaseProtocol = any AsyncUseCase<CreateSlideshowRequest, SlideshowResponse>

// Stored in the container — `any` is already embedded in the typealias, so no prefix needed
let createSlideshow: CreateSlideshowUseCaseProtocol
```

#### なぜここで使われているか

コンテナが具体的な実装クラスの型を知ってしまうと、その実装に依存してしまいます。プロトコル型として格納することで、**差し替え可能な設計**になります。

```swift
// ✅ Stored as protocol type — doesn't know the implementation
let createSlideshow: CreateSlideshowUseCaseProtocol

// The actual stored value is a concrete type wrapped in a decorator
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)
```

#### もし具体型で格納したら

```swift
// ❌ Stored as concrete type — implementation details leak out
let createSlideshow: ValidationAsyncUseCaseDecorator<CreateSlideshowUseCase>
```

テスト時にモック実装に差し替えることができなくなります。

---

### 3-3. デコレータパターン — `ValidationAsyncUseCaseDecorator`

```swift
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)
```

#### 定義

デコレータパターンとは、既存のオブジェクトを**別のオブジェクトで包むことで機能を追加する**デザインパターンです。

この場合、`CreateSlideshowUseCase`（本体の処理）を `ValidationAsyncUseCaseDecorator`（バリデーション機能）で包んでいます。

```
ValidationAsyncUseCaseDecorator (outer — handles validation)
    └─ CreateSlideshowUseCase (inner — handles actual processing)
```

#### なぜここで使われているか

バリデーションロジックを各ユースケースクラスに書くと、すべてのユースケースに同じコードが重複します。デコレータとして分離することで、本体のユースケースはビジネスロジックだけに集中できます。

#### 2つのデコレータバリアント

このコードベースでは、ユースケースが非同期か同期かに応じて2つのデコレータバリアントを使い分けています。

| デコレータ | ユースケースの種類 | 例 |
|-----------|------------------|-----|
| `ValidationAsyncUseCaseDecorator` | `AsyncUseCase`（async/await） | `CreateSlideshowUseCase`、`FetchSlideshowUseCase` など |
| `ValidationSyncUseCaseDecorator` | `SyncUseCase`（同期） | `AdvanceSlideUseCase`、`PreviousSlideUseCase`、`AddDroppedFilesUseCase` |

```swift
// Async use case — wrapped with ValidationAsyncUseCaseDecorator
createSlideshow = ValidationAsyncUseCaseDecorator(
    decoratee: CreateSlideshowUseCase(domainService: domain.slideshowService)
)

// Sync use case — wrapped with ValidationSyncUseCaseDecorator
advanceSlide = ValidationSyncUseCaseDecorator(
    decoratee: AdvanceSlideUseCase(domainService: domain.playbackService)
)
```

---

## 4. `PresentationContainer.swift` を読む

```swift
final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol
    private let loadSlideImage: LoadSlideImageUseCaseProtocol
    private let loadThumbnail: LoadThumbnailUseCaseProtocol
    private let updateSlideshowConfig: UpdateSlideshowConfigUseCaseProtocol
    private let advanceSlide: AdvanceSlideUseCaseProtocol
    private let previousSlide: PreviousSlideUseCaseProtocol
    private let addDroppedFiles: AddDroppedFilesUseCaseProtocol
    private let fetchSlideshows: FetchSlideshowsUseCaseProtocol
    private let deleteSlideshow: DeleteSlideshowUseCaseProtocol
    private let updateSlideshow: UpdateSlideshowUseCaseProtocol

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        loadThumbnail = useCases.loadThumbnail
        updateSlideshowConfig = useCases.updateSlideshowConfig
        advanceSlide = useCases.advanceSlide
        previousSlide = useCases.previousSlide
        addDroppedFiles = useCases.addDroppedFiles
        fetchSlideshows = useCases.fetchSlideshows
        deleteSlideshow = useCases.deleteSlideshow
        updateSlideshow = useCases.updateSlideshow
    }

    @MainActor
    func makeThumbnailViewModel() -> ThumbnailViewModel {
        ThumbnailViewModel(loadThumbnail: loadThumbnail)
    }

    @MainActor
    func makeSlideshowPlayerViewModel(slideshow: SlideshowResponse) -> SlideshowPlayerViewModel {
        SlideshowPlayerViewModel(
            slideshow: slideshow,
            loadSlideImage: loadSlideImage,
            updateSlideshowConfig: updateSlideshowConfig,
            advanceSlide: advanceSlide,
            previousSlide: previousSlide
        )
    }
}
```

---

### 4-1. `private let` — 情報隠蔽（カプセル化）

```swift
private let createSlideshow: CreateSlideshowUseCaseProtocol
```

#### 定義

`private` をつけると、そのプロパティは**同じファイル内からしかアクセスできません**。外部のコードからは見えません。

#### なぜここで使われているか

`PresentationContainer` が保持するユースケースは、ViewModelを組み立てるためだけに使います。外から直接 `container.createSlideshow` にアクセスされると、コンテナを経由せずに依存が利用される恐れがあります。`private` で隠すことで、外部からの利用は必ず `make*` ファクトリメソッドを通るように強制できます。

---

### 4-2. `init` でコンテナ参照を捨てる — プロトコル値の即時抽出

```swift
init(useCases: UseCaseContainer) {
    createSlideshow = useCases.createSlideshow   // Extract the protocol value
    loadSlideImage = useCases.loadSlideImage     // Extract the protocol value
    // useCases itself is NOT saved as a property!
}
```

#### なぜ `useCases` をそのまま保存しないのか

`UseCaseContainer` をプロパティに保存してしまうと、`PresentationContainer` は「ユースケース層のコンテナ全体」に依存することになります。後から `UseCaseContainer` に何か追加されると、その影響を受けてしまいます。

`init` の中でプロトコル値だけを取り出し、コンテナへの参照は捨てることで、必要な依存だけを最小限に保てます。これは「**アップストリームコンテナを捨てるパターン**」と呼ばれます。

---

### 4-3. `@MainActor` — UI スレッドの保証

#### 定義

`@MainActor` は「この関数はメインスレッドで実行される」ことをコンパイラに保証させるアノテーションです。SwiftUI の View は必ずメインスレッドで動く必要があります。

```swift
@MainActor
func makeThumbnailViewModel() -> ThumbnailViewModel {
    ThumbnailViewModel(loadThumbnail: loadThumbnail)
}
```

#### なぜここで使われているか

`ThumbnailViewModel` などは `@Observable` や `@Published` で UI 更新を行うため、メインスレッドで生成される必要があります。`@MainActor` をつけることで、バックグラウンドスレッドから誤って呼ばれた場合にコンパイルエラーが出るようになります。

#### もし `@MainActor` がなかったら

バックグラウンドスレッドから ViewModel を生成してしまい、UI の更新がメインスレッド以外から行われてクラッシュする可能性があります。

---

### 4-4. ファクトリメソッド — ViewModel の組み立て責任

```swift
@MainActor
func makeSlideshowPlayerViewModel(slideshow: SlideshowResponse) -> SlideshowPlayerViewModel {
    SlideshowPlayerViewModel(
        slideshow: slideshow,
        loadSlideImage: loadSlideImage,
        updateSlideshowConfig: updateSlideshowConfig,
        advanceSlide: advanceSlide,
        previousSlide: previousSlide
    )
}
```

#### 定義

ファクトリメソッドとは、**オブジェクトの生成を担当する専用のメソッド**です。呼び出し側は「どのように作るか」を知る必要がなく、「何が欲しいか（引数）」を渡すだけで完成品を受け取れます。

#### なぜここで使われているか

`SlideshowPlayerViewModel` には `loadSlideImage`、`updateSlideshowConfig`、`advanceSlide`、`previousSlide` という4つの依存が必要です。View（呼び出し側）がこれらを直接渡すためには、View 自身がこれら全部を知っている必要があります。

```swift
// ❌ Without a factory — View must know all dependencies
SlideshowPlayerViewModel(
    slideshow: slideshow,
    loadSlideImage: ???,   // Where does the View get this?
    ...
)
```

ファクトリメソッドを通すと、View は `slideshow`（表示したいデータ）だけを知っていれば済みます。

```swift
// ✅ With a factory — View only needs to pass slideshow
let vm = container.presentation.makeSlideshowPlayerViewModel(slideshow: slideshow)
```

#### ファクトリクロージャとして使う

`@MainActor` なメソッドは、クロージャとして引き渡すこともできます。

```swift
// Expressing the type of makeSlideshowPlayerViewModel as a closure:
// @MainActor @Sendable (SlideshowResponse) -> SlideshowPlayerViewModel

// Pass only "the method for creating ViewModels" to the View (not the entire container)
let factory: @MainActor @Sendable (SlideshowResponse) -> SlideshowPlayerViewModel
    = container.presentation.makeSlideshowPlayerViewModel
```

この型シグネチャの意味：

| 部分 | 意味 |
|------|------|
| `@MainActor` | このクロージャはメインスレッドで実行される |
| `@Sendable` | このクロージャは別のアクターに安全に渡せる |
| `(SlideshowResponse)` | 引数：表示するスライドショーのデータ |
| `-> SlideshowPlayerViewModel` | 戻り値：完成した ViewModel |

---

## 5. 実践で学んだ落とし穴

このプロジェクトの開発中に実際に遭遇した問題を紹介します。DI コンテナの設計で「なんとなく動くけど正しくない」パターンを避けるために知っておくべきポイントです。

---

### 落とし穴 1: DI コンテナを `Sendable` にする方法

#### 何が起きるか

Swift 6 の厳格な並行性チェックが有効な環境で、DI コンテナのメソッド参照を `@Sendable` クロージャとして渡すと、コンテナが `Sendable` でない場合にコンパイラ警告が出ます。

```
warning: converting non-Sendable function value to
'@MainActor @Sendable (SlideshowResponse) -> SlideshowPlayerViewModel' may introduce data races
```

実際にこのプロジェクトでは、`ContentView` が `PresentationContainer` のファクトリメソッドをクロージャとして受け取る設計になっており、`PresentationContainer` が `Sendable` でなかったためにこの警告が発生しました。

#### 正しい書き方

```swift
// ✅ final class + let only + all properties Sendable → Sendable conformance holds automatically
final class PresentationContainer: Sendable {
    private let createSlideshow: CreateSlideshowUseCaseProtocol  // typealias embeds `any`
    private let loadSlideImage: LoadSlideImageUseCaseProtocol    // typealias embeds `any`
    // ... (10 private let properties total — all UseCase protocol typealiases)

    init(useCases: UseCaseContainer) {
        createSlideshow = useCases.createSlideshow
        loadSlideImage = useCases.loadSlideImage
        // ... (all 10 extracted here)
    }
}
```

`Sendable` が成立する3条件を覚えておきましょう。

1. `final class` であること（サブクラスが状態を追加できない）
2. 全プロパティが `let` であること（変更されない）
3. 全プロパティの型が `Sendable` であること（連鎖して安全）

#### やってはいけない書き方

```swift
// ❌ Having a var property makes Sendable impossible
final class PresentationContainer: Sendable {
    private var createSlideshow: any CreateSlideshowUseCaseProtocol  // Compile error!
}

// ❌ Faking it with @unchecked Sendable — discards the compiler's protection
final class PresentationContainer: @unchecked Sendable {
    private var createSlideshow: any CreateSlideshowUseCaseProtocol
    // Data race risk remains...
}
```

**ポイント**: `@unchecked Sendable` や `nonisolated(unsafe)` で警告を黙らせるのは最終手段です。まずコンテナ自体を正しく `Sendable` にできないか検討しましょう。

---

### 落とし穴 2: レイヤーの直線的な依存関係を守る

#### 何が起きるか

「UseCase から Repository を直接呼べば簡単なのに」と思い、Domain Service を飛ばしてしまうと、**レイヤースキップ**が発生します。このプロジェクトでは Clean Architecture の V 字型ではなく、**厳密な直線フロー**を採用しています。

```
Presentation → UseCases → Domain Services → Repositories → Infrastructure
```

レイヤーを飛ばすと、SwiftLint のカスタムルールがエラーを出します。しかしそれ以上に、ビジネスロジックの置き場所が分散し、「同じ処理をあちこちで書く」状態に陥ります。

#### 正しい書き方

```swift
// ✅ UseCase only calls DomainService (does not call Repository)
final class CreateSlideshowUseCase: AsyncUseCase, Sendable {
    private let domainService: any SlideshowDomainServiceProtocol

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
}
```

#### やってはいけない書き方

```swift
// ❌ UseCase is calling Repository directly (layer skip)
final class CreateSlideshowUseCase {
    private let repository: SlideshowRepositoryProtocol  // Skipping the Domain Service!

    func execute(request: CreateSlideshowRequest) async throws -> SlideshowResponse {
        let entity = try await repository.save(...)
        return SlideshowResponse(entity)
    }
}
```

**ポイント**: 「1つのことしかしないから Domain Service を省略しよう」と思っても、各レイヤーは必ず隣接するレイヤーだけを呼ぶルールを守りましょう。こうすることで、Repository のオーケストレーション（複数の操作をまとめる処理）が常に Domain Service に集まり、一貫性のある設計が維持されます。

---

## 6. このファイルで学べること — まとめ

| 概念 | キーワード | 一言まとめ |
|------|-----------|-----------|
| **DI パターン** | `init(useCases:)` | 依存を「外から渡す」ことでテスト容易性・変更耐性を得る |
| **`final class`** | `final` | 継承を禁止し、設計の意図と最適化を守る |
| **`let` プロパティ** | `let` | 初期化後の変更を禁止し、不変な依存関係を保証する |
| **`init() throws`** | `throws` / `try` | 初期化の失敗をエラーとして伝播させ、クラッシュを避ける |
| **初期化順序** | 下層 → 上層 | 依存するものを先に作る。逆にするとコンパイルエラー |
| **`Sendable`** | `: Sendable` | 並行処理でアクター間を安全に渡せることをコンパイラに証明する |
| **`any Protocol` 型** | `XxxProtocol` | 具体実装ではなく抽象に依存し、差し替え可能にする |
| **ファクトリメソッド** | `make*()` / `@MainActor` | 複雑な組み立て手順を隠蔽し、呼び出し側を単純に保つ |

### 全体の流れを一言で

> `Container` がアプリ起動時に一度だけすべての依存を組み立て、各コンテナは必要な依存だけを `private let` で保持し、ViewModel はファクトリメソッド経由で外部から受け取る。

この設計により、**テストしやすく・変更に強く・スレッドセーフなアプリ**が実現されています。
