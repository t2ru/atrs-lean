# Rust: LangSemantics.Rust

Rust の値の意味論を Lean に定義する。所有権・借用・並行性は扱わない（モデルは値の意味論で写す）。
移植先として使う場合（`TargetModel`）も、移植元として使う場合（`SourceModel`）も、同じ定義を使う。

## 範囲

| 名前 | Rust | 意味 |
| --- | --- | --- |
| `U8`…`U64`, `I8`…`I64`, `Usize` | 固定長整数 | `BitVec` で表す。`usize` の幅はターゲットのパラメータ（既定 64） |
| `rAdd` ほか | `+ - *`（既定の演算） | 溢れ時の振る舞いはビルドプロファイルで異なる: `debug` ではパニック、`release` では折り返し（`overflow-checks` の設定に従う）。プロファイルを引数に取る |
| `rCheckedAdd` ほか | `checked_*` | 溢れたら `None` |
| `rWrappingAdd` ほか | `wrapping_*` | 2^n を法とする折り返し |
| `rSaturatingAdd` ほか | `saturating_*` | 上限・下限に張り付く |
| `rDiv`, `rRem` | `/ %` | 0 方向切捨て。0 除算と `MIN / -1` はパニック |
| `RChar` | `char` | Unicode スカラ値（U+0000–U+D7FF, U+E000–U+10FFFF） |
| `RString` | `String` / `&str` | UTF-8 のバイト列（妥当性を不変条件とする）。`len` はバイト数、`chars().count()` はスカラ値数 |
| `RVec` | `Vec<T>` | 列。範囲外の添字アクセスはパニック、`get` は `Option` |
| `ROption`, `RResult` | `Option<T>`, `Result<T, E>` | `Option`, `Except E T` 相当 |
| `RPanic` | パニック | 値として表す（メッセージ付き）。Lean の `panic!` は使わない |
| `RFloat` | `f32`, `f64` | 必要な場合だけ、Java パックと同じ方式のソフトモデルで定義する |

## 具体化（β）での写し方

| Rust | `Spec` |
| --- | --- |
| 固定長整数（値域内） | `Nat` / `Int` |
| `RString` | スカラ値の列（`chars()`） |
| `RResult` | `Except` |
| `RPanic` | β 未定義（`Refinement` で到達しないことを証明する） |

## 証明しておく基本性質

- 値域内では、既定の演算・`checked_*`・`wrapping_*` が数学的整数の演算と一致する（プロファイルに依らない）。
- `RString` の `chars().count()` と `len` の関係（ASCII のみなら等しい）。
