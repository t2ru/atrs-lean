import Spec.Env.Config
import Spec.Env.MasterData
import Spec.Env
import Spec.Env.CodeList

/-!
# Spec.MasterQuery

マスタ・設定・コードリストの参照の抽象機械（R 課題 ABS-026 の抽象側。[`Spec.Env.MasterData`](Env/MasterData.lean)）。
状態を持たず、設定とマスタは不変の入力である。PRE は設定とマスタの検証が通ること（`Env.masterConfigOk`。設定の不変条件と MD-1〜MD-8）と、
問い合わせの引数の値域。
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

/-- 問い合わせの引数の値域（原典の `Assert.hasText` に当たる。`lean/Spec/Model.lean#コード値`）。
便名は、形式（`FlightName.valid`）に合い、空白でない（`Spec.Prim.Text.hasText`）ことも課す。空港コードは英大文字なので、空白でない。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数", gap "D-034"]
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

/-- マスタ・設定・コードリストの参照の抽象機械（状態を持たない）。PRE は設定とマスタの検証が通ること（`Env.masterConfigOk`）と、
問い合わせの引数の値域。 -/
@[spec_doc "lean/Spec/Env/MasterData.lean#参照関数", gap "D-027"]
def queryMachine : Machine.Machine Unit (Config × MasterData × Query) Answer :=
  Machine.Machine.pure (fun i => Env.masterConfigOk (i.1, i.2.1) ∧ i.2.2.Valid) (fun i => answer i.1 i.2.1 i.2.2)

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
