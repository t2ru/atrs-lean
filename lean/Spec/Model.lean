import Spec.Prim

/-!
# ドメインモデル（`Spec.Model`）

列挙・コード値・エンティティ・値域。

- 列挙の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（`toCode`・`ofCode?`）。
- コード値は `String` を包む structure とする。形式の決まったコード値（空港コード・便名・カード種別コード・会員番号）は、
  形式の証明を欄（`wf`、既定 `by decide`）に持ち、形式に合わない値を表現できない（`ofString?` で読む）。マスタに存在する
  ことは `Spec.Env.MasterData` の参照関数と不変条件で表す。
- エンティティの `?` は `Option` である。採番される番号（予約番号・会員番号など）は、登録の操作で決まる。

> **区分: 要約（informative）と草案（draft）の混在。** [Spec] の定義は Lean `Spec` に形式化した（[backlog 591d](../../docs/backlog/591d-abstract-domain-types-and-master-data.md)）。各節の本文は非規範の要約であり、食い違ったら Lean が正である（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）。**[Source]** と書いた記述は、`SourceModel` に形式化するまでの草案（draft）である。
-/

namespace Spec.Model
open Spec.Prim.Text

open Spec.Prim

/-!
## 列挙

**[Spec=Source]** Lean: [`Spec.Model`](Model.lean)。列挙値の綴りは原典の Java `enum` 名と同一で、JSON・HTTP でもこの綴りを使う（Lean の `toCode`・`ofCode?`）。

