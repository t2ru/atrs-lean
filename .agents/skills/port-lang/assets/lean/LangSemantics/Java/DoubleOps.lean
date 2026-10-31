import LangSemantics.Java.JDouble

/-!
# LangSemantics.Java.DoubleOps

double の演算子の写し（`(double) n` の `jd`、`a * b` の `jdmul`、リテラルの `jdLit`、`(int) d` の `jd2i` など）。
モデルの式を Java の式の形に近づけるための短い名前で、`open LangSemantics.Java.DoubleOps` で使う。本体は `LangSemantics.Java.JDouble` の演算である。
-/

namespace LangSemantics.Java.DoubleOps

open LangSemantics.Java LangSemantics.Java.Int

/-- `(double) n`。 -/
def jd (n : Int) : JDouble := JDouble.ofInt n
/-- double リテラル。不正な表記は NaN（モデルの記述誤りを検査で見つけるため）。 -/
def jdLit (s : String) : JDouble := (JDouble.ofDecimal? s).getD .nan
def jdadd (a b : JDouble) : JDouble := JDouble.add a b
def jdsub (a b : JDouble) : JDouble := JDouble.sub a b
def jdmul (a b : JDouble) : JDouble := JDouble.mul a b
def jddiv (a b : JDouble) : JDouble := JDouble.div a b
/-- `(int) d`。 -/
def jd2i (d : JDouble) : J32 := JDouble.toJ32 d
/-- `(long) d`。 -/
def jd2l (d : JDouble) : J64 := JDouble.toJ64 d

/-- リテラル `0.01` は、0.01 に最も近い binary64（`0x3F847AE147AE147B`）である。 -/
theorem jdLit_0_01_bits : (jdLit "0.01").toBits = 0x3F847AE147AE147B#64 := by decide

/-- 例: `(int) (1430 * (1 - 30 * 0.01))` は 1000 である（厳密計算では 1001）。 -/
theorem jd2i_1430_30 : (jd2i (jdmul (jd 1430) (jdsub (jd 1) (jdmul (jd 30) (jdLit "0.01"))))).val = 1000 := by
  decide

end LangSemantics.Java.DoubleOps
