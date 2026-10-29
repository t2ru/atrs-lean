---
type: Specification
title: "ポート"
description: "副作用（時刻・永続化・採番・パスワード・レポート保存・キュー）の契約。Spec はこれらの契約だけに依存し、実装は TargetModel が提供する。"
tags: [spec, ports]
status: draft
spec_role: [draft, normative]
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# ポート

> **区分: 草案と規範の混在。** 各ポートの操作と契約（「World」〜「ReportQueue」）は **形式化前の草案（draft）** であり、Lean `Spec.Port` に形式化する。「トランザクション」節と、採番・ファイル公開・キュー配信など実行環境に課す要件は、`Spec` の関数として表現できないため **規範（normative）** としてここで定義する（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

方針は [ADR 0007](../decision/0007-functional-core-with-ports.md)、永続化とトランザクションは [ADR 0011](../decision/0011-persistence-and-transaction-semantics.md)。
[Spec] ではポートの操作を「抽象状態 `World` に対する関数」として意味づける。[Source] では原典の SQL 文を `LangSemantics.Sql` 上の式として写す（[ADR 0019](../decision/0019-sql-semantics-for-source-repositories.md)）。

## World（抽象状態）

| 成分 | 型 |
| --- | --- |
| `flights` | フライトの集合（主キーで一意） |
| `members` | 会員の集合（会員番号で一意） |
| `reservations` | 予約の集合（予約番号で一意。予約フライト・搭乗者を含む） |
| `sequences` | 採番の状態（会員・予約・予約フライト・搭乗者） |
| `reports` | 会員番号 ↦ （ファイル名 ↦ バイト列） |
| `queue` | レポート要求メッセージの列 |

マスタ（[master-data.md](master-data.md)）は `World` に含めず、不変の入力とする。

## Clock

| 操作 | 結果 |
| --- | --- |
| `today()` | Date |
| `now()` | DateTime（秒まで） |

同じユースケース内で `today()` を複数回呼んでも同じ日付を返す（[Spec] の前提。[Source] では日付をまたぐ実行で異なりうる）。

## FlightRepository

| 操作 | 契約 |
| --- | --- |
| `findAll()` | 全フライト。絞り込み・整列は呼び出し側の純粋関数（[flight-search.md](flight-search.md)）で行う。実装は条件を押し下げてよいが、結果は同一でなければならない |
| `exists(key)` | 主キーのフライトがあるか |
| `findForUpdate(key)` | 主キーのフライト。トランザクション終了まで他のトランザクションの同じキーへの `findForUpdate`・更新を待たせる |
| `updateVacantNum(key, n)` | 空席数を `n` にする。キーが存在しなければならない |

## MemberRepository

| 操作 | 契約 |
| --- | --- |
| `find(membershipNumber)` | 会員（ログイン情報を含む）または無し |
| `insert(member)` | 会員番号が未使用でなければならない |
| `update(member)` | 基本情報（氏名・生年月日・性別・電話・郵便番号・住所・メール・カード情報）を置き換える |
| `updatePassword(membershipNumber, newHash)` | `lastPassword := password`, `password := newHash` |
| `updateLoginStatus(membershipNumber, date, flg)` | `loginDateTime := date`, `loginFlg := flg` |
| `updateLogoutStatus(membershipNumber)` | `loginFlg := false` |

## ReservationRepository

| 操作 | 契約 |
| --- | --- |
| `insert(reservation)` | 予約・予約フライト・搭乗者を登録する |
| `existsReserveNo(reserveNo)` | 予約があるか（REST `GET /api/v1/ticket/check`） |
| `findHistoryByRepresentative(membershipNumber)` | `repMembershipNumber = membershipNumber` の予約の予約フライトごとの行 `{reserveNo, reserveDate, totalFare, reserveFlightNo, departureDate, flightName}`。並び `(reserveNo, reserveFlightNo)` 昇順 |

## IdGenerator

| 操作 | 書式 | 原典 |
| --- | --- | --- |
| `nextMembershipNumber()` | 10 桁ゼロ埋め十進文字列 | `sq_member_1`（1〜9999999999, CYCLE） |
| `nextReserveNo()` | 10 桁ゼロ埋め十進文字列 | `sq_reservation_1`（1〜9999999999, CYCLE） |
| `nextReserveFlightNo()` | Nat | `sq_reserve_flight_1`（1〜999999999999, CYCLE） |
| `nextPassengerNo()` | Nat | `sq_passenger_1`（1〜9999999999999, CYCLE） |

- [Spec]: 各操作は呼ぶたびに **未使用** の値を返す（`n`, `n+1`, … と単調増加する実装を参照とする）。採番空間を使い切らないことを前提とする。
- [Source]: 最大値の次は 1 に戻る。戻った値が使用済みなら、挿入時の主キー違反でシステムエラー。
- 採番は失敗したトランザクションでも巻き戻らない（[Spec=Source]。シーケンスの性質）。

## PasswordHasher

[ADR 0015](../decision/0015-password-hashing-port.md)。

| 操作 | 契約 |
| --- | --- |
| `hash(raw)` | PasswordHash（非決定的でよい） |
| `matches(raw, hash)` | `matches(raw, hash(raw)) = true`。異なる `raw` では偽（参照実装） |

## ReportStore

| 操作 | 契約 |
| --- | --- |
| `writeTemp(name, bytes)` | 一時領域に書く |
| `publish(membershipNumber, name)` | 一時領域の `"tmp_" ++ name` を会員の領域の `name` へ原子的に移す。同名が既にあれば失敗 |
| `list(membershipNumber)` | 会員の領域のファイル名の集合（順序は呼び出し側で決める） |
| `read(membershipNumber, name)` | バイト列または無し |

## ReportQueue

| 操作 | 契約 |
| --- | --- |
| `send(membershipNumber)` | 要求を末尾に追加する。呼び出し側のトランザクションとは独立 |
| 受信 | 先頭から 1 件ずつ取り出し `onReportRequested`（[reservation-history-report.md](reservation-history-report.md)）に渡す。同時に処理するのは 1 件 |

## トランザクション

**[Spec]** 状態を変更するユースケース（予約確定・会員登録・会員情報変更・ログイン/ログアウト状態更新・レポート生成）は、それぞれ原子的かつ直列化可能に実行されなければならない。
`TargetModel` は、この性質を満たす限り任意の実装（RDB のトランザクション、単一スレッド、楽観ロック等）を選んでよい（課題 [REF-003](refinement.md#証明課題)）。
