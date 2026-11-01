import Trace
import LangSemantics.Java
import LangSemantics.Sql
import LangSemantics.Sql.Postgresql
import SourceModel.Domain.Common.Util.FareUtil
import SourceModel.Domain.Model.BoardingClass
import SourceModel.Domain.Model.FareType
import SourceModel.Domain.Model.Flight
import SourceModel.Domain.Model.FlightMaster
import SourceModel.Domain.Model.Passenger
import SourceModel.Domain.Model.Route
import SourceModel.Domain.Service.B0.TicketSharedServiceImpl
import SourceModel.Db.Schema
import SourceModel.Db.Tx
import SourceModel.Domain.Common.Exception.AtrsBusinessException
import SourceModel.Domain.Common.Logging.LogMessages
import SourceModel.Domain.Model.Member
import SourceModel.Domain.Model.Reservation
import SourceModel.Domain.Model.ReserveFlight
import SourceModel.Domain.Repository.Flight.FlightRepository
import SourceModel.Domain.Repository.Member.MemberRepository
import SourceModel.Domain.Repository.Reservation.ReservationRepository
import SourceModel.Domain.Service.B2.TicketReserveDto
import SourceModel.Domain.Service.B2.TicketReserveErrorCode
import Spec.Model

/-!
# SourceModel.Domain.Service.B2.TicketReserveServiceImpl

原典の `jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl`（`atrs-domain/src/main/java/jp/co/ntt/atrs/domain/service/b2/TicketReserveServiceImpl.java`）の写し。
-/

namespace SourceModel.Domain.Service.B2
open LangSemantics.Java.DoubleOps
open LangSemantics.Java.BigDecimal LangSemantics.Java.Exception LangSemantics.Java.Spring LangSemantics.Java.Int
  LangSemantics.Java.IntLemmas
open LangSemantics.Java SourceModel.Domain.Model SourceModel.Domain.Common.Masterdata
open SourceModel.Domain.Service.B0 SourceModel.Domain.Service.B0.TicketSharedServiceImpl SourceModel.Domain.Common.Util SourceModel.Domain.Common.Util.FareUtil
  SourceModel.Domain.Service.B2

/-- `TicketReserveServiceImpl` が受ける設定（`@Value`）と、使うサービス・リポジトリ。リポジトリの文は状態の表に対する
計算（`SourceModel.Db.Tx.DbM`）なので、フィールドには持たない。`memberRepository` は、会員の文が読むマスタの表
（CREDIT_TYPE）である。 -/
structure TicketReserveServiceImpl where
  ticketSharedService : TicketSharedServiceImpl := {}
  memberRepository : SourceModel.Db.Schema.MasterDb := {}
  /-- `atrs.representativeMinAge` -/
  representativeMinAge : J32
  /-- `atrs.adultPassengerMinAge` -/
  adultPassengerMinAge : J32
  /-- `atrs.childFareRate` -/
  childFareRate : J32

namespace TicketReserveServiceImpl

/-- `calculateTotalFare`: 小児の人数を数え、フライトごとに `boardingFare * adultNum + baseFare * (childFareRate - discountRate) / 100 * childNum`
を左から int で計算して合計し、最後に `FareUtil.ceilFare` で 100 円単位に切り上げる。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#calculateTotalFare(List,List)@35bc5d27ed5f2ca9",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#calculateTotalFare(List,List)@ca1a14757ce1cb33", gap "D-003", "D-012", "D-030", "D-035"]
def calculateTotalFare (svc : TicketReserveServiceImpl) (flightList : JRef (List (JRef Flight)))
    (passengerList : JRef (List (JRef Passenger))) : JResult J32 := do
  let flights ← Assert.notEmptyValue flightList "flightList must not empty."
  let passengers ← Assert.notEmptyValue passengerList "passengerList must not empty."
  let mut childNum : J32 := J32.ofInt 0
  for passenger in passengers do
    let passenger ← Assert.notNullValue passenger "passenger must not null."
    let age ← passenger.age.deref "age"
    if java! age < svc.adultPassengerMinAge then childNum := java! childNum + 1
  let adultNum := java! ⟪J32.ofInt passengers.length⟫ - childNum
  let mut totalFare : J32 := J32.ofInt 0
  for flight in flights do
    let flight ← Assert.notNullValue flight "flight must not null."
    let flightMaster ← flight.flightMaster.deref "flightMaster"
    let route ← flightMaster.route.deref "route"
    let routeBasicFare ← route.basicFare.deref "basicFare"
    let boardingClass ← flight.boardingClass.deref "boardingClass"
    let baseFare ← calculateBasicFare svc.ticketSharedService routeBasicFare boardingClass.boardingClassCd flight.departureDate
    let fareType ← flight.fareType.deref "fareType"
    let discountRate ← fareType.discountRate.deref "discountRate"
    let boardingFare ← calculateFare baseFare discountRate
    let fare ← java! boardingFare * adultNum + baseFare * (svc.childFareRate - discountRate) / 100 * childNum
    totalFare := java! totalFare + fare
  return ceilFare totalFare

