---
type: Backlog Item
title: "予約（B0/B2）"
description: "validateFlightList・validateReservation・reserveConfirm・reserve を SourceModel と Spec で実装し、空席の不変条件を証明する。"
tags: [backlog, spec, source-model, reservation]
id: "aedfeffc-3e82-46b1-b497-3d8b7808d068"
state: todo
depends_on: ["0be7c5d4-01d9-43f4-a50d-227f174830f0", "1ae40815-ac5a-4602-99bc-1d9ad267dd0b", "f18c3c0f-4007-42c1-ba25-102fb385a16c", "bbcce088-c475-4378-9cc6-e3d821acc0f5", "ffdc480d-eaf2-42a0-9818-0b128e9403d4"]
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
- R 課題: ABS-021（採番）、ABS-023（予約・空席照会のリポジトリ）、ABS-041（予約のユースケース。`Conflict` と I/O 失敗の非決定性を含む。[ADR e56e](../decision/e56e-conflict-as-spec-nondeterminism.md)）
- W 課題: ABS-109（D-009）、ABS-114（D-014）
- L 課題: ABS-020、ABS-022
- SPEC 課題: 予約の SPEC-001〜SPEC-004
- ベクタ（成功・各エラー・往復で復路のみ失敗した場合のロールバック）

## 対象外

- 移植先側（`TargetModel`・`Refinement`・Rust。[backlog 26c5](26c5-target-model-usecases-and-refinement.md)）
- 並行実行の確認（SRC-005）

## 完了条件

- [ ] [reservation.md](../spec/reservation.md) の例がベクタで通る
- [ ] ABS-020・ABS-021・ABS-022・ABS-023・ABS-041・ABS-109・ABS-114 と、予約の SPEC-001〜SPEC-004 を証明した
- [ ] 予約の `source-model/` ベクタが Java の原典実行と一致する
- [ ] リポジトリの SQL の写しを PostgreSQL での差分実行で照合した

## 参照

- [reservation.md](../spec/reservation.md)
- [ports.md](../spec/ports.md)
