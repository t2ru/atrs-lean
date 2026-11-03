import Spec.Prim

/-!
# ドメインモデル（`Spec.Model`）

列挙・コード値・エンティティ・値域。

- 列挙の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（`toCode`・`ofCode?`）。
- コード値は `String` を包む structure とし、形式は述語（`WellFormed`）で表す。マスタに存在することは
  `Spec.MasterData` の参照関数と不変条件で表す。
- エンティティの `?` は `Option` である。採番される番号（予約番号・会員番号など）は、登録の操作で決まる。

> **区分: 要約（informative）と草案（draft）の混在。** [Spec] の定義は Lean `Spec` に形式化した（[backlog 591d](../../docs/backlog/591d-abstract-domain-types-and-master-data.md)）。各節の本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。**[Source]** と書いた記述は、`SourceModel` に形式化するまでの草案（draft）である。
-/

namespace Spec.Model
open Spec.Prim.Text

open Spec.Prim

/-!
## 列挙

**[Spec=Source]** Lean: [`Spec.Model`]()。列挙値の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（Lean の `toCode`・`ofCode?`）。

| 型 | 値 | 意味 |
| --- | --- | --- |
| `FlightType` | `RT`, `OW` | 往復, 片道 |
| `BoardingClassCd` | `N`, `S` | 一般席, 特別席 |
| `FareTypeCd` | `OW`, `RT`, `RD1`, `RD7`, `ED`, `LD`, `GD`, `SOW`, `SRT`, `SRD` | [`Spec.MasterData`](MasterData.lean#運賃種別) |
| `Gender` | `F`, `M` | 女性, 男性 |
| `LineType` | `OUTWARD`, `HOMEWARD` | 往路, 復路（表示用ラベル「往路」「復路」） |

運賃種別の分類（出典: atrs-domain/.../common/util/FareTypeUtil.java）:

- `oneWayFareTypes = [OW, RD1, RD7, ED, LD, GD, SOW, SRD]`（この順序）
- `roundTripFareTypes = [RT, SRT]`（この順序）
- `fareTypesFor(OW) = oneWayFareTypes`、`fareTypesFor(RT) = roundTripFareTypes`
-/


/-- 往復・片道。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
inductive FlightType where
  | RT | OW
  deriving DecidableEq, Repr

/-- 搭乗クラス（一般席・特別席）。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
inductive BoardingClassCd where
  | N | S
  deriving DecidableEq, Repr

/-- 運賃種別。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
inductive FareTypeCd where
  | OW | RT | RD1 | RD7 | ED | LD | GD | SOW | SRT | SRD
  deriving DecidableEq, Repr

/-- 性別。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
inductive Gender where
  | F | M
  deriving DecidableEq, Repr

/-- 往路・復路。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
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
@[spec_doc "lean/Spec/Model.lean#列挙"]
def oneWayFareTypes : List FareTypeCd := [.OW, .RD1, .RD7, .ED, .LD, .GD, .SOW, .SRD]

/-- 往復の運賃種別（この順序）。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
def roundTripFareTypes : List FareTypeCd := [.RT, .SRT]

/-- 搭乗の種別に対応する運賃種別。 -/
@[spec_doc "lean/Spec/Model.lean#列挙"]
def fareTypesFor : FlightType → List FareTypeCd
  | .OW => oneWayFareTypes
  | .RT => roundTripFareTypes

/-- どの運賃種別も、片道か往復のどちらか一方だけに属する。 -/
theorem fareType_partition (c : FareTypeCd) : (c ∈ oneWayFareTypes) ≠ (c ∈ roundTripFareTypes) := by
  cases c <;> decide

/-!
## コード値

**[Spec]** Lean: [`Spec.Model`]()。`String` を包む structure で、形式は述語 `WellFormed` で表す。マスタに存在することは、マスタの参照関数と不変条件で表す（[`Spec.MasterData`](MasterData.lean)）。

| 型 | 形式 | 例 |
| --- | --- | --- |
| `AirportCd` | 英大文字 3 文字（マスタに存在するもの）。空席照会の条件の空港コードは、入力検証を通った文字列（区切り行の `NOP` を含みうる）であり `AirportCd` とは限らない。区間の検索で見つからなければ業務エラーになる（[`Spec.CodeList`](CodeList.lean#空港コードリスト画面用)） | `HND` |
| `FlightName` | 1〜6 文字（マスタに存在するもの）。`"`・`,`・改行を含まない（[Spec] の前提。原典の列 `FLIGHT_NAME VARCHAR(6)` に文字種の制約は無い）。マスタの参照の問い合わせでは、空白でない（`hasText`）ことも課す | `NTT001` |
| `MembershipNumber` | 数字 10 文字 | `0000000001` |
| `ReserveNo` | 数字 10 文字 | `0000000123` |
| `CreditTypeCd` | 3 文字（マスタに存在するもの） | `VIS` |
| `PasswordHash` | 不透明な文字列（[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)） | — |
-/


/-- 英大文字。 -/
def isUpperAlpha (c : Char) : Bool := inRange 0x41 0x5A c

/-- 空港コード。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure AirportCd where
  val : String
  deriving DecidableEq, Repr

/-- 空港コードの形式: 英大文字 3 文字。 -/
def AirportCd.WellFormed (c : AirportCd) : Prop := c.val.length = 3 ∧ c.val.all isUpperAlpha = true

/-- 便名。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure FlightName where
  val : String
  deriving DecidableEq, Repr

/-- 便名の形式: 1〜6 文字で、`"`・`,`・改行を含まない（[Spec] の前提）。 -/
def FlightName.WellFormed (n : FlightName) : Prop :=
  1 ≤ n.val.length ∧ n.val.length ≤ 6 ∧ n.val.all (fun c => c != '"' && c != ',' && c != '\n' && c != '\r') = true

/-- 会員番号。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure MembershipNumber where
  val : String
  deriving DecidableEq, Repr

/-- 会員番号の形式: 数字 10 文字。 -/
def MembershipNumber.WellFormed (n : MembershipNumber) : Prop := n.val.length = 10 ∧ n.val.all isDigit = true

/-- 予約番号。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure ReserveNo where
  val : String
  deriving DecidableEq, Repr

/-- 予約番号の形式: 数字 10 文字。 -/
def ReserveNo.WellFormed (n : ReserveNo) : Prop := n.val.length = 10 ∧ n.val.all isDigit = true

/-- カード種別コード。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure CreditTypeCd where
  val : String
  deriving DecidableEq, Repr

/-- カード種別コードの形式: 3 文字。 -/
def CreditTypeCd.WellFormed (c : CreditTypeCd) : Prop := c.val.length = 3

/-- パスワードのハッシュ（不透明。ADR 2d1f）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure PasswordHash where
  val : String
  deriving DecidableEq, Repr

instance (c : AirportCd) : Decidable c.WellFormed := by unfold AirportCd.WellFormed; infer_instance
instance (n : FlightName) : Decidable n.WellFormed := by unfold FlightName.WellFormed; infer_instance
instance (n : MembershipNumber) : Decidable n.WellFormed := by
  unfold MembershipNumber.WellFormed; infer_instance
instance (n : ReserveNo) : Decidable n.WellFormed := by unfold ReserveNo.WellFormed; infer_instance
instance (c : CreditTypeCd) : Decidable c.WellFormed := by unfold CreditTypeCd.WellFormed; infer_instance

/-!
## エンティティ

**[Spec]** Lean: [`Spec.Model`]()。型は [Spec] の形で示す。`?` は省略可能（`Option`）。[Source] では原典の Java クラスの同名フィールドに対応し、参照型はすべて `null` になりうる。

### Flight

| フィールド | 型 | 不変条件 |
| --- | --- | --- |
| `departureDate` | Date | |
| `flightName` | FlightName | 便マスタに存在 |
| `boardingClassCd` | BoardingClassCd | |
| `fareTypeCd` | FareTypeCd | |
| `vacantNum` | Nat | 空席数。`0` もありうる |

主キー: `(departureDate, flightName, boardingClassCd, fareTypeCd)`。

### Passenger

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `familyName` | String | 姓（全角カタカナ 1〜10 文字） |
| `givenName` | String | 名（同上） |
| `age` | Nat | 0〜999 |
| `gender` | Gender | |
| `membershipNumber` | MembershipNumber? | 会員の場合のみ |

### Reservation

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `reserveNo` | ReserveNo | 登録時に採番 |
| `reserveDate` | Date | 予約日（今日） |
| `totalFare` | Nat | 合計金額 |
| `repFamilyName`, `repGivenName` | String | 予約代表者の姓名（全角カタカナ） |
| `repAge` | Nat | |
| `repGender` | Gender | |
| `repTel` | String | `tel1-tel2-tel3`（ハイフン区切り） |
| `repMail` | String | |
| `repMembershipNumber` | MembershipNumber? | |
| `reserveFlights` | [ReserveFlight] | 長さ 1（片道）または 2（往復: 往路, 復路の順） |

### ReserveFlight

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `reserveFlightNo` | Nat | 登録時に採番 |
| `reserveNo` | ReserveNo | |
| `flight` | Flight の主キー | |
| `passengers` | [Passenger] | 長さ 1〜6。**往路・復路で同一の搭乗者列**（原典は同じリストを共有する） |

各 `Passenger` は登録時に `passengerNo`（採番）を得る。

### Member

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `membershipNumber` | MembershipNumber | 登録時に採番 |
| `kanjiFamilyName`, `kanjiGivenName` | String | 全角 1〜10 文字 |
| `kanaFamilyName`, `kanaGivenName` | String | 全角カタカナ 1〜10 文字 |
| `birthday` | Date | |
| `gender` | Gender | |
| `tel` | String | `tel1-tel2-tel3` |
| `zipCode` | String | 数字 7 文字（ハイフン無し） |
| `address` | String | 全角 1〜60 文字 |
| `mail` | String | |
| `creditNo` | String | 数字 16 文字 |
| `creditTypeCd` | CreditTypeCd | |
| `creditTerm` | String | `creditMonth ++ "/" ++ creditYear`（ゼロ埋めしない）。画面の選択肢から選べば `MM/YY` になるが、サーバでは保証されない（[`Spec.InputValidation`](InputValidation.lean#会員入力c1c2)）。[Source] の列は `VARCHAR(5)` で、6 文字以上はシステムエラー（既知差異 [D-018](../../docs/spec/abstraction.md#既知差異)） |
| `login` | MemberLogin | |

### MemberLogin

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `password` | PasswordHash | 現在のパスワード |
| `lastPassword` | PasswordHash? | 前回のパスワード |
| `loginDateTime` | Date? | 最終ログイン日（原典は `LocalDate` を `TIMESTAMP` 列に保存するため、時刻は常に 00:00） |
| `loginFlg` | Bool | ログイン中か |
-/


/-- フライトの主キー。 -/
@[spec_doc "lean/Spec/Model.lean#flight"]
structure FlightKey where
  departureDate : Date
  flightName : FlightName
  boardingClassCd : BoardingClassCd
  fareTypeCd : FareTypeCd
  deriving DecidableEq

/-- フライト（空席数を持つ）。 -/
@[spec_doc "lean/Spec/Model.lean#flight"]
structure Flight where
  key : FlightKey
  vacantNum : Nat
  deriving DecidableEq

/-- 搭乗者。採番される搭乗者番号は、予約の登録で決まる（`PassengerRecord`）。 -/
@[spec_doc "lean/Spec/Model.lean#passenger"]
structure Passenger where
  familyName : String
  givenName : String
  age : Nat
  gender : Gender
  membershipNumber : Option MembershipNumber
  deriving DecidableEq

/-- 登録した搭乗者（採番した搭乗者番号を伴う）。 -/
@[spec_doc "lean/Spec/Model.lean#passenger"]
structure PassengerRecord where
  passengerNo : Nat
  passenger : Passenger
  deriving DecidableEq

/-- 予約フライト。往路・復路で同一の搭乗者列を持つ（搭乗者番号は予約フライトごとに採番する）。 -/
@[spec_doc "lean/Spec/Model.lean#reserveflight"]
structure ReserveFlight where
  reserveFlightNo : Nat
  reserveNo : ReserveNo
  flight : FlightKey
  passengers : List PassengerRecord
  deriving DecidableEq

/-- 予約。`reserveFlights` は長さ 1（片道）または 2（往復: 往路, 復路の順）。 -/
@[spec_doc "lean/Spec/Model.lean#reservation"]
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
@[spec_doc "lean/Spec/Model.lean#memberlogin"]
structure MemberLogin where
  password : PasswordHash
  lastPassword : Option PasswordHash
  loginDateTime : Option Date
  loginFlg : Bool
  deriving DecidableEq

/-- 会員。 -/
@[spec_doc "lean/Spec/Model.lean#member"]
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

/-!
## 値域

[Spec] は任意精度整数で定義するが、固定長整数で実装する移植先のために値域を定める（[ADR e41d](../../docs/decision/e41d-exact-integer-arithmetic-in-abstract-model.md)）。上限の値は Lean の `Spec.Range`（[`Spec.Model`]()）にある。マスタの値域は `MasterData.MD8`（[`Spec.MasterData`](MasterData.lean#不変条件spec)）である。
マスタデータと入力は次を満たすことを前提とする。入力の値域とマスタの値域（MD-8）は、[Spec] の各操作の事前条件 PRE に含める。入口の機械（画面・REST・レポート要求の受信）では、入力の値域とマスタの値域を環境の前提（`@[env_pre]`）に含め、その下で PRE が成り立つことを示す（[ADR 70eb](../../docs/decision/70eb-refinement-non-vacuity-obligations.md)、[abstraction.md](../../docs/spec/abstraction.md#入口の-r-課題)）。リファインメントの証明義務は、PRE の内についてだけ課される（[ADR 01d4](../../docs/decision/01d4-b-method-refinement-and-explicit-deviations.md)）。値域の外での移植元・移植先の振る舞いは差異ではない。

| 量 | 範囲 |
| --- | --- |
| 空港コード（マスタの `Airport.code`） | 英大文字 3 文字（`AirportCd.WellFormed`）で、コードリストの区切り行のコード `NOP` でない |
| `Route.basicFare + BoardingClass.extraCharge` | `0 .. 10,000,000` |
| `PeakTime.multiplicationRatio` | `0 .. 1,000` |
| `FareType.discountRate` | `0 .. 100`（かつ `≤ childFareRate`） |
| 搭乗者数 | `1 .. 6` |
| 予約フライト数 | `1 .. 2` |
| `Flight.vacantNum` | `0 .. 2,147,483,647` |
| 年齢 | `0 .. 999` |

このとき基本運賃は `100,000,000` 以下、合計金額は `1,200,000,000` 以下であり、[Spec] の **結果** は符号付き 32 ビット整数に収まる。
ただし小児運賃の **途中計算** `b × (childFareRate − r)`（[`Spec.Fare`](Fare.lean#合計金額)）は最大 `10,000,000,000` になり、32 ビットに収まらない。

- [Source] は、この途中計算が `2,147,483,647` を超えると int32 で折り返す（既知差異 [D-012](../../docs/spec/abstraction.md#既知差異)、課題 [ABS-005](../../docs/spec/abstraction.md#証明課題)）。値域は狭めず、差異として扱う。
- 移植先（`TargetModel`）は、途中計算に 64 ビット以上の整数を使わなければならない。
-/


namespace Range

/-- `Route.basicFare + BoardingClass.extraCharge` の上限。 -/
@[spec_doc "lean/Spec/Model.lean#値域", gap "D-030"]
def maxBasicFareWithCharge : Nat := 10000000

/-- 基本運賃（`basicFare` の値）の上限。`maxBasicFareWithCharge × maxMultiplicationRatio / 100`。 -/
@[spec_doc "lean/Spec/Model.lean#値域", gap "D-030"]
def maxBasicFare : Nat := 100000000

/-- `PeakTime.multiplicationRatio` の上限。 -/
@[spec_doc "lean/Spec/Model.lean#値域", gap "D-030"]
def maxMultiplicationRatio : Nat := 1000

/-- `FareType.discountRate` の上限。 -/
@[spec_doc "lean/Spec/Model.lean#値域", gap "D-030"]
def maxDiscountRate : Nat := 100

/-- 搭乗者数の範囲。 -/
@[spec_doc "lean/Spec/Model.lean#値域"]
def minPassengers : Nat := 1
@[spec_doc "lean/Spec/Model.lean#値域"]
def maxPassengers : Nat := 6

/-- 予約フライト数の範囲。 -/
@[spec_doc "lean/Spec/Model.lean#値域"]
def minReserveFlights : Nat := 1
@[spec_doc "lean/Spec/Model.lean#値域"]
def maxReserveFlights : Nat := 2

/-- `Flight.vacantNum` の上限。 -/
@[spec_doc "lean/Spec/Model.lean#値域"]
def maxVacantNum : Nat := 2147483647

/-- 年齢の上限。 -/
@[spec_doc "lean/Spec/Model.lean#値域"]
def maxAge : Nat := 999

end Range

end Spec.Model
