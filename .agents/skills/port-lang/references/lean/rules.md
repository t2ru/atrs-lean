# Lean プロジェクトの規約

Lean 4 は、すべてのモデルと証明を置く形式化言語である（[architecture.md](../architecture.md)）。

## ツールチェーンと依存

- Lean 4 を `lean-toolchain` で固定し、Lake でビルドする。
- 依存は core と Batteries にとどめることを推奨する。Mathlib はビルドが重く、移植先に写しにくい抽象（実数・代数構造）を持ち込みやすい。必要な証明は `omega`・`decide`・`simp` で賄う。
- JSON の読み書きは core の `Lean.Data.Json` を使う。

## 構成

```
lean/
  lean-toolchain
  lakefile.lean
  LangSemantics/<Lang>/   -- 言語意味論（アプリ非依存。スキルの assets/LangSemantics/ を写すか Lake 依存にする）
  Machine/                -- 抽象機械とリファインメントの枠組み（アプリ非依存。スキルの assets/Machine/ を Lake 依存にする）
  SourceModel/            -- 移植元モデル [Source]
  Spec/                   -- 抽象モデル [Spec]（正規仕様）
    Prim/                 --   基本演算（floorDiv, ceilTo, 暦日, 文字クラス）
    Port.lean             --   ポートの型
    UseCase/              --   ユースケース
  Abstraction/            -- SourceModel が Spec をリファインする（ABS-NNN）
  TargetModel/            -- 移植先モデル [Target]
  Refinement/             -- TargetModel が Spec をリファインする（REF-NNN）
  Trace/                  -- 追跡属性と trace-dump（trace-attributes.md）
  Tests/                  -- テストドライバ（lake test）
  Tools/                  -- 実行ファイル（ベクタ生成、trace-dump、移植先の写しの生成器）
```

### ルートのワークスペース（LSP 用）

Lean の言語サーバ（`lake serve`）はリポジトリのルート（エディタで開いたフォルダ）で起動されることが多い。ルートに Lake プロジェクトが無いと、`import LangSemantics.…` などが解決されない（`unknown module prefix`）。
そのため、**リポジトリのルートを Lake ワークスペースにし、リポジトリ内の Lean パッケージをすべて `require` で取り込む**。

```lean
-- <リポジトリのルート>/lakefile.lean
import Lake
open Lake DSL
package <project>Workspace
require langSemantics from "./<スキルの置き場所>/port-lang/assets"
require <project> from "./lean"
```

- ルートの `lean-toolchain` は、取り込むすべてのパッケージの `lean-toolchain` と同じ版にする。
- ルートの `.lake/` と `lake-manifest.json` のうち、`.lake/` は VCS から除外し、`lake-manifest.json` はコミットする。
- 確認: ルートで `lake setup-file <各パッケージのファイル>` が成功すること（LSP はこれを呼ぶ）。

- ファイルパスと名前空間を一致させる（`Spec.Fare` は `Spec/Fare.lean`）。
- トップレベル名前空間は上記だけとする。`Machine`・`Trace`・`Tests`・`Tools` は例外として認められている。依存の向きは [architecture.md](../architecture.md#依存の向き) に従い、CI で検査する。

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
| 暦日・時刻 | `Spec.Prim.Date`, `Spec.Prim.HourMinute`（妥当性を型で保証） |
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
- 主定理には `@[obligation "ABS-NNN"]` / `@[obligation "REF-NNN"]` を付ける。R 課題の主定理は `Machine.Refines` の形とし、仮定は PRE・INV・`@[deviation]` 付きの述語だけとする（[architecture.md](../architecture.md#リファインメントb-メソッド)）。
- 既知差異は、名前付きの述語（前提型）または貼り合わせ関係・出力の対応の名前付きの成分（観測型）として定義し、`@[deviation "D-NNN"]` / `@[deviation "T-NNN"]` を付ける。無名の仮定で差異を吸収してはならない。
- 証明が未完の定理を `sorry` で残してはならない。

## スタイル

- 1 ファイル 400 行程度を目安に分割する。
- 公開定義には docstring を付ける。仕様文書との対応は `@[spec_doc]` に書く。
