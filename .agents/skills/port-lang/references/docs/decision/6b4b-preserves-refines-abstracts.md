---
type: Architecture Decision Record
title: "adequate の廃止: A abstracts B = A preserves B ∧ B refines A"
description: "義務の束 Machine.Adequate を廃止し、B メソッドのリファインメント Machine.Refines（B refines A）と、R 課題の空虚化を防ぐ意味的な義務のすべてを束ねた Machine.Preserves（A preserves B。Refines を含まない）に分ける。両者の組を Machine.Abstracts（A abstracts B）とする。G6 は束の ch・outs を照合し、GA を GP、OB-A を OB-P に改める。並置と側ごとの段階導入は ADR ab9e から引き継ぐ。"
tags: [adr, skill, lean, refinement, traceability]
id: "6b4b86f4-2870-4f6f-a655-1602c5e068ee"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/remote
  at: 2026-10-31T23:59:00+09:00
---

# adequate の廃止: A abstracts B = A preserves B ∧ B refines A

## Context and Problem Statement

[ADR ab9e](ab9e-adequate-bundle-sum-and-side-staging.md) は、R 課題ごとの義務の束 `Machine.Adequate A C g s₀ Env` を定めた。この束は、リファインメント `refines` と空虚化を防ぐ義務の一部（`sound`・`initIs`・`initSurj`・`total`・`envWitness`・`envNeeded`）を、1 つの構造体に混ぜていた。次の 3 つの問題があった。

- 「adequate」という語は、何を保証するのかを表さない。束は R 課題の主定理 `Refines` と重複していた（束が `refines` を含む）。
- 束の外に、空虚化を防ぐ義務が別の定理として残っていた。`Pinned`・`NoFaultReachable`・`FreeFrame`（基底が `ofChoice`）と、`StateSafe`（出力のみの差異）である。そのため、束を見ても R 課題の義務の全体は分からなかった。
- 「リファインメント」の語が、B メソッドの意味（具体側の振る舞いが抽象側の許す範囲に収まる）なのか、空虚化を防ぐ義務まで含むのかが曖昧だった。

適用先 ATRS のオーナーの依頼による（ATRS の ADR 91be・backlog cb23）。依頼の構造は `(A abstracts B) = (A preserves B) and (B refines A)` で、空虚化を防ぐ証明課題群を preserves とし、そこに refines を含めないことである。

## Decision Drivers

* `refines` の語を、B メソッドのリファインメントの意味に保つこと
* 空虚化を防ぐ意味的な義務を、R 課題ごとに 1 つの主張としてすべて示すこと（束の外に残すのは、課題をまたぐ義務と構文の条件だけ）
* 束が `Refines` を含まず、`Refines` と独立に証明できること
* 既存の R 課題の形（G0〜G9）、並置（`Machine.Sum`）、側ごとの段階導入を壊さないこと
* モジュールと名前空間の規則（[ADR 1a30](1a30-lean-module-namespace-layout.md) の NS-1）を守ること

## Considered Options

* 束の分け方
  * `Preserves`（`Refines` を含まない）と `Abstracts = Preserves ∧ Refines` に分ける
  * `Adequate` の名前だけを変え、`refines` を含めたままにする
* 条件付きの義務（`Pinned`・`NoFaultReachable`・`FreeFrame`・`StateSafe`）の置き場所
  * `Preserves` の成分にする。条件は引数（`ch : Option Choice`・`outs`・`outsC`）で渡し、当たらないときは既定の証明で閉じる
  * `Abstracts` の第 3 の成分にする（B に無い具体→抽象の強化として、`Pinned`・`StateSafe` を別の群にする）
  * 今どおり、束の外の別の定理にする
* 差異の必要性（G9）
  * `Abstracts` に含めない（W 課題のまま）
  * R 課題ごとに `Abstracts` に含める
* モジュール名
  * `Preserves` で統一する（`Machine.{Machine,Glue,Refines}.Preserves`、型に属さない述語は `Machine.Preserves.Pred`）
  * `NonVacuity` で統一する

## Decision Outcome

