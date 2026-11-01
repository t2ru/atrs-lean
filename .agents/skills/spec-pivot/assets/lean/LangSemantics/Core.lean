import LangSemantics.Core.List
import LangSemantics.Core.MapM
import LangSemantics.Core.EStateHoare
import LangSemantics.Core.EStateSimp

/-!
# LangSemantics.Core

言語に依存しない列・`Option` の補題と、状態と例外を持つ計算（`EStateM`）の Hoare 三つ組・簡約のタクティク（core だけに依存する）。どの言語パック（`LangSemantics.<lang>`）からも、
移植元側・移植先側のどの層からも import してよい（スキルの `references/docs/lang/lean/rules.md`）。
-/
