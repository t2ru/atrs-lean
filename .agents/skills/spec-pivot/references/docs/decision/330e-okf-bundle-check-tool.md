---
type: Architecture Decision Record
title: "OKF バンドルとリンクの検査の道具 okf_check.py を置き、規則を設定のプロファイルで与える"
description: "OKF v0.2 の適合条件（frontmatter・type・index.md・log.md）、バンドルの規則（種類ごとの type・必須キー・必須の節・意思決定記録と作業項目の形）、索引の網羅、Markdown の相対リンクと見出しアンカーを検査する道具を scripts/docs/okf_check.py に置く。標準ライブラリだけで動かすため、frontmatter は YAML の部分集合として読む。規則は trace/project.json の okf にバンドルごとのプロファイルとして書く。"
tags: [adr, skill, documentation, okf, ci]
id: "330e6a64-190c-48d8-b9cf-bb0d941f5fbd"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T20:10:00+09:00
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/main/SPEC.md
    title: Open Knowledge Format (OKF) Specification v0.2
  - id: github-slugger
    resource: https://github.com/Flet/github-slugger
    title: github-slugger
---

# OKF バンドルとリンクの検査の道具 okf_check.py を置き、規則を設定のプロファイルで与える

## Context and Problem Statement

スキルの文書（`references/docs/`）と、適用先の文書は、どちらも OKF v0.2 のバンドルである（[ADR 87b9](87b9-skill-docs-as-okf-bundle.md)）。
`scripts/docs/ids.py` は ID と、意思決定記録・作業項目へのリンクを検査する。しかし、frontmatter・索引・変更履歴の形と、一般の相対リンク・見出しアンカーは、誰も検査していなかった。
OKF の適合条件は、frontmatter が YAML として読めること、`type` が空でないこと、`index.md`・`log.md` が §8・§9 の形であることである[^okf-spec]。
バンドルごとの規則（どのディレクトリにどの `type` を書くか、意思決定記録の節など）は、適用先によって異なる。
[backlog de90](../backlog/de90-skill-docs-okf-bundle-and-records.md) は、この一般の検査を対象外として残していた。きっかけは ATRS の backlog ddbd である。

## Decision Drivers

* 決定論的であること。同じ文書には、どの環境でも同じ判定を返す
* スキルの他の Python の道具と同じく、標準ライブラリだけで動くこと
* アプリに依存しないこと。適用先の規則は設定で与える
* スキル自身のバンドルの規則を、スキルと一緒に持ち出せること

## Considered Options

* frontmatter の読み方
  * YAML の部分集合を、道具の中の小さなパーサで読む
  * PyYAML を使う
  * PyYAML があれば使い、無ければ部分集合で読む
* 規則の与え方
  * バンドルごとのプロファイル（パスの glob ごとの規則）を設定に書き、意思決定記録・作業項目の意味の検査は種類（`kind`）として道具に組み込む
  * 検査を道具に固定し、設定は置かない
* 置き場所
  * スキルの `scripts/docs/okf_check.py`（`ids.py` と並べる）
  * `ids.py` に足す

## Decision Outcome

Chosen option: "部分集合のパーサ、プロファイルと種類、`scripts/docs/okf_check.py`", because 標準ライブラリだけで決定論的に動き、適用先ごとの違いを設定に追い出せるため。`ids.py` は ID の採番と書き換えを担っており、文書の形の検査を混ぜると見通しが悪くなる。

### 検査

違反はどれも失敗扱いとする（終了コード 1）。符号は道具の docstring に一覧がある。

| 符号 | 内容 | 根拠 |
| --- | --- | --- |
| F1・F2 | frontmatter が部分集合の YAML として読めること、空でない文字列の `type` | OKF §11-1・§11-2 |
| R1・R2 | `index.md`（frontmatter はバンドルのルートの `okf_version` だけ、本文は `#` 見出しと `* [題名](パス) - 説明` だけ）・`log.md`（frontmatter 無し、`## YYYY-MM-DD` が新しい順で重複しない） | OKF §8・§9・§11-3・§12 |
| K1〜K4・H1・S1 | プロファイルの規則: `type`、必須キー、値（`status`・`generated`・`verified`・`sources`・`tags` の形と、規則の `enum`）、ダブルクォート、`#` 見出しが 1 つで `title` と一致、必須の節の有無と順序 | OKF §5・§7、プロファイル |
| A1・B1 | 種類 `adr`: `decision_status` と `status` の対応、`superseded_by`、選択肢 2 つ以上、採択を示す行。種類 `backlog`: `state` の値、`status` を持たない、`done` の項目に未完了の完了条件が無い | [maintenance.md](../rules/maintenance.md) |
| I1・I2 | バンドルのルートの `index.md` がすべての文書を列挙し、項目の題名・説明が文書の `title`・`description` と一致する | プロファイル |
| L1〜L3 | 相対リンクの指す先がある、見出しアンカーが指す Markdown にある、`/` で始まるリンクを書かない（設定） | 設定 |

