/-!
# Trace.Id

追跡の値の型（ADR bf1b。不正な状態を表現できない型）: 空でない文字列・列と、形式の決まった ID。
どれも値 `val` と、その形式の証明（既定 `by decide`。長い文字列を持つ `NEString` は文字列の簡約の `by simp`）を持つ。字面は `ne!"…"`・`ne![…]`・`gid!"D-001"`・
`oid!"ABS-001"`・`bid!"<UUID>"` で書く。形式に合わない字面は、エラボレートの時点で型の誤りになる。

登録簿の値は評価せずに式から読む（`Trace.Gap.ofConst?`）。読み取りは `val` だけを見て、証明の引数を読み飛ばす。
-/

namespace Trace.Id

/-- 空でない文字列。 -/
structure NEString where
  val : String
  ne : val ≠ "" := by simp
  deriving DecidableEq, Repr

instance : ToString NEString := ⟨NEString.val⟩

/-- 空でない列（先頭と残り）。 -/
structure NEList (α : Type) where
  head : α
  tail : List α
  deriving DecidableEq, Repr

namespace NEList

variable {α : Type}

/-- 列に戻す。 -/
def toList (l : NEList α) : List α := l.head :: l.tail

/-- 空でない列なら作る。 -/
def ofList? : List α → Option (NEList α)
  | [] => none
  | h :: t => some ⟨h, t⟩

/-- 写像。 -/
def map {β : Type} (f : α → β) (l : NEList α) : NEList β := ⟨f l.head, l.tail.map f⟩

theorem toList_ne_nil (l : NEList α) : l.toList ≠ [] := List.cons_ne_nil _ _

end NEList

/-- 数字 3 文字か。 -/
def digits3 : List Char → Bool
  | [a, b, c] => a.isDigit && b.isDigit && c.isDigit
  | _ => false

/-- `D-NNN`（`Abstraction`）/ `T-NNN`（`Refinement`）の形か。 -/
def GapId.valid (s : String) : Bool :=
  match s.toList with
  | p :: '-' :: ds => (p == 'D' || p == 'T') && digits3 ds
  | _ => false

/-- ギャップの ID（`D-NNN` / `T-NNN`）。 -/
structure GapId where
  val : String
  wf : GapId.valid val = true := by decide
  deriving DecidableEq, Repr

/-- ギャップの側（`D-NNN` は移植元、`T-NNN` は移植先）。 -/
inductive GapSide where
  | source
  | target
  deriving DecidableEq, Repr

/-- ID の側。 -/
def GapId.side (i : GapId) : GapSide := if i.val.startsWith "T-" then .target else .source

/-- 側の証明の層。 -/
def GapSide.proofLayer : GapSide → String
  | .source => "Abstraction"
  | .target => "Refinement"

/-- 側のモデルの層（`Spec` と、側のモデル）。 -/
def GapSide.modelLayers : GapSide → List String
  | .source => ["Spec", "SourceModel"]
  | .target => ["Spec", "TargetModel"]

/-- `ABS-NNN` / `REF-NNN` / `SPEC-NNN` の形か。 -/
def ObligationId.valid (s : String) : Bool :=
  match s.toList with
  | 'A' :: 'B' :: 'S' :: '-' :: ds => digits3 ds
  | 'R' :: 'E' :: 'F' :: '-' :: ds => digits3 ds
  | 'S' :: 'P' :: 'E' :: 'C' :: '-' :: ds => digits3 ds
  | _ => false

/-- 証明課題の ID（`ABS-NNN` / `REF-NNN` / `SPEC-NNN`）。 -/
structure ObligationId where
  val : String
  wf : ObligationId.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 小文字の 16 進数字か。 -/
def isLowerHex (c : Char) : Bool := c.isDigit || ('a' ≤ c && c ≤ 'f')

/-- UUID の形（小文字の 16 進数字で `8-4-4-4-12`）か。 -/
def BacklogId.valid (s : String) : Bool := go [8, 4, 4, 4, 12] s.toList
where
  /-- 残りの組の長さ `ns` に従って、16 進数字の組と区切りの `-` を読む。 -/
  go : List Nat → List Char → Bool
    | [], [] => true
    | [0], [] => true
    | 0 :: n :: ns, '-' :: cs => go (n :: ns) cs
    | (n + 1) :: ns, c :: cs => isLowerHex c && go (n :: ns) cs
    | _, _ => false

/-- 作業項目の ID（UUID）。 -/
structure BacklogId where
  val : String
  wf : BacklogId.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 空でない文字列の字面。 -/
syntax:max "ne!" str : term
/-- 空でない列の字面。 -/
syntax:max "ne![" term,+ "]" : term
/-- ギャップの ID の字面。 -/
syntax:max "gid!" str : term
/-- 証明課題の ID の字面。 -/
syntax:max "oid!" str : term
/-- 作業項目の ID の字面。 -/
syntax:max "bid!" str : term

macro_rules
  | `(ne! $s) => `(({ val := $s } : Trace.Id.NEString))
  | `(ne![ $h ]) => `(Trace.Id.NEList.mk $h [])
  | `(ne![ $h, $t,* ]) => `(Trace.Id.NEList.mk $h [$t,*])
  | `(gid! $s) => `(({ val := $s } : Trace.Id.GapId))
  | `(oid! $s) => `(({ val := $s } : Trace.Id.ObligationId))
  | `(bid! $s) => `(({ val := $s } : Trace.Id.BacklogId))

end Trace.Id
