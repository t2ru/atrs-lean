import LangSemantics.Rust.Panic
import LangSemantics.Rust.Int
import LangSemantics.Rust.Text

/-!
# LangSemantics.Rust

Rust の言語意味論モデル（アプリ非依存）。値の意味論で写し、所有権・借用・並行性は扱わない。
移植元・移植先のどちらにも使う。説明は port-lang スキルの `references/docs/rust/semantics.md`。
-/
