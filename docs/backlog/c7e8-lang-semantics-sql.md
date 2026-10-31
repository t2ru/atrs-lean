---
type: Backlog Item
title: "LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論"
description: "値と NULL、三値論理、バッグ照会、非決定的 ORDER BY、シーケンス、TO_CHAR、UPDATE の評価規則を実装する。"
tags: [backlog, lang-semantics, sql]
id: "c7e8d83d-8d90-44fe-a6f5-de54b2efe811"
state: done
depends_on: ["be4969d4-478c-47a9-8fd9-b8cf31202bc8"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T21:44:53+09:00
---

# LangSemantics.Sql: SQL（PostgreSQL 部分集合）の意味論

> 2026-10-29: スキル port-lang の assets に、LangSemantics.Sql と LangSemantics.Sql.Postgresql の初版（core のみ、`#guard` 検査付き、Lean 4.35.0 でビルド済み）がある（[Sql.lean](../../.agents/skills/port-lang/assets/lean/LangSemantics/Sql.lean)）。`lean/` はそれを Lake の依存として取り込む（`lean/LangSemantics/` には写さない）。本項目は、ATRS で不足する演算と検査を **assets 側に** 追加する作業として行う。

## 目的

原典の SQL に含まれる業務ロジックを [Source] で忠実に写すため。

## 範囲

- `LangSemantics.Sql.Value`, `.Pred`（三値論理, BETWEEN, IN, EXISTS）, `.Query`（結合・選択・射影のバッグ意味論）, `.OrderBy`（許される順列の集合）, `.Sequence`, `.ToChar`, `.Update`
- 順列・バッグの基本補題

## 対象外

- SQL のパーサ
- ATRS 固有のテーブル定義（`SourceModel.Repository.Schema` で扱う）

## 完了条件

- [x] `ORDER BY` のキーが単射なら許される順列が 1 つであることを証明した
- [x] SQL の差分実行の仕組み: 同じデータとパラメータについて、PostgreSQL（`trace/upstream.json` の版）の実行結果と `LangSemantics.Sql` の評価結果を照合する。順序が未規定なら、許される集合に含まれることを照合する
- [x] `LangSemantics.Sql.Postgresql` の演算（`TO_CHAR`・型変換・既定の整列）を PostgreSQL と突き合わせ、範囲を [assurance.md](../spec/assurance.md) に記載した
- [x] ATRS 固有モジュールを import していない

## 結果

- assets（`.agents/skills/port-lang/assets/lean/`）
  - `LangSemantics/Sql/Query.lean`
    - `Bag.bagEq` を両方向の個数の比較に改め、順列（`List.Perm`）と同値であることを示した（`bagEq_iff_perm`）
    - 許される順列の一意性を証明した。比較が行の上で反対称・推移的で、比較が等しい行は同じ行（キーが単射）なら、許される順列はただ 1 つ（`isAllowedOrder_unique`）
    - 非 NULL の整数 1 列のキーでの系も示した（`isAllowedOrder_unique_int`）
  - `LangSemantics/Sql/Postgresql.lean`: 突き合わせで見つかった `VARCHAR(n)` の不一致を直した。超過分がすべて空白なら、エラーにせず切り詰める。
  - `LangSemanticsTest/pg/pg_table.py`
    - PostgreSQL で固定の入力表を計算し、`#guard` を生成する（生成物 `LangSemanticsTest/PostgresqlDb.lean`、373 件）
    - データを伴う照会（`ORDER BY`・`UPDATE`）は、同じデータを処理系と `LangSemantics.Sql` の両方で評価して照合する。順序が未規定なら、処理系の結果が `isAllowedOrder` を満たすことを照合する
    - これが SQL の差分実行の仕組みである。ATRS の文（`SourceModel.Repository`）の照合は、この形で運賃計算（[backlog 25f7](25f7-fare-calculation-both-models.md)）以降の項目で作る
- 版: PostgreSQL 16.15 を `trace/upstream.json` に記録した。
- CI
  - `.github/workflows/lean.yml` にサービスコンテナ `postgres:16.15` を追加した（照合順序 C・UTF8・UTC）
  - `tools/ci/lean.sh` が表を再生成し、差分が無いことを確かめる
  - ローカルでは `tools/ci/with_postgres.sh` が一時クラスタを起動する
- 突き合わせた範囲は [assurance.md](../spec/assurance.md) に書いた。型の異なる値の比較（暗黙の型変換）と日付の演算は、使う文が出てきた項目で足す。

## 参照

- [ADR 5fcb](../decision/5fcb-sql-semantics-for-source-repositories.md)
