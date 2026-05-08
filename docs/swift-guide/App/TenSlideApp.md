# TenSlideApp.swift — Swift 入門ガイド

**ソースファイル:** `Sources/App/TenSlideApp.swift`

## このファイルの役割

`TenSlideApp.swift` は **アプリの玄関口** です。macOS がアプリを起動するとき、最初に実行されるのがこのファイルです。ここでは DI（依存性注入）コンテナを初期化し、最初のウィンドウとその中身を組み立てています。

コード全体はわずか 28 行ですが、Swiftの重要な概念が凝縮されています。上から順番に読んでいきましょう。

---

## ソースコード全文

```swift
import SwiftUI
import SwiftData

@main
struct TenSlideApp: App {
    private let container: Container

    init() {
        do {
            container = try Container()
        } catch {
            fatalError("DI initialization failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                thumbnailViewModel: container.presentation.makeThumbnailViewModel(),
                createViewModel: container.presentation.makeCreateSlideshowViewModel(),
                makeSlideshowPlayerViewModel: container.presentation.makeSlideshowPlayerViewModel,
                makeSpritePlayerViewModel: container.presentation.makeSpritePlayerViewModel,
                makeSlideshowLibraryViewModel: container.presentation.makeSlideshowLibraryViewModel
            )
        }
        .modelContainer(container.infrastructure.modelContainer)
    }
}
```

---

## 概念 1 — `import SwiftUI` / `import SwiftData`：フレームワークのインポート

### これは何か？

`import` はSwiftが外部ライブラリ（フレームワーク）を読み込む命令です。`SwiftUI` はAppleが提供するUI構築フレームワーク、`SwiftData` はデータの永続化（保存・読み込み）フレームワークです。

### なぜここで使われているか？

- `SwiftUI` がないと `App` プロトコルや `WindowGroup`、`Scene` などの型が使えません。
- `SwiftData` がないと `.modelContainer()` 修飾子が使えません。

### もし使わなかったら？

```swift
// import SwiftUI を書かなかった場合
struct TenSlideApp: App {  // ❌ エラー：'App' が見つかりません
```

コンパイラは `App` が何か知らないので、ビルドエラーになります。

### 該当コード

```swift
import SwiftUI
import SwiftData
```

---

## 概念 2 — `@main`：アプリのエントリーポイント

### これは何か？

`@main` はSwiftの **属性（Attribute）** で、「このファイルがアプリの起動地点だ」とコンパイラに伝えます。Swiftのプログラムには必ずエントリーポイントが1つ必要で、`@main` がその役を担います。

### なぜここで使われているか？

macOS アプリは起動時に「どこから実行を始めるか」を知る必要があります。`@main` を付けると、Swiftは自動的にそのstructの `main()` 関数（`App` プロトコルが提供）を呼び出します。開発者は `main()` を自分で書く必要がなく、宣言するだけで済みます。

### もし使わなかったら？

プロジェクト全体でエントリーポイントが存在しなくなり、「エントリーポイントが見つからない」というリンクエラーが発生します。逆に2つ以上の型に `@main` を付けるとエラーになります。

### 該当コード

```swift
@main
struct TenSlideApp: App {
```

---

## 概念 3 — `struct TenSlideApp: App`：構造体と App プロトコルへの準拠

### これは何か？

**`struct`（構造体）** はSwiftのデータ型の一つです。クラス（`class`）と似ていますが、値型（コピーして渡される）という違いがあります。

**`: App`** はプロトコルへの準拠を表します。プロトコルは「このルールに従ってください」という契約書です。`App` プロトコルは「`body` プロパティを持つこと」を要求します。

### なぜここで使われているか？

SwiftUIのアプリは `App` プロトコルに準拠した型が必要です。Appleが「アプリの定義はこのプロトコルを通じてください」と設計したからです。`struct` を使うのは、アプリの設定を軽量な値型で表現できるためです（状態はDIコンテナが持つのでstructで十分）。

### もし使わなかったら？

```swift
// App プロトコルに準拠しなかった場合
@main
struct TenSlideApp {  // ❌ @main には静的な main() が必要です
```

