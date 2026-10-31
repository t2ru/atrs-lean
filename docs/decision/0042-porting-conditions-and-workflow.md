---
type: Architecture Decision Record
title: "移植が成り立つ条件をスキルに明示し、進め方の既定（評価・判断点・ゲート・敵対的レビュー・記録）を補う"
description: "スキル port-lang に、移植が成り立つ条件（適用の前提 P1〜P6、成立の条件 S1〜S5、言えること・言えないこと）を明示する。AWS の AI-Driven Modernization（AI Modernization Flow）のプロセス面を参考に、評価・人が判断する事項・検査ゲート・未着手の可視化・独立した敵対的レビュー・画面の確認・記録を、置き換えてよい既定の進め方として references/workflow.md に置く。"
tags: [adr, porting, process, skill]
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T10:30:00+09:00
sources:
  - id: aidm-blog
    resource: https://aws.amazon.com/jp/blogs/news/aidm-introducing-ai-modernization-flow/
  - id: aimf
    resource: https://github.com/aws-samples/sample-ai-modernization-flow
---

# 移植が成り立つ条件をスキルに明示し、進め方の既定（評価・判断点・ゲート・敵対的レビュー・記録）を補う

## Context and Problem Statement

プロジェクトオーナーの依頼で、本プロジェクトの移植の方式（スキル port-lang）と、AWS Japan の AI-Driven Modernization（AIDM）の中核である AI Modernization Flow（AIMF）[^aidm-blog][^aimf] を比べた。

* port-lang は、保証の強さ・差異の扱い・仕様の再利用性・版上げへの追従で勝る。
* 一方で、次の 2 点が欠けていた。
  * どの条件がそろえば「移植した」と言えるのかが、一か所に書かれていない。原則 A〜C、完了の定義、保証の限界の規則に散っている。適用の前提（どんな対象なら使えるか）と、証明から言えないことも、明示していない。
  * プロセス面。AIMF は次のものを備えるが、port-lang には無い。
    * 適用を判断する評価の段階と終了点
    * 後戻りのコストに応じた人の判断点
    * 検査ゲートによる完了の判定
    * 未対応ゼロの台帳
    * 完了宣言に対する独立したレビュー
    * 中断に耐える記録

オーナーは、移植が成り立つ条件をスキルに明確に書き、プロセス面を補うよう指示した。あわせて、スキルなので利用者の運用を過度に縛らないこと、それを敵対的レビューで確かめることも指示した。

## Decision Drivers

* 基本原則（[ADR 0033](0033-foundational-principles.md)）を弱めないこと。とくに、人や LLM の判断を一致の根拠にしないこと
* スキルは他のプロジェクトでも使う。運用の形（段階・判断点・記録の形式・道具・AI の使い方）を押し付けないこと
* 既存の仕組み（インベントリと TR-S1、完了の定義、`MachineTest` の反例）と重複させないこと
* 「移植した」という主張が、`Machine.Refines` と付帯の義務の保証を越えないこと

## Considered Options

* 成り立つ条件を SKILL.md に置き、進め方を「置き換えてよい既定」として references/workflow.md に置く
* 進め方を process.md の手順と完了の定義に義務として組み込む
* 進め方はスキルに置かず、ATRS の規約（docs/rules/）だけに置く

## Decision Outcome

Chosen option: "成り立つ条件を SKILL.md に置き、進め方を「置き換えてよい既定」として references/workflow.md に置く", because 成り立つ条件は方法の正しさに関わるので、スキルの入口で必ず読まれるべきだからである。一方、進め方はプロジェクトの体制（人だけ・AI 中心・規模）によって最適な形が異なる。義務にすると利用者を縛り、ATRS だけに置くと他のプロジェクトで再利用できない。

* SKILL.md に「移植が成り立つ条件」を置く。
  * 適用の前提 P1〜P6。境界ごとに確かめ、欠けた境界は範囲から外すか限界に載せる。部分適用を認める。
  * 成立の条件 S1〜S5。既存の原則と完了の定義をまとめ直したもので、新しい義務は足さない。
  * 言えること・言えないこと。移植元と移植先が直接に同じだとは言えない。事前条件の外と活性についても言えない。
* references/workflow.md に、次の既定を置く。成立の条件と完了の定義を満たす限り、プロジェクトの規約で置き換えてよい。
  * 評価と終了点
  * 人が判断する事項
  * 検査ゲート
  * 未着手の可視化
  * 独立した敵対的レビュー（指摘は反例・検査・限界の行に落とす）
  * 画面の確認（任意）
  * 記録と中断への備え
* process.md・verification.md から workflow.md を参照する。スキルの版を 0.4 にする。
* ATRS での当てはめは [atrs-porting.md](../rules/atrs-porting.md#進め方の適用atrs) に書く。

### Consequences

* Good, because 「移植した」と言うための条件と、その主張の範囲が、スキルの入口で分かる。
* Good, because 評価の段階で、費用に見合う範囲（例: 中核の純粋な計算だけ）に絞れる。部分適用も方法の内に位置づけられる。
* Good, because 人の判断を、証明と検査の外にある事項に集中させられる。
* Bad, because スキルの文書が増える。既定と各プロジェクトの規約の対応を、プロジェクト側で書く必要がある。

### Confirmation

* 設計の後、独立したエージェント 2 体による敵対的レビューを行った（下の「敵対的レビュー」）。観点は「運用を縛りすぎていないか」と「条件の正しさと既存の規範との整合」である。
* workflow.md の義務の語は、既存の規則の引用に限ることを確かめた。

## Pros and Cons of the Options

### 成り立つ条件を SKILL.md に、進め方を置き換えてよい既定として workflow.md に置く

* Good, because 方法の正しさ（条件）と運用（進め方）を分けられる。
* Bad, because 既定に従わないプロジェクトでは、進め方の品質がプロジェクトの規約しだいになる。

### 進め方を process.md の義務に組み込む

* Good, because どのプロジェクトでも同じ進め方になる。
* Bad, because 人だけで作業するプロジェクト・小規模なプロジェクト・別の運用を持つ組織に、合わない義務を課す。

### ATRS の規約だけに置く

* Good, because スキルが変わらない。
* Bad, because ほかの移植で再利用できない。スキルを方法の置き場とした [ADR 0025](0025-extract-porting-method-as-agent-skill.md) の趣旨に反する。

## More Information

* [ADR 0025](0025-extract-porting-method-as-agent-skill.md), [ADR 0033](0033-foundational-principles.md), [ADR 0034](0034-b-method-refinement-and-explicit-deviations.md), [ADR 0037](0037-conflict-as-spec-nondeterminism.md), [ADR 0039](0039-refinement-non-vacuity-obligations.md)
* スキル: [SKILL.md](../../.agents/skills/port-lang/SKILL.md#移植が成り立つ条件)、[workflow.md](../../.agents/skills/port-lang/references/workflow.md)

### 敵対的レビュー

（レビューの結果を記入する）

[^aidm-blog]: AWS Japan「[AI-Driven Modernization] AIエージェントに規律ある移行作業をさせる「AI Modernization Flow」を公開しました」 <https://aws.amazon.com/jp/blogs/news/aidm-introducing-ai-modernization-flow/>
[^aimf]: aws-samples/sample-ai-modernization-flow（v0.11.0） <https://github.com/aws-samples/sample-ai-modernization-flow>
