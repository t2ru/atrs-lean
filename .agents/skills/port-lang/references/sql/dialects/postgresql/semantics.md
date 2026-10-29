# SQL 方言 PostgreSQL: LangSemantics.Sql.Postgresql

[共通部分](../../semantics.md) に加えて、PostgreSQL 固有の意味を定義する。対象の版は、プロジェクトの版の宣言（`trace/upstream.json` または `trace/target.json`）に記録した版とする。
Lean の実装は `assets/LangSemantics/Sql/Postgresql.lean`（モジュール `LangSemantics.Sql.Postgresql`）。現在は整数型・`VARCHAR`・`TO_CHAR`（`FM` と `0`/`9` の書式）・既定の整列・既定のシーケンスを実装している。

| 対象 | 意味 |
| --- | --- |
| 整数型 | `SMALLINT` 16 ビット、`INTEGER` 32 ビット、`BIGINT` 64 ビット。溢れはエラー（折り返さない） |
| `NUMERIC` | 任意精度の十進数。丸めは四捨五入（偶数丸めではない） |
| 文字列型 | `VARCHAR(n)` は n 文字（バイトではなく文字数）を超えるとエラー。末尾空白は切り詰めない（`CHAR(n)` は空白を詰める） |
| 日付・時刻 | `DATE` を `TIMESTAMP` に変換すると時刻は 00:00:00。`TIMESTAMP`（タイムゾーン無し）は時刻をそのまま保持する |
| シーケンス | `NEXTVAL`: `MINVALUE`〜`MAXVALUE` の状態付きカウンタ。`CYCLE` なら最大値の次は最小値に戻る。ロールバックしても巻き戻らない。`CURRVAL` は同じセッションで最後に得た値 |
| `TO_CHAR(n, fmt)` | 使用する書式だけを定義する。例: `'FM0999999999'` は 10 桁ゼロ埋め十進で、先頭の空白（符号の位置）を出さない |
| 行ロック | `SELECT … FOR UPDATE`: 選んだ行をトランザクション終了まで排他する。他のトランザクションの同じ行への更新・`FOR UPDATE` は待たされる |
| 分離レベル | 既定は READ COMMITTED。文ごとに、その時点でコミット済みのデータを見る |
| 照合順序 | データベース作成時の `LC_COLLATE` に依存する。`C` なら Unicode スカラ値の辞書順（UTF-8 のバイト順） |
| 識別子 | 引用符の無い識別子は小文字に正規化される |
| `EXISTS` | `SELECT EXISTS (…)` は真偽値を 1 行返す |

参照する節は `lang:postgresql#<節>` ロケータで書く（例 `lang:postgresql#sql-createsequence`, `lang:postgresql#functions-formatting`, `lang:postgresql#transaction-iso`）。
