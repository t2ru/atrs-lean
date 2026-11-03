---
type: Architecture Decision Record
title: "束 Preserves の環境の固定を「許す選択の関係」に、環境の前提を状態つきの述語に広げる"
description: "障害の位置を具体側の入力が持ち、障害が実際に起きるかと、起きるまでに進んだもの（採番など）が実行で決まるユースケースでは、環境の選択を入力だけの関数 ce で決められない。束の pinned を、具体側の環境の記述 ce ic が許す選択の関係 adm に広げ、障害の指定の無い記述は標準の選択だけを許す（noFaultStd）。また、状態とマスタの対応（外部キー）を PRE に持つユースケースのため、環境の前提を状態と入力の述語にし、その証人は初期状態で示す。"
tags: [adr, skill, lean, refinement, vacuity]
id: "61e6eb4a-60b0-465a-8f46-65742c8605fe"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: プロジェクトオーナー（適用先 ATRS の予約の第 3 段 3d で、判断 1・3 とも案 A を選んだ）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T12:00:00+09:00
---

# 束 Preserves の環境の固定を「許す選択の関係」に、環境の前提を状態つきの述語に広げる

## Context and Problem Statement

適用先 ATRS の予約（R 課題 ABS-041）に束 `Machine.Preserves` を当てはめると、次の 2 つが示せなかった。

1. **環境の固定（`pinned`）**
   * 具体側（移植元の写し）の実行環境は、障害の位置を「k 番目の SQL 文で I/O の失敗」の形で持つ。
   * 障害が実際に起きるかは、実行で決まる。k 番目の文より前に業務例外で終われば、障害は起きない。業務例外で終わるかは、状態（会員の有無など）で決まる。
   * 失敗したときに採番がいくつ進んだかも、どこで止まったかで決まる。
   * 一方、従来の `pinned` は、抽象側の環境の選択を、具体側の入力だけの関数 `ce : ιc → E` で固定することを求めた。
   * 入力だけでは、障害が起きるかも、採番の進んだ数も決められない。
2. **入口の全域性（`total`）**
   * 予約の PRE は、状態とマスタの対応（フライトのコード・会員のカード種別がマスタにある。本物の DB では外部キー）を含む。
   * 従来の `total` は、INV と入力だけの環境の前提から PRE が出ることを求めた。
   * 状態とマスタの関係は、入力だけの前提からは出ない。
   * 状態の前提を持つ差異（例: 採番の値が上限を超えない）も、`restrictState` の層で同じ問題を起こす。

## Decision Drivers

* `pinned` の目的を守ること。目的は、障害の無い環境で具体側の誤りを「障害が起きた」と説明できないようにすることである。
* 状態を変えるユースケースの障害と取り消しの振る舞いを、主定理の中に残すこと。
* `total` の目的を守ること。目的は、PRE が環境の条件より強すぎないことである。そのうえで、外部キーのような状態とマスタの対応を、環境の条件として書けること。
* 既存の R 課題（入力だけの環境、関数の `ce`）を、形を変えずに表せること。

## Considered Options

* (a) `pinned` を「具体側の環境の記述 `ce ic : D` が許す選択の関係 `adm : D → E → Prop`」に広げ、環境の前提を状態と入力の述語にする。証人は初期状態で示す。
* (b) 主定理の対象を、障害の起きない環境と、状態の前提が要らない入力に絞る。
* (c) 抽象側（`Spec`）に「k 回目のポート呼び出しで失敗」を書き、障害の位置を入力から写す。

## Decision Outcome

Chosen option: "(a)"。理由は次のとおりである。

