import Trace
import Machine
import Spec.Prim
import Spec.Model
import Spec.Config
import Spec.MasterData
import Spec.CodeList
import Spec.MasterQuery
import Spec.Fare
import Spec.Error
import Spec.Port
import Spec.FlightSearch
import Spec.Ticket
import Spec.UseCase.Reserve
import Spec.Nondet
import Spec.Seed
import Spec.Seed.Flight
import Spec.Seed.FlightProps
import Spec.Seed.Member
import Spec.Seed.World
import Spec.EnvPre

/-!
# Spec

抽象モデル（言語中立・厳密整数の正規仕様。ADR 61bc）。各機能は `Machine.Machine` の抽象機械として与える。
依存してよいもの: `Spec`, `Machine`, `Trace`（spec-pivot の `spec/architecture.md#依存の向き`）。

| モジュール | 内容 |
| --- | --- |
| `Spec.Prim` | 基本演算・暦日・時刻・書式・文字クラス |
| `Spec.Model` | 列挙・コード値・エンティティ・値域 |
| `Spec.Seed` | シードのマスタ・設定（`tools/conformance/seed_lean.py` が生成） |
| `Spec.Seed.Flight`・`Spec.Seed.FlightProps` | シードのフライト（`World` の初期状態。`tools/conformance/flight_seed.py` が生成）と、その主キーの一意性・参照整合性 |
| `Spec.EnvPre` | 入口の環境の前提 `masterConfigOk`（`@[env_pre]`）、検査関数 `validB` と正しさ、シードが前提を満たすこと |
| `Spec.Nondet` | 非決定性 N-001〜N-005 の選択の型（`@[nondet]`）と標準の値 |
| `Spec.Config` | 設定値と不変条件 |
| `Spec.MasterData` | マスタデータ、不変条件 MD-1〜MD-8、参照関数 |
| `Spec.CodeList` | コードリスト |
| `Spec.MasterQuery` | マスタ・設定・コードリストの参照の抽象機械（SPEC 課題、ABS-026 の抽象側） |
| `Spec.Fare` | 運賃計算（基本運賃・運賃・合計金額） |
| `Spec.Error` | エラーの分類 `AtrsError`（いまは `Business`・`NotFound`） |
| `Spec.Port` | 抽象状態 `World`（いまはフライト）と不変条件、ポートの操作 |
| `Spec.FlightSearch` | 空席照会（照会可能期間・運賃種別の予約可能判定・`searchFlight`）と抽象機械 `searchMachine`（SPEC 課題） |

トップレベルの抽象機械 `Spec.machine` は、実装済みの範囲の機能の機械を並置したもの（`Machine.sum`）である。
`Abstraction` の主定理 `Abstraction.refines`・`Abstraction.preserves` の抽象側になる。入口の機械（HTTP の画面・API、
レポート要求の受信）ができたら、それを並置に加える。
-/

namespace Spec

/-- トップレベルの抽象機械の状態（各機能の状態の積。空席照会だけが状態 `World` を持つ）。 -/
abbrev State := Unit × Unit × Unit × Unit × Port.World

/-- トップレベルの抽象機械の入力: マスタ・設定・コードリストの参照、基本運賃、運賃、合計金額、空席照会。 -/
abbrev Input := (Config × MasterData × MasterQuery.Query) ⊕ Fare.BasicFareInput ⊕ Fare.FareInput ⊕ Fare.TotalFareInput ⊕
  FlightSearch.SearchInput

/-- トップレベルの抽象機械の出力。 -/
abbrev Output := MasterQuery.Answer ⊕ Nat ⊕ Nat ⊕ Nat ⊕ FlightSearch.SearchOutput

/-- トップレベルの抽象機械: 実装済みの範囲の機能の機械を並置したもの。 -/
def machine : Machine.Machine State Input Output :=
  MasterQuery.queryMachine.sum (Fare.basicFareMachine.sum (Fare.fareMachine.sum
    (Fare.totalFareMachine.sum FlightSearch.searchMachine)))

/-- 初期状態（fixture の 1 点。空席照会の状態はシードのフライト）。 -/
def init : State := ((), (), (), (), Seed.Flight.world)

end Spec
