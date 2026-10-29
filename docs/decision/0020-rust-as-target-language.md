---
type: Architecture Decision Record
title: "移植先言語を Rust とし、具体化証明課題を Verus と Kani で充足する"
description: "TargetModel と Refinement を Rust で実装し、Verus で Spec の写しとの一致を証明、Kani で有界検査、適合テストベクタで Lean Spec との対応を裏付ける。"
tags: [adr, rust, target-model, refinement, verus, kani]
status: deprecated
decision_status: superseded
superseded_by: "0022"
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
sources:
  - id: verus
    resource: https://github.com/verus-lang/verus
    title: Verus
  - id: kani
    resource: https://github.com/model-checking/kani
    title: Kani Rust Verifier
---

# 移植先言語を Rust とし、具体化証明課題を Verus と Kani で充足する

## Context and Problem Statement

[ADR 0018](0018-language-neutral-top-level-namespaces.md) では、各言語のプロジェクトが `TargetModel`（移植先モデル）と `Refinement`（具体化証明課題）を持つと決め、Lean も移植先の一つとしていた。
プロジェクトオーナーから **移植先言語を Rust に定める** 指示があった。
あわせて、`Refinement` をどの手段で充足するかを決める必要がある。候補として、Aeneas で Rust を Lean に変換して証明する方法、適合テストと性質テストのみとする方法、Rust 内で Verus と Kani を使って検証する方法を比較し、オーナーは Verus と Kani を選んだ。

## Decision Drivers

* 移植先を 1 言語に絞り、実装と検証の工数を集中すること
* `Refinement` を可能な限り「証明」として充足すること
* Lean 側の依存方針（Mathlib 不使用、[ADR 0014](0014-lean-toolchain-and-dependencies.md)）を崩さないこと
* Lean の `Spec`（正規仕様、[ADR 0021](0021-lean-spec-as-normative-source.md)）と Rust 側の検証の対応を、機械的に確認できること

## Considered Options

* Rust + Verus（演繹的検証）+ Kani（有界モデル検査）+ 適合テストベクタ
* Rust + Aeneas（Rust を Lean に変換し、Lean で証明）+ 適合テストベクタ
* Rust + 適合テストベクタ + proptest（証明しない）

## Decision Outcome

Chosen option: "Rust + Verus + Kani + 適合テストベクタ", because Rust 側で完結して検証でき、Lean 側に Mathlib を持ち込まずに済むため。

### 配置

* Lean プロジェクト（`lean/`）は `LangSemantics`, `SourceModel`, `Spec`, `Abstraction` を持ち、**`TargetModel` と `Refinement` を持たない**。Lean の役割は、正規仕様の形式化と、移植元からの抽象化の証明である。
* Rust プロジェクト（`rust/`）は `spec`, `target_model`, `refinement` の 3 つのトップレベルモジュールを持つ（[ADR 0018](0018-language-neutral-top-level-namespaces.md) の名前を Rust の慣習の snake_case に写したもの）。
  * `spec`: Lean `Spec` を **Verus の spec 関数として写したもの**。数学的整数（`int`, `nat`）で書き、実行コードを持たない。
  * `target_model`: 実行コード。純粋なコア（運賃・照会・検証・状態遷移）は `verus!` の中に置き、各関数の `ensures` で `spec` の対応する関数との一致を述べる。アダプタ（永続化・HTTP・ファイル・時計）は `#[verifier::external]` として Verus の対象外に置く。
  * `refinement`: `ensures` の証明に使う補題（proof 関数）、Kani のハーネス（`#[cfg(kani)]`）、適合テストベクタの実行器。
* Rust の具体的な規約は [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)。

### 充足方法

| 手段 | 何を保証するか | 対象 |
| --- | --- | --- |
| Verus | 全入力について `target_model` の関数が `spec` の写しと一致し、算術がオーバーフローしない | 純粋なコア、インメモリ状態に対する状態遷移（REF-002, REF-004, REF-007） |
| Kani | 有界な入力で、パニック・オーバーフロー・未定義動作が無く、アダプタが契約を満たす | `verus!` の外のコード、アダプタ（REF-005）、JSON の往復 |
| 適合テストベクタ | Lean `Spec` を実行して得た期待値と `target_model` の結果が一致する | 全操作（REF-001）。これにより Verus の写しの誤りも検出する |
| 結合テスト・設計レビュー | 原子性・直列化可能性、HTTP 契約 | DB アダプタ（REF-003）、HTTP（REF-006） |

**信頼の連鎖**: Lean `Spec` →（適合テストベクタ）→ Rust の実行コード →（Verus の証明）→ Verus の写し `spec`。
写しの誤りは「写しと一致する実装」がベクタで Lean `Spec` と食い違うことで検出される。加えて、写しは Lean `Spec` と **1 定義ずつ同じ名前・同じ構造** で書くことを規約とし、レビューで照合する（[port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)）。

### ツールチェーン

* Rust のツールチェーンは `rust/rust-toolchain.toml` で固定する。版は Verus のリリースが要求する版に合わせる。
* Verus と Kani の版を固定する。版は [backlog 0018](../backlog/0018-rust-project-scaffold.md) で決め、本 ADR の More Information に追記する。
* Verus の `verus!` で書いたコードに対して Kani を実行できるかどうかは未確認である。backlog 0018 の最初に検証し、併用できなければ Kani の対象を `verus!` の外のコードに限定する。

### Consequences

* Good, because Lean は形式化と抽象化証明に専念でき、Mathlib を持ち込まない
* Good, because Rust の `char` が Unicode スカラ値であるため、文字列長の規則（[ADR 0010](0010-text-length-and-character-classes.md)）を自然に満たせる
* Bad, because Lean `Spec` と Verus の写しという、2 つの形式的な仕様を同期させる必要がある
* Bad, because Verus が要求する Rust の部分集合と版に縛られる（trait object・一部の標準ライブラリの扱いなど）
* Bad, because Verus と Kani の併用に技術的な不確実性がある

### Confirmation

* CI で `verus` による検証、`cargo kani`、`cargo test`（適合テストベクタ）がすべて成功すること。
* `rust/src/spec/` の各定義に、対応する Lean `Spec` の定義名が注記されていること（レビュー）。

## Pros and Cons of the Options

### Verus + Kani + ベクタ

* Good, because Rust 内で証明と有界検査の両方ができる
* Bad, because 仕様が Lean と Verus に二重化する

### Aeneas

* Good, because Lean の `Spec` に対して直接証明でき、仕様が二重化しない
* Bad, because Aeneas の Lean ライブラリが Mathlib に依存し、[ADR 0014](0014-lean-toolchain-and-dependencies.md) と衝突する。変換できる Rust の部分集合にも制約がある

### ベクタ + proptest

* Good, because 最も軽い
* Bad, because `Refinement` が証明ではなく検証に留まる

## More Information

* **本 ADR は [ADR 0022](0022-models-in-lean-and-sources-traced-at-both-ends.md) に置き換えられた**。Rust を移植先とすることと Verus・Kani の採用は引き継ぎ、`TargetModel` を Lean のモデル、Rust を移植先ソースとする構成に改めた。Verus・Kani は `TargetModel` ⇔ Rust ソースの対応の確認手段になった。

* [ADR 0018](0018-language-neutral-top-level-namespaces.md) の配置の記述を本 ADR で更新する（名前空間の規則そのものは変えない）。
* [spec/refinement.md](../spec/refinement.md), [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md)
* [backlog 0015](../backlog/0015-second-language-portability-pilot.md) は Rust 移植そのものに置き換わるため取りやめる。
