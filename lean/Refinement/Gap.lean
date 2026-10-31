import Trace

/-!
# Refinement.Gap

[Spec] と [Target] のギャップ（`T-NNN`）の登録簿（正）。ID ごとに 1 つの `@[gap_entry]` の宣言を置く（ADR cc24）。
書き方は `Abstraction.Gap` と同じ。`docs/spec/refinement.md` の表は、`trace manifest`（port-lang の `scripts/trace`）がここから生成する。
いまは登録が無い。
-/

namespace Refinement.Gap
end Refinement.Gap
