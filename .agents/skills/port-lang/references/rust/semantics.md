# Rust: LangSemantics.Rust

Rust の値の意味論を Lean に定義する。所有権・借用・並行性は扱わない（モデルは値の意味論で写す）。
移植先として使う場合（`TargetModel`）も、移植元として使う場合（`SourceModel`）も、同じ定義を使う。

Lean の実装は `assets/LangSemantics/Rust/`（モジュール `LangSemantics.Rust`）。検査は `assets/LangSemanticsTest/Rust.lean`。

## 範囲

| 名前 | Rust | 意味 |
| --- | --- | --- |
| `U8`…`U64`, `I8`…`I64` | 固定長整数 | `BitVec` で表し、符号の有無（`Signedness`）を演算の引数で渡す。`usize`・`isize` は **未整備**（ターゲットの幅をパラメータにする予定） |
| `add`, `sub`, `mul`（引数 `Profile`） | `+ - *`（既定の演算） | 溢れ時の振る舞いはビルドプロファイルで異なる: `debug` ではパニック、`release` では折り返し（`overflow-checks` の設定に従う）。プロファイルを引数に取る |
| `checkedAdd`, `checkedSub`, `checkedMul` | `checked_*` | 溢れたら `None` |
| `wrappingAdd`, `wrappingSub`, `wrappingMul` | `wrapping_*` | 2^n を法とする折り返し |
| `saturatingAdd`, `saturatingSub`, `saturatingMul` | `saturating_*` | 上限・下限に張り付く |
| `div`, `rem` | `/ %` | 0 方向切捨て。0 除算と `MIN / -1` はパニック |
| `RChar` | `char` | Unicode スカラ値（U+0000–U+D7FF, U+E000–U+10FFFF） |
| `RString` | `String` / `&str` | UTF-8 のバイト列（妥当性を不変条件とする）。`strLen` はバイト数（`len()`）、`charsCount` はスカラ値数（`chars().count()`）。`trim`, `splitChar` |
| `RVec` | `Vec<T>` | 列。`index`（範囲外はパニック）、`get`（`Option`） |
| — | `Option<T>`, `Result<T, E>` | Lean の `Option`, `Except E T` をそのまま使う |
| `RPanic` | パニック | 値として表す（メッセージ付き）。Lean の `panic!` は使わない |
| — | `f32`, `f64` | **未整備**。必要になったら Java の `JDouble` と同じ方式のソフトモデルで定義する |

## 具体化（β）での写し方

| Rust | `Spec` |
| --- | --- |
| 固定長整数（値域内） | `Nat` / `Int` |
| `RString` | スカラ値の列（`chars()`） |
| `RResult` | `Except` |
| `RPanic` | β は定義しない。PRE の下で到達しないことを、リファインメントの適用可能性の証明義務で示す（[architecture.md](../architecture.md#リファインメントb-メソッド)） |

## 証明しておく基本性質

- 値域内では、既定の演算・`checked_*`・`wrapping_*` が数学的整数の演算と一致する（プロファイルに依らない）。
- `RString` の `chars().count()` と `len` の関係（ASCII のみなら等しい）。
