import Trace
import LangSemantics.Java
import SourceModel.Repository.MasterData

/-!
# SourceModel.CodeList

コードリスト（`AtrsCodeListConfig`）。DB のコードリストは、`ORDER BY display_order` の結果の 1 つの許される順列
（`List`）を受けて作る（順列の選び方は具体機械 `SourceModel.MasterQuery.queryConcrete` が与える）。
値は `LinkedHashMap` の反復の順（`asMap()`）の（コード, 表示）の列である。

- `JdbcCodeList.retrieveMap`（terasoluna-gfw 5.11.0）: キーか表示が `null` の行は飛ばし、`put` する。
- `AirportCodeList.retrieveMap`: さらに、`displayOrder ≥ airportNopInsertOrder` の最初の行の前に区切り行を 1 回 `put` する。
- `NumberRangeCodeList`・`SimpleMapCodeList`: 固定のリスト。
-/

namespace SourceModel.CodeList
open LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java SourceModel.Repository.Schema

/-- コードリストの値（`asMap()` の反復の順）。 -/
abbrev Entries := List (String × String)

/-- `JdbcCodeList.retrieveMap`: 各行の（値の列, 表示の列）。どちらかが `null` なら飛ばす。 -/
@[source "dep:org.terasoluna.gfw:terasoluna-gfw-common#JdbcCodeList.retrieveMap@terasoluna-gfw-common-5.11.0.RELEASE"]
def jdbcCodeList (rows : List (Option String × Option String)) : Entries :=
  (rows.foldl (fun (m : JLinkedHashMap String String) r =>
    match r with
    | (some k, some v) => m.put k v
    | _ => m) {}).entries

/-- `CL_AIRPORT` の設定（`AtrsCodeListConfig`）: 区切り行の値・表示・挿入位置。 -/
structure AirportNop where
  airportNopValue : String := "NOP"
  airportNopName : String := "-----------"
  airportNopInsertOrder : J32 := J32.ofInt 100

/-- `AirportCodeList.retrieveMap`: 行は（コード, 名前, 表示順）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#retrieveMap()@ee05610976981369", gap "D-029"]
def airportCodeList (cfg : AirportNop) (rows : List (Option String × Option String × Option J32)) : Entries :=
  let step (acc : JLinkedHashMap String String × Bool) (r : Option String × Option String × Option J32) :=
    match r with
    | (some k, some v, some order) =>
      let (m, nopInserted) := acc
      let (m, nopInserted) :=
        if !nopInserted && decide (cfg.airportNopInsertOrder.val ≤ order.val) then
          (m.put cfg.airportNopValue cfg.airportNopName, true)
        else (m, nopInserted)
      (m.put k v, nopInserted)
    | _ => acc
  (rows.foldl step ({}, false)).1.entries

/-- `NumberRangeCodeList`（`from ≤ to`、間隔 1）: 各値を `String.format("%02d", i)` で書く。 -/
@[source "dep:org.terasoluna.gfw:terasoluna-gfw-common#NumberRangeCodeList.afterPropertiesSet@terasoluna-gfw-common-5.11.0.RELEASE"]
def numberRange (lo hi : Nat) : Entries :=
  (List.range (hi + 1 - lo)).map fun i =>
    let n := lo + i
    let s := if n < 10 then "0" ++ toString n else toString n
    (s, s)

/-- `CL_AIRPORT`。 -/
def airport (rows : List AirportRow) : Entries :=
  airportCodeList {} (rows.map fun r => (some r.airportCd.val, some r.airportName.val, some (J32.ofInt r.displayOrder.val)))

/-- `CL_BOARDINGCLASS`（`boarding_class_name` は `null` でありうる）。 -/
def boardingClass (rows : List BoardingClassRow) : Entries :=
  jdbcCodeList (rows.map fun r => (some r.boardingClassCd.val, r.boardingClassName.map (·.val)))

/-- `CL_FARETYPE`。 -/
def fareType (rows : List FareTypeRow) : Entries :=
  jdbcCodeList (rows.map fun r => (some r.fareTypeCd.val, some r.fareTypeName.val))

/-- `CL_CREDITTYPE`。 -/
def creditType (rows : List CreditTypeRow) : Entries :=
  jdbcCodeList (rows.map fun r => (some r.creditTypeCd.val, some r.creditFirm.val))

/-- `CL_CREDITYEAR`: 0〜99。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITYEAR()@8771de6e4c3fecac"]
def creditYear : Entries := numberRange 0 99

/-- `CL_CREDITMONTH`: 1〜12。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITMONTH()@80b00a5795cfaa5b"]
def creditMonth : Entries := numberRange 1 12

/-- `CL_GENDER`。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_GENDER()@ae7bc36378865373"]
def gender : Entries := [("M", "男性"), ("F", "女性")]

/-- `CL_FLIGHTTYPE`。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FLIGHTTYPE()@53a98f3857bc2251"]
def flightType : Entries := [("RT", "往復"), ("OW", "片道")]

#guard creditMonth.head? == some ("01", "01") && creditMonth.length == 12
#guard creditYear.getLast? == some ("99", "99") && creditYear.length == 100
#guard airportCodeList {} [(some "HND", some "羽田", some (J32.ofInt 1)), (some "AXT", some "秋田", some (J32.ofInt 100))] ==
  [("HND", "羽田"), ("NOP", "-----------"), ("AXT", "秋田")]
#guard jdbcCodeList [(some "N", some "一般席"), (some "S", none)] == [("N", "一般席")]

end SourceModel.CodeList