/-! ## 予約の検証・登録（backlog aedf）

クラスに `@Transactional` が付くので、公開メソッドの呼び出しはそれぞれ 1 つのトランザクションである
（`SourceModel.Db.Tx.transactional`）。 -/

open SourceModel.Db.Tx SourceModel.Domain.Common.Exception SourceModel.Domain.Common.Logging
open SourceModel.Domain.Repository.Flight SourceModel.Domain.Repository.Member SourceModel.Domain.Repository.Reservation

/-- 予約代表者の年齢（private `validateRepresentativeAge`）。 -/
def validateRepresentativeAge (svc : TicketReserveServiceImpl) (age : J32) : JResult Unit := do
  if java! age < svc.representativeMinAge then
    throw (AtrsBusinessException.newArgs (TicketReserveErrorCode.code "e.ar.b2.2004") [toString svc.representativeMinAge.val])

/-- 運賃種別の適用可否（private `validateFareType`）。 -/
def validateFareType (reserveFlightList : List (JRef ReserveFlight)) : JResult Unit := do
  for reserveFlight in reserveFlightList do
    let reserveFlight ← Assert.notNullValue reserveFlight "reserveFlight must not null."
    let flight ← reserveFlight.flight.deref "flight"
    let fareType ← flight.fareType.deref "fareType"
    let fareTypeCd := fareType.fareTypeCd
    let passengerList ← Assert.notEmptyValue reserveFlight.passengerList "passengerList must not empty."
    if fareTypeCd = some .LD then
      for passenger in passengerList do
        let passenger ← Assert.notNullValue passenger "passenger must not null."
        if passenger.gender = some .M then throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2007"))
    else if fareTypeCd = some .GD then
      let passengerMinNum ← fareType.passengerMinNum.deref "passengerMinNum"
      if java! ⟪J32.ofInt passengerList.length⟫ < passengerMinNum then
        -- 可変長引数の `null` は例外にならない（`String.valueOf` で "null"）
        throw (AtrsBusinessException.newArgs (TicketReserveErrorCode.code "e.ar.b2.2010")
          [fareType.fareTypeName.getD "null", toString passengerMinNum.val])

/-- 氏名（カナ）と性別が会員と同一か（`a.equals(b) && c.equals(d) && e.equals(f)`。左辺が `null` なら `NullPointerException`）。 -/
def sameAsMember (familyName givenName : JRef String) (gender : JRef Spec.Model.Gender) (m : Member) : JResult Bool := do
  let f ← familyName.deref "familyName"
  if f != m.kanaFamilyName then return false
  let g ← givenName.deref "givenName"
  if g != m.kanaGivenName then return false
  let x ← gender.deref "gender"
  return some x == m.gender

/-- 予約代表者の会員照合（private `validateRepresentativeMemberInfo`）。会員番号が入力されている場合だけ照合する。 -/
def validateRepresentativeMemberInfo (svc : TicketReserveServiceImpl) (reservation : Reservation) : DbM Unit := do
  let repMember ← lift (reservation.repMember.deref "repMember")
  let repMembershipNumber := repMember.membershipNumber
  if StringUtils.hasLength repMembershipNumber then
    match ← MemberRepository.findOne svc.memberRepository repMembershipNumber with
    | none => throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2002"))
    | some m =>
      if !(← lift (sameAsMember reservation.repFamilyName reservation.repGivenName reservation.repGender m)) then
        throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2003"))

/-- 搭乗者の会員照合（private `validatePassengerMemberInfo`）。予約フライトごとに、1 から数えた位置で照合する。 -/
def validatePassengerMemberInfo (svc : TicketReserveServiceImpl) (reserveFlightList : List (JRef ReserveFlight)) :
    DbM Unit := do
  for reserveFlight in reserveFlightList do
    let reserveFlight ← lift (Assert.notNullValue reserveFlight "reserveFlight must not null.")
    let passengerList ← lift (Assert.notEmptyValue reserveFlight.passengerList "passengerList must not empty.")
    let mut position : J32 := J32.ofInt 1
    for passenger in passengerList do
      let passenger ← lift (Assert.notNullValue passenger "passenger must not null.")
      let member ← lift (passenger.member.deref "member")
      let membershipNumber := member.membershipNumber
      if StringUtils.hasLength membershipNumber then
        match ← MemberRepository.findOne svc.memberRepository membershipNumber with
        | none => throw (AtrsBusinessException.newArgs (TicketReserveErrorCode.code "e.ar.b2.2005") [toString position.val])
        | some m =>
          if !(← lift (sameAsMember passenger.familyName passenger.givenName passenger.gender m)) then
            throw (AtrsBusinessException.newArgs (TicketReserveErrorCode.code "e.ar.b2.2006") [toString position.val])
      position := java! position + 1

