---
type: Reference
title: "Lean プロジェクトの規約"
description: "形式化言語 Lean 4 のプロジェクトの規約: ツールチェーン、依存、禁止する構文、名前、静的検査。"
tags: [lean]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T19:19:29+09:00
---

# Lean プロジェクトの規約

Lean 4 は、すべてのモデルと証明を置く形式化言語である（[architecture.md](../../spec/architecture.md)）。

## ツールチェーンと依存

- Lean 4 を `lean-toolchain` で固定し、Lake でビルドする。
- 依存は core と Batteries にとどめることを推奨する。Mathlib はビルドが重く、移植先に写しにくい抽象（実数・代数構造）を持ち込みやすい。必要な証明は `omega`・`decide`・`simp` で賄う。
- JSON の読み書きは core の `Lean.Data.Json` を使う。

## 構成

```
lean/
  lean-toolchain
  lakefile.lean
  LangSemantics/<Lang>/   -- 言語意味論（アプリ非依存。スキルの assets/lean/LangSemantics/ を写すか Lake 依存にする）
  LangSemantics/Core/     -- 言語に依存しない列・Option の補題（アプリ非依存。スキルの assets）
  Machine/                -- 抽象機械とリファインメントの枠組み、汎用の核 Machine.Kernel.undefOrEq（アプリ非依存。スキルの assets/lean/Machine/ を Lake 依存にする）
  SourceModel/            -- 移植元モデル [Source]
  Spec/                   -- 抽象モデル [Spec]（正規仕様）
    Prim/                 --   基本演算（floorDiv, ceilTo, 暦日, 文字クラス）
    Port.lean             --   ポートの型
    UseCase/              --   ユースケース
  Abstraction/            -- SourceModel が Spec をリファインする（ABS-NNN）
  TargetModel/            -- 移植先モデル [Target]
  Refinement/             -- TargetModel が Spec をリファインする（REF-NNN）
  Trace/                  -- 追跡属性と trace-dump・obligation-check の本体（アプリ非依存。スキルの assets/lean/Trace/。trace-attributes.md）
  ConformanceKit/         -- 適合テストベクタの実行器（アプリ非依存。スキルの assets/lean/ConformanceKit/。spec/conformance.md）
  Tests/                  -- テストドライバ（lake test。操作の割当はプロジェクトが書き、実行は ConformanceKit を使う）
  Tools/                  -- 実行ファイル（ベクタ生成、trace-dump・obligation-check の入口、移植先の写しの生成器）
```

### ルートのワークスペース（LSP 用）

Lean の言語サーバ（`lake serve`）はリポジトリのルート（エディタで開いたフォルダ）で起動されることが多い。ルートに Lake プロジェクトが無いと、`import LangSemantics.…` などが解決されない（`unknown module prefix`）。
そのため、**リポジトリのルートを Lake ワークスペースにし、リポジトリ内の Lean パッケージをすべて `require` で取り込む**。

```lean
-- <リポジトリのルート>/lakefile.lean
import Lake
open Lake DSL
package <project>Workspace
require langSemantics from "./<スキルの置き場所>/spec-pivot/assets/lean"
require <project> from "./lean"
```

- ルートの `lean-toolchain` は、取り込むすべてのパッケージの `lean-toolchain` と同じ版にする。
- ルートの `.lake/` と `lake-manifest.json` のうち、`.lake/` は VCS から除外し、`lake-manifest.json` はコミットする。
- 確認: ルートで `lake setup-file <各パッケージのファイル>` が成功すること（LSP はこれを呼ぶ）。

