---
type: Architecture Decision Record
title: "ギャップの証明の状態を Lean の型で表し、公理・sorry を使わずに裏付けの宣言で示す"
description: "ギャップ（リファインメントの証明の中で証明できない部分）を axiom・sorry で仮定せず、登録簿 Trace.Gap に証明の状態 Evidence（偽を証明済み・被覆・未証明・形式化していない・PRE の外）を持たせ、状態を裏付ける宣言（否定の定理・被覆の定理・opaque の主張・前提の述語）に @[gap] を付けて obligation-check で照合する。"
tags: [adr, lean, traceability, refinement, gap]
id: "6ab4b6f1-debc-4dff-b6c5-47cc4c26ca82"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:00:00+09:00
---

# ギャップの証明の状態を Lean の型で表し、公理・sorry を使わずに裏付けの宣言で示す

## Context and Problem Statement

[ADR cc24](cc24-gap-registry-as-lean-attributes.md) で、ギャップの情報（種類・箇所・説明）を Lean の登録簿 `@[gap_entry]` に置いた。
しかし、ギャップが「リファインメントの証明の中で証明できない部分」であることは、Lean の対象として示していなかった。
プロジェクトオーナーは、これを `axiom` や `sorry` で表し、`@[gap]` を付けることを検討するよう求めた。

検討の結果は次のとおりである。

* ギャップが実在するなら、差異を外したリファインメントは偽である。食い違う具体的な入力は計算で確かめられるので、偽であることは原理的に証明できる（例: `need_D027 : ¬ Refines …`）。
  * これを `axiom` で仮定すると、Lean の論理が矛盾する。
  * `sorry` も同じ命題を仮定するので、同じ問題を持つ。CI の `axiom-check`・`check_lean.py` にも反する。
* 一方、真偽のどちらも示せない状態は実際にある。
  * 未証明: 前提で制限して証明したが、差異の有無をまだ確かめていない（当初の D-001 が該当した）
  * 形式化していない: モデル外の差異（D-013 など）と、命題をまだ書けない未確定の差異（D-028）
  * 被覆: 必要性を被覆で代えたので、偽の証明が無い
* 「真偽どちらも示せない」は「偽が必ず証明できる」と両立しない。前者は、差異が実在しないか、実在するかが分からない場合に限られる。

## Decision Drivers

* 公理・`sorry` を足さない（論理の健全性と、既存の CI の規則）
* ギャップごとに、なぜ証明できないかを機械で検査できる形にする
* 状態の移り変わり（未証明 → 偽を証明済み、未確定 → 命題に書き直す）を表せる
* 未実装の機能の差異も、段階導入で登録できる

## Considered Options

* `axiom` で差異を外したリファインメントを仮定し、`@[gap]` を付ける
* `sorry` で同じ命題を置き、`@[gap]` を付ける
* 証明の状態を型 `Evidence` で表し、裏付けの宣言に `@[gap]` を付ける（採択）
  * 部分案: 状態は「偽を証明済み・形式化していない」の 2 つだけにする

## Decision Outcome

採択: 証明の状態を型で表す案を、5 つの状態すべてで採る（プロジェクトオーナーの選択）。

### 型と欄

`Trace.Gap`（スキルの `assets/lean/Trace/Gap.lean`）を次のように改める。

* `evidence : Evidence` を足す。
  * `.refuted [thm, …]`: 偽を証明済み。差異を外した R 課題の否定の定理
  * `.covered M [thm, …]`: 被覆。必要な差異の述語 `M` がこの差異を覆う定理（`Machine.Adequacy.Covers M d`）
  * `.pending 理由 (some W)`: 未証明。制限して証明したが、偽も真もまだ示していない
  * `.unformalized claim 作業`: 形式化していない。証明も公理も持たない `opaque claim : Prop`
  * `.excludedBy [pre, …]`: 差異ではない。`Spec` の PRE・INV の外（前提の述語）
