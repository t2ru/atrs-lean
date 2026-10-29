---
type: Architecture Decision Record
title: "リファインメントが空虚・自明に成り立つことを防ぐ義務と検査を課す"
description: "Machine.Refines は具体⊆抽象しか保証せず、緩い Spec・強すぎる PRE・粗い貼り合わせ・名前付きの成分の乱用・環境の非決定性による不具合の吸収でも成り立つ。これを、選択の像としての Spec（ofChoice）、環境の固定（Pinned）、標準の貼り合わせ（Glue.ofStd）、入口の全域性（TotalUnder）、初期化の全射性、状態の安全性、成分の両向きの例、核の明示と、検査 TR-G・TR-N・TR-V で塞ぐ。ADR 0034・0037 を補う。"
tags: [adr, model, abstraction, refinement, proof, traceability]
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T08:40:00+09:00
sources:
  - id: abrial-bbook
    resource: https://doi.org/10.1017/CBO9780511624162
    title: "J.-R. Abrial, The B-Book: Assigning Programs to Meanings (1996)"
---

# リファインメントが空虚・自明に成り立つことを防ぐ義務と検査を課す

## Context and Problem Statement

[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md) は、`SourceModel`・`TargetModel` が `Spec` を B メソッドの意味でリファインすることを、`Machine.Refines` の 4 つの証明義務で示すと決めた。
しかし、リファインメントが保証するのは **安全性**、つまり「具体側の振る舞いが、抽象側の許す範囲に収まる」ことだけである。抽象側が具体側を十分に表していること（完全性）は保証しない。
B メソッドでも同じで、仕様の妥当性は証明の外で確かめる（アニメーション・モデル検査）。

既存の `Machine.Refines` は、次の場合にも空虚に、または自明に成り立つ。各場合の反例は `MachineTest/Adequacy.lean` に証明してある。

| 抜け道 | 例 |
| --- | --- |
| 抽象側の `step` が緩い | `step := True` なら、どの具体機械もリファインメントになる。ベクタは `run` から作るので、ベクタも通る |
| PRE が強すぎる | `Pre := False` なら、適用可能性と正しさが空虚に成り立つ |
| `αᵢ` が PRE の外へ写す | 全入力を PRE の外の 1 点へ写せば、入力の全域性を満たしたまま、他の義務が空虚になる |
| `J`・`αₒ` が粗い | `αₒ := True` なら出力は何でもよい。全域の抽象化が NaN を 0 に写すと、NaN を返す具体側が通る |
| 名前付きの成分の乱用 | `False` の差異の前提、`True` の観測の成分も「名前付き」であり、TR-D は通る |
| 環境の非決定性が不具合を吸収する | `Conflict`・I/O 失敗（[ADR 0037](0037-conflict-as-spec-nondeterminism.md)）は `Spec` が許す結果である。そのため、移植元の不具合による 500（例: D-018 の VARCHAR 超過）がこれで模倣され、差異を登録しなくても証明が通る |
| 初期状態の偏り | 抽象側の初期状態を広く取ると、具体側が満席の状態からしか始まらなくても、成功の経路を一度も通らずに成り立つ |
| 前提の外の 1 歩 | 差異の前提を破る入力の後では `J` が保証されず、その後の軌跡は無保証になる |

[ADR 0033](0033-foundational-principles.md) の原則 1 は、手段の届かない部分を [spec/assurance.md](../spec/assurance.md) にすべて列挙することを求める。しかし、上の限界は載っていなかった。

## Decision Drivers

* リファインメントの証明が、業務の振る舞いについて実際に何かを述べていること（原則 2 の実質）
* 差異・非決定性を名前で明示するだけでなく、その名前が抜け道にならないこと（原則 3）
* 業務モデルを書き始める前に、義務の形を決めること（後から足すと、すべての R 課題を書き直すことになる）
* 決定論的に検査できること。人のレビューに頼らないこと（原則 1）

## Considered Options

* 選択の像としての `Spec`・環境の固定・標準の貼り合わせ・入口の全域性などの付帯の義務と、検査 TR-G・TR-N・TR-V を課す
* 双方向のシミュレーション（双模倣）を義務にする
* 適合テストベクタの交差照合（`source-model/` の入力を `Spec` で実行して比べる）だけを足す
* 何もせず、限界として [spec/assurance.md](../spec/assurance.md) に載せるだけにする

