# Rust: ソースの構成と Lean 名前空間の対応

## 移植先として（Rust を書く）

```
<crate>/
  rust-toolchain.toml      検証器（Verus）が要求する版に固定
  Cargo.toml
  src/
    lib.rs
    <機能>.rs …            業務機能（実行コード。純粋な部分は verus! 内）
    adapter/               ポートの実装（インメモリ、DB、ファイル、時計、HTTP）。#[verifier::external]
    model/                 Lean TargetModel の Verus 写し（spec fn のみ）
    proof/                 Verus の補題（proof fn）
  kani/                    Kani ハーネス（#[cfg(kani)]）
  tests/                   適合テストベクタの照合、結合テスト
```

- Rust のソースはモデルではない。Lean のトップレベル名前空間の規則は適用せず、Rust の慣習に従う。
- 業務機能のモジュール名は、Lean `TargetModel` の下位名前空間名の snake_case にそろえる（`TargetModel.Fare` ↔ `<crate>::fare` ↔ `<crate>::model::fare`）。

### model/: TargetModel の写し

- Lean `TargetModel` の公開定義 1 つにつき、Verus の `spec fn`（または `struct`・`enum`）を 1 つ書く。名前は Lean の名前の snake_case。
- 各定義の doc コメントに追跡タグを書く: `/// trace: models TargetModel.Fare.basicFare @<Lean Merkle ハッシュ>`。ハッシュは `lake exe trace-dump` の値をそのまま書く。
- 構造（場合分け・再帰・評価順）を Lean と同じに保つ。数値は `int` / `nat` で書き、固定長整数の溢れは [semantics.md](semantics.md) と同じ定義で表す。文字列は `Seq<char>`。
- `model/` に実行コードを置いてはならない。

### 業務機能（実行コード）

- 純粋な部分は `verus!` の中に書き、各公開関数の `ensures` で `model` の対応する関数との一致を述べる（例: `ensures r == model::fare::basic_fare(x, y)`）。
- 値域を収められる固定長整数を使い、`requires` で値域を前提とする。
- `unsafe`、浮動小数点型、`unwrap`・`expect`・範囲外になりうる添字、`std::time` などの暗黙の副作用を使ってはならない。「今日」・マスタ・設定は引数で受け取る。
- Lean `TargetModel` と同じ関数の分け方・評価順・エラーの返し方を保つ。Rust 側だけで最適化したら、`TargetModel` も同じ変更で直す（本文ハッシュのずれで検出される）。
- 移植元の言語のロケータを、Rust のコード・コメントに書いてはならない。

### adapter/

- ポートの実装。`#[verifier::external]` とし、Kani と結合テストで確認する。
- `unsafe` を使ってはならない。パニックしうる箇所は Kani で到達不能を示すか、`Result` で返す。
- 採用するクレートは意思決定として記録し、版を `trace/target.json` に書く。

## 移植元として（Rust を読む）

- クレートのモジュール構成と `SourceModel` の下位名前空間を、業務機能単位で対応づける。
- `@[source "rust:<crate>::<path>@<hash>"]` を付け、`LangSemantics.Rust` の意味（ビルドプロファイルによる溢れの違いを含む）で写す。
- `unsafe` ブロック、`build.rs`、マクロ展開後にだけ現れる振る舞いは、写す前に展開結果を確認する。

> **未整備:** マクロ（`macro_rules!`・手続きマクロ）のロケータと、展開結果のインベントリ化。
