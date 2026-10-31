---
type: Architecture Decision Record
title: "モデルと証明を Lean に置き、移植先の Verus の写しは TargetModel から決定論的に生成する"
description: "ADR 796c の層構成・依存の向き・Rust の構成を引き継ぎ、Rust の model/ を Lean TargetModel から道具で生成して手書きを禁じ、Verus で Rust の実行コードとの一致を証明する。リファインメントの枠組み Machine を名前空間の例外に加える。ADR 796c を置き換える。"
tags: [adr, architecture, naming, target-model, rust, verus]
id: "0bd389b9-3285-4134-9408-200fb9c0a666"
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# モデルと証明を Lean に置き、移植先の Verus の写しは TargetModel から決定論的に生成する

## Context and Problem Statement

[ADR 796c](796c-models-in-lean-and-sources-traced-at-both-ends.md) は、モデルと証明をすべて Lean に置き、移植元ソースと移植先ソースを両端で追跡すると決めた。
Rust 側では、Lean `TargetModel` の Verus 写し `rust/src/model/` を **手書き** し、Verus で実行コードとの一致を証明するとした。ただし、写しと Lean の一致は「規約・ハッシュ・ベクタで担保し、証明ではない」とされていた。
[ADR c336](c336-foundational-principles.md) の原則 1 は、移植先プログラムと移植先モデルの一致を、決定論的な検証または変換で確認することを求める。手書きの写しは、この連鎖の切れ目になる。
あわせて、リファインメントの枠組み（[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)）を置く名前空間が、既存の規則には無い。

## Decision Drivers

* Rust の実行コードから Lean `TargetModel` までを、決定論的な手段だけでつなぐこと
* Lean に Mathlib を持ち込まないこと（[ADR 659f](659f-lean-toolchain-and-dependencies.md)）
* 移植元側と移植先側を対称な構造に保つこと

## Considered Options

* Lean `TargetModel` から Verus の写しを生成し、Verus で Rust ⇔ 写しを証明する
* Rust から Lean `TargetModel` を Charon/Aeneas で生成する
* Lean `TargetModel` から Rust の業務コードを生成する
* 写しを手書きのままにする（ADR 796c）

## Decision Outcome

Chosen option: "Lean `TargetModel` から Verus の写しを生成し、Verus で Rust ⇔ 写しを証明する", because 次の 2 つの手順だけで、Lean と Rust の連鎖が全入力についてつながるため。また、Mathlib を必要としない。
- `TargetModel` → 写し: 決定論的な変換
- 写し → Rust の実行コード: Verus による証明

### 層の構成（ADR 796c から引き継ぐ）

```
移植元ソース  ⇔trace⇔  SourceModel ─Abstraction→ Spec ←Refinement─ TargetModel  ⇔trace⇔  移植先ソース
(Java/SQL)             (Lean)                     (Lean)            (Lean)                  (Rust)
```

| 名前空間（Lean） | 日本語名 | 役割 |
| --- | --- | --- |
| `LangSemantics.<lang>` | 言語意味論モデル | アプリに依存しない言語・処理系の意味論。`Java`, `Sql`（移植元）、`Rust`（移植先） |
| `SourceModel` | 移植元モデル | 移植元ソースの振る舞いを、`LangSemantics.Java`・`LangSemantics.Sql` の意味論で写す |
| `Spec` | 抽象モデル | 正規仕様（[ADR 61bc](61bc-lean-spec-as-normative-source.md)）。抽象機械として与える（[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)） |
| `Abstraction` | 抽象化証明課題 | `SourceModel` が `Spec` をリファインする定理（`ABS-NNN`） |
| `TargetModel` | 移植先モデル | 移植先ソースの振る舞いを、`LangSemantics.Rust` の意味論で写す |
| `Refinement` | 具体化証明課題 | `TargetModel` が `Spec` をリファインする定理（`REF-NNN`） |

* 上記の 6 つ以外のトップレベル名前空間を、Lean に作ってはならない。例外は次の 4 つである。
  * `Machine`: 抽象機械とリファインメントの枠組み。アプリに依存しない
  * `Trace`: 追跡属性の基盤
  * `Tests`, `Tools`: 実行ファイル
