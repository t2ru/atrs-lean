---
type: Reference
title: "Rust: ロケータとインベントリ"
description: "Rust のロケータの文法とインベントリの作り方。"
tags: [rust, language-pack, traceability]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Rust: ロケータとインベントリ

移植元・移植先のどちらでも同じ文法を使う。

## ロケータ

| kind | body | 例 |
| --- | --- | --- |
| `rust` | `<crate>::<モジュールパス>::<項目名>`。メソッドは `<型>::<名前>`、トレイト実装は `<<型> as <トレイト>>::<名前>` | `rust:app::fare::basic_fare`, `rust:app::model::fare::basic_fare`, `rust:app::fare::Fare::total` |

- Rust から Rust への移植では、`rust@source:` / `rust@target:` と区別する。

## インベントリ

- パーサ: tree-sitter-rust。`verus!` マクロの中は一般的なパーサで読めないため、関数の境界と doc コメント（追跡タグ）を行単位で走査して補う。
- 単位: `pub` な関数・メソッド・型・定数。`model/` の `spec fn` も対象にする（追跡タグの検査に使う）。
- 本文ハッシュの正規化: コメント（追跡タグを除く）を除き、`rustfmt` 済みのトークン列からハッシュする。
- 非公開の関数は、それを呼ぶ公開関数の本文に連結してハッシュする。
