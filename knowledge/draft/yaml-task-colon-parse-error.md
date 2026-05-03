---
title: Pipeline YAML — task フィールドのコロンが BLOCK_AS_IMPLICIT_KEY エラーを引き起こす
tags: [pipeline, yaml, gotcha]
---

## 問題

パイプライン YAML の `task:` フィールドに `": "` (コロン＋スペース) を含む文字列をインライン値として書くと、YAML パーサーが nested mapping と誤解釈してエラーになる。

```yaml
# NG — feat(layer): の ": " がマッピングキーとして解釈される
- type: agent
  task: Implementation complete. Commit with message (e.g. feat(layer): ...).
```

エラー: `YAMLParseError: Nested mappings are not allowed in compact mappings`  
コード: `BLOCK_AS_IMPLICIT_KEY`

コンベンショナルコミットメッセージの例示 (`feat(scope): ...`) がそのままトリガーになるため、コミットエージェントの task で頻発する。

## 修正

コロンを含む可能性がある `task:` 値は **必ずブロックスカラー `|`** を使う。

```yaml
# OK
- type: agent
  task: |
    Implementation complete. Commit with message (e.g. feat(layer): ...).
```

## 適用範囲

- `pipelines/` 以下のすべての YAML ファイル
- `.claude/skills/meta-pipeline-creator/examples/` の example ファイル
- meta-pipeline-creator が生成するコミットエージェントの task

## 教訓

`validate-schema.cjs` を実行すれば即座に検出できる。example ファイルもスキーマ検証の対象に含めること（CI や skill 更新時に実行する）。
