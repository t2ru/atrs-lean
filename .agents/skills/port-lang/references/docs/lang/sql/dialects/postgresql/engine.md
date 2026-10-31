---
type: Reference
title: "SQL 方言 PostgreSQL: 処理系の効果と版"
description: "PostgreSQL の処理系が与える効果と、版の固定。"
tags: [sql, postgresql, language-pack]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# SQL 方言 PostgreSQL: 処理系の効果と版

[sql/frameworks.md](../../frameworks.md) の共通事項に加えて、PostgreSQL の処理系が与える効果を示す。モデルに写すときは `lang:postgresql#…` ロケータを付ける。

| 分類 | 効果 | 写し方 | ロケータ |
| --- | --- | --- | --- |
| 分離レベル | 既定 READ COMMITTED。`FOR UPDATE` で行ロック | ポート契約（直列化可能性）の規範節 | `lang:postgresql#transaction-iso` |
| 採番 | シーケンスは取消で巻き戻らない。`CYCLE` で循環し、主キーが衝突しうる | 採番ポートの契約 | `lang:postgresql#sql-createsequence` |
| 暗黙の型変換 | `DATE` を `TIMESTAMP` 列に入れると 00:00 になる | 値の写し方 | `lang:postgresql#datatype-datetime` |
| 照合順序 | `ORDER BY` の文字列比較が `LC_COLLATE` に依存する | 照合順序のパラメータ | `lang:postgresql#collation` |
| 既定の並び | `ORDER BY` が無い照会の順序は未規定（実行計画で変わる） | 許される順列の集合 | `lang:postgresql#queries-order` |

## 版の記録

- サーバの版（例 `16.4`）、`LC_COLLATE`・`LC_CTYPE`、ICU を使う場合はその版、JDBC ドライバ（または Rust のドライバ）の版を、版の宣言に記録する。

## 版上げで起こりがちな変化

- OS の glibc・ICU の版上げに伴う照合順序の変化（索引の再構築が必要になり、`ORDER BY` の結果も変わりうる）。
- 書式関数・型変換の細部の変化。
- メジャー版上げでの、既定設定（例: `standard_conforming_strings`）の変化。
