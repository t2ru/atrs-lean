import Trace
import Machine
import Spec.Glossary
import Spec.Prim
import Spec.Model
import Spec.Error
import Spec.Env
import Spec.Env.Config
import Spec.Env.MasterData
import Spec.Env.CodeList
import Spec.World
import Spec.Port
import Spec.Nondet
import Spec.MasterQuery
import Spec.Fare
import Spec.FlightSearch
import Spec.Reserve
import Spec.Reserve.FlightSelection
import Spec.Member
import Spec.Auth
import Spec.Report
import Spec.Validation
import Spec.Http
import Spec.Seed
import Spec.Seed.Master
import Spec.Seed.Flight
import Spec.Seed.FlightProps
import Spec.Seed.Member
import Spec.Seed.World

/-!
# Spec

抽象モデル（言語中立・厳密整数の正規仕様。ADR 61bc）。各機能は `Machine.Machine` の抽象機械として与える。
業務仕様の散文（要約・草案・`Spec` で表せない規範）は、各モジュールのモジュール文書に、定義のすぐ前に書く。
mdgen と mdbook で HTML の本にする（`mise run book:build`。ADR 68a6）。
依存してよいもの: `Spec`, `Machine`, `Trace`（spec-pivot の `spec/architecture.md#依存の向き`）。

| モジュール | 内容 |
| --- | --- |
| `Spec.Glossary` | 用語集（文書だけのモジュール） |
| `Spec.Prim` | 基本演算・暦日・時刻・書式・文字クラス |
| `Spec.Model` | 列挙・コード値・エンティティ・値域 |
| `Spec.Seed` | シードのマスタ・設定（`tools/conformance/seed_lean.py` が生成） |
| `Spec.Seed.Flight`・`Spec.Seed.FlightProps` | シードのフライト（`World` の初期状態。`tools/conformance/flight_seed.py` が生成）と、その主キーの一意性・参照整合性 |
| `Spec.Env` | 検証済みの設定とマスタ `ValidEnv` と境界の検証 `validate`、入口の環境の前提 `masterConfigOk`（検証が成功すること。`@[env_pre]`）、検査関数 `validB` と正しさ、シードが前提を満たすこと |
| `Spec.Nondet` | 非決定性 N-001〜N-005 の選択の型（`@[nondet]`）と標準の値 |
| `Spec.Env.Config` | 設定値と不変条件 |
| `Spec.Env.MasterData` | マスタデータ、不変条件 MD-1〜MD-8、参照関数 |
| `Spec.Env.CodeList` | コードリスト |
| `Spec.MasterQuery` | マスタ・設定・コードリストの参照の抽象機械（SPEC 課題、ABS-026 の抽象側） |
| `Spec.Fare` | 運賃計算（基本運賃・運賃・合計金額） |
| `Spec.Error` | エラーの分類 `AtrsError`（いまは `Business`・`NotFound`） |
| `Spec.Port` | 抽象状態 `World`（いまはフライト）と不変条件、ポートの操作 |
| `Spec.FlightSearch` | 空席照会（照会可能期間・運賃種別の予約可能判定・`searchFlight`）と抽象機械 `searchMachine`（SPEC 課題） |
| `Spec.Reserve.FlightSelection`・`Spec.Reserve` | 予約（選択フライトの検証・予約内容の組み立て・予約確認・予約確定）と抽象機械 `reserveMachine` |
| `Spec.Member`・`Spec.Auth`・`Spec.Report` | 会員・認証・予約履歴レポート（形式化前の草案だけを書いた、文書だけのモジュール） |
| `Spec.Validation`・`Spec.Http` | 入力検証と HTTP 契約（草案と、`Spec` で表せない規範。文書だけのモジュール） |

トップレベルの抽象機械 `Spec.machine` は、実装済みの範囲の機能の機械を並置したもの（`Machine.sum`。状態を共有する
空席照会と予約は `Machine.alt`）である。
`Abstraction` の主定理 `Abstraction.refines`・`Abstraction.preserves` の抽象側になる。入口の機械（HTTP の画面・API、
レポート要求の受信）ができたら、それを並置に加える。
-/

namespace Spec
open Spec.Env (Config MasterData)

/-- トップレベルの抽象機械の状態（各機能の状態の積。空席照会と予約が状態 `World` を共有する）。 -/
abbrev State := Unit × Unit × Unit × Unit × World

/-- トップレベルの抽象機械の入力: マスタ・設定・コードリストの参照、基本運賃、運賃、合計金額、空席照会と予約（同じ状態
`World` の上の並置）。 -/
abbrev Input := (Config × MasterData × MasterQuery.Query) ⊕ Fare.BasicFareInput ⊕ Fare.FareInput ⊕ Fare.TotalFareInput ⊕
  (FlightSearch.SearchInput ⊕ Reserve.MInput)

/-- トップレベルの抽象機械の出力。 -/
abbrev Output := MasterQuery.Answer ⊕ Nat ⊕ Nat ⊕ Nat ⊕ (FlightSearch.SearchOutput ⊕ Reserve.MOutput)

/-- トップレベルの抽象機械: 実装済みの範囲の機能の機械を並置したもの。 -/
def machine : Machine.Machine State Input Output :=
  MasterQuery.queryMachine.sum (Fare.basicFareMachine.sum (Fare.fareMachine.sum
    (Fare.totalFareMachine.sum (FlightSearch.searchMachine.alt Reserve.reserveMachine))))

/-- 初期状態（fixture の 1 点。空席照会の状態は、シードを投入した後の `World`）。 -/
def init : State := ((), (), (), (), Seed.World.world)

end Spec