## Decision Outcome

Chosen option: "選択の像としての `Spec`・環境の固定・標準の貼り合わせ・入口の全域性などの付帯の義務と、検査 TR-G・TR-N・TR-V を課す", because 上の抜け道のうち、機械的に塞げるものをすべて Lean の義務と CI の検査で塞げるため。あわせて、塞げない部分（仕様の妥当性・成分の広さ・活性）を限界として明示できる。

### 義務（Lean: スキル port-lang の `assets/Machine/Adequacy.lean`）

| 対象 | 義務 | Lean | 塞ぐ抜け道 |
| --- | --- | --- | --- |
| 抽象機械の形 | `Spec` の基底の機械を、選択の像として作る（`step s i s' o ↔ ∃ c, f s i c = (s', o)`、`run s i = f s i (e₀, f₀)`）。選択の型は、環境の選択 E（衝突・I/O 失敗・配備の設定）と自由な選択 F（ハッシュ値など）の組とする。葉の型に `@[nondet "N-NNN"]` を付け、登録簿に載せる。決定的な純粋計算は `Machine.pure` でよい | `Machine.ofChoice` | 緩い `step` |
| 環境の固定 | 具体側も、環境とマスタ・設定を入力の成分として受ける。具体側の正常終了は、E を具体側の入力の環境 `ce i_c` に固定した `f` の結果のどれかで模倣される。`correct` を含意する | `Refines.Pinned` | 環境の非決定性による不具合の吸収 |
| 貼り合わせの形 | `J s t := (β t = some s ∧ Ic t) ∨ OJ s t`、`αᵢ c a := aᵢ c = some a`、`αₒ c a := aₒ c = some a ∨ OO c a`。β・aᵢ・aₒ は標準の抽象化の **部分写像**（`none` は α/β の未定義）、OJ・OO は観測型の差異の成分で、既定は `Machine.never`。定理の型にそのまま書き、補助定義で包まない | `Glue.ofStd` | 粗い `J`・`αₒ`、α の部分性の消失 |
| 標準の抽象化 | 葉（α・β の表の行）は、核（同一視するもの）を定理で示し、表に書く。合成は、葉・構成子・射影・`Option.map/bind`・`List.map`・`Prod.map`・`Function.comp`・`id` だけで作り、分岐を含めない | `KernelIs`、`@[std_abs]` | 標準の抽象化に隠れた同一視・分岐 |
| 入口の全域性 | 入口の機械では、INV と環境の前提の下で PRE が成り立つ。環境の前提は、マスタ・設定の妥当性を入力の射影だけで書いたものである | `Machine.TotalUnder` | 強すぎる PRE、PRE の外への写し |
| 初期化 | `Spec` の初期状態を fixture の 1 点とし、それに対応する具体側の初期状態がある | `Refines.InitSurj` | 初期状態の偏り |
| 名前付きの成分 | 差異の述語・成分は、成り立つ例と成り立たない例を持つ | `Nontrivial`・`Nontrivial₂` | `True`・`False` の成分 |
| 前提の外の 1 歩 | 前提型の差異を「出力のみ」と「中断」に分けて登録する。出力のみの差異では、前提を破る 1 歩の後も、状態は `J` を保つ | `Refines.StateSafe`・`StateSafeConcrete` | 前提の外の 1 歩による状態の破壊 |

* 入口の機械は、画面・REST（`Spec.Http`）とレポート要求の受信である。
* 上の義務から次の 2 つが導かれる。どちらも `Machine` の定理である。
  * `Refines.complete`（1 歩の可換式）: PRE の下で、具体側は必ず正常終了し、その像は環境を固定した `f` の結果と一致する。障害の無い環境では、自由な選択を除いて標準の選択 `run` と一致する。[ADR 0004](0004-two-layer-model-java-faithful-and-abstract.md) の可換式に、名前付きの例外を付けた形である。
  * `Refines.run`（入口の機械の複数歩の模倣）: 差異の前提を保つ具体側の軌跡は、PRE を満たす抽象側の軌跡で模倣される。
* `Refines.congr` で、各点で同値な貼り合わせに付け替えられる。ただし、`Refines.trans` で合成した貼り合わせは `Glue.ofStd` の形にならないため、R 課題は合成で作れない。主定理は、具体機械と `Spec` の間で直接に述べる。

