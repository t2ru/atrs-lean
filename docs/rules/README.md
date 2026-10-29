---
type: Guideline
title: "作業規約（rules）"
description: "作業規約の索引と、規約・文書間の優先順位。"
tags: [rules, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:39:02+09:00
---

# 作業規約（rules）

本ディレクトリはこのリポジトリ（ATRS の移植）で作業する **人間・AI エージェントの双方** が従う **プロジェクトの運用規約** である。
**言語間移植の方法**（層構成、Lean・Java・SQL・Rust の規約、追跡、版上げ、適合テスト）は、アプリに依存しないスキル [port-lang](../../.agents/skills/port-lang/SKILL.md) にある（[ADR 0025](../decision/0025-extract-porting-method-as-agent-skill.md)）。ATRS への適用の固有事項は [atrs-porting.md](atrs-porting.md)。
[AGENTS.md](../../AGENTS.md) はここを入口として参照する。文書全体の索引は [docs/index.md](../index.md)。

## 規約一覧

| ファイル | 対象 | 要点 |
| --- | --- | --- |
| [documentation.md](documentation.md) | すべての文書 | 日本語本文＋英語識別子、RFC 2119 用語、出典記法、リンク |
| [decision-records.md](decision-records.md) | `docs/decision/` | MADR 4.0、`NNNN-<slug>.md`、状態遷移、置換手順 |
| [atrs-porting.md](atrs-porting.md) | ATRS の移植 | スキル port-lang の適用: 言語ペア、配置、機能名、型、必須の依存、上流の版、採った値 |
| [version-control.md](version-control.md) | git | 作業の区切りごとに commit、push はしない |
| [backlog.md](backlog.md) | `docs/backlog/` | 項目形式、状態、完了の定義（DoD） |

## 優先順位

規約同士・文書同士が矛盾した場合は次の順で優先する。

1. 状態が `accepted` の ADR（[docs/decision/](../decision/)）
2. 本ディレクトリの規約（[atrs-porting.md](atrs-porting.md) を含む）
3. スキル [port-lang](../../.agents/skills/port-lang/SKILL.md)
4. 正規仕様（Lean の `Spec` と [docs/spec/](../spec/README.md) の規範節。[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）
5. [AGENTS.md](../../AGENTS.md)
6. backlog の記述

矛盾を見つけたら、作業を進める前に矛盾そのものを解消する（ADR の追加または規約の修正）。

## 規約の変更

- 規約の追加・変更は、方針の変更を伴う場合は先に ADR を作成し、その ADR から規約へリンクする。
- 誤字・表現の修正のみであれば ADR は不要。