* OKF は、壊れたリンクや無い索引を理由に、消費者がバンドルを拒むことを禁じている[^okf-spec]。これは消費者の義務である。生産者が自分のバンドルにより強い規則を課すことは妨げない。この道具は生産者の側の検査である。
* 見出しアンカーは GitHub の規則（github-slugger）で作る[^github-slugger]。小文字にし、文字・数字・結合文字・連結句読点・`-`・空白以外を除き、空白を `-` にする。同じ見出しには `-1`・`-2` を付ける。見出しの Markdown（コード・リンク・強調）は表示される文字列に直してから作る。
* コードブロックとインラインのコードの中は、リンク・見出しとして扱わない。

### YAML の部分集合

frontmatter は次の部分集合で書く。部分集合の外の書き方は、YAML として正しくても違反（F1）とする。

* ブロックのマッピングとブロックの列。字下げは空白。列は親のキーより深く字下げする。
* スカラ: ダブルクォート・シングルクォート・1 行のプレーン。`null`・`true`・`false`・整数だけを型付きで読む。日付・時刻は文字列のまま読む。
* フローの列 `[a, "b"]`（要素はスカラだけ）。コメント。
* 使えないもの: フローのマッピング、ブロックのスカラ、複数行のプレーン、アンカー・別名・タグ、キーの重複。

既存の文書の frontmatter は、この部分集合で書かれていた。部分集合で読んだ値は、PyYAML で読んだ値と一致することを確かめた（日付・時刻の型の違いを除く）。

### 設定

`trace/project.json` の `okf` に書く（[traceability.md](../spec/traceability.md#プロジェクトの設定)、[maintenance.md](../rules/maintenance.md#バンドルの検査)）。

* `bundles`: `[{root, profile}]`。`profile` はプロファイルそのものか、プロファイルの JSON のパス。
* プロファイル: `okf_version`（ルートの索引に `okf_version` を要求する）、`index_complete`、`common`（`required`・`quoted`・`title_heading`・`enum`）、`rules`（`[{match, type, kind, required, enum, quoted, sections, outcome_markers}]`。最初に当たった規則を使う。どの規則にも当たらない文書は K1）。
* `links`: `{roots, skip, absolute}`。`skip` は全体の除外（道具の違反例など）。
* このバンドルの規則は `scripts/docs/profiles/spec-pivot.json` に置き、スキルと一緒に持ち出す。適用先は、その設定からこのファイルを指す。

### Consequences

* Good, because frontmatter・索引・変更履歴・リンクの崩れを CI で止められる。
* Good, because 規則が設定にあるので、適用先は自分の規則を足せる。
* Bad, because 部分集合の外の YAML（フローのマッピングなど）は書けない。必要になったら部分集合を広げる。
* Bad, because アンカーの規則は GitHub の実装を写したものであり、Unicode の版の違いなどで、まれに食い違いうる。

### Confirmation

* `python3 -I <skill>/scripts/docs/okf_check.py --self-test` が、部分集合の YAML の正例・違反例、アンカーの例、違反例のバンドル（`scripts/ci/fixtures/okf/`）で、すべての符号を検出する。
* 適用先の一括検査から `okf_check.py` を呼ぶ。

## Pros and Cons of the Options

### PyYAML を使う

* Good, because YAML のすべてを読める。
* Bad, because 標準ライブラリだけで動くという道具の方針に反し、環境に依存する。

### PyYAML があれば使う

* Good, because 手元では YAML のすべてを読める。
* Bad, because 環境によって判定が変わり、決定論的でない。

### 検査を道具に固定する

* Good, because 設定が要らない。
* Bad, because 適用先ごとの `type` やディレクトリの構成を表せない。

### `ids.py` に足す

* Good, because 道具が 1 つで済む。
* Bad, because ID の採番・書き換えと文書の形の検査が混ざる。

## More Information

* 作業: [backlog a49c](../backlog/a49c-okf-bundle-check-tool.md)
* 規則: [maintenance.md](../rules/maintenance.md#バンドルの検査)、道具: [scripts/README.md](../../../scripts/README.md)
* 来歴: ATRS の backlog ddbd（ATRS の `docs/` の検査）、ATRS の ADR a0f1（ATRS の `docs/` の OKF）。ATRS の側の決定は ATRS の ADR 920d にある。

[^okf-spec]: Open Knowledge Format (OKF) Specification v0.2 — §6.1 Links, §8 Index, §9 Log, §11 Conformance, §12 Versioning.
[^github-slugger]: github-slugger — GitHub の見出しアンカーの生成規則の実装。
