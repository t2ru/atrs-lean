---
type: Architecture Decision Record
title: "追跡の道具の未確定事項（本文ハッシュ・正規化・ロケータの細部・機能と backlog の対応）を決める"
description: "ADR 0036 と言語パックで未確定だった、本文ハッシュの方式、正規化での空白の扱い、private の呼び先の連結、ロケータとハッシュの区切り、seed:・tmpl:・xml:・http:・prop:/msg: の形、dep:/lang: の版の文字列、警告と誤りを決める機能と backlog の対応表（trace/features.json）、合格の記録が無い場合、TR-P の数え方を決める。"
tags: [adr, traceability, tooling]
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T22:21:07+09:00
---

# 追跡の道具の未確定事項（本文ハッシュ・正規化・ロケータの細部・機能と backlog の対応）を決める

## Context and Problem Statement

追跡の道具 `tools/trace`（[backlog 0024](../backlog/0024-trace-tooling.md)）を作るにあたり、次の文書を照らし合わせた。

* [ADR 0036](0036-traceability-hash-as-deterministic-check-record.md)（検査済みハッシュと TR 検査）
* [ADR 0039](0039-refinement-non-vacuity-obligations.md)（TR-G・TR-N・TR-PE）
* スキル port-lang の `references/traceability.md` と、言語パックの `locators.md`

その結果、実装に必要な次の点が未確定か、文書の間で食い違っていた。

* 本文ハッシュの方式と長さ
* 正規化で空白を「除く」（ADR 0036）か、「1 つにまとめる」（言語パック）か
* private の呼び先を連結する順序と推移性
* `@[source "<ロケータ>@<ハッシュ>"]` の区切り。`tmpl:` や `java@source:` のように、ロケータ自身が `@` を含むことがある
* `seed:` の単位。ADR 0036 は行、`sql/locators.md` はテーブルとしている
* `tmpl:`・`xml:`・`http:` の具体的な形と、`prop:`/`msg:` の区別
* `dep:`/`lang:` の版の文字列と、その版をどこで引くか
* 「backlog で完了していない機能だけ警告にしてよい」の「機能」と、インベントリの項目・Lean の定義との対応
* 合格の記録（manifest）がまだ無いときの TR-S2・TR-T2 の扱い
* TR-P の「R 課題に現れる」の数え方

## Decision Drivers

* 決定論的で、同じ入力から同じインベントリと判定が得られること
* 空白・コメント・インデントの変更では、ハッシュが変わらないこと（文字列リテラルの中身の変更では変わること）
* 対応表の抜けで、指摘が黙って消えないこと
* ADR 0036・0039 の原則（警告は未完了の機能だけ、それ以外は誤り）を保つこと

## Considered Options

* 下表のとおり決め、文書の食い違いはこの ADR で解消する
* 未確定のまま、道具の実装だけで決める

## Decision Outcome

Chosen option: "下表のとおり決め、文書の食い違いはこの ADR で解消する", because 実装の判断を文書に残し、他の言語・他の移植で同じ道具を作るときに再現できるため。

