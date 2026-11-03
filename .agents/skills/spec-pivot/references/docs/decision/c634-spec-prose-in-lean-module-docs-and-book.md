---
type: Architecture Decision Record
title: "仕様の散文を Spec のモジュール文書に書き、mdgen と mdbook で本にする道具を置く"
description: "Spec で表せない仕様・形式化前の草案・形式化した規則の要約を、Markdown の仕様文書ではなく Spec のモジュール文書（/-! -/）の節として、定義のすぐ前に書く。Markdown の仕様文書にはメタ情報だけを残す。mdgen（assets/mdgen）と mdbook で HTML の本を作る道具 scripts/book/build.py と、仕様への参照の行き先の検査、TR-R のモジュール文書への拡張を置く。"
tags: [adr, spec, documentation, lean, tooling]
id: "c6347fe6-1584-4b50-8967-6502f476eafe"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: 適用先 ATRS のオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
---

# 仕様の散文を Spec のモジュール文書に書き、mdgen と mdbook で本にする道具を置く

## Context and Problem Statement

この方法では、正規仕様は Lean の `Spec` であり、`Spec` で表せない仕様（規範）・形式化前の草案・形式化した規則の要約を、Markdown の仕様文書に書くとしていた（[spec-documents.md](../rules/spec-documents.md)）。
散文と定義が別のファイルにあると、読む人は 2 か所を往復し、定義を直しても離れた要約が古いまま残りやすい。また、定義から仕様文書の節を指す `@[spec_doc]` と、ベクタの `specRef` の行き先は、どの道具も検査していなかった。
適用先 ATRS のオーナーは、業務仕様を Lean のコメント文書として書き、mdgen と mdbook で HTML を作るよう求めた（来歴: ATRS の ADR 68a6）。

## Decision Drivers

* 散文と定義を同じファイルの隣に置くこと
* 区分（normative・meta・draft・informative）と節構成の規則は変えないこと
* 仕様の散文に、追跡の検査（TR-R の「出典:」）と、リンク・アンカーの検査が届き続けること
* 移植先の言語や文書の道具に依存しないこと（本はどの適用先でも同じ手順で作れる）

## Considered Options

* 散文を `Spec` のモジュール文書に書き、mdgen と mdbook で本にする
* 散文は Markdown の仕様文書のまま、mdbook で本にする
* doc-gen4 で `Spec` の API 文書を作る

## Decision Outcome

Chosen option: "散文を `Spec` のモジュール文書に書き、mdgen と mdbook で本にする", because 散文と定義が同じファイルに並び、mdgen は定義をコードブロックとして本に残すので、本でも要約と定義を見比べられるため。mdgen は Lean で書かれ、Lean の処理系だけで動く。

### 置き場所と書き方

* `Spec` で表せない仕様・草案・要約は、`Spec` のモジュールのモジュール文書（列 0 から始まる `/-! … -/`）の節として、その節が述べる定義のすぐ前に書く。形式化していない領域は、文書だけのモジュールにする。生成するファイルには書かない。
* 区分は、各モジュール文書・節の冒頭に書く（Markdown の frontmatter の `spec_role` に当たる）。区分と節構成の規則は変えない。
* Markdown の仕様文書には、メタ情報（課題一覧・既知差異・保証の限界・追跡・ベクタの形式）だけを置く。道具が読む見出し（[spec-documents.md](../rules/spec-documents.md#道具が読む見出しと値)）は、これまでどおり課題一覧にある。
* モジュール文書の中のリンクは、その Lean のファイルから見た相対パスで書く。`@[spec_doc]`・ベクタの `specRef` は `<Lean のファイル>#<見出しのアンカー>` で書く。アンカーは GitHub の規則で作る。

### 道具

* `assets/mdgen`: mdgen を取り込むだけの Lake パッケージ。mdgen は入力を文字列として読むだけなので、モデルの Lean パッケージの依存には加えない。版は適用先の Lean の版に合わせる。
* `scripts/book/build.py`: 本を作る（設定は `trace/project.json` の `book`）。roots の Lean のファイルを mdgen で Markdown にし、roots の中の `.lean` へのリンクを本のページへの、外へのリンクを `repo_url` の URL へのリンクに替え、`entry` の import の順で目次を作り、mdbook で HTML にする。
  * `--check` は、`@[spec_doc]`（`trace/manifest.json`）とベクタの `specRef` の行き先のファイルと見出しが在ることを確かめる。見出しのアンカーは、スキル okf-bundle の `okf_check.py` と同じ規則で作る（同スクリプトの関数を使う）。
* `trace check` の TR-R は、`docs.spec_lean`（任意）の Lean のファイルの「出典:」も検査する。

### Consequences

* Good, because 散文と定義が隣り合い、仕様への参照の行き先も検査される。
* Good, because 本の目次とページの並びが `Spec` のモジュールの構成と一致する。
* Bad, because mdgen の版を Lean の版に合わせて上げる必要がある。mdgen の地の文の規則が変われば、okf-bundle の読み方も合わせる。
* Bad, because 本の道具が、スキル okf-bundle の `okf_check.py` に依存する。

## More Information

* 規則: [spec-documents.md](../rules/spec-documents.md)。設定: [traceability.md](../spec/traceability.md#プロジェクトの設定)。道具: `scripts/README.md`。
