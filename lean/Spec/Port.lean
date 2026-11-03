import Spec.Model
import Spec.MasterData
import Spec.Prim.Format

/-!
# ポート（`Spec.Port`）

ポートと抽象状態 `World`。成分はフライト・会員・予約・採番の状態で、レポートは
それを使う機能の backlog（ac71）で足す（ADR ce36）。マスタ・設定は `World` に含めず、不変の入力とする。

> **区分: 草案と規範の混在。** 各ポートの操作と契約の表（「World」〜「ReportQueue」の表）は **形式化前の草案（draft）** であり、Lean `Spec.Port` に形式化する。次の 4 か所は、`Spec` の関数として表現できない実行環境への要件なので **規範（normative）** としてここで定義する（[ADR 61bc](../../docs/decision/61bc-lean-spec-as-normative-source.md)）: 「Clock」節の規範段落（タイムゾーン）、「ReportStore」の `publish` の原子性のうちプロセスの異常終了に対するもの、「ReportQueue」節の規範段落のうちプロセスの異常終了をまたぐ配信保証、「トランザクション」節の並行実行の要件。採番の一意性・巻き戻らないこと、`publish` の論理的な原子性、再配信の上限の非決定性は `Spec` で表せるので、草案として `Spec.Port` に形式化する。

方針は [ADR f0e4](../../docs/decision/f0e4-functional-core-with-ports.md)、永続化とトランザクションは [ADR 97f9](../../docs/decision/97f9-persistence-and-transaction-semantics.md)。
[Spec] ではポートの操作を「抽象状態 `World` に対する関数」として意味づける。[Source] では原典の SQL 文を `LangSemantics.Sql` 上の式として写す（[ADR 5fcb](../../docs/decision/5fcb-sql-semantics-for-source-repositories.md)）。
-/

namespace Spec.Port
open Spec.Model Spec.Prim.Format

/-- 採番の状態: 各 `IdGenerator` の操作が次に返す値（`lean/Spec/Port.lean#idgenerator`）。値の空間は上限を持たない
（[Source] のシーケンスは上限で循環し、INT の列は上限で読み出しに失敗する。既知差異 D-009）。 -/
@[spec_doc "lean/Spec/Port.lean#idgenerator", gap "D-009"]
structure Sequences where
  member : Nat := 1
  reserve : Nat := 1
  reserveFlight : Nat := 1
  passenger : Nat := 1
  deriving DecidableEq, Repr

/-!
## World（抽象状態）

| 成分 | 型 |
| --- | --- |
| `flights` | フライトの集合（主キーで一意） |
| `members` | 会員の集合（会員番号で一意） |
| `reservations` | 予約の集合（予約番号で一意。予約フライト・搭乗者を含む） |
| `sequences` | 採番の状態（会員・予約・予約フライト・搭乗者） |
| `reports` | 会員番号 ↦ （ファイル名 ↦ バイト列） |
| `queue` | レポート要求メッセージの列 |

マスタ（[`Spec.MasterData`](MasterData.lean)）は `World` に含めず、不変の入力とする。
-/

/-- 抽象状態。 -/
@[spec_doc "lean/Spec/Port.lean#world抽象状態"]
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
@[spec_doc "lean/Spec/Port.lean#world抽象状態"]
def Inv (w : World) : Prop := (w.flights.map (·.key)).Nodup

instance (w : World) : Decidable w.Inv := by unfold Inv; infer_instance

/-- フライトの参照整合性（DDL の FK_FLIGHT_1〜3）: 各フライトの便名・搭乗クラス・運賃種別がマスタにある。
マスタは `World` に含めない入力なので、`World.Inv` でなく、マスタとの組の述語とする（MD-3 の残り）。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec"]
def RefMaster (md : Spec.MasterData) (w : World) : Prop :=
  ∀ f ∈ w.flights, (∃ m ∈ md.flightMasters, m.flightName = f.key.flightName) ∧
    (∃ b ∈ md.boardingClasses, b.boardingClassCd = f.key.boardingClassCd) ∧
    (∃ t ∈ md.fareTypes, t.fareTypeCd = f.key.fareTypeCd)

instance (md : Spec.MasterData) (w : World) : Decidable (w.RefMaster md) := by
  unfold RefMaster; infer_instance

