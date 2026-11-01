---
type: Architecture Decision Record
title: "スキルの文書を spec/・rules/・guide/・lang/ に分け、移動の道具 docmv.py を置く"
description: "references/docs の方法の文書（平置きの 11 本）を、規範の spec/、書き方の規約の rules/、手順と進め方の guide/ に分け、言語パックを lang/<lang>/ に移す。type は spec を Specification、rules を Guideline、guide を Guide、lang を Reference とする。移動とリンクの張り直しには、新しい道具 scripts/docs/docmv.py を使う。"
tags: [adr, skill, documentation, okf]
id: "748c5270-1dc1-4103-9628-9e61597ef2ef"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:20:00+09:00
---

# スキルの文書を spec/・rules/・guide/・lang/ に分け、移動の道具 docmv.py を置く

## Context and Problem Statement

`references/docs/` は OKF v0.2 のバンドルである（[ADR 87b9](87b9-skill-docs-as-okf-bundle.md)）。ところが、方法の文書 11 本はトップに平置きで、`type` はすべて `Guideline` だった。言語パック `java/`・`sql/`・`rust/`・`lean/` もトップに並んでいた。
そのため、守るべき規範（層・義務・形式）と、書き方の規約と、手順の手引きを、置き場所からも `type` からも区別できなかった。適用先（ATRS）の `docs/` は、すでに `spec/`・`rules/`・`decision/`・`backlog/` に分かれている。
また、文書を移すと、スキル・適用先の文書、Lean・Rust・Python のコメント、設定の note にある約 250 のリンクとパスの言及を張り直す必要がある。`ids.py move` は、意思決定記録・作業項目を 1 件ずつ移す道具で、ディレクトリごとの移動、複数の同時の移動、コードの中の言及を扱えない。

## Decision Drivers

* 文書の性格（規範・規約・手引き）が、置き場所と `type` から分かること
* 適用先のバンドルの分け方と揃えること
* ファイル名と見出しを変えないこと（アンカーと本文の参照を保つ）
* 移動とリンクの張り直しを、決定論的に、漏れなく行えること。今後の組み替えでも使えること

## Considered Options

* 分け方
  * `spec/`（規範）・`rules/`（規約）・`guide/`（手引き）・`lang/<lang>/`（言語パック）
  * 方法の文書だけを `spec/`・`rules/`・`guide/` に分け、言語パックはトップに残す
  * 今のまま（平置き）
* 移動の手段
  * 新しい道具 `scripts/docs/docmv.py`（アプリに依存しない）
  * `ids.py move` を広げる
  * 手で移し、sed で張り直す

## Decision Outcome

Chosen option: "`spec/`・`rules/`・`guide/`・`lang/<lang>/` と、新しい道具 `docmv.py`", because トップがディレクトリだけになり、性格が置き場所と `type` で分かるため。道具にすれば、リンクの張り直しを検査（`okf_check.py`）と組み合わせて確かめられ、次の組み替えにも使える。`ids.py` は ID の採番・検査を担っており、一般の文書の移動を混ぜると見通しが悪くなる。

### 分け方

| ディレクトリ | `type` | 基準 | 文書 |
| --- | --- | --- | --- |
| `spec/` | `Specification` | 方法の規範。適用するプロジェクトが満たさなければならない構成・義務・形式 | architecture・portability・traceability・conformance・verification |
| `rules/` | `Guideline` | 書き方の規約 | spec-documents・maintenance |
| `guide/` | `Guide` | 手順と進め方。置き換えてよい既定を含む | process・workflow・upgrade・adding-a-language |
| `lang/<lang>/` | `Reference` | 言語パック（中の構成は変えない。`lang/sql/dialects/<dbms>/`、形式化言語の `lang/lean/` を含む） | java・sql・rust・lean |

* ファイル名は変えない。`index.md` の節は `Specification`・`Rules`・`Guide`・`Language: …`・`Decisions`・`Backlog` とする。
* プロファイル `scripts/docs/profiles/spec-pivot.json` の規則を、上の表のディレクトリごとにする。どの規則にも当たらない文書は違反（K1）になるので、新しい種類が要るときはディレクトリと規則を足し、記録を残す。

### 道具 docmv.py

* `docmv.py [--dry-run] --root <bundle> <old> <new> …`。ディレクトリはファイルに展開し、複数の移動を 1 回で行う。`git mv` で移す。
* Markdown の相対リンクは、ファイルの移動前の位置から解決し、移動の表で写し、移動後の位置から相対化し直す。コードブロックとインラインのコードの中のリンクの形は、例とみなして張り直さない。
* リンクの外のパスの言及は、`<バンドルの末尾 2 成分>/<old>`（例: `references/docs/architecture.md`）の形だけを直す。バンドルからの相対パスだけの言及（例: `sql/harness.md`）は文脈で意味が決まるので、表示して手で確かめる。
* リポジトリのルートは `git` で決める。`trace/project.json` を読まない。

### Consequences

* Good, because 規範と手引きを読み分けられる。`type` で機械的に選べる。
* Good, because 移動の作業が 1 回の実行と検査で済み、次の組み替えにも使える。
* Bad, because 既存のリンクとパスの言及が変わる。外から深いリンクを張っている利用者は張り直す必要がある。
* Bad, because 来歴（`log.md`・既存の意思決定記録の本文）にある、リンクでない旧パスは、当時の名前のまま残る。

### Confirmation

* `docmv.py --self-test` が、ファイル・ディレクトリの移動、移動元と移動先の両方が動くリンク、アンカー、コードの中のリンク、コードの中の言及を確かめる。
* このバンドルと適用先のバンドルが `okf_check.py`（`type`・索引・リンク・アンカー）と `ids.py check` を違反なしで通る。

## Pros and Cons of the Options

### 言語パックをトップに残す

* Good, because 言語パックへのリンクが変わらない。
* Bad, because トップに方法の分類と言語が混ざり、`**` の規則で `type` を決めることになる。

### 今のまま

* Good, because 何も変わらない。
* Bad, because 規範と手引きを区別できない。

### `ids.py move` を広げる

* Good, because 道具が増えない。
* Bad, because ID の道具に一般の文書の移動が混ざる。設定（`trace/project.json`）に依存する。

### 手で移す

* Good, because 道具が要らない。
* Bad, because 約 250 の箇所で漏れや誤り（コードの中の例のリンクを書き換えるなど）が起きやすく、再現できない。

## More Information

* 作業: [backlog 97a7](../backlog/97a7-skill-docs-category-directories.md)
* 規則: [maintenance.md](../rules/maintenance.md#バンドルの構成)、道具: [scripts/README.md](../../../scripts/README.md)
* 前提: [ADR 87b9](87b9-skill-docs-as-okf-bundle.md)（バンドル）、[ADR 330e](330e-okf-bundle-check-tool.md)（検査とプロファイル）
* 来歴: 適用先 ATRS の `docs/` の分け方（`spec/`・`rules/`）に倣った。
