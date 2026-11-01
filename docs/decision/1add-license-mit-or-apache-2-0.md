---
type: Architecture Decision Record
title: "公開のライセンスを MIT OR Apache-2.0 のデュアルライセンスとし、上流由来の部分を NOTICE で示す"
description: "リポジトリの公開にあたり、本プロジェクトの著作物を MIT License と Apache License 2.0 のデュアルライセンス（SPDX: MIT OR Apache-2.0）とし、ルートに LICENSE-MIT・LICENSE-APACHE・NOTICE・README.md を置く。submodule の上流 ATRS は対象外で Apache-2.0 のまま。SourceModel・共有入力・原典実行の採取結果など上流から派生した部分は NOTICE に列挙し、再配布には上流の Apache-2.0 の条件もかかることを示す。"
tags: [adr, license, publication, upstream]
id: "1add6f7f-4e01-44a7-a3d3-90ac9d76fa67"
status: stable
decision_status: accepted
date: 2026-11-02
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T09:00:00+09:00
---

# 公開のライセンスを MIT OR Apache-2.0 のデュアルライセンスとし、上流由来の部分を NOTICE で示す

## Context and Problem Statement

リポジトリを公開するにあたり、ライセンスと、リポジトリの入口になる README.md が無かった。
本リポジトリには、本プロジェクトの著作物（`Spec`・証明・スキル・道具・文書）のほかに、上流の TERASOLUNA ATRS（Apache License 2.0。Copyright NTT Corporation・NTT DATA Group Corporation）から派生した部分がある。
`SourceModel` は原典の Java/SQL を写し（[ADR e41c](e41c-source-model-mirrors-java-tree.md)）、共有入力 `conformance/fixtures/` は上流のシードから生成し（[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)）、`conformance/source-model/**/origin-run-*.json` と `tools/origin-run/http/` は原典の実行の採取結果である（[ADR 81da](81da-java-origin-run-domain-and-http.md)）。
上流のソースそのものは submodule `upstream/atrs` で参照し、リポジトリには含めない。

## Decision Drivers

* 公開と再利用を妨げないこと。特に、アプリに依存しないスキル（spec-pivot・okf-bundle・work-records）を他のプロジェクトへ持ち出しやすいこと（プロジェクトオーナーの指示: MIT と Apache-2.0）
* 移植先の Rust の慣例（`MIT OR Apache-2.0`）と揃うこと
* 上流の Apache License 2.0 の条件（第 4 条の、ライセンスの写しの同梱・変更の明示・帰属表示の保持）を守ること
* 本プロジェクトの著作物と上流由来の部分の境界が、利用者に分かること

## Considered Options

* MIT OR Apache-2.0 のデュアルライセンスとし、上流由来の部分を NOTICE で示す
* Apache-2.0 だけにする
* MIT だけにする

## Decision Outcome

Chosen option: "MIT OR Apache-2.0 のデュアルライセンスとし、上流由来の部分を NOTICE で示す", because オーナーの指示であり、Rust の生態系の慣例に揃い、利用者が MIT の簡潔さと Apache-2.0 の特許の許諾のどちらかを選べるからである。上流が Apache-2.0 なので、Apache-2.0 の側を選んだ利用者には上流と同じ条件になる。

* ルートに次を置く。
  * `LICENSE-APACHE`: Apache License 2.0 の本文（<https://www.apache.org/licenses/LICENSE-2.0.txt> のまま）
  * `LICENSE-MIT`: MIT License（Copyright (c) 2026 Tetsuya Takatsuru）
  * `NOTICE`: デュアルライセンスの宣言と、第三者の素材（上流 ATRS）の著作権・ライセンス・派生した部分の一覧
  * `README.md`: プロジェクトの概要・状態・使い方・ライセンス・貢献の扱い
* submodule `upstream/atrs` は本リポジトリのライセンスの対象外とし、上流のライセンスに従う。
* 上流から派生した部分（`lean/SourceModel/`・`conformance/fixtures/`・`conformance/source-model/**/origin-run-*.json`・`tools/origin-run/http/`・`trace/`・`docs/spec/` の原典の抜き書き）は `NOTICE` に列挙する。本プロジェクトが加えた部分はデュアルライセンスで提供し、再配布には上流の Apache-2.0 の条件もかかることを示す。
* 貢献は、明示が無い限り、Apache-2.0 の定義に従い追加の条件なしにデュアルライセンスで提供されるものとする（README.md に書く）。
* ソースファイルごとのライセンスの見出し（SPDX の行）は付けない。ルートのファイルで全体を覆う。

### Consequences

* Good, because 利用者が MIT と Apache-2.0 を選べ、Rust の移植先のクレートとも揃う
* Good, because スキルをリポジトリの外へ持ち出すときのライセンスが明確になる
* Good, because 上流由来の部分と、そこにかかる上流の条件が NOTICE で分かる
* Bad, because 上流由来の部分を MIT の側で再配布する利用者も、上流の Apache-2.0 の条件を守る必要があり、MIT の簡潔さがその部分では効かない
* Bad, because スキルのディレクトリだけを持ち出すときは、ルートのライセンスの写しを一緒に持ち出す必要がある

### Confirmation

* ルートに `LICENSE-MIT`・`LICENSE-APACHE`・`NOTICE`・`README.md` があり、`LICENSE-APACHE` の SHA-256 が公式の本文と一致する（`cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30`）。機械の検査は置かない。
* 上流から派生する部分を新たに足したときは、`NOTICE` の一覧を改める。

## More Information

* 上流のライセンス: `upstream/atrs/license.md`（Apache License 2.0）。上流に NOTICE ファイルは無い。
* 本 ADR は法的な助言ではない。公開の前に、必要ならオーナーが専門家に確かめる。
* スキルの `SKILL.md` の frontmatter の `license` 欄（Agent Skills の形式）は、本 ADR では足さない。