Chosen option: "`Preserves` と `Abstracts = Preserves ∧ Refines` に分け、条件付きの義務も `Preserves` の成分にする。必要性は含めない。モジュールは Preserves で統一する", because `refines` を B の意味のまま保ち、R 課題ごとの意味的な義務を 1 つの束で示せるため。
`Adequate` の改名だけでは、`Refines` との重複と、束の外の義務が残る。条件付きの義務を第 3 の群にすると、「空虚化を防ぐ義務はすべて preserves」という依頼の構造が崩れる。
必要性は、差異 ID ごとに課題をまたいで課す（少なくとも 1 つの R 課題で示す）義務である。R 課題ごとに課すと現行の規則より強くなり、新しい証明が要る。

### B メソッドのリファインメントとの照合

`Machine.Refines` を、B の証明義務と照合した。M（INVARIANT I）を M'（INVARIANT J）がリファインし、操作 `PRE P THEN S` を `PRE P' THEN S'` にリファインする。

| B の証明義務 | 式 | `Refines` の成分 | 対応 |
| --- | --- | --- | --- |
| 初期化 | `[Init'] ¬[Init] ¬J` | `init` | 一致 |
| 操作: 事前条件 | `I ∧ J ∧ P ⇒ P'` | `applicable` の `∀ e, ¬ C.step t ic (.error e)` | 一致。`Concrete.ofMachine` が PRE の違反を `.error` に写すので、「誤りにならない」が「P' が成り立ち、abort しない」に当たる |
| 操作: 停止 | `[S'] R` の trm(S') | `applicable` の `∃ r, C.step t ic r` | 一致（やや強い）。wp の意味論では、奇跡（結果の無い S'）が義務を空虚に満たす。B は、実装（B0）が実行可能な代入だけを使うことで、これを排除している。具体機械は実装のモデルなので、`∃ r` で同じことを要求する |
| 操作: 正しさ | `I ∧ J ∧ P ⇒ [S'] ¬[S] ¬(J ∧ out' = out)` | `correct` | 一致。抽象側の非決定性は減らしてよく、具体側のすべての分岐が模倣されなければならない |
| （入力は同じ名前・型） | — | `input_total` と `αi`・`αo` | 一般化。`αi`・`αo` が等号なら B と同じになる。`input_total` は、像を持たない、制約の無い具体側の入力を生まないための条件である（B では入力が同一なので、自動的に成り立つ） |
| 抽象機械の無矛盾性 | M 自身の義務 | `Machine.Sound`（`Refines` の外。`Preserves` の `sound`） | B でもリファインメントの義務ではない |

`Refines` は B の初期化・操作の証明義務を、入出力の対応で一般化したものであり、B の意味と食い違う点は無い。PRE の外では、具体側に義務が無い（B と同じ）。
`Pinned`・`StateSafe` は B に無い強化なので、`Refines` には入れない。`Abstracts` は B のリファインメントより厳密に強い（`Abstracts` ⇒ B refines A。逆は成り立たない）。

### 定義

```lean
structure Preserves (A : Machine σ ιa οa) (C : Concrete τ ιc οc ε) (g : Glue σ τ ιa ιc οa οc) (s₀ : σ)
    (Env : ιa → Prop) (ch : Option (Choice σ ιa οa ιc) := none) (outs : List (OutLayer σ ιa οa) := [])
    (outsC : List (OutLayerC τ ιc οc ε) := []) : Prop where
  sound : A.Sound
  initIs : A.InitIs s₀
  initSurj : Refines.InitSurj A C g
  total : A.TotalUnder Env
  envWitness : Refines.EnvWitness C g Env
  envNeeded : Env = always ∨ ¬ A.TotalUnder always
  pinned : ∀ c, ch = some c → Refines.Pinned A C g c.f c.ce := by intro _ h; simp at h
  noFault : ∀ c, ch = some c → Refines.NoFaultReachable C g c.ce c.e₀ := by intro _ h; simp at h
  freeFrame : ∀ c, ch = some c → Machine.FreeFrame c.f c.m := by intro _ h; simp at h
  stateSafe : ∀ l ∈ outs, Refines.StateSafe l.base C g l.P := by intro _ h; simp at h
  stateSafeC : ∀ l ∈ outsC, Refines.StateSafeConcrete A l.base g l.P := by intro _ h; simp at h

structure Abstracts (A C g s₀ Env) (ch := none) (outs := []) (outsC := []) : Prop where
  preserves : Preserves A C g s₀ Env ch outs outsC
  refines : Refines A C g
```

- `Choice`（`E`・`F`・`P`・`f`・`ce`・`e₀`・`m`）は選択の像の材料、`OutLayer`・`OutLayerC`（`base`・`P`）は「出力のみ」の差異の層である。どちらも `Machine.Preserves` の名前空間に置く。
- 基底が `pure` で「出力のみ」の差異が無い R 課題では、`ch`・`outs`・`outsC` が既定値になり、条件付きの成分は既定の証明で閉じる。
- `Abstracts` の系は、両方を使うもの（`run`・`run_init`・`exists_ok`・`complete`）である。`Refines.run`・`Refines.complete` は、`Abstracts.run_of`・`Abstracts.complete_of` に改めた。

各成分の向き（抽象のみ、抽象→具体、具体→抽象）と塞ぐものは、[architecture.md](../spec/architecture.md#空虚化を防ぐ義務)の表に置く。

### `Abstracts` の外に残る義務

| 義務 | 規則 | 外に残す理由 |
| --- | --- | --- |
| 差異の必要性（`¬ Refines`・`¬ (Refines ∧ Pinned)`・`Covers`） | G9（W 課題） | 差異 ID ごとに、少なくとも 1 つの R 課題について課す。課題をまたぎ、`Refines` の否定も含む |
| `Nontrivial`（`@[deviation]`・`@[env_pre]`） | G8 | 定数ごとの義務 |
| `KernelIs`（`@[std_abs]` の葉、`Choice.m`） | G7・G3 | 定数ごとの義務。K が等号か `@[kernel]` であることは構文の条件 |
| `ch`・`outs` が R 課題の構造に合うこと | G6 | 基底と「出力のみ」の区別は、構文と登録簿で決まる |
| 形（閉じた型、`Glue.ofStd`、`ofChoice`/`pure`、同語反復の禁止）と配置 | G0〜G5・G7、layout-check | 構文の条件 |
| `Spec` 自身の課題 | SPEC-NNN | 抽象機械だけの義務 |

### モジュール（NS-1）

| モジュール | 内容 |
| --- | --- |
| `Machine.Refines` | `Refines`（B のリファインメント）、系 `congr`・`complete_fun`、否定 `not_of_error`・`not_of_stuck`・`not_of_mismatch` |
| `Machine.Glue` | `Glue.Equiv` を足す |
| `Machine.Preserves.Pred` | 型に属さない述語 `Machine.Preserves.{never, always, anyOf, Covers, Covers₂, Nontrivial, Nontrivial₂, KernelIs}`（旧 `Machine.Adequacy`。E1） |
| `Machine.Machine.Preserves`・`Machine.Glue.Preserves`・`Machine.Refines.Preserves` | 旧 `Machine.{Machine,Glue,Refines}.Adequacy`（`ofChoice`・`InitIs`・`TotalUnder`・`Glue.ofStd`・`InitSurj`・`Pinned`・`StateSafe` など） |
| `Machine.Machine.Run`・`Machine.Concrete.Run` | 歩みの列 |
| `Machine.Preserves`・`Machine.Preserves.Sum` | 束 `Preserves`、`Preserves.core`・`Preserves.sum`・`Preserves.congrPre` |
| `Machine.Abstracts`・`Machine.Abstracts.Sum` | `Abstracts.Forall₂`、束 `Abstracts` と系、`Abstracts.sum`・`Abstracts.congrPre` |
| `Machine.Refines.Sum` | `Refines.congrPre` を足す |

利用側は、述語を `open Machine.Preserves (never always …)` のように名前を選んで開く。

### トップレベルの主定理

```lean
theorem refines : Machine.Refines (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue
theorem preserves : Machine.Preserves (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
theorem abstracts : Machine.Abstracts (Spec.machine.restrict dev) (SourceModel.machine.restrict devC) glue Spec.init env
```

`refines` は R 課題の主定理の並置（`Refines.sum`・`Refines.congrPre`）から、`preserves` は R 課題ごとの束の並置（`Preserves.sum`・`Preserves.congrPre`）から示す。どちらも、もう一方を使わない。`abstracts` は両者の組である。

### 検査

* obligation-check
  * G6（改訂）: R 課題ごとに、同じ課題 ID・同じ `A`・`C`・`g` の `@[obligation]` の `Machine.Preserves` がある。
    * `ch` は、基底が `ofChoice` のときに限り `some (Choice.mk E F P f ce e₀ m)` とする。`f`・`e₀` は基底のもの、`ce` は `@[std_abs]` の定数そのものである。自由な選択があれば、`m` は `KernelIs` の定理を持つ定数そのものとする（無ければ G3）。
    * `outs`・`outsC` の層の述語は、R 課題の制限の述語とする。層の `base` は、その層を外した機械か基底とする。
    * 別の定理としての `InitSurj`・`Sound`・`InitIs`・`Pinned`・`NoFaultReachable`・`FreeFrame`・`StateSafe` は、もう要求しない。
  * GP（旧 GA）: 結論が `Machine.Preserves` の `@[obligation]` は、同じ課題 ID の R 課題と同じ `A`・`C`・`g` を束ねる。
  * 報告の `obligations[].preserves`（旧 `adequate`）。R 課題の `state_safe` は束の層から、`total_under` は束の `Env` と別の定理から出す。
* `check_obligations.py`: OB-P（旧 OB-A）。フィクスチャを `r-without-preserves` に改める。
* `trace check`: TR-P は、R 課題と束（`preserves`）の閉包を使う（`Preserves` は `Refines` を含まないので、R 課題そのものも閉包に入れる）。

### ADR ab9e から引き継ぐもの

機能の機械の並置（`Machine.Sum`）、トップレベルの主定理を `Abstraction.lean`・`Refinement.lean` に置くこと、主定理に `@[obligation]` を付けないこと、追跡の検査の側ごとの段階導入は、ab9e の決定をそのまま引き継ぐ。名前は上のとおりに改める。

### Consequences

* Good, because `refines` が B メソッドのリファインメントの意味だけを表し、空虚化を防ぐ義務と混ざらない
* Good, because R 課題ごとの、空虚化を防ぐ意味的な義務が 1 つの束にまとまり、束の外の義務（必要性・定数ごとの義務・構文の条件）との境界が明確になる
* Good, because `Preserves` は `Refines` を含まないので、トップレベルの `preserves` と `refines` が独立に示される
* Bad, because 条件付きの成分を持つ束どうしの並置（`Choice` と層の並置）は、まだ無い。現行の R 課題は基底が `pure` で「出力のみ」の差異を使わないので、トップレベルも全体の定義を満たす。最初の `ofChoice`・「出力のみ」の R 課題を取り込むときに、`Preserves.sum` を一般化する
* Bad, because 名前が大きく変わる。対応表（ATRS の `tools/docs/lean-renames-preserves.json`）と `scripts/lean/rename.py` で書き換えた

### Confirmation

* `assets/lean` の `lake build`・`lake exe trace-test`・`lake exe layout-check` が通る。
  * `Test.Machine.Preserves`: `halfC_preserves`（`Refines` を使わない）と `halfC_abstracts`、条件付きの成分を持つ `goodLang_preserves`・`goodLang_abstracts`、反例 `langC_not_preserves`
  * `Test.Trace.ObligationFixture`: G6・GP の正例と違反例
* `scripts/ci/check_obligations.py --self-test` と `scripts/trace` の `cargo test`（`tr_p_follows_preserves_bundle`）が通る。
* 適用先 ATRS で `tools/ci/lean.sh` が通る。

## More Information

* 置き換える ADR: [ADR ab9e](ab9e-adequate-bundle-sum-and-side-staging.md)
* [architecture.md](../spec/architecture.md#空虚化を防ぐ義務)、[traceability.md](../spec/traceability.md#検査)
* 範囲外: `Choice` と「出力のみ」の層の並置（上の Consequences）
* 来歴: ATRS の ADR 91be・backlog cb23
