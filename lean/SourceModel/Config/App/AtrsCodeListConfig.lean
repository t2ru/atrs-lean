import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Db.Schema
import SourceModel.Domain.Common.Codelist.AirportCodeList
import SourceModel.Gfw.CodeList
import Spec.Model

/-!
# SourceModel.Config.App.AtrsCodeListConfig

原典の `jp.co.ntt.atrs.config.app.AtrsCodeListConfig`（`atrs-domain/src/main/java/jp/co/ntt/atrs/config/app/AtrsCodeListConfig.java`）の写し。

コードリスト（`AtrsCodeListConfig`）。DB のコードリストは、`ORDER BY display_order` の結果の 1 つの許される順列
（`List`）を受けて作る（順列の選び方は具体機械 `SourceModel.MasterQuery.queryConcrete` が与える）。
値は `LinkedHashMap` の反復の順（`asMap()`）の（コード, 表示）の列である。

- `JdbcCodeList.retrieveMap`（terasoluna-gfw 5.11.0）: キーか表示が `null` の行は飛ばし、`put` する。
- `AirportCodeList.retrieveMap`: さらに、`displayOrder ≥ airportNopInsertOrder` の最初の行の前に区切り行を 1 回 `put` する。
- `NumberRangeCodeList`・`SimpleMapCodeList`: 固定のリスト。
-/

namespace SourceModel.Config.App
open LangSemantics.Sql.Core LangSemantics.Sql.Query
open LangSemantics.Sql.Postgresql SourceModel.Db.Schema
open SourceModel.Config.App
open LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Gfw.CodeList SourceModel.Domain.Common.Codelist

namespace AtrsCodeListConfig

/-- `CL_AIRPORT`: `SELECT airport_cd,airport_name,display_order FROM airport order by display_order ASC`（整列前）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_AIRPORT()@6236d6ba59dfd39c"]
def airportCodeListRows (db : MasterDb) : Bag AirportRow := db.airport

/-- `CL_BOARDINGCLASS`: `SELECT boarding_class_cd,boarding_class_name FROM boarding_class ORDER BY display_order ASC`
（整列前。整列キーのために `display_order` も持つ）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_BOARDINGCLASS()@c0ccb970d9355072"]
def boardingClassCodeListRows (db : MasterDb) : Bag BoardingClassRow := db.boardingClass

/-- `CL_FARETYPE`: `SELECT fare_type_cd, fare_type_name FROM fare_type ORDER BY display_order ASC`（整列前）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FARETYPE()@49649a5d73522449"]
def fareTypeCodeListRows (db : MasterDb) : Bag FareTypeRow := db.fareType

/-- `CL_CREDITTYPE`: `SELECT credit_type_cd, credit_firm FROM credit_type ORDER BY display_order ASC`（整列前）。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITTYPE()@14fc9ae274494f99"]
def creditTypeCodeListRows (db : MasterDb) : Bag CreditTypeRow := db.creditType

/-- `JdbcCodeList.retrieveMap`: 各行の（値の列, 表示の列）。どちらかが `null` なら飛ばす。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#jdbcTemplateForCodeList()@7719b7cc8cb21bb3",
  "dep:org.terasoluna.gfw:terasoluna-gfw-common#JdbcCodeList.retrieveMap@terasoluna-gfw-common-5.11.0.RELEASE", gap "D-015"]
def jdbcCodeList (rows : List (Option String × Option String)) : Entries :=
  (rows.foldl (fun (m : JLinkedHashMap String String) r =>
    match r with
    | (some k, some v) => m.put k v
    | _ => m) {}).entries

/-- `CL_AIRPORT`。 -/
@[gap "D-029"]
def CL_AIRPORT (rows : List AirportRow) : Entries :=
  AirportCodeList.afterPropertiesSet {} (rows.map fun r => (some r.airportCd.val, some r.airportName.val, some (J32.ofInt r.displayOrder.val)))

/-- `CL_BOARDINGCLASS`（`boarding_class_name` は `null` でありうる）。 -/
def CL_BOARDINGCLASS (rows : List BoardingClassRow) : Entries :=
  jdbcCodeList (rows.map fun r => (some r.boardingClassCd.val, r.boardingClassName.map (·.val)))

/-- `CL_FARETYPE`。 -/
def CL_FARETYPE (rows : List FareTypeRow) : Entries :=
  jdbcCodeList (rows.map fun r => (some r.fareTypeCd.val, some r.fareTypeName.val))

/-- `CL_CREDITTYPE`。 -/
def CL_CREDITTYPE (rows : List CreditTypeRow) : Entries :=
  jdbcCodeList (rows.map fun r => (some r.creditTypeCd.val, some r.creditFirm.val))

/-- `CL_CREDITYEAR`: 0〜99。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITYEAR()@8771de6e4c3fecac"]
def CL_CREDITYEAR : Entries := numberRange 0 99

/-- `CL_CREDITMONTH`: 1〜12。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_CREDITMONTH()@80b00a5795cfaa5b"]
def CL_CREDITMONTH : Entries := numberRange 1 12

/-- `CL_GENDER`。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_GENDER()@ae7bc36378865373"]
def CL_GENDER : Entries := [("M", "男性"), ("F", "女性")]

/-- `CL_FLIGHTTYPE`。 -/
@[source "java:jp.co.ntt.atrs.config.app.AtrsCodeListConfig#CL_FLIGHTTYPE()@53a98f3857bc2251"]
def CL_FLIGHTTYPE : Entries := [("RT", "往復"), ("OW", "片道")]

#guard CL_CREDITMONTH.head? == some ("01", "01") && CL_CREDITMONTH.length == 12
#guard CL_CREDITYEAR.getLast? == some ("99", "99") && CL_CREDITYEAR.length == 100
#guard AirportCodeList.afterPropertiesSet {} [(some "HND", some "羽田", some (J32.ofInt 1)), (some "AXT", some "秋田", some (J32.ofInt 100))] ==
  [("HND", "羽田"), ("NOP", "-----------"), ("AXT", "秋田")]
#guard jdbcCodeList [(some "N", some "一般席"), (some "S", none)] == [("N", "一般席")]

end AtrsCodeListConfig

end SourceModel.Config.App
