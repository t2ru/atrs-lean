---
type: Reference
title: "Lean の追跡属性と trace-dump"
description: "Lean の追跡属性・ギャップの登録簿と、trace-dump・obligation-check の実装。"
tags: [lean, traceability]
status: stable
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T22:00:00+09:00
---

# Lean の追跡属性と trace-dump

追跡の考え方は [traceability.md](../../spec/traceability.md)。ここでは Lean 側の実装を定める。
実装はスキルの `assets/lean/Trace/` にあり、プロジェクトは Lake の依存（`require langSemantics`）として取り込む。

| モジュール | 内容 |
| --- | --- |
| `Trace.Attr` | 文字列引数の追跡属性 |
| `Trace.Gap` | ギャップの登録簿（`Trace.Gap`・`@[gap_entry]`） |
| `Trace.Dump` | `trace-dump` の本体 |
| `Trace.Obligation` | `obligation-check` の本体（TR-G の Lean 側と GK） |
| `Trace.Layout` | `layout-check` の本体（宣言がモジュール名の下にあること。[rules.md](rules.md#モジュールと名前空間)）。モジュールの組は組ごとに別のプロセスで判定する（[ADR 89f2](../../decision/89f2-layout-check-one-process-per-group.md)） |

道具の入口（`main`）は、モデルを import するプロジェクトの側に置く（例: `Tools/TraceDump.lean` が `Trace.Dump.loadEnv` と `Trace.Dump.dumpJson` を呼ぶ）。
`assets/lean/` の `lake exe trace-test` は、`Test/Trace/` のフィクスチャで `trace-dump`・`obligation-check`・`layout-check` の処理を確かめる。
`assets/lean/` の `lake exe layout-check` は、スキルの assets 自身の宣言を確かめる。

## 属性

`Trace` 名前空間（どのモデルにも依存しない基盤）に、次の属性を定義する。
引数は文字列リテラルの並びとする。属性は環境拡張（`registerParametricAttribute` 等）に記録し、`trace-dump` が読み出せるようにする。

| 属性 | 付ける対象 | 引数 |
| --- | --- | --- |
| `@[source "<locator>@<hash>", …]` | `SourceModel`、移植元の `LangSemantics` の定義 | 移植元ロケータと検査済みの本文ハッシュ（`dep:`・`lang:` は版） |
| `@[target "<locator>@<hash>", …]` | `TargetModel`、移植先の `LangSemantics` の定義 | 移植先ロケータと検査済みの本文ハッシュ |
| `@[obligation "<ID>"]` | `Abstraction`・`Refinement` の主定理と補題、`Spec` 自身の証明課題の定理 | `ABS-NNN` / `REF-NNN` / `SPEC-NNN` |
| `@[deviation "<ID>"]` | 既知差異の前提の述語（前提型）、または貼り合わせ関係・出力の対応の成分（観測型） | `D-NNN` / `T-NNN`。1 つの定数に 1 つだけ（同じ出力に重なる観測型の差異は、定数を分けて `Machine.Preserves.anyOf` で並べる） |
| `@[gap "<ID>", …]` | ギャップの生じる `Spec`・`SourceModel`・`TargetModel` の定義（箇所の印）。`D-NNN` は `Spec`・`SourceModel`、`T-NNN` は `Spec`・`TargetModel` に付ける | `D-NNN` / `T-NNN`。宣言（`@[gap_entry]`）のある ID |
| `@[nondet "<ID>"]` | `Spec` の非決定性の選択の型（`Machine.ofChoice` の選択の型の葉） | `N-NNN` |
| `@[std_abs "<path>#<anchor>"]` | 標準の抽象化 α/β の部分写像（`Glue.ofStd` の β・aᵢ・aₒ と、その部品）、環境の写像 `ce`、`FreeFrame` の射影 | α・β の表の節 |
| `@[kernel "<path>#<anchor>"]` | 標準の抽象化の核（同一視する関係。`KernelIs` の K） | α・β の表の節 |
| `@[env_pre "<ID>"]` | 入口の機械の環境の前提（`TotalUnder` の Env） | `MD-N` など |
| `@[spec_doc "<path>#<anchor>"]` | `Spec` の公開定義 | 仕様文書の節 |
| `@[no_source "<理由>"]` | 移植元に対応の無い `Spec` の定義 | 理由 |
| `@[ns_exception "<理由>"]` | モジュール名の下に置けない宣言（`layout-check` の例外 E3。[rules.md](rules.md#モジュールと名前空間)）。`trace-dump` の属性には出さない | 技術的な必要 |

例:

```lean
@[source "java:com.example.FareService#basicFare(int,int)@9c1e…", "lang:java#JLS-15.17.1@java-21"]
def basicFare (routeFare extra : Int32) : JResult Int32 := ...
```

- 属性の付け忘れは検査 TR-S1 / TR-T1 で、ロケータの誤りは TR-R で、差異の付け忘れ・余分は TR-D で検出される。
- `@[nondet]` の付け忘れ・余分と、`@[std_abs]`・`@[kernel]`・`@[env_pre]` の付け忘れは、TR-N・TR-G で検出される。追跡属性はモデルの層の定数にだけ付ける（TR-G の G0）。
- `@[source]` / `@[target]` のハッシュは、決定論的な検査が合格したときに道具（`rehash`）が書き込む。手で書き換えてはならない（[traceability.md](../../spec/traceability.md#検査済みハッシュ)）。
- 移植元側の層に `@[target]` を、移植先側の層に `@[source]` を付けてはならない（TR-X）。
- `@[gap]` の不足・誤りは TR-K と obligation-check の GK で検出される。属性は `merkle` に含まれないので、印を足しても `@[source]` の再検査は要らない。

## ギャップの登録簿

`Spec` とモデルのギャップは、差異（前提型・観測型・モデル外。[architecture.md](../../spec/architecture.md#差異)）と、それに準じて明示するもの（`Spec` の PRE の外での振る舞い・種類が未確定のもの）である。
登録簿の正は Lean とし、ID ごとに型 `Trace.Gap` の宣言を 1 つ置いて `@[gap_entry]` を付ける。`D-NNN` は `Abstraction` の層（例: `Abstraction.Gap`）、`T-NNN` は `Refinement` の層（例: `Refinement.Gap`）に置く。
説明（表の「差異」「振る舞い」「状況」の列）は宣言の docstring に Markdown で書く。文書の表は、道具が `trace-dump` の `gaps` から生成する（手で編集しない）。

```lean
/-- [Source] は税込み価格を `price * 1.1` の double で計算して切り捨てる。[Spec] は `floorDiv(price * 110, 100)` -/
@[gap_entry]
def D001 : Trace.Gap where
  id := "D-001"
  kind := .pre
  sites := [⟨"税込み価格", "docs/spec/pricing.md#税込み価格", ""⟩]
  premise := "`dev_D001`: `price` が 0〜100,000"
  deviations := [``Abstraction.Pricing.dev_D001]
  evidence := .refuted [``Abstraction.Pricing.need_D001]
  rTasks := ["ABS-001"]
  impact := some (.abort, "差のある価格が注文に保存される")
  backlog := ["<Lean 側を完了させる作業項目の ID>"]
```

| 種類（`kind`） | 意味 | 必須の欄 | 書かない欄 | 許す証明の状態 | 印・差異の定数 |
| --- | --- | --- | --- | --- | --- |
| `pre`・`preConcreteInput`・`preConcreteState`・`preConcreteEnv` | 前提型（抽象側／具体側の入力・状態・環境） | `premise`（前提）・`rTasks`・`impact`・`backlog` | — | `refuted`・`covered`・`pending` | `Spec` と具体側の `@[gap]`。`@[deviation]`（すべて `deviations` に挙げる） |
| `observational` | 観測型 | `premise`（成分）・`rTasks` | `impact` | `refuted`・`covered`・`pending` | 同上 |
| `outOfModel` | モデル外 | `premise`（モデル外とする理由） | `deviations`・`rTasks`・`impact` | `unformalized` | 主張のほかに持たない |
| `outsidePre` | `Spec` の PRE・INV の外での具体側の振る舞い（差異ではない） | `premise`（それを除く `Spec` の前提） | `deviations`・`rTasks`・`impact` | `excludedBy` | `Spec` と具体側の `@[gap]`。`@[deviation]` は持たない |
| `undetermined` | 種類が未確定 | — | `premise`・`deviations`・`rTasks`・`impact` | `unformalized`（確定させる作業を書く）・`pending` | `@[deviation]` は持たない |

- `sites`（1 つ以上）は、リポジトリのルートからの文書のパスとアンカーで書く。表では文書からの相対リンクになり、`note` はリンクの後に続く。
- 名前（`deviations` と証明の状態の宣言）は ``` ``名前`` ``` で書く。存在しない名前は、エラボレートの時点で誤りになる。
- 値は、定義の展開だけで構築子・文字列リテラル・名前リテラルの組み合わせになる式で書く（`Trace.Gap.ofConst?` が評価せずに式から読む）。
- `@[gap_entry]` は付けた時点で値を読み、種類ごとの必須の欄・書かない欄と、種類と証明の状態の組み合わせ（`Trace.Gap.problems`）を検査する。
- `backlog` は、Lean 側（箇所の印・裏付けの宣言）を完了させる作業項目である。前提型の影響の表の列にもなる。TR-K の段階導入に使う。

### 証明の状態（`evidence`）

ギャップは、リファインメントの証明の中で証明できない部分である。それを公理や `sorry` で仮定してはならない。
ギャップが実在すれば、差異を外したリファインメントは偽なので、それを公理にすると矛盾する。
代わりに、ギャップごとに「なぜ証明できないか」を状態（`Trace.Gap.Evidence`）で示し、状態を裏付ける Lean の宣言に `@[gap "<ID>"]` を付ける。
裏付けの宣言は、証明の層（`Abstraction`・`Refinement`）に置いてよい。

| 状態 | 意味 | 裏付けの宣言 | W 課題（表の列） |
| --- | --- | --- | --- |
| `.refuted [thm, …]` | 偽を証明済み。差異を外した R 課題の否定が定理である | 必要性の定理（G9 の形の `¬ Refines …`） | 定理の `@[obligation]` |
| `.covered M [thm, …]` | 被覆。必要な差異の述語 `M` が、この差異を覆う | `Machine.Preserves.Covers M d`・`Covers₂ M d` の定理（`d` は `deviations` のどれか） | 定理の `@[obligation]` |
| `.pending 理由 (some W)` | 未証明。前提で制限して R 課題を証明したが、必要性（偽）も一致（真）もまだ示していない | なし | 予定の `W` |
| `.unformalized claim 作業` | 形式化していない。Lean の命題として書けない（モデル外、または未確定で命題をまだ書けない） | `opaque claim : Prop`（docstring に主張を書く） | — |
| `.excludedBy [pre, …]` | 差異ではない。`Spec` の PRE・INV の外である | 前提の述語（`Spec` の箇所の印を兼ねる） | — |

- 制限（`restrict`）は仮定を強めるだけなので、差異が実在してもしなくても、`pending` の R 課題は公理なしに証明できる。
- `opaque c : Prop` は公理を足さず（axiom-check を通る）、定義が見えないので、Lean の中で真とも偽とも証明できない。どの定数からも参照してはならない（仮定として推論に持ち込まない）。
- 状態は確定に向けて移す。
  - `pending` は、必要性の定理ができたら `refuted` に移す。一致が証明できたら、差異を取り消す。
  - `unformalized`（未確定）は、モデルができたら命題に書き直して `pending` か `refuted` に移す。
- 前提型・観測型で Lean に述語がまだ無いものは、`deviations := []` と `.pending "Lean に述語がまだ無い" (some W)` にする。

```lean
/-- D-013 の主張: [Source] は照合と更新を別のトランザクションで行うので、並行実行の下では [Spec] と観測が異なりうる -/
@[gap "D-013"] opaque claim_D013 : Prop

/-- …（説明） -/
@[gap_entry]
def D013 : Trace.Gap where
  id := "D-013"
  kind := .outOfModel
  sites := [⟨"トランザクション", "docs/spec/ports.md#トランザクション", "（規範節）"⟩]
  premise := "— モデル外（並行実行はモデルに現れない）"
  evidence := .unformalized ``claim_D013 ""
```

### 検査

- obligation-check の GK（`Trace.Obligation`）
  - 宣言の層と docstring、ID の重複
  - 印の層と、印の ID の宣言（裏付けの宣言は証明の層でもよい）
  - `@[deviation]` の ID が前提型・観測型の宣言を持ち、その `deviations` に挙がっていること
  - 種類と印・差異の定数が矛盾しないこと
  - 状態ごとの裏付け
    - `refuted`: 定理が、どれかの R 課題について `deviations` のどれかの必要性の定理である
    - `covered`: 定理の型と、被覆の連鎖が循環せずに `refuted` の差異に着くこと
    - `pending`: 必要性の定理が無いこと
    - `unformalized`: 主張が `opaque` の `Prop` で、どの定数からも参照されないこと
    - 裏付けの宣言が `@[gap "<ID>"]` を持つこと
  - `pending` の差異の G9 の誤りは、`warnings` に下げる
- `trace check` の TR-K は、`pending` を段階導入の指摘にする（`backlog` がすべて完了したら誤り）。

## trace-dump

`lake exe trace-dump` は、全定義について次を JSON で出力する。

```json
{
  "name": "TargetModel.Fare.basicFare",
  "layer": "TargetModel",
  "attributes": { "target": ["rust:app::fare::basic_fare@41d0…"] },
  "merkle": "77ab…",
  "references": ["LangSemantics.Rust.Int.U64.add", "TargetModel.Fare.ratio"],
  "module": "TargetModel.Fare"
}
```

出力の最上位は `{"lean_version", "definitions": [...], "gaps": [...]}` である。`gaps` の各要素は、登録の宣言の名前・モジュール・値の各欄（`id`・`kind`・`kind_label`・`sites`・`premise`・`r_tasks`・`impact`・`backlog`）・証明の状態（`evidence`: `state`・`label`・`witnesses`・`reason`・`coverer`・`pre`）・W 課題（`w_task`。裏付けの定理の `@[obligation]` か予定）・確定させる作業（`resolution`）・docstring（`doc`）と、同じ ID の `@[gap]` の定数（`markers`）・`@[deviation]` の定数（`deviations`）からなる。`obligation-check` の JSON も同じ `gaps` を持つ。

- `references`: 定義の型と本体に現れる定数。`Abstraction`・`Refinement` の定理については、これからモデル間の対応を自動導出する（どの `SourceModel` / `TargetModel` 定義がどの `Spec` 定義と結ばれているか）。
- `merkle`: 定義の型と本体の `Expr` のハッシュに、`references` のうち **同じ層と、その層が依存する `LangSemantics`・`Machine`** の定数の `merkle` を名前順に合成したもの。`LangSemantics` の変更でも、写しのハッシュがずれるようにするためである。依存する定義が変わっても値が変わる。循環参照（相互再帰）は、強連結成分ごとにまとめて計算する。
- `merkle` は属性を含まない。注釈のハッシュを `rehash` が書き換えても変わらない。
- `module`: 定義のあるモジュール。`rehash` が注釈を書き換えるファイルを引くのに使う。
- ハッシュは処理系の内部表現に依存しうる。Lean の版を上げると、全定義の `merkle` が変わることがある。そのため版上げでは、移植先の写しを一括で再生成し、移植先の検証器を再実行する。
