---
type: Architecture Decision Record
title: "予約の第 1 段: 3 段の分け方、状態の共有、World と状態の表の拡張、予約の Spec と SourceModel の関数"
description: "backlog aedf（予約）を 3 段に分ける。空席照会と予約が同じ World を共有するため、スキルに同じ状態の上の合成子を足す。World に会員・予約・採番を、SourceModel の状態の表に会員・予約の表とシーケンスを足す。予約の Spec（Spec.Reserve.FlightSelection・Spec.Reserve）と SourceModel（原典のソースツリーの形）の関数、共有ベクタ、Java の原典実行を第 1 段で置く。D-009 の範囲を INT の上限に広げる（確認待ち）。"
tags: [adr, spec, source-model, reservation, world, transaction]
id: "4c452acd-cb57-40e1-ba49-b623b35fb390"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-01T23:00:00+09:00
---

# 予約の第 1 段: 3 段の分け方、状態の共有、World と状態の表の拡張、予約の Spec と SourceModel の関数

## Context and Problem Statement

[backlog aedf](../backlog/aedf-reservation-usecase.md)（予約 B0/B2）は、状態を変える最初の機能である。これまでの機能と比べて、次の点が新しい。

* 状態を変える（フライトの空席数を減らし、予約を登録する）。
* トランザクションがある。失敗したら取り消す。採番だけは巻き戻らない。
* 環境の非決定性（N-001 `Conflict`・N-002 I/O 失敗）と、自由な非決定性 N-004（`InvalidRequest` の詳細）がある。
* 状態の成分を、すでに完了した空席照会（[backlog 0be7](../backlog/0be7-flight-search-usecase.md)）と共有する。

着手の前に、次のことを決める必要があった。

1. 作業の分け方。
2. 状態の共有の仕方。スキルの `Machine.sum` は状態を積にするので、予約をトップレベルの 6 番目の加数にすると、空席照会と予約が別々の `World` を持ってしまう。そうなると、照会が予約の結果を見ない。
3. `World` と [Source] の状態の表の広げ方。
4. 予約の操作の境界。原典は、選択フライトの検証・予約内容の検証・予約の登録を、別のトランザクション（または、トランザクションの外）で行う。
5. 新しい差異と、既存の差異の修正をどう登録するか。

f18c（Java の原典実行）は、別のセッションで完了していた。そのため、aedf の依存はすべて完了している。

## Decision Drivers

* 基本原則 1〜3（[ADR c336](c336-foundational-principles.md)）
* [`Spec.Port`](../../lean/Spec/World.lean) は、フライト・会員・予約・採番を `World` の成分とする。状態を変えるユースケースは、原子的な 1 つの操作とする（[ADR 97f9](97f9-persistence-and-transaction-semantics.md)、[ADR e56e](e56e-conflict-as-spec-nondeterminism.md)）。
* 空席照会の R 課題 ABS-011 の証明を、できるだけ作り直さない。
* 段ごとに検査ゲート（`mise run ci`）を通す。

## Considered Options

* 状態の共有
  * (a) スキルに、同じ状態の上で入力と出力を和にする合成子 `Machine.alt` を足す
  * (b) 空席照会と予約を、1 つの機械（入力 `SearchInput ⊕ ReserveInput`）に組み直す
* 予約の操作の境界
  * (a) Controller の順に、選択フライトの検証を含める
  * (b) Service のメソッドごとに操作を分ける
* 差異の登録
  * (a) 「プロジェクトオーナーの確認待ち」と明記して登録し、作業を続ける
  * (b) 登録のたびに作業を止める

## Decision Outcome

Chosen option: "状態の共有 (a)・操作の境界 (a)・差異の登録 (a)"。理由は次のとおりである。

