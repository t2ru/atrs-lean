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
  at: 2026-10-30T10:00:00+09:00
---

# ポート

> **区分: 草案と規範の混在。** 各ポートの操作と契約の表（「World」〜「ReportQueue」の表）は **形式化前の草案（draft）** であり、Lean `Spec.Port` に形式化する。次の 4 か所は、`Spec` の関数として表現できない実行環境への要件なので **規範（normative）** としてここで定義する（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）: 「Clock」節の規範段落（タイムゾーン）、「ReportStore」の `publish` の原子性のうちプロセスの異常終了に対するもの、「ReportQueue」節の規範段落のうちプロセスの異常終了をまたぐ配信保証、「トランザクション」節の並行実行の要件。採番の一意性・巻き戻らないこと、`publish` の論理的な原子性、再配信の上限の非決定性は `Spec` で表せるので、草案として `Spec.Port` に形式化する。

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

[Spec] の各ユースケースは、初めに 1 回だけ `today()` を読み、その値を使う。[Source] は呼ぶたびに読むので、日付をまたぐ実行で異なりうる（既知差異 [D-014](abstraction.md#既知差異)）。

**規範（実行環境の要件）**: 本番の `Clock` アダプタは、現在時刻を **Asia/Tokyo**（UTC+9、夏時間なし）の暦日・時刻として返す。実行環境の既定のタイムゾーンに依存してはならない（[ADR 0028](../decision/0028-clock-timezone-and-fixture-base-date.md)）。テストでは任意の固定値を注入してよい。

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

- [Spec]: 各操作は呼ぶたびに **未使用** の値を返す（`n`, `n+1`, … と単調増加する実装を参照とする。値の空間は上限を持たない）。
- [Source]: 最大値の次は 1 に戻る。戻った値が使用済みなら、挿入時の主キー違反でシステムエラー（既知差異 [D-009](abstraction.md#既知差異)）。
- 採番は失敗したトランザクションでも巻き戻らない（[Spec=Source]。シーケンスの性質）。そのため、各ユースケースの「失敗時は状態が変化しない」は `World.sequences` を除いた成分についての性質である。
- 適合テストでは、fixture にシード投入後の各シーケンスの次の値（原典では会員 `8`、予約・予約フライト・搭乗者 `1`。`00230_insert_member.sql` は `nextval('sq_member_1')` を 7 回呼ぶ）を持たせ、参照実装（`n`, `n+1`, …）で採番した番号を厳密に比較する（[conformance.md](conformance.md#共有入力fixtures)）。

## PasswordHasher

[ADR 0015](../decision/0015-password-hashing-port.md)。

| 操作 | 契約 |
| --- | --- |
| `hash(raw)` | PasswordHash（非決定的でよい） |
| `matches(raw, hash)` | `matches(raw, hash(raw)) = true`。異なる `raw` では偽 |

この契約は理想化である。リファインメント定理はこの契約を仮定に置かず、各モデルのポート実装が契約を満たすことを証明する（ABS-024・REF-008）。
- 参照実装（インメモリ）と各モデルの写し（raw について単射な符号化）は、この契約を厳密に満たす。
- 実際のハッシュ関数（原典の PBKDF2 など。[ADR 0015](../decision/0015-password-hashing-port.md)）は、衝突の確率が無視できる程度にしか満たさない。モデルとの違いは保証の限界とする（[assurance.md](assurance.md)）。

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
| 受信 | 1 件ずつ取り出し `onReportRequested`（[reservation-history-report.md](reservation-history-report.md)）に渡す。同時に処理するのは 1 件 |

**規範（配信保証。[ADR 0031](../decision/0031-report-queue-at-least-once-delivery.md)）**

- 少なくとも 1 回配信する。`onReportRequested` が失敗した要求は再配信する。
- 再配信の回数には上限を設ける。上限は 1 以上の値で、実装（配備の設定）が選ぶ。[Spec] はどの値も許す（抽象側の非決定性）。上限を超えた要求は破棄してログに残す。参考値は 10 回（原典が組み込みで使う ActiveMQ Artemis の既定 `maxDeliveryAttempts = 10`。デッドレターの宛先は設定されておらず、超えた要求は破棄される）。
- 同じ要求が重複して配信されてもよい。配信の順序は保証しない。

## トランザクション

**[Spec]** 状態を変更するユースケース（予約確定・会員登録・会員情報変更・ログイン/ログアウト状態更新・レポート生成）は、それぞれ原子的かつ直列化可能に実行されなければならない。この一覧を正とする（[ADR 0011](../decision/0011-persistence-and-transaction-semantics.md) の一覧にレポート生成を加えたもの。[ADR 0030](../decision/0030-member-update-in-single-transaction.md)）。
会員情報変更は、現在パスワードの照合（[member.md](member.md#現在パスワードの照合checkmemberpassword)）も同じトランザクションに含む（[Source] とは異なる。モデル外の既知差異 [D-013](abstraction.md#既知差異)）。
移植先は、この性質を満たす限り任意の実装（RDB のトランザクション、単一スレッド、楽観ロック等）を選んでよい。
- 各モデル（`Spec`・`SourceModel`・`TargetModel`）では、各ユースケースを抽象機械の 1 つの操作として原子的に扱う。
- 実際の並行実行がどれかの逐次実行と一致することは、モデルの外の要件である。確認は確認課題 SRC-005（[refinement.md](refinement.md)）の決定論的な手段で行い、確かめきれない部分は保証の限界とする（[assurance.md](assurance.md)）。
- [Source] は PostgreSQL の既定の分離レベル READ COMMITTED で動き、この要件を一般には満たさない（モデル外の既知差異 [D-025](abstraction.md#既知差異)）。

状態を変更するユースケースの [Spec] は、通常の結果に加えて、次の非決定的な結果を許す（[ADR 0037](../decision/0037-conflict-as-spec-nondeterminism.md)、[errors-and-messages.md](errors-and-messages.md#分類atrserror)）。
- 出力は `Conflict`。
- `World.sequences` を除く状態は変わらない。

実装は、デッドロック・ロック待ちのタイムアウト・直列化失敗・楽観ロックの衝突を、再試行などで吸収できない場合に、この結果を選ぶ。実行可能な [Spec] の標準の選択は `Conflict` を選ばない。

同様に、ポートの I/O の失敗も、ポートの操作の非決定的な結果である。失敗しうる操作は、`FlightRepository`・`MemberRepository`・`ReservationRepository`・`IdGenerator` の全操作と、`ReportStore`・`ReportQueue` の全操作である。`Clock` と `PasswordHasher` は失敗しない。このとき、そのユースケースは次のようになる（[ADR 0037](../decision/0037-conflict-as-spec-nondeterminism.md#実行環境の失敗)）。
- 出力は `System("e.ar.fw.9999")`（I/O 失敗のコードは、この 1 つだけとする。他のコードの `System` は非決定的な結果に含まれない）。
- `World.sequences` を除く状態は変わらない。
- 標準の選択は、この結果を選ばない。

常に失敗を返す実装もリファインメントになる。活性は [assurance.md](assurance.md) の限界とする。