* `deviations : List Name` を足す。その ID の `@[deviation]` の定数をすべて挙げる（R 課題ごとに定数を分けてよい）。
* 名前は ``` ``名前`` ``` で書く。存在しない名前は、エラボレートの時点で誤りになる。
* `wTask` を削る。W 課題は、裏付けの定理の `@[obligation]` から引く（`pending` は予定を状態に書く）。
* `resolution` を削る。未確定の確定させる作業は、状態に書く。
* 種類と状態の組み合わせを、`@[gap_entry]` を付けた時点で検査する。

| 種類 | 許す状態 |
| --- | --- |
| 前提型・観測型 | `refuted`・`covered`・`pending` |
| モデル外 | `unformalized` |
| 未確定 | `unformalized`・`pending` |
| PRE の外 | `excludedBy` |

### 検査

* obligation-check の GK
  * `refuted`: 定理が、どれかの R 課題について `deviations` のどれかの必要性の定理（G9 の形）である
  * `covered`: 定理の型が `Covers M d` で、被覆の連鎖が循環せずに `refuted` の差異に着く
  * `pending`: 必要性の定理が無い（あれば `refuted` にする）
  * `unformalized`: 主張が `opaque` の `Prop` で、どの定数からも参照されない
  * 裏付けの宣言は `@[gap "<ID>"]` を持つ。証明の層（`Abstraction`・`Refinement`）に置いてよい
  * `@[deviation]` の定数は、宣言の `deviations` に挙がっている
* `pending` の差異の G9 の誤りは、警告（`warnings`）に下げる。
* `trace check` の TR-K は、`pending` を段階導入の指摘にする（登録の backlog がすべて完了したら誤り）。
* 生成する表に「証明の状態」の列を足す。

### ATRS への適用

| 状態 | ギャップ |
| --- | --- |
| `refuted` | D-001（`need_D001`）・D-002（`need_D002`）・D-012（`need_D012`）・D-027（`need_D027`） |
| `pending`（Lean に述語がまだ無い） | D-006〜D-009・D-011・D-014・D-017〜D-022・D-026 |
| `unformalized` | D-013・D-016・D-023・D-024・D-025（モデル外）、D-028（未確定） |
| `excludedBy` | D-003（MD-7）・D-004（MD-4）・D-005（MD-5）・D-010（前提の述語はまだ無い）・D-015（MD-1〜3）・D-029（MD-8）・D-030（値域） |

* D-005 の前提 MD-5 に、`@[gap "D-005"]` を足した。

### Consequences

* Good: 公理・`sorry` を足さずに、ギャップごとの「証明できない理由」を Lean の宣言と照合できる。
* Good: 差異の述語・定理を名前で持つので、名前の誤りはエラボレートで、型の誤りは obligation-check で見つかる。
* Good: 未証明・未確定の状態が表に出るので、確定させる作業が見える。
* Neutral: `opaque` の主張は、Lean の中では何も主張しない。主張の中身は docstring にあり、保証の限界の文書と同じく人が読む。
* Bad: 未実装の機能の差異が多いうちは、`pending` の警告が多い。

### Confirmation

* スキルの `TraceTest` に、状態ごとの正例と違反例を足した。違反例は次のとおり。
  * 種類と状態が合わない
  * 否定の定理が別の差異のものである
  * 裏付けの宣言に `@[gap]` が無い
  * 被覆が循環する
  * 主張が `opaque` でない
  * 主張を定理が参照する
  * `deviations` に挙がらない `@[deviation]`
* ATRS で obligation-check の誤り・警告が 0、axiom-check が通る。
* `tools/ci/lean.sh` が全段通る。

## More Information

* [ADR cc24](cc24-gap-registry-as-lean-attributes.md)・[スキルの ADR 7fe4](../../.agents/skills/spec-pivot/references/docs/decision/7fe4-move-trace-attributes-to-skill.md) の続きである。
* 必要性と被覆は [ADR 9ac6](9ac6-vacuity-literature-necessity-and-mutation.md)、空虚化を防ぐ義務は [ADR 70eb](70eb-refinement-non-vacuity-obligations.md) による。
* 書き方は、スキルの `references/lean/trace-attributes.md#証明の状態evidence` にある。
* 作業項目: [backlog c27d](../backlog/c27d-gap-evidence-states.md)
