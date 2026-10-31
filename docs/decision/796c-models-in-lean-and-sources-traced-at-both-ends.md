---
type: Architecture Decision Record
title: "モデルと証明をすべて Lean に置き、移植元ソースと移植先ソースは両端で追跡する"
description: "LangSemantics・SourceModel・Spec・Abstraction・TargetModel・Refinement を Lean に置き、Java 原典と Rust ソースはそれぞれのモデルとだけ追跡でつなぐ。ADR 3e1d・dd0f を置き換える。"
tags: [adr, architecture, naming, target-model, rust]
id: "796cdc52-2288-46c9-a061-40bc68d61fa4"
status: deprecated
decision_status: superseded
superseded_by: "0bd389b9-3285-4134-9408-200fb9c0a666"
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# モデルと証明をすべて Lean に置き、移植元ソースと移植先ソースは両端で追跡する

## Context and Problem Statement

[ADR 3e1d](3e1d-language-neutral-top-level-namespaces.md) は、各言語のプロジェクトが `TargetModel` と `Refinement` を持つとした。
[ADR dd0f](dd0f-rust-as-target-language.md) は移植先を Rust とし、`TargetModel` を Rust の実行コード（`target_model`）、`Refinement` を Verus・Kani で充足するとした。
この構成では「移植先モデル」と「移植先ソース」が同一になり、移植元側との対称性がない。移植元側では、移植元ソース（Java）と移植元モデル（`SourceModel`）を区別している。
プロジェクトオーナーから、トレースは **移植元ソース ⇔ 移植元モデル** と **移植先モデル ⇔ 移植先ソース** の 2 本とし、移植元ソースと移植先ソースを直接つながないという方針が示された。あわせて `TargetModel` を Lean のモデルとして置く構成が選ばれた。

## Decision Drivers

* 移植元側と移植先側を対称な構造にすること
* 層の間の関係（抽象化・具体化）を同じ証明系（Lean）で証明すること
* ソースとモデルの対応（トレース）と、モデル間の対応（証明）を区別すること
* Lean 側に Mathlib を持ち込まないこと（[ADR 659f](659f-lean-toolchain-and-dependencies.md)）

## Considered Options

* すべてのモデルと証明を Lean に置き、ソースは両端で追跡する
* `TargetModel` を Rust 側の Verus モデル（spec 関数群）として置く
* 現行（ADR dd0f: `TargetModel` = Rust の実行コード）のまま

## Decision Outcome

Chosen option: "すべてのモデルと証明を Lean に置き、ソースは両端で追跡する", because 移植元側と移植先側が対称になり、`Spec` との関係が両側とも Lean の定理として証明できるため。

### 層の構成

```
移植元ソース  ⇔trace⇔  SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel  ⇔trace⇔  移植先ソース
(Java/SQL)             (Lean)                     (Lean)            (Lean)                  (Rust)
```

| 名前空間（Lean） | 日本語名 | 役割 |
| --- | --- | --- |
| `LangSemantics.<lang>` | 言語意味論モデル | アプリに依存しない言語・処理系の意味論。`Java`, `Sql`（移植元）、`Rust`（移植先） |
| `SourceModel` | 移植元モデル | 移植元ソースの振る舞いを `LangSemantics.Java`・`LangSemantics.Sql` の意味論で写す |
| `Spec` | 抽象モデル | 正規仕様（[ADR 61bc](61bc-lean-spec-as-normative-source.md)） |
| `Abstraction` | 抽象化証明課題 | `SourceModel` → `Spec` の定理（`ABS-NNN`） |
| `TargetModel` | 移植先モデル | 移植先ソースの振る舞いを `LangSemantics.Rust` の意味論で写す（固定長整数とオーバーフロー、`char`、UTF-8 文字列、`Result`、パニック） |
| `Refinement` | 具体化証明課題 | `Spec` → `TargetModel` の定理（`REF-NNN`） |

* 上記の 6 つ以外のトップレベル名前空間を Lean に作ってはならない（`Tests`・`Tools` と、どのモデルにも依存しない追跡属性の基盤モジュールは例外。[ADR 81ab](81ab-cross-language-traceability.md)）。
* 依存の向き:
  * `LangSemantics.<lang>` は他に依存しない。
  * `Spec` は他のどれにも依存しない。
  * `SourceModel` は `LangSemantics.Java`・`LangSemantics.Sql` と `Spec` の型に依存してよい。
  * `TargetModel` は `LangSemantics.Rust` と `Spec` の型に依存してよい。
  * `Abstraction` は `SourceModel`・`Spec` に、`Refinement` は `Spec`・`TargetModel` に依存する。
  * **`SourceModel` 側（`SourceModel`, `Abstraction`, `LangSemantics.Java/Sql`）と `TargetModel` 側（`TargetModel`, `Refinement`, `LangSemantics.Rust`）は互いに依存してはならない。**

