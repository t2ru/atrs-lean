---
type: Architecture Decision Record
title: "永続化をリポジトリ契約として仕様化し、ユースケース単位の原子性を要求する"
description: "SQL に埋め込まれた業務ロジック・採番・行ロック・トランザクション境界を、技術非依存のリポジトリ契約として定義する。"
tags: [adr, persistence, transaction]
id: "97f9f4bc-43d3-4ec9-863f-e070387d0739"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
sources:
  - id: flight-repo
    resource: https://github.com/terasolunaorg/atrs/blob/f4bfbf0615eb91805546c9c780d4761be92ce17e/JavaConfig-Thymeleaf/atrs/atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/flight/FlightRepository.xml
    title: FlightRepository.xml
---

# 永続化をリポジトリ契約として仕様化し、ユースケース単位の原子性を要求する

## Context and Problem Statement

原典は PostgreSQL + MyBatis を使い、業務ロジックの一部を SQL に持つ。

* 空席照会: `beforeDayNum BETWEEN rsrv_available_end_day_num AND rsrv_available_start_day_num`、`ORDER BY fare_type.display_order, flight_master.departure_time`[^flight-repo]
* 予約: `SELECT … FOR UPDATE` で便の空席行をロックし、空席数を減算して更新
* 採番: `TO_CHAR(NEXTVAL('sq_member_1'), 'FM0999999999')`（10 桁ゼロ埋め）、シーケンスは `MAXVALUE 9999999999 CYCLE`
* パスワード変更: `UPDATE member_login SET last_password = password, password = :new`
* `@Transactional` によるサービスメソッド単位のコミット/ロールバック

## Decision Drivers

* 永続化技術に依存しないこと
* 予約の同時実行時に空席数が負にならないこと（原典の保証）を仕様として残すこと
* SQL 内の業務ロジックを漏らさないこと

## Considered Options

* リポジトリ契約（操作ごとの事前・事後条件）+ ユースケース単位の原子性・直列化可能性
* SQL（PostgreSQL 方言）をそのまま仕様にする
* 永続化を仕様から外し、インメモリの状態のみ定義する

## Decision Outcome

Chosen option: "リポジトリ契約 + ユースケース単位の原子性", because SQL 内の業務ロジックを純粋関数として取り出しつつ、同時実行の保証を技術非依存に表現できるため。

* SQL の絞り込み・並び順は純粋関数として [spec/flight-search.md](../spec/flight-search.md) 等に定義し、リポジトリは「全件を返す」または「キー検索」の単純な契約にする（実装は SQL に押し下げてよい）。
* 状態を変更するユースケース（予約登録・会員登録・会員更新・ログイン/ログアウト状態更新）は **原子的**（全て反映されるか全く反映されない）かつ **直列化可能** でなければならない。原典の `FOR UPDATE` はこの保証の一実装である。
* 採番は `IdGenerator` ポートとし、生成値の書式（10 桁ゼロ埋め十進）と一意性を契約にする。循環（CYCLE）後の重複は原典では主キー違反によるシステムエラーとなる。[Spec] では「採番空間を使い切らない」ことを前提とし、[Source] では循環を再現する。
* 原典の「更新件数が期待と異なれば `SystemException`（`e.ar.a0.L9002`）」は、[Spec] ではリポジトリ契約（キーが存在すれば必ず 1 件更新）により到達不能とし、[Source] ではシステムエラーとして残す。
* 契約の詳細は [spec/ports.md](../spec/ports.md)。
* [Source] では原典の SQL 文そのものを `LangSemantics.Sql` 上の式として写し（[ADR 5fcb](5fcb-sql-semantics-for-source-repositories.md)）、[Spec] の純粋関数との一致を `Abstraction` で証明する。

### Consequences

* Good, because 他言語実装が RDB 以外も選べる
* Good, because インメモリの抽象状態上で予約の不変条件（空席数 ≥ 0）を証明できる
* Bad, because 原典の SQL との対応を [traceability.md](../spec/traceability.md) で別途管理する必要がある

### Confirmation

* インメモリアダプタ上で「予約ユースケースの実行前後で空席数が負にならない」「失敗時に状態が変わらない」を Lean で証明する（[spec/abstraction.md](../spec/abstraction.md)）。

## Pros and Cons of the Options

### リポジトリ契約

* Good, because 技術非依存、証明可能
* Bad, because 契約の記述量が増える

### SQL をそのまま仕様に

* Good, because 原典と同一
* Bad, because RDB と PostgreSQL 方言への依存を強いる

### 永続化を仕様から外す

* Good, because 単純
* Bad, because 同時実行・原子性の要件が失われる

## More Information

* [spec/ports.md](../spec/ports.md), [ADR f0e4](f0e4-functional-core-with-ports.md)
* 後続: [ADR 578b](578b-member-update-in-single-transaction.md)（会員情報変更の照合と更新を 1 トランザクションにし、原子性の対象にレポート生成を含める。一覧は [spec/ports.md](../spec/ports.md#トランザクション) を正とする）

[^flight-repo]: atrs-domain/src/main/resources/jp/co/ntt/atrs/domain/repository/flight/FlightRepository.xml `findByVacantSeatSearchCriteria`, `findOneForUpdate`
* （補足 2026-10-30・訂正）Decision Outcome の「原典の `FOR UPDATE` はこの保証の一実装である」は不正確である。原典は PostgreSQL の既定の分離レベル READ COMMITTED で動き、`FOR UPDATE` は予約での空席行の競合だけを防ぐ。会員情報変更などでは直列化可能でない（既知差異 D-013、モデル外の差異 D-025。[spec/abstraction.md](../spec/abstraction.md#既知差異)）。並行実行とモデルとの一致は [spec/assurance.md](../spec/assurance.md) に限界として扱う。`Conflict` の扱いは [ADR e56e](e56e-conflict-as-spec-nondeterminism.md)。
