import LangSemantics.Java
import Spec.Model

/-!
# SourceModel.Config

`atrs.properties`（`META-INF/spring/atrs.properties`）の値のうち、`@Value` でサービス・ヘルパーに注入されるもの。
フィールドの型は注入先の Java の型である（`int` は `J32`、enum は `Spec.Model` の型、ほかは `String`）。
文字列からこれらの型への変換は Spring が起動時に行い、変換できない値では起動しない。
モデルは変換後の値を入力として受ける（変換できない値と、[Spec] の型で表せない値は、既知差異 D-027 の前提の外）。
-/

namespace SourceModel.Config
open LangSemantics.Java.Int LangSemantics.Java.IntLemmas

open LangSemantics.Java

/-- `@Value` で注入される設定の値。 -/
structure AtrsConfig where
  /-- `atrs.limitDay`（`TicketSharedServiceImpl`） -/
  limitDay : J32
  /-- `atrs.reserveIntervalTime`（`TicketSharedServiceImpl`・`TicketSearchHelper`） -/
  reserveIntervalTime : J32
  /-- `atrs.representativeMinAge`（`TicketReserveServiceImpl`） -/
  representativeMinAge : J32
  /-- `atrs.adultPassengerMinAge`（`TicketReserveServiceImpl`） -/
  adultPassengerMinAge : J32
  /-- `atrs.childFareRate`（`TicketReserveServiceImpl`） -/
  childFareRate : J32
  /-- `atrs.dateOfBirthMinDate`（`MemberValidator`・`MemberHelper`。`yyyy/MM/dd` の文字列のまま） -/
  dateOfBirthMinDate : String
  /-- `default.flightType`（`TicketSearchHelper`） -/
  defaultFlightType : Spec.Model.FlightType
  /-- `default.depAirportCd`（`TicketSearchHelper`） -/
  defaultDepAirportCd : String
  /-- `default.arrAirportCd`（`TicketSearchHelper`） -/
  defaultArrAirportCd : String
  /-- `default.boardingClassCd`（`TicketSearchHelper`） -/
  defaultBoardingClassCd : Spec.Model.BoardingClassCd
  deriving DecidableEq, Repr

/-- 上流の `atrs.properties` の値（配備の既定。`conformance/fixtures/config.json` はこれと同じ値を持つ。
`lake test` が突き合わせる）。 -/
@[source "prop:atrs.properties#atrs.limitDay@69f59c273b6e669a",
  "prop:atrs.properties#atrs.reserveIntervalTime@2abaca4911e68fa9",
  "prop:atrs.properties#atrs.representativeMinAge@4ec9599fc203d176",
  "prop:atrs.properties#atrs.adultPassengerMinAge@6b51d431df5d7f14",
  "prop:atrs.properties#atrs.childFareRate@39fa9ec190eee7b6",
  "prop:atrs.properties#atrs.dateOfBirthMinDate@16b66d733ba7d984",
  "prop:atrs.properties#default.flightType@3165be96f5833ae0",
  "prop:atrs.properties#default.depAirportCd@44f7c891ed8c4f86",
  "prop:atrs.properties#default.arrAirportCd@44f7c891ed8c4f86",
  "prop:atrs.properties#default.boardingClassCd@8ce86a6ae65d3692"]
def upstreamConfig : AtrsConfig where
  limitDay := J32.ofInt 90
  reserveIntervalTime := J32.ofInt 120
  representativeMinAge := J32.ofInt 18
  adultPassengerMinAge := J32.ofInt 12
  childFareRate := J32.ofInt 60
  dateOfBirthMinDate := "1900/01/01"
  defaultFlightType := .RT
  defaultDepAirportCd := "HND"
  defaultArrAirportCd := "HND"
  defaultBoardingClassCd := .N

end SourceModel.Config