/-- 会員の参照整合性（DDL の FK_MEMBER_1）: 各会員のカード種別がマスタにある。`World.RefMaster` と同じく、マスタとの組の
述語とする。予約の PRE に含める（会員の取得は、原典ではカード種別の表と結合する。backlog aedf の第 3 段）。 -/
@[spec_doc "lean/Spec/MasterData.lean#不変条件spec"]
def MemberRefMaster (md : Spec.MasterData) (w : World) : Prop :=
  ∀ m ∈ w.members, ∃ c ∈ md.creditTypes, c.creditTypeCd = m.creditTypeCd

instance (md : Spec.MasterData) (w : World) : Decidable (w.MemberRefMaster md) := by
  unfold MemberRefMaster; infer_instance

/-!
## FlightRepository

| 操作 | 契約 |
| --- | --- |
| `findAll()` | 全フライト。絞り込み・整列は呼び出し側の純粋関数（[`Spec.FlightSearch`](FlightSearch.lean)）で行う。実装は条件を押し下げてよいが、結果は同一でなければならない |
| `exists(key)` | 主キーのフライトがあるか |
| `findForUpdate(key)` | 主キーのフライト。トランザクション終了まで他のトランザクションの同じキーへの `findForUpdate`・更新を待たせる |
| `updateVacantNum(key, n)` | 空席数を `n` にする。キーが存在しなければならない |
-/


/-- `FlightRepository.findAll`: 全フライト（絞り込み・整列は呼び出し側の純粋関数で行う）。 -/
@[spec_doc "lean/Spec/Port.lean#flightrepository"]
def findAll (w : World) : List Flight := w.flights

/-- `FlightRepository.exists(key)`。 -/
@[spec_doc "lean/Spec/Port.lean#flightrepository"]
def existsFlight (w : World) (k : FlightKey) : Bool := w.flights.any (·.key == k)

/-- `FlightRepository.findForUpdate(key)`。排他はモデルの外の要件で、各操作は原子的に実行される
（`lean/Spec/Port.lean#トランザクション`）。 -/
@[spec_doc "lean/Spec/Port.lean#flightrepository"]
def findForUpdate (w : World) (k : FlightKey) : Option Flight := w.flights.find? (·.key == k)

/-- `FlightRepository.updateVacantNum(key, n)`。 -/
@[spec_doc "lean/Spec/Port.lean#flightrepository"]
def updateVacantNum (w : World) (k : FlightKey) (n : Nat) : World :=
  { w with flights := w.flights.map fun f => if f.key == k then { f with vacantNum := n } else f }

/-!
## MemberRepository

| 操作 | 契約 |
| --- | --- |
| `find(membershipNumber)` | 会員（ログイン情報を含む）または無し |
| `insert(member)` | 会員番号が未使用でなければならない |
| `update(member)` | 基本情報（氏名・生年月日・性別・電話・郵便番号・住所・メール・カード情報）を置き換える |
| `updatePassword(membershipNumber, newHash)` | `lastPassword := password`, `password := newHash` |
| `updateLoginStatus(membershipNumber, date, flg)` | `loginDateTime := date`, `loginFlg := flg` |
| `updateLogoutStatus(membershipNumber)` | `loginFlg := false` |
-/


/-- `MemberRepository.find(membershipNumber)`。 -/
@[spec_doc "lean/Spec/Port.lean#memberrepository"]
def findMember (w : World) (n : MembershipNumber) : Option Member := w.members.find? (·.membershipNumber == n)

/-!
## ReservationRepository

| 操作 | 契約 |
| --- | --- |
| `insert(reservation)` | 予約・予約フライト・搭乗者を登録する |
| `existsReserveNo(reserveNo)` | 予約があるか（REST `GET /api/v1/ticket/check`） |
| `findHistoryByRepresentative(membershipNumber)` | `repMembershipNumber = membershipNumber` の予約の予約フライトごとの行 `{reserveNo, reserveDate, totalFare, reserveFlightNo, departureDate, flightName}`。並び `(reserveNo, reserveFlightNo)` 昇順 |
-/


/-- `ReservationRepository.insert(reservation)`: 予約・予約フライト・搭乗者を登録する。 -/
@[spec_doc "lean/Spec/Port.lean#reservationrepository"]
def insertReservation (w : World) (r : Reservation) : World := { w with reservations := w.reservations ++ [r] }

/-!
## IdGenerator

| 操作 | 書式 | 原典 |
| --- | --- | --- |
| `nextMembershipNumber()` | 10 桁ゼロ埋め十進文字列 | `sq_member_1`（1〜9999999999, CYCLE） |
| `nextReserveNo()` | 10 桁ゼロ埋め十進文字列 | `sq_reservation_1`（1〜9999999999, CYCLE） |
| `nextReserveFlightNo()` | Nat | `sq_reserve_flight_1`（1〜999999999999, CYCLE） |
| `nextPassengerNo()` | Nat | `sq_passenger_1`（1〜9999999999999, CYCLE） |

