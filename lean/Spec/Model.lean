import Spec.Prim

/-!
# Spec.Model

列挙・コード値・エンティティ・値域（`docs/spec/domain-model.md`）。

- 列挙の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（`toCode`・`ofCode?`）。
- コード値は `String` を包む structure とし、形式は述語（`WellFormed`）で表す。マスタに存在することは
  `Spec.MasterData` の参照関数と不変条件で表す。
- エンティティの `?` は `Option` である。採番される番号（予約番号・会員番号など）は、登録の操作で決まる。
-/

namespace Spec

open Spec.Prim

/-! ## 列挙 -/

/-- 往復・片道。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive FlightType where
  | RT | OW
  deriving DecidableEq, Repr

/-- 搭乗クラス（一般席・特別席）。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive BoardingClassCd where
  | N | S
  deriving DecidableEq, Repr

/-- 運賃種別。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive FareTypeCd where
  | OW | RT | RD1 | RD7 | ED | LD | GD | SOW | SRT | SRD
  deriving DecidableEq, Repr

/-- 性別。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive Gender where
  | F | M
  deriving DecidableEq, Repr

/-- 往路・復路。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
inductive LineType where
  | OUTWARD | HOMEWARD
  deriving DecidableEq, Repr

namespace FlightType
def toCode : FlightType → String | RT => "RT" | OW => "OW"
def ofCode? : String → Option FlightType | "RT" => some RT | "OW" => some OW | _ => none
theorem ofCode?_toCode (x : FlightType) : ofCode? x.toCode = some x := by cases x <;> rfl
end FlightType

namespace BoardingClassCd
def toCode : BoardingClassCd → String | N => "N" | S => "S"
def ofCode? : String → Option BoardingClassCd | "N" => some N | "S" => some S | _ => none
theorem ofCode?_toCode (x : BoardingClassCd) : ofCode? x.toCode = some x := by cases x <;> rfl
end BoardingClassCd

namespace FareTypeCd
def toCode : FareTypeCd → String
  | OW => "OW" | RT => "RT" | RD1 => "RD1" | RD7 => "RD7" | ED => "ED"
  | LD => "LD" | GD => "GD" | SOW => "SOW" | SRT => "SRT" | SRD => "SRD"
def ofCode? : String → Option FareTypeCd
  | "OW" => some OW | "RT" => some RT | "RD1" => some RD1 | "RD7" => some RD7 | "ED" => some ED
  | "LD" => some LD | "GD" => some GD | "SOW" => some SOW | "SRT" => some SRT | "SRD" => some SRD
  | _ => none
theorem ofCode?_toCode (x : FareTypeCd) : ofCode? x.toCode = some x := by cases x <;> rfl
end FareTypeCd

namespace Gender
def toCode : Gender → String | F => "F" | M => "M"
def ofCode? : String → Option Gender | "F" => some F | "M" => some M | _ => none
theorem ofCode?_toCode (x : Gender) : ofCode? x.toCode = some x := by cases x <;> rfl
end Gender

namespace LineType
def toCode : LineType → String | OUTWARD => "OUTWARD" | HOMEWARD => "HOMEWARD"
def ofCode? : String → Option LineType
  | "OUTWARD" => some OUTWARD | "HOMEWARD" => some HOMEWARD | _ => none
theorem ofCode?_toCode (x : LineType) : ofCode? x.toCode = some x := by cases x <;> rfl
/-- 表示用ラベル。 -/
def label : LineType → String | OUTWARD => "往路" | HOMEWARD => "復路"
end LineType

/-- 片道の運賃種別（この順序）。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
def oneWayFareTypes : List FareTypeCd := [.OW, .RD1, .RD7, .ED, .LD, .GD, .SOW, .SRD]

/-- 往復の運賃種別（この順序）。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
def roundTripFareTypes : List FareTypeCd := [.RT, .SRT]

/-- 搭乗の種別に対応する運賃種別。 -/
@[spec_doc "docs/spec/domain-model.md#列挙"]
def fareTypesFor : FlightType → List FareTypeCd
  | .OW => oneWayFareTypes
  | .RT => roundTripFareTypes

/-- どの運賃種別も、片道か往復のどちらか一方だけに属する。 -/
theorem fareType_partition (c : FareTypeCd) : (c ∈ oneWayFareTypes) ≠ (c ∈ roundTripFareTypes) := by
  cases c <;> decide

/-! ## コード値 -/

/-- 英大文字。 -/
def isUpperAlpha (c : Char) : Bool := inRange 0x41 0x5A c

/-- 空港コード。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure AirportCd where
  val : String
  deriving DecidableEq, Repr

/-- 空港コードの形式: 英大文字 3 文字。 -/
def AirportCd.WellFormed (c : AirportCd) : Prop := c.val.length = 3 ∧ c.val.all isUpperAlpha = true

/-- 便名。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure FlightName where
  val : String
  deriving DecidableEq, Repr

/-- 便名の形式: 1〜6 文字で、`"`・`,`・改行を含まない（[Spec] の前提）。 -/
def FlightName.WellFormed (n : FlightName) : Prop :=
  1 ≤ n.val.length ∧ n.val.length ≤ 6 ∧ n.val.all (fun c => c != '"' && c != ',' && c != '\n' && c != '\r') = true

