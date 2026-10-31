---
type: Architecture Decision Record
title: "移植が成り立つ条件をスキルに明示し、進め方の既定（評価・判断点・ゲート・敵対的レビュー・記録）を補う"
description: "スキル port-lang に、移植が成り立つ条件（適用の前提 P1〜P6、成立の条件 S1〜S6、言えること・言えないこと）を明示する。AWS の AI-Driven Modernization（AI Modernization Flow）のプロセス面を参考に、評価・判断を記録する事項・検査ゲート・未着手の可視化・独立した敵対的レビュー・画面の確認・記録を、置き換えてよい既定の進め方として references/workflow.md に置く。"
tags: [adr, porting, process, skill]
id: "0b83c75e-af18-453d-8384-f30da3c66bee"
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

* 基本原則（[ADR c336](c336-foundational-principles.md)）を弱めないこと。とくに、人や LLM の判断を一致の根拠にしないこと
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
  * 適用の前提 P1〜P6（参考）。対象ごとに確かめる評価の目安とし、欠けたときの典型的な扱いを示す。部分適用を認める。
  * 成立の条件 S1〜S6。既存の原則と完了の定義を、主張の側から並べ直したもので、新しい義務は足さない。食い違えば原則と完了の定義が優先する。
  * 言えること・言えないこと。証明が言うのはモデルについてで、ソースについては両端の手段が確かめた範囲に限る。移植元と移植先が直接に同じだとは言えない。事前条件の外、「中断」の差異の前提を破った後、活性、`Spec` の妥当性についても言えない。
* references/workflow.md に、次の既定を置く。成立の条件と完了の定義を満たす限り、プロジェクトの規約で置き換えてよい。
  * 評価と終了点
  * 判断を記録する事項（既存の規則が求めるものの再掲と、任意の既定に分ける）
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

* 草案の後、独立したエージェント 2 体による敵対的レビューを行い、反映の後に第 2 巡を行った（下の「敵対的レビュー」）。観点は「運用を縛りすぎていないか」と「条件の正しさと既存の規範との整合」である。
* workflow.md と成立の条件の節の義務の語が、既存の規則の再掲に限ることを、検索で確かめた。
* 変更した文書の相対リンクとアンカーを、スクリプトで確かめた。

## Pros and Cons of the Options

### 成り立つ条件を SKILL.md に、進め方を置き換えてよい既定として workflow.md に置く

* Good, because 方法の正しさ（条件）と運用（進め方）を分けられる。
* Bad, because 既定に従わないプロジェクトでは、進め方の品質がプロジェクトの規約しだいになる。

### 進め方を process.md の義務に組み込む

* Good, because どのプロジェクトでも同じ進め方になる。
* Bad, because 人だけで作業するプロジェクト・小規模なプロジェクト・別の運用を持つ組織に、合わない義務を課す。

### ATRS の規約だけに置く

* Good, because スキルが変わらない。
* Bad, because ほかの移植で再利用できない。スキルを方法の置き場とした [ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md) の趣旨に反する。

## More Information

