---
type: Architecture Decision Record
title: "空席照会の第 2 段: 状態を読むだけの機械、シードのフライトの生成と展開しない証明、業務例外を出力の値にすること、SQL の差分実行"
description: "backlog 0be7 の第 2 段の設計を決める。空席照会の抽象機械は選択を持たない Machine.ofChoice で状態を変えない 1 歩とし、初期状態はシード 00250 の生成の形から作り、主キーの一意性と参照整合性を展開せずに証明する。具体機械は FLIGHT 表を状態とし、業務例外を出力の値として受ける。findByVacantSeatSearchCriteria は PostgreSQL で全件を投入して実行し、条件の押し下げを定理で示したうえで照合する。D-027 の範囲を状態の表 FLIGHT に広げる。"
tags: [adr, spec, source-model, flight-search, world, sql, conformance]
id: "cdb6c8a2-ad5d-4904-8527-1e22361a57d6"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T12:00:00+09:00
---

# 空席照会の第 2 段: 状態を読むだけの機械、シードのフライトの生成と展開しない証明、業務例外を出力の値にすること、SQL の差分実行

## Context and Problem Statement

[backlog 0be7](../backlog/0be7-flight-search-usecase.md) の第 2 段は、R 課題 ABS-011（第 3 段）の土台として、次のものを作る（[ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md)）。

* 状態を持つ抽象機械と具体機械
* その初期状態（シード 00250 から作る）
* SPEC 課題
* SQL の写しの PostgreSQL での差分実行

着手にあたって、次の 4 つの問題があった。

1. obligation-check（G3・G3'）は、[Spec] の機械の基底を `Machine.ofChoice` か `Machine.pure` に限る。一方 `pure` は、状態が `Unit` の場合に限られる。
2. シード 00250 は plpgsql の関数で、121 日 × 1260 行（15 万行）を投入する。Lean のリテラルにも JSON にも展開できず、主キーの一意性を `decide` で確かめることもできない。
3. 原典は、業務例外（2001・2002・2003）を例外の経路で返す。`Machine.Refines` は、PRE の下で具体側がエラーで止まることを許さない。
4. 空席照会の文は 4 つの表の直積を選ぶ。FLIGHT の全件で写しを評価すると約 38 億組になり、テストで評価できない。

## Decision Drivers

* 基本原則 1〜3（[ADR c336](c336-foundational-principles.md)）。差分実行は決定論的な照合で、評価の近道は定理で正当化する。
* スキルの検査器（obligation-check）を変えずに済むなら、変えない。
* 生成物は上流のシードから決定論的に作り、CI が `--check` で最新であることを確かめる。

## Considered Options

* 機械: (a) 選択を持たない `ofChoice`（選択の型は `Unit`）、(b) スキルに `Machine.readOnly` を足し、obligation-check を広げる
* シード: (a) 生成の形（日付 × 便名 × 枠）のまま書き出し、性質を形から証明する、(b) 全件を書き出す
* 業務例外: (a) 具体機械の出力の値にする、(b) 抽象側でもエラーの経路にする
* 差分実行: (a) 全件を PostgreSQL に投入し、Lean は条件を押し下げた形で評価する（等しさは定理）、(b) 小さな FLIGHT 表を別に作って投入する

## Decision Outcome

Chosen option: "機械 (a)・シード (a)・業務例外 (a)・差分実行 (a)", because 検査器を変えずに済み、原典のシードそのものとの一致を確かめられ、評価の近道が定理で正当化されるからである（プロジェクトオーナーの承認した計画）。

### 決定

