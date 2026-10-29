---
type: Architecture Decision Record
title: "意思決定を MADR 形式の ADR として記録する"
description: "設計判断を MADR 4.0 形式の ADR として docs/decision/NNNN-<slug>.md に記録する。"
tags: [adr, process]
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 意思決定を MADR 形式の ADR として記録する

## Context and Problem Statement

ATRS の Lean 移植では、数値意味論・二層モデル・スコープなど、後から理由を辿る必要のある判断が多数発生する。
さらに最終目標は他言語への再移植であり、将来の移植者が「なぜこの仕様なのか」を原典を読まずに理解できなければならない。
判断をどこに、どの形式で残すかを決める必要がある。

## Decision Drivers

* 判断理由と検討した代替案が後から追えること
* 人間と AI エージェントの双方が機械的に読み書きできる定型があること
* 判断の置換（supersede）を履歴を壊さずに表現できること
* 文書は日本語で書きたい（識別子は英語）

## Considered Options

* MADR 4.0 形式の ADR を `docs/decision/NNNN-<slug>.md` に置く
* Nygard 形式の簡易 ADR
* 設計書（単一の大きな文書）に判断を追記していく
* Issue トラッカーのみに残す

## Decision Outcome

Chosen option: "MADR 4.0 形式の ADR を `docs/decision/NNNN-<slug>.md` に置く", because 代替案と判断基準を定型で残せ、ファイル単位で置換関係を表現でき、リポジトリと一緒に版管理できるため。
本文は日本語、frontmatter と節見出しは MADR の英語表記とする。

### Consequences

* Good, because 判断ごとに理由・代替案・影響が一箇所にまとまる
* Good, because ファイル名の連番で判断の時系列が分かる
* Bad, because 小さな判断でも 1 ファイル必要になり、記述の手間が増える

### Confirmation

* [docs/rules/decision-records.md](../rules/decision-records.md) にテンプレートと運用規則を置く。
* レビュー時に、`docs/decision/` の全ファイルが命名規則と必須節（Context and Problem Statement / Considered Options / Decision Outcome / Consequences）を持つことを確認する。

## Pros and Cons of the Options

### MADR 4.0

* Good, because 判断基準（Decision Drivers）と各案の長所短所を残す節がある
* Good, because 広く使われており、テンプレートが安定している
* Bad, because Nygard 形式より記述量が多い

### Nygard 形式

* Good, because 短く書ける
* Bad, because 代替案の比較を残す定型がない

### 単一の設計書

* Good, because 全体を一度に読める
* Bad, because 判断の置換履歴が埋もれる。並行して編集すると衝突しやすい

### Issue トラッカーのみ

* Good, because 議論の経緯が残る
* Bad, because リポジトリ外にあり、版と結び付かない。オフラインで参照できない

## More Information

* MADR: <https://adr.github.io/madr/>
* 運用規則: [docs/rules/decision-records.md](../rules/decision-records.md)
