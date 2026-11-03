---
type: Architecture Decision Record
title: "不正な状態を表現できない型（MISU）を Lean のすべてのデータ型に課す"
description: "値の妥当性の条件を docstring・別の述語・付けた時点の検査に置かず、型（和型・証明フィールド付きの structure・名前付きの structure）で表す。外部から来る値は生の型のまま置き、検証の関数で検証済みの型に移す。機械の PRE・INV、独立な入力の間の関係、環境の全体にわたる性質は述語・検査のまま残す。"
tags: [adr, skill, lean, types, misu]
id: "bf1bd8ee-25cd-4e3f-b64a-b6a57b48a15b"
status: stable
decision_status: accepted
date: 2026-11-03
decision-makers: プロジェクトオーナー（適用先 ATRS のオーナーの指示「各データ型を make illegal states unrepresentable にすることを徹底せよ」）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-03T14:00:00+09:00
---

# 不正な状態を表現できない型（MISU）を Lean のすべてのデータ型に課す

## Context and Problem Statement

スキルの Lean のライブラリと適用先の `Spec` には、妥当な値の条件を型の外に置いた型が多い。

* `Trace.Gap` は、種類（`kind`）によって欄の要・不要と許す証明の状態が変わる。その条件は、付けた時点の検査 `Gap.problems` が文字列のエラーで確かめている。
* `Machine.Preserves` は、`ch : Option Choice` と、`∀ c, ch = some c → …` で守った成分を持つ。`ch` と基底の機械の対応は、docstring と obligation-check の G6 にしか無い。
* `LangSemantics` の値の型（`JDouble.finite` の仮数と指数、`JLocalDate`・`JLocalTime`・`JLocalDateTime` の範囲、`JHashMap` のキーの一意性、`SequenceDef`、`ConformanceKit.SqlTable` の行の幅）は、移植元の処理系では作れない値も表せる。
* 適用先の `Spec` では、コード値が `val : String` と別の述語 `WellFormed` で、列の長さ・エラーコードの綴りは docstring にしか無い。

型の外の条件は、作る側が守らなければ破れる。破れた値は、証明では仮定の側に紛れ、道具では表や JSON の誤りとして後で見つかる。条件を型に置けば、破れた値はエラボレートの時点で作れなくなる。

## Decision Drivers

* 条件を、コメントや文書でなく形式的に表すこと。
* 外部から来る値（要求・設定・マスタ・DB の行・機械の入力）は、不正な値も来うる。それを表せなくしてはならない。PRE の外の振る舞いのギャップ（outsidePre）と、環境の前提の非自明性（G8）は、不正な入力を表せることに依存する。
* B メソッドの機械の PRE・INV は、述語であることが意味論の一部である（[ADR 6b4b](6b4b-preserves-refines-abstracts.md)）。
* 移植先の言語に写せること（[spec/portability.md](../spec/portability.md)）。
* 評価できること。`Spec`・`TargetModel` は実行可能でなければならない。また、登録簿の値は評価せずに式から読む（`Trace.Gap.ofConst?`）。

## Considered Options

* A: 値の不変条件を型に置き、外部の値は生の型と検証済みの型に分ける。述語のまま残すものを限定して列挙する。
* B: いまの述語と付けた時点の検査を保ち、文書で条件を補う。
* C: すべての条件（PRE・INV を含む）を型に置く。

## Decision Outcome

Chosen option: "A", because 値の状態は型で閉じられる一方、入力の不正と B メソッドの PRE・INV は、表せることそのものが方法の前提だからである。

### 規則

1. **値の不変条件は型に置く。**
   * 条件付きの欄 → 和型。構築子ごとに、その場合に要る欄だけを持たせる。
   * 空でない列・文字列、範囲、形式 → 証明フィールド付きの `structure`（`Subtype` でもよい）。雛形は `Spec.Prim.Date` と `LangSemantics.Sql.Postgresql.Int4` である。
   * 一緒に決まる旗・`Option` の組 → 1 つの和型。
   * 位置で意味が決まる組 → 名前付きの `structure`。
   * 同じ値の 2 つの写し → 片方を消し、必要なら導く関数にする。
   * 文字列で表した有限の値（コード・層・種類）→ 列挙（`inductive`）。外部に出す綴りは `toCode` 関数で与える。
