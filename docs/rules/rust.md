---
type: Guideline
title: "Rust 規約"
description: "Rust プロジェクトの構成、Lean Spec を Verus に写す規則、target_model の書き方、Verus・Kani・適合テストによる検証の規約。"
tags: [rules, rust, verus, kani]
status: draft
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# Rust 規約

移植先は Rust であり、具体化証明課題 `Refinement` を Verus と Kani と適合テストベクタで充足する（[ADR 0020](../decision/0020-rust-as-target-language.md)）。
名前空間の規則は [ADR 0018](../decision/0018-language-neutral-top-level-namespaces.md) に従う。

本規約は `status: draft` である。Verus と Kani の併用可否（[backlog 0018](../backlog/0018-rust-project-scaffold.md)）の結果で見直す。

## 構成

```
rust/
  rust-toolchain.toml      Verus のリリースが要求する版に固定
  Cargo.toml               パッケージ atrs（単一クレート）
  src/
    lib.rs                 spec / target_model / refinement だけを公開
    spec/                  Lean Spec の Verus 写し（spec fn のみ）
    target_model/
      core/                純粋なコア。verus! の中に置き、ensures で spec を参照する
      adapter/             ポートの実装（インメモリ、DB、ファイル、時計、HTTP）。#[verifier::external]
    refinement/
      lemmas/              ensures の証明に使う proof fn
      kani/                Kani ハーネス（#[cfg(kani)]）
      conformance/         適合テストベクタの実行器（cargo test）
```

- トップレベルモジュールは `spec`, `target_model`, `refinement` だけとする。パッケージ名 `atrs` はクレートの名前であり、名前空間の規則の対象外とする。
- 下位モジュールは Lean と同じ機能名を snake_case で使う（Lean `Spec.Fare` ↔ `spec::fare` ↔ `target_model::core::fare` ↔ `refinement::lemmas::fare`）。
- 依存の向き: `spec` は他に依存しない。`target_model::core` は `spec` に、`target_model::adapter` は `target_model::core` に依存してよい。`refinement` はすべてに依存してよい。`spec` と `target_model` は `refinement` に依存してはならない（`refinement::lemmas` の proof fn を `target_model::core` の証明から呼ぶことだけは許す）。

## spec: Lean Spec の写し

- Lean `Spec` の公開定義 1 つにつき、Verus の `spec fn`（または `struct`・`enum`）を 1 つ書く。名前は Lean の名前の snake_case とし、doc コメントに Lean の完全名を書く（`/// Lean: Spec.Fare.basicFare`）。
- 構造（場合分け・再帰・評価順）を Lean と同じに保つ。最適化や書き換えをしてはならない。
- 数値は数学的整数 `int` / `nat` を使う。`floorDiv`・`ceilTo` などは Lean `Spec.Prim` と同じ名前の `spec fn` として定義する。
- 文字列は `Seq<char>`（Unicode スカラ値の列）として扱う。
- `spec` に実行コード（`fn`, `exec`）を置いてはならない。
- Lean `Spec` を変更したら、同じ変更（同じコミット）で `spec` も直す。

## target_model

### core（Verus で検証する）

- 各公開関数の `ensures` に、対応する `spec` の関数との一致を書く（例: `ensures r as int == spec::fare::fare(basic as int, rate as int)`）。
- 数値型は値域（[domain-model.md](../spec/domain-model.md#値域)）を収められる固定長整数（原則 `u64` / `i64`）を使い、`requires` で値域を前提とする。オーバーフローが無いことは Verus の算術検査で示す。
- `unsafe`、浮動小数点型（`f32`, `f64`）、`unwrap`・`expect`・添字アクセスによるパニックの可能性、`std::time` などの暗黙の副作用を使ってはならない。
- 「今日」・マスタ・設定は引数で受け取る（[ADR 0007](../decision/0007-functional-core-with-ports.md)）。
- 状態遷移（予約確定など）は、インメモリの状態を引数と戻り値で受け渡す純粋関数として書き、`ensures` で `spec` の状態遷移と一致することを述べる。

### adapter（Verus の対象外）

- ポート（[ports.md](../spec/ports.md)）の実装を置く。`#[verifier::external]` とし、Kani と結合テストで検査する。
- `unsafe` を使ってはならない。パニックしうる箇所は Kani のハーネスで到達不能を示すか、`Result` で返す。
- HTTP フレームワーク・DB ドライバの選択は、採用時に ADR を作る。

## refinement

| 手段 | 置き場所 | 対象とする課題（[refinement.md](../spec/refinement.md)） |
| --- | --- | --- |
| Verus の証明 | `target_model::core` の `ensures` と `refinement::lemmas` | REF-002, REF-004, REF-007 |
| Kani のハーネス | `refinement::kani` | REF-004（`verus!` の外のコード）, REF-005, JSON の往復 |
| 適合テストベクタ | `refinement::conformance` | REF-001（全操作） |
| 結合テスト | `rust/tests/` | REF-003, REF-005（DB アダプタ）, REF-006 |

- Verus の `assume`・`admit`・`#[verifier::external_body]` を `target_model::core` と `refinement::lemmas` で使ってはならない。やむを得ず使う場合は ADR を作り、課題 ID とともに一覧化する。
- Kani のハーネスは、境界（`kani::any()` の範囲・ループ展開数）をコメントに書き、何を保証しないかを明記する。
- 各課題の充足状況（どの関数・ハーネス・テストで満たしたか）を [refinement.md](../spec/refinement.md) の表に記録する。

## 品質

- `cargo fmt`, `cargo clippy -- -D warnings` を通す。
- CI は Verus の検証、`cargo kani`、`cargo test` のすべてを実行する。
