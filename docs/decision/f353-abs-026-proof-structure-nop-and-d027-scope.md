---
type: Architecture Decision Record
title: "ABS-026 の証明の構成と、空港コード NOP の禁止・D-027 の範囲・LocalDate の通算日数の修正を決める"
description: "R 課題 ABS-026 の証明に向けて、空港コード NOP を MD-8 で禁じること、D-027 の対象を具体側の入力全体に広げること、LangSemantics.Java の LocalDate の通算日数の変換を床除算で書き直すこと（負の年で JVM と食い違っていた）、補題の置き場所と、有限の範囲の検査にカーネルの評価（decide +kernel）を使うことを決める。"
tags: [adr, abstraction, master-data, lang-semantics]
id: "f35355de-9923-4691-935a-34a550fd0814"
status: stable
decision_status: accepted
date: 2026-10-31
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-31T14:40:17+09:00
---

# ABS-026 の証明の構成と、空港コード NOP の禁止・D-027 の範囲・LocalDate の通算日数の修正を決める

## Context and Problem Statement

[backlog 25f7](../backlog/25f7-fare-calculation-both-models.md) の第 2 段 b では、R 課題 ABS-026 を証明する。第 2 段 b は 2b-1・2b-2 に分けた（プロジェクトオーナーの決定）。

| 段 | 内容 |
| --- | --- |
| 2b-1 | 補題と [Spec] の修正 |
| 2b-2 | 主定理・付帯の義務・W 課題 |

証明を組み立てる中で、次のことが分かった。

* 空港コードリストの区切り行のコードは `NOP` である。`NOP` は英大文字 3 文字なので、MD-8 を満たす。
  * `NOP` の空港があると、[Source] の `LinkedHashMap` では、同じキーへの `put` で区切り行の表示がその空港の名前に置き換わる。
  * [Spec] は両方を並べる。ABS-026 が成り立たない。
* ABS-026 の具体側の入力には、問い合わせの引数（`LocalDate` など）もある。Java の `LocalDate` は、[Spec] の暦日（1〜9999 年）を超える日付を取る。
  * D-027（ADR c108）の対象は DB のマスタと設定だけで、問い合わせの引数は入力の全域性を満たさない。
* `LangSemantics.Java` の `LocalDate.toEpochDay`・`ofEpochDay` は、H. Hinnant の算法を C++ の 0 方向の除算のつもりで写していた。
  * Lean の `Int` の `/` は床除算なので、負の年で JVM と食い違っていた。例: -400-03-01 は JVM で -865565、モデルで -865566。
  * これまでの JVM の突き合わせ表には、負の年が無かった。
* `omega` は入れ子の床除算（400 年の周期の中の年と日の範囲）を扱いきれない。

## Decision Drivers

* 基本原則 1〜3（ADR c336）。不一致は、証明と文書で明示する。
* `sorry`・公理・`native_decide` を使わない（check_lean・axiom-check）
* 言語意味論（スキルの assets）を、アプリに依存しない正しいモデルに保つ

## Considered Options

* 下表のとおり決める
* `NOP` を前提型の差異にする
* 問い合わせの値域を別の差異にする

## Decision Outcome

Chosen option: "下表のとおり決める", because 次のとおりだからである。

* `NOP` は区切り行の予約語で、入力検証も `NOP` を「存在する」と扱う。仕様として空港コードに使えないとするのが自然である（プロジェクトオーナーの決定）。
* 表せない値は、入力の成分によらず 1 つの差異にまとめられる（プロジェクトオーナーの決定）。