2. **境界は「生の型 → 検証済みの型」に分ける**（parse, don't validate）。
   * 外部から来る値は、来うる値をすべて表せる生の型のまま置く。対象は機械の入力、要求、設定・マスタの環境、DB の行である。
   * 検証の関数 `Raw → Option Valid`（`none` は PRE の外）か `Raw → Except E Valid`（`E` は仕様が定めるエラー）で、検証済みの型に移す。内部の関数は検証済みの型だけを受ける。
   * 生の型であることは、宣言に `@[raw_input "<理由>"]` を付けて明示する。
3. **述語・検査のまま残すもの**（値の状態ではないので MISU の対象外とする）
   * 機械の PRE・INV。B メソッドの意味論であり、G8 の非自明性と outsidePre のギャップがこれに依存する。
   * 互いに独立な入力の間の関係。例: 状態とマスタの外部キー（どちらの型にも置けない）。
   * 環境の全体にわたる性質。宣言の書き方（「その場で書く」「`@[std_abs]` の定数である」）、名前の解決、docstring の有無、登録簿の ID の重複などで、obligation-check・GK・`trace check` が検査する。
   * 評価せずに式から読む値の、字面の形（文字列リテラルであることなど）。
4. **移植しやすさ。**
   * 和型と証明フィールドは、移植先では、和型（enum）と、検査付きの構築子を持つ newtype に写る。証明は消える。
   * `Spec` の公開関数のシグネチャには、添字付きの型族（長さで添字づけたベクタなど）を使わない。長さの条件は証明フィールドで持つ。
5. **リファインメントへの影響。**
   * 検証済みの型を作る α は、具体側の不変条件の下で証明を渡す。不変条件の外では、既定の値に写してよい（`dite`）。
   * 具体側に、抽象側の型で表せない値があれば、それは前提型の差異（具体側の入力・状態）である。
   * 抽象側の PRE の成分が型に移ると、その成分を `excludedBy` に挙げた outsidePre の項目は付け替えが要る。付け替えは、適用先の意思決定記録に残す。
6. **繰り返しの作業。**
   * 型の棚卸しの手順を [guide/type-inventory.md](../guide/type-inventory.md) に置く。機能を取り込むたびと、版上げの後に使う。
   * `scripts/ci/check_lean.py` の MISU-1 は、`Spec` で、証明フィールドの無い単一の `String`・`Nat` を包む `structure` と、型の外の `T.WellFormed`・`T.Valid` を、`@[raw_input]` が無ければ誤りにする。

### Consequences

* Good, because 不正な値はエラボレートの時点で作れなくなり、付けた時点の文字列の検査（`Gap.problems` など）が要らなくなる。
* Good, because 生の型と検証済みの型の境界が宣言（`@[raw_input]`）で見え、仕様の読み手が「どこで検証するか」を型から読める。
* Bad, because 型を作るところで証明が要る。字面には `by decide` の既定値とマクロを用意し、生成器はそれを出す。
* Bad, because 既存の宣言と証明の書き換えが大きい。段ごとに行う（[backlog d3fd](../backlog/d3fd-misu-skill-types.md)）。

### Confirmation

* `scripts/ci/check_lean.py` の MISU-1。
* 不正な値が型の誤りになることの `#guard_msgs`（`Test/Trace/GapErrors.lean` など）。
* 型の棚卸し（[guide/type-inventory.md](../guide/type-inventory.md)）の結果を、適用先の意思決定記録に残す。

## Pros and Cons of the Options

### B: 述語と検査を保つ

* Good, because 書き換えが要らない。
* Bad, because 条件は作る側の注意に依存し、検査の書き漏れを見つけられない。

### C: PRE・INV も型に置く

* Bad, because PRE の外の入力・状態を表せなくなり、B メソッドの意味論、outsidePre のギャップ、G8 の非自明性が成り立たない。

## More Information

* 来歴: 適用先 ATRS のオーナーの指示。ATRS の側の適用は、ATRS の ADR 6d36 と backlog 8d24 にある。
* 関連: [ADR 6b4b](6b4b-preserves-refines-abstracts.md)（Preserves・Refines・Abstracts）、[ADR 61e6](61e6-env-relation-and-state-env-pre.md)（環境の前提）、[lang/lean/rules.md](../lang/lean/rules.md#不正な状態を表現できない型)。
