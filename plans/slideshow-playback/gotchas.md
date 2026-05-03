# Gotchas

## テストファースト

この機能はテストファーストで実装する。各レイヤーの実装前に、まずテストを書くこと。

- **テストが仕様書になる**: プロトコルのシグニチャと期待される振る舞いをテストで先に定義し、テストが通るように実装する
- **Domain Entity のテストから始める**: `SlideshowConfig.default` の値、`TransitionType` の rawValue 変換、`Slideshow` に config が含まれること
- **Repository テストではプロトコルの Mock を使う**: DataSource プロトコルの Mock を作成し、DTO ↔ Entity 変換が正しいことを検証する
- **UseCase テストでは Repository の Mock を使う**: 入力に対する出力と、Repository メソッドの呼び出し回数を検証する
- **ViewModel テストでは UseCase の Mock を使う**: 状態遷移（isPlaying, currentIndex, showFilmstrip）が期待通りであることを検証する

## YAML 設定

- `ConfigStore` はファイル未存在時にデフォルト値を返す（エラーではない）
- YAML の `transition` フィールドは `TransitionType.rawValue` (String) で保存する
- ファイルパスは `Application Support/10slide/config.yml`

## SwiftData マイグレーション

- `SlideshowModel` にフィールドを追加するため、既存データがある場合はマイグレーションが必要になる可能性がある。初期段階ではデフォルト値で対応する。

## Photos フレームワーク

- `PHPhotoLibrary.authorizationStatus` チェックが必要。権限未取得時のハンドリングを忘れないこと。
