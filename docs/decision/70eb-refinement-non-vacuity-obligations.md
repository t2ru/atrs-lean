---
type: Architecture Decision Record
title: "リファインメントが空虚・自明に成り立つことを防ぐ義務と検査を課す"
description: "Machine.Refines は具体⊆抽象しか保証せず、緩い Spec・空の INV・強すぎる PRE・粗い貼り合わせ・名前付きの成分の乱用・非決定性による不具合の吸収でも成り立つ。これを、選択の像としての Spec（ofChoice・FreeFrame）、Sound と 1 点の初期状態、環境の固定（Pinned・NoFaultReachable）、標準の貼り合わせ（Glue.ofStd）、入口の全域性（TotalUnder・EnvWitness）、初期化の全射性、状態の安全性、成分の両向きの例、核の明示と、検査 TR-G・TR-N・TR-V・TR-PE で塞ぐ。ADR 01d4・e2a4・e56e に義務と検査を加える。"
tags: [adr, model, abstraction, refinement, proof, traceability]
id: "70ebaf6b-ec24-4790-bdc2-543d6734dda0"
status: stable
decision_status: accepted
date: 2026-10-30
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:40:00+09:00
sources:
  - id: abrial-bbook
    resource: https://doi.org/10.1017/CBO9780511624162
    title: "J.-R. Abrial, The B-Book: Assigning Programs to Meanings (1996)"
---

# リファインメントが空虚・自明に成り立つことを防ぐ義務と検査を課す

## Context and Problem Statement

[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) は、`SourceModel`・`TargetModel` が `Spec` を B メソッドの意味でリファインすることを、`Machine.Refines` の 4 つの証明義務で示すと決めた。
しかし、リファインメントが保証するのは **安全性**、つまり「具体側の振る舞いが、抽象側の許す範囲に収まる」ことだけである。抽象側が具体側を十分に表していること（完全性）は保証しない。
B メソッドでも同じで、仕様の妥当性は証明の外で確かめる（アニメーション・モデル検査）。

既存の `Machine.Refines` は、次の場合にも空虚に、または自明に成り立つ。各場合の反例は、`MachineTest/Adequacy.lean` の Lean の証明か、`lean/Tests/ObligationFixture.lean` の検査器の違反例として示してある。

| 抜け道 | 例 |
| --- | --- |
| 抽象側の INV が空 | `Inv := False` なら、適用可能性と正しさは INV を仮定するので空虚に成り立つ |
| 抽象側の `step` が緩い | `step := True` なら、どの具体機械もリファインメントになる。ベクタは `run` から作るので、ベクタも通る |
| PRE が強すぎる | `Pre := False` なら、適用可能性と正しさが空虚に成り立つ |
| `αᵢ` が PRE の外へ写す | 全入力を PRE の外の 1 点へ写せば、入力の全域性を満たしたまま、他の義務が空虚になる |
| `J`・`αₒ` が粗い | `αₒ := True` なら出力は何でもよい。全域の抽象化が NaN を 0 に写すと、NaN を返す具体側が通る |
| 名前付きの成分の乱用 | `False` の差異の前提、`True` の観測の成分も「名前付き」であり、TR-D は通る |
| 環境の非決定性が不具合を吸収する | `Conflict`・I/O 失敗（[ADR e56e](e56e-conflict-as-spec-nondeterminism.md)）は `Spec` が許す結果である。そのため、移植元の不具合による 500（例: D-018 の VARCHAR 超過）がこれで模倣され、差異を登録しなくても証明が通る |
| 初期状態の偏り | 抽象側の初期状態を広く取ると、具体側が満席の状態からしか始まらなくても、成功の経路を一度も通らずに成り立つ |
| 自由な非決定性による吸収 | 実装が選んでよい値（ハッシュ値など）の型を結果全体にすれば、どの具体機械も模倣される |
| 前提の外の 1 歩 | 差異の前提を破る入力の後では `J` が保証されず、その後の軌跡は無保証になる |

