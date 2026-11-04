import Spec.Env.Config
import Spec.Env.MasterData
import Spec.Env
import Spec.Env.CodeList

/-!
# マスタの参照（`Spec.MasterQuery`）

> **区分: 要約（informative）。** 本文は Lean の定義の非規範の要約で、食い違ったら Lean が正である。

マスタデータ・設定・コードリストを参照する問い合わせと、それに答える状態を持たない抽象機械を定める。参照関数そのもの
（`routeOf`・`flightMasterOf`・`peakTimeOn` など）は [`Spec.Env.MasterData`](Env/MasterData.lean#参照関数)、コードリストは
[`Spec.Env.CodeList`](Env/CodeList.lean) にあり、本章はそれらを 1 つの入口にまとめる。設定とマスタは機械の不変の入力である。
-/

namespace Spec.MasterQuery
open Spec.Env
open Spec.Env.MasterData (Airport Route FlightMaster BoardingClass FareType PeakTime Plane CreditType BoardingClassInfo FareTypeInfo)
open Spec.Env.CodeList Spec.Model Spec.Prim.Text

open Spec.Prim

/-- コードリストの名前（`lean/Spec/Env/CodeList.lean#空港コードリスト画面用`）。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#空港コードリスト画面用"]
inductive CodeListName where
  | airport | boardingClass | fareType | creditType | creditMonth | creditYear | gender | flightType
  deriving DecidableEq, Repr


/-- 名前で引いたコードリスト。 -/
@[spec_doc "lean/Spec/Env/CodeList.lean#空港コードリスト画面用"]
def codeListOfName (md : MasterData) : CodeListName → List CodeEntry
  | .airport => airport md
  | .boardingClass => boardingClass md
  | .fareType => fareType md
  | .creditType => creditType md
  | .creditMonth => creditMonth
  | .creditYear => creditYear
  | .gender => gender
  | .flightType => flightType



/-!
## 問い合わせ

問い合わせ `Query` は次のどれかで、答え `Answer` はそれぞれ対応する参照関数の結果である（`answer`）。

| 問い合わせ | 答え |
| --- | --- |
| `routeOf(dep, arr)` | 区間（無ければ無し） |
| `flightMasterOf(name)` | 便マスタ（無ければ無し） |
| `fareTypeOf(cd)` | 運賃種別（表示順を除く。無ければ無し） |
| `boardingClassOf(cd)` | 搭乗クラス（表示順を除く。無ければ無し） |
| `peakTimeOn(d)` | 搭乗日 `d` を含むピーク時期（無ければ無し） |
| `multiplicationRatioOn(d)` | 搭乗日 `d` の積算比率（ピーク時期が無ければ 100） |
| `config` | 設定の値 |
| `codeList(name)` | 名前で引いたコードリスト |

搭乗クラスと運賃種別の答えは、表示順を除いた射影（`BoardingClassInfo`・`FareTypeInfo`）である。表示順を観測するのは
コードリストの問い合わせだけとする（原典の参照の結果にも表示順は無い）。

問い合わせの引数の値域（`Query.Valid`）: 区間の空港コード（生の文字列）は空港コードの形式 `AirportCd.valid` に合い、便名は
形式 `FlightName.valid` に合い、空白でない（[文字クラス](Prim/Text.lean#文字クラス) の `hasText`。原典の `Assert.hasText`）。
引数がこれを満たさないときの [Source] の振る舞い（`Assert.hasText` の例外、`-` を含む空港コードでのキャッシュのキーの衝突）は、
差異ではない（参考 [D-034](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）。
-/

/-- 参照の問い合わせ。 -/
@[raw_input "機械の入力（参照の問い合わせ）。妥当性 Query.Valid は PRE"]
inductive Query where
  | routeOf (dep arr : String)
  | flightMasterOf (name : String)
  | fareTypeOf (cd : FareTypeCd)
  | boardingClassOf (cd : BoardingClassCd)
  | peakTimeOn (d : Date)
  | multiplicationRatioOn (d : Date)
  /-- 設定の値。 -/
  | config
  /-- コードリスト。 -/
  | codeList (n : CodeListName)

/-- 問い合わせの引数の値域（原典の `Assert.hasText` に当たる。形式は `lean/Spec/Model.lean#コード値`）。
便名は、形式（`FlightName.valid`）に合い、空白でない（`Spec.Prim.Text.hasText`）ことも課す。空港コードは英大文字なので、空白でない。 -/
@[spec_doc "lean/Spec/MasterQuery.lean#問い合わせ", gap "D-034"]
def Query.Valid : Query → Prop
  | .routeOf dep arr => AirportCd.valid dep = true ∧ AirportCd.valid arr = true
  | .flightMasterOf name => FlightName.valid name = true ∧ hasText name = true
  | _ => True

instance (q : Query) : Decidable q.Valid := by
  cases q <;> unfold Query.Valid <;> infer_instance

/-- 問い合わせの結果。 -/
inductive Answer where
  | route (r : Option Route)
  | flightMaster (f : Option FlightMaster)
  | fareType (f : Option FareTypeInfo)
  | boardingClass (b : Option BoardingClassInfo)
  | peakTime (p : Option PeakTime)
  | ratio (n : Nat)
  | config (c : Config)
  | codeList (l : List CodeEntry)

/-- 問い合わせに答える。 -/
def answer (cfg : Config) (md : MasterData) : Query → Answer
  | .routeOf dep arr => .route (md.routeOf dep arr)
  | .flightMasterOf name => .flightMaster (md.flightMasterOf name)
  | .fareTypeOf cd => .fareType ((md.fareTypeOf cd).map (·.info))
  | .boardingClassOf cd => .boardingClass ((md.boardingClassOf cd).map (·.info))
  | .peakTimeOn d => .peakTime (md.peakTimeOn d)
  | .multiplicationRatioOn d => .ratio (md.multiplicationRatioOn d)
  | .config => .config cfg
  | .codeList n => .codeList (codeListOfName md n)

/-!
## 抽象機械

`queryMachine` は状態を持たない抽象機械（`Machine.Machine.pure`）で、入力は設定・マスタ・問い合わせの組、1 歩はその
問い合わせの答えを出力する。PRE は次の連言である。

- 設定とマスタの検証が通ること（[`Spec.Env`](Env.lean) の `masterConfigOk`。設定の不変条件と、マスタの不変条件 MD-1〜MD-8）。
- 問い合わせの引数の値域（`Query.Valid`。[問い合わせ](#問い合わせ)）。

マスタの不変条件の下では、どの参照関数も一致するものが高々 1 つなので、答えはマスタの行の並びに依存しない。
DB の値が [Spec] の型で表せない場合は、既知差異 [D-027](../../docs/spec/abstraction.md#既知差異) である。
-/

/-- マスタ・設定・コードリストの参照の抽象機械（状態を持たない）。PRE は設定とマスタの検証が通ること（`Env.masterConfigOk`）と、
問い合わせの引数の値域。 -/
@[spec_doc "lean/Spec/MasterQuery.lean#抽象機械", gap "D-027"]
def queryMachine : Machine.Machine Unit (Config × MasterData × Query) Answer :=
  Machine.Machine.pure (fun i => Env.masterConfigOk (i.1, i.2.1) ∧ i.2.2.Valid) (fun i => answer i.1 i.2.1 i.2.2)

/-! ## 性質（SPEC 課題） -/

/-- SPEC-001: PRE の下で、標準の選択は関係に含まれる。 -/
@[obligation "SPEC-001"]
theorem queryMachine_run_step :
    ∀ s i, queryMachine.Pre s i → queryMachine.step s i (queryMachine.run s i).1 (queryMachine.run s i).2 :=
  queryMachine.run_step

/-- SPEC-002・SPEC-003: 初期化は INV を満たし、PRE の下の操作は INV を保つ。 -/
@[obligation "SPEC-002", "SPEC-003"]
theorem queryMachine_sound : queryMachine.Sound := Machine.Machine.sound_pure _ _

/-- SPEC-007: 初期状態は 1 点（状態を持たない）。 -/
@[obligation "SPEC-007"]
theorem queryMachine_initIs : queryMachine.InitIs () := fun _ => ⟨fun _ => rfl, fun _ => trivial⟩


end Spec.MasterQuery

/-!
## 根拠と対応

- 根拠: [ADR c108](../../docs/decision/c108-master-data-source-model-and-spec-fixes.md)（マスタ・設定・コードリストの読み込みの移植元モデルと [Spec] の修正）、[ADR f353](../../docs/decision/f353-abs-026-proof-structure-nop-and-d027-scope.md)（答えの射影と D-027 の範囲）
- 既知差異: D-027（[既知差異](../../docs/spec/abstraction.md#既知差異)）、PRE の外の D-034（[前提の外の振る舞い](../../docs/spec/abstraction.md#spec-の前提の外での-source-の振る舞い差異ではない)）
- 移植元モデル: 具体機械は [`SourceModel.MasterQuery`](../SourceModel/MasterQuery.lean) の `queryConcrete`（起動時に各 Provider の `load()` とコードリストの読み込みを行う。Mapper の SQL の写しは PostgreSQL で差分実行して照合する）
- 抽象化の証明: [`Abstraction.MasterData`](../Abstraction/MasterData.lean)（ABS-026。Mapper の文の結果の並びが未規定でも答えが同じこと、差異の必要性 ABS-127）
- 適合テストベクタ: `conformance/shared/master-data/`、SQL の差分実行 `conformance/sql/master-data.json`
-/
