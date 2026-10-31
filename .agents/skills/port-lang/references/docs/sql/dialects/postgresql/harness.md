---
type: Reference
title: "SQL 方言 PostgreSQL: ベクタの実行環境"
description: "PostgreSQL で SQL の適合テストベクタを実行する環境の設定。"
tags: [sql, postgresql, language-pack, conformance]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# SQL 方言 PostgreSQL: ベクタの実行環境

[sql/harness.md](../../harness.md) の共通事項を、PostgreSQL で満たすための設定。

- サーバ: 版の宣言に記録した版のコンテナイメージ（例 `postgres:16.4`）を使う。版はタグで固定し、`latest` を使わない。
- 照合順序: `initdb --locale=C --encoding=UTF8`（またはデータベース作成時に `LC_COLLATE='C'`）で、OS に依存しない順序にする。移植元がそれ以外の照合順序を前提とする場合は、その照合順序をそのまま再現し、版の宣言に記録する。
- タイムゾーン: `TimeZone=UTC`。
- シーケンス: ベクタの `world` の値で `setval` してから実行する。
- 各ケースは独立したトランザクションで実行し、終了時にロールバックする（状態を変える操作は、`worldAfter` の比較を済ませてからロールバックする）。

## 方言の突き合わせ表

`assets/lean/Test/LangSemantics/pg/pg_table.py` は、固定の入力を PostgreSQL で評価し、`LangSemantics.Sql`・`LangSemantics.Sql.Postgresql` と照合する `#guard` を生成する（生成物 `Test/LangSemantics/PostgresqlDb.lean`）。

- データを伴う照会は、同じデータを処理系と Lean の両方で評価する。順序が未規定なら、処理系の結果が `isAllowedOrder` を満たすことを照合する。
- 移植元の文ごとの差分実行も、同じ形で作る。原典の SQL を処理系で実行した結果と、写した式（`SourceModel.Repository.*`）を同じデータで評価した結果を照合する `#guard`（またはテスト）を生成する。
- `--expect-version` で版を確かめ、データベースが照合順序 `C`・`UTF8` でなければ止まる。出力に版は含めない。生成物をコミットし、CI で再生成して差分が無いことを確かめる。