[ADR c336](c336-foundational-principles.md) の原則 1 は、手段の届かない部分を [spec/assurance.md](../spec/assurance.md) にすべて列挙することを求める。しかし、上の限界は載っていなかった。

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

### 義務（Lean: スキル spec-pivot の `assets/lean/Machine/Adequacy.lean`）

| 対象 | 義務 | Lean | 塞ぐ抜け道 |
| --- | --- | --- | --- |
| 抽象機械の形 | `Spec` の基底の機械を、選択の像として作る（`step s i s' o ↔ ∃ c, f s i c = (s', o)`、`run s i = f s i (e₀, f₀)`）。選択の型は、環境の選択 E（衝突・I/O 失敗・配備の設定）と自由な選択 F（ハッシュ値など）の組とする。葉の型に `@[nondet "N-NNN"]` を付け、登録簿に種類（環境・自由）とともに載せる。決定的な純粋計算は `Machine.pure` でよい | `Machine.ofChoice` | 緩い `step` |
| 自由な選択の枠 | 自由な選択が変えうる部分を、射影 `m` の核（`KernelIs`）として示す（`∀ s i e x y, m (f s i (e,x)) = m (f s i (e,y))`） | `Machine.FreeFrame` | 自由な非決定性による吸収 |
| 不変条件と初期化 | 基底の機械が `Sound` で、初期状態が fixture の 1 点である。あわせて INV が空でないことを保証する | `Machine.Sound`・`Machine.InitIs` | 空の INV |
| 環境の固定 | 具体側も、環境とマスタ・設定を入力の成分として受ける。具体側の正常終了は、E を具体側の入力の環境 `ce i_c` に固定した `f` の結果のどれかで模倣される。`ce` は `@[std_abs]` の標準の抽象化である。`correct` を含意する | `Refines.Pinned` | 環境の非決定性による不具合の吸収 |
| 障害の無い環境での実現 | 抽象側の各入力は、`ce` が標準の環境 `e₀` を返す具体側の入力でも実現される | `Refines.NoFaultReachable` | `ce` が障害でない入力を障害の環境に写すこと |
| 貼り合わせの形 | `J s t := (β t = some s ∧ Ic t) ∨ OJ s t`、`αᵢ c a := aᵢ c = some a`、`αₒ c a := aₒ c = some a ∨ OO c a`。β・aᵢ・aₒ は標準の抽象化の **部分写像**（`none` は α/β の未定義）で、`@[std_abs]` の定数そのものを渡す。OJ・OO は観測型の差異の成分（`@[deviation]` の定数そのもの）で、既定は `Machine.Adequacy.never`。補助定義で包まない（`@[reducible]` の定義は展開して判定する） | `Glue.ofStd` | 粗い `J`・`αₒ`、α の部分性の消失 |
| 標準の抽象化 | 1 引数の関数とする（関数・インスタンスを引数に取らない）。葉（α・β の表の行）は、核（同一視するもの）を定理で示し、表に書く。核は等号か、`@[kernel]` を付けた名前付きの関係とする。合成は、葉・構成子・射影・インスタンス・`Option.map/bind`・`List.map/mapM`・`Prod.map`・`Function.comp`・`id` だけで作り、分岐を含めない。aₒ と `FreeFrame` の射影には、合成であっても核の定理を課す | `KernelIs`、`@[std_abs]`、`@[kernel]` | 標準の抽象化に隠れた同一視・分岐 |
| 入口の全域性 | 入口の機械では、INV と環境の前提の下で PRE が成り立つ。環境の前提は、マスタ・設定の妥当性（MD-1〜MD-8）と入力の値域を入力の成分だけで書いた、`@[env_pre]` の定数である。R 課題には、環境の前提を満たす像を持つ具体側の入力があることも課す | `Machine.TotalUnder`・`Refines.EnvWitness`、`@[env_pre]` | 強すぎる PRE、PRE・環境の前提の外への写し |
| 初期化 | `Spec` の初期状態（1 点）に、対応する具体側の初期状態がある | `Refines.InitSurj` | 初期状態の偏り |
| 名前付きの成分 | 差異の述語・成分と環境の前提は、成り立つ例と成り立たない例を持つ。`restrict` などには定数そのものを渡す（引数を与えて `False` にできないように） | `Nontrivial`・`Nontrivial₂` | `True`・`False` の成分 |
| 同語反復の禁止 | 具体機械は、`Concrete.ofMachine`（旧 `toConcrete`）と `Spec` の関数（型・構成子・射影・インスタンス以外）を参照しない | — | 抽象機械をそのまま具体機械にすること |
| 前提の外の 1 歩 | 前提型の差異を「出力のみ」と「中断」に分けて登録する。出力のみの差異では、前提を破る 1 歩の後も、状態は `J` を保つ | `Refines.StateSafe`・`StateSafeConcrete` | 前提の外の 1 歩による状態の破壊 |

