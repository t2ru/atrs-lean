---
type: Architecture Decision Record
title: "言語間移植の方法をアプリ非依存のスキル port-lang に切り出し、docs/ には ATRS 固有の情報を残す"
description: "Lean を介した言語間移植の方法を Agent Skills 形式のスキル .agents/skills/port-lang に移し、言語ごとの情報を役割に依存しない言語パックとして references/<lang>/ に置く。"
tags: [adr, skill, porting, documentation]
id: "f4e1419f-97dc-4629-b465-b90a88300568"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:39:02+09:00
sources:
  - id: agentskills
    resource: https://agentskills.io/specification
    title: Agent Skills Specification
---

# 言語間移植の方法をアプリ非依存のスキル port-lang に切り出し、docs/ には ATRS 固有の情報を残す

## Context and Problem Statement

`docs/` には、ATRS 固有の仕様・決定と、アプリに依存しない移植の方法が混在していた。
方法の例は、層構成、正規仕様の置き方、追跡、版上げ、適合テスト、Lean・Rust の規約、Java/SQL の意味論の扱いである。
方法の部分は、別のアプリケーション・別の言語ペアの移植にもそのまま使える。
プロジェクトオーナーから次の 3 点の指示があった[^agentskills]。
- 方法を Agent Skills 仕様のスキル `.agents/skills/port-lang/{SKILL.md,references}` に移す。
- 言語ごとの情報を `references/<lang>/` に置き、どの言語も移植元にも移植先にもなれる構成にする。
- `docs/` には ATRS 特有の情報を残す。

## Decision Drivers

* 方法を他のアプリケーション・言語ペアで再利用できること
* AI エージェントが、必要な時に必要な分だけ読み込めること（Agent Skills の段階的な読み込み）
* ATRS の意思決定の記録（ADR）を壊さないこと
* 言語パックが役割（移植元・移植先）に縛られないこと

## Considered Options

* スキル `port-lang` に方法を切り出し、役割に依存しない言語パックを置く。`docs/` は ATRS 固有の情報と ADR を持つ
* `docs/` に方法と ATRS 固有の情報を混在させたままにする
* 方法を別リポジトリに切り出す

## Decision Outcome

Chosen option: "スキル `port-lang` に方法を切り出し、役割に依存しない言語パックを置く", because 再利用性と段階的な読み込みを得られ、ATRS の記録はそのまま残せるため。

### 分類の基準

| 情報 | 置き場所 |
| --- | --- |
| アプリにも言語にも依存しない方法（層、手順、仕様文書の書き方、言語中立性、ベクタの形式、追跡、版上げ、検証の使い分け） | `.agents/skills/port-lang/SKILL.md` と `references/*.md` |
| 言語固有の情報 | `references/<lang>/` |
| 形式化言語 Lean の規約 | `references/lean/` |
| ATRS 固有の仕様・決定・作業・運用規約、スキルの ATRS への適用（言語ペア、配置、機能名、型、必須の依存、上流の版） | `docs/`（適用は [docs/rules/atrs-porting.md](../rules/atrs-porting.md)） |

### 言語パック

言語パック `references/<lang>/` は、移植元にも移植先にもなれるように、同じ 6 ファイルで構成する。
役割による違いは、各ファイルの「移植元として」「移植先として」の節に書く。
整備されていない項目は「未整備」と明記して残す。

| ファイル | 内容 |
| --- | --- |
| `semantics.md` | `LangSemantics.<Lang>` |
| `locators.md` | ロケータとインベントリ |
| `frameworks.md` | フレームワーク・ランタイムの効果 |
| `harness.md` | ベクタの実行（オラクル／照合） |
| `verification.md` | 検証器 |
| `layout.md` | ソース構成と Lean 名前空間の対応 |

### 規則

