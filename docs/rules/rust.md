---
type: Guideline
title: "Rust 規約"
description: "移植先ソース（Rust）の構成、Lean TargetModel を Verus に写す規則、実行コードの書き方、追跡タグ、Verus・Kani・適合テストによる検証の規約。"
tags: [rules, rust, verus, kani]
status: draft
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:24:48+09:00
---

# Rust 規約

`rust/` は **移植先ソース** である。モデルではない（[ADR 0022](../decision/0022-models-in-lean-and-sources-traced-at-both-ends.md)）。
移植先モデル `TargetModel` は Lean にあり、Rust ソースとは追跡（[ADR 0023](../decision/0023-cross-language-traceability.md)）と次の 3 つの確認手段でつながる。

| 手段 | 何を確かめるか |
| --- | --- |
| 適合テストベクタ（`conformance/target-model/`, `shared/`） | Rust の実行結果が Lean `TargetModel` の実行結果と一致する |
| Verus | Rust の実行コードが `model/`（Lean `TargetModel` の Verus 写し）と全入力で一致し、算術がオーバーフローしない |
| Kani | 有界な入力で、パニック・オーバーフロー・未定義動作が無く、アダプタが契約を満たす |

本規約は `status: draft` である。Verus と Kani の併用可否（[backlog 0018](../backlog/0018-rust-project-scaffold.md)）の結果で見直す。

## 構成

```
rust/
  rust-toolchain.toml      Verus のリリースが要求する版に固定
  Cargo.toml               パッケージ atrs（単一クレート）
  src/
    lib.rs
    fare.rs, flight_search.rs, reservation.rs, …   業務機能（実行コード。純粋な部分は verus! 内）
    adapter/               ポートの実装（インメモリ、DB、ファイル、時計、HTTP）。#[verifier::external]
    model/                 Lean TargetModel の Verus 写し（spec fn のみ）
    proof/                 Verus の補題（proof fn）
  kani/                    Kani ハーネス（#[cfg(kani)]）
  tests/                   適合テストベクタの実行器、結合テスト
```

- `rust/` は名前空間規則（Lean のトップレベル名前空間）の対象外であり、Rust の慣習に従う。
- 業務機能のモジュール名は、Lean `TargetModel` の下位名前空間名の snake_case にそろえる（`TargetModel.Fare` ↔ `atrs::fare` ↔ `atrs::model::fare`）。

## model/: Lean TargetModel の写し

- Lean `TargetModel` の公開定義 1 つにつき、Verus の `spec fn`（または `struct`・`enum`）を 1 つ書く。名前は Lean の名前の snake_case とする。
- 各定義の doc コメントに追跡タグを書く: `/// trace: models TargetModel.Fare.basicFare @<Lean Merkle ハッシュ>`。ハッシュは `lake exe trace-dump` が出す値をそのまま書く。Lean 側を変えるとハッシュがずれ、検査 TR-T2 が失敗する。
- 構造（場合分け・再帰・評価順）を Lean と同じに保つ。数値は数学的整数 `int` / `nat` で書き、Rust の固定長整数の意味（溢れ）は Lean `LangSemantics.Rust` と同じ定義で表す。
- 文字列は `Seq<char>`（Unicode スカラ値の列）として扱う。
- `model/` に実行コードを置いてはならない。

## 業務機能（実行コード）

- 純粋な部分（運賃・照会・検証・状態遷移）は `verus!` の中に書き、各公開関数の `ensures` で `model` の対応する関数との一致を述べる（例: `ensures r == model::fare::basic_fare(x, y)`）。
- 数値型は値域（[domain-model.md](../spec/domain-model.md#値域)）を収められる固定長整数（原則 `u64` / `i64`）を使い、`requires` で値域を前提とする。
- `unsafe`、浮動小数点型、`unwrap`・`expect`・範囲外になりうる添字、`std::time` などの暗黙の副作用を使ってはならない。「今日」・マスタ・設定は引数で受け取る。
- Lean `TargetModel` と同じ関数の分け方・評価順・エラーの返し方を保つ。Rust 側だけで最適化した場合は、`TargetModel` も同じ変更で直す（Rust の本文が変わると `@[target]` のハッシュがずれて TR-T2 が失敗するので、見落とさない）。
- 移植元ロケータ（`java:` `sql:` 等）を Rust のコード・コメントに書いてはならない（検査 TR-X）。移植元との関係は Lean の証明グラフを通してのみたどる。

## adapter/

- ポート（[ports.md](../spec/ports.md)）の実装を置く。`#[verifier::external]` とし、Kani と結合テストで検査する。
- `unsafe` を使ってはならない。パニックしうる箇所は Kani で到達不能を示すか、`Result` で返す。
- HTTP フレームワーク・DB ドライバ・パスワードハッシュのクレートは、採用時に ADR を作る。依存クレートの版は `trace/target.json` に記録する。

## 検証

| 手段 | 置き場所 | 何を確かめるか |
| --- | --- | --- |
| Verus | 業務機能の `ensures` と `proof/` | 実行コード ＝ `model/` |
| Kani | `kani/` | `verus!` の外のコード、アダプタの契約、JSON の往復 |
| 適合テスト | `tests/` | Rust の結果 ＝ Lean `TargetModel` の結果（`target-model/`, `shared/`） |
| 結合テスト | `tests/` | トランザクション・HTTP の契約（[ports.md](../spec/ports.md#トランザクション), [http-contract.md](../spec/http-contract.md)） |

- Verus の `assume`・`admit`・`#[verifier::external_body]` を業務機能と `proof/` で使ってはならない。やむを得ず使う場合は ADR を作り、[refinement.md](../spec/refinement.md#未証明の前提) に列挙する。
- Kani のハーネスは、境界（`kani::any()` の範囲・ループ展開数）と、何を保証しないかをコメントに書く。

## 品質

- `cargo fmt`, `cargo clippy -- -D warnings` を通す。
- CI は Verus の検証、`cargo kani`、`cargo test`、追跡の検査（`tools/trace check`）を実行する。