| 項目 | 決定 |
| --- | --- |
| `NOP` | MD-8 に「空港のコードは `NOP`（`Spec.MasterData.airportNopCode`）でない」を加える。破れた場合の [Source] の振る舞いは、「[Spec] の前提の外」に記録する |
| D-027 の範囲 | 具体側の入力全体（DB のマスタの各行・設定・問い合わせの引数）とする。述語は「α が定義される」。ADR c108 の決定を補う |
| `LocalDate` の通算日数 | `toEpochDay`・`ofEpochDay` を床除算で書き直す。<br>- 周期 `era = y / 400`（`z / 146097`）、周期の中の位置は剰余とする<br>- `ofEpochDay` は、補助の関数（`yoeOfDoe`・`doyOfDoe`・`mpOfDoy`・`civilOfDoe`）に分ける<br>- JVM の突き合わせ表に、負の年・400 年の境界・PostgreSQL の日付の範囲の端を加える |
| 往復の補題 | `LangSemantics.Java.JLocalDate.toEpochDay_ofEpochDay`（すべての整数で `toEpochDay (ofEpochDay z) = z`）を、スキルの assets（`LocalDateLemmas`）で証明する |
| 有限の範囲の検査 | 400 年の周期の中の年・日の範囲（`civil_bounds`）は、146097 日をカーネルの評価（`decide +kernel`。1000 日ずつ）で確かめる。<br>- `native_decide` ではないので、カーネルが検査する（公理を足さない）<br>- ビルドに約 45 秒かかる |
| 参照の答えの射影（2b-2a） | [Spec] の参照の答えのうち、搭乗クラス・運賃種別は表示順を除いた射影（`BoardingClassInfo`・`FareTypeInfo`）とする。[Source] の参照の結果には表示順が無い（Mapper が `display_order` を選ばない）。表示順はコードリストの問い合わせだけが観測する。差異は増えない（プロジェクトオーナーの決定） |
| 空白の便名（2b-2a） | `Query.Valid` の便名に「空白でない」（`Spec.Prim.hasText`。文字クラス `Blank` は Java の `Character.isWhitespace` と同じ集合）を加える。`Query.Valid` は原典の `Assert.hasText` に当たるので、誤りの修正である。`FlightName.WellFormed` は変えない（プロジェクトオーナーの決定） |
| 標準の抽象化 α の形（2b-2a） | 値・行・問い合わせ・答えの写しは `@[std_abs]` の葉とし、核の定理を示す（ABS-048）。<br>- 行の写しを合成にしないのは、`Varchar n` の述語（`String.length`）が項に現れ、G7 の許可した構成に収まらないためである<br>- マスタ全体・設定・入力（`masterDataOf`・`configOf`・`aiMQ`）は、葉を `Option.bind`・`List.mapM` などで組んだ合成とする<br>- 答えの写し `answerOf?` の核 `answerKer` は、[Spec] が観測する成分（`answerObs`）の一致である |
| 部分写像の汎用の核（2b-2a） | 定義域の上で単射な部分写像の核を、汎用の `@[kernel]` の定数 `undefOrEq`（どちらも定義されないか、等しい）をその葉自身に適用して書けるよう、obligation-check の G7 を広げる。別の葉に適用したものは受けない（`ObligationFixture` の正例・反例）。葉ごとに同じ形の核の定数を書く冗長を避ける |
| 補題の置き場所 | 次のとおり置く。依存の向き（check_lean）に従う。<br>- アプリに依存しない補題（`LocalDate`・`HashMap`）: スキルの assets<br>- [Spec] と `LangSemantics.Java` をつなぐ補題（暦の一致など）: `Abstraction`<br>- R 課題の定理ではないので、`@[obligation]` は付けない |

### Consequences

* Good, because `LocalDate` のモデルの誤り（負の年）が直り、JVM の表で確かめられる
* Good, because ABS-026 の入力の全域性と、区切り行の一致が示せるようになる
* Bad, because `LangSemantics.Java` のビルドが約 45 秒長くなる
* Bad, because MD-8 が強くなり、`NOP` の空港を持つ DB は [Spec] の前提の外になる
* Bad, because [Spec] の参照の答えの型が、マスタの要素の型と別になる（`BoardingClassInfo`・`FareTypeInfo`）
* Bad, because obligation-check の核の受け入れの規則が 1 つ増える

### Confirmation

* JVM の突き合わせ表（`tools/ci/jvm_table.sh`）が、負の年を含めて一致する。
* 開発中に、JVM と 4229 点（-1316〜10183 年と、日付の範囲の端）を突き合わせ、両向きで一致することを確かめた。
* `toEpochDay_ofEpochDay` などの補題が、`sorry`・公理なしでビルドされる（axiom-check）。
* `Tests.SpecChecks` で、`NOP` の空港が MD-8 を破ることを確かめる。
* 2b-1 の補題の一覧は [backlog 25f7](../backlog/25f7-fare-calculation-both-models.md#第-2-段-b-1-の結果) に記す。

## More Information

* [ADR c108](c108-master-data-source-model-and-spec-fixes.md)、[ADR 9ac6](9ac6-vacuity-literature-necessity-and-mutation.md)、[ADR c336](c336-foundational-principles.md)
* [abstraction.md](../spec/abstraction.md#既知差異)（D-027）、[master-data.md](../spec/master-data.md)
