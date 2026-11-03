import LangSemantics.Core.EStateHoare
import SourceModel.Db.Tx
import SourceModel.Domain.Service.B0.InvalidFlightException
import SourceModel.Domain.Common.Exception.AtrsBusinessException

/-!
# Abstraction.Reserve.Tx

状態の表に対する計算（`SourceModel.Db.Tx`）の基本の操作の Hoare 三つ組（backlog aedf の第 3 段）。

- `IsFault env e`: 実行環境 `env` の障害（I/O の失敗・排他の失敗）の例外。それぞれ `env` がその障害の位置を持つときに限る。[Spec] の環境の選択 N-001・N-002 に当たる。
- `IsIoFault env e`: I/O の失敗の例外（読むだけの文の障害。行ロックを取らないので排他の失敗は起きない）。
- `query`・`sql`: 文の実行。障害の位置なら障害の例外、そうでなければ文の結果。
- `lift`・`now`・`transactional`
-/

namespace Abstraction.Reserve.Tx
open LangSemantics.Core.EStateHoare
open LangSemantics.Java LangSemantics.Java.Exception LangSemantics.Sql.Core
open SourceModel.Db.Schema SourceModel.Db.Tx

/-- 実行環境 `env` の障害（I/O の失敗・排他の失敗）の例外。それぞれ、`env` がその障害の位置を持つときに限る。 -/
def IsFault (env : Env) (e : JThrow) : Prop :=
  ∃ m, (e = .other ioFailureClass m ∧ env.ioFailAt.isSome = true) ∨
    (e = .other conflictClass m ∧ env.conflictAt.isSome = true)

/-- 実行環境 `env` の I/O の失敗の例外（`env` が I/O の失敗の位置を持つときに限る）。読むだけの文の障害。 -/
def IsIoFault (env : Env) (e : JThrow) : Prop :=
  ∃ m, e = .other ioFailureClass m ∧ env.ioFailAt.isSome = true

theorem IsIoFault.fault {env : Env} {e : JThrow} (h : IsIoFault env e) : IsFault env e :=
  let ⟨m, he, hi⟩ := h
  ⟨m, .inl ⟨he, hi⟩⟩

/-- 不正要求に包まれる例外（`InvalidFlightException`・業務例外）。 -/
def BadReq (e : JThrow) : Prop :=
  ∃ cls msg, e = .other cls msg ∧
    (cls = SourceModel.Domain.Service.B0.InvalidFlightException.className ∨
      cls = SourceModel.Domain.Common.Exception.AtrsBusinessException.className)

/-- 文を 1 回実行した後の状態の計数。 -/
def tick (s : St) : St := { s with sqlCalls := s.sqlCalls + 1 }

/-- 読むだけの文。 -/
theorem query_hoare {α : Type} (f : FlightDb → SqlResult α) (P : St → Prop) :
    Hoare P (query f)
      (fun a s' => ∃ s, P s ∧ s' = tick s ∧ f s.db = .ok a)
      (fun e s' => ∃ s, P s ∧ s' = tick s ∧ (IsIoFault s.env e ∨ ∃ err, f s.db = .error err ∧ e = translate err)) := by
  intro s hs
  simp only [query, bind, EStateM.bind, get, getThe, MonadStateOf.get, EStateM.get, set, MonadStateOf.set,
    EStateM.set]
  by_cases h1 : s.env.ioFailAt = some s.sqlCalls
  · simp only [h1, ite_true, throw, throwThe, MonadExceptOf.throw]
    exact ⟨s, hs, rfl, .inl ⟨_, rfl, by simp [h1]⟩⟩
  · simp only [h1, ite_false, pure]
    cases hf : f s.db with
    | ok a =>
      simp only [hf]
      exact ⟨s, hs, rfl, hf⟩
    | error err =>
      simp only [hf, throw, throwThe, MonadExceptOf.throw, EStateM.throw]
      exact ⟨s, hs, rfl, .inr ⟨err, hf, rfl⟩⟩

/-- 純粋な計算の持ち上げ。 -/
theorem lift_hoare {α : Type} (r : JResult α) (P : St → Prop) :
    Hoare P (lift r) (fun a s => r = .ok a ∧ P s) (fun e s => r = .error e ∧ P s) := by
  intro s hs
  cases r <;> exact ⟨rfl, hs⟩

end Abstraction.Reserve.Tx