* 作成時は旧番号 0042 だったが、main に [ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)・[ADR 9ac6](9ac6-vacuity-literature-necessity-and-mutation.md) が先に入ったため、旧番号 0044 に採番し直した。
* [ADR f4e1](f4e1-extract-porting-method-as-agent-skill.md), [ADR c336](c336-foundational-principles.md), [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md), [ADR e56e](e56e-conflict-as-spec-nondeterminism.md), [ADR 70eb](70eb-refinement-non-vacuity-obligations.md)
* スキル: [SKILL.md](../../.agents/skills/port-lang/SKILL.md#移植が成り立つ条件)、[workflow.md](../../.agents/skills/port-lang/references/workflow.md)

### 敵対的レビュー

草案の後、独立したエージェント 2 体による敵対的レビューを行った。観点は「運用を縛りすぎていないか」（A）と「条件の正しさと既存の規範との整合」（B）である。その反映の後、両方の観点で第 2 巡を行った。レビュー側には一次資料と観点だけを渡し、作業側の推論は渡していない。主な指摘と対応は次のとおり。

| 巡 | 観点 | 指摘 | 対応 |
| --- | --- | --- | --- |
| 1 | A | 成立の条件で「人が判断する」と定めると新しい義務になり、AI だけのプロジェクトが満たせない | 成立の条件からは、限界の文書に載せることだけを求める。判断者は workflow.md の既定とし、置き換えてよいとした |
| 1 | A | 任意の評価なのに、適用の前提が成立の必要条件として働く。P1 の「使えない」と「範囲から外す」が矛盾する | 適用の前提を「参考」に下げ、「限る」を成立の条件だけに掛けた。P1 は「その対象には適用できない」とした |
| 1 | A | 前提の手段をオラクル・差分実行に狭めている | 「verification.md の決定論的な手段（例: …）」とした |
| 1 | A | 機械で判定できない項目まで検査を求めている。「見逃しのある検査器は根拠にならない」が強すぎる | 機械で確かめられる項目に限って検査を対応させ、他は判断による確認と明示するとした。違反例で確かめていない迂回は検査器の限界とした |
| 1 | A | 範囲外を限界の文書にも載せる二重記録になる。未着手の状況の一覧が閉じている。推奨のはずの文が断定になっている | 範囲外は範囲外の一覧と意思決定記録だけにした。状況は例示にして、「規範節に記述」「限界に記載」を足した。語尾を「とよい」に揃えた |
| 1 | A | 「すべて推奨」とすると、規約上の SHOULD として、逸脱のたびに記録が要る | 「選んで使える既定（任意）」とし、置き換えの記録も「とよい」にした |
| 1 | B | ブラウザ E2E を決定論的な手段に数えると、移植元の出力を期待値にでき、直接接続の禁止を迂回できる | 両端の一致の根拠に数えないとした。移植元の出力を移植先の根拠にすることを禁じ（規則 4 の再掲）、ベクタで照合しない部分を限界に載せるとした |
| 1 | B | 「言えること」の主語がソースになっている。正常終了・`Refines.complete`・`Refines.run` が抜けている。冒頭の「同じ振る舞いのまま」と矛盾する | 主語をモデルにし、ソースは両端の手段の範囲に限った。適用可能性・`complete`・`run` を書いた。スキルの冒頭を「`Spec` が定める振る舞いのまま」に改めた |
| 1 | B | 成立の条件から、完了の定義の一部が漏れている（TR-* の失敗扱い、informative 化、`Spec` 自身の義務、依存の向き、写しの再生成、ベクタの全件） | S1〜S6 に割り当て直し、対応する規則の列を設けた |
| 1 | B | 限界の必須項目（「中断」の差異の前提を破った後の軌跡、検査器、`Machine`）が漏れている。活性の記述が不正確 | verification.md の必須項目を参照する形にし、「言えないこと」に「中断」と活性を正確に書いた |
| 1 | B | AI の自律の理由が誤っている。止まる条件に、PRE の強化・`@[nondet]`・`@[env_pre]`・`@[kernel]` が無い | 理由を「証明は核が、形と追跡は検査器が確かめる」に限った。止まる条件の例に足した |
| 2 | A・B | 「判断を記録する事項」の表に、既存の規則に無い行がある。それを置き換え不可とすると、新しい義務になる | 既存の規則が求める行（根拠の規則つき）と、任意の既定の行に表を分けた |
| 2 | A・B | S1 が、写しの再生成を無条件に求めている（規則 5 では、検証器が使える場合だけ）。S6 が、限界の文書に新しい必須項目を足している | S1 を「言語パックの決定論的な手段。検証器を使う場合は再生成も」とした。S6 の信頼の基盤は例示にした |
| 2 | B | 「`Spec` の結果と一致する」が `Refines.complete` を越えている（環境の固定、`J`・`αₒ` を通した一致、核による同一視、前提の INV・`J`・定義域） | 前提と「一致」の意味を明記した |
| 2 | B | 用語の残り（「人が判断する事項」）。`Spec` の独立の漏れ。TR-N を差異の検査としている | 直した |

第 2 巡の後の修正は、指摘の文面に沿って行い、第 3 巡は行っていない。

main に [ADR 9ac6](9ac6-vacuity-literature-necessity-and-mutation.md)（成分の必要性・仕様の変異テスト・意図から書く例）が入ったのに合わせ、次を整えた。

* 成立の条件 S2 に、W 課題の差異の必要性を加えた。
* workflow.md の判断を記録する事項に、意図から書く例と `Spec` の食い違い（既存の規則）を加え、意図から書く例・変異テストへの参照を添えた。
* 検査ゲートの例に、仕様の変異テストを加えた。

いずれも main の規範を参照・再掲するだけで、新しい義務は足していない。そのため、敵対的レビューは再び行っていない。

[^aidm-blog]: AWS Japan「[AI-Driven Modernization] AIエージェントに規律ある移行作業をさせる「AI Modernization Flow」を公開しました」 <https://aws.amazon.com/jp/blogs/news/aidm-introducing-ai-modernization-flow/>
[^aimf]: aws-samples/sample-ai-modernization-flow（v0.11.0） <https://github.com/aws-samples/sample-ai-modernization-flow>
