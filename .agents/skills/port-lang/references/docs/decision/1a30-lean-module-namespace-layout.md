---
type: Architecture Decision Record
title: "Lean の宣言をモジュール名の下に置き、機能の証明課題を機能のモジュールに置く"
description: "Lean の宣言の完全名をモジュール名そのものかその下に限り（NS-1）、技術的な必要がある 4 つの例外（型の名前空間・main・明示した例外・型名のモジュールのインスタンス）だけを認める。R・W・C 課題と付帯の義務は機能の名前空間のモジュールに、補題は下位のモジュールに置く（TR-L）。検査の道具 layout-check と改名の道具 rename.py を置く。"
tags: [adr, skill, lean, namespace]
id: "1a30c312-4acf-4d91-92fe-e14592cf7ad0"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T22:40:00+09:00
---

# Lean の宣言をモジュール名の下に置き、機能の証明課題を機能のモジュールに置く

## Context and Problem Statement

[lean/rules.md](../lang/lean/rules.md) には「ファイルパスと名前空間を一致させる」と書かれていた。しかし、どの道具もこれを検査していなかった。
実際には、ほとんどの宣言が親ディレクトリの名前空間に置かれていた（例: `Abstraction/Fare/Factors.lean` の `Abstraction.Fare.basicFactor`、`Spec/Model.lean` の `Spec.FlightType`）。
適用先 ATRS とこのスキルの assets を合わせて、約 1100 件の宣言が、モジュール名の下になかった。中には、別の機能の名前空間に置かれた宣言もあった（`Abstraction/Fare/Load.lean` の `Abstraction.MasterData.*`）。

Lean では、モジュール（ファイル）と名前空間は別の仕組みである。どのファイルからでも、どの名前空間にでも宣言を置ける。
一方、道具の層の判定は、2 つの手がかりに分かれている。

- `scripts/ci/check_lean.py`（依存の向き）: ファイルのパスで層を決める
- `trace-dump`: 宣言の名前で層を決める

モジュール名と名前空間が食い違うと、2 つの道具が同じ宣言を別の層と見なしうる。
また、名前から定義の場所を引けない。どれが証明課題でどれが補題かも、ファイルの一覧から分からない。

## Decision Drivers

* 宣言の名前から、それを定義したファイルが分かること（見通し）
* ファイルのパスで層を判定する道具と、名前で層を判定する道具が、同じ答えを出すこと
* 証明課題（R・W・C 課題）が補題と分かれ、機能ごとに一箇所で読めること
* 例外は技術的な必要があるものに限り、例外であることが道具で分かること
* 規則を CI で機械的に確かめられること

## Considered Options

* 一致の厳しさ
  * 宣言の完全名を、モジュール名そのものかその下に限る（NS-1）
  * 名前空間を、親ディレクトリのモジュールに合わせる（当時の実態）
  * 規則にせず、慣習にとどめる
* 複数の型を集めたモジュール（`Spec.Model` など）の型
  * モジュール名の下へ改名する（`Spec.Model.FlightType`）
  * 型ごとにモジュールを分け、型の名前は変えない
* 機能の名前空間（`Abstraction.Fare`）に置くもの
  * R・W・C 課題と、R 課題の付帯の義務だけ
  * 課題に加えて、命題の部品（α・差異の述語）も
* 検査の置き場所
  * Lean の環境を読む道具（`layout-check`）と、`trace check` の規則（TR-L）
  * `check_lean.py` の正規表現

## Decision Outcome

Chosen option: "NS-1 を規則にする。複数の型はモジュール名の下へ改名する。機能の名前空間には課題と付帯の義務だけを置く。検査は Lean の環境で行う", because 名前から場所が分かり、2 種類の道具の層の判定がそろうため。ディレクトリに合わせる案では、ファイルと名前の対応が 1 対 1 にならない。正規表現では、`namespace`・`section`・`_root_`・自動生成の名前を正しく扱えない。

### NS-1: モジュールと名前空間

宣言 `n` のモジュールを `M` とする。`n = M` か、`n` が `M.` で始まらなければならない。
自動生成の補助の定数（`Trace.Dump.isHidden`）と `private` の名前は対象外とする。
例外は次の 4 つだけで、`layout-check` が判定する。

| 例外 | 条件 | 技術的な必要 | 例 |
| --- | --- | --- | --- |
| E1 型の名前空間 | `n` が型 `T` の下にあり、`T` を定義したモジュールが `M` の真の祖先である | ドット記法（`x.f`）は、型の名前空間の定数だけを引く | `LangSemantics/Java/JDouble/Lemmas.lean` の `LangSemantics.Java.JDouble.pow2_eq` |
| E2 実行ファイルの入口 | ルートの `main` | Lake の `lean_exe` の入口はルートの `main` に限られる | `Tools/AxiomCheck.lean` の `main` |
| E3 明示した例外 | `n` かその接頭辞の定数に `@[ns_exception "<理由>"]` がある | 上のどれにも当たらない必要（理由を書く） | — |
| E4 型名のモジュールのインスタンス | `M` が `M` で定義された型で、`n` が `M` の親の名前空間に直接置かれたインスタンスか、その下の補助の定数である | `deriving` は、インスタンスを型の外の名前空間に `instReprT` と名付ける | `LangSemantics.Java.instReprJDouble` |

モジュールの作り方は、次のとおりとする。

