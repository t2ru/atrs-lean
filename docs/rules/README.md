---
type: Guideline
title: "作業規約（rules）"
description: "作業規約の索引と、規約・文書間の優先順位。"
tags: [rules, index]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# 作業規約（rules）

本ディレクトリはこのリポジトリで作業する **人間・AI エージェントの双方** が従う規約である。
[AGENTS.md](../../AGENTS.md) はここを入口として参照する。文書全体の索引は [docs/index.md](../index.md)。

## 規約一覧

| ファイル | 対象 | 要点 |
| --- | --- | --- |
| [documentation.md](documentation.md) | すべての文書 | 日本語本文＋英語識別子、RFC 2119 用語、出典記法、リンク |
| [decision-records.md](decision-records.md) | `docs/decision/` | MADR 4.0、`NNNN-<slug>.md`、状態遷移、置換手順 |
| [spec-writing.md](spec-writing.md) | `docs/spec/` | 定義の型、二層モデル併記、事例、既知差異 |
| [porting.md](porting.md) | 移植作業全般 | Java → spec → Lean の順序、差異の扱い |
| [portability.md](portability.md) | spec と抽象モデル | 他言語へ写せるための制約 |
| [lean.md](lean.md) | Lean コード・証明 | 全域関数、型の選択、モジュール構成、証明方針 |
| [rust.md](rust.md) | Rust・Verus・Kani | クレート構成、Spec の写し方、検証、禁止事項 |
| [version-control.md](version-control.md) | git | 作業の区切りごとに commit、push はしない |
| [testing.md](testing.md) | テスト | 適合テストベクタ、性質テスト、Java オラクル |
| [backlog.md](backlog.md) | `docs/backlog/` | 項目形式、状態、完了の定義（DoD） |

## 優先順位

規約同士・文書同士が矛盾した場合は次の順で優先する。

1. 状態が `accepted` の ADR（[docs/decision/](../decision/)）
2. 本ディレクトリの規約
3. 正規仕様（Lean の `Spec` と [docs/spec/](../spec/README.md) の規範節。[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）
4. [AGENTS.md](../../AGENTS.md)
5. backlog の記述

矛盾を見つけたら、作業を進める前に矛盾そのものを解消する（ADR の追加または規約の修正）。

## 規約の変更

- 規約の追加・変更は、方針の変更を伴う場合は先に ADR を作成し、その ADR から規約へリンクする。
- 誤字・表現の修正のみであれば ADR は不要。