### 課題と登録簿（[spec/abstraction.md](../spec/abstraction.md)・[spec/refinement.md](../spec/refinement.md)）

* `Spec` 自身の課題を加える。
  * SPEC-005: 基底の機械が `ofChoice` か `pure` である
  * SPEC-006: 入口の機械が `TotalUnder` を満たす
  * SPEC-007: 初期状態が fixture の 1 点である
* R 課題には、`Refines` に加えて次を課す。ID は増やさない。
  * `InitSurj`
  * 基底が `ofChoice` なら `Pinned`
  * 「出力のみ」の差異ごとの `StateSafe`
* W 課題を両向きにする。
  * 前提型: 前提を満たす例と、破って一致しない例
  * 観測型: 成分が関係づける例と、関係づけない例
* 登録簿を 3 つ加える。
  * 「Spec の非決定性（N-NNN）」
  * 「入口の R 課題」
  * 「前提型の差異の影響」
* α・β の表に「同一視するもの（核）」の列を加える。
* 主定理は閉じた命題とする（∀ の仮定を持たない）。前提型の差異は `restrict`・`restrictState`・`Concrete.restrict` で機械の中に置く。[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md) の「仮定は PRE・INV・`@[deviation]` だけ」は、この形で満たす。

### 環境とマスタ・設定（[ADR 0034](0034-b-method-refinement-and-explicit-deviations.md)・[0037](0037-conflict-as-spec-nondeterminism.md) を補う）

* 具体側（`SourceModel`・`TargetModel`）の各操作は、マスタ・設定と環境を **入力の成分** として受ける。
  * 環境とは、衝突が起きるか、どのポート操作が I/O で失敗するか、配備の設定（再配信の上限など）である。
  * マスタは不変なので、移植元が DB から読む場合も、具体機械の状態に含めず入力とする。
  * `aᵢ` は環境を落とし、`ce` は環境を `Spec` の環境の選択へ写す。
* 環境が障害を示さないとき、具体側は `Conflict`・I/O 失敗の結果を返してはならない（`Pinned`）。
  * これにより、移植元の不具合による 500 が環境の非決定性に紛れなくなる。前提型の差異として登録しなければ、証明が通らない。