- [Spec]: 各操作は呼ぶたびに **未使用** の値を返す（`n`, `n+1`, … と単調増加する実装を参照とする。値の空間は上限を持たない）。
- [Source]: 最大値の次は 1 に戻る。戻った値が使用済みなら、挿入時の主キー違反でシステムエラー。また、予約フライト番号・搭乗者番号は列が `INT`、採番の `selectKey` が `resultType="Integer"` なので、シーケンスの最大値より前の 2,147,483,648 から採番・挿入に失敗する（既知差異 [D-009](../../docs/spec/abstraction.md#既知差異)）。
- 採番は失敗したトランザクションでも巻き戻らない（[Spec=Source]。シーケンスの性質）。そのため、各ユースケースの「失敗時は状態が変化しない」は `World.sequences` を除いた成分についての性質である。
- 適合テストでは、fixture にシード投入後の各シーケンスの次の値（原典では会員 `8`、予約・予約フライト・搭乗者 `1`。`00230_insert_member.sql` は `nextval('sq_member_1')` を 7 回呼ぶ）を持たせ、参照実装（`n`, `n+1`, …）で採番した番号を厳密に比較する（[conformance.md](../../docs/spec/conformance.md#共有入力fixtures)）。
-/


/-- 予約番号の書式: 10 桁ゼロ埋めの十進文字列。 -/
@[spec_doc "lean/Spec/Port.lean#idgenerator"]
def reserveNoOf (n : Nat) : ReserveNo := ⟨padNat 10 n⟩

/-- `IdGenerator.nextReserveNo()`。 -/
@[spec_doc "lean/Spec/Port.lean#idgenerator"]
def nextReserveNo (w : World) : ReserveNo × World :=
  (reserveNoOf w.sequences.reserve, { w with sequences := { w.sequences with reserve := w.sequences.reserve + 1 } })

/-- `IdGenerator.nextReserveFlightNo()`。 -/
@[spec_doc "lean/Spec/Port.lean#idgenerator"]
def nextReserveFlightNo (w : World) : Nat × World :=
  (w.sequences.reserveFlight,
    { w with sequences := { w.sequences with reserveFlight := w.sequences.reserveFlight + 1 } })

/-- `IdGenerator.nextPassengerNo()`。 -/
@[spec_doc "lean/Spec/Port.lean#idgenerator"]
def nextPassengerNo (w : World) : Nat × World :=
  (w.sequences.passenger, { w with sequences := { w.sequences with passenger := w.sequences.passenger + 1 } })

end World

end Spec.Port

/-!
## Clock

| 操作 | 結果 |
| --- | --- |
| `today()` | Date |
| `now()` | DateTime（秒まで） |

[Spec] の各ユースケースは、初めに 1 回だけ `today()` を読み、その値を使う。[Source] は呼ぶたびに読むので、日付をまたぐ実行で異なりうる（既知差異 [D-014](../../docs/spec/abstraction.md#既知差異)）。

**規範（実行環境の要件）**: 本番の `Clock` アダプタは、現在時刻を **Asia/Tokyo**（UTC+9、夏時間なし）の暦日・時刻として返す。実行環境の既定のタイムゾーンに依存してはならない（[ADR 9ee4](../../docs/decision/9ee4-clock-timezone-and-fixture-base-date.md)。[Source] は JVM の既定のタイムゾーンで決める。既知差異 [D-023](../../docs/spec/abstraction.md#既知差異)）。テストでは任意の固定値を注入してよい。
-/

/-!
## PasswordHasher

[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)。

| 操作 | 契約 |
| --- | --- |
| `hash(raw)` | PasswordHash（非決定的でよい） |
| `matches(raw, hash)` | `matches(raw, hash(raw)) = true`。異なる `raw` では偽 |

この契約は理想化である。リファインメント定理はこの契約を仮定に置かず、各モデルのポート実装が契約を満たすことを証明する（ABS-024・REF-008）。
- 参照実装（インメモリ）と各モデルの写し（raw について単射な符号化）は、この契約を厳密に満たす。
- 実際のハッシュ関数（原典の PBKDF2 など。[ADR 2d1f](../../docs/decision/2d1f-password-hashing-port.md)）は、衝突の確率が無視できる程度にしか満たさない。モデルとの違いは保証の限界とする（[assurance.md](../../docs/spec/assurance.md)）。
-/

/-!
## ReportStore

| 操作 | 契約 |
| --- | --- |
| `writeTemp(name, bytes)` | 一時領域に書く |
| `publish(membershipNumber, name)` | 一時領域の `"tmp_" ++ name` を会員の領域の `name` へ原子的に移す。同名が既にあれば失敗 |
| `list(membershipNumber)` | 会員の領域のファイル名の集合（順序は呼び出し側で決める） |
| `read(membershipNumber, name)` | バイト列または無し |
-/

/-!
## ReportQueue

| 操作 | 契約 |
| --- | --- |
| `send(membershipNumber)` | 要求を末尾に追加する。呼び出し側のトランザクションとは独立 |
| 受信 | 1 件ずつ取り出し `onReportRequested`（[`Spec.ReservationHistoryReport`](ReservationHistoryReport.lean)）に渡す。同時に処理するのは 1 件 |

**規範（配信保証。[ADR 90f5](../../docs/decision/90f5-report-queue-at-least-once-delivery.md)）**

- 少なくとも 1 回配信する。`onReportRequested` が失敗した要求は再配信する。
- 再配信の回数には上限を設ける。上限は 1 以上の値で、実装（配備の設定）が選ぶ。[Spec] はどの値も許す（抽象側の非決定性）。上限を超えた要求は破棄してログに残す。参考値は 10 回（原典が組み込みで使う ActiveMQ Artemis の既定 `maxDeliveryAttempts = 10`。デッドレターの宛先は設定されておらず、超えた要求は破棄される）。
- 同じ要求が重複して配信されてもよい。配信の順序は保証しない。
-/

/-!
## トランザクション

**[Spec]** 状態を変更するユースケース（予約確定・会員登録・会員情報変更・ログイン/ログアウト状態更新・レポート生成）は、それぞれ原子的かつ直列化可能に実行されなければならない。この一覧を正とする（[ADR 97f9](../../docs/decision/97f9-persistence-and-transaction-semantics.md) の一覧にレポート生成を加えたもの。[ADR 578b](../../docs/decision/578b-member-update-in-single-transaction.md)）。
会員情報変更は、現在パスワードの照合（[`Spec.Member`](Member.lean#現在パスワードの照合checkmemberpassword)）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-013](../../docs/spec/abstraction.md#既知差異)）。予約確定は、予約内容の検査（`validateReservation`）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-037](../../docs/spec/abstraction.md#既知差異)）。
移植先は、この性質を満たす限り任意の実装（RDB のトランザクション、単一スレッド、楽観ロック等）を選んでよい。
- 各モデル（`Spec`・`SourceModel`・`TargetModel`）では、各ユースケースを抽象機械の 1 つの操作として原子的に扱う。
- 実際の並行実行がどれかの逐次実行と一致することは、モデルの外の要件である。確認は確認課題 SRC-005（[refinement.md](../../docs/spec/refinement.md)）の決定論的な手段で行い、確かめきれない部分は保証の限界とする（[assurance.md](../../docs/spec/assurance.md)）。
- [Source] は PostgreSQL の既定の分離レベル READ COMMITTED で動き、この要件を一般には満たさない（モデル外の既知差異 [D-025](../../docs/spec/abstraction.md#既知差異)）。

状態を変更するユースケースの [Spec] は、通常の結果に加えて、次の非決定的な結果を許す（[ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md)、[`Spec.Error`](Error.lean#分類atrserror)）。
- 出力は `Conflict`。
- `World.sequences` を除く状態は変わらない。

実装は、デッドロック・ロック待ちのタイムアウト・直列化失敗・楽観ロックの衝突を、再試行などで吸収できない場合に、この結果を選ぶ。実行可能な [Spec] の標準の選択は `Conflict` を選ばない。

同様に、ポートの I/O の失敗も、ポートの操作の非決定的な結果である。失敗しうる操作は、`FlightRepository`・`MemberRepository`・`ReservationRepository`・`IdGenerator` の全操作と、`ReportStore`・`ReportQueue` の全操作である。`Clock` と `PasswordHasher` は失敗しない。このとき、そのユースケースは次のようになる（[ADR e56e](../../docs/decision/e56e-conflict-as-spec-nondeterminism.md#実行環境の失敗)）。
- 出力は `System("e.ar.fw.9999")`（I/O 失敗のコードは、この 1 つだけとする。他のコードの `System` は非決定的な結果に含まれない）。
- `World.sequences` を除く状態は変わらない。
- 標準の選択は、この結果を選ばない。

常に失敗を返す実装もリファインメントになる。活性は [assurance.md](../../docs/spec/assurance.md) の限界とする。
-/
