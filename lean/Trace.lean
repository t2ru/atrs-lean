import Trace.Attr

/-!
# Trace

追跡属性（`@[source]`, `@[target]`, `@[obligation]`, `@[deviation]`, `@[nondet]`, `@[std_abs]`, `@[kernel]`, `@[env_pre]`, `@[spec_doc]`, `@[no_source]`）。
どのモデルにも依存しない基盤である（port-lang の `lean/trace-attributes.md`）。
`trace-dump` の本体は `Trace.Dump`、`obligation-check` の本体は `Trace.Obligation`（どちらも道具とテストだけが使う）にある。
-/
