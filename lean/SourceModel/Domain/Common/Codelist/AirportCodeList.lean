import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Gfw.CodeList
import Spec.Model

/-!
# SourceModel.Domain.Common.Codelist.AirportCodeList

原典の `jp.co.ntt.atrs.domain.common.codelist.AirportCodeList`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/common/codelist/AirportCodeList.java`）の写し。
-/

namespace SourceModel.Domain.Common.Codelist
open LangSemantics.Java.HashMap LangSemantics.Java.Int LangSemantics.Java.IntLemmas
open LangSemantics.Java
open SourceModel.Gfw.CodeList SourceModel.Domain.Common.Codelist

/-- `CL_AIRPORT` の設定（`AtrsCodeListConfig`）: 区切り行の値・表示・挿入位置。 -/
structure AirportCodeList where
  airportNopValue : String := "NOP"
  airportNopName : String := "-----------"
  airportNopInsertOrder : J32 := J32.ofInt 100

namespace AirportCodeList

/-- `AirportCodeList.retrieveMap`: 行は（コード, 名前, 表示順）。 -/
@[source "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#afterPropertiesSet()@b418d81d146f85b8",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setAirportNopInsertOrder(int)@4315f7151eeddd11",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setAirportNopName(String)@43f9d2d05dbfb456",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setAirportNopValue(String)@c833910b855ec69d",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setDataSource(DataSource)@be6d1fb6e225aecc",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setJdbcTemplate(JdbcTemplate)@6e673815724a50bf",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setLabelColumn(String)@a20c04fdbe9c4744",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setOrderColumn(String)@79c49c88225297cd",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setQuerySql(String)@35a9be27051026b5",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#setValueColumn(String)@3ce171d35383e4f7",
  "java:jp.co.ntt.atrs.domain.common.codelist.AirportCodeList#retrieveMap()@ee05610976981369", gap "D-029"]
def afterPropertiesSet (cfg : AirportCodeList) (rows : List (Option String × Option String × Option J32)) : Entries :=
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

end AirportCodeList

end SourceModel.Domain.Common.Codelist
