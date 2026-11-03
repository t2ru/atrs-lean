import Abstraction.MasterData.AlphaLeaf
import Abstraction.MasterData.Alpha
import Abstraction.Fare.TotalAlpha
import Abstraction.World.Alpha
import Spec.UseCase.Reserve
import SourceModel.ReserveQuery

/-!
# Abstraction.Reserve.Alpha

予約（R 課題 ABS-041）の標準の抽象化 α と、前提型の差異の述語（backlog aedf の第 3 段。
`docs/spec/abstraction.md#抽象化関数-α`）。

- 状態: 空席照会と共有する `Abstraction.World.Alpha.worldOfDb` と、具体側の不変条件 `IcW`（貼り合わせの `J` が同じ）。
- 入力: 設定・マスタは ABS-026 の `configOf`・`masterDataOf`、今日は Clock の最初の読み出し（`dateOfJ`。D-014 の前提で、
  どの読み出しも同じ日付）、選択フライトは `keyOfForm`、予約フォームは各欄をそのまま（年齢は `natOfJ32`）。
  実行環境の障害（I/O の失敗・排他の失敗の位置）は抽象側の入力に無い（[Spec] の環境の選択 N-001・N-002 に当たる）。
- 出力: 合計金額・予約番号・支払期限と、業務例外（コードと引数）・不正要求（`InvalidRequest`。詳細は自由な選択 N-004 で
  置き換える）・I/O の失敗（`System("e.ar.fw.9999")`）・排他の失敗（`Conflict`）。
-/

namespace Abstraction.Reserve.Alpha
open Abstraction.MasterData.AlphaLeaf Abstraction.MasterData.Alpha Abstraction.Fare.TotalAlpha Abstraction.World.Alpha
  Spec.Model Machine.Kernel
open Machine.Preserves (KernelIs)
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Java.Int Spec.UseCase.Reserve

/-! ## 入力 -/

/-- 年齢の欄（`null` は未入力、負の値には定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def optAgeOf : JRef J32 → Option (Option Nat)
  | none => some none
  | some a => (natOfJ32 a).map some

