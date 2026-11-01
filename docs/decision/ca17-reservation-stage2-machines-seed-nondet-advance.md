---
type: Architecture Decision Record
title: "予約の第 2 段: 抽象機械 reserveMachine と SPEC 課題、具体機械 reserveConcrete、会員のシード、失敗時の採番の前進"
description: "backlog aedf の第 2 段の設計を決める。予約確認と予約確定を 1 つの抽象機械（選択の像。N-001・N-002・N-004）にし、Conflict は予約確定だけが返す。Conflict・I/O 失敗の選択に、失敗するまでに進んだ採番の数を持たせる（確認待ち）。具体機械は業務例外・不正要求・I/O 失敗・排他の失敗を出力の値とする。会員のシードを生成器で展開し、ログイン日時を投入日とみなす。空席照会の状態の型の変更と全表の α は第 3 段に回す。"
tags: [adr, spec, source-model, reservation, nondet, machine]
id: "ca173162-e613-422b-a0f5-6c353788d60b"
status: stable
decision_status: accepted
date: 2026-11-01
decision-makers: プロジェクトオーナー（3 段の進め方と、確認待ちで登録して続けること）
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-11-02T01:00:00+09:00
---

# 予約の第 2 段: 抽象機械 reserveMachine と SPEC 課題、具体機械 reserveConcrete、会員のシード、失敗時の採番の前進

## Context and Problem Statement

[ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md) で、[backlog aedf](../backlog/aedf-reservation-usecase.md) を 3 段に分けた。第 1 段では、予約の関数・共有ベクタ・原典実行を置いた。第 2 段では、機械と初期状態を置く。

その前に、次のことを決める必要があった。

