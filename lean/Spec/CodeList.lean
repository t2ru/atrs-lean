import Spec.MasterData

/-!
# Spec.CodeList

画面の選択肢と入力検証の `InCodeList` が使うコードリスト（[空港コードリスト](#空港コードリスト画面用)）。
各要素は（コード, 表示）の組で、並びは表示の順である。
-/

namespace Spec.CodeList
open Spec.MasterData (Airport Route FlightMaster BoardingClass FareType PeakTime Plane CreditType BoardingClassInfo FareTypeInfo)
open Spec.Prim.Format


/-!
## 空港コードリスト（画面用）

**[Spec=Source]** Lean: [`Spec.CodeList`]()。画面の空港選択肢（`CL_AIRPORT`）は、空港を `displayOrder` 昇順に並べ、`displayOrder ≥ 100` の最初の空港の直前に区切り行 `("NOP", "-----------")` を 1 つ挿入したものである。
入力検証の「コードリストに存在する」（[`Spec.InputValidation`](InputValidation.lean)）は **区切り行の `NOP` も存在するものとして扱う**。そのため `NOP` を指定した空席照会は入力検証を通過し、区間が見つからずに業務エラー `e.ar.b1.2002` となる。

出典: `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#retrieveMap()`, `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_AIRPORT()`

その他のコードリスト:

| ID | 値 | 表示 |
| --- | --- | --- |
| `CL_BOARDINGCLASS` | 搭乗クラスを `displayOrder` 順 | `boardingClassName` |
| `CL_FARETYPE` | 運賃種別を `displayOrder` 順 | `fareTypeName` |
| `CL_CREDITTYPE` | カード種別を `displayOrder` 順 | `creditFirm` |
| `CL_CREDITMONTH` | `"01"`〜`"12"` | 同左 |
| `CL_CREDITYEAR` | `"00"`〜`"99"` | 同左 |
| `CL_GENDER` | `M`, `F` | 男性, 女性 |
| `CL_FLIGHTTYPE` | `RT`, `OW` | 往復, 片道 |
-/

/-- コードリストの要素。 -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
structure CodeEntry where
  code : String
  label : String
  deriving DecidableEq, Repr


/-- 空港の区切り行を入れる `displayOrder` の下限。 -/
def airportNopInsertOrder : Nat := 100

/-- 空港の区切り行。 -/
def airportNop : CodeEntry := ⟨MasterData.airportNopCode, "-----------"⟩

/-- 表示順に並べた空港に、`displayOrder ≥ 100` の最初の空港の直前に区切り行を 1 つ入れる。 -/
def insertNop : List Airport → List CodeEntry
  | [] => []
  | a :: as =>
    if airportNopInsertOrder ≤ a.displayOrder then airportNop :: (a :: as).map fun a => ⟨a.code.val, a.name⟩
    else ⟨a.code.val, a.name⟩ :: insertNop as

/-- `CL_AIRPORT`: 空港を `displayOrder` 昇順に並べ、区切り行 `("NOP", "-----------")` を入れたもの。 -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def airport (md : MasterData) : List CodeEntry :=
  insertNop (md.airports.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder))

/-- `CL_BOARDINGCLASS` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def boardingClass (md : MasterData) : List CodeEntry :=
  (md.boardingClasses.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun b =>
    ⟨b.boardingClassCd.toCode, b.boardingClassName⟩

/-- `CL_FARETYPE` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def fareType (md : MasterData) : List CodeEntry :=
  (md.fareTypes.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun f =>
    ⟨f.fareTypeCd.toCode, f.fareTypeName⟩

/-- `CL_CREDITTYPE` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def creditType (md : MasterData) : List CodeEntry :=
  (md.creditTypes.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun c =>
    ⟨c.creditTypeCd.val, c.creditFirm⟩

/-- `CL_CREDITMONTH`: `"01"`〜`"12"` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def creditMonth : List CodeEntry := (List.range 12).map fun i => let s := padNat 2 (i + 1); ⟨s, s⟩

/-- `CL_CREDITYEAR`: `"00"`〜`"99"` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def creditYear : List CodeEntry := (List.range 100).map fun i => let s := padNat 2 i; ⟨s, s⟩

/-- `CL_GENDER` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def gender : List CodeEntry := [⟨"M", "男性"⟩, ⟨"F", "女性"⟩]

/-- `CL_FLIGHTTYPE` -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def flightType : List CodeEntry := [⟨"RT", "往復"⟩, ⟨"OW", "片道"⟩]

/-- 値がコードリストに存在する（入力検証の `InCodeList`）。空港の区切り行 `NOP` も存在するものとして扱う。 -/
@[spec_doc "lean/Spec/CodeList.lean#空港コードリスト画面用"]
def contains (l : List CodeEntry) (s : String) : Bool := l.any (·.code == s)

/-- 例: 表示順 1・100・2 の空港では、表示順 100 の空港の直前に区切り行が入る。 -/
example :
    insertNop ([⟨⟨"HND"⟩, "羽田", 1⟩, ⟨⟨"ITM"⟩, "伊丹", 2⟩, ⟨⟨"AXT"⟩, "秋田", 100⟩] : List Airport) =
      [⟨"HND", "羽田"⟩, ⟨"ITM", "伊丹"⟩, airportNop, ⟨"AXT", "秋田"⟩] := by decide

/-- 例: 表示順 100 以上の空港が無ければ、区切り行は入らない。 -/
example : insertNop ([⟨⟨"HND"⟩, "羽田", 1⟩] : List Airport) = [⟨"HND", "羽田"⟩] := by decide

#guard creditMonth.head? == some ⟨"01", "01"⟩ && creditMonth.length == 12
#guard creditYear.getLast? == some ⟨"99", "99"⟩ && creditYear.length == 100


end Spec.CodeList