`@main` と `App` プロトコルはセットです。`App` が `main()` の実装を提供しているため、準拠しないとコンパイルエラーになります。

### 該当コード

```swift
struct TenSlideApp: App {
```

---

## 概念 4 — `private let container: Container`：アクセス制御と定数

### これは何か？

- **`private`**：このプロパティは `TenSlideApp` の内部からしかアクセスできないというアクセス制御です。
- **`let`**：一度値を代入したら変更できない定数です（`var` は変更可能な変数）。
- **`container: Container`**：`Container` 型のプロパティで、アプリ全体の依存性注入（DI）コンテナを保持します。

### なぜここで使われているか？

`container` は `init()` で初期化した後、アプリの動作中に差し替える必要がありません。`let` にすることで「誰かが誤って書き換える」バグを防げます。また `private` にすることで、外のコードが `container` を直接操作できないようにカプセル化しています。

### もし使わなかったら？

```swift
var container: Container  // 変更可能で外部からも見える
```

外部のコードが `app.container = 別のコンテナ` と書き換えられてしまい、予期しない動作の原因になります。

### 該当コード

```swift
private let container: Container
```

---

## 概念 5 — `init()`：イニシャライザ

### これは何か？

`init()` は **初期化メソッド** です。structやclassのインスタンスが作られるとき（`TenSlideApp()` が呼ばれるとき）に自動的に実行されます。すべての `let` プロパティは `init()` の中で必ず値を設定しなければなりません。

### なぜここで使われているか？

`container` を初期化するためです。`Container()` はエラーを投げる可能性があるため（`throws`）、`init()` の中で `do-catch` を使って安全に扱う必要があります。Swiftのルール上、`let` プロパティは宣言時に初期値を与えるか `init()` の中で設定するかのどちらかです。

### もし使わなかったら？

```swift
private let container: Container = Container()
// ❌ Container() は throws なので、ここでは直接呼べません
```

`throws` な関数を `try` なしで呼ぶとコンパイルエラーになります。`init()` を明示的に書くことで `do-catch` を使う場所を確保しています。

### 該当コード

```swift
init() {
    do {
        container = try Container()
    } catch {
        fatalError("DI initialization failed: \(error)")
    }
}
```

---

## 概念 6 — `do-catch` / `fatalError`：エラーハンドリング

### これは何か？

**`do-catch`** はエラーが発生しうる処理を安全に実行するための構文です。

- `do { }` ブロック：エラーが発生するかもしれない処理を書く
- `try`：エラーを投げる可能性がある関数の前に付ける
- `catch { }` ブロック：エラーが発生したときの処理を書く

**`fatalError()`** はプログラムを即座に強制終了させる関数です。回復不可能な状態を示すために使います。

### なぜここで使われているか？

`Container()` の初期化は失敗する可能性があります（例：必要なファイルが見つからないなど）。もし失敗したままアプリを動かすと、`container` が未初期化のままになり、クラッシュや不正な動作が起きます。ここでは「初期化できなければアプリを起動しない」という判断をしています。

`fatalError` を使うのは、DIコンテナの初期化失敗はアプリが正常に動作できないことを意味し、ユーザーに中途半端な状態を見せるより、明確に終了させる方が安全だからです。

### もし `do-catch` なしで書いたら？

```swift
// try? を使った場合（失敗を無視してnilにする）
container = try? Container()
// ❌ container は Optional<Container> になってしまい、
//    型が合わなくなるうえ、失敗しても気づけません
```

### `\(error)` について（文字列補間）

`"\(error)"` はSwiftの **文字列補間** です。`\( )` の中に式を書くと、その値を文字列に埋め込めます。

```swift
let name = "Swift"
print("Hello, \(name)!")  // → "Hello, Swift!"
```

### 該当コード

```swift
do {
    container = try Container()
} catch {
    fatalError("DI initialization failed: \(error)")
}
```

---

## 概念 7 — `var body: some Scene`：プロパティ、Scene プロトコル、`some` キーワード

### これは何か？

