import SourceModel.ReserveQuery
import Abstraction.Reserve.Tx

/-!
# Abstraction.Reserve.Catch

ABS-041 の補題: 具体機械の出力の値とする例外（`SourceModel.ReserveQuery.catchReserve`）の像（backlog aedf の第 3 段）。
業務例外のメッセージはコードと引数を改行でつないだものなので、コードと引数が改行を含まなければ、分けた結果は元の
コードと引数である。
-/

namespace Abstraction.Reserve.Catch
open LangSemantics.Java.Exception SourceModel.ReserveQuery SourceModel.Domain.Common.Exception
open Abstraction.Reserve.Tx

/-- 改行を含まない文字列。 -/
abbrev NoNL (s : String) : Prop := '\n' ∉ s.toList

theorem catch_business {c : String} {args : List String} (hc : NoNL c) (ha : ∀ a ∈ args, NoNL a) :
    catchReserve (.error (AtrsBusinessException.newArgs c args)) = .ok (.error (.business c args)) := by
  have h : ((AtrsBusinessException.newArgs c args |> fun _ => String.intercalate (String.singleton '\n') (c :: args)).split
      '\n').toList.map (·.copy) = c :: args := by
    rw [String.toList_split_intercalate]
    · simp
    · intro s hs
      simp only [List.mem_cons] at hs
      rcases hs with rfl | hs
      · exact hc
      · exact ha s hs
  simp only [catchReserve, AtrsBusinessException.newArgs, ite_true]
  have e : ("\n" : String) = String.singleton '\n' := rfl
  rw [e, h]

theorem catch_badRequest (msg : String) :
    catchReserve (.error (.other SourceModel.App.B2.TicketReserveHelper.badRequestClass msg)) = .ok (.error .badRequest) := by
  have h1 : SourceModel.App.B2.TicketReserveHelper.badRequestClass ≠ AtrsBusinessException.className := by decide
  simp [catchReserve, h1]

theorem catch_fault {env : SourceModel.Db.Tx.Env} {e : JThrow} (h : IsFault env e) :
    catchReserve (.error e) = .ok (.error .ioFailure) ∨ catchReserve (.error e) = .ok (.error .conflict) := by
  have h1 : SourceModel.Db.Tx.ioFailureClass ≠ AtrsBusinessException.className := by decide
  have h2 : SourceModel.Db.Tx.ioFailureClass ≠ SourceModel.App.B2.TicketReserveHelper.badRequestClass := by decide
  have h3 : SourceModel.Db.Tx.conflictClass ≠ AtrsBusinessException.className := by decide
  have h4 : SourceModel.Db.Tx.conflictClass ≠ SourceModel.App.B2.TicketReserveHelper.badRequestClass := by decide
  have h5 : SourceModel.Db.Tx.conflictClass ≠ SourceModel.Db.Tx.ioFailureClass := by decide
  obtain ⟨m, rfl | ⟨rfl, -⟩⟩ := h
  · left; simp [catchReserve, h1, h2]
  · right; simp [catchReserve, h3, h4, h5]

/-- 排他の失敗の位置を持たない実行環境の障害は、I/O の失敗。 -/
theorem catch_fault_none {env : SourceModel.Db.Tx.Env} (hc : env.conflictAt = none) {e : JThrow} (h : IsFault env e) :
    catchReserve (.error e) = .ok (.error .ioFailure) := by
  have h1 : SourceModel.Db.Tx.ioFailureClass ≠ AtrsBusinessException.className := by decide
  have h2 : SourceModel.Db.Tx.ioFailureClass ≠ SourceModel.App.B2.TicketReserveHelper.badRequestClass := by decide
  obtain ⟨m, rfl | ⟨rfl, hs⟩⟩ := h
  · simp [catchReserve, h1, h2]
  · simp [hc] at hs

end Abstraction.Reserve.Catch