@[obligation "ABS-048"]
theorem optAgeOf_kernel : KernelIs optAgeOf (undefOrEq optAgeOf) := by
  apply kernelIs_undefOrEq
  intro x y b hx hy
  cases x <;> cases y <;> simp only [optAgeOf, Option.some.injEq, Option.map_eq_some_iff] at hx hy
  · rfl
  · obtain ⟨_, _, rfl⟩ := hy; cases hx
  · obtain ⟨_, _, rfl⟩ := hx; cases hy
  · obtain ⟨n, hn, rfl⟩ := hx
    obtain ⟨n', hn', he⟩ := hy
    cases he
    rw [inj_of_kernel natOfJ32_kernel hn hn']

/-- 操作の種類。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def opOf : SourceModel.ReserveQuery.Kind → Option Op
  | .confirm => some .confirm
  | .reserve => some .reserve

@[obligation "ABS-048"]
theorem opOf_kernel : KernelIs opOf (undefOrEq opOf) := by
  apply kernelIs_undefOrEq
  intro x y b hx hy
  cases x <;> cases y <;> simp only [opOf, Option.some.injEq] at hx hy <;> (try subst hx) <;> first | rfl | cases hy

/-- 選択フライト情報（`null` には定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def selectOfForm (f : SourceModel.App.B0.SelectFlightForm) : Option Spec.Ticket.SelectFlight :=
  (keyOfForm f).map fun k => ⟨k.departureDate, k.flightName, k.boardingClassCd, k.fareTypeCd⟩

/-- 搭乗者情報フォーム（年齢は `optAgeOf`）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def passengerInputOf (p : SourceModel.App.B2.PassengerForm) : Option PassengerInput :=
  (optAgeOf p.age).map fun a => ⟨p.familyName, p.givenName, a, p.gender, p.membershipNumber⟩

/-- 予約フォームの予約入力の部分（代表者の欄は `null` に定義しない。年齢は負の値に定義しない）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def reserveInputOf (f : SourceModel.App.B2.TicketReserveForm) : Option ReserveInput :=
  f.repFamilyName.bind fun fn => f.repGivenName.bind fun gn => (f.repAge.bind natOfJ32).bind fun age =>
    f.repGender.bind fun g => f.repTel1.bind fun t1 => f.repTel2.bind fun t2 => f.repTel3.bind fun t3 =>
      f.repMail.bind fun ml => (f.passengerFormList.mapM passengerInputOf).map fun ps =>
        ⟨fn, gn, age, g, t1, t2, t3, ml, f.repMembershipNumber, ps⟩

/-- 予約の要求（選択フライトと予約入力）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def requestOf (f : SourceModel.App.B2.TicketReserveForm) : Option Request :=
  (f.selectFlightFormList.mapM selectOfForm).bind fun ss => (reserveInputOf f).map fun r => ⟨ss, r⟩

/-- 入力: 設定・マスタ・今日（Clock の最初の読み出し）・要求・操作の種類。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aiR (ic : SourceModel.ReserveQuery.MInput) : Option MInput :=
  (configOf ic.input.config).bind fun cfg => (masterDataOf ic.input.db).bind fun md =>
    (dateOfJ (ic.input.env.clock 0)).bind fun today => (requestOf ic.input.form).bind fun req =>
      (opOf ic.kind).map fun op => ⟨cfg, md, today, req, op⟩

/-! ## 出力 -/

/-- 出力: 合計金額・予約番号・支払期限と、例外の出力の値。不正要求の詳細は空文字に写す（[Spec] の詳細は自由な選択 N-004
で置き換える）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def aoR : SourceModel.ReserveQuery.MOutput → Option MOutput
  | .ok (.confirmed o) => (natOfJ32 o.totalFare).map fun n => .ok (.confirmed n)
  | .ok (.reserved o) =>
    (o.reserveNo.bind Spec.Model.ReserveNo.ofString?).bind fun no => (o.paymentDate.bind dateOfJ).bind fun d =>
      (o.totalFare.bind natOfJ32).map fun tf => .ok (.reserved ⟨no, d, tf⟩)
  | .error (.business c a) => some (.error (.business c a))
  | .error .badRequest => some (.error (.invalidRequest ""))
  | .error .ioFailure => some (.error (.system "e.ar.fw.9999"))
  | .error .conflict => some (.error (.conflict "conflict"))

theorem optDateOfJ_inj {x y : JRef JLocalDate} {d : Spec.Prim.Date} (hx : x.bind dateOfJ = some d)
    (hy : y.bind dateOfJ = some d) : x = y := by
  cases x <;> cases y <;> simp only [Option.bind_none, Option.bind_some, reduceCtorEq] at hx hy
  rw [inj_of_kernel dateOfJ_kernel hx hy]

theorem optNatOfJ32_inj {x y : JRef J32} {n : Nat} (hx : x.bind natOfJ32 = some n) (hy : y.bind natOfJ32 = some n) :
    x = y := by
  cases x <;> cases y <;> simp only [Option.bind_none, Option.bind_some, reduceCtorEq] at hx hy
  rw [inj_of_kernel natOfJ32_kernel hx hy]

/-- `aoR` の像からの元の形。 -/
theorem aoR_confirmed {x : SourceModel.ReserveQuery.MOutput} {n : Nat} (h : aoR x = some (.ok (.confirmed n))) :
    ∃ t, x = .ok (.confirmed ⟨t⟩) ∧ natOfJ32 t = some n := by
  rcases x with (⟨c, a⟩ | _ | _ | _) | (⟨⟨t⟩⟩ | ⟨⟨no, d, tf⟩⟩) <;>
    simp only [aoR, Option.some.injEq, Option.map_eq_some_iff, Option.bind_eq_some_iff, reduceCtorEq,
      Except.ok.injEq, MOutputValue.confirmed.injEq, and_false, exists_false] at h
  obtain ⟨m, hm, rfl⟩ := h
  exact ⟨t, rfl, hm⟩

theorem aoR_reserved {x : SourceModel.ReserveQuery.MOutput} {r : ReserveResult} (h : aoR x = some (.ok (.reserved r))) :
    ∃ d tf, x = .ok (.reserved ⟨some r.reserveNo.val, d, tf⟩) ∧ d.bind dateOfJ = some r.paymentDate ∧
      tf.bind natOfJ32 = some r.totalFare := by
  rcases x with (⟨c, a⟩ | _ | _ | _) | (⟨⟨t⟩⟩ | ⟨⟨no, d, tf⟩⟩) <;>
    simp only [aoR, Option.some.injEq, Option.map_eq_some_iff, Option.bind_eq_some_iff, reduceCtorEq,
      Except.ok.injEq, MOutputValue.reserved.injEq, and_false, exists_false] at h
  obtain ⟨rn, ⟨n, rfl, hrn⟩, j, hj, k, hk, rfl⟩ := h
  refine ⟨d, tf, ?_, Option.bind_eq_some_iff.mpr hj, Option.bind_eq_some_iff.mpr hk⟩
  simp only [Spec.Model.ReserveNo.val_of_ofString? hrn]

theorem aoR_error {x : SourceModel.ReserveQuery.MOutput} {e : Spec.Error.AtrsError} (h : aoR x = some (.error e)) :
    (∃ c a, e = .business c a ∧ x = .error (.business c a)) ∨ (e = .invalidRequest "" ∧ x = .error .badRequest) ∨
      (e = .system "e.ar.fw.9999" ∧ x = .error .ioFailure) ∨ (e = .conflict "conflict" ∧ x = .error .conflict) := by
  rcases x with (⟨c, a⟩ | _ | _ | _) | (⟨⟨t⟩⟩ | ⟨⟨no, d, tf⟩⟩) <;>
    simp only [aoR, Option.some.injEq, Option.map_eq_some_iff, Option.bind_eq_some_iff, reduceCtorEq,
      Except.error.injEq, and_false, exists_false] at h
  · exact .inl ⟨c, a, h.symm, rfl⟩
  · exact .inr (.inl ⟨h.symm, rfl⟩)
  · exact .inr (.inr (.inl ⟨h.symm, rfl⟩))
  · exact .inr (.inr (.inr ⟨h.symm, rfl⟩))

@[obligation "ABS-048"]
theorem aoR_kernel : KernelIs aoR (undefOrEq aoR) := by
  apply kernelIs_undefOrEq
  intro x y b hx hy
  rcases b with e | (n | r)
  · rcases aoR_error hx with ⟨c, a, rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩ <;>
      rcases aoR_error hy with ⟨c', a', he, rfl⟩ | ⟨he, rfl⟩ | ⟨he, rfl⟩ | ⟨he, rfl⟩ <;>
      first | rfl | (cases he; rfl) | (cases he; done)
  · obtain ⟨t, rfl, ht⟩ := aoR_confirmed hx
    obtain ⟨t', rfl, ht'⟩ := aoR_confirmed hy
    rw [inj_of_kernel natOfJ32_kernel ht ht']
  · obtain ⟨d, tf, rfl, hd, htf⟩ := aoR_reserved hx
    obtain ⟨d', tf', rfl, hd', htf'⟩ := aoR_reserved hy
    rw [optDateOfJ_inj hd hd', optNatOfJ32_inj htf htf']

/-! ## 貼り合わせ -/

/-- 予約の標準の貼り合わせ（状態は `worldOfDb`、具体側の不変条件は `IcW`。空席照会の貼り合わせと `J` が同じ）。 -/
abbrev glueR := Machine.Glue.ofStd worldOfDb IcW aiR aoR

/-- 具体側の入力の環境の記述（障害の位置。束の環境の固定 `pinned` の `ce`。ADR ab93 の 3d）。 -/
@[std_abs "docs/spec/abstraction.md#抽象化関数-α"]
def ceR (ic : SourceModel.ReserveQuery.MInput) : Spec.Nondet.FaultSpec :=
  (ic.input.env.ioFailAt, ic.input.env.conflictAt)

/-- `ceR` の核: 障害の位置が同じ入力を同一視する。 -/
@[kernel "docs/spec/abstraction.md#抽象化関数-α"]
def ceRKer (a b : SourceModel.ReserveQuery.MInput) : Prop :=
  a.input.env.ioFailAt = b.input.env.ioFailAt ∧ a.input.env.conflictAt = b.input.env.conflictAt

@[obligation "ABS-048"]
theorem ceR_kernel : Machine.Preserves.KernelIs ceR ceRKer := fun _ _ => by simp [ceR, ceRKer]

/-! ## 前提型の差異 -/

/-- D-027（予約）: 具体側の入力（DB のマスタ・設定・Clock の最初の読み出し・予約フォーム・操作の種類）が [Spec] の型で
表せる（`aiR` が定義される）。あわせて、業務例外の引数に使うマスタの運賃種別名が改行を含まない（SourceModel の業務例外の
メッセージは、コードと引数を改行でつないだもの。`AtrsBusinessException.newArgs`）。 -/
@[deviation "D-027"]
def dev_D027R (ic : SourceModel.ReserveQuery.MInput) : Prop :=
  (aiR ic).isSome = true ∧ ∀ ft ∈ ic.input.db.fareType, '\n' ∉ ft.fareTypeName.val.toList

/-- D-014（予約）: 1 回の操作の中で、Clock のどの読み出しも最初の読み出しと同じ日付（予約日と、予約フライトごとの
予約可能期間の判定の今日が同じ）。 -/
@[deviation "D-014"]
def dev_D014R (ic : SourceModel.ReserveQuery.MInput) : Prop := ∀ n, ic.input.env.clock n = ic.input.env.clock 0

/-- D-009: 予約確定では、採番の次の値から、1 回の予約確定が使う番号（予約番号 1、予約フライト番号 2 まで、搭乗者番号
12 まで）が、シーケンスの最大値と `int` の上限（予約フライト番号・搭乗者番号の列と `selectKey` の `Integer`）を超えない。 -/
@[deviation "D-009"]
def dev_D009 (w : Spec.Port.World) (i : MInput) : Prop :=
  i.op = .reserve → w.sequences.reserve ≤ 9999999999 ∧ w.sequences.reserveFlight + 1 ≤ 2147483647 ∧
    w.sequences.passenger + 11 ≤ 2147483647

/-- D-031: 往復の予約では、往路便の便マスタの到着時刻が 24:00 より前。 -/
@[deviation "D-031"]
def dev_D031 (i : MInput) : Prop :=
  ∀ o h, i.req.selects = [o, h] → ∀ m, i.md.flightMasterOf o.flightName = some m → m.arrivalTime.toMinutes < 1440

/-- 予約の合計金額の入力: 選択フライトの主キーと、空でない搭乗者欄の年齢。 -/
def tfOf (i : MInput) : Spec.Fare.TotalFareInput :=
  ⟨i.cfg, i.md, i.req.selects.map (·.key), (i.req.form.passengers.filter (!·.isEmpty)).map fun p => p.age.getD 0⟩

/-- D-001（予約）: 合計金額の入力 `tfOf` に `dev_D001T` が成り立つ。 -/
@[deviation "D-001"]
def dev_D001R (i : MInput) : Prop := Abstraction.Fare.TotalAlpha.dev_D001T (tfOf i)

/-- D-002（予約）: 合計金額の入力 `tfOf` に `dev_D002T` が成り立つ。 -/
@[deviation "D-002"]
def dev_D002R (i : MInput) : Prop := Abstraction.Fare.TotalAlpha.dev_D002T (tfOf i)

/-- D-012（予約）: 合計金額の入力 `tfOf` に `dev_D012` が成り立つ。 -/
@[deviation "D-012"]
def dev_D012R (i : MInput) : Prop := Abstraction.Fare.TotalAlpha.dev_D012 (tfOf i)

end Abstraction.Reserve.Alpha
