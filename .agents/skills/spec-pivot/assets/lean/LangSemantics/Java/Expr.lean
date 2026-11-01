import Lean.Elab.Term
import Lean.Elab.SyntheticMVars
import LangSemantics.Java.Int
import LangSemantics.Java.DoubleOps
import Trace.Attr

/-!
# LangSemantics.Java.Expr

Java の式の構文 `java! e`。`SourceModel` の式を、原典の Java の式と同じ字面で書くためのもの。
意味は持たない。展開すると、`LangSemantics.Java` の原始関数（`j32add`・`jdmul`・`jd2i`・`jdiv32` など）を
手で書いたときと **同じ項** になる（`Test.LangSemantics.JavaExpr` が `#guard_expr … =ₛ …` で確かめる）。
そのため、証明は展開後の原始関数について書けばよい。

- 優先順位と結合（JLS 15）: 低い順に `||`・`&&`・`==` `!=`・`<` `<=` `>` `>=`・`+` `-`・`*` `/` `%`、単項の `-` `!` とキャスト。
  2 項演算子は左結合で、比較は結合しない。
- 項: 識別子（`svc.childFareRate` のようなドット付きを含む）、リテラル、括弧、メソッド呼び出し `f(a, b)`（Lean の関数
  `f a b` の適用。`p.getBoardingClass(cd)` はドット記法になる）、Lean の項 `⟪t⟫`。
- リテラルの型は字面で決まる（JLS 3.10）: `100` は `int`（`J32.ofInt 100`）、`100L` は `long`（`J64.ofInt 100`）、
  `0.01`・`1d` は `double`（`jdLit "0.01"`）。範囲外の整数リテラルと、指数表記の double リテラルは誤り。
- 2 項の数値昇格（JLS 5.6.2）: どちらかが `double` なら `double`、そうでなくどちらかが `long` なら `long`、ほかは `int`。
  `int` から `double` は `jd x.val`、`long` へは `J64.ofInt x.val` で、整数リテラルはその値のまま（`jd 1`・`J64.ofInt 1`）。
- 演算: 加減乗除・剰余は昇格した型の原始関数。比較は `decide (a.val ≥ b.val)`（整数リテラルは値のまま。`decide (x.val ≥ 0)`）。
  `==`・`!=` は整数なら `decide (a.val = b.val)`・`decide (a.val ≠ b.val)`、`boolean` なら `==`・`!=`。
  `&&`・`||` は短絡評価、`!` は否定。
- キャスト: `(int) d` は `jd2i d`、`(long) d` は `jd2l d`、`(int) l` は `J32.ofInt l.val`、`(double) n` は `jd n.val`。
- 例外: 整数の `/`・`%`（0 除算で `ArithmeticException`）と、`JResult` を返す呼び出しを含む式は `JResult τ` になる。
  部分式を左から順に `>>=` でつなぐ。それ以外の式は `τ` のままである（`let x := java! …` と `let x ← java! …` を使い分ける）。
- 扱わないもの: `double` の比較・剰余、`float`・`char`・`short`・`byte`、参照型の `==`、代入式、`?:`。必要になった時点で足す。

lang: `lang:java#JLS-3.10`, `lang:java#JLS-5.6.2`, `lang:java#JLS-15`
-/

namespace LangSemantics.Java.Expr
open Lean Elab Term Meta
open LangSemantics.Java.Int LangSemantics.Java.Exception LangSemantics.Java.DoubleOps

/-- Java の式の構文。 -/
declare_syntax_cat jexpr

attribute [ns_exception "構文の種類の定数は Lean が Lean.Parser.Category の下に名付ける（declare_syntax_cat）"]
  Lean.Parser.Category.jexpr

