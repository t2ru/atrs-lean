import Spec.Env.MasterData

/-!
# コードリスト（`Spec.Env.CodeList`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。

画面の選択肢と、入力検証の「コードリストに存在する」（`InCodeList`。[`Spec.Validation`](../Validation.lean)）が使う
コードリストを定める。コードリストは（コード, 表示）の組 `CodeEntry` の列で、並びは画面に表示する順である。
マスタから作るもの（空港・搭乗クラス・運賃種別・カード種別）と、固定のもの（カードの有効期限の月・年、性別、
往復・片道の別）がある。
-/

namespace Spec.Env.CodeList
open Spec.Env
open Spec.Env.MasterData (Airport Route FlightMaster BoardingClass FareType PeakTime Plane CreditType BoardingClassInfo FareTypeInfo)
open Spec.Prim.Format


/-!
## 空港コードリスト（画面用）

**[Spec=Source]** 画面の空港選択肢（`CL_AIRPORT`）は、空港を `displayOrder` 昇順に並べ、`displayOrder ≥ 100` の最初の空港の直前に区切り行 `("NOP", "-----------")` を 1 つ挿入したものである。
区切り行のコード `NOP` は空港のコードには使えない（マスタの不変条件 MD-8。[`Spec.Env.MasterData`](MasterData.lean#不変条件spec)）。

出典: `java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#retrieveMap()`, `java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_AIRPORT()`
-/


/-- コードリストの要素。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#空港コードリスト画面用"]
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
@[spec_doc "lean/Spec/Env/CodeList.lean#空港コードリスト画面用"]
def airport (md : MasterData) : List CodeEntry :=
  insertNop (md.airports.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder))

/-!
## その他のコードリスト

**[Spec=Source]** マスタから作るものは、表示順（`displayOrder`）の昇順に並べる。

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

/-- `CL_BOARDINGCLASS`: 搭乗クラスを表示順に並べたもの。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def boardingClass (md : MasterData) : List CodeEntry :=
  (md.boardingClasses.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun b =>
    ⟨b.boardingClassCd.toCode, b.boardingClassName⟩

/-- `CL_FARETYPE`: 運賃種別を表示順に並べたもの。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def fareType (md : MasterData) : List CodeEntry :=
  (md.fareTypes.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun f =>
    ⟨f.fareTypeCd.toCode, f.fareTypeName⟩

/-- `CL_CREDITTYPE`: カード種別を表示順に並べたもの。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def creditType (md : MasterData) : List CodeEntry :=
  (md.creditTypes.mergeSort fun a b => decide (a.displayOrder ≤ b.displayOrder)).map fun c =>
    ⟨c.creditTypeCd.val, c.creditFirm⟩

/-- `CL_CREDITMONTH`: `"01"`〜`"12"` -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def creditMonth : List CodeEntry := (List.range 12).map fun i => let s := padNat 2 (i + 1); ⟨s, s⟩

/-- `CL_CREDITYEAR`: `"00"`〜`"99"` -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def creditYear : List CodeEntry := (List.range 100).map fun i => let s := padNat 2 i; ⟨s, s⟩

/-- `CL_GENDER`: 性別。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def gender : List CodeEntry := [⟨"M", "男性"⟩, ⟨"F", "女性"⟩]

/-- `CL_FLIGHTTYPE`: 往復・片道の別。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#その他のコードリスト"]
def flightType : List CodeEntry := [⟨"RT", "往復"⟩, ⟨"OW", "片道"⟩]

/-!
## コードリストに存在すること（InCodeList）

**[Spec=Source]** 値がコードリストに存在するとは、いずれかの要素のコードと一致することである。空港コードリストでは、
**区切り行の `NOP` も存在するものとして扱う**。そのため `NOP` を指定した空席照会は入力検証を通過し、区間が見つからずに
業務エラー `e.ar.b1.2002` になる。
-/

/-- 値がコードリストに存在する（入力検証の `InCodeList`）。空港の区切り行 `NOP` も存在するものとして扱う。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#コードリストに存在することincodelist"]
def contains (l : List CodeEntry) (s : String) : Bool := l.any (·.code == s)

/-! ## 例 -/

/-- 例: 表示順 1・100・2 の空港では、表示順 100 の空港の直前に区切り行が入る。 -/
example :
    insertNop ([⟨{ val := "HND" }, "羽田", 1⟩, ⟨{ val := "ITM" }, "伊丹", 2⟩, ⟨{ val := "AXT" }, "秋田", 100⟩] : List Airport) =
      [⟨"HND", "羽田"⟩, ⟨"ITM", "伊丹"⟩, airportNop, ⟨"AXT", "秋田"⟩] := by decide

/-- 例: 表示順 100 以上の空港が無ければ、区切り行は入らない。 -/
example : insertNop ([⟨{ val := "HND" }, "羽田", 1⟩] : List Airport) = [⟨"HND", "羽田"⟩] := by decide

#guard creditMonth.head? == some ⟨"01", "01"⟩ && creditMonth.length == 12
#guard creditYear.getLast? == some ⟨"99", "99"⟩ && creditYear.length == 100


end Spec.Env.CodeList

/-!
## 根拠と対応

- 根拠: [ADR f353](../../../docs/decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)（区切り行のコード `NOP`）
- 既知差異: マスタに `NOP` の空港があるときの [Source] の振る舞いは D-029（参考。
  [abstraction.md](../../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）
- 移植元モデル: [`SourceModel.MasterQuery`](../../SourceModel/MasterQuery.lean)（コードリストの読み込みを含む）
- 抽象化の証明: [`Abstraction.MasterData.CodeList`](../../Abstraction/MasterData/CodeList.lean)
- 適合テストベクタ: `conformance/shared/master-data/codeList.json`
-/