- 宣言はモジュール名の下に置く（[モジュールと名前空間](#モジュールと名前空間)）。証明課題は機能のモジュールに置く（[証明課題の配置](#証明課題の配置)）。
- トップレベル名前空間は上記だけとする。`Machine`・`Trace`・`ConformanceKit`・`Tests`・`Tools` は例外として認められている。スキルの assets の検査は `Test.<ライブラリ>`（`assets/lean/Test/`）に置き、`Tests` と同じ層として扱う（[ADR c08b](../../decision/c08b-test-namespace-for-skill-asset-tests.md)）。適用先は `Test` を使わない。依存の向きは [architecture.md](../../spec/architecture.md#依存の向き) に従い、CI で検査する（`scripts/ci/check_lean.py`）。
- アプリに依存しない補題・道具は、プロジェクトに置かず、スキルの assets に足す。置き場所は次のとおり。
  - 特定の言語の意味論の補題 → `LangSemantics.<lang>`
  - どの言語にも依存しない列・`Option`・文字列の補題 → `LangSemantics.Core`
  - 標準の抽象化の汎用の核（部分写像の `undefOrEq` など）→ `Machine`
  - 適合テストの実行の道具 → `ConformanceKit`

  プロジェクトの業務の型（`Spec` の型・`SourceModel` のモデル）を参照するものは、プロジェクトに置く。

## モジュールと名前空間

Lean では、モジュール（ファイル）と名前空間は別の仕組みで、どのファイルからでもどの名前空間にも宣言を置ける。
この方法では、名前から定義の場所が分かるように、両者を一致させる（[ADR 1a30](../../decision/1a30-lean-module-namespace-layout.md)）。

- **NS-1**: 宣言 `n` のモジュールを `M` とする。`n = M` か、`n` が `M.` で始まる（`Spec/Fare.lean` の宣言は `Spec.Fare.*`）。自動生成の補助の定数と `private` の名前は対象外とする。
- 例外は、技術的な必要がある次の 4 つだけとする。

  | 例外 | 条件 | 例 |
  | --- | --- | --- |
  | E1 型の名前空間 | `n` が型 `T` の下にあり、`T` を定義したモジュールが `M` の真の祖先である（ドット記法 `x.f` のため） | `LangSemantics/Java/JDouble/Lemmas.lean` の `LangSemantics.Java.JDouble.pow2_eq` |
  | E2 実行ファイルの入口 | ルートの `main` | `Tools/AxiomCheck.lean` の `main` |
  | E3 明示した例外 | `n` かその接頭辞に `@[ns_exception "<理由>"]` がある（上に当たらない必要。理由を書く） | — |
  | E4 型名のモジュールのインスタンス | `M` が `M` で定義された型で、`n` が `M` の親の名前空間のインスタンスかその下の補助の定数である（`deriving` の名付けのため） | `LangSemantics.Java.instReprJDouble` |

- 主題の型が 1 つのモジュールは、モジュール名を型名にそろえる（`Spec/Prim/Date.lean` の型 `Spec.Prim.Date`）。型より前に要る補助の定義は型の名前空間に置き、型は `open <型> in` で宣言する。
- 複数の型を集めたモジュールでは、型もモジュール名の下に置く（`Spec/Model.lean` の `Spec.Model.FlightType`）。
- 型の外から足すドット記法の補題は、型のモジュールの下位モジュールに置く（E1。`Machine/Refines/Preserves.lean` の `Machine.Refines.InitSurj`）。型を定義するモジュールに置けるものは、そこに置く。ドット記法を使うためだけの E3 は認めない（関数の形で呼べるため）。
- 利用側は名前空間を `open` する。同じ短い名前がぶつかるときは、型だけを開く `open X (A B)` か、修飾した名前を使う。`namespace Test.X` の中の `open X` は `Test.X` を開くので、検査のモジュールでは `open` を `namespace` の前に置く。
- 検査: `lake exe layout-check`（本体は `Trace.Layout`。入口はスキルの assets と適用先にある）。違反があれば失敗し、E3 の一覧を出す。改名は `scripts/lean/rename.py` で、対応表から一度に行う。

## 証明課題の配置

`Abstraction`・`Refinement` では、機能の証明課題を機能のモジュールに、その補題を下位のモジュールに置く（[ADR 1a30](../../decision/1a30-lean-module-namespace-layout.md)）。

| 置き場所 | 置くもの |
| --- | --- |
| 機能のモジュール（`Abstraction/Fare.lean`。名前空間 `Abstraction.Fare`） | R 課題・W 課題・C 課題（`@[obligation]`）と、R 課題の名前で始まる付帯の義務（`<R>_initSurj` など） |
| 下位のモジュール（`Abstraction/Fare/Alpha.lean` など） | α・貼り合わせ・差異の述語、L 課題、核の課題、補題、証人 |

- 機能の名前空間は `<層>.<x>` で、`x` は適用先の機能の対応表（`trace/features.json` の `lean`）に挙げたものとする。
- `trace check` の TR-L1 は、R 課題と W 課題が機能の名前空間に直接あることを、TR-L2 は、機能のモジュールに上の表のもの以外が無いことを確かめる（[traceability.md](../../spec/traceability.md#検査)）。C 課題と L 課題は道具で区別できないので、この表で分ける。
- `Spec` の機能のモジュール（`Spec/Fare.lean`）は、機械と SPEC 課題を持ち、補助は `Spec.Fare.*` の下位に置いてよい。`SourceModel`・`TargetModel` はソースの構造を写すので、NS-1 だけを課す。`SourceModel` のモジュールは原典のソースツリーの形に並べる（言語パックの `layout.md`。TR-M）。

## 書き方

- `Spec` と `TargetModel` は **実行可能** でなければならない（ベクタの期待値を生成するため）。命題で述べたい性質は、計算可能な定義に対する定理として書く。
- `Spec` の各機能は、抽象機械（`Machine.Machine`）として与える。操作には、関係 `step` と実行可能な標準の選択 `run` を与え、定理 `PRE → step s i (run s i)` を持たせる。
- `TargetModel` は、移植先の写しの生成器が扱える部分集合で書く。部分集合は次のとおりで、この一覧を正とする。
  - 構造的再帰
  - `match`・`if`・`let`
  - `Except`・`Option`
  - `structure`・`inductive`
  - `LangSemantics.<移植先>` の演算
- `SourceModel` は移植元ソースの構造を、`TargetModel` は移植先ソースの構造（関数の分け方・評価順・エラーの返し方）を、そのまま写す。最適化を抽象化してはならない。抽象化は `Abstraction` / `Refinement` の仕事である。
- `SourceModel` の式は、言語パックに式の構文があればそれで書く（Java は `java!`）。原典と同じ字面になり、展開した項は原始関数の項と同じである。
- `LangSemantics` にはアプリ固有の型・用語を入れてはならない。言語仕様の該当節を docstring と `lang:` ロケータに書く。
- 言語の例外・パニックは、`LangSemantics.<Lang>` の値として明示的に表す。Lean の `panic!` で表してはならない。

## 全域性と安全性

- `Trace`・`Tests`・`Tools` 以外では、`partial`, `unsafe`, `panic!`, `get!`, `xs[i]!`, `sorry`, `implemented_by`, `native_decide` を使ってはならない。`Tests`・`Tools` では I/O 境界に限り `partial` を許す。`native_decide`・`bv_decide` は `Tests` だけで許す（`Lean.ofReduceBool` の公理を持ち込むため）。
- 停止性は構造的再帰か `termination_by` で示す。
- 失敗しうる操作は `Except <Error> α`（または `Option`）を返す。
- `Float` は `Tests` での突き合わせ以外で使ってはならない。言語の浮動小数は、言語パックのソフトモデル（例: `LangSemantics.Java.JDouble`）で表す。
- `axiom` を追加してはならない（`propext`, `Quot.sound`, `Classical.choice` 以外）。CI で `#print axioms` を確認する。

## 型（Spec）

| 量 | 型 |
| --- | --- |
| 非負が保証される量（金額・個数・日数・百分率） | `Nat` |
| 符号を持つ中間値 | `Int` |
| コード値 | 専用 `structure`（`String` を包む）または `inductive` |
| 列挙 | `inductive` + `DecidableEq` + `Repr` + JSON 変換 |
| 暦日・時刻 | `Spec.Prim.Date`, `Spec.Prim.Time.HourMinute`（妥当性を型で保証） |
| 不変条件付きの値 | `Subtype` または証明フィールド付き `structure` |

- 移植先に写しにくい高度な型機能（依存型による長さ付きベクタ等）は証明側（`Abstraction`・`Refinement`）に閉じ込め、`Spec` の公開関数のシグネチャは素朴な型にとどめる。
- `SourceModel` / `TargetModel` の型は、それぞれの言語の型に対応させる（言語パックの `semantics.md`）。

## 命名

- 型: `UpperCamelCase`、関数・フィールド: `lowerCamelCase`、定理: `snake_case`。
- `Spec` は仕様の用語、`SourceModel` / `TargetModel` はそれぞれのソースの識別子（lowerCamelCase に写したもの）を優先する。
- 下位の名前空間は層をまたいで同じ機能名を使う。
- 定理名は対象と性質を表す（`basicFare_source_eq_spec_of_seed`, `basicFare_target_refines_spec`）。

## 証明

- 使ってよい自動化: `simp`, `omega`, `decide`, `grind`（利用可能なら。`#print axioms` で公理を確認する）。`native_decide`・`bv_decide` は証明に使ってはならない（`Tests` の確認だけに使う）。
- 主定理には `@[obligation "ABS-NNN"]` / `@[obligation "REF-NNN"]` を付ける。R 課題の主定理は `Machine.Refines` の形とし、仮定は PRE・INV・`@[deviation]` 付きの述語だけとする（[architecture.md](../../spec/architecture.md#リファインメントb-メソッド)）。W 課題の必要性の定理は、R 課題の命題から差異を外したものの否定（`¬ Refines …`。基底が `ofChoice` なら `¬ (Refines … ∧ Refines.Pinned …)` でもよい）の形で、両向きの例とは別の閉じた定理とする。他の差異に覆われる差異は `Machine.Preserves.Covers` を示す（[architecture.md](../../spec/architecture.md#空虚化を防ぐ義務)）。
  - 形: `Machine.Refines (A.restrict dev_D001) (C.restrict dev_D019) glue`。`A : Machine.Machine σ ι ο` は `Spec` の抽象機械、`C : Machine.Concrete τ ι' ο' ε` はモデルの具体機械、`glue : Machine.Glue …` は `J`・`αi`・`αo` である。
  - 前提型の差異は、抽象側なら `Machine.Machine.restrict`（入力の述語）・`restrictState`（状態と入力の述語）、具体側だけにある入力なら `Machine.Concrete.restrict` で表す。観測型の差異は、`glue` の `J`・`αo` の名前付きの成分にする。
  - `Spec` 自身の課題は `Machine.Machine.Sound`（INIT ⇒ INV、INV の保存）で表す。標準の選択が関係に含まれることは、`Machine.Machine` の成分 `run_step` である。
  - 状態を持たない計算は `Machine.Machine.pure`・`Machine.Concrete.pure` と `Machine.Refines.of_pure` で簡単に示せる。
- 既知差異は、名前付きの述語（前提型）または貼り合わせ関係・出力の対応の名前付きの成分（観測型）として定義し、`@[deviation "D-NNN"]` / `@[deviation "T-NNN"]` を付ける。無名の仮定で差異を吸収してはならない。
- 差異の登録は `Abstraction.Gap`・`Refinement.Gap` の `@[gap_entry]` の宣言に書き、差異の生じる定義に `@[gap]` を付ける（[trace-attributes.md](trace-attributes.md#ギャップの登録簿)）。
- 証明が未完の定理を `sorry` で残してはならない。

## スタイル

- 1 ファイル 400 行程度を目安に分割する。
- 公開定義には docstring を付ける。仕様文書との対応は `@[spec_doc]` に書く。
