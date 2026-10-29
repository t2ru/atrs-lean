# SQL: 処理系・マッパの効果

## 処理系（DBMS）の効果

分離レベル・採番・暗黙の型変換・照合順序・既定の並びなど、処理系が与える効果は DBMS ごとに異なる。方言パックの `engine.md` に従う。

| DBMS | 方言パック |
| --- | --- |
| PostgreSQL | [dialects/postgresql/engine.md](dialects/postgresql/engine.md) |

どの DBMS でも、次の点はモデルに写すか、規範の仕様文書に書く。

- 分離レベルの既定値と、行ロックの意味（ポート契約の直列化可能性）。
- 採番がロールバックで巻き戻るか。循環するか。
- `ORDER BY` が無い照会・同順位の並びは未規定であること。
- 文字列比較の照合順序。

## マッパの効果（呼び出し側の言語パックと共同で扱う）

- MyBatis: `#{}` は束縛変数、`${}` は文字列展開。`<selectKey order="BEFORE">` は挿入前に採番する。結果の対応づけ（`resultMap`）で、列が null の関連オブジェクトの生成有無が変わる。
- JPA・他の ORM を使う場合は、生成される SQL を確定させてから SQL パックで写す。

## 依存の版

- DBMS の版と照合順序の設定（方言パックの `engine.md` の「版の記録」）、ドライバ・マッパの版を、`trace/upstream.json`（移植元）または `trace/target.json`（移植先）に記録する。