| 項目 | 決定 |
| --- | --- |
| 本文ハッシュ | 正規化した本文の SHA-256 の先頭 16 桁（小文字 16 進。Lean の Merkle ハッシュと同じ長さ） |
| 正規化 | 構文解析器のトークン列（コメントを除く）を、空白 1 つでつないだもの。空白・改行・インデントの違いは無視する（ADR 0036 の「空白とコメントを除く」と、言語パックの「空白を 1 つに」のどちらも満たす）。文字列リテラルは 1 トークンとして中身を保つ。SQL は予約語を大文字にし、識別子とリテラルは変えない。properties は値の前後の空白を除いた値。Rust は `rustfmt` を通さず、トークン列をそのまま使う（トークン列は書式の違いに影響されないため） |
| private の呼び先 | 同じクラス（Rust は同じモジュール）の private メソッド・関数の本文を、呼ぶ側の本文の後に連結する。推移的に、初出順で、重複なく連結する |
| ロケータとハッシュの区切り | `"<ロケータ>@<ハッシュ>"` は **最後の `@`** で分ける |
| `seed:` | `seed:<ファイル名>#<テーブル名>`。テーブル単位で、関数や `DO` ブロックの中の `INSERT` も含める。ADR 0036 の `seed:<file>#<row>` はこれに改める |
| `ddl:` | `CREATE TABLE|SEQUENCE|INDEX|VIEW <名前>` と、`ALTER TABLE … ADD CONSTRAINT <名前>` の名前 |
| `tmpl:` | パスは画面テンプレートの置き場所（ATRS は `WEB-INF/views/`）からの相対。単位は `th:*` 属性を持つ要素。`id` があれば `#<id>`、無ければ `#<タグ>[@<最初の th: 属性>='<値>']`。同じものが複数あれば、末尾に出現順の `[n]` を付ける。ハッシュは開始タグ（全属性）の正規化 |
| `xml:` | `web.xml` の `<web-app>` 直下の要素。`#<要素>[<識別子の子要素>=<値>]`。識別子は `param-name`・`filter-name`・`servlet-name`・`listener-class`・`error-code`・`exception-type` の順で最初にあるもの。無い場合と重複する場合は `[n]` を付ける |
| `http:` | ハンドラのメソッドの `@RequestMapping` 系の注釈と、クラスの `@RequestMapping` のパスを合成する。`params` が判別パラメータで、複数あれば `&` でつなぐ。HTTP メソッドの指定が無ければ `*`。ハッシュはハンドラのメソッドと同じ |
| `prop:` / `msg:` | `i18n/` の配下と、名前に `Messages` を含む `.properties` は `msg:`、それ以外は `prop:` |
| 対象のファイル | テストのソース（`src/test/`）は走査しない。`pom.xml` は走査しない（依存の版は `trace/upstream.json` が正で、`check_upstream.py` が検査する） |
| `dep:` / `lang:` の版 | 版の文字列は `<名前>-<版>`（例 `java-17`、`postgresql-16.15`、`spring-beans-7.0.3`）。`lang:` は `trace/upstream.json`（移植先は `trace/target.json`）の `languages`、`dep:` は `dependencies` の座標で引く。宣言の無い言語・座標は TR-R の誤り。インベントリには列挙しない |
| 機能と backlog の対応 | `trace/features.json` に、機能ごとに backlog の一覧、ロケータの glob、Lean の名前空間、R 課題の ID を書く。TR-S1・TR-T1・TR-P・TR-PE・TR-D の指摘は、その機能の backlog がすべて `done` なら誤り、そうでなければ警告とする。どの機能にも属さない対象範囲の項目、R 課題、`SourceModel`・`Abstraction`・`TargetModel`・`Refinement` の定義は誤り（TR-R）とする。差異の行は、その R 課題の機能のどれかが完了していれば誤りとする |
| 合格の記録が無い場合 | TR-S2・TR-T2 は誤りとする。`rehash` が記録するまで合格とみなさない |
| TR-P の「現れる」 | R 課題の定理から参照をたどって届く定義の集合（参照の閉包）に含まれること。TR-PE は、同じ数え方を入口の R 課題に限る |
| 公開操作 | `@[source]`（`dep:`・`lang:` 以外）を持つ `SourceModel` の定義と、`@[target]` を持つ `TargetModel` の定義 |
| 対象外 | `out-of-scope.json` の glob に当たる項目は、TR-S1 の対象から外す。それに対応を付けることは妨げない（D-019 の `tmpl:` など） |
| TR-D の無名の仮定 | `obligation-check` の G1・G2 の誤り（型が閉じていない、制限の述語が `@[deviation]` でない）を、TR-D としても報告する |
| manifest | ノード（追跡属性を持つ定義と、`SourceModel`・`Abstraction`・`TargetModel`・`Refinement` の定義）・型付きのリンク・合格した検査の記録。Merkle ハッシュは合格の記録にだけ残す（Lean の変更のたびに manifest が変わらないように） |

### Consequences

* Good, because 同じ入力から同じインベントリと判定が得られ、他の移植でも同じ道具を作れる
* Good, because 対応表の抜けが TR-R の誤りになり、警告に紛れない
* Bad, because `trace/features.json` を機能の追加・分割のたびに保守する必要がある
* Bad, because ハッシュを 16 桁に切り詰めるので、意図的な衝突には弱い（偶然の衝突は実用上起きない）

### Confirmation

* `tools/trace` の `cargo test` で、各規則の違反例を検出することを確かめる。
* CI（`tools/ci/lean.sh`）で、インベントリ・manifest・生成区画が最新であることと、`trace check` の誤りが 0 件であることを確かめる。

## More Information

* [ADR 0036](0036-traceability-hash-as-deterministic-check-record.md)、[ADR 0039](0039-refinement-non-vacuity-obligations.md)、[backlog 0024](../backlog/0024-trace-tooling.md)
* スキル port-lang の [traceability.md](../../.agents/skills/port-lang/references/traceability.md)、[java/locators.md](../../.agents/skills/port-lang/references/java/locators.md)、[sql/locators.md](../../.agents/skills/port-lang/references/sql/locators.md)
