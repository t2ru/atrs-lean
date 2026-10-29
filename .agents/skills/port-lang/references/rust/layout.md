# Rust: ソースの構成と Lean 名前空間の対応

## 移植先として（Rust を書く）

```
<crate>/
  rust-toolchain.toml      検証器（Verus）が要求する版に固定
  Cargo.toml
  src/
    lib.rs
    <機能>.rs …            業務機能（実行コード。純粋な部分は verus! 内）
    adapter/               ポートの実装。インメモリは verus! の中、DB・ファイル・時計・HTTP は #[verifier::external]
    model/                 Lean TargetModel から生成した Verus の写し（spec fn と型のみ。手で編集しない）
    model_prelude.rs       LangSemantics.Rust の演算の Verus 版（スキルの assets/verus/ から写す。生成器が参照する）
    proof/                 Verus の補題（proof fn）
  kani/                    Kani ハーネス（#[cfg(kani)]）
  tests/                   適合テストベクタの照合、結合テスト
```

- Rust のソースはモデルではない。Lean のトップレベル名前空間の規則は適用せず、Rust の慣習に従う。
- 業務機能のモジュール名は、Lean `TargetModel` の下位名前空間名の snake_case にそろえる（`TargetModel.Fare` ↔ `<crate>::fare` ↔ `<crate>::model::fare`）。

### model/: TargetModel の写し（生成物）

- `model/` は、Lean `TargetModel` から生成器（例: `lake exe gen-verus`）で生成する。**手で書いたり編集したりしてはならない。** 生成物はコミットし、CI で再生成して差分が無いことを確認する。
- 生成器は、Lean `TargetModel` の公開定義 1 つにつき、Verus の `spec fn`（または `struct`・`enum`）を 1 つ出力する。名前は Lean の名前の snake_case とする。
- 生成器は、各定義の doc コメントに追跡タグを書く: `/// trace: models TargetModel.Fare.basicFare @<Lean Merkle ハッシュ>`。
- 構造（場合分け・再帰・評価順）は Lean と同じになる。数値は `int` / `nat`、固定長整数の溢れは `model_prelude.rs` の定義（[semantics.md](semantics.md) と同じ意味）、文字列は `Seq<char>` で表す。
- 生成器が扱えない Lean の構文（部分集合の外）があれば、生成器は失敗する。`TargetModel` を部分集合の中で書き直す。
- `model/` に実行コードを置いてはならない。

### 業務機能（実行コード）

- 純粋な部分は `verus!` の中に書く。各公開関数は、生成された事前条件と写しを、ちょうど次の形で参照する（CI の `gen-verus --check-contracts` で検査する）。
  - `requires model::fare::pre_basic_fare(x, y)`
  - `ensures r == model::fare::basic_fare(x, y)`

  `requires` を手で強めてはならない（強めると証明が空虚になりうる）。
- 値域を収められる固定長整数を使う。値域は `Spec` の PRE として、`pre_*` に現れる。
- `unsafe`、浮動小数点型、`unwrap`・`expect`・範囲外になりうる添字、`std::time` などの暗黙の副作用を使ってはならない。「今日」・マスタ・設定は引数で受け取る。禁止する API は `clippy.toml` の `disallowed-methods` / `disallowed-types` に載せ、CI で機械的に検査する。
- Lean `TargetModel` と同じ関数の分け方・評価順・エラーの返し方を保つ。Rust 側だけで最適化したら、`TargetModel` も同じ変更で直し、写しを再生成する。ずれは、本文ハッシュと Verus の証明の失敗で検出される。
- 移植元の言語のロケータを、Rust のコード・コメントに書いてはならない。

### adapter/

- ポートの実装。
  - インメモリの実装の状態遷移は `verus!` の中に書き、`model/` に生成されたポート実装との一致を Verus で証明する。状態を `Mutex` で包む薄い層は `#[verifier::external]` とし、Kani で確認する。
  - DB・ファイル・時計・HTTP の実装は `#[verifier::external]` とする。その振る舞いは `TargetModel.Adapter.*` に写す（DB は `LangSemantics.Sql` の式）。一致は、SQL の差分実行と固定フィクスチャの結合テストで確認し、限界を保証の限界の文書に書く。
  - `#[verifier::external]` は、上の 2 種類にだけ付けてよい。
- `unsafe` を使ってはならない。パニックしうる箇所は Kani で到達不能を示すか、`Result` で返す。
- 採用するクレートは意思決定として記録し、版を `trace/target.json` に書く。

## 移植元として（Rust を読む）

- クレートのモジュール構成と `SourceModel` の下位名前空間を、業務機能単位で対応づける。
- `@[source "rust:<crate>::<path>@<hash>"]` を付け、`LangSemantics.Rust` の意味（ビルドプロファイルによる溢れの違いを含む）で写す。
- `unsafe` ブロック、`build.rs`、マクロ展開後にだけ現れる振る舞いは、写す前に展開結果を確認する。

> **未整備:** マクロ（`macro_rules!`・手続きマクロ）のロケータと、展開結果のインベントリ化。