* 入口の機械は、画面・REST（`Spec.Http`）とレポート要求の受信である。
* 上の義務から次の 2 つが導かれる。どちらも `Machine` の定理である。
  * `Refines.complete`（1 歩の可換式）: PRE の下で、具体側は必ず正常終了し、その像は環境を固定した `f` の結果と一致する。障害の無い環境では、自由な選択を除いて標準の選択 `run` と一致する。[ADR a43d](a43d-two-layer-model-java-faithful-and-abstract.md) の可換式に、名前付きの例外を付けた形である。
  * `Refines.run`（入口の機械の複数歩の模倣）: 差異の前提を保つ具体側の軌跡は、PRE を満たす抽象側の軌跡で模倣される。
* `Refines.congr` で、各点で同値な貼り合わせに付け替えられる。ただし、`Refines.trans` で合成した貼り合わせは `Glue.ofStd` の形にならないため、R 課題は合成で作れない。主定理は、具体機械と `Spec` の間で直接に述べる。

### 課題と登録簿（[spec/abstraction.md](../spec/abstraction.md)・[spec/refinement.md](../spec/refinement.md)）

* `Spec` 自身の課題を加える。
  * SPEC-005: 基底の機械が `ofChoice` か `pure` である。選択の型は登録簿の種類どおりに使い、自由な選択には `FreeFrame` を示す
  * SPEC-006: 入口の機械が、`@[env_pre]` の環境の前提の下で `TotalUnder` を満たす
  * SPEC-007: 初期状態が fixture の 1 点である（`InitIs`）
  * SPEC-008: 標準の環境の下で、`f` は環境の非決定性に固有の結果（`Conflict`・I/O 失敗）を返さない
* R 課題には、`Refines` に加えて次を課す。ID は増やさない。
  * `InitSurj`、基底の `Sound`・`InitIs`
  * 基底が `ofChoice` なら `Pinned` と `NoFaultReachable`
  * 入口の R 課題なら `TotalUnder` と `EnvWitness`
  * 「出力のみ」の差異ごとの `StateSafe`（同じ基底の機械と貼り合わせについて）
* W 課題を両向きにする。
  * 前提型: 前提を満たす例と、破って一致しない例
  * 観測型: 成分が関係づける例と、関係づけない例
* 登録簿を 3 つ加える。各行には、Lean 側を整える backlog 項目を書く（段階導入に使う）。
  * 「Spec の非決定性（N-NNN）」（種類: 環境・自由）
  * 「入口の R 課題」
  * 「前提型の差異の影響」
* α・β の表に「同一視するもの（核）」の列を加える。
* 主定理は閉じた命題とする（∀ の仮定を持たない）。前提型の差異は `restrict`・`restrictState`・`Concrete.restrict` で機械の中に置く。[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) の「仮定は PRE・INV・`@[deviation]` だけ」は、この形で満たす。
  * 具体側の状態の述語（例: D-009）は、`J` で対応する抽象側の状態の述語に書き直して `restrictState` で置く。
  * 具体側の不変条件 `Ic` は仮定ではない。`InitSurj` で初期状態について成り立ち、正しさの義務で `J` とともに保たれることを示すので、到達可能な状態についての証明済みの不変条件である。