1. 予約確認と予約確定を、1 つの機械にするか、2 つの機械にするか。
2. `Conflict`・I/O 失敗のとき、[Spec] の状態がどう変わるか。
   - [ports.md](../spec/ports.md#idgenerator) と [ADR e56e](e56e-conflict-as-spec-nondeterminism.md) は、「採番以外の状態は変わらない」「採番は失敗したトランザクションでも巻き戻らない」と定める。
   - [Source] では、失敗するまでに `nextval` が呼ばれた回数だけ採番が進む。
   - ところが Lean の選択の型 `ConflictChoice`・`IoFailureChoice` は `none | conflict` で、進んだ数を表せなかった。
3. 具体機械で、どの例外を出力の値にするか。
4. 会員のシードの `LOGIN_DATE_TIME` は `localtimestamp`（投入の時刻）である。初期状態の値をどう決めるか。
5. 空席照会の状態の型の変更（全表の `World`・`FlightDb` と初期状態）を、いつ行うか。

## Decision Drivers

* [ADR e56e](e56e-conflict-as-spec-nondeterminism.md): 状態を変える操作だけが `Conflict` を返す。採番以外は変えない。標準の選択は失敗を選ばない。
* 選択の像の義務（`Pinned`・`NoFaultReachable`・`FreeFrame`）を、第 3 段で示せる形にする。
* 空虚な PRE を避け、PRE の内容を定義で表す（[ADR 70eb](70eb-refinement-non-vacuity-obligations.md)）。

## Considered Options

* 機械: (a) 1 つの `ofChoice`（入力に操作の種類を持つ）、(b) 予約確認と予約確定を別の機械にし、`alt` で並置する
* 採番の前進: (a) N-001・N-002 の選択の型に、進んだ数 `SeqAdvance` を持たせる、(b) 採番を自由な選択（未使用の任意の値）にし、`J` を不等式にする

## Decision Outcome

Chosen option: "機械 (a)・採番の前進 (a)"。理由は次のとおりである。

* (a) なら、課題 ABS-041（予約確定・予約確認）の 1 つの R 課題の形と一致する。
* 採番の前進 (a) は、ports.md・ADR e56e の文言（採番以外は変えない）をそのまま Lean で表す。(b) は新しい非決定性を足し、採番の値の対応を弱める。

採番の前進の選択の型の変更は、非決定性の登録簿の変更なので、プロジェクトオーナーの確認待ちとする（ADR 4c45 の方針）。

### 決定

| 項目 | 決定 |
| --- | --- |
| 抽象機械 | `Spec.UseCase.Reserve.reserveMachine := Machine.ofChoice World.Inv (· = Spec.Seed.World.world) MInput.Pre reserveStep (std, std) InvalidRequestDetail.std`。<br>- 入力 `MInput` は、設定・マスタ・今日・要求・操作の種類（`confirm`・`reserve`）。<br>- 出力は `Except AtrsError MOutputValue`（`confirmed totalFare`・`reserved result`）。<br>- 選択の型は `(ConflictChoice × IoFailureChoice) × InvalidRequestDetail` |
| 1 歩 `reserveStep` | 次の順に選ぶ。<br>- I/O 失敗: `System("e.ar.fw.9999")`、採番だけ進む。<br>- `Conflict`: 予約確定だけ。`Conflict`、採番だけ進む。予約確認は状態を変えないので `Conflict` を返さない（ADR e56e）。<br>- それ以外: 標準の結果 `baseStep` の `InvalidRequest` の詳細を、自由な選択 N-004 で置き換える |
| PRE | 設定とマスタが妥当で、操作の標準の結果が定まる（`confirmOp`・`reserveOp` が `some`）。<br>`buildDraft` は空でない搭乗者欄が無ければ無し（ADR 4c45 のレビューの指摘）なので、PRE は搭乗者が 1 名以上であることを含む |
| INV | `World.Inv`（フライトの主キーの一意性）のまま。予約の主キー・使用済みの番号は、第 3 段の [Source] の具体側の不変条件（`Glue.ofStd` の `Ic`）で扱う |
| SPEC 課題 | すべて `sorry` なしで証明した。<br>- SPEC-001: `reserveMachine_run_step`<br>- SPEC-002・003: `reserveMachine_sound`。空席の確保は主キーを変えず、登録と採番はフライトを変えない<br>- SPEC-004: `reserveStep_failure`・`reserveStep_conflict`・`advance_frame`<br>- SPEC-007: `reserveMachine_initIs`<br>- SPEC-008: `reserveStep_std`。標準の環境では、標準の結果のどのエラーも業務例外か不正要求で、`Conflict`・`System("e.ar.fw.9999")` でない（`AllNE` の補題の連鎖） |
| N-001・N-002 の型 | `ConflictChoice.conflict (adv : SeqAdvance := {})`・`IoFailureChoice.failure (adv : SeqAdvance := {})`。`SeqAdvance` は、会員・予約・予約フライト・搭乗者の採番の進んだ数（プロジェクトオーナーの確認待ち） |
| 具体機械 | `SourceModel.ReserveQuery.reserveConcrete`。<br>- 状態は `FlightDb`、初期状態は `SourceModel.Db.Seed.seedDb`。<br>- 1 歩は、許される並び `mo` のどれかで読み込んで操作を実行する（`runOp`）。<br>- 出力の値とするもの（`catchReserve`）: 業務例外（コードと引数）・`BadRequestException`・I/O の失敗（`DataAccessResourceFailureException`）・排他の失敗（`PessimisticLockingFailureException`）。<br>- 正常でない結果とするもの: 前提違反・制約違反・`SystemException`（`e.ar.a0.L9002`）・`MyBatisSystemException`（D-009）などの他の例外。<br>- 定義域: 予約確認では排他の失敗を起こさない（予約確認の文は行ロックを取らない） |
| 会員のシード | 生成器 `tools/conformance/member_seed.py` が、00230 から `Spec.Seed.Member`（会員の列・採番の初期値。会員は 8、ほかは 1）と `SourceModel.Db.MemberSeed`（MEMBER・MEMBER_LOGIN の行・`sq_member_1` = 7）を書き出す。<br>`LOGIN_DATE_TIME`（`localtimestamp`）は、投入日（fixture の `loadDate`）の 0:00 とみなす。<br>初期状態は `Spec.Seed.World.world`・`SourceModel.Db.Seed.seedDb` |
| 予約の SQL の差分実行 | `exists`・`findOneForUpdate`・`update`・`MemberRepository.findOne`・3 つの insert（`selectKey`）とシードの会員の表を、PostgreSQL の実行結果と照合する（`conformance/sql/reservation.json`・`Tests.ReservationSql`、検査 `pg-reservation-sql`） |
| 第 3 段に回すもの | 空席照会の状態と初期状態を全表の `World`・`FlightDb` に広げること（全表の α と一体のため）、D-014 の述語 `dev_D014R`、R 課題の証明 |

### Consequences

* Good, because 予約の抽象機械が、ADR e56e の非決定性（失敗時の採番の前進を含む）をそのまま表す
* Good, because SPEC 課題（予約の SPEC-001〜004・007・008）が第 2 段で閉じる
* Bad, because N-001・N-002 の Lean の型が変わる（使う機械は予約だけで、ほかへの影響は無い）
* Bad, because 投入日の 0:00 というログイン日時は、実際の投入の時刻と違う（ログイン日時を読む操作は 44f8 の範囲。予約は読まない）

### Confirmation

* `lake build`・`lake test` が通り、axiom-check が OK である。
* 予約の SPEC 課題に `sorry` が無い。
* `member_seed.py --check` が通る。
* 予約の SQL の差分実行（`pg-reservation-sql`）が通る。

## More Information

* 予約の SQL の差分実行（75 件とシードの会員の表）で、[Source] の写しの制約の検査の順が PostgreSQL と 4 件で違った。違いは次の 2 つである。
  * PostgreSQL は、主キーの一意性を索引への挿入で検査し、外部キーは文の終わりの AFTER ROW トリガで検査する。そのため、主キーと外部キーの両方に反すると、主キーの違反になる。
  * PostgreSQL は、`VALUES` のすべての値を列の型に変換（`VARCHAR(n)` の長さの検査を含む）してから、NOT NULL を検査する。

  → `ReservationRepository` の 3 つの挿入を、型変換・NOT NULL・主キー・外部キーの順に直し、4 件とも一致した。

* [ADR 4c45](4c45-reservation-stage1-shared-state-and-source-model.md)、[ADR e56e](e56e-conflict-as-spec-nondeterminism.md)、[ADR 70eb](70eb-refinement-non-vacuity-obligations.md)、[スキルの ADR a303](../../.agents/skills/spec-pivot/references/docs/decision/a303-shared-state-machine-alt-and-transaction.md)
