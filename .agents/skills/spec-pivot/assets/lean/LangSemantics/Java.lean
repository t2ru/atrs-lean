import LangSemantics.Java.Exception
import LangSemantics.Java.Int
import LangSemantics.Java.JDouble
import LangSemantics.Java.DoubleOps
import LangSemantics.Java.Expr
import LangSemantics.Java.BigDecimal
import LangSemantics.Java.String
import LangSemantics.Java.Spring
import LangSemantics.Java.DecimalFormat
import LangSemantics.Java.JLocalDate
import LangSemantics.Java.HashMap
import LangSemantics.Java.JLocalDate.Lemmas
import LangSemantics.Java.JLocalDate.RoundTrip
import LangSemantics.Java.HashMap.Lemmas
import LangSemantics.Java.JDouble.Lemmas
import LangSemantics.Java.JDouble.Compare
import LangSemantics.Java.ResultLemmas
import LangSemantics.Java.IntLemmas

/-!
# LangSemantics.Java

Java の言語意味論モデル（アプリ非依存）。移植元・移植先のどちらにも使う。
説明は spec-pivot スキルの `references/docs/lang/java/semantics.md`。
-/
