---
type: Architecture Decision Record
title: "空虚化を防ぐ義務を既存の研究に照らして補う（成分の必要性・変異テスト・意図から書く例）"
description: "ADR 0039 の義務を、Event-B の証明義務・vacuity detection・IronSpec・mCoq・Dafny の proof dependencies などの研究と対応づける。その上で、名前付きの成分を外すと R 課題の命題が偽になること（成分の必要性。G9）を義務に加える。成分の広さには仕様の変異テストを、仕様の妥当性には意図から書く例を採る。"
tags: [adr, model, abstraction, refinement, proof, traceability]
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T09:40:00+09:00
sources:
  - id: beer2001
    resource: https://doi.org/10.1023/A:1008779610539
    title: "I. Beer, S. Ben-David, C. Eisner, Y. Rodeh, Efficient Detection of Vacuity in Temporal Model Checking, Formal Methods in System Design 18(2), 2001"
  - id: kupferman2003
    resource: https://doi.org/10.1007/s100090100062
    title: "O. Kupferman, M. Y. Vardi, Vacuity detection in temporal model checking, STTT 4(2), 2003"
  - id: ironspec
    resource: https://www.usenix.org/conference/osdi24/presentation/goldweber
    title: "E. Goldweber, W. Yu, S. A. Vakil Ghahani, M. Kapritsos, IronSpec: Increasing the Reliability of Formal Specifications, OSDI 2024"
  - id: mcoq
    resource: https://doi.org/10.1109/ASE.2019.00057
    title: "A. Celik, K. Palmskog, M. Parovic, E. J. Gallego Arias, M. Gligoric, Mutation Analysis for Coq, ASE 2019"
  - id: dafny-deps
    resource: https://dafny.org/blog/2023/10/27/proof-dependencies/
    title: "Dafny blog, Proof dependencies (contradictory and redundant assumptions), 2023"
  - id: abrial2010
    resource: https://doi.org/10.1017/CBO9781139195881
    title: "J.-R. Abrial, Modeling in Event-B: System and Software Engineering (2010)"
  - id: rodin-po
    resource: https://wiki.event-b.org/index.php/Proof_Obligation_Names_(Rodin_User_Manual)
    title: "Rodin User Manual, Proof Obligation Names"
  - id: leroy2009
    resource: https://doi.org/10.1007/s10817-009-9155-4
    title: "X. Leroy, A Formally Verified Compiler Back-end, Journal of Automated Reasoning 43(4), 2009"
  - id: certora-sanity
    resource: https://docs.certora.com/en/latest/docs/solana/sanity.html
    title: "Certora documentation, Rule Sanity Checks (vacuity)"
---

# 空虚化を防ぐ義務を既存の研究に照らして補う（成分の必要性・変異テスト・意図から書く例）

## Context and Problem Statement

