# SQL: ロケータとインベントリ

移植元・移植先のどちらでも、どの DBMS でも同じ文法を使う。DBMS の仕様の節は `lang:<dbms>#<節>`（例 `lang:postgresql#sql-createsequence`）で指す。

## ロケータ

| kind | body | 例 |
| --- | --- | --- |
| `sql` | `<Mapper の namespace またはファイル名>#<文の id または名前>` | `sql:com.example.repository.OrderRepository#findOpen`, `sql:queries/order.sql#find_open` |
| `ddl` | `<ファイル名>#<オブジェクト名>`（テーブル・シーケンス・索引・制約） | `ddl:001_create_tables.sql#SQ_ORDER_1` |
| `seed` | `<ファイル名>#<テーブル名>`（初期データ。テーブル単位で、関数や `DO` ブロックの中の `INSERT` も含める） | `seed:010_insert_master.sql#PRODUCT` |

## インベントリ

- MyBatis の Mapper XML: `<select|insert|update|delete id="…">` ごとに 1 項目。`<selectKey>`・`<foreach>` などの動的要素も本文に含める。
- 素の SQL ファイル: 文ごと（または名前付きクエリごと）に 1 項目。
- DDL: `CREATE …` の文ごとに 1 項目。
- 本文ハッシュの正規化: SQL のコメントを除き、空白を 1 つにまとめ、キーワードを大文字にそろえる。識別子とリテラルはそのまま残す。
