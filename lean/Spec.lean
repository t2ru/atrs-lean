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
# ATRS 航空券予約システムの仕様（`Spec`）

> **区分: 要約と凡例（informative）。** 本章は本書の読み方と章の構成を示す。仕様そのものは各章にある。

本書は、TERASOLUNA のサンプルアプリケーション ATRS（航空券予約システム）の業務仕様である。移植先の言語によらず
同じロジックを実装できるよう、言語に中立で、整数を厳密に扱う抽象モデルとして書く。

## 正規仕様と散文

- **正規仕様は Lean の定義である。** 各章の Lean のコード（型・関数・抽象機械）が仕様の正である。
- 地の文（散文）は、定義の要約・形式化前の草案・Lean で表せない要件（規範）の 3 種類で、各章・各節の冒頭の
  「区分」に示す。要約が Lean と食い違ったら Lean が正である。
- 実装は仕様に従い、仕様に無い振る舞いを持ってはならない。
- 金額・日付・回数などの計算はすべて厳密な整数で定める。浮動小数点数は使わない。

## 区分

| 区分 | 意味 |
| --- | --- |
| 要約（informative） | Lean に形式化した規則の、非規範の要約 |
| 草案（draft） | Lean で表せるが、まだ形式化していない業務規則 |
| 規範（normative） | Lean の関数として表せない要件（並行実行の原子性、伝送とセキュリティの方式、実行環境の要件など）。リファインメントの証明の対象外で、確かめ方は [保証の限界](../docs/spec/assurance.md) に挙げる |
| メタ情報（meta） | 用語集など、仕様を読み運用するための情報 |

## 記号

