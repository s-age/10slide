# SlideshowPlayerView — Swift 概念ガイド

**対象ファイル**: `Sources/Presentation/Views/SlideshowPlayerView.swift`

**概要**: スライドショーを全画面再生する View。写真を順番に表示し、キーボード・ドラッグ・タップで操作できる。フィルムストリップ（サムネイル一覧）の表示/非表示、トランジションアニメーション、フルスクリーンヒント表示も担う。

---

## 目次

1. [struct … : View — View プロトコル](#1-struct--view--view-プロトコル)
2. [let vs var — プロパティの宣言](#2-let-vs-var--プロパティの宣言)
3. [@escaping クロージャ — ライフサイクルを超えるクロージャ](#3-escaping-クロージャ--ライフサイクルを超えるクロージャ)
4. [var body: some View — body プロパティと some キーワード](#4-var-body-some-view--body-プロパティと-some-キーワード)
5. [ZStack・HStack — レイアウトコンテナ](#5-zstackhstack--レイアウトコンテナ)
6. [.ignoresSafeArea() — セーフエリア](#6-ignoressafearea--セーフエリア)
7. [.frame()・.padding() — レイアウト修飾子](#7-framepadding--レイアウト修飾子)
8. [if let — Optional バインディング](#8-if-let--optional-バインディング)
9. [.task { } — 非同期タスク修飾子](#9-task---非同期タスク修飾子)
10. [.onKeyPress() — キーボードイベント](#10-onkeypress--キーボードイベント)
11. [.onTapGesture・.simultaneousGesture・DragGesture — ジェスチャー](#11-ontapgesturesimultaneousgesturedraggesture--ジェスチャー)
12. [.animation() — アニメーション](#12-animation--アニメーション)
13. [.transition() — トランジション](#13-transition--トランジション)
14. [@ViewBuilder — ビュービルダー属性](#14-viewbuilder--ビュービルダー属性)
15. [AnyTransition — 型消去されたトランジション](#15-anytransition--型消去されたトランジション)
16. [.onReceive(NotificationCenter…) — 通知の監視](#16-onreceivenotificationcenter--通知の監視)
17. [.onHover — ホバーイベント](#17-onhover--ホバーイベント)
18. [Task { await … } — クロージャ内での非同期呼び出し](#18-task--await---クロージャ内での非同期呼び出し)
19. [.id() — ビューの一意識別](#19-id--ビューの一意識別)
20. [実践で学んだ落とし穴](#20-実践で学んだ落とし穴)
21. [このファイルで学べること — まとめ](#21-このファイルで学べること--まとめ)

---

## 1. `struct … : View` — View プロトコル

### 何であるか

`struct SlideshowPlayerView: View` は「`SlideshowPlayerView` という名前の構造体（struct）を定義し、`View` プロトコルに準拠させる」という宣言です。

**プロトコル**とは「このルールを守ってください」という約束事の集まりです。`View` プロトコルは「`body` プロパティを必ず実装すること」を要求します。SwiftUI はこの `body` を読んで画面を描画します。

### なぜここで使われているか

SwiftUI のすべての画面部品は `View` プロトコルに準拠する必要があります。`View` に準拠することで、`ZStack` や `.task` といった SwiftUI の修飾子・コンテナが使えるようになります。

### もし使わなかったら

`View` に準拠しない struct は SwiftUI の画面ツリーに組み込めません。`body` プロパティを持てず、`.frame()` などの修飾子も呼べません。

```swift
struct SlideshowPlayerView: View {   // View プロトコルに準拠することを宣言
    // ...
}
```

---

## 2. `let` vs `var` — プロパティの宣言

### 何であるか

`let` は**定数**（一度代入したら変更不可）、`var` は**変数**（後から変更可能）です。

### なぜここで使われているか

このファイルでは、View が受け取るすべての入力プロパティが `let` で宣言されています。

```swift
let viewModel: SlideshowPlayerViewModel
let thumbnailViewModel: ThumbnailViewModel
let onBack: () -> Void
let onSpriteMode: ((Int) -> Void)?
```

これらは **View の外から渡されるもの**で、View 自身が変更する必要はありません。`let` にすることで「この View はこれらの値を書き換えない」という意図が明確になり、コンパイラが誤った書き換えを検出してくれます。

一方、`body` は `var` です。これは `View` プロトコルが `var body` を要求しているためで、SwiftUI が状態変化のたびに `body` を再計算できるようにする設計上の理由があります。

### もし `let` の代わりに `var` を使ったら

コンパイルは通りますが、「この値は変わりうる」という誤ったメッセージを読み手に与えます。意図を正確に伝えるために `let` を選ぶことが Swift のベストプラクティスです。

---

## 3. `@escaping` クロージャ — ライフサイクルを超えるクロージャ

### 何であるか

クロージャ（`{ }` で書く無名関数）をプロパティとして保存したり、非同期に呼び出す場合、`@escaping` 属性が必要です。「このクロージャは関数の呼び出しが終わった後も生き続ける（脱出する）かもしれない」とコンパイラに伝えます。

### なぜここで使われているか

```swift
init(
    viewModel: SlideshowPlayerViewModel,
    thumbnailViewModel: ThumbnailViewModel,
    onBack: @escaping () -> Void,          // @escaping
    onSpriteMode: ((Int) -> Void)? = nil   // Optional なので暗黙的に @escaping
) {
    self.onBack = onBack       // ← struct のプロパティとして保存している
```

`onBack` は `init` が終わった後も `self.onBack` として保存され、ボタンが押されたときに呼び出されます。「呼び出し元の `init` が終わった後も生き残る」ため `@escaping` が必要です。

`onSpriteMode` が `Optional` 型（`?` あり）なのに `@escaping` が省略されているのは、Optional クロージャはコンパイラが自動的に escaping として扱うためです。

### もし `@escaping` を付けなかったら

コンパイルエラーになります。Swift はデフォルトで「クロージャは関数の実行中だけ使われる（non-escaping）」と仮定するため、プロパティへの保存を禁止します。

---

## 4. `var body: some View` — body プロパティと `some` キーワード

### 何であるか

`body` は View プロトコルが要求する必須プロパティです。ここに「画面に何を表示するか」を書きます。

`some View` の `some` は**不透明型（opaque type）**と呼ばれます。「`View` に準拠する何らかの具体的な型」を返すが、その型名は外に公開しない、という意味です。

### なぜここで使われているか

`body` の中身は `ZStack` の中に `Color`、`Image`、`FilmstripView` などが組み合わさった複雑な型になります。その型を `ZStack<TupleView<(Color, some View, ...)>>` のように書くのは非現実的です。`some View` と書くことで「型の詳細はコンパイラに任せる」ことができます。

```swift
var body: some View {
    ZStack(alignment: .bottom) {
        // ...
    }
    .animation(...)
    .task { ... }
}
```

### もし `some` を使わなかったら

戻り値の型を正確に書く必要があり、コードが非常に複雑になります。また、型が変わるたびに書き直しが必要になります。

---

## 5. `ZStack`・`HStack` — レイアウトコンテナ

### 何であるか

SwiftUI のレイアウトコンテナは、複数のビューをどのように配置するかを決めます。

| コンテナ | 配置方向 |
|---------|---------|
| `ZStack` | 奥から手前へ**重ね合わせる**（Z 軸方向） |
| `HStack` | 左から右へ**横に並べる**（Horizontal） |
| `VStack` | 上から下へ**縦に並べる**（Vertical） |

### なぜここで使われているか

**ZStack**: スライドショーは「黒背景の上に画像、その上にフィルムストリップ、さらにその上にヒント表示」という重ね合わせ構造です。`ZStack` がこれに最適です。

```swift
ZStack(alignment: .bottom) {
    Color.black          // 一番奥：黒背景
        .ignoresSafeArea()

    slideImage           // 中間：スライド画像

    if viewModel.showFilmstrip {
        FilmstripView(...)   // 手前：フィルムストリップ（下部）
    }
}
```

`alignment: .bottom` は、デフォルトの配置（中央）ではなく下揃えにする指定です。

**HStack**: 「スプライトモードボタン」と「閉じるボタン」を横に並べるために使っています。

```swift
HStack(spacing: 0) {
    if let onSpriteMode { Button { ... } }
    Button { onBack() } label: { ... }
}
```

### もし使わなかったら

コンテナなしでは複数のビューを並べて配置できません。SwiftUI では必ずコンテナの中にビューを入れる必要があります。

---

## 6. `.ignoresSafeArea()` — セーフエリア

### 何であるか

**セーフエリア**とは、ノッチ・ホームインジケーター・画面端のシステム UI に被らない「安全な表示領域」です。デフォルトでは、SwiftUI のビューはセーフエリアの内側にのみ描画されます。

`.ignoresSafeArea()` を付けると、セーフエリアを無視して画面端まで広がります。

### なぜここで使われているか

スライドショーの黒背景は画面全体を覆う必要があります。セーフエリアを無視しないと、ノッチ周辺や画面端に背景色が当たらない隙間が生じます。

```swift
Color.black
    .ignoresSafeArea()   // 画面の端から端まで黒くする
```

### もし使わなかったら

macOS では影響が少ないですが、iOS/iPadOS のノッチやダイナミックアイランド周辺に黒以外の色（システム背景）が見えてしまいます。

---

## 7. `.frame()`・`.padding()` — レイアウト修飾子

### 何であるか

SwiftUI では、ビューに `.修飾子名()` を連鎖的に付けることでサイズ・余白・見た目を変えられます。これを**修飾子（modifier）**といいます。

- `.frame(maxWidth:maxHeight:)` — ビューの推奨サイズを指定する
- `.padding()` — ビューの周囲に余白を追加する

### なぜここで使われているか

```swift
slideImage
    .frame(maxWidth: .infinity, maxHeight: .infinity)  // 利用可能な最大サイズまで広げる
```

`maxWidth: .infinity` は「横幅は親ビューの許す限り最大にして」という指示です。スライド画像を画面全体に広げるために使っています。

```swift
Image(systemName: "xmark.circle.fill")
    .padding(16)   // アイコンの周囲に16ポイントの余白を付けてタップしやすくする
```

ボタンのアイコンは小さいため、`.padding()` でタップ領域を広げています。

### もし使わなかったら

`.frame()` がないと、ビューは内容に合わせた最小サイズになり、画面を埋めません。`.padding()` がないと、アイコンが端に密着してタップしにくくなります。

---

## 8. `if let` — Optional バインディング

### 何であるか

`Optional`（`?` 型）は「値があるかもしれないし、ないかもしれない（nil）」を表す型です。`if let` は「値があれば取り出して使う、なければスキップする」構文です。

### なぜここで使われているか

このファイルでは 3 箇所で使われています。

**① スプライトモードボタンの表示判定**

```swift
if let onSpriteMode {
    Button {
        onSpriteMode(viewModel.currentIndex)
    } label: { ... }
}
```

`onSpriteMode` は `((Int) -> Void)?`（Optional なクロージャ）です。渡されていない場合（`nil`）はボタンを表示しない、という条件分岐です。

**② フルスクリーンヒントの表示**

```swift
if let hint = viewModel.fullscreenHint {
    fullscreenHintOverlay(hint)
}
```

ヒントが存在する（非 nil）ときだけオーバーレイを表示します。

**③ スライド画像の表示**

```swift
if let nsImage = viewModel.currentNSImage {
    Image(nsImage: nsImage)
        .resizable()
        .scaledToFit()
} else {
    Color.black
}
```

画像が読み込まれていれば表示、まだロード中（`nil`）なら黒で代替します。

### もし使わなかったら

`if let` なしで Optional を使うと、`nil` の場合にクラッシュします。強制アンラップ（`!`）は避けるべきで、`if let` が安全な方法です。

---

## 9. `.task { }` — 非同期タスク修飾子

### 何であるか

`.task { }` はビューが**表示されたときに非同期処理を開始**し、**ビューが非表示になったときに自動でキャンセル**する修飾子です。

`async/await` は Swift の非同期処理の仕組みです。`await` のついた処理は「完了を待つが、その間スレッドをブロックしない」という意味です。

### なぜここで使われているか

```swift
.task {
    await viewModel.loadCurrentImage()   // 画像を非同期でロード
    viewModel.play()                     // ロード完了後に再生開始
}
```

スライドショーが表示されたら画像をロードして再生を開始するという初期化処理です。`await` があるため、`.task { }` の中でないと呼び出せません。

### `onAppear` との違い

```swift
// NG な例（アーキテクチャルールでも禁止）
.onAppear {
    Task { await viewModel.loadCurrentImage() }  // ビューが消えてもキャンセルされない
}

// 推奨
.task {
    await viewModel.loadCurrentImage()           // ビューが消えると自動キャンセル
}
```

`.task { }` はビューのライフサイクルと同期してキャンセルされるため、**メモリリークや不要な処理の防止**になります。

---

## 10. `.onKeyPress()` — キーボードイベント

### 何であるか

`.onKeyPress(_:)` は特定のキーが押されたときの処理を登録する修飾子です。`.focusable()` と組み合わせて使います。`.focusable()` はビューがキーボードフォーカスを受け取れるようにします。

戻り値の `.handled` は「このキー入力は処理済み（他に伝播させない）」という意味です。

### なぜここで使われているか

```swift
.focusable()
.onKeyPress(.space) {
    if viewModel.isPlaying { viewModel.pause() } else { viewModel.play() }
    return .handled   // スペースキーのデフォルト動作を上書き
}
.onKeyPress(.leftArrow) {
    Task { await viewModel.previous() }
    return .handled
}
.onKeyPress(.rightArrow) {
    Task { await viewModel.userDidNext() }
    return .handled
}
```

スライドショーをキーボードで操作できるようにしています。スペースで再生/一時停止、矢印キーで前後のスライドへ移動します。

### もし使わなかったら

マウスやタッチでしか操作できなくなり、キーボードユーザーの使い勝手が大きく下がります。

---

## 11. `.onTapGesture`・`.simultaneousGesture`・`DragGesture` — ジェスチャー

### 何であるか

- `.onTapGesture { }` — タップ（クリック）を検出する
- `DragGesture` — ドラッグ操作を検出する
- `.simultaneousGesture(_:)` — 他のジェスチャーと**同時に**認識させる

### なぜここで使われているか

**タップ**:

```swift
.onTapGesture {
    viewModel.userDidInteract()   // タップでフィルムストリップを表示
}
```

画面をタップするとフィルムストリップ（操作 UI）が表示されます。

**ドラッグ（スワイプ）**:

```swift
.simultaneousGesture(
    DragGesture(minimumDistance: 20)
        .onEnded { value in
            let dx = value.translation.width   // 横方向の移動量
            let dy = value.translation.height  // 縦方向の移動量
            if abs(dx) > abs(dy) {
                if dx < -50 {
                    Task { await viewModel.userDidNext() }    // 左スワイプ → 次へ
                } else if dx > 50 {
                    Task { await viewModel.previous() }      // 右スワイプ → 前へ
                }
            } else {
                viewModel.userDidInteract()   // 縦スワイプ → インタラクション扱い
            }
        }
)
```

`minimumDistance: 20` は「20ポイント以上動いたらドラッグとみなす」設定です。これにより誤タップを防ぎます。

`.simultaneousGesture(_:)` を使う理由は、`.onTapGesture` と **同時に** 認識させるためです。通常、SwiftUI は複数のジェスチャーが競合すると一方だけを選びますが、`.simultaneousGesture` を使うと両方が独立して動作します。

### もし `.simultaneousGesture` の代わりに `.gesture` を使ったら

タップとドラッグが競合し、どちらか一方しか認識されなくなります。

---

## 12. `.animation()` — アニメーション

### 何であるか

`.animation(_:value:)` は、指定した値が変化したときにアニメーションを適用する修飾子です。値が変わると、その変化を SwiftUI が滑らかな動きとして描画します。

### なぜここで使われているか

```swift
.animation(.easeInOut(duration: 0.5), value: viewModel.currentIndex)
.animation(.easeInOut(duration: 0.3), value: viewModel.showFilmstrip)
.animation(.easeInOut(duration: 0.5), value: viewModel.fullscreenHint)
```

3 つの値それぞれに対してアニメーションを設定しています。

- `currentIndex` が変わる → スライドの切り替えアニメーション（0.5秒）
- `showFilmstrip` が変わる → フィルムストリップの表示/非表示アニメーション（0.3秒）
- `fullscreenHint` が変わる → ヒント表示のフェードアニメーション（0.5秒）

`.easeInOut` は「始めと終わりがゆっくり、中間が速い」自然な動きのカーブです。

### もし使わなかったら

値が変わった瞬間に画面がパっと切り替わります。ユーザーに何が起きたのか伝わりにくくなります。

---

## 13. `.transition()` — トランジション

### 何であるか

`.transition(_:)` はビューが**表示される・消える瞬間**のアニメーションを指定します。`.animation()` が「値の変化」に対するアニメーションなのに対して、`.transition()` は「ビューの出現・消滅」専用です。

### なぜここで使われているか

```swift
slideImage
    .transition(slideTransition)   // スライド切り替え時のトランジション
```

```swift
FilmstripView(...)
    .transition(.move(edge: .bottom).combined(with: .opacity))
    // 下から滑り込みながらフェードイン、下に滑り出しながらフェードアウト
```

```swift
if let hint = viewModel.fullscreenHint {
    fullscreenHintOverlay(hint)
        .transition(.opacity)   // フェードイン/フェードアウト
}
```

`.combined(with:)` は複数のトランジションを組み合わせます。「移動 + 透明度変化」を同時に適用しています。

### もし使わなかったら

ビューが瞬間的に出現・消滅します。`if` による条件分岐でビューが入れ替わるたびにぎこちない表示になります。

---

## 14. `@ViewBuilder` — ビュービルダー属性

### 何であるか

`@ViewBuilder` は「この関数やプロパティの中で SwiftUI のビューを構築できる」ことを示す属性です。`if/else` や `switch` を使ってビューを返せるようになります。

### なぜここで使われているか

このファイルでは 2 つのプロパティ・メソッドに `@ViewBuilder` が付いています。

```swift
@ViewBuilder
private func fullscreenHintOverlay(_ hint: SlideshowPlayerViewModel.FullscreenHintType) -> some View {
    let label: String = switch hint {   // hint の値によってラベルを切り替え
    case .enter: "Full Screen: Fn+F"
    case .exit: "Exit Full Screen: Esc"
    }
    // ...
    Label(label, systemImage: icon)
        .font(.callout)
        // ...
}
```

```swift
@ViewBuilder
private var slideImage: some View {
    if let nsImage = viewModel.currentNSImage {   // 条件分岐でビューを返す
        Image(nsImage: nsImage)
    } else {
        Color.black
    }
}
```

`slideImage` は `if/else` で異なる型のビュー（`Image` または `Color`）を返しています。`@ViewBuilder` がないと、戻り値の型が一致しないためコンパイルエラーになります。

### もし使わなかったら

条件分岐を含む関数で `some View` を返せなくなります。または三項演算子 `? :` などで書き直す必要があり、複雑になります。

---

## 15. `AnyTransition` — 型消去されたトランジション

### 何であるか

`.opacity`、`.move(edge:)`、`.slide` など、SwiftUI のトランジションはそれぞれ異なる型を持っています。`AnyTransition` はこれらの型を**消去（erase）**して統一的に扱える型です。

### なぜここで使われているか

```swift
private var slideTransition: AnyTransition {
    switch viewModel.slideshow.config.transition {
    case .none:
        return .identity          // AnyTransition.identity
    case .fade, .dissolve:
        return .opacity           // AnyTransition.opacity
    case .slide:
        return .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        )
    }
}
```

`switch` で場合分けして**異なるトランジションを返す**ためには、戻り値の型を統一する必要があります。それぞれのトランジションは異なる型（`OpacityTransition`、`MoveTransition` など）ですが、すべて `AnyTransition` に包まれているため、ひとつの関数/プロパティから返せます。

`.asymmetric` は「出現時と消滅時で別々のトランジション」を設定できる特別なトランジションです。スライドが右から入って左へ出る「スライド送り」の動きを実現しています。

### もし `AnyTransition` を使わなかったら

`switch` の各ケースで異なる型を返せず、コンパイルエラーになります。型消去は Swift で多態性を実現するための重要なパターンです。

---

## 16. `.onReceive(NotificationCenter…)` — 通知の監視

### 何であるか

**NotificationCenter** は「何かが起きた」というイベントをアプリ全体に広報する仕組みです。`.onReceive(_:)` は特定の通知が届いたときに処理を実行する修飾子です。

### なぜここで使われているか

```swift
.onReceive(
    NotificationCenter.default.publisher(
        for: NSWindow.didEnterFullScreenNotification
    )
) { _ in
    viewModel.windowDidEnterFullScreen()
}
```

macOS でウィンドウがフルスクリーンになると、システムが `NSWindow.didEnterFullScreenNotification` を発信します。この通知を受け取って ViewModel に伝えています。

`NotificationCenter.default.publisher(for:)` は Combine フレームワークの Publisher で、通知を非同期ストリームとして扱えるようにするアダプターです。

### もし使わなかったら

フルスクリーン状態の変化を検知できなくなり、ヒント表示などの機能が動作しなくなります。

---

## 17. `.onHover` — ホバーイベント

### 何であるか

`.onHover { hovering in ... }` はマウスカーソルがビューの上に**乗った・離れた**ときに処理を実行する修飾子です。`hovering` が `true` のときカーソルが上にあり、`false` のとき離れています。

### なぜここで使われているか

このファイルでは 3 箇所に `.onHover` があります。

```swift
// フィルムストリップへのホバー
FilmstripView(...)
    .onHover { hovering in
        if hovering { viewModel.overlayHoverBegan() }
        else { viewModel.overlayHoverEnded() }
    }

// ボタン群へのホバー
HStack { ... }
    .onHover { hovering in
        if hovering { viewModel.overlayHoverBegan() }
        else { viewModel.overlayHoverEnded() }
    }

// 画面全体へのホバー
.onHover { hovering in
    if hovering { viewModel.userDidInteract() }
}
```

操作 UI（フィルムストリップ・ボタン）の上にカーソルがあるときは自動非表示のタイマーを止め、カーソルが離れたら再びタイマーを動かすという仕組みです。

### もし使わなかったら

ユーザーがフィルムストリップを操作中でも UI が自動で消えてしまい、使いにくくなります。

---

## 18. `Task { await … }` — クロージャ内での非同期呼び出し

### 何であるか

`async` 関数は `async` なコンテキスト（`async` 関数や `.task { }` モディファイア内）からしか呼べません。通常のクロージャ（例: ボタンの `action:`）は同期的なので、そのままでは `await` が使えません。

`Task { await ... }` は「非同期タスクを新たに作って中で `await` を使う」構文です。

### なぜここで使われているか

```swift
onSelect: { index in Task { await viewModel.jumpTo(index: index) } },
onNext: { Task { await viewModel.userDidNext() } },
```

`onSelect` や `onNext` は同期クロージャとして受け取られます。しかし `viewModel.jumpTo(index:)` は `async` 関数です。`Task { }` でラップすることで、同期クロージャから非同期処理を起動できます。

### `.task { }` との使い分け

| 状況 | 使うもの |
|------|---------|
| ビュー表示時の初期化処理 | `.task { }` |
| ボタン押下などイベント内からの非同期呼び出し | `Task { await ... }` |

`.task { }` はビューが消えると自動キャンセルされますが、`Task { }` はキャンセルされません。短時間で完了する操作（次のスライドへ移動など）には `Task { }` が適しています。

---

## 19. `.id()` — ビューの一意識別

### 何であるか

`.id(_:)` はビューに一意な識別子を付けます。SwiftUI は同じ ID を持つビューは「同じビュー」として再利用し、ID が変わったビューは「別のビュー」として作り直します。

### なぜここで使われているか

```swift
slideImage
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .id(viewModel.currentIndex)   // ← 現在のスライド番号を ID として使用
    .transition(slideTransition)
```

`currentIndex` が変わる（= スライドが切り替わる）と、SwiftUI は「古いビューが消えて新しいビューが出現した」と認識します。これにより `.transition()` が発火します。

`.id()` を使わない場合、SwiftUI はビューを再利用しようとするため、「出現・消滅」が発生せず `.transition()` のアニメーションが動きません。

### もし使わなかったら

スライドの切り替えアニメーション（`.transition(slideTransition)`）が機能しなくなり、画像がアニメーションなしで入れ替わります。

---

## 20. 実践で学んだ落とし穴

このファイルに関連する実際の開発で遭遇した落とし穴を紹介します。

### 落とし穴 1: `.task {}` と `Task {}` の使い分け

`.onAppear` の中で `Task {}` を作ると、**View が消えてもタスクがキャンセルされません**。画面遷移後も裏で処理が動き続け、すでに存在しない ViewModel に書き込もうとする危険があります。

```swift
// ❌ BAD — View が消えてもタスクが走り続ける
.onAppear {
    Task { await viewModel.loadCurrentImage() }
}
```

`.task { }` 修飾子を使えば、View が非表示になったときに**自動でキャンセル**されます。値の変化に応じて再実行したい場合は `.task(id:)` を使います。

```swift
// ✅ GOOD — View 消滅時に自動キャンセル
.task {
    await viewModel.loadCurrentImage()
    viewModel.play()
}

// ✅ GOOD — currentImage が変わるたびに前のタスクをキャンセルして再実行
.task(id: viewModel.currentImage) {
    guard let data = viewModel.currentImage else { return }
    decodedImage = await Task.detached(priority: .userInitiated) {
        NSImage(data: data)
    }.value
}
```

**使い分けの目安**:
| 状況 | 使うもの |
|------|---------|
| View 表示時のデータ読み込み | `.task { }` |
| 値が変わるたびに再実行したい処理 | `.task(id: value) { }` |
| ボタン押下など短時間で完了する操作 | `Task { await ... }` |
| View のライフサイクルと無関係な処理（ログ送信など） | `Task { }` |

**注意**: `.task` のキャンセルは**協調的**です。非同期処理の中で `Task.isCancelled` をチェックするか、キャンセル可能な API（`Task.sleep` など）を使わないと、実際には処理が止まりません。

---

### 落とし穴 2: LazyVGrid で正方形サムネイルが崩れる

フィルムストリップなどでサムネイルを正方形に表示したいとき、2つのよくある間違いがあります。

```swift
// ❌ BAD① — scaledToFill は画像のレイアウトサイズが枠を超え、
//           重なったボタンのヒットテストが壊れる
Image(nsImage: nsImage)
    .resizable()
    .scaledToFill()
    .frame(width: 80, height: 80)

// ❌ BAD② — LazyVGrid は高さを無限に提案するため、
//           .fill では正方形にならない
Image(nsImage: nsImage)
    .resizable()
    .aspectRatio(1, contentMode: .fill)
```

正解は、**まず幅を確定させてから `aspectRatio(1, contentMode: .fit)` で高さ = 幅にする**方法です。

```swift
// ✅ GOOD — 幅を先に確定し、アスペクト比で正方形にする
ZStack {
    Color.gray.opacity(0.15)           // レターボックス背景
    if let nsImage = image {
        Image(nsImage: nsImage)
            .resizable()
            .scaledToFit()             // 枠内に収まる
    }
}
.frame(maxWidth: .infinity)            // 列幅いっぱいに広げる
.aspectRatio(1, contentMode: .fit)     // 高さ = 幅 → 正方形
.clipShape(RoundedRectangle(cornerRadius: 6))
```

**ポイント**: `scaledToFill()` はレイアウトサイズがはみ出すため、上に重ねたボタンが押せなくなることがある。`scaledToFit()` + レターボックス背景の組み合わせが安全です。

---

### 落とし穴 3: 兄弟ビュー間のアクション連携

例えば「ライブラリパネルの編集ボタンを押したら、作成中のフォームに未保存データがあるか確認する」という処理。兄弟ビュー同士が直接やりとりしたくなりますが、**兄弟ビューが互いの ViewModel にアクセスするのはアンチパターン**です。

```swift
// ❌ BAD — 兄弟ビューが別の兄弟の ViewModel を直接参照
struct SlideshowLibraryPanel: View {
    let createViewModel: CreateSlideshowViewModel  // ← 本来別の兄弟が持つ ViewModel
    func onEditTapped() {
        if createViewModel.hasUnsavedWork { ... }  // ← 責務が曖昧になる
    }
}
```

正解は、**親ビューをコーディネーターとして使い、クロージャで連携する**方法です。

```swift
// ✅ GOOD — 親ビュー（HomeView）がコーディネーター役
struct HomeView: View {
    let createViewModel: CreateSlideshowViewModel

    var body: some View {
        HStack {
            SlideshowLibraryPanel(
                onEdit: { slideshow in handleEdit(slideshow) }  // クロージャで通知
            )
            LibraryPickerView(viewModel: createViewModel)
        }
    }

    private func handleEdit(_ slideshow: SlideshowResponse) {
        if createViewModel.hasUnsavedWork {
            pendingEditSlideshow = slideshow   // 確認ダイアログを表示
        } else {
            applyEdit(slideshow)              // 直接適用
        }
    }
}
```

**なぜ親ビューか**: 親ビューは両方の兄弟ビューの ViewModel を持っているため、ガードロジック（「未保存の作業がある？」）を置く自然な場所です。兄弟ビューはクロージャで「何かが起きた」と親に伝えるだけで、相手の存在を知る必要がありません。

---

## 21. このファイルで学べること — まとめ

| 概念 | 学べること |
|------|-----------|
| `struct … : View` | SwiftUI の画面部品はプロトコル準拠で作る |
| `let` vs `var` | 意図を型システムで表現する（不変・可変） |
| `@escaping` | クロージャがライフサイクルを超えるときの明示 |
| `some View` | 複雑な型を隠蔽する不透明型 |
| `ZStack`・`HStack` | ビューの積み重ね・水平配置 |
| `.ignoresSafeArea()` | システム UI を超えて画面端まで描画する |
| `.frame()`・`.padding()` | サイズと余白の宣言的な指定 |
| `if let` | Optional を安全に取り出す |
| `.task { }` | ビューライフサイクルと連動した非同期処理 |
| `.onKeyPress()` | キーボードショートカットの実装 |
| ジェスチャー | タップ・ドラッグの同時認識 |
| `.animation()` | 値の変化を滑らかなアニメーションに変換 |
| `.transition()` | ビューの出現・消滅をアニメーションする |
| `@ViewBuilder` | 条件分岐を含む View を返す関数を書く |
| `AnyTransition` | 異なるトランジション型を統一して扱う型消去 |
| `.onReceive` | システム通知をビューで受け取る |
| `.onHover` | マウスカーソルのホバー検知（macOS） |
| `Task { await }` | 同期クロージャから非同期処理を起動する |
| `.id()` | ビューの同一性を制御してトランジションを発火させる |

### 全体を通じて見えるパターン

1. **宣言的 UI**: SwiftUI では「どう見えるか」を宣言し、「いつ更新するか」はフレームワークに任せます。`.animation(value:)` も `.id()` も、この「宣言的」アプローチの典型です。

2. **修飾子チェーン**: `.frame()`, `.padding()`, `.transition()`, `.onTapGesture()` などをドットでつなぐのが SwiftUI の書き方です。読む順に「画面の奥から手前」「重要な処理から補助的な処理」という順序で並べると読みやすくなります。

3. **ライフサイクルの意識**: `.task { }` と `Task { }` の使い分けのように、処理がいつ始まっていつ終わるかを常に意識することが Swift/SwiftUI では重要です。