[ADR 0039](0039-refinement-non-vacuity-obligations.md) は、リファインメントが空虚・自明に成り立つ抜け道を、付帯の義務と検査 TR-G・TR-N で塞いだ。
ただし、根拠にした文献は B-Book だけである。また、次の 2 つは保証の限界として人の判断に残っている（[spec/assurance.md](../spec/assurance.md#モデル間の保証の限界)）。

* **名前付きの成分の広さ**
  * 差異の述語・観測の成分・環境の前提が、必要以上に広くないこと
  * W 課題の「一致しない例」が実際に差を示していること（定理の文面を人が読んで確かめる）
* **仕様の妥当性**: `Spec` の標準の選択 `run` が業務の意図どおりであること

特に、名前付きの成分が **そもそも要らない** 場合は、どの義務でも検出できない。
`Nontrivial` が示すのは、述語が `True`・`False` でないことだけである。
そのため、外してもリファインメントが成り立つ差異（実際には差の無い差異）を登録しても、検査を通ってしまう。
原則 3（差異の明示）は、差異が実在することまでを求めている（[ADR 0033](0033-foundational-principles.md)）。

## Decision Drivers

* 既存の研究で確立した手法があれば、それに合わせる（独自の手法を増やさない）
* 人の判断に残した部分を、決定論的な検査に移せるなら移す（原則 1）
* 業務モデルを書き始める前に、義務の形を決める（後から足すと、すべての R 課題・W 課題を書き直すことになる）
* 費用が、R 課題ごとの定理の数に比例する範囲に収まる

## 調査

ADR 0039 の義務と、研究で確立した手法の対応は次のとおりである。

| 研究 | 要点 | ADR 0039 の対応 |
| --- | --- | --- |
| Event-B の証明義務[^abrial2010][^rodin-po] | FIS（実行可能性）、GRD（ガードの強化）、INV（不変条件の保存）、INI（初期化）、DLF（相対的デッドロック自由）、WD（well-definedness） | FIS は `Machine.ofChoice`（`f` が関数なので常に実行可能）が満たす。GRD・INV は `applicable`・`correct`・`Sound`、INI は `init`・`InitSurj`、DLF は `TotalUnder`・`Refines.complete` が満たす。WD は Lean の関数が全域なので不要 |
| Morgan の refinement calculus の miracle と abort | 偽の事前条件（miracle）と、何でも許す仕様（abort）は、自明なリファインメントを生む | miracle は `Sound`・`InitIs`・`TotalUnder` が、abort は `ofChoice`・`FreeFrame` が防ぐ |
| CompCert[^leroy2009] | 決定的な側では、前方シミュレーションから後方シミュレーションが従う | `Refines.complete`（障害の無い環境では `run` と一致する） |
| IronSpec の Automatic Sanity Checker[^ironspec] | 事後条件が入力に依存しない仕様、出力を制約しない仕様を検出する | `ofChoice`・`FreeFrame`、aₒ の `KernelIs` |
| Certora の vacuity check[^certora-sanity] | 仮定が矛盾し、規則の末尾に到達できない | `InitIs`・`EnvWitness`、`Nontrivial` の成り立つ例 |
| Dafny の contradictory assumptions[^dafny-deps] | 証明が目標を使わずに済んでいれば、仮定が矛盾している | 同上 |
| **vacuity detection**[^beer2001][^kupferman2003] | 部分式を自明な値に替えても真理値が変わらなければ、その式は空虚に満たされている。空虚でないことは、真理値が変わることを示す例（interesting witness）で示す | **無い**。`Nontrivial` は成分そのものが自明でないことしか示さず、成分を外したときに R 課題の命題が変わることを示さない |
| Dafny の redundant assumptions[^dafny-deps] | どの証明にも使われない仮定は冗長である（unsat core による） | **無い**（同上） |
| **仕様の変異テスト**[^ironspec][^mcoq] | 仕様を強める変異体を作り、証明が通ったまま残る変異体（alive）を、仕様が緩い兆候として報告する。弱める変異体と同値な変異体は除く | **無い**。成分の広さに効く |
| **Spec-Testing Proofs**[^ironspec] | 意図から書いた正・負の例を、仕様についての証明として示す（Usefulness・Correctness・Provability・Counterexample） | W 課題が Counterexample STP に当たる。ただし、ベクタは `run` から生成するので、意図とは独立していない |

## Considered Options

* A. 成分の必要性（vacuity detection の証拠）を義務にする
* B. 仕様の変異テストを、成分の広さの検査として採る
* C. 意図から書く例（STP）を、仕様の妥当性の手段として採る
* D. Dafny と同じく、証明の依存（unsat core）から冗長な仮定を検出する
* E. 何もしない（限界のままにする）

A・B・C は互いに排他でないので、組み合わせて評価した。

## Decision Outcome

Chosen option: "A・B・C を採る。A は本 ADR で義務と検査を定めて実装し、B は道具を backlog に起こし、C はスキルの方法として各機能で適用する", because 次のとおりだからである。

* A は、vacuity detection の定義をそのまま R 課題に当てはめたものである。Lean の定理と検査器で決定論的に確かめられる。
  * 「W 課題の一致しない例を人が読む」という限界が消える。
  * 費用は、成分ごとに 1 つの定理である。
* B は、A が届かない「広さ」に効く唯一の手法である。ただし、変異させる業務モデルがまだ無いので、道具の設計は最初の機能の証明の後に決める。
* C は、`run` から生成するベクタと独立した確認を与える。新しい道具は要らない。

### A. 成分の必要性（G9）

R 課題で使う名前付きの成分ごとに、**その成分を外した R 課題の命題が偽である** ことを、Lean の閉じた定理で示す。

| 成分 | 外し方 | 定理の形 |
| --- | --- | --- |
| 前提型の差異 `d`（`.restrict d`・`.restrictState d`・`Concrete.restrict d`） | その層を 1 つ外す | 抽象側の基底が `ofChoice` なら `¬ (Refines A' C' g ∧ Pinned A' C' g f ce)`、`pure` なら `¬ Refines A' C' g` |
| 観測型の差異 `d`（`Glue.ofStd` の OJ・OO） | `d` を `Machine.never` に替える | 同上（`A`・`C` はそのままで、貼り合わせを替えた `g'`） |
| 環境の前提 `Env`（`@[env_pre]`） | `Machine.always` に替える | `¬ A.TotalUnder always`（`TotalUnder A Env` を示した機械 `A` について） |

* **`ofChoice` の基底では `Pinned` を含める。** `Refines` だけでは、環境の選択（`Conflict`・I/O 失敗）が具体側の不具合を模倣する。そのため、差異を外しても `Refines` は成り立ちうる（ADR 0039 の抜け道「環境の非決定性が不具合を吸収する」。反例 13）。`f` は基底の `f`、`ce` は R 課題の `Pinned` の `ce` とする。
* **少なくとも 1 つの R 課題について示せばよい。** 同じ差異を引き継ぐ複合の R 課題（例: ABS-045 の D-001）ごとに示すことは求めない。複合の R 課題での冗長な使用は、B の変異テストの「除去」の変異体として報告する。
* **W 課題の内容を「両向きの例＋必要性」とする。** 必要性の定理は、その差異の W 課題（`ABS-1NN`・`REF-1NN`）として `@[obligation]` を付けてよい。課題の ID は増やさない。
* 環境の前提の必要性は、SPEC-006 に含める。
* Lean（スキル port-lang の `assets/lean/Machine/Adequacy.lean`）には、次を置く。
  * `always`
  * 証人から否定を導く補題: `Refines.not_of_error`（適用可能性が破れる）、`Refines.not_of_mismatch`（正しさが破れる）、`Refines.Pinned.not_of_mismatch`、`Machine.TotalUnder.not_always`
* 検査器 `obligation-check` の規則 G9 で、次を確かめる。
  * 必要性の定理の (A, C, g, f, ce) が、R 課題から成分を 1 つ外した形と一致すること。照合は `@[reducible]` を展開した式で行う。
  * 必要性の形の `@[obligation]` 定理（W 課題）を、G0（`Refines` を含むのに結論が `Refines` でない）の誤りにしない。

### B. 仕様の変異テスト（[backlog 0033](../backlog/0033-mutation-testing-of-named-components.md)）

名前付きの成分（`@[deviation]`・`@[env_pre]`・`FreeFrame` の射影）の本体を **仕様を強める向き**（差異を狭める向き）に変異させる。そして R 課題を作り直す。

* 生き残った変異体は、成分が必要以上に広い兆候である。
* IronSpec と同じく、弱める変異体と同値な変異体を除いてから判定する。
* 生き残った変異体ごとに、処置（成分を狭める／理由を付けて受け入れる）を記録する。処置の無い変異体を失敗とする（原則 1 の決定論的な検査にする）。
* 変異の演算子・処置の記録の形式・実行の頻度と費用は、backlog 0033 の未確定事項とし、実装のときに ADR で決める。

### C. 意図から書く例（Spec-Testing Proofs）

仕様文書の規範節に書いた具体例（例: [fare-calculation.md](../spec/fare-calculation.md) の D-002 の 1430 円・30%）は、`run` から生成したベクタとは別に、期待値を手で書いた検査で `Spec` に照らす。

* 形は `#guard` か定理とする。
* 許す例（Usefulness・Provability）に加えて、拒む例（Correctness。`¬ step s i s' o`、PRE の外）も書く。
* 方法はスキルの [conformance.md](../../.agents/skills/port-lang/references/conformance.md) と [spec-documents.md](../../.agents/skills/port-lang/references/spec-documents.md) に置き、各機能の `Spec` を作る backlog 項目で適用する。

### 保証の限界の変更（[spec/assurance.md](../spec/assurance.md)）

* 削除: 「W 課題の『一致しない例』が実際に差を示していることは、人が読んで確かめる」。G9 が、差異を外すと R 課題の命題が偽になることを確かめる。
* 残す: 成分の広さ。B の道具ができるまでは人の判断である。道具ができた後も、変異の演算子が作れない広さは人の判断である。
* 追加
  * 複合の R 課題での冗長な使用（G9 は少なくとも 1 つの R 課題についてだけ確かめる）
  * 環境の前提の必要性は機械ごとに見る。同じ機械に対する前提どうしの強さは比べない

### Consequences

* Good, because 「登録したが実在しない差異」が、検査で失敗するようになる（原則 3）
* Good, because 義務の名前と形を、研究の用語（feasibility・deadlock freedom・vacuity・interesting witness・mutation）と対応づけて説明できる
* Good, because W 課題の確認が、人の読解から定理の照合に変わる
* Bad, because 差異ごとに、必要性の定理が 1 つ増える。`ofChoice` の基底では `Pinned` の否定を示すために、環境を固定したすべての自由な選択との不一致を示す必要がある
* Bad, because B の道具を作るまで、成分の広さは人の判断のままである

### Confirmation

* `MachineTest/Adequacy.lean`
  * 反例 12: 不要な差異。`Refines` も `Nontrivial` も成り立つが、外しても成り立つ
  * 反例 13: 環境の選択が不具合を吸収する。`Refines` だけでは必要性を示せない
  * 正例: 前提型（`not_of_error`・`Pinned.not_of_mismatch`）、観測型（`not_of_mismatch`）、環境の前提（`TotalUnder.not_always`）
* `lean/Tests/ObligationFixture.lean` の正例と違反例で、`obligation-check` が次を判定することを `lake test` で確かめる。
  * 違反例: 必要性の無い差異、`Pinned` を伴わない必要性、必要性の無い環境の前提
  * 正例: 観測型の成分を `never` に替えた必要性、W 課題としての必要性（G0 の誤りにならない）
* `tools/ci/lean.sh` が全段通る。

## Pros and Cons of the Options

### A. 成分の必要性

* Good, because 研究で確立した定義（部分式を自明な値に替えると真理値が変わる）を、R 課題にそのまま当てはめられる
* Good, because 構成的な証明なので、検査器は形の照合だけで済む
* Bad, because 広さ（成分のどの部分が要るか）は分からない

### B. 仕様の変異テスト

* Good, because 広さに効く。mCoq・IronSpec が、検証済みのシステムの仕様の不備を実際に見つけている
* Bad, because 変異体ごとに証明を作り直すので費用が大きい。生き残った変異体の判断は人に残る（処置の記録で決定論的にする）

### C. 意図から書く例

* Good, because 道具が要らず、仕様文書の例をそのまま使える
* Bad, because 網羅性は無い。例の選び方は人の判断である

### D. 証明の依存から冗長な仮定を検出する

* Good, because Dafny では自動である
* Bad, because Lean には unsat core に当たるものが無い。`Classical` を使う証明では、依存の解析で必要性を判定できない。A の構成的な証拠のほうが強い

### E. 何もしない

* Good, because 費用が無い
* Bad, because 機械で確かめられる「差異の実在」を人の判断に残すことになり、原則 1・3 の趣旨に反する

## More Information

* 本 ADR は、[ADR 0039](0039-refinement-non-vacuity-obligations.md) の決定を変えず、義務（G9）と手段（B・C）を加える。
* [ADR 0033](0033-foundational-principles.md), [ADR 0034](0034-b-method-refinement-and-explicit-deviations.md), [ADR 0037](0037-conflict-as-spec-nondeterminism.md), [backlog 0032](../backlog/0032-component-necessity-witness.md), [backlog 0033](../backlog/0033-mutation-testing-of-named-components.md)

[^beer2001]: Beer, Ben-David, Eisner, Rodeh (2001). vacuity と interesting witness の定義。
[^kupferman2003]: Kupferman, Vardi (2003). すべての部分式が真理値に影響することを求める、強い vacuity の検出。
[^ironspec]: Goldweber ほか (OSDI 2024). Automatic Sanity Checker、Spec-Testing Proofs、仕様の変異テスト（弱める変異体の除去、vacuity の除去、証明の作り直し）。
[^mcoq]: Celik ほか (ASE 2019). Coq の定義の変異解析。生き残った変異体が、不完全な仕様を示す。
[^dafny-deps]: Dafny 4.4 の `--warn-contradictory-assumptions`・`--warn-redundant-assumptions`。
[^abrial2010]: Abrial (2010). Event-B の証明義務。
[^rodin-po]: Rodin の証明義務の名前（FIS・GRD・INV・WD など）。
[^leroy2009]: Leroy (2009). 前方シミュレーションと決定性から後方シミュレーションを得る。
[^certora-sanity]: Certora の規則の sanity check（vacuity）。
