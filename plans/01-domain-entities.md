# 01 — Domain Entities

## 現状

既存の Entity は 2 つ。

```swift
// Sources/Domain/Entities/Slide.swift
struct Slide: Identifiable, Equatable, Sendable {
    let id: UUID
    let localIdentifier: String  // Photos asset identifier
    var order: Int
    var duration: TimeInterval
    var title: String?
}

// Sources/Domain/Entities/Slideshow.swift
struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var createdAt: Date
}
```

## 追加する Entity

### TransitionType

トランジション種別の enum。YAML config から読み込まれる。

```swift
// Sources/Domain/Entities/TransitionType.swift
enum TransitionType: String, Equatable, Sendable, CaseIterable, Codable {
    case none
    case fade
    case slide
    case dissolve
}
```

`String` rawValue にすることで YAML との相互変換がシンプルになる。

### SlideshowConfig

スライドショー全体のデフォルト設定。YAML ファイルで外部編集可能。

```swift
// Sources/Domain/Entities/SlideshowConfig.swift
struct SlideshowConfig: Equatable, Sendable, Codable {
    var defaultDuration: TimeInterval   // スライド1枚あたりの表示秒数（デフォルト）
    var transition: TransitionType      // トランジション種別
    var loop: Bool                      // ループ再生するか

    static let `default` = SlideshowConfig(
        defaultDuration: 5.0,
        transition: .fade,
        loop: true
    )
}
```

## 既存 Entity への変更

### Slideshow

Config への参照を追加する。

```swift
// Sources/Domain/Entities/Slideshow.swift
struct Slideshow: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var slides: [Slide]
    var config: SlideshowConfig    // 追加
    var createdAt: Date
}
```

### Slide — 変更なし

`Slide.duration` は既にスライド単位の表示秒数を持つ。
`SlideshowConfig.defaultDuration` はスライド作成時の初期値として使い、
個別の `Slide.duration` で上書き可能とする。

## 優先度についての判断

- `Slide.transition` (スライド個別のトランジション) は初期スコープ外。全体設定のみで開始する。
- `SlideshowConfig` に `Codable` を付与するのは YAML 変換のためだが、実際のエンコード/デコード処理は Infrastructure 層で行う。Domain 層は `Codable` 準拠の宣言のみ。

## ファイル構成（変更後）

```
Sources/Domain/Entities/
├── Slide.swift              // 変更なし
├── Slideshow.swift           // config フィールド追加
├── SlideshowConfig.swift     // 新規
└── TransitionType.swift      // 新規
```