この一行には3つの要素が含まれています。

**`var body`**：変更可能なプロパティです（ただし実際には再計算されるだけで外から変更するわけではありません）。`App` プロトコルが「`body` プロパティを用意せよ」と要求しているため必須です。

**`Scene`**：アプリの画面（ウィンドウグループなど）を表すプロトコルです。macOSアプリのウィンドウやメニューバーなどは `Scene` の一種です。

**`some Scene`**：`some` は **不透明型（Opaque Type）** と呼ばれるSwiftの機能です。「`Scene` プロトコルに準拠している何らかの具体的な型を返す」という意味です。

### なぜ `some` を使うのか？

`body` が実際に返す型は `WindowGroup<ContentView>` という複雑な型です。これを毎回正確に書くのは大変ですし、実装を変えるたびに型の記述も変える必要が生じます。`some Scene` と書けば「Sceneプロトコルに準拠した何かを返す」とだけ宣言でき、具体的な型はコンパイラが推論してくれます。

### もし `some` なしで書いたら？

```swift
// some なし
var body: Scene { ... }
// ❌ プロトコル型 'any Scene' を返り値の型として使うには
//    'any Scene' と書く必要があります（Swift 5.7+）
```

また `any Scene` にすると型消去（type erasure）が発生し、コンパイラの最適化が効きにくくなります。`some` の方がパフォーマンスと型安全性の両面で優れています。

### 該当コード

```swift
var body: some Scene {
```

---

## 概念 8 — `WindowGroup { }`：ウィンドウの定義とトレイリングクロージャ

### これは何か？

**`WindowGroup`** はmacOS/iOS アプリでウィンドウを定義するSwiftUIの型です。`{ }` の中に書いたViewがウィンドウの中身になります。

`{ }` の書き方は **トレイリングクロージャ（Trailing Closure）** と呼ばれる構文糖衣です。関数の最後の引数がクロージャ（関数型の引数）のとき、括弧の外に `{ }` で書けます。

```swift
// 本来の書き方
WindowGroup(content: { ContentView(...) })

// トレイリングクロージャ（同じ意味）
WindowGroup {
    ContentView(...)
}
```

### なぜここで使われているか？

SwiftUI のUIは「宣言的」に書きます。`WindowGroup { ContentView(...) }` は「このウィンドウグループの中身は ContentView です」と宣言しているだけで、ウィンドウをいつ・どのように表示するかはSwiftUIフレームワークが管理します。

### 該当コード

```swift
WindowGroup {
    ContentView(
        thumbnailViewModel: container.presentation.makeThumbnailViewModel(),
        createViewModel: container.presentation.makeCreateSlideshowViewModel(),
        makeSlideshowPlayerViewModel: container.presentation.makeSlideshowPlayerViewModel,
        makeSpritePlayerViewModel: container.presentation.makeSpritePlayerViewModel,
        makeSlideshowLibraryViewModel: container.presentation.makeSlideshowLibraryViewModel
    )
}
```

`ContentView(...)` の引数に注目してください。`container.presentation.make〇〇ViewModel()` と呼ぶことで、DIコンテナからViewModelを取り出して渡しています。これがDI（依存性注入）の実践です。Viewが自分でViewModelを生成するのではなく、外から受け取ることで、テストや差し替えが容易になります。

---

## 概念 9 — `.modelContainer()`：修飾子（Modifier）と SwiftData

### これは何か？

**修飾子（Modifier）** はSwiftUIのViewやSceneに対してドット（`.`）でチェーンする関数呼び出しです。見た目は「プロパティの設定」ですが、実際は新しいScene/Viewを返す関数です。

**`.modelContainer()`** はSwiftDataの修飾子で、SwiftUIの環境にデータストア（ModelContainer）を注入します。一度ここで設定すると、子Viewすべてから `@Environment(\.modelContext)` でデータベース操作が可能になります。

### なぜここで使われているか？

SwiftDataのモデルコンテナを最上位のSceneレベルで登録することで、アプリ内のすべてのViewがデータにアクセスできるようになります。ここで渡している `container.infrastructure.modelContainer` は、DIコンテナのInfrastructureレイヤーが管理するModelContainerインスタンスです。

