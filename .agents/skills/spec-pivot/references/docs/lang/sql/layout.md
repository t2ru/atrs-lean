---
type: Reference
title: "SQL: ソースの構成と Lean 名前空間の対応"
description: "SQL（Mapper・クエリファイル）の構成と、Lean の名前空間の対応。"
tags: [sql, language-pack]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# SQL: ソースの構成と Lean 名前空間の対応

## 移植元として

- Mapper（またはクエリファイル）の各文を、`SourceModel.Repository.<機能>` の 1 定義に写す。名前は文の id を lowerCamelCase にしたもの。
- 文の中にある業務ロジック（絞り込み条件・並び順・採番）は、`Spec` では純粋関数として取り出す。リポジトリのポートは「全件取得」「キー検索」などの単純な契約にする。こうすると、移植先は永続化技術を自由に選べる。
- DDL は `SourceModel.Db.Schema` に、制約（主キー・一意・外部キー）とシーケンスを写す。

## 移植先として

- 移植先が SQL を使う場合も、文ごとに `TargetModel.Repository.<機能>` の 1 定義を対応させ、`@[target "sql:…@<hash>"]` を付ける。
- SQL ファイルの中で、文の前に `-- trace: models <TargetModel の完全名> @<Merkle ハッシュ>` を書く（写しを持たない場合も、どのモデル定義に対応するかを示すため）。
