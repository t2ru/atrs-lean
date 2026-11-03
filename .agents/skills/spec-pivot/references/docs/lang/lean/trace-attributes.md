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
| `Trace.Id` | 追跡の値の型（ID・空でない文字列と列・文書の節・ロケータ）と、その字面のマクロ |
| `Trace.Attr` | 追跡属性（引数を、付けた時点で `Trace.Id` の型に解析する） |
| `Trace.Gap` | ギャップの登録簿（`Trace.Gap`・`@[gap_entry]`） |
| `Trace.Dump` | `trace-dump` の本体 |
| `Trace.Obligation` | `obligation-check` の本体（TR-G の Lean 側と GK） |
| `Trace.Layout` | `layout-check` の本体（宣言がモジュール名の下にあること。[rules.md](rules.md#モジュールと名前空間)）。モジュールの組は組ごとに別のプロセスで判定する（[ADR 89f2](../../decision/89f2-layout-check-one-process-per-group.md)） |

道具の入口（`main`）は、モデルを import するプロジェクトの側に置く（例: `Tools/TraceDump.lean` が `Trace.Dump.loadEnv` と `Trace.Dump.dumpJson` を呼ぶ）。
`assets/lean/` の `lake exe trace-test` は、`Test/Trace/` のフィクスチャで `trace-dump`・`obligation-check`・`layout-check` の処理を確かめる。
`assets/lean/` の `lake exe layout-check` は、スキルの assets 自身の宣言を確かめる。

## 属性

`Trace` 名前空間（どのモデルにも依存しない基盤）に、次の属性を定義する。
引数は文字列リテラルの並びとする。付けた時点で、属性ごとの型（下の表の「引数」の形式。`Trace.Id`）に解析し、その型の値として環境拡張（`registerParametricAttribute`）に記録する。形式に合わない引数は、付けた時点で誤りになる（不正な状態を表現できない型。[ADR bf1b](../../decision/bf1b-make-illegal-states-unrepresentable.md)）。`trace-dump` は文字列に戻して出す。

| 属性 | 付ける対象 | 引数 |
| --- | --- | --- |
| `@[source "<locator>@<hash>", …]` | `SourceModel`、移植元の `LangSemantics` の定義 | 移植元ロケータと検査済みの本文ハッシュ（`dep:`・`lang:` は版）。型 `Locator`（`<scheme>:<locator>@<pin>`） |
| `@[target "<locator>@<hash>", …]` | `TargetModel`、移植先の `LangSemantics` の定義 | 移植先ロケータと検査済みの本文ハッシュ。型 `Locator` |
| `@[obligation "<ID>"]` | `Abstraction`・`Refinement` の主定理と補題、`Spec` 自身の証明課題の定理 | `ABS-NNN` / `REF-NNN` / `SPEC-NNN` |
| `@[deviation "<ID>"]` | 既知差異の前提の述語（前提型）、または貼り合わせ関係・出力の対応の成分（観測型） | `D-NNN` / `T-NNN`。構文が 1 つだけを受ける（同じ出力に重なる観測型の差異は、定数を分けて `Machine.Preserves.anyOf` で並べる） |
| `@[gap "<ID>", …]` | ギャップの生じる `Spec`・`SourceModel`・`TargetModel` の定義（箇所の印）。`D-NNN` は `Spec`・`SourceModel`、`T-NNN` は `Spec`・`TargetModel` に付ける | `D-NNN` / `T-NNN`。宣言（`@[gap_entry]`）のある ID |
| `@[nondet "<ID>"]` | `Spec` の非決定性の選択の型（`Machine.ofChoice` の選択の型の葉） | `N-NNN` |
| `@[std_abs "<path>#<anchor>"]` | 標準の抽象化 α/β の部分写像（`Glue.ofStd` の β・aᵢ・aₒ と、その部品）、環境の写像 `ce`、`FreeFrame` の射影 | α・β の表の節。型 `DocAnchor`（`<path>.md` か `<path>.md#<anchor>`。`kernel`・`spec_doc` も同じ） |
| `@[kernel "<path>#<anchor>"]` | 標準の抽象化の核（同一視する関係。`KernelIs` の K） | α・β の表の節 |
| `@[env_pre "<ID>"]` | 入口の機械の環境の前提（`TotalUnder` の Env） | `MD-N`・`CFG` など（英大文字と、任意の `-` と数字） |
| `@[spec_doc "<path>#<anchor>"]` | `Spec` の公開定義 | 仕様文書の節 |
| `@[no_source "<理由>"]` | 移植元に対応の無い `Spec` の定義 | 理由 |
| `@[raw_input "<理由>"]` | 外部から来る値を、不正な値も表せる生の型のまま置く `Spec` の型（[ADR bf1b](../../decision/bf1b-make-illegal-states-unrepresentable.md)。検査 MISU-1 の対象外。その `Valid` は機械の PRE） | 外部の出所 |
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
  id := gid!"D-001"
  sites := ne![⟨ne!"税込み価格", ne!"docs/spec/pricing.md#税込み価格", ""⟩]
  body := .pre {
    side := .abstract
    premise := ne!"`dev_D001`: `price` が 0〜100,000"
    evidence := .refuted ne![``Abstraction.Pricing.dev_D001] ne![``Abstraction.Pricing.need_D001]
    rTasks := ne![oid!"ABS-001"]
    impact := .abort
    impactReason := ne!"差のある価格が注文に保存される"
    backlog := ne![bid!"<Lean 側を完了させる作業項目の UUID>"] }
```

値の型は、種類ごとに要る欄と許す証明の状態だけを持つ和型である（不正な状態を表現できない型。[ADR bf1b](../../decision/bf1b-make-illegal-states-unrepresentable.md)）。不正な組み合わせは、エラボレートの時点で型の誤りになる（例は `assets/lean/Test/Trace/GapErrors.lean`）。

| 本体（`body`） | 種類（表の `kind`） | 欄 | 証明の状態（`evidence`） | 印・差異の定数 |
| --- | --- | --- | --- | --- |
| `.pre { side, … }` | `side` が `.abstract`・`.concreteInput`・`.concreteState`・`.concreteEnv` の前提型（抽象側／具体側の入力・状態・環境） | `premise`（前提）・`evidence`・`rTasks`（1 つ以上）・`impact`・`impactReason`・`backlog`（1 つ以上） | `TypedEvidence`: `refuted`・`covered`・`pending` | `Spec` と具体側の `@[gap]`。`@[deviation]`（すべて証明の状態の `deviations` に挙げる） |
| `.observational { … }` | 観測型 | `component`（成分）・`evidence`・`rTasks`（1 つ以上）・`backlog` | `TypedEvidence` | 同上 |
| `.outOfModel { … }` | モデル外 | `reason`（モデル外とする理由）・`claim`（主張）・`resolution`・`backlog` | 形式化していない（だけ） | 主張のほかに持たない |
| `.outsidePre { … }` | `Spec` の PRE・INV の外での具体側の振る舞い（差異ではない） | `excludingPre`（それを除く `Spec` の前提）・`pre`（前提の述語）・`backlog` | PRE の外（だけ） | `Spec` と具体側の `@[gap]`。`@[deviation]` は持たない |
| `.undetermined { … }` | 種類が未確定 | `evidence`・`backlog` | `UndeterminedEvidence`: `pending`・`unformalized`（確定させる作業を書く） | `@[deviation]` は持たない |

- 字面は `Trace.Id` のマクロで書く。`gid!"D-001"`（`D-NNN`・`T-NNN`）、`oid!"ABS-001"`（`ABS-NNN`・`REF-NNN`・`SPEC-NNN`）、`bid!"<UUID>"`、空でない文字列 `ne!"…"`、空でない列 `ne![…]`。形式に合わない字面は型の誤りになる。
- `TypedEvidence` の各構築子は、その ID の `@[deviation]` の定数 `deviations` を持つ。`refuted`・`covered` では 1 つ以上で、`pending` では空でもよい（Lean に述語がまだ無い）。
- `sites`（1 つ以上）は、リポジトリのルートからの文書のパスとアンカーで書く。表では文書からの相対リンクになり、`note` はリンクの後に続く。
- 名前（差異の定数と証明の状態の宣言）は ``` ``名前`` ``` で書く。存在しない名前は、エラボレートの時点で誤りになる。
- 値は、定義の展開だけで構築子・文字列リテラル・名前リテラルの組み合わせになる式で書く（`Trace.Gap.ofConst?` が評価せずに式から読む）。`@[gap_entry]` は付けた時点で、値を読めることを確かめる。
- `backlog` は、Lean 側（箇所の印・裏付けの宣言）を完了させる作業項目である。前提型の影響の表の列にもなる。TR-K の段階導入に使う。
- 構造体の字面の欄を改行で続けるときは、`{` の直後で改行し、欄の桁をそろえる（後の欄の桁が最初の欄より左だと、構文の誤りになる）。

### 証明の状態（`evidence`）

ギャップは、リファインメントの証明の中で証明できない部分である。それを公理や `sorry` で仮定してはならない。
ギャップが実在すれば、差異を外したリファインメントは偽なので、それを公理にすると矛盾する。
代わりに、ギャップごとに「なぜ証明できないか」を状態（`Trace.Gap.Evidence`）で示し、状態を裏付ける Lean の宣言に `@[gap "<ID>"]` を付ける。
裏付けの宣言は、証明の層（`Abstraction`・`Refinement`）に置いてよい。

| 状態 | 意味 | 裏付けの宣言 | W 課題（表の列） |
| --- | --- | --- | --- |
| `.refuted devs [thm, …]` | 偽を証明済み。差異を外した R 課題の否定が定理である | 必要性の定理（G9 の形の `¬ Refines …`） | 定理の `@[obligation]` |
| `.covered devs M [thm, …]` | 被覆。必要な差異の述語 `M` が、この差異を覆う | `Machine.Preserves.Covers M d`・`Covers₂ M d` の定理（`d` は `deviations` のどれか） | 定理の `@[obligation]` |
| `.pending devs 理由 (some W)` | 未証明。前提で制限して R 課題を証明したが、必要性（偽）も一致（真）もまだ示していない | なし | 予定の `W` |
| `.unformalized claim 作業`（未確定）・`.outOfModel { claim, … }` | 形式化していない。Lean の命題として書けない（モデル外、または未確定で命題をまだ書けない） | `opaque claim : Prop`（docstring に主張を書く） | — |
| `.outsidePre { pre := [pre, …], … }` | 差異ではない。`Spec` の PRE・INV の外である | 前提の述語（`Spec` の箇所の印を兼ねる） | — |

- 制限（`restrict`）は仮定を強めるだけなので、差異が実在してもしなくても、`pending` の R 課題は公理なしに証明できる。
- `opaque c : Prop` は公理を足さず（axiom-check を通る）、定義が見えないので、Lean の中で真とも偽とも証明できない。どの定数からも参照してはならない（仮定として推論に持ち込まない）。
- 状態は確定に向けて移す。
  - `pending` は、必要性の定理ができたら `refuted` に移す。一致が証明できたら、差異を取り消す。
  - `unformalized`（未確定）は、モデルができたら命題に書き直して `pending` か `refuted` に移す。
- 前提型・観測型で Lean に述語がまだ無いものは、`.pending [] ne!"Lean に述語がまだ無い" (some oid!"W")` にする。

```lean
/-- D-013 の主張: [Source] は照合と更新を別のトランザクションで行うので、並行実行の下では [Spec] と観測が異なりうる -/
@[gap "D-013"] opaque claim_D013 : Prop

/-- …（説明） -/
@[gap_entry]
def D013 : Trace.Gap where
  id := gid!"D-013"
  sites := ne![⟨ne!"トランザクション", ne!"lean/Spec/Port.lean#トランザクション", "（規範節）"⟩]
  body := .outOfModel {
    reason := ne!"— モデル外（並行実行はモデルに現れない）"
    claim := ``claim_D013 }
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
