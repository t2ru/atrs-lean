---
type: Reference
title: "Rust: ランタイム・クレートの効果"
description: "Rust のランタイム・クレートが与える効果と、モデルへの写し方・dep: ロケータ。"
tags: [rust, language-pack]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Rust: ランタイム・クレートの効果

移植先として採用するクレートの効果は `TargetModel` に、移植元が使っているクレートの効果は `SourceModel` に写し、`dep:` ロケータを付ける。

| 分類 | 効果 | 写し方 | `dep:` / `lang:` の例 |
| --- | --- | --- | --- |
| 整数の溢れ | ビルドプロファイル（`overflow-checks`）で、パニックか折り返しかが変わる | `LangSemantics.Rust` のプロファイル引数 | `lang:rust#integer-overflow` |
| JSON | serde / serde_json: 未知のフィールドの扱い（`deny_unknown_fields`）、`Option` と欠落の区別、数値の範囲外の扱い | シリアライズ関数 | `dep:serde_json#from_str` |
| 日付 | chrono / time: 書式指定子の意味、タイムゾーンの既定値 | 書式関数 | `dep:chrono#NaiveDate` |
| HTTP | Web フレームワーク（axum 等）: 抽出器の失敗時のステータス、パスの正規化、フォームの空文字の扱い | HTTP 契約の写し | `dep:axum#extract` |
| DB | sqlx 等: トランザクションの既定、プールの分離 | ポート契約 | `dep:sqlx#Transaction` |
| パスワード | ハッシュクレートの出力形式 | ポート（不透明な値） | `dep:argon2#PasswordHash` |

## 依存の版

`Cargo.lock` から、採用したクレートの版を `trace/target.json`（移植元として使う場合は `trace/upstream.json`）に記録する。Rust ツールチェーン・Verus・Kani の版も記録する。

## 版上げで起こりがちな変化

- Verus の版上げに伴う、要求 Rust 版の変化と `vstd` の API の変化。
- serde の既定の振る舞いの変化。
- Lean の版上げ（Merkle ハッシュの一括変化）にともなう、`model/` の一括再確認。
