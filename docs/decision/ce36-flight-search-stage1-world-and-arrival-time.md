---
type: Architecture Decision Record
title: "空席照会の第 1 段: フライトを World の状態とし、翌日着の到着時刻を表し、Java の原典実行の完了条件を f18c に移す"
description: "backlog 0be7（空席照会）を 3 段に分け、第 1 段の設計を決める。フライトは抽象状態 World の成分とし、空席照会は状態を読むだけの操作とする。便マスタの到着時刻は出発日 0:00 からの時分（24 時以降を許す）で表し、fixture の outsideSpec を外す。[Source] の DateTimeParseException は予約（B2）の往復便の検査で起きるので、D-031 として登録する。Java の原典実行との一致の完了条件を backlog f18c に移す。"
tags: [adr, spec, source-model, flight-search, world, master-data]
id: "ce36fa1e-e227-4754-93ec-cbc59247e79c"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T10:00:00+09:00
---

# 空席照会の第 1 段: フライトを World の状態とし、翌日着の到着時刻を表し、Java の原典実行の完了条件を f18c に移す

## Context and Problem Statement

[backlog 0be7](../backlog/0be7-flight-search-usecase.md)（空席照会 B1）は、次の 2 点で、これまでの機能（マスタの参照・運賃計算）と違う。

* SQL に業務ロジックがある。`findByVacantSeatSearchCriteria` は、FLIGHT・FARE_TYPE・FLIGHT_MASTER・ROUTE の結合、`IN`、`BETWEEN`、2 列の `ORDER BY` を持つ。
* 読む表 FLIGHT は、予約で空席数が変わる。マスタのように不変の入力とは言えない。

着手の前に、次の 4 つを決める必要があった。

1. 0be7 は `depends_on` に backlog f18c（Java の原典実行。todo）を持つ。規約（[backlog.md](../rules/backlog.md)）では、このままでは着手できない。
2. フライトを機械の状態とするか、入力とするか。
3. 上流のシードの便マスタのうち NTT523・NTT528 は到着時刻が `2415`（翌日 0:15）で、[Spec] の `HourMinute`（0:00〜23:59）で表せない。[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md) は暫定措置として fixture に `outsideSpec` を付け、解消を 0be7 に委ねていた。
4. 作業の分け方。

調べると、3 について [master-data.md](../spec/master-data.md) と 0be7 の記述に誤りがあった。

* 空席照会は到着時刻を `DateTimeUtil.toFormatTimeString` で文字列として整形するだけで、`"2415"` を `"24:15"` にする。例外は投げない。
* `DateTimeParseException` を投げるのは `DateTimeUtil.toLocalTime`（`DateTimeFormatter("HHmm")`、SMART）である。呼ぶのは予約（B2）の `TicketSharedServiceImpl.validateFlightDepartureDateForRoundTripFlight` で、往路便が NTT523・NTT528 のときに起きる。

## Decision Drivers

