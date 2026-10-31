---
type: Architecture Decision Record
title: "基本原則: 両端の決定論的な一致、B メソッドのリファインメント、差異の全明示"
description: "ソース⇔モデルの一致を決定論的な検証または変換で確認し、抽象モデルと移植元/先モデルの間に B メソッドのリファインメントを証明し、不一致を証明と文書の両方ですべて明示することを、全 ADR・規約・スキルの上位の原則とする。"
tags: [adr, principles, verification, refinement, traceability]
id: "c3364914-71b0-4e9e-b193-a5b4e261583f"
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 基本原則: 両端の決定論的な一致、B メソッドのリファインメント、差異の全明示

## Context and Problem Statement

プロジェクトオーナーから、次の 3 つを基本原則として定めるよう指示があった（原文）。

> 1. 移植元プログラムと移植元モデル、移植先プログラムと移植先モデルは、決定論的な検証または変換によって一致が確認されていなければならない。また、トレーサビリティが保たれていなければならない。
> 2. 抽象モデルと移植(元/先)モデルの間には、Bメソッドでいうリファインメントの関係にあることが証明されていなければならない。
> 3. 抽象モデルと移植(元/先)モデルで一致しない点がある場合は、それを証明の中とドキュメントにおいてすべて明示されていなければならない。

既存の文書を敵対的にレビューした。その結果、上の原則と食い違う箇所が多数見つかった。主なものは次のとおり。

- 手書きの Verus の写しを「証明ではない」と明言している。
- 人の確認に頼る「確認済みハッシュ」がある。
- 「設計レビュー」で一致を確かめるとしている。
- 関数の可換性だけで関係を定義している。
- 証明課題の無い既知差異がある。
- 移植先側に差異の登録簿が無い。

原則の意味を定め、ほかの決定との優先関係を決める必要がある。

## Decision Drivers

* 原則の各語（決定論的、リファインメント、明示）に、検査できる意味を与えること
* 現実に適用できる手段が言語ごとに異なることを認めつつ、限界を隠さないこと
* 既存の ADR・規約・スキルとの優先関係を一意にすること

## Considered Options

* 3 原則を最上位の原則とし、語を定義し、言語ごとに手段と保証の限界を規定させる
* 3 原則を目標として掲げるだけにし、既存の決定はそのまま残す

## Decision Outcome

Chosen option: "3 原則を最上位の原則とし、語を定義し、言語ごとに手段と保証の限界を規定させる", because 原則が検査可能になり、既存の決定との矛盾を機械的・文書的に解消できるため。

### 用語

| 原則の語 | 本プロジェクトでの名前 |
| --- | --- |
| 移植元プログラム | 移植元ソース（Java/SQL。`upstream/atrs`） |
| 移植元モデル | Lean `SourceModel`（と移植元の `LangSemantics`） |
| 抽象モデル | Lean `Spec` |
| 移植先モデル | Lean `TargetModel`（と移植先の `LangSemantics`） |
| 移植先プログラム | 移植先ソース（Rust。`rust/`） |

### 原則 1: 両端の決定論的な一致とトレーサビリティ

* **決定論的な検証または変換** とは、機械が実行し、同じ入力に対して常に同じ判定を返す手続きをいう。該当するものは次のとおり。
  * 定理証明
  * 検証器（Verus など）による証明
  * 決定論的な生成（コード生成・変換）
  * 固定した適合テストベクタの照合
  * オラクル（原典そのものの実行）との照合
  * 有限域の全探索
  * 固定シードの性質テスト
  * 有界モデル検査（Kani など）
* 人や LLM の判断（レビュー、設計レビュー、目視の確認、判断に基づくハッシュの更新）は、一致の根拠にしてはならない。補助としてだけ使ってよい。
* 一致の確認手段は、言語ごと・役割（移植元/移植先）ごとに、スキル port-lang の言語パック `verification.md` に規定する。各手段について **保証の限界**（どの入力・どの部分を保証しないか）を併記しなければならない。
* 本プロジェクトで実際に残る限界は、[spec/assurance.md](../spec/assurance.md) に境界ごとにすべて列挙する。列挙されていない限界があってはならない。
* トレーサビリティは [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) の注釈と検査で保つ。

### 原則 2: B メソッドのリファインメント

* `Spec` を抽象機械とし、`SourceModel` と `TargetModel` を、それぞれ `Spec` を **リファインする** 具体機械とする。
* リファインメントの定義・証明義務（初期化・適用可能性・正しさ）と、Lean での表し方は [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) で定める。
* 名前空間 `Abstraction` は「`SourceModel` が `Spec` をリファインする」証明を置く。名前空間 `Refinement` は「`TargetModel` が `Spec` をリファインする」証明を置く。どちらも B メソッドの意味のリファインメントである。

