import SourceModel.FlightSearch
import SourceModel.Repository.FlightSeed

/-!
# SourceModel.FlightSearchQuery

空席照会の具体機械（R 課題 ABS-011 の具体側。backlog 0be7 の第 2 段）。

- 状態は FLIGHT 表 `FlightDb`。初期状態は、シードの投入後の表 `FlightSeed.seedFlightDb`。照会は状態を変えない。
- 入力は、DB のマスタ・注入された設定・今日の日付・照会条件（`SourceModel.FlightSearch.SearchInput`）。
- 1 歩は、マスタの文の許される並び `mo`（`Order.Allowed`）と、空席照会の文の許される並べ方 `sortRows`
  （`SortAllowed`）のどれかで、起動時の読み込みと `searchFlight` を実行する関係とする。原典はマスタを起動時に 1 度だけ
  読み込むが、この機械はマスタの並びを 1 歩ごとに選び直す。許す振る舞いが原典より多い（上からの近似）ので、
  リファインメントの証明には安全である（マスタの参照・運賃計算の具体機械と同じ扱い）。
- 業務例外（`AtrsBusinessException`・`FlightNotFoundException`）は、原典の画面・API が捕まえてメッセージに変える
  観測可能な結果なので、出力の値 `BusinessError` として受ける（ADR a4fa「エラーは値」）。それ以外の例外
  （前提違反・NPE など）は、例外の経路 `JThrow` に残す。
-/

namespace SourceModel.FlightSearchQuery
open LangSemantics.Java.Exception

open LangSemantics.Java SourceModel.FlightSearch SourceModel.Repository.Flight SourceModel.Repository.Schema

/-- 業務例外（原典の `AtrsBusinessException` と、その派生の `FlightNotFoundException`）。 -/
inductive BusinessError where
  /-- `AtrsBusinessException(code)` -/
  | business (code : String)
  /-- `FlightNotFoundException`（照会結果 0 件） -/
  | notFound (code : String)
  deriving DecidableEq, Repr

/-- 具体機械の出力: 業務例外か、便ごとの空席情報の列。 -/
abbrev SearchOutput := Except BusinessError (List FlightVacantInfoDto)

/-- 業務例外を出力の値に変える。それ以外の例外は、そのまま例外とする。 -/
def catchBusiness (r : JResult (List FlightVacantInfoDto)) : JResult SearchOutput :=
  match r with
  | .ok v => .ok (.ok v)
  | .error (.other cls code) =>
    if cls = businessExceptionClass then .ok (.error (.business code))
    else if cls = flightNotFoundClass then .ok (.error (.notFound code))
    else .error (.other cls code)
  | .error e => .error e

/-- 空席照会の具体機械。1 歩は、許される並びのどれかで照会し、状態を変えない。 -/
def searchConcrete : Machine.Concrete FlightDb SearchInput SearchOutput JThrow where
  Init t := t = SourceModel.Repository.FlightSeed.seedFlightDb
  step t ic r := ∃ mo sortRows, mo.Allowed ic.db ∧ SortAllowed sortRows ∧
    r = (catchBusiness (runSearchFlight t ic mo sortRows)).map fun o => (t, o)

end SourceModel.FlightSearchQuery