### 環境とマスタ・設定（[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)・[e56e](e56e-conflict-as-spec-nondeterminism.md) を補う）

* 具体側（`SourceModel`・`TargetModel`）の各操作は、マスタ・設定と環境を **入力の成分** として受ける。
  * 環境とは、衝突が起きるか、どのポート操作が I/O で失敗するか、配備の設定（再配信の上限など）である。
  * マスタは不変なので、移植元が DB から読む場合も、具体機械の状態に含めず入力とする。
  * `aᵢ` は環境を落とし、`ce` は環境を `Spec` の環境の選択へ写す。
* 環境が障害を示さないとき、具体側は `Conflict`・I/O 失敗の結果を返してはならない（`Pinned`）。
  * これにより、移植元の不具合による 500 が環境の非決定性に紛れなくなる。前提型の差異として登録しなければ、証明が通らない。
* [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) のとおり、入力の値域とマスタの値域は PRE に含める。入口の機械では、それらを環境の前提（`@[env_pre]`）として名前を付け、その下で PRE が成り立つことを示す。値域の外の入力での具体側の振る舞いは、ADR 01d4 のとおり差異ではなく、保証の限界である。
* [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md) は「`J`・`αᵢ`・`αₒ` は関係」とする。`Glue.ofStd` で作る `J`・`αᵢ`・`αₒ` も関係である。ただし、標準の部分は部分写像のグラフに限り、関係でしか書けない部分（例: SQL の許される順列、D-022 の多重集合）は観測型の差異の成分か、具体側の非決定性として表す。

### 検査

| 検査 | 内容 | 実装 |
| --- | --- | --- |
| TR-G | 属性の置き場所（G0）、R 課題の形（G1〜G5）と付帯の定理（G6）、`Spec` の機械の形（G3'）、`@[std_abs]` の葉・合成（G7）、`@[deviation]`・`@[env_pre]` の `Nontrivial`（G8） | `lake exe obligation-check`（`lean/Trace/Obligation.lean`） |
| TR-G（文書側）・TR-N | `@[nondet]` と N-NNN の 1 対 1 と種類、種類 R の課題の形、入口の R 課題の `TotalUnder`・`EnvWitness`、出力のみの差異の `StateSafe`、前提型の差異の影響の登録、`@[deviation]` の登録 | `tools/ci/check_obligations.py` |
| TR-V | ベクタのうち差異の前提の外に落ちるものに、差異 ID のラベル `outsidePre` がある（ラベルと外に落ちることが一致する） | ベクタの実行器（[backlog a8ef](../backlog/a8ef-conformance-vector-format-and-generator.md)） |
| TR-PE | 公開操作が、入口の R 課題の具体機械に含まれる（[ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) の TR-P に加えて検査する） | `tools/trace check`（[backlog ffdc](../backlog/ffdc-trace-tooling.md)） |

* TR-G・TR-N の段階導入は、本 ADR で定める。登録簿の各行の backlog 項目が `done` でない間は、「文書にあって Lean にまだ無い」ことを警告にし、`done` なら失敗にする。これは [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md) の検査（TR-S1〜TR-R）の段階導入を変えない。
* 本 ADR は、[ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md)・[ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md)・[ADR e56e](e56e-conflict-as-spec-nondeterminism.md) の決定を変えず、義務と検査を加える。

### 保証の限界として残すもの（[spec/assurance.md](../spec/assurance.md)）

* 仕様の妥当性: `Spec` の標準の選択 `run` が業務の意図どおりであること。ベクタと仕様文書の例でだけ確かめる。
* 名前付きの成分の広さ: 次の 3 つを越える部分は、人の判断である。対象は、差異の述語・観測の成分・非決定性の選択の型と `FreeFrame` の核・環境の前提・標準の抽象化の核（`@[kernel]` と表の一致）・「出力のみ／中断」の分類である。
  * 形の制限
  * 両向きの例
  * TR-V