| 記号 | 意味 |
| --- | --- |
| **[Spec]** | この仕様（抽象モデル）の定め |
| **[Source]** | 移植元（原典の Java/SQL）の観測できる振る舞い |
| **[Spec=Source]** | 両者の定めが同じ |
| **[Target]** | 移植先の振る舞い。仕様と異なる点（`T-NNN`）があるときだけ書く |
| `D-NNN` | 既知差異: 仕様と移植元の違い（[一覧](../docs/spec/abstraction.md#既知差異)） |
| `T-NNN` | 既知差異: 仕様と移植先の違い（[一覧](../docs/spec/refinement.md)） |
| `N-NNN` | 仕様が許す非決定性（[`Spec.Nondet`](Spec/Nondet.lean)） |
| `MD-N` | マスタデータの不変条件（[`Spec.Env.MasterData`](Spec/Env/MasterData.lean)） |
| PRE | 操作の事前条件。PRE の外の入力に対する移植元の振る舞いは、仕様の定めの外である |
| `出典:` | 定めの根拠になった移植元のソースの位置（ロケータ） |

画面 ID（`A0`〜`D1`）は原典の画面の区分で、`B0` はフライト選択の共通処理、`B1` は空席照会、`B2` は予約、
`C1`・`C2` は会員登録・会員情報変更、`D1` は予約履歴レポートである。

## 章の構成

章は、基礎の型から順に、環境・状態・機能・外部とのやり取りへと並ぶ。

| 部分 | 章（モジュール） | 内容 |
| --- | --- | --- |
| 序 | [`Spec.Glossary`](Spec/Glossary.lean) | 用語集 |
| 基礎 | [`Spec.Prim`](Spec/Prim.lean) | 整数の演算・暦日・時刻・書式・文字クラス |
| ドメイン | [`Spec.Model`](Spec/Model.lean) | 列挙・コード値・エンティティ・値域 |
| | [`Spec.Error`](Spec/Error.lean) | エラーの分類とメッセージ |
| 環境 | [`Spec.Env`](Spec/Env.lean) | 設定とマスタ（環境）の検証と、入口の環境の前提 |
| | [`Spec.Env.Config`](Spec/Env/Config.lean)・[`Spec.Env.MasterData`](Spec/Env/MasterData.lean)・[`Spec.Env.CodeList`](Spec/Env/CodeList.lean) | 設定値、マスタデータと不変条件 MD-1〜MD-8・参照関数、コードリスト |
| 状態 | [`Spec.World`](Spec/World.lean) | 抽象状態 `World`（フライト・会員・予約・採番）と、リポジトリ・採番の操作 |
| | [`Spec.Port`](Spec/Port.lean) | その他のポート（時計・パスワード・レポート）と、実行環境への要件（トランザクションなど） |
| | [`Spec.Nondet`](Spec/Nondet.lean) | 仕様が許す非決定性 N-001〜N-005 |
| 機能 | [`Spec.MasterQuery`](Spec/MasterQuery.lean) | マスタ・設定・コードリストの参照 |
| | [`Spec.Fare`](Spec/Fare.lean) | 運賃計算（基本運賃・運賃・合計金額） |
| | [`Spec.FlightSearch`](Spec/FlightSearch.lean) | 空席照会（B1） |
| | [`Spec.Reserve`](Spec/Reserve.lean)・[`Spec.Reserve.FlightSelection`](Spec/Reserve/FlightSelection.lean) | 予約（B2）と、選択フライトの検証（B0） |
| | [`Spec.Member`](Spec/Member.lean)・[`Spec.Auth`](Spec/Auth.lean)・[`Spec.Report`](Spec/Report.lean) | 会員（C1/C2）・認証（A0〜A2）・予約履歴レポート（D1）。草案 |
| 外部契約 | [`Spec.Validation`](Spec/Validation.lean)・[`Spec.Http`](Spec/Http.lean) | 入力検証と、画面・REST API の HTTP 契約。草案と規範 |
| シード | [`Spec.Seed`](Spec/Seed.lean) | 原典の初期データ（マスタ・設定・フライト・会員）と、それが環境の前提を満たすこと |

## 読み方

- 各章は、先頭で区分と扱う範囲を述べ、続いて節ごとに散文と、それが述べる Lean の定義を並べる。定義の節は
  「シグネチャ・事前条件・定義・エラー・例・出典」の順に書く。
- 「性質」「SPEC 課題」の見出しの下は、定義が満たす性質の定理である。業務の規則を知るだけなら読み飛ばしてよい。
- 各章の末尾の「根拠と対応」に、決定の記録（ADR）、関係する既知差異、移植元モデル（`SourceModel`）の対応、
  適合テストベクタの場所を挙げる。

## トップレベルの抽象機械

`Spec.machine` は、形式化した機能の抽象機械を並置したもの（`Machine.sum`。状態 `World` を共有する空席照会と予約は
`Machine.alt`）である。初期状態 `Spec.init` は、シードを投入した後の `World` である。移植元モデル・移植先モデルが
この機械をリファインすることを、`Abstraction`・`Refinement` で証明する。

## 根拠と対応

- 根拠: [ADR 61bc](../docs/decision/61bc-lean-spec-as-normative-source.md)（Lean の `Spec` を正規仕様にする）、[ADR 68a6](../docs/decision/68a6-business-spec-in-lean-module-docs-and-book.md)（業務仕様をモジュール文書に書き、本にする）、[ADR e41d](../docs/decision/e41d-exact-integer-arithmetic-in-abstract-model.md)（厳密な整数）、[ADR 01d4](../docs/decision/01d4-b-method-refinement-and-explicit-deviations.md)（B メソッドのリファインメントと差異の明示）
- 抽象化の証明（移植元モデルが本仕様をリファインする）: [`Abstraction`](Abstraction.lean) の `Abstraction.refines`・`Abstraction.preserves`・`Abstraction.abstracts`
- 証明課題・既知差異の一覧: [abstraction.md](../docs/spec/abstraction.md)・[refinement.md](../docs/spec/refinement.md)、保証の限界: [assurance.md](../docs/spec/assurance.md)
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
