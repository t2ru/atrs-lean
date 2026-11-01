-- expect:
-- 言語パックの式の構文のモジュール（LangSemantics.<Lang>.Expr）は、構文を展開するために Lean を import してよい
import Lean.Elab.Term
import LangSemantics.Java.Int

namespace LangSemantics.Java.Expr
end LangSemantics.Java.Expr