* スキルにはアプリ固有の決定を書かず、`docs/` へのリンクも張らない（他リポジトリへ持ち出せるようにするため）。
* 既存の ADR（本 ADR より前の 24 件）は ATRS の意思決定の記録として `docs/decision/` に残す。決定内容は変えず、移動した規約へのリンクだけを張り替える。方法の詳細の正は、以後スキルにある。
* 優先順位: ATRS の ADR → `docs/rules/`（`atrs-porting.md` を含む）→ スキル。
* スキルの改訂は `SKILL.md` の `metadata.version` で管理する。ATRS が使う版は `atrs-porting.md` に記録する。
* スキルの方針を変える改訂は、ATRS にも影響する場合は ATRS の ADR を作る。

### 移動したもの

| 旧 | 新 |
| --- | --- |
| `docs/rules/porting.md` | `references/process.md` |
| `docs/rules/spec-writing.md` | `references/spec-documents.md` |
| `docs/rules/portability.md` | `references/portability.md` |
| `docs/rules/testing.md` | `references/verification.md` |
| `docs/rules/upstream-upgrade.md` | `references/upgrade.md`（ATRS の例は `atrs-porting.md` へ） |
| `docs/rules/lean.md` | `references/lean/rules.md`, `references/lean/trace-attributes.md`（ATRS の型・機能名は `atrs-porting.md` へ） |
| `docs/rules/rust.md` | `references/rust/layout.md`, `references/rust/verification.md` ほか |
| `docs/spec/conformance.md`・`traceability.md`・`refinement.md` の方式部分 | `references/conformance.md`・`traceability.md`・`verification.md`（ATRS の操作名・例・課題一覧は `docs/spec/` に残す） |

### Consequences

* Good, because 別のアプリケーション・言語ペアでも、スキルと言語パックをそのまま使える
* Good, because エージェントは `SKILL.md` と、使う言語のパックだけを読めばよい
* Bad, because 方法（スキル）と ATRS の決定（ADR）の 2 か所を見る必要がある
* Bad, because Claude Code はスキルを `.claude/skills/` から自動で読み込むため、`.agents/skills/` を使うには AGENTS.md からの参照（または利用環境での設定）が必要

### Confirmation

* `SKILL.md` の frontmatter が Agent Skills 仕様を満たす（`name` がディレクトリ名と一致、`description` 1024 文字以内、`metadata` の値が文字列、本文 500 行未満）。
* スキル内に ATRS 固有の語（ATRS の機能・コード・commit・`docs/` へのリンク）が無いことを検査する。
* `docs/` のリンク検査が通る。

## Pros and Cons of the Options

### スキルに切り出す

* Good, because 再利用・段階的な読み込みができる
* Bad, because 参照先が 2 か所になる

### 混在のまま

* Good, because 移動の手間が無い
* Bad, because 再利用できず、ATRS 固有の判断と方法の区別がつかない

### 別リポジトリ

* Good, because 完全に独立する
* Bad, because 現時点では ATRS と同時に育てる必要があり、同期の手間が大きい

## More Information

* [port-lang の SKILL.md](../../.agents/skills/port-lang/SKILL.md), [atrs-porting.md](../rules/atrs-porting.md)
* 補足（2026-10-31）: スキルの `references/` は `references/docs/`（OKF v0.2 のバンドル）に移った。本文の `references/*.md`・`references/<lang>/` は、今は `references/docs/` の下にある。スキル自身の意思決定記録・作業項目もそこに置き、純粋にスキルの ADR・backlog は ATRS から移した（[ADR 50f9](50f9-move-skill-records-to-skill-bundle.md)、[スキルの ADR 87b9](../../.agents/skills/port-lang/references/docs/decision/87b9-skill-docs-as-okf-bundle.md)）。スキルの記録に限り、ATRS の記録を来歴としてリンク無しで挙げてよい。

[^agentskills]: Agent Skills Specification — `SKILL.md` の frontmatter（`name`, `description`, `compatibility`, `metadata`）、`references/` の段階的な読み込み、ファイル参照は 1 段まで。
