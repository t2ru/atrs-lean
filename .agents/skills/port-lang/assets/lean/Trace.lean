import Trace.Attr
import Trace.Gap

/-!
# Trace

追跡属性（`@[source]`, `@[target]`, `@[obligation]`, `@[deviation]`, `@[gap]`, `@[gap_entry]`, `@[nondet]`, `@[std_abs]`, `@[kernel]`, `@[env_pre]`, `@[spec_doc]`, `@[no_source]`）。
どのモデルにも依存しない基盤である（port-lang の `references/docs/lang/lean/trace-attributes.md`）。

- `Trace.Attr`: 文字列引数の追跡属性
- `Trace.Gap`: ギャップの登録簿（`@[gap_entry]` と `Trace.Gap`）
- `Trace.Dump`: `trace-dump` の本体
- `Trace.Obligation`: `obligation-check` の本体

`Trace.Dump`・`Trace.Obligation` は、道具とテストだけが使う。道具の入口（`main`）は、モデルを import するアプリの側に置く。
-/