* 障害の指定の無い記述が標準の選択だけを許す（`noFaultStd`）ので、障害の無い環境では従来と同じく選択が固定される。これで `pinned` の目的は保たれる。
* 障害の指定がある記述では、障害が起きたか・起きなかったか、採番の進んだ数を、具体側の実行に合わせて選べる。採番の値そのものは、状態の対応 `J` で厳密に合わせる。
* `adm` を等号 `Machine.Preserves.sameEnv` にすれば、従来の関数の `ce` と同じである。既存の R 課題はこれで表せる。
* 環境の前提を状態つきにすれば、外部キーのような対応を環境の条件として書ける。証人を初期状態 `s₀` で示すので、前提が空でないことは従来どおり確かめられる。
* (b) は、障害の振る舞いと状態の前提を持つ入力を主定理の外に出し、保証が弱くなる。
* (c) は、抽象側を移植元の呼び出し順に縛り、移植先も同じ順にしなければならなくなる。

### 決定

| 項目 | 決定 |
| --- | --- |
| `Machine.Preserves.Choice` | 欄に `D`（具体側の環境の記述の型）・`adm : D → E → Prop`（記述が許す環境の選択）・`d₀ : D`（障害の指定の無い記述）を足す。`ce : ιc → D` |
| `Refines.Pinned A C g f ce adm` | 具体側の正常終了ごとに、`∃ e x, adm (ce ic) e ∧ J (f s ia (e, x)).1 t' ∧ αo oc (f s ia (e, x)).2` |
| `Refines.NoFaultReachable C g ce d₀` | 形は従来どおり（環境の記述が `d₀` の具体側の入力でも実現される） |
| 束の `noFaultStd` | `∀ c, ch = some c → ∀ e, c.adm c.d₀ e → e = c.e₀`（障害の指定の無い記述は標準の選択だけを許す） |
| `adm` の形（obligation-check の G6） | `Machine.Preserves.sameEnv`（等号）か、`Spec` の層の裸の定数。`ce` は従来どおり裸の `@[std_abs]` の定数 |
| `Machine.TotalUnder A Env` | `Env : σ → ιa → Prop`。`∀ s i, A.Inv s → Env s i → A.Pre s i`。`restrictState` の述語は、状態つきのまま環境の前提に加えられる |
| `Refines.EnvWitness C g s₀ Env` | `∃ ic ia, C.Dom ic ∧ g.αi ic ia ∧ Env s₀ ia`（初期状態で示す） |
| `Machine.Preserves.always` | 2 引数（状態と入力）の常に真の述語 |
| 並置 | 状態つきの環境の前提の並置 `Machine.Sum.sumEnv`（`Machine.sum`。状態は組）・`altEnv`（`Machine.alt`。同じ状態） |
| 複数歩の模倣 `Abstracts.run_of` | 各入力の像が、INV を満たすどの状態でも環境の前提を満たすことを仮定する |
| 違反例 | `Test/Trace/ObligationFixture.lean` の `v6_admPlain`（`adm` が証明の層の補助の関係なら G6） |
| 版 | 0.27 |

### Consequences

* Good, because 障害の位置を入力に持つ具体側でも、障害の無い環境での固定を保ったまま、障害と取り消しの振る舞いを主定理に含められる
* Good, because 外部キーのような状態とマスタの対応を、PRE の中でなく環境の条件として明示できる
* Bad, because 既存の束の環境の前提を、状態を受ける形（`fun _ => env`）に書き直す必要がある
* Bad, because 状態つきの環境の前提では、複数歩の模倣の仮定が「INV を満たすどの状態でも」になり、その前提を満たさない状態を含む軌跡には使いにくい（状態の前提を不変条件として保つ形は、必要になったときに足す）

### Confirmation

* `assets/lean` の `lake build`（`Test.Machine`・`Test.Trace` を含む）と `lake exe trace-test` が通る。
* 適用先 ATRS の既存の束（ABS-026・001・002・004・011）とトップレベルの `Abstraction.preserves` が、新しい形で通る。
* 適用先 ATRS の予約の束（ABS-041）が、`adm` と状態つきの環境の前提で示せる。

## More Information

* 来歴: 適用先 ATRS の ADR ab93（予約の第 3 段 3d）
* [spec/architecture.md#空虚化を防ぐ義務](../spec/architecture.md#空虚化を防ぐ義務)
* 先行の判断: [ADR 6b4b](6b4b-preserves-refines-abstracts.md)（束 `Preserves`）