| 型 | 値 | 意味 |
| --- | --- | --- |
| `FlightType` | `RT`, `OW` | 往復, 片道 |
| `BoardingClassCd` | `N`, `S` | 一般席, 特別席 |
| `FareTypeCd` | `OW`, `RT`, `RD1`, `RD7`, `ED`, `LD`, `GD`, `SOW`, `SRT`, `SRD` | [`Spec.Env.MasterData`](Env/MasterData.lean#運賃種別) |
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

**[Spec]** Lean: [`Spec.Model`](Model.lean)。`String` を包む structure で、`AirportCd`・`FlightName`・`MembershipNumber`・`CreditTypeCd` は形式の証明を値に持つ（不正な値を表せない。[ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)）。`ReserveNo` は採番の値で持つ。外部から来るコード（空席照会の条件・選択フライトの便名・マスタの問い合わせの引数）は生の文字列のまま受け、照合では値を比べる。形式に合わない DB の値は [Spec] の型で表せない（既知差異 D-027）。マスタに存在することは、マスタの参照関数と不変条件で表す（[`Spec.Env.MasterData`](Env/MasterData.lean)）。

| 型 | 形式 | 例 |
| --- | --- | --- |
| `AirportCd` | 英大文字 3 文字（マスタに存在するもの。形式は型が持つ。マスタのコードが形式に合わない場合は既知差異 D-036）。空席照会の条件の空港コードは、入力検証を通った文字列（区切り行の `NOP` を含みうる）であり `AirportCd` ではない（生の文字列）。区間の検索で見つからなければ業務エラーになる（[`Spec.Env.CodeList`](Env/CodeList.lean#空港コードリスト画面用)） | `HND` |
| `FlightName` | 1〜6 文字（マスタに存在するもの）。`"`・`,`・改行を含まない（形式 `FlightName.valid` は型が持つ。原典の列 `FLIGHT_NAME VARCHAR(6)` に文字種の制約は無く、形式に合わない DB の便名は既知差異 D-027）。選択フライトの便名は生の文字列で、便マスタを値で引く。マスタの参照の問い合わせでは、空白でない（`hasText`）ことも課す | `NTT001` |
| `MembershipNumber` | 数字 10 文字（形式は型が持つ。予約入力の会員番号は生の文字列で照合し、照合に成功した番号を登録で読む） | `0000000001` |
| `ReserveNo` | 採番の値（自然数。上限なし）で持ち、表記は 10 桁にゼロ埋めした十進文字列（採番が 10^10 以上なら 11 桁以上。[Source] との違いは既知差異 D-009）。表記を読むときは、この形でない文字列を拒む（[ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)） | `0000000123` |
| `CreditTypeCd` | 3 文字（マスタに存在するもの。形式は型が持つ） | `VIS` |
| `PasswordHash` | 不透明な文字列（[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)） | — |
-/


/-- 英大文字。 -/
def isUpperAlpha (c : Char) : Bool := inRange 0x41 0x5A c

/-- 空港コードの形式: 英大文字 3 文字（`toList` で見る）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def AirportCd.valid (s : String) : Bool := s.toList.length == 3 && s.toList.all isUpperAlpha

/-- 空港コード。形式（`AirportCd.valid`）の証明を持つ。形式に合わない DB のマスタのコードは表せない（D-036。D-027 に覆われる）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値", gap "D-036"]
structure AirportCd where
  val : String
  wf : AirportCd.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 空港コードを読む。形式に合わなければ無し。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def AirportCd.ofString? (s : String) : Option AirportCd := if h : AirportCd.valid s then some ⟨s, h⟩ else none

/-- 空港コードは値で決まる。 -/
theorem AirportCd.ext {a b : AirportCd} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めた空港コードの値は、読んだ文字列そのもの。 -/
theorem AirportCd.val_of_ofString? {s : String} {c : AirportCd} (h : AirportCd.ofString? s = some c) : c.val = s := by
  unfold AirportCd.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- 空港コードの値を読むと、その空港コード。 -/
@[simp] theorem AirportCd.ofString?_val (c : AirportCd) : AirportCd.ofString? c.val = some c := by
  simp [AirportCd.ofString?, c.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem AirportCd.ofString?_isSome_iff {s : String} : (AirportCd.ofString? s).isSome ↔ AirportCd.valid s = true := by
  unfold AirportCd.ofString?
  split <;> simp_all

/-- 便名の形式: 1〜6 文字で、`"`・`,`・改行を含まない（[Spec] の前提。ADR f353。`toList` で見る）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def FlightName.valid (s : String) : Bool :=
  1 ≤ s.toList.length && s.toList.length ≤ 6 &&
    s.toList.all (fun c => c != '"' && c != ',' && c != '\n' && c != '\r')

/-- 便名。形式（`FlightName.valid`）の証明を持つ。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure FlightName where
  val : String
  wf : FlightName.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 便名を読む。形式に合わなければ無し。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def FlightName.ofString? (s : String) : Option FlightName := if h : FlightName.valid s then some ⟨s, h⟩ else none

/-- 便名は値で決まる。 -/
theorem FlightName.ext {a b : FlightName} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めた便名の値は、読んだ文字列そのもの。 -/
theorem FlightName.val_of_ofString? {s : String} {n : FlightName} (h : FlightName.ofString? s = some n) : n.val = s := by
  unfold FlightName.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- 便名の値を読むと、その便名。 -/
@[simp] theorem FlightName.ofString?_val (n : FlightName) : FlightName.ofString? n.val = some n := by
  simp [FlightName.ofString?, n.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem FlightName.ofString?_isSome_iff {s : String} : (FlightName.ofString? s).isSome ↔ FlightName.valid s = true := by
  unfold FlightName.ofString?
  split <;> simp_all

/-- 会員番号の形式: 数字 10 文字（`toList` で見る）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def MembershipNumber.valid (s : String) : Bool := s.toList.length == 10 && s.toList.all isDigit

/-- 会員番号。形式（`MembershipNumber.valid`）の証明を持つ。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure MembershipNumber where
  val : String
  wf : MembershipNumber.valid val = true := by decide
  deriving DecidableEq, Repr

/-- 会員番号を読む。形式に合わなければ無し。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def MembershipNumber.ofString? (s : String) : Option MembershipNumber :=
  if h : MembershipNumber.valid s then some ⟨s, h⟩ else none

/-- 会員番号は値で決まる。 -/
theorem MembershipNumber.ext {a b : MembershipNumber} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めた会員番号の値は、読んだ文字列そのもの。 -/
theorem MembershipNumber.val_of_ofString? {s : String} {n : MembershipNumber} (h : MembershipNumber.ofString? s = some n) :
    n.val = s := by
  unfold MembershipNumber.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- 会員番号の値を読むと、その会員番号。 -/
@[simp] theorem MembershipNumber.ofString?_val (n : MembershipNumber) : MembershipNumber.ofString? n.val = some n := by
  simp [MembershipNumber.ofString?, n.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem MembershipNumber.ofString?_isSome_iff {s : String} :
    (MembershipNumber.ofString? s).isSome ↔ MembershipNumber.valid s = true := by
  unfold MembershipNumber.ofString?
  split <;> simp_all

/-- 予約番号。採番の値で持つ（上限を持たない。ADR 6d36）。表記 `val` は 10 桁にゼロ埋めした十進文字列で、採番が
10^10 以上なら 11 桁以上になる（[Source] のシーケンスは上限で循環する。既知差異 D-009）。どの採番の値も予約番号として
妥当なので、型は不正な値を持たない。 -/
@[spec_doc "lean/Spec/Model.lean#コード値", gap "D-009"]
structure ReserveNo where
  num : Nat
  deriving DecidableEq, Repr

/-- 予約番号の表記: 10 桁にゼロ埋めした十進文字列。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def ReserveNo.val (n : ReserveNo) : String := Spec.Prim.Format.padNat 10 n.num

/-- 予約番号の表記を読む。表記 `val` の形（10 桁以上のゼロ埋めの十進文字列）でなければ無し。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def ReserveNo.ofString? (s : String) : Option ReserveNo :=
  let n : ReserveNo := ⟨s.toList.foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0⟩
  if n.val = s then some n else none

/-- 読めた予約番号の表記は、読んだ文字列そのもの。 -/
theorem ReserveNo.val_of_ofString? {s : String} {n : ReserveNo} (h : ReserveNo.ofString? s = some n) : n.val = s := by
  unfold ReserveNo.ofString? at h
  by_cases hv : (⟨s.toList.foldl (fun acc c => acc * 10 + (c.toNat - 48)) 0⟩ : ReserveNo).val = s
  · simp only [hv, ite_true, Option.some.injEq] at h
    subst h; exact hv
  · simp only [hv, ite_false, reduceCtorEq] at h

/-- カード種別コードの形式: 3 文字（`toList` で見る）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def CreditTypeCd.valid (s : String) : Bool := s.toList.length == 3

/-- カード種別コード。形式（`CreditTypeCd.valid`）の証明を持つ。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
structure CreditTypeCd where
  val : String
  wf : CreditTypeCd.valid val = true := by decide
  deriving DecidableEq, Repr

/-- カード種別コードを読む。形式に合わなければ無し。 -/
@[spec_doc "lean/Spec/Model.lean#コード値"]
def CreditTypeCd.ofString? (s : String) : Option CreditTypeCd :=
  if h : CreditTypeCd.valid s then some ⟨s, h⟩ else none

/-- カード種別コードは値で決まる。 -/
theorem CreditTypeCd.ext {a b : CreditTypeCd} (h : a.val = b.val) : a = b := by
  cases a; cases b; cases h; rfl

/-- 読めたカード種別コードの値は、読んだ文字列そのもの。 -/
theorem CreditTypeCd.val_of_ofString? {s : String} {c : CreditTypeCd} (h : CreditTypeCd.ofString? s = some c) :
    c.val = s := by
  unfold CreditTypeCd.ofString? at h
  split at h
  · cases h; rfl
  · cases h

/-- カード種別コードの値を読むと、そのカード種別コード。 -/
@[simp] theorem CreditTypeCd.ofString?_val (c : CreditTypeCd) : CreditTypeCd.ofString? c.val = some c := by
  simp [CreditTypeCd.ofString?, c.wf]

/-- 読めるのは、形式に合うときに限る。 -/
theorem CreditTypeCd.ofString?_isSome_iff {s : String} :
    (CreditTypeCd.ofString? s).isSome ↔ CreditTypeCd.valid s = true := by
  unfold CreditTypeCd.ofString?
  split <;> simp_all

/-- パスワードのハッシュ（不透明。ADR 2d1f）。 -/
@[spec_doc "lean/Spec/Model.lean#コード値", raw_input "パスワードエンコーダのポートが返す不透明な値（ADR 2d1f）"]
structure PasswordHash where
  val : String
  deriving DecidableEq, Repr

/-! ## エンティティ -/
/-!
## エンティティ

**[Spec]** Lean: [`Spec.Model`](Model.lean)。型は [Spec] の形で示す。`?` は省略可能（`Option`）。[Source] では原典の Java クラスの同名フィールドに対応し、参照型はすべて `null` になりうる。

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
| `reserveFlights` | ReserveFlights | 片道（1 便）または往復（往路・復路の 2 便）と、搭乗者の列（1 つ） |

### ReserveFlight

| フィールド | 型 | 説明 |
| --- | --- | --- |
| `reserveFlightNo` | Nat | 登録時に採番 |
| `flight` | Flight の主キー | |

予約番号と搭乗者は予約が持つ（予約フライトに写しを置かない）。

### ReserveFlights

予約の便と搭乗者。形が型で決まる（[ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)）。

| 構築子 | 内容 |
| --- | --- |
| `oneWay(flight, passengers)` | 片道。`passengers` は `[{ passenger, passengerNo }]`（長さ 1〜6） |
| `roundTrip(outward, homeward, passengers)` | 往復。`passengers` は `[{ passenger, outwardNo, homewardNo }]`（長さ 1〜6）。**往路・復路で同一の搭乗者列**（原典は同じリストを共有する）を、1 つの列で表す |

各搭乗者は、登録時に予約フライトごとの搭乗者番号（採番）を得る。採番の順は、便の順に、予約フライト番号、搭乗者ごとの搭乗者番号である。

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
| `creditTerm` | String | `creditMonth ++ "/" ++ creditYear`（ゼロ埋めしない）。画面の選択肢から選べば `MM/YY` になるが、サーバでは保証されない（[`Spec.Validation`](Validation.lean#会員入力c1c2)）。[Source] の列は `VARCHAR(5)` で、6 文字以上はシステムエラー（既知差異 [D-018](../../docs/spec/abstraction.md#既知差異)） |
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

/-- 搭乗者。採番される搭乗者番号は、予約の登録で決まる（`OneWayPassenger`・`RoundTripPassenger`）。 -/
@[spec_doc "lean/Spec/Model.lean#passenger"]
structure Passenger where
  familyName : String
  givenName : String
  age : Nat
  gender : Gender
  membershipNumber : Option MembershipNumber
  deriving DecidableEq

/-- 予約フライト: 予約フライト番号と、フライトの主キー（予約番号・搭乗者は予約が持つ）。 -/
@[spec_doc "lean/Spec/Model.lean#reserveflight"]
structure ReserveFlight where
  reserveFlightNo : Nat
  flight : FlightKey
  deriving DecidableEq

/-- 片道の予約の搭乗者（搭乗者番号は 1 つ）。 -/
@[spec_doc "lean/Spec/Model.lean#passenger"]
structure OneWayPassenger where
  passenger : Passenger
  passengerNo : Nat
  deriving DecidableEq

/-- 往復の予約の搭乗者（往路・復路の搭乗者番号）。 -/
@[spec_doc "lean/Spec/Model.lean#passenger"]
structure RoundTripPassenger where
  passenger : Passenger
  outwardNo : Nat
  homewardNo : Nat
  deriving DecidableEq

/-- 予約の便と搭乗者: 片道は 1 便、往復は往路・復路の 2 便。搭乗者の列は 1 つで、便ごとの搭乗者番号を伴う
（往路・復路で同一の搭乗者列を持つ）。 -/
@[spec_doc "lean/Spec/Model.lean#reserveflight"]
inductive ReserveFlights where
  | oneWay (flight : ReserveFlight) (passengers : List OneWayPassenger)
  | roundTrip (outward homeward : ReserveFlight) (passengers : List RoundTripPassenger)
  deriving DecidableEq

namespace ReserveFlights

/-- 便ごとの予約フライトと、その搭乗者（搭乗者番号と搭乗者の組。搭乗者の順）。往路、復路の順。 -/
def legs : ReserveFlights → List (ReserveFlight × List (Nat × Passenger))
  | .oneWay f ps => [(f, ps.map fun p => (p.passengerNo, p.passenger))]
  | .roundTrip o h ps =>
    [(o, ps.map fun p => (p.outwardNo, p.passenger)), (h, ps.map fun p => (p.homewardNo, p.passenger))]

/-- 予約フライトの列（往路、復路の順）。 -/
def flights : ReserveFlights → List ReserveFlight
  | .oneWay f _ => [f]
  | .roundTrip o h _ => [o, h]

/-- 搭乗者の列。 -/
def passengers : ReserveFlights → List Passenger
  | .oneWay _ ps => ps.map (·.passenger)
  | .roundTrip _ _ ps => ps.map (·.passenger)

/-- 片道: 予約フライトと、採番した搭乗者番号と搭乗者の組の列から。 -/
def oneWayOf (f : ReserveFlight) (recs : List (Nat × Passenger)) : ReserveFlights :=
  .oneWay f (recs.map fun x => ⟨x.2, x.1⟩)

/-- 往復: 往路・復路の予約フライトと、それぞれで採番した搭乗者番号と搭乗者の組の列から（位置ごとに組にする。
搭乗者は往路の組のもの）。 -/
def roundTripOf (o h : ReserveFlight) (out home : List (Nat × Passenger)) : ReserveFlights :=
  .roundTrip o h (List.zipWith (fun a b => ⟨a.2, a.1, b.1⟩) out home)

theorem flights_eq (x : ReserveFlights) : x.flights = x.legs.map (·.1) := by
  cases x <;> rfl

@[simp] theorem legs_oneWayOf (f : ReserveFlight) (recs : List (Nat × Passenger)) :
    (oneWayOf f recs).legs = [(f, recs)] := by
  simp [oneWayOf, legs, List.map_map, Function.comp_def]

theorem zipWith_out : ∀ (out home : List (Nat × Passenger)), out.map (·.2) = home.map (·.2) →
    (List.zipWith (fun a b => (⟨a.2, a.1, b.1⟩ : RoundTripPassenger)) out home).map
      (fun p => (p.outwardNo, p.passenger)) = out ∧
    (List.zipWith (fun a b => (⟨a.2, a.1, b.1⟩ : RoundTripPassenger)) out home).map
      (fun p => (p.homewardNo, p.passenger)) = home
  | [], [], _ => ⟨rfl, rfl⟩
  | [], _ :: _, h => by simp at h
  | _ :: _, [], h => by simp at h
  | a :: out, b :: home, h => by
    simp only [List.map_cons, List.cons.injEq] at h
    obtain ⟨h1, h2⟩ := zipWith_out out home h.2
    simp only [List.zipWith_cons_cons, List.map_cons, h1, h2]
    exact ⟨trivial, by rw [h.1]⟩

theorem legs_roundTripOf (o h : ReserveFlight) {out home : List (Nat × Passenger)}
    (he : out.map (·.2) = home.map (·.2)) : (roundTripOf o h out home).legs = [(o, out), (h, home)] := by
  obtain ⟨h1, h2⟩ := zipWith_out out home he
  simp only [roundTripOf, legs, h1, h2]

end ReserveFlights

/-- 予約。`reserveFlights` は片道（1 便）か往復（往路・復路の 2 便）で、搭乗者の列を 1 つ持つ。 -/
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
  reserveFlights : ReserveFlights
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

[Spec] は任意精度整数で定義するが、固定長整数で実装する移植先のために値域を定める（[ADR e41d](../../docs/decision/e41d-exact-integer-arithmetic-in-abstract-model.md)）。上限の値は Lean の `Spec.Range`（[`Spec.Model`](Model.lean)）にある。マスタの値域は `MasterData.MD8`（[`Spec.Env.MasterData`](Env/MasterData.lean#不変条件spec)）である。
マスタデータと入力は次を満たすことを前提とする。入力の値域とマスタの値域（MD-8）は、[Spec] の各操作の事前条件 PRE に含める。入口の機械（画面・REST・レポート要求の受信）では、入力の値域とマスタの値域を環境の前提（`@[env_pre]`）に含め、その下で PRE が成り立つことを示す（[ADR 70eb](../../docs/decision/70eb-refinement-non-vacuity-obligations.md)、[abstraction.md](../../docs/spec/abstraction.md#入口の-r-課題)）。リファインメントの証明義務は、PRE の内についてだけ課される（[ADR 01d4](../../docs/decision/01d4-b-method-refinement-and-explicit-deviations.md)）。値域の外での移植元・移植先の振る舞いは差異ではない。

| 量 | 範囲 |
| --- | --- |
| 空港コード（マスタの `Airport.code`） | 英大文字 3 文字（型 `AirportCd` が持つ）で、コードリストの区切り行のコード `NOP` でない（MD-8） |
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