* 活性: 環境が常に障害を示す配備では、具体側は常に失敗しうる。
* 「中断」の差異の前提を破った後の軌跡。
* 入口でない R 課題の PRE: 入口の R 課題の証明で使われる範囲でだけ意味を持つ。
* 環境・マスタを入力とする具体側のモデル: 移植元の原典実行は、障害・衝突を注入できず、マスタを DB から読む。この部分の一致は、原典実行の届く範囲（障害の無い環境、fixture のマスタ）に限られる。
* SPEC-008（標準の環境で環境に固有の結果を返さない）: 機能ごとの定理で示すが、その形は検査器では確かめない。

### Consequences

* Good, because 上の抜け道のうち機械で塞げるものが、Lean の型と CI の検査で塞がれる（反例を `MachineTest/Adequacy.lean` で証明済み）
* Good, because リファインメントに、ADR a43d の可換式（`Refines.complete`）と複数歩の模倣（`Refines.run`）が加わり、「名前付きの例外を除いて一致する」と言えるようになる
* Good, because 環境の非決定性が、移植元の不具合を隠さなくなる
* Bad, because 具体側のモデルに、環境の成分と、入力としてのマスタ・設定を持たせる必要がある
* Bad, because R 課題ごとに付帯の定理（`InitSurj`・`Sound`・`InitIs`・`Pinned`・`NoFaultReachable`・`TotalUnder`・`EnvWitness`・`StateSafe`）が増える
* Bad, because 標準の抽象化を部分写像として書き、葉ごとに核の定理を示す必要がある

### Confirmation

* `MachineTest/Adequacy.lean` で、抜け道ごとに「`Refines` は成り立つが、新しい義務は成り立たない」ことを証明する。あわせて、すべての義務を満たす正例を示す。
* `lean/Tests/ObligationFixture.lean` の正例と違反例（実装後のレビューで作られた迂回を含む）で、`obligation-check` が G0〜G8 を検出することを `lake test` で確かめる。
* `check_obligations.py --self-test` で、文書側の規則（失敗と警告）を確かめる。
* `tools/ci/lean.sh` で、`obligation-check` と `check_obligations.py` を毎回実行する。

## Pros and Cons of the Options

### 付帯の義務と検査（採用）

* Good, because 抜け道ごとに、塞ぐ義務と反例が対応する
* Bad, because 定理と検査の量が増える

### 双方向のシミュレーション（双模倣）

