---
type: Backlog Item
title: "Spec: ドメイン型・基本演算・マスタデータ"
description: "Spec.Prim（floorDiv・暦日・書式・文字クラス）、エンティティ型、MasterData と不変条件、参照関数を実装する。"
tags: [backlog, spec, domain-model]
id: "0003"
state: todo
depends_on: ["0001"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T21:38:09+09:00
---

# Spec: ドメイン型・基本演算・マスタデータ

## 目的

すべての機能の [Spec] が依存する土台を作る。

## 範囲

- `Spec.Prim`: `floorDiv`, `ceilDiv`, `ceilTo`, `Date`（epochDay, addDays, daysBetween, fullYearsBetween）, `HourMinute`, 書式（`fmtDate`, `fmtTime`, `fmtYen`, `fmtTimestamp`）, 文字クラス
- `Spec.Model`: 列挙・エンティティ・値域
- `Spec.MasterData`: 型、不変条件 MD-1〜MD-8、参照関数
- `Spec.Config`

## 対象外

- ユースケース

## 完了条件

- [ ] マスタデータと共通の部分について、SPEC-001〜SPEC-003（[abstraction.md](../spec/abstraction.md#spec-自身の証明課題spec-nnn)）を証明した
- [ ] 日付演算の境界（閏年・月末・年越し）の性質を証明またはテストした
- [ ] `conformance/shared/format/` のベクタを作り全件通した

## 参照

- [domain-model.md](../spec/domain-model.md)
- [master-data.md](../spec/master-data.md)
- [configuration.md](../spec/configuration.md)
- [ADR 0009](../decision/0009-date-and-time-model.md)
