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

/-- `N-NNN` の形か。 -/
def NondetId.valid (s : String) : Bool :=
  match s.toList with
  | 'N' :: '-' :: ds => digits3 ds
  | _ => false

/-- `Spec` の非決定性の ID（`N-NNN`）。 -/
structure NondetId where
  val : String
  wf : NondetId.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 英大文字か。 -/
def isUpper (c : Char) : Bool := 'A' ≤ c && c ≤ 'Z'

/-- 英大文字 1 文字以上と、任意の `-` と数字 1 文字以上（`MD-1`・`CFG`）の形か。 -/
def EnvPreId.valid (s : String) : Bool :=
  let cs := s.toList
  let pre := cs.takeWhile isUpper
  let rest := cs.drop pre.length
  !pre.isEmpty && match rest with
    | [] => true
    | '-' :: ds => !ds.isEmpty && ds.all Char.isDigit
    | _ => false

/-- 入口の環境の前提の ID（`MD-N`・`CFG` など）。 -/
structure EnvPreId where
  val : String
  wf : EnvPreId.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 文字の列が文書の拡張子（`.md`、または Lean のモジュール文書の `.lean`）で終わり、その前が空でないか。 -/
def endsWithMd (cs : List Char) : Bool :=
  match cs.reverse with
  | 'd' :: 'm' :: '.' :: _ :: _ => true
  | 'n' :: 'a' :: 'e' :: 'l' :: '.' :: _ :: _ => true
  | _ => false

/-- 文書のパス（`.md` か `.lean` で終わる）と、任意のアンカー（`#` の後。空でない）の形か。 -/
def DocAnchor.valid (s : String) : Bool :=
  let cs := s.toList
  let path := cs.takeWhile (· != '#')
  match cs.drop path.length with
  | [] => endsWithMd path
  | _ :: anchor => endsWithMd path && !anchor.isEmpty && !anchor.contains '#'

/-- 文書の節（`<path>.md`・`<path>.lean` か、その後に `#<anchor>`。`.lean` は Lean のモジュール文書の見出し）。 -/
structure DocAnchor where
  val : String
  wf : DocAnchor.valid val = true := by decide
  deriving DecidableEq, Repr

/-- ロケータと照合の記録（`<scheme>:<locator>@<pin>`。pin は検査済みハッシュか依存の版）の形か。
pin は最後の `@` の後で、空でなく `@` を含まない。scheme は空でなく、`:` の後のロケータも空でない。 -/
def Locator.valid (s : String) : Bool :=
  let rcs := s.toList.reverse
  let pin := rcs.takeWhile (· != '@')
  match rcs.drop pin.length with
  | [] => false
  | _ :: rloc =>
    let loc := rloc.reverse
    let scheme := loc.takeWhile (· != ':')
    !pin.isEmpty && !scheme.isEmpty && scheme.length + 1 < loc.length

/-- 移植元・移植先のロケータと照合の記録。 -/
structure Locator where
  val : String
  wf : Locator.valid val = true := by decide
  deriving DecidableEq, Repr

instance : ToString GapId := ⟨GapId.val⟩
instance : ToString ObligationId := ⟨ObligationId.val⟩
instance : ToString BacklogId := ⟨BacklogId.val⟩
instance : ToString NondetId := ⟨NondetId.val⟩
instance : ToString EnvPreId := ⟨EnvPreId.val⟩
instance : ToString DocAnchor := ⟨DocAnchor.val⟩
instance : ToString Locator := ⟨Locator.val⟩

/-- 文字列から ID を作る（形式に合わなければ無し）。属性の引数の解析と、式からの読み取りに使う。 -/
class OfString? (α : Type) where
  /-- 期待する形式（誤りの文に使う） -/
  form : String
  ofString? : String → Option α

instance : OfString? NEString := ⟨"a non-empty string", fun s => if h : s ≠ "" then some ⟨s, h⟩ else none⟩
instance : OfString? GapId := ⟨"D-NNN / T-NNN", fun s => if h : GapId.valid s = true then some ⟨s, h⟩ else none⟩
instance : OfString? ObligationId :=
  ⟨"ABS-NNN / REF-NNN / SPEC-NNN", fun s => if h : ObligationId.valid s = true then some ⟨s, h⟩ else none⟩
instance : OfString? BacklogId := ⟨"a UUID", fun s => if h : BacklogId.valid s = true then some ⟨s, h⟩ else none⟩
instance : OfString? NondetId := ⟨"N-NNN", fun s => if h : NondetId.valid s = true then some ⟨s, h⟩ else none⟩
instance : OfString? EnvPreId :=
  ⟨"an upper-case ID with an optional number (MD-1, CFG)", fun s => if h : EnvPreId.valid s = true then some ⟨s, h⟩ else none⟩
instance : OfString? DocAnchor :=
  ⟨"<path>.md / <path>.lean, optionally #<anchor>", fun s => if h : DocAnchor.valid s = true then some ⟨s, h⟩ else none⟩
instance : OfString? Locator :=
  ⟨"<scheme>:<locator>@<pin>", fun s => if h : Locator.valid s = true then some ⟨s, h⟩ else none⟩

instance : ToString NEString := ⟨NEString.val⟩

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