### 原則 3: 差異の全明示

* `Spec` と `SourceModel` の差異は `D-NNN`、`Spec` と `TargetModel` の差異は `T-NNN` として登録する。
* `Spec` とモデルの差異は、次の 2 か所に現れなければならない。どちらか一方だけの差異があってはならない。
  * 証明: リファインメント定理の名前付きの仮定、または貼り合わせ関係の名前付きの成分。Lean の属性 `@[deviation]` を付ける。
  * 文書: [spec/abstraction.md](../spec/abstraction.md#既知差異)、[spec/refinement.md](../spec/refinement.md#既知差異t-nnn)
* `Spec` の外の規範節（[ADR 61bc](61bc-lean-spec-as-normative-source.md)）とソースの違いは、どのモデルにも現れない。したがって、抽象モデルと移植元/先モデルの不一致ではない。これを **モデル外の差異** という。例は、並行実行・セッション・Cookie である。
  * モデル外の差異も登録簿に登録する（種類「モデル外」）。
  * 確認の手段と限界を [spec/assurance.md](../spec/assurance.md) に載せる。
  * モデル外とできるのは、ADR 61bc が `Spec` の外と定める種類の仕様だけである。`Spec` で表現できる振る舞いの違いを、モデル外としてはならない。
* 詳細は [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)。

### 優先関係

* 本 ADR は、他のすべての ADR・規約（`docs/rules/`）・スキル port-lang に優先する。
* 本 ADR と矛盾する既存 ADR の決定は、次の ADR で置き換える。

| 置き換える ADR | 置き換え先 |
| --- | --- |
| [a43d](a43d-two-layer-model-java-faithful-and-abstract.md) | [01d4](01d4-b-method-refinement-and-explicit-deviations.md) |
| [796c](796c-models-in-lean-and-sources-traced-at-both-ends.md) | [0bd3](0bd3-generate-verus-mirror-from-target-model.md) |
| [81ab](81ab-cross-language-traceability.md) | [e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) |
| [41f7](41f7-concurrency-failure-as-conflict-error.md) | [e56e](e56e-conflict-as-spec-nondeterminism.md) |

* 原則の適用時期: 原則は、backlog で **完了** を宣言する作業の完了の定義に含める（[rules/backlog.md](../rules/backlog.md)）。未完了の作業が原則を満たしていないことは違反ではない。ただし、未完了であることが backlog に記録されていなければならない。

### Consequences

* Good, because 「一致した」「証明した」「差異は無い」という主張が、すべて機械的な根拠と文書の記載に結びつく
* Good, because 現実に保証できないことが、隠れずに [spec/assurance.md](../spec/assurance.md) に集まる
* Bad, because 抽象機械とリファインメントの枠組み、Verus の写しの生成器など、道具の実装が増える
* Bad, because 差異ごとに証拠の定理を書く工数が増える

### Confirmation

* 本 ADR の後に作る ADR・規約・スキルの変更は、3 原則と矛盾しないことを確かめる。確かめ方は、敵対的レビュー（原則を与えた独立のレビュー）とする。
* CI で次を確認する。
  * 証明: `sorry` 無し・新規 `axiom` 無し・`native_decide` と `bv_decide` 無し（どちらも `Lean.ofReduceBool` に依存する）
  * 追跡の検査: TR-*（TR-D を含む）
  * 言語ごとの検証器
* [spec/assurance.md](../spec/assurance.md) に無い限界が見つかったら、同文書に追記するか、手段を強めて限界をなくす。

## Pros and Cons of the Options

### 最上位の原則とし、語を定義する

* Good, because 検査可能で、既存の決定との優先関係が明確
* Bad, because 既存 ADR の置き換えと文書の改訂が多い

### 目標として掲げるだけ

* Good, because 工数が少ない
* Bad, because 「証明ではない」とする既存の決定と原則が並存し、どちらに従うかが決まらない

## More Information

* [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md), [ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md), [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md), [ADR e56e](e56e-conflict-as-spec-nondeterminism.md)
* [spec/assurance.md](../spec/assurance.md)（保証の限界）
* スキル port-lang: [SKILL.md](../../.agents/skills/port-lang/SKILL.md#原則), [verification.md](../../.agents/skills/port-lang/references/docs/verification.md), [architecture.md](../../.agents/skills/port-lang/references/docs/architecture.md#リファインメントb-メソッド)