* 主題の型が 1 つのモジュールは、モジュール名を型名にそろえる（`Spec/Prim/Date.lean` の型 `Spec.Prim.Date`、`Machine/Machine.lean` の型 `Machine.Machine`）。型より前に置く補助の定義は型の名前空間に置き、型の宣言は `open <型> in` で書く。
* 複数の型を集めたモジュールでは、型もモジュール名の下に置く（`Spec.Model.FlightType`）。
* 型の外から足すドット記法の補題は、型のモジュールの下位モジュールに置く（E1。`Machine/Refines/Adequacy.lean` の `Machine.Refines.InitSurj`）。型を定義するモジュールに置けるものは、そこに置く。
* 下位モジュールの名前は、集約のモジュールの名前と衝突させない。`namespace Test.X` の中で `open X` と書くと、Lean は `Test.X` を開く。そのため、検査のモジュールでは `open` を `namespace` の前に置く（[ADR c08b](c08b-test-namespace-for-skill-asset-tests.md)）。

### NS-2: 証明課題の配置（`Abstraction`・`Refinement`）

* R 課題（obligation-check の `refinements`）と W 課題（登録簿の `w_task` の ID を `@[obligation]` に持つ定理）は、機能の名前空間に直接置く（TR-L1）。機能の名前空間は `<層>.<x>` で、`x` は適用先の機能の対応表（ATRS では `trace/features.json` の `lean`）に挙げたものである。
* 機能のモジュール（`Abstraction/Fare.lean`）には、`@[obligation]` の定理と、R 課題の名前で始まる付帯の義務（`<R>_initSurj` など）だけを置く（TR-L2）。
* C 課題は機能の名前空間に置き、L 課題・核の課題・補題・α・差異の述語は、下位のモジュールに置く。C 課題と L 課題は道具では区別できないので、規約にとどめる。
* `Spec` の機能のモジュール（`Spec.Fare`）は、機械と SPEC 課題を持つ。`SourceModel`・`TargetModel` は、ソースの構造を写すので、NS-1 だけを課す。

### 道具

* `Trace.Layout`（`assets/lean/Trace/Layout.lean`）: NS-1 と E1〜E4 の判定。入口の `layout-check` は、スキルの assets（`Test/Trace/LayoutCheck.lean`）と適用先（ATRS では `lean/Tools/LayoutCheck.lean`）に置く。どちらも `main` を持つため、実行ファイルの入口のモジュールは、組を分けて読み込む。`trace-test` が、フィクスチャ `Test.Trace.LayoutFixture` と assets の定数で判定を確かめる。
* 属性 `@[ns_exception "<理由>"]`（`Trace.Attr`）: E3。`trace-dump` の属性には含めない。
* `trace check` の TR-L1・TR-L2（[traceability.md](../spec/traceability.md#検査)）。
* `scripts/lean/rename.py`: 完全名の対応表で、リポジトリのテキスト（Lean・Markdown・JSON など）を一度に書き換える。改名は 1000 件を超え、層をまたいで繰り返すため、手作業にせず道具にした。

### 既存の宣言の書き換え

* assets: `LangSemantics.Java.Double` を `JDouble` に、`LocalDate` を `JLocalDate` に、`Machine.Basic` を `Machine.Machine` に改名した。`Machine.Glue` は `Machine.Refines` から分けた。
* `Machine.Adequacy` は、型に属さない述語（`never`・`always`・`Covers`・`Nontrivial`・`KernelIs` など）だけにした。型ごとの定義は `Machine.{Machine,Concrete,Glue,Refines}.Adequacy` に分けた（E1）。義務の束 `Machine.Adequate`（[ADR ab9e](ab9e-adequate-bundle-sum-and-side-staging.md)）は型名のモジュール `Machine.Adequate` に置いた。
* 機械の並置（[ADR ab9e](ab9e-adequate-bundle-sum-and-side-staging.md)）は、型ごとに `Machine.{Machine,Concrete,Glue,Refines,Adequate}.Sum` に分けた（E1。`A₁.sum A₂`・`h₁.sum h₂` のドット記法のため）。型に属さない `sumPred` は `Machine.Sum.sumPred` にした。
* double の演算子の写し（`jd`・`jdmul` など）は `LangSemantics.Java.DoubleOps` に分けた。`Machine.toConcrete` は `Machine.Concrete.ofMachine` に改名した（ドット記法は技術的な必要ではないため、E3 にしない）。
* 適用先の書き換えは、適用先の作業項目に記録する（ATRS の backlog 9ed8）。

### Consequences

* Good, because 宣言の名前からファイルが分かり、`check_lean.py` と `trace-dump` の層の判定がそろう
* Good, because 機能ごとに、証明課題が 1 つのモジュールにまとまる
* Good, because 例外が 4 つに限られ、E3 は理由とともに一覧に出る
* Bad, because 名前が長くなり、利用側の `open` が増える。名前空間を開くと、同じ短い名前を持つ別の名前空間とぶつかることがある（例: `Spec.MasterData.boardingClassOf` と `Abstraction.MasterData.Load.boardingClassOf`）。型だけを開く選択の `open X (A B)` か、修飾した名前で避ける
* Bad, because 改名で Merkle ハッシュが変わり、合格の記録を取り直す（`trace rehash`）必要がある

### Confirmation

* `layout-check`（assets と適用先）が違反 0 で通る。`trace-test` がフィクスチャで NS-1・E1〜E4 を確かめる。
* `trace check` が TR-L1・TR-L2 を検査する。`cargo test` が違反例を確かめる。
* `rename.py --self-test` が通り、`rename.py check` で旧い名前が来歴の他に残っていない。

## More Information

* 前の規則: [lean/rules.md](../lang/lean/rules.md) の「ファイルパスと名前空間を一致させる」（検査は無かった）
* 関連: [ADR c08b](c08b-test-namespace-for-skill-asset-tests.md)（`Test.<ライブラリ>` の名前と `open` の注意）
* 来歴: 適用先 ATRS のオーナーの依頼（名前空間とファイル配置の関係が分かりにくい。技術的な必要がない限り一致させ、上位の証明課題を上位の名前空間に、補題を下位に置きたい）。
