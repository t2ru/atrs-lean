---
type: Backlog Item
title: "LangSemantics.Rust: Rust の意味論"
description: "固定長整数（検査付き・折り返し）、char、UTF-8 String、Vec、Result、パニックを、アプリ非依存の検証可能なモデルとして Lean に定義する。"
tags: [backlog, lean, lang-semantics, rust]
id: "0021"
state: todo
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# LangSemantics.Rust: Rust の意味論

## 目的

`TargetModel` が Rust ソースの振る舞いを正確に写せるようにする。

## 範囲

- `LangSemantics.Rust.Int`（`u8`〜`u64`, `i8`〜`i64`。`checked_*`・`wrapping_*`・既定の演算でのデバッグ時パニック／リリース時折り返しの区別）
- `LangSemantics.Rust.Char`（Unicode スカラ値）、`RString`（UTF-8、`len` はバイト数、`chars().count()` はスカラ値数）
- `Vec`、`Option`、`Result`、`Panic`（値として表す）
- 参照する The Rust Reference の節を docstring と `lang:rust#…` ロケータに書く

## 対象外

- ATRS 固有の型・関数
- 所有権・借用・並行性の意味論（`TargetModel` は値の意味論で写す）

## 完了条件

- [ ] `u64` の加算のオーバーフロー時の振る舞い（検査付き・折り返し）を定理で示した
- [ ] `RString` の `len` と `chars().count()` の違いを例で確認した
- [ ] ATRS 固有モジュールを import していない

## 参照

- [ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)
- [port-lang/lean/rules.md](../../.agents/skills/port-lang/references/lean/rules.md)
