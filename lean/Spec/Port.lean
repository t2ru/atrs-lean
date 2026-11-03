import Spec.Model
import Spec.MasterData
import Spec.Prim.Format

/-!
# Spec.Port

ポートと抽象状態 `World`（`docs/spec/ports.md`）。成分はフライト・会員・予約・採番の状態で、レポートは
それを使う機能の backlog（ac71）で足す（ADR ce36）。マスタ・設定は `World` に含めず、不変の入力とする。
-/

namespace Spec.Port
open Spec.Model Spec.Prim.Format

/-- 採番の状態: 各 `IdGenerator` の操作が次に返す値（`docs/spec/ports.md#idgenerator`）。値の空間は上限を持たない
（[Source] のシーケンスは上限で循環し、INT の列は上限で読み出しに失敗する。既知差異 D-009）。 -/
@[spec_doc "docs/spec/ports.md#idgenerator", gap "D-009"]
structure Sequences where
  member : Nat := 1
  reserve : Nat := 1
  reserveFlight : Nat := 1
  passenger : Nat := 1
  deriving DecidableEq, Repr

/-- 抽象状態。 -/
@[spec_doc "docs/spec/ports.md#world抽象状態"]
structure World where
  /-- フライトの集合（主キーで一意。列の順序は意味を持たない） -/
  flights : List Flight
  /-- 会員の集合（会員番号で一意） -/
  members : List Member := []
  /-- 予約の集合（予約番号で一意。登録順） -/
  reservations : List Reservation := []
  /-- 採番の状態 -/
  sequences : Sequences := {}
  deriving DecidableEq

namespace World

/-- `World` の不変条件: フライトは主キーで一意である。会員・予約・採番の不変条件は、それを使う機械（backlog aedf の
第 2 段）で足す。 -/
@[spec_doc "docs/spec/ports.md#world抽象状態"]
def Inv (w : World) : Prop := (w.flights.map (·.key)).Nodup

instance (w : World) : Decidable w.Inv := by unfold Inv; infer_instance

/-- フライトの参照整合性（DDL の FK_FLIGHT_1〜3）: 各フライトの便名・搭乗クラス・運賃種別がマスタにある。
マスタは `World` に含めない入力なので、`World.Inv` でなく、マスタとの組の述語とする（MD-3 の残り）。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec"]
def RefMaster (md : Spec.MasterData) (w : World) : Prop :=
  ∀ f ∈ w.flights, (∃ m ∈ md.flightMasters, m.flightName = f.key.flightName) ∧
    (∃ b ∈ md.boardingClasses, b.boardingClassCd = f.key.boardingClassCd) ∧
    (∃ t ∈ md.fareTypes, t.fareTypeCd = f.key.fareTypeCd)

instance (md : Spec.MasterData) (w : World) : Decidable (w.RefMaster md) := by
  unfold RefMaster; infer_instance

/-- 会員の参照整合性（DDL の FK_MEMBER_1）: 各会員のカード種別がマスタにある。`World.RefMaster` と同じく、マスタとの組の
述語とする。予約の PRE に含める（会員の取得は、原典ではカード種別の表と結合する。backlog aedf の第 3 段）。 -/
@[spec_doc "docs/spec/master-data.md#不変条件spec"]
def MemberRefMaster (md : Spec.MasterData) (w : World) : Prop :=
  ∀ m ∈ w.members, ∃ c ∈ md.creditTypes, c.creditTypeCd = m.creditTypeCd

instance (md : Spec.MasterData) (w : World) : Decidable (w.MemberRefMaster md) := by
  unfold MemberRefMaster; infer_instance

/-! ## FlightRepository -/

/-- `FlightRepository.findAll`: 全フライト（絞り込み・整列は呼び出し側の純粋関数で行う）。 -/
@[spec_doc "docs/spec/ports.md#flightrepository"]
def findAll (w : World) : List Flight := w.flights

/-- `FlightRepository.exists(key)`。 -/
@[spec_doc "docs/spec/ports.md#flightrepository"]
def existsFlight (w : World) (k : FlightKey) : Bool := w.flights.any (·.key == k)

/-- `FlightRepository.findForUpdate(key)`。排他はモデルの外の要件で、各操作は原子的に実行される
（`docs/spec/ports.md#トランザクション`）。 -/
@[spec_doc "docs/spec/ports.md#flightrepository"]
def findForUpdate (w : World) (k : FlightKey) : Option Flight := w.flights.find? (·.key == k)

/-- `FlightRepository.updateVacantNum(key, n)`。 -/
@[spec_doc "docs/spec/ports.md#flightrepository"]
def updateVacantNum (w : World) (k : FlightKey) (n : Nat) : World :=
  { w with flights := w.flights.map fun f => if f.key == k then { f with vacantNum := n } else f }

/-! ## MemberRepository -/

/-- `MemberRepository.find(membershipNumber)`。会員番号は入力の文字列で引く（形式に合わない文字列の会員は無い）。 -/
@[spec_doc "docs/spec/ports.md#memberrepository"]
def findMember (w : World) (n : String) : Option Member := w.members.find? (·.membershipNumber.val == n)

/-- 見つかった会員の会員番号は、引いた文字列そのもの。 -/
theorem findMember_val {w : World} {n : String} {m : Member} (h : w.findMember n = some m) :
    m.membershipNumber.val = n := by
  unfold findMember at h
  simpa using List.find?_some h

/-- 会員が見つかる文字列は、会員番号として読め、その会員の会員番号になる。 -/
theorem findMember_ofString? {w : World} {n : String} {m : Member} (h : w.findMember n = some m) :
    MembershipNumber.ofString? n = some m.membershipNumber := by
  rw [← findMember_val h, MembershipNumber.ofString?_val]

/-! ## ReservationRepository -/

/-- `ReservationRepository.insert(reservation)`: 予約・予約フライト・搭乗者を登録する。 -/
@[spec_doc "docs/spec/ports.md#reservationrepository"]
def insertReservation (w : World) (r : Reservation) : World := { w with reservations := w.reservations ++ [r] }

/-! ## IdGenerator（参照実装: `n`, `n+1`, …） -/

/-- 予約番号の書式: 10 桁ゼロ埋めの十進文字列。 -/
@[spec_doc "docs/spec/ports.md#idgenerator"]
def reserveNoOf (n : Nat) : ReserveNo := ⟨n⟩

/-- `IdGenerator.nextReserveNo()`。 -/
@[spec_doc "docs/spec/ports.md#idgenerator"]
def nextReserveNo (w : World) : ReserveNo × World :=
  (reserveNoOf w.sequences.reserve, { w with sequences := { w.sequences with reserve := w.sequences.reserve + 1 } })

/-- `IdGenerator.nextReserveFlightNo()`。 -/
@[spec_doc "docs/spec/ports.md#idgenerator"]
def nextReserveFlightNo (w : World) : Nat × World :=
  (w.sequences.reserveFlight,
    { w with sequences := { w.sequences with reserveFlight := w.sequences.reserveFlight + 1 } })

/-- `IdGenerator.nextPassengerNo()`。 -/
@[spec_doc "docs/spec/ports.md#idgenerator"]
def nextPassengerNo (w : World) : Nat × World :=
  (w.sequences.passenger, { w with sequences := { w.sequences with passenger := w.sequences.passenger + 1 } })

end World

end Spec.Port
