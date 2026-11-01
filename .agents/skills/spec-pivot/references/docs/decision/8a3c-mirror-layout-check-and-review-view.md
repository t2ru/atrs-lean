---
type: Architecture Decision Record
title: "移植元のモデルを原典のソースツリーの形に並べ、対応を TR-M で検査し、対照表を trace review で生成する"
description: "移植元のモデルのモジュールを原典のクラスと 1 対 1 にする規則を言語パックに置き、プロジェクトの設定 source.mirror で有効にする。配置・名前・引数・欄の対応を trace check の TR-M で検査し、原典とモデルを並べた静的な HTML を trace review で生成する。trace-dump は宣言の引数・欄・行の範囲を出力する。"
tags: [adr, traceability, tooling, review, java]
id: "8a3cd5dd-9fdc-4ded-a00c-809f1742b511"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T18:00:00+09:00
---

# 移植元のモデルを原典のソースツリーの形に並べ、対応を TR-M で検査し、対照表を trace review で生成する

## Context and Problem Statement

両端の一致は決定論的な手段で確かめる。それでも、人がモデルと原典を見比べる場面は残る（手段の届かない部分の検討、レビュー、版上げの差分）。
これまでの言語パックは「`SourceModel` はパッケージ構成を写す必要は無い」としていた。そのため、1 つのクラスが複数のモジュールに分かれ、
1 つのモジュールに複数のクラスが混ざっていた。`@[source]` とインベントリは原典の行の範囲を持つが、両者を並べて見る道具が無かった。

## Decision Drivers

* 見比べやすさを、人の注意ではなく決定論的な検査で保つ
* 配置の規則はアプリに依存しない（接頭辞・根・写し方はプロジェクトの設定）
* 既存の検査（TR-S・TR-L・layout-check）と矛盾しない
* 生成物はリポジトリに置かない（差分を増やさない）

## Considered Options

* 原典のクラスと 1 対 1 のモジュールにする規則と、その検査（TR-M）・対照表（`trace review`）を置く
* 対照表だけを置き、配置は自由にする
* 原典のファイルに対応するモデルのファイルを、コメントで手書きする

## Decision Outcome

Chosen option: "原典のクラスと 1 対 1 のモジュールにする規則と、その検査（TR-M）・対照表（`trace review`）を置く", because 原典のファイルを開けば同じパスに写しがあり、
規則が機械的なので検査できるからである。対照表だけでは、1 つのクラスの写しが散らばることを防げない。

* 規則（[lang/java/layout.md](../lang/java/layout.md#移植元として原典を読む)）: 原典のクラス `<prefix>.<pkg>.<Class>` を、モジュール `<層>.<Pkg>.<Class>` に写す
  （`case = upper-camel` なら、パッケージの各成分の先頭を大文字に）。型はモジュールと同じ名前、メソッドは `<Class>.<method>`、定数は原典の綴り、
  コンストラクタは `<Class>.new`。Mapper の文は同じパッケージのリポジトリのモジュールに置く。原典のクラスに当たらないもの（具体機械・DB の状態・
  フレームワークの値・設定）は、根（`roots`）の外に置く。
* 設定: `trace/project.json` の `source.mirror`（`lean_root`・`package_prefix`・`roots`・`case`・`shared`）。無ければ TR-M を行わない。
  `shared` は、どの定義から引いてもよい横断的な設定のクラス（MyBatis の設定など）で、配置の根拠にしない。
* 検査 TR-M（`scripts/trace/src/mirror.rs`）:
  * TR-M1: `java:`・`sql:` のロケータを持つ定義が、そのクラスのモジュールにない。根の外の定義がそれらを持つ。機能の移植元側で段階導入。
  * TR-M2: mirror のモジュールの直下の宣言の名前が、自分のロケータのメンバーの名前とも、クラスのソース（Java・Mapper の XML）の識別子とも合わない。警告（人が確かめる）。
  * TR-M3: メソッドの写しの引数の名前に、Java の引数の名前が順に現れない（可変長引数は省いてよい）。機能の移植元側で段階導入。
  * TR-M4: クラスの型の欄が、Java のクラスの欄に無い。警告（環境から受ける値など、モデルが足す欄がありうる）。
  * 名前は大文字小文字と `_`・`-` を区別せずに比べる。Java の欄・引数は tree-sitter で取る（インベントリには入れない。ハッシュは変わらない）。
* `trace-dump`: 各定義に `params`（明示的な引数の名前）・`fields`（構造体の欄）・`range`（宣言の行の範囲）を足す。`merkle` には含めない。
* `trace review --dump … [--out <dir>]`（`scripts/trace/src/review.rs`）: 原典のクラスごとのページに、原典のメンバーと、それを `@[source]` で指す定義を並べ、
  検査済みハッシュ・ギャップの印・覆われていないメンバーを示す。既定の出力は `build/review/`。JavaScript を使わない静的な HTML で、出力は決定論的である。
  CI は artifact として上げ、リポジトリには置かない。

### Consequences

* Good, because 配置の誤り（クラスの写しが別のモジュールにある）が CI で見つかる
* Good, because 引数・欄の名前の食い違い（例: 原典の `fareTypeMap` をモデルが `fareTypeCodeMap` と書く）が見つかる
* Bad, because ファイルが増え、名前が長くなる
* Bad, because TR-M2・TR-M4 は警告にとどまる（モデルだけの補助の定義や欄は、規則で禁じられない）

### Confirmation

`cargo test --release`（`scripts/trace`）が TR-M の違反例と対照表の補助関数を確かめること。適用先で `trace check` が TR-M1・TR-M3 を失敗扱いで通ること。

## More Information

* 式の構文と語彙: [ADR 1f75](1f75-java-expression-syntax-and-spring-assert.md)
* 宣言をモジュール名の下に置く規則（NS-1）: [ADR 1a30](1a30-lean-module-namespace-layout.md)。mirror のモジュールでも NS-1 は変わらない
* 適用先 ATRS の ADR e41c
