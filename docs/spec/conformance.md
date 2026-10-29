---
type: Specification
title: "適合テストベクタ"
description: "conformance/ に置く言語中立の JSON テストベクタのディレクトリ構成・スキーマ・操作名・期待値の書き方。"
tags: [spec, conformance, testing]
status: draft
spec_role: meta
models: [spec, source]
generated:
  by: claude-code/claude-opus-5-5
  at: 2026-10-29T22:07:40+09:00
---

# 適合テストベクタ

> **区分: メタ情報（meta）。** 仕様と検証を運用するための情報であり、Lean `Spec` には形式化しない（[ADR 0021](../decision/0021-lean-spec-as-normative-source.md)）。

方針は [ADR 0013](../decision/0013-conformance-test-vectors.md)、運用は [rules/testing.md](../rules/testing.md)。

## ディレクトリ

```
conformance/
  fixtures/                共有入力（master-data.json, config.json, world-*.json）
  spec/<feature>/          [Spec] の期待値
  source-model/<feature>/  [Source] の期待値
  shared/<feature>/        [Spec] と [Source] で同じ期待値
```

`<feature>` は `fare`, `flight-search`, `reservation`, `member`, `authentication`, `report`, `validation`, `format`, `http`。
`spec/`・`shared/` の期待値は Lean `Spec` を実行して生成する。`source-model/` の期待値は Lean `SourceModel` の実行または Java オラクルで得る（[rules/testing.md](../rules/testing.md)）。
Rust の `target_model` は `spec/` と `shared/` の全ベクタを通さなければならない（[refinement.md](refinement.md#証明課題) REF-001）。

## ファイル形式

1 ファイル = 1 つの操作に関するケースの配列。

```json
{
  "operation": "fare.fare",
  "specRef": "docs/spec/fare-calculation.md#運賃",
  "fixtures": { "master": "fixtures/master-data.json", "config": "fixtures/config.json" },
  "cases": [
    {
      "id": "fare-030-1430",
      "description": "丸め誤差で Source が 100 円少なくなる例",
      "input": { "basicFare": 1430, "discountRate": 30 },
      "expected": { "ok": 1100 },
      "source": "lean-spec",
      "differences": ["D-002"]
    }
  ]
}
```

| キー | 必須 | 内容 |
| --- | --- | --- |
| `operation` | 必須 | 操作名（下表） |
| `specRef` | 必須 | 仕様の節への相対パス＋アンカー |
| `fixtures` | 任意 | 既定の共有入力。ケースの `input` で上書きできる |
| `cases[].id` | 必須 | ファイル内で一意 |
| `cases[].today` | 日付に依存する操作では必須 | `"yyyy-MM-dd"` |
| `cases[].now` | 日時に依存する操作では必須 | `"yyyy-MM-ddTHH:mm:ss"`（タイムゾーン無し） |
| `cases[].world` | 状態を使う操作では必須 | 実行前の状態（[ports.md](ports.md#world抽象状態)）またはその fixture への参照 |
| `cases[].input` | 必須 | 操作の入力 |
| `cases[].expected` | 必須 | `{"ok": 値}` または `{"error": {"kind": "Business", "code": "e.ar.b2.2009", "args": []}}`。状態を変える操作は `"worldAfter"` も持てる |
| `cases[].source` | 必須 | `lean-spec`（`spec/`・`shared/`）/ `lean-source-model` / `java-oracle`（`source-model/`）。手計算の例は Lean 側のテストに置き、ベクタには入れない |
| `cases[].differences` | 任意 | 関係する既知差異 ID（[abstraction.md](abstraction.md#既知差異)） |

## 値の表現

| 型 | JSON |
| --- | --- |
| 整数 | 数値（整数のみ。小数・指数表記は使わない） |
| 文字列 | 文字列（UTF-8） |
| Date | `"yyyy-MM-dd"` |
| HourMinute | `"HH:mm"` |
| 列挙 | 原典の綴りの文字列（`"RT"`, `"N"`, `"F"`） |
| Option | 値または `null` |
| 順序付き写像 | `[[key, value], ...]` の配列（JSON オブジェクトのキー順に依存しないため） |
| バイト列 | `{"utf8": "…"}`（UTF-8 として正しい場合）または `{"hex": "…"}` |
| [Source] の非決定的結果 | `{"oneOf": [値, ...]}` |

## 操作名

| 操作 | 仕様 |
| --- | --- |
| `fare.basicFare`, `fare.fare`, `fare.totalFare` | [fare-calculation.md](fare-calculation.md) |
| `flightSearch.validateDepartureDate`, `flightSearch.isAvailableFareType`, `flightSearch.searchFlight` | [flight-search.md](flight-search.md) |
| `reservation.validateFlightList`, `reservation.validateReservation`, `reservation.reserveConfirm`, `reservation.reserve` | [reservation.md](reservation.md) |
| `member.toMember`, `member.toMemberUpdateInput`, `member.register`, `member.update` | [member.md](member.md) |
| `auth.login`, `auth.logout` | [authentication.md](authentication.md) |
| `report.reportFileName`, `report.renderCsv`, `report.createReport`, `report.listReports` | [reservation-history-report.md](reservation-history-report.md) |
| `validation.<入力名>` | [input-validation.md](input-validation.md) |
| `format.fmtDate`, `format.fmtTime`, `format.fmtYen`, `format.fullYearsBetween` | [domain-model.md](domain-model.md) |
| `http.<リクエスト>` | [http-contract.md](http-contract.md) |

`PasswordHasher` を使う操作のベクタは、参照アダプタのハッシュ（`"{test}" ++ raw`）を前提とする。