* 基本原則 1〜3（[ADR c336](c336-foundational-principles.md)）。差異は、証明と文書で明示する。
* [ports.md](../spec/ports.md#world抽象状態) は `flights` を `World` の成分とし、マスタだけを不変の入力とする。[refinement.md](../spec/refinement.md) の REF-001 は、空席照会を「状態を変えない操作」とする。
* 移植先で同じ振る舞いを再現できる、言語中立な時刻の表し方にする。
* 一度に大きな差分を作らず、段ごとに検査ゲート（`tools/ci/lean.sh`）を通す。

## Considered Options

* フライト: (a) `World` の状態の成分とし、空席照会は状態を読むだけの 1 歩とする、(b) マスタと同じく入力の成分とする
* 到着時刻: (a) 出発日 0:00 からの時分（24 時以降を許す）、(b) 時分と翌日の印の組
* 原典実行: (a) 完了条件を f18c へ移して着手する、(b) 先に a8ef・f18c を済ませる

## Decision Outcome

Chosen option: "フライト (a)・到着時刻 (a)・原典実行 (a)", because 文書（ports.md の `World`、REF-001）の位置づけと一致し、空席照会（B1）は到着時刻について Spec=Source になり、原典実行を待たずに段ごとに検査ゲートを通せるからである（プロジェクトオーナーの決定）。

### 決定

| 項目 | 決定 |
| --- | --- |
| 段の分け方 | 0be7 を 3 段に分ける。<br>- 第 1 段: `Spec.FlightSearch` と `SourceModel.FlightSearch`（SQL の `Bag` 式を含む）の関数、`Spec.Port.World`、到着時刻の表し方、共有ベクタ。<br>- 第 2 段: 初期状態（シード 00250 の展開）、FLIGHT 表を含む PostgreSQL での差分実行、`Spec`・`SourceModel` の機械と SPEC 課題。<br>- 第 3 段: L 課題 ABS-010・R 課題 ABS-011 と、トップレベルの主定理への統合 |
| Java の原典実行 | 0be7 の完了条件「`source-model/` ベクタが Java の原典実行と一致する」を [backlog f18c](../backlog/f18c-java-oracle-harness.md) に移し、0be7 の `depends_on` から f18c を外す。期待値は、f18c までは仕様の例から取る（[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md) と同じ） |
| フライト | `Spec.Port.World` を置き、いまの成分は `flights : List Flight` だけとする。INV は主キー（出発日・便名・搭乗クラス・運賃種別）の一意性である。空席照会は、状態を変えずに `flights` を読む操作とする（機械は第 2 段）。[Source] の状態は FLIGHT 表 `FlightDb` で、マスタの表 `MasterDb` は入力のままとする。予約（[backlog aedf](../backlog/aedf-reservation-usecase.md)）と状態を共有する機械の合成は、aedf で決める |
| 関数の形 | `Spec.FlightSearch.searchFlight` は、設定・マスタ・今日の日付・照会条件・フライトの全件を引数に取る（[flight-search.md](../spec/flight-search.md#シグネチャ)）。`SourceModel.Domain.Service.B1.TicketSearchServiceImpl.searchFlight` は、読み込んだ Provider・設定・今日の日付・照会条件と、Mapper の文の結果の並び（許される順序の 1 つ）を引数に取る |
| 今日の日付 | 入力の成分とする（[ports.md](../spec/ports.md#clock)）。[Source] は 1 回の照会で Clock を 3 回読むが、モデルは 1 つの値で写し、箇所に `@[gap "D-014"]` を付ける（D-014 の前提「Clock の各呼び出しが同じ日付を返す」の下での写し） |
| 到着時刻 | `Spec.Prim.Time.ArrivalTime` を置く。出発日 0:00 からの時分で、`hour < 48`・`minute ≤ 59`（翌日の 23:59 まで）。`HHmm` の 4 桁の数字列から読み（`ArrivalTime.parseHHmm`）、`HH:mm` で書く（`2415` → `24:15`。[Source] の `toFormatTimeString` と同じ）。MD-6 は分数で比べる。出発時刻は `HourMinute` のままとする。値域の外の文字列（例 `4815`・`2460`）は、引き続き D-027（α が定義されない）の範囲である |
| fixture | `master_fixture.py` は、到着時刻を `ArrivalTime` の値域で判定し、NTT523・NTT528 に `outsideSpec` を付けない。`Spec.Seed` と `Spec` 用の読み込みは、2 行を含む |
| DateTimeParseException | 既知差異 D-031（前提型、[Source] の入力）として登録する。前提は「往復の予約で、往路便の到着時刻が 24:00 未満」。24:00 より後は例外、`2400` は例外にならず当日 0:00 と読まれる（SMART の解決）。R 課題は ABS-021・ABS-041、W 課題は ABS-131 で、証明の状態は未証明（予約の `SourceModel` が未着手）とする。証明は aedf で行う |
| 言語意味論 | `DecimalFormat("###,###")`・`String.substring`・`String.format("%s:%s")` に当たる最小の写しが無ければ、スキルの `LangSemantics.Java` に足す（アプリに依存しない） |

### Consequences

* Good, because 空席照会（B1）は到着時刻について Spec=Source になり、差異を足さずに済む
* Good, because NTT523・NTT528 が `Spec` のマスタに入り、[ADR 8f18](8f18-fare-source-model-and-shared-vectors.md) の暫定措置が解消する
* Good, because `World` が最初の状態の成分を持ち、以後の機能（予約・会員）が同じ型を広げられる
* Good, because 例外の起きる箇所（B2）を正しく記録し、W 課題を予約の R 課題とともに証明できる
* Bad, because 状態を持つ機械の合成（空席照会と予約が同じ `flights` を見る）は aedf まで決まらない
* Bad, because `ArrivalTime` と `HourMinute` の 2 つの時刻の型を持つ
* Bad, because `source-model/` の期待値は、f18c までは原典の実行で確かめたものではない（[assurance.md](../spec/assurance.md)）

### Confirmation

* `lake build`・`lake test` で、`shared/flight-search` のベクタを `Spec` と `SourceModel` の両方で実行し、すべて合格する。
* ABS-026 の証明（`queryRefines`・`queryPreserves`・`need_D027`）が、到着時刻の葉を `ArrivalTime` に替えても、`sorry`・公理なしで通る（axiom-check）。
* `master_fixture.py --check`・`seed_lean.py --check` が通り、fixture に `outsideSpec` が無い。
* 登録簿に D-031 があり、`trace manifest --check` が通る。

## More Information

* 敵対的レビュー（第 1 段の完了前。独立したエージェント）の指摘と対応:
  * フライトがマスタに無い搭乗クラスなどを指すと、[Spec] は `none`、[Source] は NPE になり、「`none` は MD-3 が破れたときだけ」という説明が誤りだった → フライトの参照整合性 `Spec.Port.World.RefMaster`（FK_FLIGHT_1〜3）を置き、説明を直した。機械の PRE に入れるのは第 2 段。
  * [Source] は 1 回の照会で Clock を 3 回読む → D-014 の R 課題に ABS-011 を加えた。
  * 運賃の書式 `DecimalFormat("###,###")` の区切り文字は JVM の既定の書式ロケールによる → 既知差異 D-032（前提型・具体側の環境。W 課題 ABS-132）を登録した（プロジェクトオーナーの決定）。
  * 状態の表 FLIGHT の値（負の空席数など）と、導出した日付（照会可能期間の末日が 9999-12-31 を超える場合）は D-027 の範囲の外 → 第 2 段で、FLIGHT の α（`FlightDb` → `World`）とともに D-027 の範囲を広げる（プロジェクトオーナーの決定）。
  * `2400` は SMART の解決で例外にならず、当日 0:00 と読まれる → D-031 の説明を直した（前提は変わらない）。
  * 同順位・置き換えが起きない根拠は MD-5 だけでなく MD-1・MD-2・`World.Inv` も要る → 説明を直した。第 2 段の具体機械の 1 歩には `mo.Allowed ic.db` と `SortAllowed sortRows` を課す。
  * 確かめて正しかったもの: 例外の評価順、期間の判定の同値、候補の条件と SQL の結合の同値（MD-2 の下）、`ORDER BY` の同順位が生じないこと、グループ化、到着時刻の書式、ベクタの期待値（独立に再計算して一致）。
* [ADR 8f18](8f18-fare-source-model-and-shared-vectors.md)（翌日着の便の暫定措置）、[ADR e9bc](e9bc-fare-double-analysis.md)（原典実行の完了条件を f18c に移した前例）、[ADR c108](c108-master-data-source-model-and-spec-fixes.md)（Mapper の文の `Bag` 式と許される並び）、[ADR 5fcb](5fcb-sql-semantics-for-source-repositories.md)、[ADR 97f9](97f9-persistence-and-transaction-semantics.md)
* [flight-search.md](../spec/flight-search.md)、[master-data.md](../spec/master-data.md)、[ports.md](../spec/ports.md)、[abstraction.md](../spec/abstraction.md#既知差異)（D-014・D-027・D-031）