syntax:max ident : jexpr
syntax:max num : jexpr
syntax:max num noWs ident : jexpr
syntax:max scientific : jexpr
syntax:max scientific noWs ident : jexpr
syntax:max "(" jexpr ")" : jexpr
syntax:max "⟪" term "⟫" : jexpr
syntax:max ident noWs "(" jexpr,* ")" : jexpr
syntax:100 "(" &"int" ")" jexpr:100 : jexpr
syntax:100 "(" &"long" ")" jexpr:100 : jexpr
syntax:100 "(" &"double" ")" jexpr:100 : jexpr
syntax:100 "-" jexpr:100 : jexpr
syntax:100 "!" jexpr:100 : jexpr
syntax:70 jexpr:70 " * " jexpr:71 : jexpr
syntax:70 jexpr:70 " / " jexpr:71 : jexpr
syntax:70 jexpr:70 " % " jexpr:71 : jexpr
syntax:65 jexpr:65 " + " jexpr:66 : jexpr
syntax:65 jexpr:65 " - " jexpr:66 : jexpr
syntax:50 jexpr:51 " < " jexpr:51 : jexpr
syntax:50 jexpr:51 " <= " jexpr:51 : jexpr
syntax:50 jexpr:51 " > " jexpr:51 : jexpr
syntax:50 jexpr:51 " >= " jexpr:51 : jexpr
syntax:45 jexpr:45 " == " jexpr:46 : jexpr
syntax:45 jexpr:45 " != " jexpr:46 : jexpr
syntax:35 jexpr:35 " && " jexpr:36 : jexpr
syntax:30 jexpr:30 " || " jexpr:31 : jexpr

/-- `java! e`: Java の式 `e` を、`LangSemantics.Java` の原始関数の項に展開する。 -/
syntax (name := javaExpr) "java! " jexpr : term

/-! ## 型と値 -/

/-- 式の値の型。 -/
inductive Ty where
  | int | long | double | bool | other
  deriving BEq, Repr, Inhabited

/-- 数値型（`int`・`long`・`double`）か。 -/
def Ty.isNumeric : Ty → Bool
  | .int | .long | .double => true
  | _ => false

/-- 整数型（`int`・`long`）か。 -/
def Ty.isIntegral : Ty → Bool
  | .int | .long => true
  | _ => false