* 依存の向き:
  * `Machine` と `Trace` は、ほかの層に依存しない。
  * `LangSemantics.<lang>` は、同じ `<lang>` と `Trace` にだけ依存する。
  * `Spec` は、`Machine` と `Trace` 以外に依存しない。
  * `SourceModel` は、`LangSemantics.Java`・`LangSemantics.Sql`・`Spec` の型・`Machine` に依存してよい。
  * `TargetModel` は、`LangSemantics.Rust`・`LangSemantics.Sql`（DB アダプタの写しのため）・`Spec` の型・`Machine` に依存してよい。
  * `Abstraction` は `SourceModel`・`Spec`・`Machine` に依存する。`Refinement` は `Spec`・`TargetModel`・`Machine` に依存する。
  * **`SourceModel` 側（`SourceModel`, `Abstraction`）と `TargetModel` 側（`TargetModel`, `Refinement`）は、互いに依存してはならない。** `LangSemantics.<lang>` はアプリに依存しない言語の意味論なので、その言語を使う側から使ってよい。ATRS では、`Java` は移植元側、`Rust` は移植先側、`Sql` は両側で使う。

### 移植先ソース（Rust）

* 移植先言語は Rust とする。
* `rust/` は **ソース** であり、モデルではない。名前空間の規則の対象外とし、Rust の慣習に従う。
* `rust/src/model/`: Lean `TargetModel` から `lake exe gen-verus` で **生成** した、Verus の spec 関数と型。
  * 手で編集してはならない。
  * 生成物はコミットする。CI で再生成し、差分が無いことを確認する。
  * 生成器は `lean/Tools/` に置く（[backlog d77c](../backlog/d77c-verus-mirror-generator.md)）。
  * 生成器の入力は、`TargetModel` のうち `TargetModel.Adapter.*` を除いた公開定義である。生成器が受け付けるのは、書き方の部分集合だけである。部分集合は [port-lang/lean/rules.md](../../.agents/skills/port-lang/references/lean/rules.md#書き方) に一覧する。入力に部分集合の外の定義があれば、生成器は失敗しなければならない。
  * 生成器は、各操作の事前条件を写した `pre_<操作>` の spec 関数も出力する。各 `@[target]` の実行関数は、`requires pre_<操作>(..)` と `ensures r == model::<操作>(..)` を、ちょうどこの形で持たなければならない。この形は CI で検査する（`gen-verus --check-contracts`）。
  * `LangSemantics.Rust` の各演算の Verus 版は、スキル port-lang の assets（`assets/verus/model_prelude.rs`）に置き、`rust/src/model_prelude.rs` に写す。各定義に `/// trace: models LangSemantics.Rust.… @<Merkle>` を付ける。対応の正しさは信頼の基盤であり、[spec/assurance.md](../spec/assurance.md) に載せる。
* `rust/src/proof/`: Verus の補題。
* 業務機能: 純粋な部分と **インメモリのアダプタの状態遷移** は `verus!` の中に置く。`ensures` で `model/` との一致を述べ、Verus で全入力について証明する。インメモリのアダプタの状態を `Mutex` で包む薄い層は、`verus!` の外（`#[verifier::external]`）に置く。
* DB・ファイル・時計・HTTP のアダプタは、`#[verifier::external]` とする。DB・ファイル・時計の振る舞いは `TargetModel.Adapter.*` に写す（DB は `LangSemantics.Sql` の式で写す）。`Refinement` で、それがポートの契約をリファインすることを証明する（REF-009）。HTTP のアダプタは `TargetModel.Http` に写し、REF-007 で扱う。Rust のアダプタと `TargetModel.Adapter.*` の一致は、次の 2 つで確認する。
  * SQL の差分実行（SRC-010）
  * 固定フィクスチャの結合テスト
* `#[verifier::external]` を付けてよいのは、上の 2 種類（Mutex の層と、DB・ファイル・時計・HTTP のアダプタ）だけである。その一覧を [spec/assurance.md](../spec/assurance.md) に載せる。`assume`・`admit`・`external_body`・`assume_specification`・`external_fn_specification` は、使ってはならない。vstd は信頼の基盤とする。
* `rust/kani/`: Kani のハーネス。`verus!` の外のコード（変換・JSON・HTTP の接続）を、有界に検査する。
* `rust/tests/`: 適合テストと、DB・ファイル・HTTP のアダプタの結合テスト（固定フィクスチャ）。
* 規約は [port-lang/rust/layout.md](../../.agents/skills/port-lang/references/rust/layout.md) に従う。

### 両端の一致の確認（決定論的な手段と限界）

| 境界 | 決定論的な手段 | 限界（[spec/assurance.md](../spec/assurance.md) に列挙） |
| --- | --- | --- |
| 移植元ソース ⇔ `SourceModel` | 次の 2 つを照合する。<br>- Java/SQL のオラクルの結果と `conformance/source-model/` のベクタ<br>- PostgreSQL での SQL の実行結果と `LangSemantics.Sql` の評価結果（同じデータで）<br>版上げ時は、新旧の差分オラクルを使う（[ADR 3f36](3f36-following-upstream-releases.md)） | ベクタの入力の外は保証しない。ハーネス化できない部分は保証しない |
| `TargetModel` ⇔ 移植先ソース | 次の 4 つで確認する。<br>- `TargetModel` から写しを生成する（変換）<br>- Verus で、実行コードと写しの一致を全入力について証明する<br>- `conformance/target-model/` のベクタを通す<br>- Kani で有界に検査する | 次の 3 つは保証しない。<br>- `verus!` の外のコード: 有界な範囲とベクタの入力に限る<br>- DB・ファイル・時計・HTTP のアダプタ: SQL の差分実行と結合テストの入力に限る<br>- 生成器・`model_prelude.rs` の対応表・vstd・Rust 標準の `Mutex`: 信頼する |

* 構造の一致（追跡）は [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) で保つ。

### Consequences

* Good, because 実行コードから `TargetModel` までの連鎖のうち、`verus!` の中の部分が全入力について機械的に確かめられる
* Good, because 写しの同期の手間が、生成で無くなる
* Good, because 別の移植先言語でも、同じ型の生成器を用意すれば同じ連鎖を作れる
* Bad, because 生成器と、`TargetModel` の書き方の制約（部分集合）が必要になる
* Bad, because 生成器と `model_prelude.rs` の対応表の正しさは、信頼の基盤に残る

### Confirmation

* Lean のビルド構成で、依存の向きを CI で検査する。
* CI で `lake exe gen-verus` を実行し、`rust/src/model/` に差分が無いことを確認する。
* CI で Verus を実行する。`assume`・`admit`・`external_body`・`assume_specification`・`external_fn_specification` を数えて 0 であることを確認する。`#[verifier::external]` の一覧が [spec/assurance.md](../spec/assurance.md) の一覧と一致することを確認する。
* 追跡の検査 TR-X・TR-T1・TR-T2 を CI で実行する。

## Pros and Cons of the Options

### Lean → Verus の生成

* Good, because 決定論的で、Mathlib が不要
* Bad, because 生成器の実装が必要

### Rust → Lean（Aeneas）

* Good, because 手書きの `TargetModel` も Verus も不要になる
* Bad, because Aeneas の Lean ライブラリが Mathlib に依存し、[ADR 659f](659f-lean-toolchain-and-dependencies.md) を改める必要がある
* Bad, because `LangSemantics.Rust` が Aeneas の標準ライブラリに置き換わる

### Lean → Rust の生成

* Good, because Rust の業務コードが生成物になり、一致が自明になる
* Bad, because 移植先のコードが手書きの Rust でなくなり、慣習的な Rust から離れる

### 手書きのまま

* Good, because 工数が最小
* Bad, because 写しと Lean の一致が決定論的に確かめられず、原則 1 を満たさない

## More Information

* 本 ADR は [ADR 796c](796c-models-in-lean-and-sources-traced-at-both-ends.md) を置き換える。ADR 796c が置き換えた [ADR 3e1d](3e1d-language-neutral-top-level-namespaces.md) と [ADR dd0f](dd0f-rust-as-target-language.md) から、名前と Rust・Verus・Kani の採用を引き続き引き継ぐ。
* Verus・Kani・Rust ツールチェーンの版は、[backlog fb50](../backlog/fb50-rust-project-scaffold.md) で決めて追記する。
* [ADR c336](c336-foundational-principles.md), [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md), [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md), [ADR 3f36](3f36-following-upstream-releases.md)
