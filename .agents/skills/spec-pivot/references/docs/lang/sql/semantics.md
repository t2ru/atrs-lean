---
type: Reference
title: "SQL: LangSemantics.Sql"
description: "DBMS に依存しない SQL の意味論 LangSemantics.Sql と、方言の分け方。"
tags: [sql, language-pack, lean]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# SQL: LangSemantics.Sql

SQL の意味論を Lean に定義する。DBMS に依存しない **共通部分** を `LangSemantics.Sql` に、DBMS 固有の部分を **方言** `LangSemantics.Sql.<Dbms>` に置く。
アプリ固有のテーブル定義は含めない（テーブル定義はモデル側の `Repository.Schema` で扱う）。
移植元のリポジトリ（Mapper の文。例 `SourceModel.Domain.Repository.Route.RouteRepository`）を写すときも、移植先が SQL を使う場合（`TargetModel.Repository.*`）も、同じ定義を使う。

Lean の実装は `assets/lean/LangSemantics/Sql/`（モジュール `LangSemantics.Sql`）。検査は `assets/lean/Test/LangSemantics/Sql.lean`。

## 共通部分（LangSemantics.Sql）

| 対象 | 意味 |
| --- | --- |
| 値 | `NULL`、整数型、`NUMERIC`、文字列型、`DATE`、`TIMESTAMP`、`BOOLEAN`。各型の値域・精度は方言が与える |
| 述語 | 比較・`AND`/`OR`/`NOT` の三値論理（`UNKNOWN`）。`BETWEEN a AND b` ≡ `x >= a AND x <= b`。`IN (…)`、`EXISTS`、`IS NULL` |
| 照会 | 内部結合・外部結合・選択・射影・`DISTINCT`・集約を **バッグ（多重集合）** として定義する |
| 整列 | `ORDER BY k1, k2 …`: キーが等しい行の相対順序は **未規定**。結果は「許される順列の集合」として表す。`ORDER BY` が無い照会の順序も未規定。文字列の比較は照合順序（方言のパラメータ）に従う |
| 更新 | `UPDATE … SET c1 = e1, c2 = e2`: 右辺は更新前の行で評価する。`INSERT`・`UPDATE`・`DELETE` は件数を返す |
| 制約 | 主キー・一意・外部キー・NOT NULL の違反はエラー値になる |
| トランザクション | コミット／ロールバックの原子性。分離レベルの既定値と、行ロックの構文・意味は方言が与える。ロールバックはシーケンスを戻さない。モデルは逐次の実行だけを写し、行ロック（`SELECT … FOR UPDATE`）と分離レベルは、逐次の実行では観測されないので写さない |

### Lean 実装の範囲

実装済み: `SqlValue`（NULL・整数・文字列・真偽・日付）、`Truth`（三値論理）、比較・`between`・`inList`・`isNull`、`Bag`（選択・射影・直積・内部結合・`EXISTS`・`COUNT(*)`）、`isAllowedOrder`・`orderByStable`（並びのキーは、向きとキーの組の列 `OrderBy`）、`updateWhere`・`deleteWhere`・`insertUnique`、`nextval`、取消 `Transaction.run`（`EStateM` の計算。例外で終わったら、状態を `restore 開始時 終了時` にする。表は開始時、シーケンスは終了時のように、戻す成分は呼び出し側が決める）。方言 PostgreSQL の `TIMESTAMP` の列の型 `PgTimestamp`。

**未整備**: `NUMERIC`、`TIMESTAMP` の演算と格納、外部結合、`DISTINCT`、`COUNT(*)` 以外の集約、外部キー・NOT NULL の検査関数。

## 方言（LangSemantics.Sql.<Dbms>）

次の項目は DBMS ごとに異なるため、方言パック `references/docs/lang/sql/dialects/<dbms>/` に定義する。

| 項目 | 例 |
| --- | --- |
| 型の値域・精度・暗黙の型変換 | `INT` の幅、`DATE` → `TIMESTAMP` の変換。列の型は、処理系が許す値の範囲を持つ型で写す（物理的なビット幅でなく、範囲の制限という意味を再現する。PostgreSQL では `Int4`・`PgDate`・`Varchar n`）。モデルの表の行はこの型で持ち、抽象側の型との違いは、リファインメントの前提型の差異（表せない値）として扱う |
| 採番 | シーケンス（`NEXTVAL`, `CYCLE`）、自動採番列 |
| 書式・文字列関数 | `TO_CHAR`、`LPAD`、連結演算子 |
| 行ロック | `SELECT … FOR UPDATE` の有無と意味 |
| 分離レベルの既定値 | READ COMMITTED など |
| 照合順序の既定値 | `C`、ICU、OS 依存 |
| 識別子の大文字小文字 | 引用符の無い識別子の正規化 |

用意されている方言:

| DBMS | 方言パック | Lean |
| --- | --- | --- |
| PostgreSQL | [dialects/postgresql/semantics.md](dialects/postgresql/semantics.md), [engine.md](dialects/postgresql/engine.md), [harness.md](dialects/postgresql/harness.md) | `LangSemantics.Sql.Postgresql` |

方言を追加する手順は [adding-a-language.md](../../guide/adding-a-language.md#方言サブパック) にある。

## 抽象化（α）での写し方

- 照会結果（許される順列の集合）は、順列ごとに `Spec` の列へ写す関係とする。リファインメントの正しさの義務は、許されるすべての順列について示す。整列キーが単射なら順列は 1 つになり、義務は簡単になる。順列によって観測が変わる場合は、観測型の差異として明示する。
- `NULL` は `Option` の `none` に写す。三値論理の `UNKNOWN` は、`WHERE` では偽として扱う。
- 列の値（`INT`・`DATE`・`VARCHAR` など）の葉は、方言の型の範囲で写し、`Spec` の型で表せない値（負の数・範囲外の日付・未知のコード・`NULL` の必須列）には定義しない。核は、定義域の上で単射なら `Machine.Kernel.undefOrEq` で示す。表せない値を具体側の入力から除くのは、前提型の差異（具体側の入力）である。
- 照会結果の写しの核は「なし（各順列を単射に写す）」とする。

| SQL の値 | `Spec` | 同一視するもの（核） |
| --- | --- | --- |
| 照会結果（バッグ・許される順列の集合） | 列（順列ごとに写す関係） | なし（各順列を単射に写す） |
| 列の値（方言の型） | 対応する `Spec` の値（表せない値には定義しない） | 定義域の上で単射なら `Machine.Kernel.undefOrEq` |
| `NULL` | `Option.none` | なし |

基本補題は assets の `LangSemantics.Sql.QueryLemmas`（結合 `filter_cross`、許される順列と `List.mergeSort` の一致 `allowed_map_eq_mergeSort`・`allowed_mergeSort_self`、条件の押し下げ `cross_filter_left`・`select_filter_of_imp`）にある。条件の押し下げは、大きな表の直積を、1 つの表だけで決まる条件で先に絞って評価するときに使う（評価の等しさは定理で示す）。

## 基本補題（用意するもの）

- `ORDER BY` のキーが単射なら、許される順列はちょうど 1 つ。
- バッグの選択・射影の結合法則。順列とバッグの基本補題は Mathlib を使わずに用意する。
- 比較対象が固定長の数字列などであれば、照合順序に依らず辞書順と一致する。
