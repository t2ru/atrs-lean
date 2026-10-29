---
type: Backlog Item
title: "予約（B0/B2）"
description: "validateFlightList・validateReservation・reserveConfirm・reserve を両モデルで実装し、空席の不変条件を証明する。"
tags: [backlog, spec, source-model, reservation]
id: "0007"
state: todo
depends_on: ["0006"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# 予約（B0/B2）

## 目的

状態変更とトランザクションを伴う中心機能を実装する。

## 範囲

- `Spec.Ticket`, `Spec.UseCase.Reserve`, `Spec.Port`
- `SourceModel.UseCase.Reserve`, `SourceModel.Repository.Reservation`
- ABS-020, ABS-021, ABS-022
- ベクタ（成功・各エラー・往復で復路のみ失敗した場合のロールバック）

## 対象外

- 並行実行の証明（REF-003 は TargetModel 側）

## 完了条件

- [ ] [reservation.md](../spec/reservation.md) の例がベクタで通る
- [ ] ABS-020 を証明した

## 参照

- [reservation.md](../spec/reservation.md)
- [ports.md](../spec/ports.md)
