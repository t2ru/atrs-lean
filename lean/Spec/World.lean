import Spec.Model
import Spec.Env.MasterData

/-!
# 抽象状態（`Spec.World`）

> **区分: 要約（informative）と草案（draft）の混在。** 節ごとに示す。Lean に定義のある操作の本文は非規範の要約で、
> 食い違ったら Lean が正である。

ATRS の状態を変えうるデータの全体を、抽象状態 `World` として定める。成分はフライト（空席数）・会員・予約・採番の状態で
ある。設定とマスタは `World` に含めず、不変の入力（環境。[`Spec.Env`](Env.lean)）とする。

ユースケースが状態に触れる口（ポート）のうち、リポジトリ（フライト・会員・予約）と採番（`IdGenerator`）は、
`World` に対する関数として本章で意味を定める。状態を変更する各ユースケースは、これらの関数を組み合わせた
`World → 結果 × World` の 1 つの操作として原子的に実行する（並行実行の要件はモデルの外。
[`Spec.Port`](Port.lean#トランザクション)）。時計・パスワードのハッシュ・レポートのポートは [`Spec.Port`](Port.lean) にある。

[Source] は、リポジトリの操作を原典の SQL 文として持つ（移植元モデルでは `LangSemantics.Sql` の式として写す）。
-/

namespace Spec
open Spec.Model

/-!
## World（抽象状態）

**[Spec]** `World` の成分は次のとおりである。

| 成分 | 型 |
| --- | --- |
| `flights` | フライトの集合（主キーで一意。一意性の証明 `flights_nodup` を値に持つので、重複したフライトを表せない） |
| `members` | 会員の集合（会員番号で一意） |
| `reservations` | 予約の集合（予約番号で一意。予約フライト・搭乗者を含む。登録順） |
| `sequences` | 採番の状態（会員・予約・予約フライト・搭乗者。次に返す値） |

予約履歴レポート（[`Spec.Report`](Report.lean)）を形式化するときに、次の成分を足す（**草案（draft）**。Lean の `World` にはまだ無い）。

| 成分 | 型 |
| --- | --- |
| `reports` | 会員番号 ↦ （ファイル名 ↦ バイト列） |
| `queue` | レポート要求メッセージの列 |

不変条件 `World.Inv` は、フライトが主キーで一意であることである（証明フィールドが持つので、どの `World` も満たす）。
フライト・会員がマスタを参照すること（`World.RefMaster`・`World.MemberRefMaster`。DDL の外部キーに当たる）は、マスタとの組の
述語で、`World` の不変条件には含めない。必要とするユースケースが事前条件に課す（予約は課し、空席照会は課さない）。
マスタ（[`Spec.Env.MasterData`](Env/MasterData.lean)）は `World` に含めず、不変の入力とする。
-/

namespace World

/-- 採番の状態: 各 `IdGenerator` の操作が次に返す値（[IdGenerator](#idgenerator)）。値の空間は上限を持たない
（[Source] のシーケンスは上限で循環し、INT の列は上限で読み出しに失敗する。既知差異 D-009）。 -/
@[spec_doc "lean/Spec/World.lean#idgenerator", gap "D-009"]
structure Sequences where
  member : Nat := 1
  reserve : Nat := 1
  reserveFlight : Nat := 1
  passenger : Nat := 1
  deriving DecidableEq, Repr

end World


/-- 抽象状態。 -/
@[spec_doc "lean/Spec/World.lean#world抽象状態"]
structure World where
  /-- フライトの集合（主キーで一意。列の順序は意味を持たない） -/
  flights : List Flight
  /-- フライトは主キーで一意である（重複したフライトを表せない） -/
  flights_nodup : (flights.map (·.key)).Nodup := by decide
  /-- 会員の集合（会員番号で一意） -/
  members : List Member := []
  /-- 予約の集合（予約番号で一意。登録順） -/
  reservations : List Reservation := []
  /-- 採番の状態 -/
  sequences : World.Sequences := {}
  deriving DecidableEq

namespace World

/-- `World` の不変条件: フライトは主キーで一意である。主キーの一意性は `World` の証明フィールド `flights_nodup` が
持つので、どの `World` も満たす（`inv`）。抽象機械の不変条件（INV）の枠として、述語の形で置く。 -/
@[spec_doc "lean/Spec/World.lean#world抽象状態"]
def Inv (w : World) : Prop := (w.flights.map (·.key)).Nodup

instance (w : World) : Decidable w.Inv := by unfold Inv; infer_instance

/-- どの `World` も不変条件を満たす（証明フィールド `flights_nodup`）。 -/
theorem inv (w : World) : w.Inv := w.flights_nodup

/-- 空席数の更新（フライトの列の写像）は、主キーの列を変えない。 -/
theorem map_key_setVacant (fs : List Flight) (k : FlightKey) (n : Nat) :
    (fs.map fun f => if f.key == k then { f with vacantNum := n } else f).map (·.key) = fs.map (·.key) := by
  simp only [List.map_map]
  congr 1
  funext f
  simp only [Function.comp]
  split <;> rfl

/-- フライトの参照整合性（DDL の FK_FLIGHT_1〜3）: 各フライトの便名・搭乗クラス・運賃種別がマスタにある。
マスタは `World` に含めない入力なので、`World.Inv` でなく、マスタとの組の述語とする（MD-3 の残り）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec"]
def RefMaster (md : Spec.Env.MasterData) (w : World) : Prop :=
  ∀ f ∈ w.flights, (∃ m ∈ md.flightMasters, m.flightName = f.key.flightName) ∧
    (∃ b ∈ md.boardingClasses, b.boardingClassCd = f.key.boardingClassCd) ∧
    (∃ t ∈ md.fareTypes, t.fareTypeCd = f.key.fareTypeCd)

instance (md : Spec.Env.MasterData) (w : World) : Decidable (w.RefMaster md) := by
  unfold RefMaster; infer_instance

/-- 会員の参照整合性（DDL の FK_MEMBER_1）: 各会員のカード種別がマスタにある。`World.RefMaster` と同じく、マスタとの組の
述語とする。予約の PRE に含める（会員の取得は、原典ではカード種別の表と結合する）。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#不変条件spec"]
def MemberRefMaster (md : Spec.Env.MasterData) (w : World) : Prop :=
  ∀ m ∈ w.members, ∃ c ∈ md.creditTypes, c.creditTypeCd = m.creditTypeCd

instance (md : Spec.Env.MasterData) (w : World) : Decidable (w.MemberRefMaster md) := by
  unfold MemberRefMaster; infer_instance

/-!
## FlightRepository

**[Spec]** 区分: 要約（すべての操作に Lean の定義がある）。

| 操作 | 契約 |
| --- | --- |
| `findAll()` | 全フライト。絞り込み・整列は呼び出し側の純粋関数（[`Spec.FlightSearch`](FlightSearch.lean)）で行う。実装は条件を押し下げてよいが、結果は同一でなければならない |
| `exists(key)` | 主キーのフライトがあるか |
| `findForUpdate(key)` | 主キーのフライト。トランザクション終了まで他のトランザクションの同じキーへの `findForUpdate`・更新を待たせる |
| `updateVacantNum(key, n)` | 空席数を `n` にする。キーが存在しなければならない |
-/


/-- `FlightRepository.findAll`: 全フライト（絞り込み・整列は呼び出し側の純粋関数で行う）。 -/
@[spec_doc "lean/Spec/World.lean#flightrepository"]
def findAll (w : World) : List Flight := w.flights

/-- `FlightRepository.exists(key)`。 -/
@[spec_doc "lean/Spec/World.lean#flightrepository"]
def existsFlight (w : World) (k : FlightKey) : Bool := w.flights.any (·.key == k)

/-- `FlightRepository.findForUpdate(key)`。排他はモデルの外の要件で、各操作は原子的に実行される
（[トランザクション](Port.lean#トランザクション)）。 -/
@[spec_doc "lean/Spec/World.lean#flightrepository"]
def findForUpdate (w : World) (k : FlightKey) : Option Flight := w.flights.find? (·.key == k)

/-- `FlightRepository.updateVacantNum(key, n)`。 -/
@[spec_doc "lean/Spec/World.lean#flightrepository"]
def updateVacantNum (w : World) (k : FlightKey) (n : Nat) : World :=
  { w with
    flights := w.flights.map fun f => if f.key == k then { f with vacantNum := n } else f
    flights_nodup := by rw [map_key_setVacant]; exact w.flights_nodup }

/-!
## MemberRepository

**[Spec]** `find` は Lean の定義（`findMember`）の要約である。ほかの操作は、会員・認証の機能（[`Spec.Member`](Member.lean)・
[`Spec.Auth`](Auth.lean)）を形式化するときに定義する **草案（draft）** である。

| 操作 | 契約 | Lean |
| --- | --- | --- |
| `find(membershipNumber)` | 会員（ログイン情報を含む）または無し。引数は入力の文字列で、会員番号の値と比べる | `findMember` |
| `insert(member)` | 会員番号が未使用でなければならない | 草案 |
| `update(member)` | 基本情報（氏名・生年月日・性別・電話・郵便番号・住所・メール・カード情報）を置き換える | 草案 |
| `updatePassword(membershipNumber, newHash)` | `lastPassword := password`, `password := newHash` | 草案 |
| `updateLoginStatus(membershipNumber, date, flg)` | `loginDateTime := date`, `loginFlg := flg` | 草案 |
| `updateLogoutStatus(membershipNumber)` | `loginFlg := false` | 草案 |
-/


/-- `MemberRepository.find(membershipNumber)`。会員番号は入力の文字列で引く（形式に合わない文字列の会員は無い）。 -/
@[spec_doc "lean/Spec/World.lean#memberrepository"]
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

/-!
## ReservationRepository

**[Spec]** `insert` は Lean の定義（`insertReservation`）の要約である。ほかの操作は、REST の予約の確認と予約履歴レポート
（[`Spec.Http`](Http.lean)・[`Spec.Report`](Report.lean)）を形式化するときに定義する **草案（draft）** である。

| 操作 | 契約 | Lean |
| --- | --- | --- |
| `insert(reservation)` | 予約・予約フライト・搭乗者を登録する | `insertReservation` |
| `existsReserveNo(reserveNo)` | 予約があるか（REST `GET /api/v1/ticket/check`） | 草案 |
| `findHistoryByRepresentative(membershipNumber)` | `repMembershipNumber = membershipNumber` の予約の予約フライトごとの行 `{reserveNo, reserveDate, totalFare, reserveFlightNo, departureDate, flightName}`。並び `(reserveNo, reserveFlightNo)` 昇順 | 草案 |
-/


/-- `ReservationRepository.insert(reservation)`: 予約・予約フライト・搭乗者を登録する。 -/
@[spec_doc "lean/Spec/World.lean#reservationrepository"]
def insertReservation (w : World) (r : Reservation) : World := { w with reservations := w.reservations ++ [r] }

/-!
## IdGenerator

**[Spec]** 採番の状態 `World.sequences` を 1 つ進め、進める前の値を返す。`nextMembershipNumber` は会員登録
（[`Spec.Member`](Member.lean)）を形式化するときに定義する **草案（draft）** で、ほかは Lean の定義の要約である。

| 操作 | 書式 | 原典 | Lean |
| --- | --- | --- | --- |
| `nextMembershipNumber()` | 10 桁ゼロ埋め十進文字列 | `sq_member_1`（1〜9999999999, CYCLE） | 草案（状態は `sequences.member`） |
| `nextReserveNo()` | 予約番号（表記は 10 桁以上のゼロ埋め十進文字列。`ReserveNo.val`） | `sq_reservation_1`（1〜9999999999, CYCLE） | `nextReserveNo` |
| `nextReserveFlightNo()` | Nat | `sq_reserve_flight_1`（1〜999999999999, CYCLE） | `nextReserveFlightNo` |
| `nextPassengerNo()` | Nat | `sq_passenger_1`（1〜9999999999999, CYCLE） | `nextPassengerNo` |

- [Spec]: 各操作は呼ぶたびに **未使用** の値を返す（`n`, `n+1`, … と単調増加する実装を参照とする。値の空間は上限を持たない）。
- [Source]: 最大値の次は 1 に戻る。戻った値が使用済みなら、挿入時の主キー違反でシステムエラー。また、予約フライト番号・搭乗者番号は列が `INT`、採番の `selectKey` が `resultType="Integer"` なので、シーケンスの最大値より前の 2,147,483,648 から採番・挿入に失敗する（既知差異 [D-009](../../docs/spec/abstraction.md#既知差異)）。
- 採番は失敗したトランザクションでも巻き戻らない（[Spec=Source]。シーケンスの性質）。そのため、各ユースケースの「失敗時は状態が変化しない」は `World.sequences` を除いた成分についての性質である。
- 適合テストでは、fixture にシード投入後の各シーケンスの次の値（原典では会員 `8`、予約・予約フライト・搭乗者 `1`。`00230_insert_member.sql` は `nextval('sq_member_1')` を 7 回呼ぶ）を持たせ、参照実装（`n`, `n+1`, …）で採番した番号を厳密に比較する（[conformance.md](../../docs/spec/conformance.md#共有入力fixtures)）。
-/


/-- 採番の値を予約番号にする（表記は `ReserveNo.val` の 10 桁以上のゼロ埋めの十進文字列）。 -/
@[spec_doc "lean/Spec/World.lean#idgenerator"]
def reserveNoOf (n : Nat) : ReserveNo := ⟨n⟩

/-- `IdGenerator.nextReserveNo()`。 -/
@[spec_doc "lean/Spec/World.lean#idgenerator"]
def nextReserveNo (w : World) : ReserveNo × World :=
  (reserveNoOf w.sequences.reserve, { w with sequences := { w.sequences with reserve := w.sequences.reserve + 1 } })

/-- `IdGenerator.nextReserveFlightNo()`。 -/
@[spec_doc "lean/Spec/World.lean#idgenerator"]
def nextReserveFlightNo (w : World) : Nat × World :=
  (w.sequences.reserveFlight,
    { w with sequences := { w.sequences with reserveFlight := w.sequences.reserveFlight + 1 } })

/-- `IdGenerator.nextPassengerNo()`。 -/
@[spec_doc "lean/Spec/World.lean#idgenerator"]
def nextPassengerNo (w : World) : Nat × World :=
  (w.sequences.passenger, { w with sequences := { w.sequences with passenger := w.sequences.passenger + 1 } })

end World

end Spec

/-!
## 根拠と対応

- 根拠: [ADR f0e4](../../docs/decision/f0e4-functional-core-with-ports.md)（純粋な核とポート）、
  [ADR 97f9](../../docs/decision/97f9-persistence-and-transaction-semantics.md)（永続化とトランザクション）、
  [ADR 5fcb](../../docs/decision/5fcb-sql-semantics-for-source-repositories.md)（移植元のリポジトリを SQL の意味論で写す）、
  [ADR 6d36](../../docs/decision/6d36-misu-spec-types.md)（フライトの主キーの一意性を型に持たせる）、
  [ADR ce36](../../docs/decision/ce36-flight-search-stage1-world-and-arrival-time.md)（`World` の導入）
- 既知差異: 採番の上限と循環（D-009。[abstraction.md](../../docs/spec/abstraction.md#既知差異)）
- 移植元モデル: [`SourceModel.Domain.Repository`](../SourceModel/Domain/Repository/)（Mapper の SQL の写し）と、
  状態の表 [`SourceModel.Db`](../SourceModel/Db/)
- 抽象化の証明: 状態の抽象化関数 [`Abstraction.World.Alpha`](../Abstraction/World/Alpha.lean)
- 初期状態（シードを投入した後の `World`）: [`Spec.Seed.World`](Seed/World.lean)
-/
