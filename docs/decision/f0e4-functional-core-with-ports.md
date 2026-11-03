---
type: Architecture Decision Record
title: "業務ロジックを純粋関数のコアとし、副作用をポート経由にする"
description: "業務ロジックは純粋関数、時刻・永続化・採番・ハッシュ・ファイル・キューはポートとして抽象化する。"
tags: [adr, architecture, ports]
id: "f0e4889d-5cbf-4c3d-b194-d62a87d0ff45"
status: stable
decision_status: accepted
date: 2026-10-29
decision-makers: プロジェクトオーナー
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 業務ロジックを純粋関数のコアとし、副作用をポート経由にする

## Context and Problem Statement

原典のサービスは Spring の DI で `ClockFactory`、MyBatis の Repository、`PasswordEncoder`、JMS、ファイルシステムに直接依存している。
マスタは `*Provider` が起動時にキャッシュする。
これをそのまま写すと、仕様が特定のフレームワークや I/O の順序に依存し、証明も困難になる。

## Decision Drivers

* 仕様を言語中立に、かつ証明可能にすること
* 副作用の順序（空席更新 → 予約挿入 など）とトランザクション境界は仕様として残すこと
* 他言語実装が任意の永続化技術を選べること

## Considered Options

* 関数型コア + ポート（ヘキサゴナル）
* 原典どおりのサービス + リポジトリ構造を写す
* すべてを状態遷移関数 `State → Input → (State, Output)` で書く

## Decision Outcome

Chosen option: "関数型コア + ポート", because 計算部分は純粋関数として証明でき、状態変更を伴うユースケースもポートの契約を通じて言語中立に記述できるため。

* **純粋関数**: 運賃計算、空席照会結果の整形、予約検証、入力検証、CSV 行生成など。マスタ・設定値・今日の日付はすべて引数で受け取る。
* **ポート**（[spec/ports.md](../../lean/Spec/Port.lean)）: `Clock`, `FlightRepository`, `MemberRepository`, `ReservationRepository`, `IdGenerator`（会員番号・予約番号・予約フライト番号・搭乗者番号）, `PasswordHasher`, `ReportStore`, `ReportQueue`。
* **マスタ**（空港・路線・便マスタ・運賃種別・搭乗クラス・ピーク時期・カード種別）は不変の値 `MasterData` として純粋関数に渡す。
* **ユースケース** はポートを使う手続きとして定義し、トランザクション境界（全部成功か全部取消か）を明記する。
* Lean では、ポートを `Monad m` 上の関数レコード（`structure Ports (m : Type → Type)`）として `Spec` に置き、`Spec` のユースケースはインメモリの抽象状態 `StateT World (Except AtrsError)` 上で意味を与える。実際のアダプタ（インメモリ・HTTP・永続化）は移植先モデル `TargetModel` に置く（[ADR 0bd3](0bd3-generate-verus-mirror-from-target-model.md)）。

### Consequences

* Good, because 計算の大半が純粋関数となり、テストベクタと証明が書きやすい
* Good, because 他言語はポートを自由に実装できる（RDB、KVS、メモリ）
* Bad, because 原典の `@Transactional` と DB ロック（`FOR UPDATE`）の効果をポート契約として明文化する手間がかかる（[ADR 97f9](97f9-persistence-and-transaction-semantics.md)）

### Confirmation

* `Spec` に `IO` が現れないことを確認する。
* 各ユースケースの仕様に、使用するポート操作とトランザクション境界が書かれていることをレビューで確認する。

## Pros and Cons of the Options

### 関数型コア + ポート

* Good, because 純粋部分の証明が容易、I/O は差し替え可能
* Bad, because 原典の構造と 1 対 1 に対応しない部分がある

### 原典の構造を写す

* Good, because 対応関係が自明
* Bad, because DI・例外・トランザクションのフレームワーク意味論を仕様に持ち込む

### 単一の状態遷移関数

* Good, because 最も形式的
* Bad, because 他言語移植者にとって読みにくく、永続化技術の選択を縛る

## More Information

* [spec/ports.md](../../lean/Spec/Port.lean), [ADR 97f9](97f9-persistence-and-transaction-semantics.md)