/-- `validateReservation(reservation)`: 代表者の年齢、運賃種別の適用可否、代表者の会員照合、搭乗者の会員照合の順。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#validateReservation(Reservation)@d94a3852f47a03d1",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#validateReservation(Reservation)@66cb03764db77def"]
def validateReservation (svc : TicketReserveServiceImpl) (reservation : JRef Reservation) : DbM Unit :=
  transactional do
    let reservation ← lift (Assert.notNullValue reservation "reservation must not null.")
    let reserveFlightList ← lift (Assert.notEmptyValue reservation.reserveFlightList "reserveFlightList must not empty.")
    let repAge ← lift (reservation.repAge.deref "repAge")
    lift (validateRepresentativeAge svc repAge)
    lift (validateFareType reserveFlightList)
    validateRepresentativeMemberInfo svc reservation
    validatePassengerMemberInfo svc reserveFlightList

/-- 空席数の確認と更新（private `validateAndUpdateVacancy`）。運賃種別の予約可能判定（Clock を読む。既知差異 D-014）、
排他でのフライトの取得、空席数の検査と更新。 -/
@[gap "D-014"]
def validateAndUpdateVacancy (svc : TicketReserveServiceImpl) (reserveFlight : JRef ReserveFlight) : DbM Unit := do
  let reserveFlight ← lift (Assert.notNullValue reserveFlight "reserveFlight must not null.")
  let flight ← lift (Assert.notNullValue reserveFlight.flight "flight must not null.")
  let today ← now
  if !(← lift (isAvailableFareType flight.fareType flight.departureDate today)) then
    throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2008"))
  let fm ← lift (flight.flightMaster.deref "flightMaster")
  let locked ← FlightRepository.findOneForUpdate flight.departureDate fm.flightName flight.boardingClass flight.fareType
  let locked ← lift (locked.deref "flight")
  let vacantNum ← lift (locked.vacantNum.deref "vacantNum")
  let passengerList ← lift (reserveFlight.passengerList.deref "passengerList")
  let passengerNum := J32.ofInt passengerList.length
  if java! vacantNum < passengerNum then throw (AtrsBusinessException.new (TicketReserveErrorCode.code "e.ar.b2.2009"))
  let updated := { locked with vacantNum := some (java! vacantNum - passengerNum) }
  let flightUpdateCount ← FlightRepository.update (some updated)
  if java! flightUpdateCount != 1 then throw (LogMessages.E_AR_A0_L9002 flightUpdateCount (J32.ofInt 1))

/-- `registerReservation(reservation)`: 予約フライトごとに空席数を確認・更新し、予約・予約フライト・搭乗者を登録する。
支払期限は往路の搭乗日。 -/
@[source "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveServiceImpl#registerReservation(Reservation)@14ec7266e29f86b3",
  "java:jp.co.ntt.atrs.domain.service.b2.TicketReserveService#registerReservation(Reservation)@4df168e425feb579", gap "D-014"]
def registerReservation (svc : TicketReserveServiceImpl) (reservation : JRef Reservation) : DbM TicketReserveDto :=
  transactional do
    let reservation ← lift (Assert.notNullValue reservation "reservation must not null.")
    let reserveFlightList ← lift (Assert.notEmptyValue reservation.reserveFlightList "reserveFlightList must not empty.")
    for reserveFlight in reserveFlightList do
      validateAndUpdateVacancy svc reserveFlight
    let (reservationInsertCount, reservation) ← ReservationRepository.insert reservation
    if java! reservationInsertCount != 1 then throw (LogMessages.E_AR_A0_L9002 reservationInsertCount (J32.ofInt 1))
    let reserveNo := reservation.reserveNo
    for reserveFlight in reserveFlightList do
      let reserveFlight ← lift (reserveFlight.deref "reserveFlight")
      let (reserveFlightInsertCount, reserveFlight) ← ReservationRepository.insertReserveFlight { reserveFlight with reserveNo }
      if java! reserveFlightInsertCount != 1 then
        throw (LogMessages.E_AR_A0_L9002 reserveFlightInsertCount (J32.ofInt 1))
      for passenger in ← lift (reserveFlight.passengerList.deref "passengerList") do
        let passenger ← lift (passenger.deref "passenger")
        let (passengerInsertCount, _) ←
          ReservationRepository.insertPassenger { passenger with reserveFlightNo := reserveFlight.reserveFlightNo }
        if java! passengerInsertCount != 1 then throw (LogMessages.E_AR_A0_L9002 passengerInsertCount (J32.ofInt 1))
    let first ← lift ((← lift (JList.get reserveFlightList 0)).deref "reserveFlight")
    let paymentDate := (first.flight.bind (·.departureDate))
    let _ ← lift (first.flight.deref "flight")
    pure { reserveNo, paymentDate }

end TicketReserveServiceImpl

end SourceModel.Domain.Service.B2