* 入口の機械の PRE には入力の値域を含めない。値域の外の入力には、入口の `Spec` が入力検証の結果を定める（[domain-model.md](../spec/domain-model.md#値域)）。入口でない機械の PRE は、値域を含んでよい。
* [ADR 0034](0034-b-method-refinement-and-explicit-deviations.md) は「`J`・`αᵢ`・`αₒ` は関係」とする。`Glue.ofStd` で作る `J`・`αᵢ`・`αₒ` も関係である。ただし、標準の部分は部分写像のグラフに限り、関係でしか書けない部分（例: SQL の許される順列、D-022 の多重集合）は観測型の差異の成分か、具体側の非決定性として表す。

### 検査

| 検査 | 内容 | 実装 |
| --- | --- | --- |
| TR-G | R 課題の形（G1〜G5）と付帯の定理（G6）、`@[std_abs]` の葉・合成（G7）、`@[deviation]` の `Nontrivial`（G8） | `lake exe obligation-check`（`lean/Trace/Obligation.lean`） |
| TR-G（文書側）・TR-N | `@[nondet]` と N-NNN の 1 対 1、入口の R 課題の `TotalUnder`、出力のみの差異の `StateSafe`、前提型の差異の影響の登録 | `tools/ci/check_obligations.py` |
| TR-V | ベクタのうち差異の前提の外に落ちるものに、差異 ID のラベル `outsidePre` がある（ラベルと外に落ちることが一致する） | ベクタの実行器（[backlog 0012](../backlog/0012-conformance-vector-format-and-generator.md)） |
| TR-P（改訂） | 公開操作の網羅を、入口の R 課題の具体機械だけで数える | `tools/trace check`（[backlog 0024](../backlog/0024-trace-tooling.md)） |

* 文書にあって Lean にまだ無いものは、段階導入として警告にする（スキル port-lang の [traceability.md](../../.agents/skills/port-lang/references/traceability.md)）。

### 保証の限界として残すもの（[spec/assurance.md](../spec/assurance.md)）

* 仕様の妥当性: `Spec` の標準の選択 `run` が業務の意図どおりであること。ベクタと仕様文書の例でだけ確かめる。
* 名前付きの成分の広さ: 次の 3 つを越える部分は、人の判断である。
  * 形の制限
  * 両向きの例
  * TR-V
* 活性: 環境が常に障害を示す配備では、具体側は常に失敗しうる。
* 「中断」の差異の前提を破った後の軌跡。
* 入口でない R 課題の PRE: 入口の R 課題の証明で使われる範囲でだけ意味を持つ。

### Consequences

* Good, because 上の抜け道のうち機械で塞げるものが、Lean の型と CI の検査で塞がれる（反例を `MachineTest/Adequacy.lean` で証明済み）
* Good, because リファインメントに、ADR 0004 の可換式（`Refines.complete`）と複数歩の模倣（`Refines.run`）が加わり、「名前付きの例外を除いて一致する」と言えるようになる
* Good, because 環境の非決定性が、移植元の不具合を隠さなくなる
* Bad, because 具体側のモデルに、環境の成分と、入力としてのマスタ・設定を持たせる必要がある
* Bad, because R 課題ごとに付帯の定理（`InitSurj`・`Pinned`・`StateSafe`）が増える
* Bad, because 標準の抽象化を部分写像として書き、葉ごとに核の定理を示す必要がある

### Confirmation

* `MachineTest/Adequacy.lean` で、抜け道ごとに「`Refines` は成り立つが、新しい義務は成り立たない」ことを証明する。あわせて、すべての義務を満たす正例を示す。
* `lean/Tests/ObligationFixture.lean` の正例と違反例で、`obligation-check` が G1〜G8 を検出することを `lake test` で確かめる。
* `check_obligations.py --self-test` で、文書側の規則を確かめる。
* `tools/ci/lean.sh` で、`obligation-check` と `check_obligations.py` を毎回実行する。

## Pros and Cons of the Options

### 付帯の義務と検査（採用）

* Good, because 抜け道ごとに、塞ぐ義務と反例が対応する
* Bad, because 定理と検査の量が増える

### 双方向のシミュレーション（双模倣）

* Good, because 「抽象側のすべての振る舞いが具体側で実現される」と言える
* Bad, because `Spec` の非決定性（`Conflict`・ハッシュ値・上限の選択）を具体側で減らすことを禁じてしまい、[ADR 0037](0037-conflict-as-spec-nondeterminism.md) と両立しない。採用案の `Pinned` と `complete` は、環境の選択に限って逆向きを保証する

### ベクタの交差照合だけ

* Good, because 実装が軽い
* Bad, because `run` との一致は見るが `step` の緩さは見ない。差異の前提が広すぎても検出しない。採用案では、前提の網羅を TR-V として残し、交差照合そのものは証明（`complete`）で含意されるので採らない

### 限界に載せるだけ

* Good, because 費用が無い
* Bad, because 機械で塞げる抜け道を人の判断に委ねることになり、原則 1・2 の趣旨に反する

## More Information

* 設計段階で、独立したエージェントによる敵対的レビューを行った。その指摘を受け、草案を次のように改めた。
  * 全域の写像 → 部分写像
  * 一律の `KernelIs` → 葉だけ
  * SPEC-1NN の非決定性の証拠 → 選択の像としての形
  * `Concrete.Inhabited` → `InitSurj`
  * `Pinned`・`StateSafe`・TR-V・TR-P の改訂を追加
* 実装後に行った敵対的レビューの結果は、下の「実装後の敵対的レビュー」に記す。
* 非決定性の登録で、`IdGenerator` の値（N-006）を自由な選択とした理由は次のとおりである。[ports.md](../spec/ports.md#idgenerator) の [Spec] は「呼ぶたびに未使用の値を返す」ことを契約とし、`n`, `n+1`, … を参照の実装とする。契約が値を 1 つに定めないので、`Spec` の非決定性として登録し、参照の実装を標準の選択とする。ベクタは標準の選択で生成する。
* [ADR 0033](0033-foundational-principles.md), [ADR 0034](0034-b-method-refinement-and-explicit-deviations.md), [ADR 0036](0036-traceability-hash-as-deterministic-check-record.md), [ADR 0037](0037-conflict-as-spec-nondeterminism.md), [backlog 0030](../backlog/0030-refinement-non-vacuity.md)

### 実装後の敵対的レビュー

（実施後に記入する）
