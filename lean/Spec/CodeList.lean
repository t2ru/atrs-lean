import Spec.MasterData

/-!
# Spec.CodeList

画面の選択肢と入力検証の `InCodeList` が使うコードリスト（`docs/spec/master-data.md#空港コードリスト画面用`）。
各要素は（コード, 表示）の組で、並びは表示の順である。
-/

namespace Spec

open Spec.Prim

/-- コードリストの要素。 -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
structure CodeEntry where
  code : String
  label : String
  deriving DecidableEq, Repr

namespace CodeList

/-- 空港の区切り行を入れる `displayOrder` の下限。 -/
def airportNopInsertOrder : Nat := 100

/-- 空港の区切り行。 -/
def airportNop : CodeEntry := ⟨"NOP", "-----------"⟩

/-- 表示順に並べた空港に、`displayOrder ≥ 100` の最初の空港の直前に区切り行を 1 つ入れる。 -/
def insertNop : List Airport → List CodeEntry
  | [] => []
  | a :: as =>
    if airportNopInsertOrder ≤ a.displayOrder then airportNop :: (a :: as).map fun a => ⟨a.code.val, a.name⟩
    else ⟨a.code.val, a.name⟩ :: insertNop as

/-- `CL_AIRPORT`: 空港を `displayOrder` 昇順に並べ、区切り行 `("NOP", "-----------")` を入れたもの。 -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def airport (md : MasterData) : List CodeEntry :=
  insertNop (md.airports.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder))

/-- `CL_BOARDINGCLASS` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def boardingClass (md : MasterData) : List CodeEntry :=
  (md.boardingClasses.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun b =>
    ⟨b.boardingClassCd.toCode, b.boardingClassName⟩

/-- `CL_FARETYPE` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def fareType (md : MasterData) : List CodeEntry :=
  (md.fareTypes.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun f =>
    ⟨f.fareTypeCd.toCode, f.fareTypeName⟩

/-- `CL_CREDITTYPE` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def creditType (md : MasterData) : List CodeEntry :=
  (md.creditTypes.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun c =>
    ⟨c.creditTypeCd.val, c.creditFirm⟩

/-- `CL_CREDITMONTH`: `"01"`〜`"12"` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def creditMonth : List CodeEntry := (List.range 12).map fun i => let s := padNat 2 (i + 1); ⟨s, s⟩

/-- `CL_CREDITYEAR`: `"00"`〜`"99"` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def creditYear : List CodeEntry := (List.range 100).map fun i => let s := padNat 2 i; ⟨s, s⟩

/-- `CL_GENDER` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def gender : List CodeEntry := [⟨"M", "男性"⟩, ⟨"F", "女性"⟩]

/-- `CL_FLIGHTTYPE` -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def flightType : List CodeEntry := [⟨"RT", "往復"⟩, ⟨"OW", "片道"⟩]

/-- 値がコードリストに存在する（入力検証の `InCodeList`）。空港の区切り行 `NOP` も存在するものとして扱う。 -/
@[spec_doc "docs/spec/master-data.md#空港コードリスト画面用"]
def contains (l : List CodeEntry) (s : String) : Bool := l.any (·.code == s)

/-- 例: 表示順 1・100・2 の空港では、表示順 100 の空港の直前に区切り行が入る。 -/
example :
    insertNop ([⟨⟨"HND"⟩, "羽田", 1⟩, ⟨⟨"ITM"⟩, "伊丹", 2⟩, ⟨⟨"AXT"⟩, "秋田", 100⟩] : List Airport) =
      [⟨"HND", "羽田"⟩, ⟨"ITM", "伊丹"⟩, airportNop, ⟨"AXT", "秋田"⟩] := by decide

/-- 例: 表示順 100 以上の空港が無ければ、区切り行は入らない。 -/
example : insertNop ([⟨⟨"HND"⟩, "羽田", 1⟩] : List Airport) = [⟨"HND", "羽田"⟩] := by decide

#guard creditMonth.head? == some ⟨"01", "01"⟩ && creditMonth.length == 12
#guard creditYear.getLast? == some ⟨"99", "99"⟩ && creditYear.length == 100

end CodeList

end Spec
