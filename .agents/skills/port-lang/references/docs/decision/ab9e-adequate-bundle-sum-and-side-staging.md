---
type: Architecture Decision Record
title: "義務の束 Machine.Adequate、機械の並置によるトップレベルの主定理、側ごとの段階導入"
description: "R 課題ごとに、Refines と空虚化を防ぐ義務を Machine.Adequate に束ね、同じ課題 ID の @[obligation] で示す（GA・OB-A）。機能の機械を Machine.sum で並置し、トップレベルの Refines・Adequate を Abstraction.lean・Refinement.lean に置く。追跡の検査の段階導入を、指摘の側（移植元・移植先）の作業項目で判定する。"
tags: [adr, skill, lean, refinement, traceability]
id: "ab9e8324-7818-4618-9335-9c61321f3916"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T23:30:00+09:00
---

# 義務の束 Machine.Adequate、機械の並置によるトップレベルの主定理、側ごとの段階導入

## Context and Problem Statement

R 課題の主定理 `Refines` と、空虚化を防ぐ義務（`Sound`・`InitIs`・`InitSurj`・`TotalUnder`・`EnvWitness` など。[architecture.md](../spec/architecture.md#空虚化を防ぐ義務)）は、別々の定理として書いていた。
付帯の定理があるかは obligation-check の G6 が式の一致で探すが、次の 3 つの問題があった。

- 何がどこにあるか分からない。主定理は機能ごとの下の名前空間に散らばり、`Abstraction.lean`・`Refinement.lean` を読んでも、移植元・移植先と [Spec] の関係が分からない。
- 義務が束として示されない。`Refines.run`（複数歩の模倣）は `Sound` と `TotalUnder` を要るが、それらを 1 つにまとめた主張が無い。
  入口でない R 課題の `TotalUnder`・`EnvWitness` は課されず、示されなかった。
- 段階導入が移植先の完了を待つ。追跡の検査（TR-S1・TR-P・TR-D・TR-K）は、機能の作業項目が **すべて** 完了するまで警告にとどまる。そのため、移植元側を終えた機能でも、移植先側（別の言語の実装）が終わるまで、移植元側の退行が CI で失敗しない。

適用先 ATRS のオーナーの依頼による（ATRS の ADR a41d・backlog 76a6）。

## Decision Drivers

* トップレベルの主張を、ファイルの冒頭で読めること
* 空虚化を防ぐ義務を、R 課題ごとに 1 つの主張として示し、その系（複数歩の模倣、具体側の正常終了の実在）を使えること
* 移植元側を終えた機能が、以後の機能の取り込みで壊れないことを CI で保つこと
* 既存の R 課題の形（G0〜G9）と道具を壊さないこと

## Considered Options

* 義務の束
  * 構造体 `Machine.Adequate A C g s₀ Env`（`refines`・`sound`・`initIs`・`initSurj`・`total`・`envWitness`・`envNeeded`）を足し、R 課題と同じ課題 ID の `@[obligation]` で示す
  * R 課題の結論そのものを `Adequate` に変える
  * 付帯の定理を別々に置くままにする
* トップレベルの主定理
  * 機能の機械を並置する `Machine.sum`（入力は和、状態は積）を足し、`Refines.sum`・`Adequate.sum` で R 課題から組み立てる
  * トップレベルの機械を機能ごとに手で書く
* 段階導入
  * `features.json` の作業項目を側（`source`・`target`）に分け、指摘の側の作業項目で判定する
  * 現在の警告の集合を固定し、増えたら失敗にする（ラチェット）

## Decision Outcome

Chosen option: "義務の束を別の構造体とし、R 課題と同じ ID で示す。機能の機械は並置で組み立てる。段階導入は側ごとに判定する", because 既存の R 課題の形と G0〜G9 を変えずに、束とトップレベルの主張を足せるため。
R 課題の結論を `Adequate` にすると、G1〜G9 の照合（制限の連鎖、`Glue.ofStd`、必要性の形）をすべて書き換える必要がある。
ラチェットは、機能の作業中に正当に増える警告と区別できない。

* `Machine.Adequate`（`Machine.Adequacy`）
  * 系: `run_init`（初期状態からの複数歩の模倣）、`exists_ok`（環境の前提を満たす具体側の入力が正常終了し、抽象側の歩みで模倣される）
  * `envNeeded` は「環境の前提を置かない（`Env = always`）か、前提が無ければ PRE が成り立たない入力がある」とする。PRE が全域な機械にも課せる
  * 出力が関数で決まる機械（`Machine.pure` とその制限）の 1 歩の可換式 `Refines.complete_fun` を足す。`Pinned` を持たない機械の完全性である
* `Machine.Sum`
  * `Machine.sum`・`Concrete.sum`・`Glue.sum`・`sumPred`
  * `Refines.sum`・`Adequate.sum`
  * `Adequate.congrPre`: PRE と具体側の定義域を各点で同値なものに替える。並置した機械の制限（`(A₁.sum A₂).restrict (sumPred P₁ P₂)`）と、制限した機械の並置を結ぶ
* トップレベルの主定理は次の形とし、適用先の `Abstraction.lean`・`Refinement.lean` のトップレベルに置く。`Spec.machine` は機能の機械の並置である。

  ```lean
  theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
  theorem adequate : Machine.Adequate (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
  ```

  主定理は機能をまたぐので、`@[obligation]` を付けない（形の検査は R 課題ごとに行う）。
* 検査
  * obligation-check
    * GA: 結論が `Machine.Adequate` の `@[obligation]` は、同じ課題 ID の R 課題と同じ `A`・`C`・`g` を束ねる
    * G3': `Spec` の層の機械は、`ofChoice`・`pure` か、それらを `Machine.sum` で並置したもの
  * `check_obligations.py`
    * OB-A: Lean にある R 課題に、同じ課題 ID の束が無い
    * OB-R: 束を、R 課題の ID を持つ非 `Refines` の定理の誤りにしない
  * `trace check`
    * TR-P: 「R 課題の閉包」に、束の閉包を含める。束の証人（`EnvWitness` の入力など）に現れる移植元の定義も、R 課題で使われたとみなす
    * 段階導入（側ごと）
      * 移植元側の作業項目で判定する: TR-S1、`SourceModel` の操作の TR-P、`Abstraction` 層・D-NNN の TR-D・TR-K
      * 移植先側の作業項目で判定する: TR-T1、`TargetModel` の操作の TR-P、`Refinement` 層・T-NNN の TR-D・TR-K
      * 両側の完了で判定する: TR-PE（入口からの到達は、入口の機能に依存する）
      * 側の作業項目が無い機能では、その側の指摘は警告にとどまる
      * 作業項目を配列だけで書いた機能（従来の形）は、両側に共通とみなす
    * `--verbose` に `--feature`・`--rule` の絞り込みを足す。機能を取り込むときに、未対応の項目を機能ごとに一覧する

### Consequences

* Good, because トップレベルの主張がファイルの冒頭で読め、`lake build` が通る限り、取り込んだ機能すべてについて束が成り立つ
* Good, because 移植元側を終えた機能の退行が、移植先側の完了を待たずに CI で失敗する
* Good, because 入口でない R 課題にも `TotalUnder`・`EnvWitness` が課され、R 課題の具体側の正常終了が実在することが示される
* Bad, because R 課題ごとに束の定理が 1 つ増える。束は既存の付帯の定理を並べるだけなので、手間は小さい
* Bad, because トップレベルの主定理は `@[obligation]` を持たず、形の検査の対象外である。並置と `congrPre` だけで組み立てるので、R 課題の形の検査で足りる

### Confirmation

* `assets/lean` の `lake build`・`lake exe trace-test` が通る。`Test.Machine.Adequacy` の正例（`halfC_adequate` と系）、`Test.Trace.ObligationFixture` の GA の正例・違反例。
* `scripts/ci/check_obligations.py --self-test`（OB-A のフィクスチャ `r-without-adequate`）と `scripts/trace` の `cargo test`（`staged_by_side`・`tr_p_follows_adequate_bundle`）が通る。
* 適用先 ATRS で `tools/ci/lean.sh` が通る。

## More Information

* [architecture.md](../spec/architecture.md#空虚化を防ぐ義務)、[traceability.md](../spec/traceability.md#検査)
* 来歴: ATRS の ADR a41d・backlog 76a6
