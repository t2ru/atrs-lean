-- expect: LEAN-IMPORT
-- 式の構文のモジュールでない言語パックのモジュールは、Lean を import してはならない
import Lean.Elab.Term

namespace LangSemantics.Java.ImportsLean
end LangSemantics.Java.ImportsLean
