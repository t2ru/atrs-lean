---
type: Architecture Decision Record
title: "OKF のバンドルの管理と記録の管理を、別のスキル okf-bundle・work-records に分ける"
description: "移植に関係の無い文書の道具（okf_check.py・docmv.py・ids.py）と規則を、スキル spec-pivot から汎用のスキル okf-bundle（OKF のバンドル）と work-records（ADR・作業項目）に分け、設定を trace/project.json から専用のファイル .okf.json・.work-records.json に移し、移植に固有の検査を一般化する。"
tags: [adr, skill, okf, records, tooling]
id: "22b41e82-4967-4762-b166-4cd22b7e448d"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: 適用先 ATRS のオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T20:30:00+09:00
---

# OKF のバンドルの管理と記録の管理を、別のスキル okf-bundle・work-records に分ける

## Context and Problem Statement

このスキルの `scripts/docs/` には、OKF v0.2 のバンドルとリンクの検査（`okf_check.py`。ADR 330e）、文書の移動（`docmv.py`。ADR 748c）、意思決定記録・作業項目の ID の道具（`ids.py`）があり、その規則は [rules/maintenance.md](../rules/maintenance.md) にあった。
どれも言語間の移植とは関係が無く、移植をしないリポジトリでも使える。しかし、設定は追跡の設定 `trace/project.json` の `okf`・`ids` にあり、`ids.py` には移植に固有の検査（機能と作業項目の対応表 `trace/features.json`、登録簿の表の旧番号、旧番号からの書き換え）が入っていた。
そのため、文書の管理だけを使いたいリポジトリも、追跡の設定の形と spec-pivot に依存する。spec-pivot の説明・規則も、移植の方法と文書の管理が混ざって読みにくい。

## Decision Drivers

* 移植の方法（spec-pivot）と、どのリポジトリでも使える文書の管理を分け、それぞれを単独で持ち出せること
* 道具の設定が、追跡の設定（`trace/`）の形に依存しないこと
* 既存の検査（件数と違反の検出）を、分けた後も同じに保つこと
* 記録の来歴（`depends_on`・リンク）が、持ち出すバンドルの境界を破らないこと

## Considered Options

* 2 つのスキルに分ける: okf-bundle（OKF のバンドルの形・索引・変更履歴・リンク、文書の移動）と work-records（ADR・作業項目の形式・ID・参照・状態）
* 1 つのスキル（OKF と記録をまとめたもの）に分ける
* spec-pivot に残し、文書の中で節を分けるだけにする

## Decision Outcome

Chosen option: "2 つのスキルに分ける", because OKF のバンドルは記録を持たない文書の集まりにも使え、記録は OKF の外（素の Markdown のディレクトリ）でも使えるので、関心ごとに独立して持ち出せるからである。

* **okf-bundle**: `scripts/okf_check.py`・`scripts/docmv.py`・`scripts/fixtures/`（元の `scripts/ci/fixtures/okf/`）、規則 `references/docs/rules/bundle.md`。設定はリポジトリのルートの `.okf.json`（元の `trace/project.json` の `okf`。形は同じ）。プロファイルの `kind: adr|backlog` の特別の検査（A1・B1）は、work-records に移す。
* **work-records**: `scripts/ids.py`、規則 `references/docs/rules/records.md`、雛形 `assets/templates/`。設定はリポジトリのルートの `.work-records.json`（元の `trace/project.json` の `ids`）。
  * 機能と作業項目の対応表の検査（`features`）は、ID を書く JSON の欄の宣言 `id_fields: [{file, keys, kind}]` に一般化する。
  * 登録簿の旧番号の検査（`registers`）と、旧番号からの書き換え（`migrate`。`legacy`・`backlog_index`）は、旧番号の移行にだけ使う適用先の事情なので、汎用の道具から除き、適用先の道具に移す。
  * 記録の形の検査（A1・B1）を `ids.py check` に移し、`--self-test` と違反例を足す。`outcome_markers` は設定のキーにする。
* このスキル（spec-pivot）は、文書のバンドルの構成（`type` の割り当て）と、方法の文書の置き場所だけを [rules/maintenance.md](../rules/maintenance.md) に残す。バンドルの規則のファイルは `scripts/docs/profiles/spec-pivot.json` から `references/okf-profile.json` に移す（`scripts/docs/` は無くなる）。保守には両スキルを使う（`SKILL.md` の `compatibility`）。
* 3 つのスキルは互いにリンクしない。参照は名前を文字で書く。
* 既存の記録は移さない。ADR 330e・748c・87b9・8cb7、作業項目 de90・a49c・97a7 は、道具がこのスキルにあったときの来歴であり、`depends_on` の連鎖（97a7 → a49c → de90）を分けるとバンドルの境界を破るためである。新しいスキルの索引・変更履歴から、来歴として文字で指す。

### Consequences

* Good, because 文書の管理だけを、移植をしないリポジトリでも、追跡の設定なしに使える。
* Good, because spec-pivot の規則と道具の一覧が、移植の方法に絞られる。
* Bad, because 適用先は 3 つのスキルと 2 つの設定ファイルを持つ。
* Bad, because 記録の形の検査が、okf_check（節の有無・順序・必須キー）と ids.py（状態・選択肢・採択の行）に分かれる。

### Confirmation

* `okf_check.py --self-test`・`docmv.py --self-test`・`ids.py --self-test` が通る。`ids.py --self-test` は、A1・B1 と ID・参照・持ち出すバンドルの違反例を検出する。
* 分けた後の `ids.py check` と `okf_check.py` が、適用先で分ける前と同じ件数（ADR・作業項目の数）で通る。

## Pros and Cons of the Options

### 1 つのスキルに分ける

* Good, because 設定と文書が 1 か所に集まる。
* Bad, because 記録を使わない OKF のバンドル、OKF を使わない記録のどちらにも、使わない部分が付いてくる。

### spec-pivot に残す

* Good, because 変更が最も少ない。
* Bad, because 文書の管理だけを使うリポジトリが、移植の方法と追跡の設定に依存し続ける。

## More Information

* 道具の元の決定: [ADR 330e](330e-okf-bundle-check-tool.md)（検査とプロファイル）、[ADR 748c](748c-skill-docs-category-directories.md)（docmv.py）、[ADR 87b9](87b9-skill-docs-as-okf-bundle.md)（スキルの記録をスキルで持つ）、[ADR 8cb7](8cb7-run-python-tools-with-uv.md)（uv で実行する。新しいスキルの道具も従う）
* 規則: [rules/maintenance.md](../rules/maintenance.md)
* 来歴: 適用先 ATRS のオーナーの依頼。ATRS の側の適用は ATRS の ADR 625d・backlog 2ba8 にある。