| 項目 | 決定 |
| --- | --- |
| 抽象機械 | `Spec.FlightSearch.searchMachine := Machine.ofChoice World.Inv (· = Seed.Flight.world) SearchInput.Pre (fun w i (_ : Unit × Unit) => (w, answer w i)) () ()`。<br>- 1 歩は状態を変えない。<br>- PRE は、設定とマスタの不変条件、`World.RefMaster`、照会の空港コードの形。<br>- `searchFlight_isSome` で、PRE の下では `answer` の既定値が観測されないことを示した。<br>- 当初の計画にあったスキルの `Machine.readOnly` は、G3・G3' を広げる必要があるので採らなかった |
| シードの生成 | `tools/conformance/flight_seed.py` が 00250 を読む。<br>- 関数の形（期間・日の進め方・3 つのパターン・便ごとの 10 枠の共通の順序）を確かめる。<br>- 日付の列・枠の列・便名の列・パターンの表を、`Spec.Seed.Flight` と `SourceModel.Repository.FlightSeed` に書き出す。<br>- 全件は、`world`・`seedFlightDb` が列の組み合わせで作る |
| 展開しない証明 | `Spec.Seed.FlightProps.world_inv`: 日付・便名・枠の列がそれぞれ重複しないことから、主キーの一意性を示す（`List.pairwise_flatMap`）。<br>`world_refMaster`: 便名・枠の列がシードのマスタにあることを、`decide +kernel` で確かめる。どちらも全件を展開しない |
| 具体機械 | `SourceModel.FlightSearchQuery.searchConcrete`。状態は `FlightDb`、初期状態は `seedFlightDb`。<br>- 1 歩は `∃ mo sortRows, mo.Allowed ic.db ∧ SortAllowed sortRows ∧ r = (catchBusiness (runSearchFlight t ic mo sortRows)).map (t, ·)` で、状態を変えない。<br>- 業務例外（`AtrsBusinessException`・`FlightNotFoundException`）は、出力の値 `BusinessError` にする（[ADR a4fa](a4fa-errors-as-values-with-stable-codes.md)）。<br>- それ以外の例外は、例外の経路に残す |
| 差分実行 | `tools/conformance/master_sql.py` が 00250 を、`current_date` を投入日に置き換えて投入する。<br>- FLIGHT の要約（行数・整列した全行の md5）を、生成器の展開と照合する。<br>- `findByVacantSeatSearchCriteria` は、この文に限って `<foreach>`・`#{…}` を束縛する値のリテラルで描画し、13 の条件で実行する（`conformance/sql/flight-search.json`）。<br>- `Tests.FlightSql` は、まず `seedFlightDb` の全行の多項式ハッシュが生成器の値と一致することを確かめる。次に `vacantSeatRowsOn` を評価し、PostgreSQL の並びが許される並びであることを確かめる。`vacantSeatRowsOn` は FLIGHT の行だけで決まる条件を先に絞る形で、`vacantSeatRows_eq_on` により `vacantSeatRows` に等しい |
| スキル | `LangSemantics.Sql.QueryLemmas` に、条件の押し下げの補題 `cross_filter_left`・`select_filter_of_imp` を足す（スキルの版 0.16） |
| D-027 | 範囲を状態の表 FLIGHT に広げる（[ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md) のレビューでのプロジェクトオーナーの決定）。<br>- α `Abstraction.FlightSearch.Alpha.flightOfRow`・`worldOfDb` を置き、核の定理 `flightOfRow_kernel`（ABS-048）を示した。<br>- 照会は状態を変えないので、シードから到達する状態は前提を満たす。<br>- 導出した日付（照会可能期間の末日）は、[Spec] が日数で比べるので機械の上では生じない |
| 第 3 段への申し送り | 初期状態の対応 `worldOfDb seedFlightDb = some Seed.Flight.world`（InitSurj の中身）、R 課題 ABS-011、L 課題 ABS-010、W 課題、トップレベルへの統合、D-032 の述語 |

### Consequences

* Good, because 原典のシードそのもの（PostgreSQL で実行した 00250）と、Lean の初期状態が決定論的な照合で結ばれる
* Good, because 主キーの一意性と参照整合性が、展開せずに数十秒で証明できる
* Good, because スキルの検査器を変えずに、状態を持つ機械を置ける
* Bad, because `Tests.FlightSql` の評価が数十秒かかる（条件ごとに FLIGHT の全件を一度なめる）
* Bad, because 業務例外を値にする対応（`catchBusiness`）が、原典のどの層にも 1 対 1 では対応しない。画面・API が業務例外を捕まえることの写しであることを、文書に記す

### Confirmation

* `lake build` で、`world_inv`・`world_refMaster`・`searchFlight_isSome`・SPEC 課題（`searchMachine_run_step`・`searchMachine_sound`・`searchMachine_initIs`）・`vacantSeatRows_eq_on`・`flightOfRow_kernel` が、`sorry`・公理なしで通る（axiom-check）。
* `lake test` の `Tests.FlightSql` で、シードの照合と 13 の条件がすべて合格する。
* `tools/ci/master_sql.sh`・`flight_seed.py --check` が通る。

## More Information

* [ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md)（第 1 段）、[ADR c108](c108-master-data-source-model-and-spec-fixes.md)（マスタの文の差分実行）、[ADR 9ee4](9ee4-clock-timezone-and-fixture-base-date.md)（投入日）、[ADR a4fa](a4fa-errors-as-values-with-stable-codes.md)
* [backlog 0be7](../backlog/0be7-flight-search-usecase.md)、[spec/conformance.md](../spec/conformance.md)、[spec/abstraction.md](../spec/abstraction.md#既知差異)（D-027）
