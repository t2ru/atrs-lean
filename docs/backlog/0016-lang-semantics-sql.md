---
type: Backlog Item
title: "LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論"
description: "値と NULL、三値論理、バッグ照会、非決定的 ORDER BY、シーケンス、TO_CHAR、UPDATE の評価規則を実装する。"
tags: [backlog, lang-semantics, sql]
id: "0016"
state: todo
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論

> 2026-10-29: スキル port-lang の assets に、LangSemantics.Sql と LangSemantics.Sql.Postgresql の初版（core のみ、`#guard` 検査付き、Lean 4.35.0 でビルド済み）がある（[Sql.lean](../../.agents/skills/port-lang/assets/lean/LangSemantics/Sql.lean)）。本項目は、それを `lean/LangSemantics/` に取り込み、ATRS で不足する演算を **assets 側に** 追加する作業として行う。

## 目的

原典の SQL に含まれる業務ロジックを [Source] で忠実に写すため。

## 範囲

- `LangSemantics.Sql.Value`, `.Pred`（三値論理, BETWEEN, IN, EXISTS）, `.Query`（結合・選択・射影のバッグ意味論）, `.OrderBy`（許される順列の集合）, `.Sequence`, `.ToChar`, `.Update`
- 順列・バッグの基本補題

## 対象外

- SQL のパーサ
- ATRS 固有のテーブル定義（`SourceModel.Repository.Schema` で扱う）

## 完了条件

- [ ] `ORDER BY` のキーが単射なら許される順列が 1 つであることを証明した
- [ ] SQL の差分実行の仕組み: 同じデータとパラメータについて、PostgreSQL（`trace/upstream.json` の版）の実行結果と `LangSemantics.Sql` の評価結果を照合する。順序が未規定なら、許される集合に含まれることを照合する
- [ ] `LangSemantics.Sql.Postgresql` の演算（`TO_CHAR`・型変換・既定の整列）を PostgreSQL と突き合わせ、範囲を [assurance.md](../spec/assurance.md) に記載した
- [ ] ATRS 固有モジュールを import していない

## 参照

- [ADR 0019](../decision/0019-sql-semantics-for-source-repositories.md)