* Good, because 「抽象側のすべての振る舞いが具体側で実現される」と言える
* Bad, because `Spec` の非決定性（`Conflict`・ハッシュ値・上限の選択）を具体側で減らすことを禁じてしまい、[ADR e56e](e56e-conflict-as-spec-nondeterminism.md) と両立しない。採用案の `Pinned` と `complete` は、環境の選択に限って逆向きを保証する

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
* 採番（`IdGenerator`）の値は非決定性として登録しない。[Spec] の状態 `World.sequences` が次の値を決め、適合テストは番号を厳密に比較する（[`Spec.Port`](../../lean/Spec/World.lean#idgenerator)）。草案では自由な選択（N-006）としたが、実装後のレビューで ports.md・conformance.md と矛盾すると分かったので取り消した。
* [ADR c336](c336-foundational-principles.md), [ADR 01d4](01d4-b-method-refinement-and-explicit-deviations.md), [ADR e2a4](e2a4-traceability-hash-as-deterministic-check-record.md), [ADR e56e](e56e-conflict-as-spec-nondeterminism.md), [backlog f7b7](../backlog/f7b7-refinement-non-vacuity.md)
* 補足: [ADR 9ac6](9ac6-vacuity-literature-necessity-and-mutation.md) で、本 ADR の義務を既存の研究（Event-B の証明義務、vacuity detection、仕様の変異テストなど）と対応づけた。あわせて、成分の必要性（G9）を義務に加え、成分の広さには変異テストを、仕様の妥当性には意図から書く例を採った。本 ADR の決定は変えていない。

### 実装後の敵対的レビュー

実装の後、独立したエージェント 2 体（形式面と検査器、文書と規則）による敵対的レビューを行った。形式面のレビューでは、当時の義務と検査をすべて満たしたまま空虚・自明になる例を、10 件、実際に作って検査器に通した。指摘と対応は次のとおりである。作られた例は、`MachineTest/Adequacy.lean`（反例 7〜11）と `lean/Tests/ObligationFixture.lean`（違反例）に加え、検出されることを確かめた。

| 指摘 | 対応 |
| --- | --- |
| `Inv := False` で全義務が空虚になる | `Sound`・`InitIs` を付帯の義務にした（G6） |
| 自由な選択の型を結果全体にすれば何でも吸収できる。環境の型を自由な選択の位置に置けば `Pinned` を逃れる | `FreeFrame` を課し、環境・自由の別を登録簿の種類と照合する（G3・OB-N3） |
| `ce` が障害でない入力を障害の環境に写せる | `ce` を `@[std_abs]` に限り、`NoFaultReachable` を課した（G6） |
| `TotalUnder` の環境の前提が任意（`False` でもよい） | 環境の前提を `@[env_pre]` の定数に限り、`Nontrivial` と `EnvWitness` を課した（G6・G8・OB-E1） |
| 走査の対象の名前空間の外に属性を付ければ、検査を逃れる | 属性を付けた定数はモデルの層に限り（G0）、R 課題と付帯の定理は名前空間に関係なく走査する |
| 頭部の定数だけで照合するので、引数で `False` にできる | 差異の述語・標準の抽象化などには定数そのものを要求し、付帯の定理は `@[reducible]` を展開した式全体で照合する |
| `KernelIs` の K が自明でもよい。関数を引数に取る合成で分岐を隠せる | K を等号か `@[kernel]` の定数に限り、標準の抽象化を 1 引数の関数に限り、aₒ には核を課した（G7） |
| `Refines ∧ True` や `abbrev` で R 課題の検査を逃れる | 結論の `@[reducible]` を展開して判定し、`Refines` を含むのに結論が `Refines` でないものを失敗にした（G0）。文書で種類 R の課題が `Refines` でなければ失敗にした（OB-R） |
| 抽象機械を `Concrete.ofMachine`（旧 `toConcrete`）でそのまま具体機械にできる | 具体機械の参照の閉包に `Concrete.ofMachine`（旧 `toConcrete`）と `Spec` の関数があれば失敗にした（G4） |
| `StateSafe` を別の機械について示しても通る。文書の種類を書き換えれば逃れる | 同じ基底の機械と貼り合わせで照合し、`restrict` に使う差異が前提型で影響の行を持つことを確かめる（OB-S1・OB-D2） |
| 「出力のみ／中断」の分類・核と表の一致・N の広さは人の判断である | 保証の限界に載せた |
| 入口の PRE から値域を除くことが ADR 01d4 と矛盾する | 値域は PRE に残し、環境の前提として名前を付ける形に改めた |
| TR-P の改訂と段階導入の拡張が ADR e2a4 と矛盾する | TR-P は変えず、TR-PE を加えた。段階導入は本 ADR の検査についてだけ定めた |
| N-006 が ports.md・conformance.md と矛盾する | 取り消した |
| `Glue.ofStd` を `abbrev` で包むと付帯の定理の照合が外れる（誤検出） | 照合の前に `@[reducible]` を展開する |
| 合成の標準の抽象化で、`List.mapM` やインスタンスが使えない（誤検出） | 許可した。`match` は許可しない（射影で書く） |

直さなかった指摘は次のとおりである。

* 観測の成分 OO を関数的、または有界の像に限ること: 両向きの例と登録簿の記述で足りるとし、広さは限界とした。
* 合成の標準の抽象化で `match` を許すこと: 射影で書けるので許可しない。
* 機能ごとの段階導入の対応づけを、登録簿の行に backlog の列を置く形で行った。登録簿に無い検査（TR-D など）の段階導入は、ADR e2a4 と [backlog ffdc](../backlog/ffdc-trace-tooling.md) による。
