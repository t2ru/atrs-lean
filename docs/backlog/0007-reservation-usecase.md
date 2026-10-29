---
type: Backlog Item
title: "予約（B0/B2）"
description: "validateFlightList・validateReservation・reserveConfirm・reserve を SourceModel と Spec で実装し、空席の不変条件を証明する。"
tags: [backlog, spec, source-model, reservation]
id: "0007"
state: todo
depends_on: ["0006", "0027", "0013", "0005", "0024"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T10:00:00+09:00
---

# 予約（B0/B2）

## 目的

状態変更とトランザクションを伴う中心機能を、移植元側（`SourceModel`・`Abstraction`）と `Spec` で実装する。

## 範囲

- `Spec.Ticket`, `Spec.UseCase.Reserve`, `Spec.Port`
- `SourceModel.UseCase.Reserve`, `SourceModel.Repository.Reservation`（`@[source]` 付き）
- R 課題: ABS-021（採番）、ABS-023（予約・空席照会のリポジトリ）、ABS-041（予約のユースケース。`Conflict` と I/O 失敗の非決定性を含む。[ADR 0037](../decision/0037-conflict-as-spec-nondeterminism.md)）
- W 課題: ABS-109（D-009）、ABS-114（D-014）
- L 課題: ABS-020、ABS-022
- SPEC 課題: 予約の SPEC-001〜SPEC-004
- ベクタ（成功・各エラー・往復で復路のみ失敗した場合のロールバック）

## 対象外

- 移植先側（`TargetModel`・`Refinement`・Rust。[backlog 0023](0023-target-model-usecases-and-refinement.md)）
- 並行実行の確認（SRC-005）

## 完了条件

- [ ] [reservation.md](../spec/reservation.md) の例がベクタで通る
- [ ] ABS-020・ABS-021・ABS-022・ABS-023・ABS-041・ABS-109・ABS-114 と、予約の SPEC-001〜SPEC-004 を証明した
- [ ] 予約の `source-model/` ベクタが Java オラクルと一致する
- [ ] リポジトリの SQL の写しを PostgreSQL での差分実行で照合した

## 参照

- [reservation.md](../spec/reservation.md)
- [ports.md](../spec/ports.md)