### もし `.modelContainer()` がなかったら？

```swift
// .modelContainer() を書かなかった場合
WindowGroup { ContentView(...) }
// → 子Viewが @Query や @Environment(\.modelContext) を使おうとすると
//   実行時エラーになります（モデルコンテナが未設定）
```

### 修飾子はチェーンできる

```swift
WindowGroup { ... }
    .modelContainer(...)
    .commands { ... }  // さらに別の修飾子を追加することもできます
```

### 該当コード

```swift
.modelContainer(container.infrastructure.modelContainer)
```

---

## 実践で学んだ落とし穴

このプロジェクトの開発中に発見した、macOS の SwiftUI 開発で知っておくべきポイントです。

---

### 落とし穴 1: macOS で `.navigationTitle()` がウィンドウタイトルになる

#### 何が起きるか

macOS では、`WindowGroup` 内のルートビューに `.navigationTitle()` を付けると、その文字列が**ウィンドウのタイトルバー**に表示されます。`NavigationStack` や `NavigationSplitView` がなくても機能します。

これは iOS 開発の経験だけでは気づきにくい挙動です。iOS では `.navigationTitle()` はナビゲーションバーに表示されるだけで、ウィンドウタイトルという概念がありません。

#### 正しい書き方

```swift
// ✅ .navigationTitle() でウィンドウタイトルを制御する（NavigationStack は不要）
var body: some Scene {
    WindowGroup {
        if let slideshow = currentSlideshow {
            SlideshowPlayerView(slideshow: slideshow)
                .navigationTitle(slideshow.name)   // → タイトルバーにスライドショー名が表示される
        } else {
            HomeView()
                .navigationTitle("")               // → タイトルバーのテキストを非表示にする
        }
    }
}
```

`if`/`else` の各分岐に `.navigationTitle()` を付けることで、アプリの状態に応じてウィンドウタイトルを動的に切り替えられます。

#### やってはいけない書き方

```swift
// ❌ NSViewRepresentable を使ってウィンドウタイトルを設定しようとする — 過剰に複雑
struct WindowTitleSetter: NSViewRepresentable {
    let title: String
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title  // タイミングによっては window が nil
        }
        return view
    }
    // ...
}
```

**ポイント**: macOS の SwiftUI では `.navigationTitle()` がウィンドウタイトルを設定する正式な方法です。`NSViewRepresentable` で `window?.title` を直接操作する必要はありません。

---

## このファイルで学べること

| 概念 | キーワード | 一言まとめ |
|------|-----------|-----------|
| フレームワーク読み込み | `import` | 外部ライブラリを使えるようにする |
| エントリーポイント | `@main` | アプリの起動地点を宣言する属性 |
| プロトコル準拠 | `struct ... : App` | 「この型はこのルールに従います」という宣言 |
| アクセス制御と定数 | `private let` | 外から見えず変更もできないプロパティ |
| 初期化 | `init()` | インスタンス生成時に自動実行される処理 |
| エラーハンドリング | `do-catch` / `try` / `fatalError` | エラーを安全に捕捉し、回復不能なら終了する |
| 不透明型 | `some Scene` | 「このプロトコルに準拠した何か」を返す |
| ウィンドウ定義 | `WindowGroup { }` | アプリのウィンドウとその中身を宣言する |
| 修飾子 | `.modelContainer()` | SwiftUI/SwiftDataの機能をチェーンで追加する |

### まとめ

このファイルは小さいですが、Swiftアプリ開発の基礎が詰まっています。

1. **`import`** でライブラリを読み込み
2. **`@main` + `App` プロトコル** でアプリの起動口を定義し
3. **`init()` + `do-catch`** でエラーになりうる初期化を安全に行い
4. **`some Scene` + `WindowGroup`** で宣言的にUIを組み立て
5. **`.modelContainer()`** でデータ層をアプリ全体に届ける

この流れを理解すると、「SwiftUIアプリがどう動き始めるか」の全体像が見えてきます。