* (a) なら、ABS-011 は状態の型の変更に合わせて直すだけで済み、予約の R 課題とは別に証明できる。
* 原典の Controller が観測できる単位と、[`Spec.Http`](../../lean/Spec/Http.lean#b2-予約) の単位が一致する。
* 差異の登録は、[ADR 0b0c](0b0c-flight-search-stage3-abs011.md) の D-033 と同じ扱いである。

状態の共有・差異の登録・段の分け方は、プロジェクトオーナーが決めた。

### 決定

| 項目 | 決定 |
| --- | --- |
| 段の分け方 | aedf を 3 段に分け、行けるところまで 1 つの PR に積む。<br>- 第 1 段: 予約の `Spec` と `SourceModel` の関数、`World` と状態の表の拡張、共有ベクタ、Java の原典実行。<br>- 第 2 段: 合成子 `Machine.alt` と例・反例、初期状態（会員のシードと採番の初期値）、抽象機械 `reserveMachine` と SPEC 課題、具体機械 `reserveConcrete`、予約の SQL の PostgreSQL での差分実行。<br>- 第 3 段: α を全表に広げ、L 課題 ABS-020・ABS-022、R 課題 ABS-021・ABS-023・ABS-041、W 課題 ABS-109・ABS-131、トップレベルの主定理への統合 |
| 状態の共有 | スキルに `Machine.alt`（同じ状態 σ の上で、入力と出力を和にする）と、`Concrete.alt`・`Glue.alt`（2 つの貼り合わせで `J` が同一）・`Refines.alt`・`Preserves.core.alt` を足す（[スキルの ADR a303](../../.agents/skills/spec-pivot/references/docs/decision/a303-shared-state-machine-alt-and-transaction.md)。実装は第 2 段）。トップレベルの 5 番目の成分を `searchMachine.alt reserveMachine` にする |
| `World` | 成分は `flights`・`members`・`reservations`・`sequences`（`Spec.World.Sequences`。各採番の次の値。値の空間は上限を持たない）。登録した搭乗者は、搭乗者番号との組 `Spec.Model.PassengerRecord` とする。INV に足すもの（会員・予約の主キー、参照整合性、使用済みの番号が次の値より小さいこと）は第 2 段で決める |
| 状態の表 | `SourceModel.Db.Schema.FlightDb` に、MEMBER・MEMBER_LOGIN・RESERVATION・RESERVE_FLIGHT・PASSENGER の行と、4 つのシーケンスの状態を足す。名前は第 1 段では変えない。取消は `FlightDb.rollback` で、表は開始時に戻し、シーケンスは終了時のまま。空席照会の α `worldOfDb` の定義域は、予約・会員の表とシーケンスが使われていない状態に限る。全表の α は第 3 段で置く |
| 状態の表に対する計算 | `SourceModel.Db.Tx.DbM := EStateM JThrow St`。状態は、表とシーケンス、実行環境（Clock の i 回目の値、I/O の失敗・排他の失敗を起こす文の位置）、読み出しの回数である。<br>- Mapper の文は `sql` で実行し、SQL のエラーは Spring の `DataAccessException` に変換する。<br>- `@Transactional` は `transactional` で写す。業務例外も取り消す。<br>- 行ロック（`FOR UPDATE`）と分離レベルは写さない（並行実行はモデルの外。D-025・SRC-005） |
| 予約の操作 | `Spec.Reserve.confirmOp`・`reserveOp` は、Controller の順に選択フライトの検証を含める。選択フライトの検証の失敗は、すべて `InvalidRequest` とする（`Business` の `e.ar.b2.2001` も。原典の `TicketReserveHelper.validateFlightList` が `BadRequestException` に包む）。`Spec.Reserve.FlightSelection.validateFlightList` 自身は、`Business` を返す（B1 の選択で使う） |
| 予約確定の [Spec] | `World` に対する関数 `Spec.Reserve.reserve`（標準の結果）。予約内容の組み立て、`validateReservation`、合計金額、予約フライトごとの空席の確保、採番と登録の順である。失敗したときは元の `World` を返す（標準の結果では、失敗の前に採番しない）。`Conflict`・I/O 失敗は、第 2 段の抽象機械の選択で与える |
| `validateReservation` の搭乗者の照合 | 原典は予約フライトごとに繰り返すが、どの予約フライトも同じ搭乗者列を持つ。そのため [Spec] は 1 回だけ照合する（結果は同じ） |
| 業務例外の引数 | `AtrsBusinessException.newArgs code args`。メッセージは、コードと引数（`toString` の値）を改行でつないだものとする。`SystemException`（`e.ar.a0.L9002`）も同じ表し方にする |
| エラーの分類 | `Spec.Error.AtrsError` に `invalidRequest (detail)`・`system (code args)`・`conflict (reason)` を足す |
| 写す範囲 | 予約確認・予約確定の流れが呼ぶものを写す。画面の表示・初期値だけが使う `TicketReserveHelper.createSelectFlightDtoList`・`createTicketReserveForm`・`createParameterMapForFlightSearch` と、`TicketReserveServiceImpl.findMember` は、HTTP の backlog（[a89e](../backlog/a89e-http-contract-adapter.md)）で写す |
| `InvalidFlightException` のメッセージ | 原典はフライトの `toString()` を連結するが、写しでは連結しない。詳細は自由な選択 N-004 で、α が捨てる |
| 言語意味論（スキル） | スキルに次を足す（スキルの版 0.21）。<br>- `LangSemantics.Java.JLocalTime`: `DateTimeFormatter.ofPattern("HHmm")` の SMART 解決（`2400` は 0:00、`2415` は例外）と、`LocalDateTime` の分の加算・比較。JVM の表で突き合わせる。<br>- `StringUtils.hasLength`・`hasText`<br>- `LangSemantics.Sql.Transaction.run`<br>- PostgreSQL の `TIMESTAMP`（`PgTimestamp`） |
| D-009 | 範囲を広げる（プロジェクトオーナーの確認待ち）。`RESERVE_FLIGHT_NO`・`PASSENGER_NO` は `INT` で、`selectKey` は `resultType="Integer"` なので、シーケンスの値が 2,147,483,647 を超えると読み出しが失敗する。前提を「会員番号・予約番号は最大値以下、予約フライト番号・搭乗者番号は INT の最大値以下」に改める |
| D-031 | R 課題の欄を ABS-031・ABS-041・ABS-045 に直す（選択フライトの検証は、画面の予約・REST の予約・HTTP の各機械に現れる。ABS-021 は採番で、誤りだった。確認待ち） |
| D-014 | 予約確定で Clock を読む箇所（Helper の予約日、予約フライトごとの `isAvailableFareType`）を説明に足す。述語 `dev_D014R` は第 2 段で置く。D-014 の必要性は、既存の W 課題 ABS-114（`need_D014`）で示されている |

### Consequences

* Good, because 空席照会の証明（ABS-011・ABS-114・ABS-132）は、α の定義域を限るだけで通り続ける
* Good, because 予約の [Spec] と [Source] の関数が、47 件の共有ベクタ（選択フライトの検証 10・予約内容の検証 16・予約確認 8・予約確定 13）で一致する。期待値は仕様の例と手計算から取った。原典の実行とも一致する
* Good, because 原典の取消（往路の空席数の更新を、復路の残席不足で取り消す）を、トランザクションの写しで再現する
* Bad, because 第 1 段の時点では、空席照会の α が予約の状態を写さない。予約を含む状態は、第 3 段まで α の定義域の外である
* Bad, because `FlightDb` の名前が、内容（全状態の表）と合わなくなる

### Confirmation

* `lake build`・`lake test` が通り、`shared/reservation` の 47 件を `Spec` と `SourceModel` の両方で実行して、すべて合格する。
* ABS-011・ABS-114・ABS-132 と、トップレベルの主定理が、`sorry`・公理なしで通る（axiom-check）。
* スキルの `assets/lean` の `lake build` が通り、JVM の表（`LocalTime`）と一致する。
* `shared/reservation` が Java の原典実行で一致する（`tools/ci/java_origin_run.sh domain`）。

## More Information

* 敵対的レビュー（第 1 段の完了前。独立したエージェント）の指摘と対応。高い重大度の指摘は無かった。
  * [Source] の会員の取得は、MEMBER・MEMBER_LOGIN・CREDIT_TYPE を結合する。ログインの行が無い会員は見つからない。[Spec] は `members` を引くだけである。→ 第 2 段で、`World` と状態の表の α の定義域（D-027 の範囲）に「どの会員にもログインの行があり、カード種別がマスタにある」を課す。α で除けない場合は差異として登録する。
  * 空でない搭乗者欄が無い入力で、[Spec] は搭乗者 0 名の予約を登録し、[Source] は `IllegalArgumentException` を投げる。→ `buildDraft` が搭乗者 0 名で無し（PRE）を返すようにした（入力検証の相関 `e.ar.b2.5002` が除く）。
  * 逆区間の検査で、[Source] の写しは 4 つの空港コードを先に参照外ししていた。原典は `||` で短絡し、`equals(null)` は偽を返す。→ 原典の評価順に直した（マスタの値では到達しない）。
  * グループ割の業務例外で、[Source] の写しは運賃種別名の `null` を参照外ししていた。原典は可変長引数に `null` を渡すだけである。→ `"null"` として渡すように直した。
  * 空席照会の α の定義域を限ったので、上流のシードを投入した状態は定義域の外になる。→ [assurance.md](../spec/assurance.md) に暫定の限界として載せた。第 3 段の終了条件とする。
  * 業務例外の引数は `toString` の値で比べる。原典は表示のときに `MessageFormat` で書式化するので、1000 以上の数は桁区切りが付きうる。→ 表示の書式は HTTP・メッセージの backlog（[a89e](../backlog/a89e-http-contract-adapter.md)）の範囲として申し送る（いまの引数はどれも 1000 未満）。
  * ベクタの不足 → 次のケースを足した（計 47 件）。
    * 選択フライトの検証が予約内容の検証より先
    * 予約可能期間の両端（ちょうど 7 日前・60 日前）と、61 日前の `e.ar.b2.2008`
    * グループ割の成功
    * 代表者の照合が搭乗者の照合より先
    * 詰めた後の位置での `e.ar.b2.2006`
    * 特別席・ピーク時期の合計金額
    * 特別往復運賃の往復での取消
  * D-031 の [Source] の例外のベクタは、W 課題 ABS-131 とともに第 3 段で置く。
  * 確かめて正しかったもの:
    * 評価順・`null` の経路・取消の範囲・採番が戻らないこと
    * `selectKey` と MyBatis の束縛
    * DDL の制約
    * MapStruct の入れ子の対象
    * `String.format` の `null`
    * `JLocalTime` の SMART 解決と負の通算分
    * `PgTimestamp` の範囲
    * ベクタの期待値（独立に再計算した）
* Java の原典実行: 共有ベクタ 47 件が原典と一致した。シードの範囲から予約確認の 76 件を採取した（`conformance/source-model/reservation/origin-run-confirm.json`。結果は成功 56 件、`e.ar.b2.2004` 11 件、`e.ar.b2.2010` 5 件、`e.ar.b2.2007` 4 件）。原典の取消が働くことは、トランザクションの包みを外すと `rs-rt-homeward-short` が失敗することで確かめた。
* [backlog aedf](../backlog/aedf-reservation-usecase.md)、[`Spec.Reserve`](../../lean/Spec/Reserve.lean)、[`Spec.Port`](../../lean/Spec/World.lean)、[`Spec.Http`](../../lean/Spec/Http.lean#b2-予約)
* [ADR ce36](ce36-flight-search-stage1-world-and-arrival-time.md)（`World` の導入）、[ADR cdb6](cdb6-flight-search-stage2-machines-seed-sql.md)（状態の表と D-027）、[ADR 0b0c](0b0c-flight-search-stage3-abs011.md)（確認待ちの登録の前例）、[ADR e56e](e56e-conflict-as-spec-nondeterminism.md)、[ADR 97f9](97f9-persistence-and-transaction-semantics.md)
* 補足: 上の表の D-009 の拡大と D-031 の R 課題の修正（確認待ち）は、[ADR f786](f786-gap-inventory-and-registry-fixes.md) でプロジェクトオーナーが承認した。