/-- 会員番号。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure MembershipNumber where
  val : String
  deriving DecidableEq, Repr

/-- 会員番号の形式: 数字 10 文字。 -/
def MembershipNumber.WellFormed (n : MembershipNumber) : Prop := n.val.length = 10 ∧ n.val.all isDigit = true

/-- 予約番号。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure ReserveNo where
  val : String
  deriving DecidableEq, Repr

/-- 予約番号の形式: 数字 10 文字。 -/
def ReserveNo.WellFormed (n : ReserveNo) : Prop := n.val.length = 10 ∧ n.val.all isDigit = true

/-- カード種別コード。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure CreditTypeCd where
  val : String
  deriving DecidableEq, Repr

/-- カード種別コードの形式: 3 文字。 -/
def CreditTypeCd.WellFormed (c : CreditTypeCd) : Prop := c.val.length = 3

/-- パスワードのハッシュ（不透明。ADR 2d1f）。 -/
@[spec_doc "docs/spec/domain-model.md#コード値"]
structure PasswordHash where
  val : String
  deriving DecidableEq, Repr

instance (c : AirportCd) : Decidable c.WellFormed := by unfold AirportCd.WellFormed; infer_instance
instance (n : FlightName) : Decidable n.WellFormed := by unfold FlightName.WellFormed; infer_instance
instance (n : MembershipNumber) : Decidable n.WellFormed := by
  unfold MembershipNumber.WellFormed; infer_instance
instance (n : ReserveNo) : Decidable n.WellFormed := by unfold ReserveNo.WellFormed; infer_instance
instance (c : CreditTypeCd) : Decidable c.WellFormed := by unfold CreditTypeCd.WellFormed; infer_instance

/-! ## エンティティ -/

/-- フライトの主キー。 -/
@[spec_doc "docs/spec/domain-model.md#flight"]
structure FlightKey where
  departureDate : Date
  flightName : FlightName
  boardingClassCd : BoardingClassCd
  fareTypeCd : FareTypeCd
  deriving DecidableEq

/-- フライト（空席数を持つ）。 -/
@[spec_doc "docs/spec/domain-model.md#flight"]
structure Flight where
  key : FlightKey
  vacantNum : Nat
  deriving DecidableEq

/-- 搭乗者。採番される搭乗者番号は、予約の登録で決まる（`World` に置く）。 -/
@[spec_doc "docs/spec/domain-model.md#passenger"]
structure Passenger where
  familyName : String
  givenName : String
  age : Nat
  gender : Gender
  membershipNumber : Option MembershipNumber
  deriving DecidableEq

/-- 予約フライト。往路・復路で同一の搭乗者列を持つ。 -/
@[spec_doc "docs/spec/domain-model.md#reserveflight"]
structure ReserveFlight where
  reserveFlightNo : Nat
  reserveNo : ReserveNo
  flight : FlightKey
  passengers : List Passenger
  deriving DecidableEq

/-- 予約。`reserveFlights` は長さ 1（片道）または 2（往復: 往路, 復路の順）。 -/
@[spec_doc "docs/spec/domain-model.md#reservation"]
structure Reservation where
  reserveNo : ReserveNo
  reserveDate : Date
  totalFare : Nat
  repFamilyName : String
  repGivenName : String
  repAge : Nat
  repGender : Gender
  repTel : String
  repMail : String
  repMembershipNumber : Option MembershipNumber
  reserveFlights : List ReserveFlight
  deriving DecidableEq

/-- 会員のログイン情報。 -/
@[spec_doc "docs/spec/domain-model.md#memberlogin"]
structure MemberLogin where
  password : PasswordHash
  lastPassword : Option PasswordHash
  loginDateTime : Option Date
  loginFlg : Bool
  deriving DecidableEq

/-- 会員。 -/
@[spec_doc "docs/spec/domain-model.md#member"]
structure Member where
  membershipNumber : MembershipNumber
  kanjiFamilyName : String
  kanjiGivenName : String
  kanaFamilyName : String
  kanaGivenName : String
  birthday : Date
  gender : Gender
  tel : String
  zipCode : String
  address : String
  mail : String
  creditNo : String
  creditTypeCd : CreditTypeCd
  creditTerm : String
  login : MemberLogin
  deriving DecidableEq

/-! ## 値域（`docs/spec/domain-model.md#値域`。各操作の PRE に含める） -/

namespace Range

/-- `Route.basicFare + BoardingClass.extraCharge` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxBasicFareWithCharge : Nat := 10000000

/-- `PeakTime.multiplicationRatio` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxMultiplicationRatio : Nat := 1000

/-- `FareType.discountRate` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxDiscountRate : Nat := 100

/-- 搭乗者数の範囲。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def minPassengers : Nat := 1
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxPassengers : Nat := 6

/-- 予約フライト数の範囲。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def minReserveFlights : Nat := 1
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxReserveFlights : Nat := 2

/-- `Flight.vacantNum` の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxVacantNum : Nat := 2147483647

/-- 年齢の上限。 -/
@[spec_doc "docs/spec/domain-model.md#値域"]
def maxAge : Nat := 999

end Range

end Spec
