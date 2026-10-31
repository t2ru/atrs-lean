---
type: Architecture Decision Record
title: "docs/ を OKF v0.2 の Knowledge Bundle とする"
description: "docs/ 配下の全文書を Open Knowledge Format v0.2 に準拠させ、docs/index.md を文書インデックスとする。"
tags: [adr, documentation, okf]
id: "a0f1f899-b342-4e15-881f-8878d29680d7"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/open-knowledge-format/blob/main/SPEC.md
    title: Open Knowledge Format (OKF) Specification v0.2
---

# docs/ を OKF v0.2 の Knowledge Bundle とする

## Context and Problem Statement

`docs/` の文書（ADR・仕様・規約・バックログ）は人間と AI エージェントの双方が読み書きする。
文書の種類・来歴・検証状態・ライフサイクルを機械可読に持たせ、文書全体の索引を一箇所に置きたい。
プロジェクトオーナーから「ドキュメントは OKF v0.2 とし、`docs/index.md` に文書のインデックスを置く」との指示があった。

OKF v0.2 は Markdown + YAML frontmatter のディレクトリ階層を Knowledge Bundle とし、
予約ファイル `index.md`（索引）と `log.md`（更新履歴）、必須キー `type`、
ライフサイクル `status`（`draft` / `stable` / `deprecated`）、来歴 `generated`・`verified`・`sources` を定める[^okf-spec]。

一方、MADR（[ADR d845](d845-record-architecture-decisions-with-madr.md)）の frontmatter も `status` キー（`proposed` / `accepted` …）を使うため、両者の衝突を解消する必要がある。

## Decision Drivers

* プロジェクトオーナーの指示（OKF v0.2 準拠、`docs/index.md` の設置）
* MADR の構成（節見出し・状態遷移）を維持すること
* 既存のツール（GitHub のレンダリング、相対リンク）で読めること

## Considered Options

* `docs/` を OKF バンドルとし、OKF の `status` をライフサイクルに使い、MADR の状態は拡張キー `decision_status` に置く
* `docs/` を OKF バンドルとし、`status` に MADR の値をそのまま書く
* OKF を採用しない

## Decision Outcome

Chosen option: "OKF バンドルとし、MADR の状態は拡張キー `decision_status` に置く", because OKF の予約キーの意味を壊さず、MADR の情報も失わないため。

規則（詳細は [documentation.md](../rules/documentation.md#okf-v02)）:

* バンドルのルートは `docs/`。ルートの [`docs/index.md`](../index.md) は frontmatter に `okf_version: "0.2"` だけを持ち、本文は `#` 見出し + 箇条書きリンク（`* [題名](パス) - 説明`）の索引とする。
* `docs/` 配下の `index.md`・`log.md` 以外のすべての `.md`（`README.md` を含む）は frontmatter を持ち、`type` を必須とする。`title`・`description`・`tags` も書く。
* `status` は OKF のライフサイクル（`draft` / `stable` / `deprecated`）にのみ使う。
  * ADR の MADR 状態は `decision_status`（`proposed` / `accepted` / `rejected` / `deprecated` / `superseded`）、置換先は `superseded_by` に書く。対応: `proposed` → `status: draft`、`accepted` → `stable`、それ以外 → `deprecated`。
  * backlog の作業状態は `state`（`todo` / `doing` / `blocked` / `done` / `dropped`）に書く。
* 来歴: AI が生成・更新した文書には `generated: {by: <producer>/<version>, at: <ISO 8601 オフセット付き>}` を書く。人がレビューしたら `verified` に `by: human:<id>` を追加する（OKF の trust tier で human-reviewed になる）。
* 原典などの出典は `sources`（`id`, `resource`, `title`）に書き、本文から脚注 `[^id]` で参照してよい。
* 変更履歴は [`docs/log.md`](../log.md)（新しい順、`## YYYY-MM-DD` 見出し）に記録する。
* MADR の `date`・`decision-makers`・`consulted`・`informed` は拡張キーとして残す。
* リンクは相対パスで書く（OKF は `/` 始まりのバンドル相対リンクを推奨するが、相対リンクも許容しており、GitHub 上でも正しく解決されるため）。

### Consequences

* Good, because 文書の種類・状態・来歴を機械的に集計できる（例: 未レビュー文書の一覧）
* Good, because `docs/index.md` から全文書へ段階的に辿れる
* Bad, because frontmatter の記述量が増え、`index.md` の更新漏れが起こりうる

### Confirmation

* `docs/` の `index.md`・`log.md` 以外の全 `.md` が YAML frontmatter と空でない `type` を持つことをスクリプトで検査する（OKF §11 の適合条件）。
* `docs/index.md` が `docs/` 配下の全文書へのリンクを持つことを検査する。

## Pros and Cons of the Options

### `decision_status` に分離

* Good, because OKF の `status` の意味を保つ
* Bad, because MADR 標準ツールが `status` を期待する場合に対応が要る

### `status` に MADR の値

* Good, because MADR のテンプレートそのまま
* Bad, because OKF の消費者が `accepted` 等を不正なライフサイクル値として扱う

### OKF を採用しない

* Good, because 記述量が少ない
* Bad, because 指示に反する

## More Information

* [ADR d845](d845-record-architecture-decisions-with-madr.md) を補完する（置換しない）。
* [decision-records.md](../rules/decision-records.md), [backlog.md](../rules/backlog.md)

[^okf-spec]: Open Knowledge Format (OKF) Specification v0.2 — §3 Bundle, §4 Frontmatter, §5 Provenance/Trust/Lifecycle, §8 Index, §9 Log, §12 Versioning.
