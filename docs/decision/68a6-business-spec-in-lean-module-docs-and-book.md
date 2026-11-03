---
type: Architecture Decision Record
title: "業務仕様を Spec のモジュール文書に書き、mdgen と mdbook で HTML の本にする"
description: "docs/spec の業務仕様（要約・草案・Spec で表せない規範）を、lean/Spec の各モジュールのモジュール文書（/-! -/）として定義のすぐ前に置く。形式化していない領域は文書だけのモジュールにする。mdgen で Markdown に、mdbook で HTML にして CI の artifact にする。docs/spec にはメタ情報だけを残す。mise が管理する道具に mdbook を足す。"
tags: [adr, spec, documentation, lean, mdbook]
id: "68a643d6-307e-45a2-ad90-0a9774c42fc3"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
---

# 業務仕様を Spec のモジュール文書に書き、mdgen と mdbook で HTML の本にする

## Context and Problem Statement

正規仕様は Lean の `Spec` であり、`Spec` で表せない仕様・形式化前の草案・形式化した規則の要約は `docs/spec/*.md` に書いていた（[ADR 61bc](61bc-lean-spec-as-normative-source.md)）。
業務仕様の散文と Lean の定義が別のファイルにあるため、次のことが起きていた。

* 読む人は、Markdown の節と Lean の定義を `@[spec_doc "docs/spec/<文書>.md#<見出し>"]` を手がかりに往復する。
* 定義を直しても、離れた文書の要約が古いまま残りやすい（ADR 61bc の Bad の 1 つ）。
* `@[spec_doc]`・ベクタの `specRef` の行き先（文書と見出し）は、どの検査も確かめていなかった。

プロジェクトオーナーは、業務仕様を `docs` ではなく Lean のコメント文書として書き、mdgen と mdbook で HTML を作るよう指示した（[backlog c89a](../backlog/c89a-business-spec-in-lean-module-docs.md)）。

## Decision Drivers

* 散文と定義を同じファイルの隣に置き、食い違いを見つけやすくすること
* 読む人には、Lean を開かなくても通して読める本を渡すこと
* 移した後も、リンク・見出しアンカー・「出典:」の検査が届く範囲を減らさないこと
* `atrs` パッケージの依存（Batteries と langSemantics だけ。ADR 659f）を増やさないこと

## Considered Options

* 業務仕様を `Spec` のモジュール文書（`/-! -/`）に移し、mdgen と mdbook で本にする
* doc-gen4 で API 文書を作り、散文は `docs/spec` に残す
* `docs/spec` のまま、mdbook で `docs/spec` を本にする

## Decision Outcome

Chosen option: "業務仕様を `Spec` のモジュール文書に移し、mdgen と mdbook で本にする", because 散文と定義が同じファイルに並び、mdgen が定義をコードブロックとして本に残すので、本の中でも要約と定義を見比べられるため。doc-gen4 は宣言の文書を作るが、節立ての散文と表の本には向かず、ビルドも重い。`docs/spec` のまま本にしても、散文と定義が離れたままである。

### 置き場所

* 移す範囲は業務仕様の 14 本（用語集・設定・ドメインモデル・マスタデータ・運賃計算・空席照会・予約・会員・認証・予約履歴レポート・入力検証・エラーとメッセージ・ポート・HTTP 契約）とした。メタ情報（`README`・`abstraction`・`refinement`・`assurance`・`conformance`・`traceability`）は `docs/spec` に残す。これらは道具が読み書きする（生成区画・課題の表）ためである。
* 各文書の `##` 節を 1 つの `/-! … -/` とし、その節を `@[spec_doc]` で指す宣言の直前に置く。文書の題と前文は、移し先のモジュールの先頭のモジュール文書に合わせ、題を「<文書の題>（`<モジュール名>`）」とする。区分（normative・draft・informative・meta）の表示は、各文書・節の冒頭にそのまま残す。
* 形式化していない領域は、文書だけのモジュール `Spec.Glossary`・`Spec.Member`・`Spec.Authentication`・`Spec.ReservationHistoryReport`・`Spec.InputValidation`・`Spec.Http` にする。形式化するときは、同じファイルに定義を足す。
* 生成するファイル（`Spec.Seed` など）には散文を置かない（生成で消えるため）。シードデータの節は `Spec.MasterData` に置いた。
* 移し先は配置表 `tools/docs/spec-to-lean.json` に、古い `docs/spec/<文書>.md#<見出し>` と新しい `lean/Spec/<File>.lean#<見出し>` の対応は `tools/docs/spec-anchors.json` に残す。