/-- 整数の値のリテラルの項（負なら `-n`）。 -/
def intLit {m : Type → Type} [Monad m] [MonadQuotation m] (n : Int) : m Term := do
  let k : Term := Syntax.mkNumLit (toString n.natAbs)
  if n < 0 then `(-$k) else return k

/-- 型の名前（誤りの報告に使う）。 -/
def Ty.name : Ty → String
  | .int => "int" | .long => "long" | .double => "double" | .bool => "boolean" | .other => "（Java の基本型でない）"

/-- 型 `t` を Java の基本型に分類する。 -/
def tyOf (t : Expr) : MetaM Ty := do
  let t ← instantiateMVars t
  if ← isDefEq t (mkConst ``J32) then return .int
  if ← isDefEq t (mkConst ``J64) then return .long
  if ← isDefEq t (mkConst ``LangSemantics.Java.JDouble) then return .double
  if ← isDefEq t (mkConst ``Bool) then return .bool
  return .other

/-- 部分式を elaborate した値。`monadic` なら `e : JResult τ` で、`ty` は `τ` の分類である。 -/
structure Val where
  e : Expr
  τ : Expr
  ty : Ty
  monadic : Bool

/-- `java! e` を elaborate して、値の型を調べる。 -/
def elabVal (stx : TSyntax `jexpr) : TermElabM Val := do
  let e ← elabTerm (← `(java! $stx)) none
  synthesizeSyntheticMVarsNoPostponing
  let e ← instantiateMVars e
  let t ← whnfR (← instantiateMVars (← inferType e))
  if t.isAppOfArity ``Except 2 then
    let τ := t.appArg!
    return { e, τ, ty := ← tyOf τ, monadic := true }
  else
    let τ ← instantiateMVars (← inferType e)
    return { e, τ, ty := ← tyOf τ, monadic := false }

/-- 整数リテラル（`n`・`-n`・括弧）の値。`long` のリテラルなら `long := true`。 -/
def litInt? : Nat → TSyntax `jexpr → Option (Int × Bool)
  | 0, _ => none
  | fuel + 1, stx =>
    match stx with
    | `(jexpr| $n:num) => some (n.getNat, false)
    | `(jexpr| $n:num$s:ident) => if s.getId == `L || s.getId == `l then some (n.getNat, true) else none
    | `(jexpr| ($e)) => litInt? fuel e
    | `(jexpr| - $e) => (litInt? fuel e).map fun (n, l) => (-n, l)
    | _ => none

/-- 値の項の構文（monadic なら束縛した変数）と、束縛の並び。 -/
structure Bound where
  /-- 値として使う項（束縛した変数か、値そのもの） -/
  arg : Term
  ty : Ty
  /-- 整数リテラルなら、その値 -/
  lit : Option Int := none
  deriving Inhabited

/-- `liftJ% t`: `t` が `JResult` ならそのまま、そうでなければ `pure t`。 -/
elab "liftJ% " t:term : term => do
  let e ← elabTerm t none
  synthesizeSyntheticMVarsNoPostponing
  let ty ← whnfR (← instantiateMVars (← inferType e))
  if ty.isAppOfArity ``Except 2 then return e
  elabTerm (← `(pure (f := JResult) $(← exprToSyntax e))) none

/-- 値を左から順に束縛して `k` に渡し、`>>=` でつないだ項を作る。束縛が無く `k` の項が純粋なら、そのまま返す。 -/
def withBinds (vs : Array (Val × Option Int)) (k : Array Bound → TermElabM Term) : TermElabM Term := do
  let mut binds : Array (Ident × Term × Term) := #[]
  let mut args : Array Bound := #[]
  for (v, lit) in vs do
    if v.monadic then
      let x := mkIdent (← mkFreshUserName `x)
      binds := binds.push (x, ← exprToSyntax v.e, ← exprToSyntax v.τ)
      args := args.push { arg := x, ty := v.ty }
    else
      args := args.push { arg := ← exprToSyntax v.e, ty := v.ty, lit := lit }
  let core ← k args
  if binds.isEmpty then return core
  -- 本体が純粋か JResult かは elaborate してから決まるので、`liftJ%` で JResult にそろえる
  let mut body ← `(liftJ% $core)
  for (x, m, τ) in binds.reverse do
    body ← `($m >>= fun ($x : $τ) => $body)
  return body

/-! ## 昇格 -/

/-- 2 項の数値昇格の型。 -/
def promote (a b : Ty) : Option Ty :=
  if !(a.isNumeric && b.isNumeric) then none
  else if a == .double || b == .double then some .double
  else if a == .long || b == .long then some .long
  else some .int

/-- 値 `b` を型 `to` に昇格した項。 -/
def widen (b : Bound) (to : Ty) : TermElabM Term := do
  if b.ty == to then return b.arg
  match b.ty, to, b.lit with
  | .int, .long, some n => `(J64.ofInt $(← intLit n))
  | .int, .long, none => `(J64.ofInt ($(b.arg)).val)
  | .int, .double, some n | .long, .double, some n => `(jd $(← intLit n))
  | .int, .double, none | .long, .double, none => `(jd ($(b.arg)).val)
  | _, _, _ => throwError "java!: {b.ty.name} を {to.name} に昇格できない"

/-- 比較に使う整数の値の項（リテラルは値のまま、ほかは `.val`）。 -/
def intValue (b : Bound) : TermElabM Term := do
  match b.lit with
  | some n => `(($(← intLit n) : Int))
  | none => `(($(b.arg)).val)

/-! ## 演算子 -/

/-- `jbin% op a b`: 算術の 2 項演算子。 -/
syntax "jbin% " str jexpr:max jexpr:max : term
/-- `jcmp% op a b`: 比較・等値。 -/
syntax "jcmp% " str jexpr:max jexpr:max : term
/-- `jlogic% op a b`: `&&`・`||`（短絡評価）。 -/
syntax "jlogic% " str jexpr:max jexpr:max : term
/-- `jcast% ty a`: キャスト。 -/
syntax "jcast% " str jexpr:max : term
/-- `jneg% a`: 単項の `-`。 -/
syntax "jneg% " jexpr:max : term
/-- `jnot% a`: `!`。 -/
syntax "jnot% " jexpr:max : term
/-- `jcall% f (args)`: メソッド呼び出し。 -/
syntax "jcall% " ident "(" jexpr,* ")" : term
/-- `jint% n l`: 整数リテラル。 -/
syntax "jint% " num str : term

/-- 束縛した値が 1 つ。 -/
def one (xs : Array Bound) : TermElabM Bound :=
  match xs with
  | #[x] => return x
  | _ => throwError "java!: 内部の誤り（値の数が {xs.size}）"

/-- 束縛した値が 2 つ。 -/
def two (xs : Array Bound) : TermElabM (Bound × Bound) :=
  match xs with
  | #[x, y] => return (x, y)
  | _ => throwError "java!: 内部の誤り（値の数が {xs.size}）"

/-- 部分式を、リテラルの値とともに elaborate する。 -/
def elabArg (stx : TSyntax `jexpr) : TermElabM (Val × Option Int) := do
  return (← elabVal stx, (litInt? 16 stx).map (·.1))

elab_rules : term
  | `(jbin% $op:str $a $b) => do
    let va ← elabArg a
    let vb ← elabArg b
    let stx ← withBinds #[va, vb] fun xs => do
      let (x, y) ← two xs
      let some t := promote x.ty y.ty
        | throwError "java!: {op.getString} を {x.ty.name} と {y.ty.name} に使えない"
      let x' ← widen x t
      let y' ← widen y t
      match t, op.getString with
      | .int, "+" => `(j32add $x' $y')
      | .int, "-" => `(j32sub $x' $y')
      | .int, "*" => `(j32mul $x' $y')
      | .int, "/" => `(jdiv32 $x' $y')
      | .int, "%" => `(jrem32 $x' $y')
      | .long, "+" => `(j64add $x' $y')
      | .long, "-" => `(j64sub $x' $y')
      | .long, "*" => `(j64mul $x' $y')
      | .long, "/" => `(jdiv64 $x' $y')
      | .long, "%" => `(jrem64 $x' $y')
      | .double, "+" => `(jdadd $x' $y')
      | .double, "-" => `(jdsub $x' $y')
      | .double, "*" => `(jdmul $x' $y')
      | .double, "/" => `(jddiv $x' $y')
      | _, o => throwError "java!: {t.name} の {o} は扱わない"
    elabTerm stx none
  | `(jcmp% $op:str $a $b) => do
    let va ← elabArg a
    let vb ← elabArg b
    let stx ← withBinds #[va, vb] fun xs => do
      let (x, y) ← two xs
      match x.ty, y.ty, op.getString with
      | .bool, .bool, "==" => `($(x.arg) == $(y.arg))
      | .bool, .bool, "!=" => `($(x.arg) != $(y.arg))
      | s, t, o => do
        unless s.isIntegral && t.isIntegral do throwError "java!: {o} を {s.name} と {t.name} に使えない"
        let p ← intValue x
        let q ← intValue y
        match o with
        | "<" => `(decide ($p < $q))
        | "<=" => `(decide ($p ≤ $q))
        | ">" => `(decide ($p > $q))
        | ">=" => `(decide ($p ≥ $q))
        | "==" => `(decide ($p = $q))
        | "!=" => `(decide ($p ≠ $q))
        | _ => throwError "java!: 比較 {o} は扱わない"
    elabTerm stx none
  | `(jlogic% $op:str $a $b) => do
    let va ← elabArg a
    let vb ← elabArg b
    unless va.1.ty == .bool && vb.1.ty == .bool do
      throwError "java!: {op.getString} は boolean に使う（{va.1.ty.name} と {vb.1.ty.name}）"
    -- 右辺は左辺の値によっては評価しない（短絡評価）ので、左辺だけを先に束縛する
    let rhs ← exprToSyntax vb.1.e
    let stx ← withBinds #[va] fun xs => do
      let x := (← one xs).arg
      match op.getString, vb.1.monadic with
      | "&&", false => `($x && $rhs)
      | "||", false => `($x || $rhs)
      | "&&", true => `(if $x then $rhs else pure (f := JResult) false)
      | _, _ => `(if $x then pure (f := JResult) true else $rhs)
    elabTerm stx none
  | `(jcast% $ty:str $a) => do
    let va ← elabArg a
    let stx ← withBinds #[va] fun xs => do
      let x ← one xs
      match ty.getString, x.ty, x.lit with
      | "int", .int, _ | "long", .long, _ | "double", .double, _ => return x.arg
      | "int", .long, _ => `(J32.ofInt ($(x.arg)).val)
      | "int", .double, _ => `(jd2i $(x.arg))
      | "long", .int, some n => `(J64.ofInt $(← intLit n))
      | "long", .int, none => `(J64.ofInt ($(x.arg)).val)
      | "long", .double, _ => `(jd2l $(x.arg))
      | "double", .int, _ | "double", .long, _ => widen x .double
      | t, s, _ => throwError "java!: ({t}) を {s.name} に使えない"
    elabTerm stx none
  | `(jneg% $a) => do
    let va ← elabArg a
    let stx ← withBinds #[va] fun xs => do
      let x ← one xs
      match x.ty with
      | .int => `(j32neg $(x.arg))
      | .long => `(j64neg $(x.arg))
      | .double => `(jdneg $(x.arg))
      | s => throwError "java!: 単項の - を {s.name} に使えない"
    elabTerm stx none
  | `(jnot% $a) => do
    let va ← elabArg a
    unless va.1.ty == .bool do throwError "java!: ! を {va.1.ty.name} に使えない"
    let stx ← withBinds #[va] fun xs => do `(! $((← one xs).arg))
    elabTerm stx none
  | `(jcall% $f:ident ($args,*)) => do
    let vs ← args.getElems.mapM elabArg
    let stx ← withBinds vs fun xs => do
      let as := xs.map (·.arg)
      `($f $as*)
    elabTerm stx none
  | `(jint% $n:num $l:str) => do
    let v : Int := n.getNat
    if l.getString == "long" then
      unless v ≤ 9223372036854775807 do throwError "java!: long のリテラル {v} は範囲外"
      elabTerm (← `(J64.ofInt $n)) none
    else
      unless v ≤ 2147483647 do throwError "java!: int のリテラル {v} は範囲外"
      elabTerm (← `(J32.ofInt $n)) none

/-- double リテラルの字面（Java の接尾辞 `d`・`D` を除く）。 -/
def doubleText (s : TSyntax `scientific) : String :=
  (s.raw.isLit? scientificLitKind).getD ""

/-- double リテラルの項。`jdLit` が読む十進の小数の形（指数部の無いもの）だけを受ける。 -/
def doubleLit (s : TSyntax `scientific) : MacroM Term := do
  let t := doubleText s
  if t.any (fun c => c == 'e' || c == 'E') then
    Macro.throwError s!"java!: 指数表記の double リテラル {t} は扱わない（jdLit が読めない）"
  `(jdLit $(quote t))

macro_rules
  | `(java! $i:ident) => `($i)
  | `(java! ⟪$t⟫) => `($t)
  | `(java! ($e)) => `(java! $e)
  | `(java! $n:num) => `(jint% $n "int")
  | `(java! $n:num$s:ident) => do
    match s.getId with
    | `L | `l => `(jint% $n "long")
    | `d | `D => `(jdLit $(quote (toString n.getNat)))
    | _ => Macro.throwError s!"java!: 整数リテラルの接尾辞 {s.getId} は扱わない"
  | `(java! $s:scientific) => doubleLit s
  | `(java! $s:scientific$x:ident) => do
    match x.getId with
    | `d | `D => doubleLit s
    | _ => Macro.throwError s!"java!: 浮動小数リテラルの接尾辞 {x.getId} は扱わない"
  | `(java! $f:ident($args,*)) => `(jcall% $f ($args,*))
  | `(java! (int) $a) => `(jcast% "int" $a)
  | `(java! (long) $a) => `(jcast% "long" $a)
  | `(java! (double) $a) => `(jcast% "double" $a)
  | `(java! - $n:num) => do
    -- 負の整数リテラル（`-2147483648` を許す）
    if n.getNat ≤ 2147483648 then `(J32.ofInt (-$n)) else Macro.throwError s!"java!: int のリテラル -{n.getNat} は範囲外"
  | `(java! - $a) => `(jneg% $a)
  | `(java! ! $a) => `(jnot% $a)
  | `(java! $a * $b) => `(jbin% "*" $a $b)
  | `(java! $a / $b) => `(jbin% "/" $a $b)
  | `(java! $a % $b) => `(jbin% "%" $a $b)
  | `(java! $a + $b) => `(jbin% "+" $a $b)
  | `(java! $a - $b) => `(jbin% "-" $a $b)
  | `(java! $a < $b) => `(jcmp% "<" $a $b)
  | `(java! $a <= $b) => `(jcmp% "<=" $a $b)
  | `(java! $a > $b) => `(jcmp% ">" $a $b)
  | `(java! $a >= $b) => `(jcmp% ">=" $a $b)
  | `(java! $a == $b) => `(jcmp% "==" $a $b)
  | `(java! $a != $b) => `(jcmp% "!=" $a $b)
  | `(java! $a && $b) => `(jlogic% "&&" $a $b)
  | `(java! $a || $b) => `(jlogic% "||" $a $b)

end LangSemantics.Java.Expr
