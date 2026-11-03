---
type: Backlog Item
title: "Spec: ドメイン型・基本演算・マスタデータ"
description: "Spec.Prim（floorDiv・暦日・書式・文字クラス）、エンティティ型、MasterData と不変条件、参照関数を実装する。"
tags: [backlog, spec, domain-model]
id: "591d9aa4-065b-4975-8146-86aae05b780a"
state: done
depends_on: ["be4969d4-478c-47a9-8fd9-b8cf31202bc8"]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-30T08:12:23+09:00
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

- [x] マスタデータと共通の部分について、SPEC-001〜SPEC-003（[abstraction.md](../spec/abstraction.md#spec-自身の証明課題spec-nnn)）を証明した
- [x] 日付演算の境界（閏年・月末・年越し）の性質を証明またはテストした
- [x] `conformance/shared/format/` のベクタを作り全件通した

## 結果

- `lean/Spec/`
  - `Prim/Int.lean`: `floorDiv`・`ceilDiv`・`ceilTo`・`pct` と特徴付けの補題
  - `Prim/Date.lean`: 暦日 `Date`、`ordinal`・`epochDay`・`ofEpochDay?`・`addDays`・`daysBetween`・`fullYearsBetween`・`dayOfWeek`
  - `Prim/Time.lean`: `HourMinute`・`parseHHmm`・`DateTime`
  - `Prim/Format.lean`: 書式
  - `Prim/Text.lean`: `scalarLen` と文字クラス
  - `Model.lean`: 列挙・コード値・エンティティ・値域
  - `Config.lean`: 設定
  - `MasterData.lean`: マスタ、MD-1〜MD-8、参照関数
  - `CodeList.lean`: コードリスト
- SPEC 課題: 参照関数をまとめた状態を持たない抽象機械 `Spec.MasterQuery.queryMachine` について、SPEC-001（`queryMachine_run_step`）と SPEC-002・SPEC-003（`queryMachine_sound`）を証明した。MD の下で参照関数の結果が並びに依存しないこと（`routeOf_eq_some_iff` など）も証明した。backlog 25f7 の ABS-026 で使う。
- 日付の性質
  - 証明: 順序と年月日の辞書順の一致（`lt_iff_lex`）、通算日数の単射性、`addDays` と `daysBetween` の関係、閏年・月末・年越し・範囲外の例。
  - `ofOrdinal?` が範囲内の全日で値を返すことは証明せず、`lake test` で 0001-01-01〜9999-12-31 の全日（3,652,059 日）について、値を返すことと翌日の繰り上がりを検査した（`Tests.SpecChecks.dateExhaustive`）。この検査で、年の候補に 0 年が入る不具合を見つけて直した。
- 適合テストベクタ: `conformance/shared/format/` の 10 操作・73 ケース。期待値は Python の `datetime` とも照合した。`lake test` が `Tests.Conformance` で `Spec` に対して実行する。実行器のファイルの読み込み・形式の検査・比較は機能に依存しない形にした（backlog a8ef で生成器と他の機能に広げる）。
- 文書: `domain-model.md`・`master-data.md`・`configuration.md` の形式化した節を、Lean を正とする要約（informative）に改めた。

## 参照

- [`Spec.Model`](../../lean/Spec/Model.lean)
- [`Spec.MasterData`](../../lean/Spec/MasterData.lean)
- [`Spec.Config`](../../lean/Spec/Config.lean)
- [ADR 6eb2](../decision/6eb2-date-and-time-model.md)