### 書き方

* モジュール文書のリンクは、その Lean のファイルから見た相対パスで書く（エディタと GitHub で辿れる）。
* 仕様への参照（`@[spec_doc]`・登録簿の `sites`・ベクタの `specRef`）は `lean/Spec/<File>.lean#<見出し>` で書く。見出しのアンカーは、モジュール文書の見出しから GitHub の規則で作る（mdbook の id と一致することを確かめた）。
* 形式の規則は、スキル spec-pivot の [spec-documents.md](../../.agents/skills/spec-pivot/references/docs/rules/spec-documents.md) による（[スキルの ADR c634](../../.agents/skills/spec-pivot/references/docs/decision/c634-spec-prose-in-lean-module-docs-and-book.md)）。

### 本と検査

* `mise run book:build` が、スキルの `scripts/book/build.py` で本を作る。mdgen（Lean のファイルを Markdown にする。スキルの `assets/mdgen` の Lake パッケージ）で Markdown にし、mdbook で `build/book/html/` に HTML を出す。CI は artifact `spec-book` として上げる。設定は `trace/project.json` の `book`。
* mdbook は mise が版を固定して入れる（`mise.toml` の `[tools]`）。[ADR 44a0](44a0-mise-tasks-and-uv-for-tools.md) の「mise が管理する道具は uv だけ」を、uv と mdbook に改める。
* `mise run book:check`（常時の段）が、`@[spec_doc]` の行き先とベクタの `specRef` が、Lean のモジュール文書の見出しにあることを確かめる。
* `okf_check.py`（`docs:okf`）が、`lean/Spec.lean`・`lean/Spec/` のモジュール文書の中のリンクと、`.lean` の見出しアンカーを検査する（`.okf.json` の `links.lean_roots`。スキル okf-bundle の [ADR 75c9](../../.agents/skills/okf-bundle/references/docs/decision/75c9-check-links-in-lean-module-docs.md)）。
* `trace check` の TR-R が、`Spec` のモジュール文書の「出典:」も検査する（`trace/project.json` の `docs.spec_lean`）。

### Consequences

* Good, because 業務仕様の散文と Lean の定義が同じファイルに並び、本でも隣り合う。
* Good, because 仕様への参照の行き先が、初めて検査される。
* Bad, because 散文の変更も Lean のファイルの変更になり、変更時の段（Lean のビルドなど）を起こしうる。
* Bad, because 道具（mdgen と mdbook）が増え、mdgen の版を Lean の版に合わせて上げる必要がある。

### Confirmation

* `mise run book:check`・`docs:okf`・`trace:check` が CI で通ること。
* `mise run book:build` の本で、`@[spec_doc]` と `specRef` の行き先のアンカーが HTML の id として存在すること。

## More Information

* ADR 61bc の決定（`Spec` が正規、`Spec` で表せない仕様は規範節）は変えない。規範節・草案・要約の **置き場所** だけを、`docs/spec` から `Spec` のモジュール文書に改める。
* 道具は [mdgen](https://github.com/Seasawher/mdgen)（版 `v4.35.0-rc4`。Lean 4.35 系）と [mdBook](https://github.com/rust-lang/mdBook)（版 0.5.4）。