### 移植先ソース（Rust）

* 移植先言語は Rust とする（ADR dd0f から引き継ぐ）。
* `rust/` は **ソース** であり、モデルではない。名前空間規則の対象外とし、Rust の慣習に従って業務機能ごとのモジュール（`fare`, `flight_search` …）を置く。検証のための付属物を次に置く。
  * `rust/src/model/`: Lean `TargetModel` を Verus の spec 関数として写したもの
  * `rust/src/proof/`: Verus の補題
  * `rust/kani/`: Kani のハーネス
  * `rust/tests/`: 適合テスト
* 規約は [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/docs/rust/layout.md)。

### 両端の対応の確認（対称）

| 境界 | 振る舞いの一致 | 構造の一致 |
| --- | --- | --- |
| 移植元ソース ⇔ `SourceModel` | Java オラクルで `conformance/source-model/` のベクタを確認する。版上げ時は新旧の差分オラクル（[ADR 3f36](3f36-following-upstream-releases.md)） | 追跡注釈と本文ハッシュ（[ADR 81ab](81ab-cross-language-traceability.md)） |
| `TargetModel` ⇔ 移植先ソース | Lean `TargetModel` を実行して生成した `conformance/target-model/` のベクタを Rust が通す。Verus で Rust の実行コードが `model/` の写しと一致することを証明する。Kani で有界検査する | 追跡注釈と本文ハッシュ（双方向） |

* ADR dd0f の「Verus・Kani・適合テストベクタ」は、`Spec` との関係ではなく **`TargetModel` ⇔ Rust ソースの対応の確認手段** として引き継ぐ。`Spec` → `TargetModel` は Lean で証明する。
* Verus の写しは `Spec` ではなく `TargetModel` の写しになる。写しと Lean `TargetModel` の対応は、規約（同名・同構造）・ハッシュによる陳腐化検出・`target-model/` ベクタで担保する。証明ではない。

### Consequences

* Good, because 移植元側と移植先側が対称になり、両端の役割（ソースとモデルの対応づけ）と内側の役割（モデル間の証明）が分かれる
* Good, because `Spec` → `TargetModel` が Lean の定理になり、Rust 固有の意味論（オーバーフロー等）の扱いも証明の対象になる
* Good, because 別の移植先言語を追加するときは `LangSemantics.<lang>` と、その言語向けの `TargetModel`・`Refinement` を足せばよい
* Bad, because Rust のコードを Lean `TargetModel` と Verus の写しの 2 か所で表すため、同期の手間が増える
* Bad, because Lean に `LangSemantics.Rust` を定義する工数がかかる

### Confirmation

* Lean のビルド構成で、依存の向き（特に `SourceModel` 側と `TargetModel` 側の相互非依存）を CI で検査する。
* 追跡の検査 TR-X（直接接続が無いこと。[ADR 81ab](81ab-cross-language-traceability.md)）が通ること。

## Pros and Cons of the Options

### すべて Lean に置く

* Good, because 対称で、両側の関係が同じ証明系で証明できる
* Bad, because `LangSemantics.Rust` と `TargetModel` の実装が必要

### `TargetModel` を Verus モデルにする

* Good, because Rust ソースとの距離が近い
* Bad, because `Spec`（Lean）と `TargetModel`（Verus）の関係が言語をまたぎ、証明できない

### 現行のまま

* Good, because 工数が最小
* Bad, because 移植先モデルと移植先ソースの区別が無く、要求されたトレース構造にならない

## More Information

* 本 ADR は [ADR 3e1d](3e1d-language-neutral-top-level-namespaces.md) と [ADR dd0f](dd0f-rust-as-target-language.md) を置き換える。両 ADR の名前（`SourceModel` 等）と、Rust・Verus・Kani の採用は引き継ぐ。
* Verus・Kani・Rust ツールチェーンの版は [backlog fb50](../backlog/fb50-rust-project-scaffold.md) で決め、本 ADR の More Information に追記する。Verus と Kani の併用可否の確認も同項目で行う。
* [ADR 81ab](81ab-cross-language-traceability.md), [ADR 3f36](3f36-following-upstream-releases.md)

* （補足 2026-10-30）本 ADR は [ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md) で置き換えられた（[ADR c336](c336-foundational-principles.md) の基本原則に合わせるため）。
