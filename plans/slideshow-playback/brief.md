# Goal

写真を選択してタイマー付きスライドショーを再生する機能を追加する。トランジション種別と表示秒数を YAML 設定ファイルで外部編集可能にし、再生画面下部に自動非表示のフィルムストリップを配置する。

# Key Design Decisions

- `SlideshowConfig` は Domain Entity (struct, Codable) として定義し、Infrastructure 層の `ConfigStore` actor が YAML ファイルとの I/O を担う
- `Slide.duration` で個別スライドの秒数を上書き可能。`SlideshowConfig.defaultDuration` はスライド作成時の初期値
- 再生タイマーは Presentation 層 ViewModel で管理（UI ライフサイクルと密結合のため）
- YAML パーサーには Yams (SPM) を使用
- スライド個別のトランジション指定は初期スコープ外
