# SQL: LangSemantics.Sql

SQL の意味論を Lean に定義する。DBMS に依存しない **共通部分** を `LangSemantics.Sql` に、DBMS 固有の部分を **方言** `LangSemantics.Sql.<Dbms>` に置く。
アプリ固有のテーブル定義は含めない（テーブル定義はモデル側の `Repository.Schema` で扱う）。
移植元のリポジトリ（`SourceModel.Repository.*`）を写すときも、移植先が SQL を使う場合（`TargetModel.Repository.*`）も、同じ定義を使う。

Lean の実装は `assets/lean/LangSemantics/Sql/`（モジュール `LangSemantics.Sql`）。検査は `assets/lean/LangSemanticsTest/Sql.lean`。

## 共通部分（LangSemantics.Sql）

| 対象 | 意味 |
| --- | --- |
| 値 | `NULL`、整数型、`NUMERIC`、文字列型、`DATE`、`TIMESTAMP`、`BOOLEAN`。各型の値域・精度は方言が与える |
| 述語 | 比較・`AND`/`OR`/`NOT` の三値論理（`UNKNOWN`）。`BETWEEN a AND b` ≡ `x >= a AND x <= b`。`IN (…)`、`EXISTS`、`IS NULL` |
| 照会 | 内部結合・外部結合・選択・射影・`DISTINCT`・集約を **バッグ（多重集合）** として定義する |
| 整列 | `ORDER BY k1, k2 …`: キーが等しい行の相対順序は **未規定**。結果は「許される順列の集合」として表す。`ORDER BY` が無い照会の順序も未規定。文字列の比較は照合順序（方言のパラメータ）に従う |
| 更新 | `UPDATE … SET c1 = e1, c2 = e2`: 右辺は更新前の行で評価する。`INSERT`・`UPDATE`・`DELETE` は件数を返す |
| 制約 | 主キー・一意・外部キー・NOT NULL の違反はエラー値になる |
| トランザクション | コミット／ロールバックの原子性。分離レベルの既定値と、行ロックの構文・意味は方言が与える |

### Lean 実装の範囲

実装済み: `SqlValue`（NULL・整数・文字列・真偽・日付）、`Truth`（三値論理）、比較・`between`・`inList`・`isNull`、`Bag`（選択・射影・直積・内部結合・`EXISTS`・`COUNT(*)`）、`isAllowedOrder`・`orderByStable`、`updateWhere`・`deleteWhere`・`insertUnique`、`nextval`。

**未整備**: `NUMERIC`・`TIMESTAMP`、外部結合、`DISTINCT`、`COUNT(*)` 以外の集約、外部キー・NOT NULL の検査関数。

## 方言（LangSemantics.Sql.<Dbms>）

次の項目は DBMS ごとに異なるため、方言パック `references/sql/dialects/<dbms>/` に定義する。

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

方言を追加する手順は [adding-a-language.md](../adding-a-language.md#方言サブパック) にある。

## 抽象化（α）での写し方

- 照会結果（許される順列の集合）は、順列ごとに `Spec` の列へ写す関係とする。リファインメントの正しさの義務は、許されるすべての順列について示す。整列キーが単射なら順列は 1 つになり、義務は簡単になる。順列によって観測が変わる場合は、観測型の差異として明示する。
- `NULL` は `Option` の `none` に写す。三値論理の `UNKNOWN` は、`WHERE` では偽として扱う。

## 基本補題（用意するもの）

- `ORDER BY` のキーが単射なら、許される順列はちょうど 1 つ。
- バッグの選択・射影の結合法則。順列とバッグの基本補題は Mathlib を使わずに用意する。
- 比較対象が固定長の数字列などであれば、照合順序に依らず辞書順と一致する。
